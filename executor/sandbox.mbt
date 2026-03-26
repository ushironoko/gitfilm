///|
fn git_in(path : String, args : Array[String]) -> Result[String, String] {
  let full_args : Array[String] = ["-C", path]
  for a in args {
    full_args.push(a)
  }
  match @process.exec("git", full_args, ".") {
    Ok((output, exit_code)) =>
      if exit_code == 0 {
        Ok(output)
      } else {
        let args_str = args.join(" ")
        Err("git \{args_str} failed (exit \{exit_code}): \{output}")
      }
    Err(e) => Err(e)
  }
}

///|
fn generate_worktree_path() -> Result[String, String] {
  match @process.exec("date", ["+%s%N"], ".") {
    Ok((output, _)) => {
      let ts = trim_end(output)
      Ok("/tmp/gitfilm-wt-\{ts}")
    }
    Err(e) => Err(e)
  }
}

///|
fn check_head_exists() -> Result[Unit, String] {
  match @process.exec("git", ["rev-parse", "HEAD"], ".") {
    Ok((_, code)) =>
      if code == 0 {
        Ok(())
      } else {
        Err("repository has no commits (HEAD does not exist)")
      }
    Err(e) => Err(e)
  }
}

///|
pub fn create_worktree() -> Result[String, String] {
  match validate_git_repo(".") {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  let wt_path = match generate_worktree_path() {
    Ok(p) => p
    Err(e) => return Err(e)
  }
  let has_head = match check_head_exists() {
    Ok(_) => true
    Err(_) => false
  }
  if has_head {
    match
      @process.exec(
        "git", ["worktree", "add", wt_path, "--detach", "HEAD"], ".",
      ) {
      Ok((_, code)) =>
        if code != 0 {
          return Err("Failed to create worktree")
        }
      Err(e) => return Err(e)
    }
    match sync_dirty_files(wt_path) {
      Ok(_) => ()
      Err(e) => {
        let _ = remove_worktree(wt_path)
        return Err(e)
      }
    }
  } else {
    match create_fresh_sandbox(wt_path) {
      Ok(_) => ()
      Err(e) => {
        let _ = @process.exec("rm", ["-rf", wt_path], ".")
        return Err(e)
      }
    }
  }
  Ok(wt_path)
}

///|
fn get_source_git_dir() -> Result[String, String] {
  match @process.exec("git", ["rev-parse", "--absolute-git-dir"], ".") {
    Ok((output, code)) =>
      if code == 0 {
        Ok(trim_end(output))
      } else {
        Err("Failed to resolve source .git directory")
      }
    Err(e) => Err(e)
  }
}

///|
fn copy_repo_local_settings(
  src_git_dir : String,
  dst_git_dir : String,
) -> Unit {
  // Reproduce source repo's local config (user.name, user.email, etc.)
  let _ = @process.exec(
    "cp", ["-f", src_git_dir + "/config", dst_git_dir + "/config"], ".",
  )
  // Reproduce source repo's hooks for faithful dry-run behavior
  let _ = @process.exec("rm", ["-rf", dst_git_dir + "/hooks"], ".")
  let _ = @process.exec(
    "cp", ["-a", src_git_dir + "/hooks", dst_git_dir + "/hooks"], ".",
  )
}

///|
fn create_fresh_sandbox(wt_path : String) -> Result[Unit, String] {
  match @process.exec("mkdir", ["-p", wt_path], ".") {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  match @process.exec("git", ["init", wt_path], ".") {
    Ok((_, code)) =>
      if code != 0 {
        return Err("Failed to initialize sandbox repository")
      }
    Err(e) => return Err(e)
  }
  let src_git_dir = match get_source_git_dir() {
    Ok(d) => d
    Err(e) => return Err(e)
  }
  copy_repo_local_settings(src_git_dir, wt_path + "/.git")
  // Copy indexed files from original repo to sandbox
  let wt_prefix = wt_path + "/"
  let _ = @process.exec(
    "git",
    ["checkout-index", "--all", "--force", "--prefix", wt_prefix],
    ".",
  )
  // Stage copied files in the sandbox
  let _ = git_in(wt_path, ["add", "-A"])
  // Overwrite with working tree modifications
  let wt_modified = match
    @process.exec("git", ["diff", "--diff-filter=d", "--name-only"], ".") {
    Ok((output, _)) => lines_from_output(output)
    Err(_) => []
  }
  for file in wt_modified {
    copy_file_to_wt(file, wt_path)
  }
  // Handle working tree deletions
  let wt_deleted = match
    @process.exec("git", ["diff", "--diff-filter=D", "--name-only"], ".") {
    Ok((output, _)) => lines_from_output(output)
    Err(_) => []
  }
  for file in wt_deleted {
    remove_file_from_wt(file, wt_path)
  }
  // Copy untracked files
  let untracked = match
    @process.exec(
      "git", ["ls-files", "--others", "--exclude-standard"], ".",
    ) {
    Ok((output, _)) => lines_from_output(output)
    Err(_) => []
  }
  for file in untracked {
    copy_file_to_wt(file, wt_path)
  }
  Ok(())
}

///|
fn lines_from_output(output : String) -> Array[String] {
  output
  .split("\n")
  .map(fn(sv) { sv.to_string() })
  .filter(fn(s) { s != "" })
  .collect()
}

///|
fn copy_file_to_wt(file : String, wt_path : String) -> Unit {
  let dest = wt_path + "/" + file
  let parent = extract_parent_dir(dest)
  if parent != "" {
    let _ = @process.exec("mkdir", ["-p", parent], ".")
  }
  let _ = @process.exec("cp", [file, dest], ".")
}

///|
fn remove_file_from_wt(file : String, wt_path : String) -> Unit {
  let dest = wt_path + "/" + file
  let _ = @process.exec("rm", ["-f", dest], ".")
}

///|
fn sync_dirty_files(wt_path : String) -> Result[Unit, String] {
  let wt_prefix = wt_path + "/"
  // Overwrite worktree files with current index content (reproduces staged state)
  let _ = @process.exec(
    "git",
    ["checkout-index", "--all", "--force", "--prefix", wt_prefix],
    ".",
  )
  // Handle staged deletions: files removed from index but still present in worktree from HEAD
  let staged_deletions = match
    @process.exec(
      "git", ["diff", "--cached", "--diff-filter=D", "--name-only"], ".",
    ) {
    Ok((output, _)) => lines_from_output(output)
    Err(_) => []
  }
  for file in staged_deletions {
    remove_file_from_wt(file, wt_path)
    let _ = git_in(wt_path, ["rm", "--force", file])
  }
  // Stage files that are in the index but differ from HEAD (excluding deletions already handled)
  let staged_modified = match
    @process.exec(
      "git", ["diff", "--cached", "--diff-filter=d", "--name-only"], ".",
    ) {
    Ok((output, _)) => lines_from_output(output)
    Err(_) => []
  }
  for file in staged_modified {
    let _ = git_in(wt_path, ["add", file])
  }
  // Handle unstaged deletions: files in index but deleted from working tree
  let unstaged_deletions = match
    @process.exec(
      "git", ["diff", "--diff-filter=D", "--name-only"], ".",
    ) {
    Ok((output, _)) => lines_from_output(output)
    Err(_) => []
  }
  for file in unstaged_deletions {
    remove_file_from_wt(file, wt_path)
  }
  // Overwrite with working tree content for unstaged modifications (excluding deletions)
  let unstaged_modified = match
    @process.exec(
      "git", ["diff", "--diff-filter=d", "--name-only"], ".",
    ) {
    Ok((output, _)) => lines_from_output(output)
    Err(_) => []
  }
  for file in unstaged_modified {
    copy_file_to_wt(file, wt_path)
  }
  // Copy untracked files
  let untracked = match
    @process.exec(
      "git", ["ls-files", "--others", "--exclude-standard"], ".",
    ) {
    Ok((output, _)) => lines_from_output(output)
    Err(_) => []
  }
  for file in untracked {
    copy_file_to_wt(file, wt_path)
  }
  Ok(())
}

///|
fn extract_parent_dir(path : String) -> String {
  let chars = path.to_array()
  let mut last_slash = -1
  for i, c in chars {
    if c == '/' {
      last_slash = i
    }
  }
  if last_slash <= 0 {
    ""
  } else {
    String::from_array(chars[0:last_slash].to_array())
  }
}

///|
pub fn remove_worktree(wt_path : String) -> Result[Unit, String] {
  let _ = @process.exec("git", ["worktree", "remove", wt_path, "--force"], ".")
  // worktree remove may leave the directory if untracked files exist
  let _ = @process.exec("rm", ["-rf", wt_path], ".")
  let _ = @process.exec("git", ["worktree", "prune"], ".")
  Ok(())
}

///|
pub fn validate_git_repo(path : String) -> Result[Unit, String] {
  match git_in(path, ["rev-parse", "--is-inside-work-tree"]) {
    Ok(_) => Ok(())
    Err(_) => Err("'\{path}' is not a git repository")
  }
}

///|
fn trim_end(s : String) -> String {
  let chars = s.to_array()
  let mut end = chars.length()
  while end > 0 {
    let c = chars[end - 1]
    if c == '\n' || c == '\r' || c == ' ' || c == '\t' {
      end -= 1
    } else {
      break
    }
  }
  String::from_array(chars[0:end].to_array())
}
