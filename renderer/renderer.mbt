///|
fn collect_all_paths(state : @model.GitState) -> Array[String] {
  let paths : Map[String, Unit] = {}
  state.working_tree.files.each(fn(k, _) { paths[k] = () })
  state.staging_area.files.each(fn(k, _) { paths[k] = () })
  match state.repository.head_commit() {
    Some(commit) => commit.files.each(fn(k, _) { paths[k] = () })
    None => ()
  }
  let result : Array[String] = []
  paths.each(fn(k, _) { result.push(k) })
  result.sort()
  result
}

///|
fn format_diff(d : @model.DiffSummary) -> String {
  "(+\{d.added} -\{d.removed})"
}

///|
fn compute_wt_status(
  path : String,
  state : @model.GitState,
) -> @model.FileStatus? {
  let wt_content = state.working_tree.files.get(path)
  match wt_content {
    None => {
      let in_repo = match state.repository.head_commit() {
        Some(c) => c.files.contains(path)
        None => false
      }
      if in_repo {
        Some(@model.FileStatus::Deleted)
      } else {
        None
      }
    }
    Some(wt) => {
      let ref_content = match state.staging_area.files.get(path) {
        Some(sa) => sa
        None => state.repository.get_file_at_head(path)
      }
      if ref_content.is_empty() {
        let in_repo = match state.repository.head_commit() {
          Some(c) => c.files.contains(path)
          None => false
        }
        if in_repo {
          let repo_content = state.repository.get_file_at_head(path)
          if wt == repo_content {
            Some(@model.FileStatus::Clean)
          } else {
            Some(
              @model.FileStatus::Modified(@model.diff_summary(repo_content, wt)),
            )
          }
        } else {
          Some(@model.FileStatus::Untracked)
        }
      } else if wt == ref_content {
        Some(@model.FileStatus::Clean)
      } else {
        Some(@model.FileStatus::Modified(@model.diff_summary(ref_content, wt)))
      }
    }
  }
}

///|
fn compute_sa_status(
  path : String,
  state : @model.GitState,
) -> @model.FileStatus? {
  match state.staging_area.files.get(path) {
    None => None
    Some(sa_content) =>
      if sa_content.is_empty() {
        Some(@model.FileStatus::Deleted)
      } else {
        let repo_content = state.repository.get_file_at_head(path)
        if sa_content == repo_content {
          Some(@model.FileStatus::Clean)
        } else {
          Some(
            @model.FileStatus::Staged(
              @model.diff_summary(repo_content, sa_content),
            ),
          )
        }
      }
  }
}

///|
fn compute_repo_status(
  path : String,
  state : @model.GitState,
) -> @model.FileStatus? {
  match state.repository.head_commit() {
    Some(commit) =>
      if commit.files.contains(path) {
        Some(@model.FileStatus::Committed(commit.id))
      } else {
        None
      }
    None => None
  }
}

///|
fn format_status(status : @model.FileStatus) -> String {
  match status {
    Clean => "clean"
    Untracked => "untracked"
    Modified(d) => "modified  \{format_diff(d)}"
    Staged(d) => "staged    \{format_diff(d)}"
    Committed(id) => "committed (\{id})"
    Deleted => "deleted"
  }
}

///|
pub fn render_state(state : @model.GitState, label : String) -> String {
  let buf = StringBuilder::new()
  buf.write_string("=== \{label} ===\n")
  let paths = collect_all_paths(state)
  buf.write_string("[Working Tree]  ")
  let mut wt_has_entries = false
  for path in paths {
    match compute_wt_status(path, state) {
      Some(status) => {
        if wt_has_entries {
          buf.write_string("                ")
        }
        buf.write_string("\{path}: \{format_status(status)}\n")
        wt_has_entries = true
      }
      None => ()
    }
  }
  if not(wt_has_entries) {
    buf.write_string("(empty)\n")
  }
  buf.write_string("[Staging Area]  ")
  let mut sa_has_entries = false
  for path in paths {
    match compute_sa_status(path, state) {
      Some(status) => {
        if sa_has_entries {
          buf.write_string("                ")
        }
        buf.write_string("\{path}: \{format_status(status)}\n")
        sa_has_entries = true
      }
      None => ()
    }
  }
  if not(sa_has_entries) {
    buf.write_string("(empty)\n")
  }
  buf.write_string("[Repository]    ")
  let mut repo_has_entries = false
  for path in paths {
    match compute_repo_status(path, state) {
      Some(status) => {
        if repo_has_entries {
          buf.write_string("                ")
        }
        buf.write_string("\{path}: \{format_status(status)}\n")
        repo_has_entries = true
      }
      None => ()
    }
  }
  if not(repo_has_entries) {
    buf.write_string("(no commits)\n")
  }
  buf.to_string()
}

///|
pub fn render_comparison(
  prev : @model.GitState,
  next : @model.GitState,
  ops : Array[@model.Operation],
) -> String {
  let ops_desc = ops.map(fn(op) { op.to_string() }).join(", ")
  let prev_output = render_state(prev, "prev")
  let next_output = render_state(next, "next (after: \{ops_desc})")
  prev_output + "\n" + next_output
}

