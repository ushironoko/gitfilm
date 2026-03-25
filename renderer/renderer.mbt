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
  // Working Tree
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
  // Staging Area
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
  // Repository
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
