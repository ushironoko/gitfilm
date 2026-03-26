///|
pub(all) struct SimResult {
  prev_porcelain_status : String
  prev_log_output : String
  porcelain_status : String
  diff_stat : String
  log_output : String
  touched_paths : Array[String]
  exec_log : String
  prev_tracked_paths : Array[String]
  tracked_paths : Array[String]
} derive(Show)

///|
fn get_commit_count(repo_path : String) -> Int {
  match git_in(repo_path, ["rev-list", "--count", "HEAD"]) {
    Ok(output) => {
      let trimmed = trim_end(output)
      @strconv.parse_int(trimmed) catch {
        _ => 0
      }
    }
    Err(_) => 0
  }
}

///|
fn resolve_git_args(
  op : @model.Operation,
  repo_path : String,
  sandbox? : Bool = true,
) -> Result[Array[Array[String]], String] {
  match op {
    ResetSoft(n) => {
      let count = get_commit_count(repo_path)
      if n >= count && count > 0 {
        if not(sandbox) {
          return Err(
            "--execute does not support resetting past the root commit",
          )
        }
        Ok([["update-ref", "-d", "HEAD"]])
      } else {
        Ok([to_git_args(op).args])
      }
    }
    ResetMixed(n) => {
      let count = get_commit_count(repo_path)
      if n >= count && count > 0 {
        if not(sandbox) {
          return Err(
            "--execute does not support resetting past the root commit",
          )
        }
        Ok([["update-ref", "-d", "HEAD"], ["rm", "--cached", "-rf", "."]])
      } else {
        Ok([to_git_args(op).args])
      }
    }
    ResetHard(n) => {
      let count = get_commit_count(repo_path)
      if n >= count && count > 0 {
        if not(sandbox) {
          return Err(
            "--execute does not support resetting past the root commit",
          )
        }
        Ok([["rm", "-rf", "."], ["update-ref", "-d", "HEAD"]])
      } else {
        Ok([to_git_args(op).args])
      }
    }
    _ => Ok([to_git_args(op).args])
  }
}

///|
fn run_op(
  repo_path : String,
  op : @model.Operation,
  log : StringBuilder,
  sandbox? : Bool = true,
) -> Result[Unit, String] {
  let cmd_groups = match resolve_git_args(op, repo_path, sandbox~) {
    Ok(groups) => groups
    Err(e) => return Err(e)
  }
  for args in cmd_groups {
    let args_str = args.join(" ")
    match git_in(repo_path, args) {
      Ok(output) => {
        log.write_string("$ git \{args_str}\n")
        if output != "" {
          log.write_string(output)
          if not(output.has_suffix("\n")) {
            log.write_string("\n")
          }
        }
      }
      Err(e) => return Err(e)
    }
  }
  Ok(())
}

///|
fn extract_paths_from_porcelain(porcelain : String) -> Array[String] {
  let paths : Array[String] = []
  if porcelain == "" {
    return paths
  }
  let lines = porcelain.split("\n").map(fn(sv) { sv.to_string() }).collect()
  for line in lines {
    if line.length() >= 3 {
      let path = line[3:].to_string()
      if path != "" {
        paths.push(path)
      }
    }
  }
  paths
}

///|
fn get_head_hash(repo_path : String) -> String? {
  match git_in(repo_path, ["rev-parse", "HEAD"]) {
    Ok(output) => Some(trim_end(output))
    Err(_) => None
  }
}

///|
fn extract_lines(output : String) -> Array[String] {
  if output == "" {
    return []
  }
  let lines : Array[String] = output
    .split("\n")
    .map(fn(sv) { sv.to_string() })
    .filter(fn(s) { s != "" })
    .collect()
  lines
}

///|
fn collect_tree_diff_paths(
  repo_path : String,
  before_head : String?,
  after_head : String?,
) -> Array[String] {
  match (before_head, after_head) {
    (Some(old), Some(new_h)) =>
      if old == new_h {
        []
      } else {
        extract_lines(
          git_in(repo_path, [
            "diff-tree", "--no-commit-id", "--name-only", "-r", old, new_h,
          ]).unwrap_or(""),
        )
      }
    (Some(hash), None) =>
      extract_lines(
        git_in(repo_path, ["ls-tree", "--name-only", "-r", hash]).unwrap_or(""),
      )
    (None, Some(hash)) =>
      extract_lines(
        git_in(repo_path, ["ls-tree", "--name-only", "-r", hash]).unwrap_or(""),
      )
    (None, None) => []
  }
}