///|
pub(all) struct PorcelainEntry {
  staging : Char
  worktree : Char
  path : String
} derive(Show, Eq)

///|
pub fn parse_porcelain_status(output : String) -> Array[PorcelainEntry] {
  let entries : Array[PorcelainEntry] = []
  if output == "" {
    return entries
  }
  let lines = output.split("\n").map(fn(sv) { sv.to_string() }).collect()
  for line in lines {
    if line.length() < 3 {
      continue
    }
    let staging = line.code_unit_at(0).unsafe_to_char()
    let worktree = line.code_unit_at(1).unsafe_to_char()
    let path = line[3:].to_string()
    entries.push({ staging, worktree, path })
  }
  entries
}

///|
fn format_porcelain_wt_status(entry : PorcelainEntry) -> String {
  match entry.worktree {
    'M' => "modified"
    'D' => "deleted"
    '?' => "untracked"
    _ =>
      // Staged deletion means file is absent from working tree
      if entry.staging == 'D' {
        "deleted"
      } else {
        "clean"
      }
  }
}

///|
fn format_porcelain_sa_status(entry : PorcelainEntry) -> String? {
  match entry.staging {
    'A' => Some("staged (new file)")
    'M' => Some("staged (modified)")
    'D' => Some("staged (deleted)")
    _ => None
  }
}

///|
fn render_area_files(
  buf : StringBuilder,
  label : String,
  paths : Array[String],
  entries : Array[PorcelainEntry],
  format_fn : (PorcelainEntry) -> String?,
  default_fn : (String) -> String,
  empty_label : String,
) -> Unit {
  buf.write_string("\{label}")
  let padding = " ".repeat(label.length())
  let mut first = true
  for path in paths {
    let mut found_status : String? = None
    for e in entries {
      if e.path == path {
        found_status = format_fn(e)
        break
      }
    }
    let status = found_status.unwrap_or(default_fn(path))
    if status == "" {
      continue
    }
    if not(first) {
      buf.write_string(padding)
    }
    buf.write_string("\{path}: \{status}\n")
    first = false
  }
  if first {
    buf.write_string("\{empty_label}\n")
  }
}

///|
fn render_log(buf : StringBuilder, label : String, log_output : String) -> Unit {
  buf.write_string(label)
  if log_output == "" {
    buf.write_string("(no commits)\n")
  } else {
    let padding = " ".repeat(label.length())
    let commits = log_output
      .split("\n")
      .map(fn(sv) { sv.to_string() })
      .filter(fn(s) { s != "" })
      .collect()
    let mut first = true
    for c in commits {
      if not(first) {
        buf.write_string(padding)
      }
      buf.write_string("\{c}\n")
      first = false
    }
  }
}

///|
fn operation_to_json(op : @model.Operation) -> Json {
  let obj : Map[String, Json] = {}
  match op {
    Add(file) => {
      obj["kind"] = Json::string("add")
      obj["args"] = Json::array([Json::string(file)])
    }
    Commit(None) => {
      obj["kind"] = Json::string("commit")
      obj["args"] = Json::array([])
    }
    Commit(Some(msg)) => {
      obj["kind"] = Json::string("commit")
      obj["args"] = Json::array([Json::string("-m"), Json::string(msg)])
    }
    ResetSoft(n) => {
      obj["kind"] = Json::string("reset")
      obj["args"] = Json::array([
        Json::string("--soft"),
        Json::string("HEAD~\{n}"),
      ])
    }
    ResetMixed(n) => {
      obj["kind"] = Json::string("reset")
      obj["args"] = Json::array([
        Json::string("--mixed"),
        Json::string("HEAD~\{n}"),
      ])
    }
    ResetHard(n) => {
      obj["kind"] = Json::string("reset")
      obj["args"] = Json::array([
        Json::string("--hard"),
        Json::string("HEAD~\{n}"),
      ])
    }
    Restore(file) => {
      obj["kind"] = Json::string("restore")
      obj["args"] = Json::array([Json::string(file)])
    }
    Checkout(file) => {
      obj["kind"] = Json::string("checkout")
      obj["args"] = Json::array([Json::string("--"), Json::string(file)])
    }
    Rm(file) => {
      obj["kind"] = Json::string("rm")
      obj["args"] = Json::array([Json::string(file)])
    }
  }
  Json::object(obj)
}

///|
fn build_wt_json(
  paths : Array[String],
  entries : Array[PorcelainEntry],
  tracked : Map[String, Unit],
) -> Json {
  let items : Array[Json] = []
  for path in paths {
    let mut status_str = ""
    for e in entries {
      if e.path == path {
        status_str = format_porcelain_wt_status(e)
        break
      }
    }
    if status_str == "" && tracked.contains(path) {
      status_str = "clean"
    }
    if status_str != "" {
      let entry : Map[String, Json] = {}
      entry["path"] = Json::string(path)
      entry["status"] = Json::string(status_str)
      items.push(Json::object(entry))
    }
  }
  Json::array(items)
}