///|
fn dedupe_and_sort(arr : Array[String]) -> Array[String] {
  let seen : Map[String, Unit] = {}
  for s in arr {
    seen[s] = ()
  }
  let result : Array[String] = []
  seen.each(fn(k, _) { result.push(k) })
  result.sort()
  result
}

///|
pub fn simulate(ops : Array[@model.Operation]) -> Result[SimResult, String] {
  let wt_path = match create_worktree() {
    Ok(p) => p
    Err(e) => return Err(e)
  }
  let prev_porcelain_status = git_in(wt_path, ["status", "--porcelain"]).unwrap_or(
    "",
  )
  let prev_log_output = git_in(wt_path, ["log", "--oneline", "-20"]).unwrap_or(
    "",
  )
  let prev_tracked_paths = extract_lines(
    git_in(wt_path, ["ls-files"]).unwrap_or(""),
  )
  let log = StringBuilder::new()
  let all_touched : Array[String] = []
  for op in ops {
    let before_paths = extract_paths_from_porcelain(
      git_in(wt_path, ["status", "--porcelain"]).unwrap_or(""),
    )
    let before_head = get_head_hash(wt_path)
    match run_op(wt_path, op, log) {
      Ok(_) => ()
      Err(e) => {
        let _ = remove_worktree(wt_path)
        return Err(e)
      }
    }
    let after_paths = extract_paths_from_porcelain(
      git_in(wt_path, ["status", "--porcelain"]).unwrap_or(""),
    )
    let after_head = get_head_hash(wt_path)
    for p in before_paths {
      all_touched.push(p)
    }
    for p in after_paths {
      all_touched.push(p)
    }
    let tree_diff = collect_tree_diff_paths(wt_path, before_head, after_head)
    for p in tree_diff {
      all_touched.push(p)
    }
    match op {
      Add(file) => if file != "." { all_touched.push(file) }
      Restore(file) => all_touched.push(file)
      Checkout(file) => all_touched.push(file)
      Rm(file) => all_touched.push(file)
      _ => ()
    }
  }
  let porcelain_status = git_in(wt_path, ["status", "--porcelain"]).unwrap_or(
    "",
  )
  let diff_stat = git_in(wt_path, ["diff", "--stat"]).unwrap_or("")
  let log_output = git_in(wt_path, ["log", "--oneline", "-20"]).unwrap_or("")
  let tracked_paths = extract_lines(git_in(wt_path, ["ls-files"]).unwrap_or(""))
  match remove_worktree(wt_path) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  let touched_paths = dedupe_and_sort(all_touched)
  Ok({
    prev_porcelain_status,
    prev_log_output,
    porcelain_status,
    diff_stat,
    log_output,
    touched_paths,
    exec_log: log.to_string(),
    prev_tracked_paths,
    tracked_paths,
  })
}

///|
// Pure validation: given an initial commit count, reject any operation sequence
// that would reset past the root commit.
fn validate_ops_commit_safety(
  initial_count : Int,
  ops : Array[@model.Operation],
) -> Result[Unit, String] {
  let mut count = initial_count
  for i, op in ops {
    match op {
      ResetSoft(n) | ResetMixed(n) | ResetHard(n) => {
        if n >= count && count > 0 {
          return Err(
            "step \{i + 1}: --execute does not support resetting past the root commit",
          )
        }
        count = count - n
      }
      Commit(_) => count = count + 1
      _ => ()
    }
  }
  Ok(())
}

///|
fn preflight_execute_ops(
  repo_path : String,
  ops : Array[@model.Operation],
) -> Result[Unit, String] {
  validate_ops_commit_safety(get_commit_count(repo_path), ops)
}

///|
pub fn execute(ops : Array[@model.Operation]) -> Result[String, String] {
  match validate_git_repo(".") {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  match preflight_execute_ops(".", ops) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  match simulate(ops) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  let log = StringBuilder::new()
  for i, op in ops {
    match run_op(".", op, log, sandbox=false) {
      Ok(_) => ()
      Err(e) => {
        log.write_string("Error at step \{i + 1}: \{e}\n")
        let total = ops.length()
        log.write_string("Completed \{i}/\{total} operations\n")
        return Err(log.to_string())
      }
    }
  }
  Ok(log.to_string())
}