///|
fn build_sa_json(
  paths : Array[String],
  entries : Array[PorcelainEntry],
) -> Json {
  let items : Array[Json] = []
  for path in paths {
    for e in entries {
      if e.path == path {
        match format_porcelain_sa_status(e) {
          Some(status_str) => {
            let entry : Map[String, Json] = {}
            entry["path"] = Json::string(path)
            entry["status"] = Json::string(status_str)
            items.push(Json::object(entry))
          }
          None => ()
        }
        break
      }
    }
  }
  Json::array(items)
}

///|
fn parse_commit_line(line : String) -> Json {
  let obj : Map[String, Json] = {}
  let mut first_space = -1
  for i = 0; i < line.length(); i = i + 1 {
    if line.code_unit_at(i) == 0x20 {
      first_space = i
      break
    }
  }
  if first_space >= 0 {
    obj["hash"] = Json::string(line[0:first_space].to_string())
    obj["message"] = Json::string(line[first_space + 1:].to_string())
  } else {
    obj["hash"] = Json::string(line)
    obj["message"] = Json::string("")
  }
  Json::object(obj)
}

///|
fn build_repo_json(log_output : String) -> Json {
  let commits : Array[Json] = []
  if log_output != "" {
    let lines = log_output
      .split("\n")
      .map(fn(sv) { sv.to_string() })
      .filter(fn(s) { s != "" })
      .collect()
    for line in lines {
      commits.push(parse_commit_line(line))
    }
  }
  let repo : Map[String, Json] = {}
  repo["commits"] = Json::array(commits)
  Json::object(repo)
}

///|
pub fn render_json_from_sim_result(
  result : @executor.SimResult,
  ops : Array[@model.Operation],
) -> String {
  let touched = result.touched_paths
  let prev_entries = parse_porcelain_status(result.prev_porcelain_status)
  let next_entries = parse_porcelain_status(result.porcelain_status)
  let prev_tracked : Map[String, Unit] = {}
  for p in result.prev_tracked_paths {
    prev_tracked[p] = ()
  }
  let next_tracked : Map[String, Unit] = {}
  for p in result.tracked_paths {
    next_tracked[p] = ()
  }
  let ops_json : Array[Json] = ops.map(fn(op) { operation_to_json(op) })
  let prev : Map[String, Json] = {}
  prev["working_tree"] = build_wt_json(touched, prev_entries, prev_tracked)
  prev["staging_area"] = build_sa_json(touched, prev_entries)
  prev["repository"] = build_repo_json(result.prev_log_output)
  let next : Map[String, Json] = {}
  next["working_tree"] = build_wt_json(touched, next_entries, next_tracked)
  next["staging_area"] = build_sa_json(touched, next_entries)
  next["repository"] = build_repo_json(result.log_output)
  let root : Map[String, Json] = {}
  root["operations"] = Json::array(ops_json)
  root["prev"] = Json::object(prev)
  root["next"] = Json::object(next)
  Json::object(root).stringify()
}

///|
pub fn render_from_sim_result(
  result : @executor.SimResult,
  ops : Array[@model.Operation],
) -> String {
  let ops_desc = ops.map(fn(op) { op.to_string() }).join(", ")
  let buf = StringBuilder::new()
  let touched = result.touched_paths
  let prev_entries = parse_porcelain_status(result.prev_porcelain_status)
  let next_entries = parse_porcelain_status(result.porcelain_status)
  let prev_tracked : Map[String, Unit] = {}
  for p in result.prev_tracked_paths {
    prev_tracked[p] = ()
  }
  let next_tracked : Map[String, Unit] = {}
  for p in result.tracked_paths {
    next_tracked[p] = ()
  }
  buf.write_string("=== prev ===\n")
  render_area_files(
    buf,
    "[Working Tree]  ",
    touched,
    prev_entries,
    fn(e) { Some(format_porcelain_wt_status(e)) },
    fn(path) { if prev_tracked.contains(path) { "clean" } else { "" } },
    "(empty)",
  )
  render_area_files(
    buf,
    "[Staging Area]  ",
    touched,
    prev_entries,
    fn(e) { format_porcelain_sa_status(e) },
    fn(_) { "" },
    "(empty)",
  )
  render_log(buf, "[Repository]    ", result.prev_log_output)
  buf.write_string("\n")
  buf.write_string("=== next (after: \{ops_desc}) ===\n")
  render_area_files(
    buf,
    "[Working Tree]  ",
    touched,
    next_entries,
    fn(e) { Some(format_porcelain_wt_status(e)) },
    fn(path) { if next_tracked.contains(path) { "clean" } else { "" } },
    "(empty)",
  )
  render_area_files(
    buf,
    "[Staging Area]  ",
    touched,
    next_entries,
    fn(e) { format_porcelain_sa_status(e) },
    fn(_) { "" },
    "(empty)",
  )
  render_log(buf, "[Repository]    ", result.log_output)
  buf.to_string()
}
