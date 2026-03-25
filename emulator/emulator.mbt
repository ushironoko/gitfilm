///|
fn copy_file_map(
  m : Map[String, @model.FileContent],
) -> Map[String, @model.FileContent] {
  let result : Map[String, @model.FileContent] = {}
  m.each(fn(k, v) { result[k] = v })
  result
}

///|
fn apply_add(
  state : @model.GitState,
  file : String,
) -> Result[@model.GitState, String] {
  match state.working_tree.files.get(file) {
    Some(content) => {
      let new_staging = copy_file_map(state.staging_area.files)
      new_staging[file] = content
      Ok({
        working_tree: state.working_tree,
        staging_area: { files: new_staging },
        repository: state.repository,
        next_commit_seq: state.next_commit_seq,
      })
    }
    None => Err("pathspec '\{file}' did not match any files")
  }
}

///|
fn apply_commit(state : @model.GitState) -> Result[@model.GitState, String] {
  if state.staging_area.files.is_empty() {
    return Err("nothing to commit, staging area is empty")
  }
  let base_files : Map[String, @model.FileContent] = match
    state.repository.head_commit() {
    Some(commit) => copy_file_map(commit.files)
    None => {}
  }
  state.staging_area.files.each(fn(path, content) {
    if content.is_empty() {
      base_files.remove(path)
    } else {
      base_files[path] = content
    }
  })
  let commit_id = @model.generate_commit_id(state.next_commit_seq)
  let parent_id : String? = match state.repository.head_commit() {
    Some(c) => Some(c.id)
    None => None
  }
  let new_commit : @model.Commit = {
    id: commit_id,
    files: base_files,
    parent: parent_id,
  }
  let new_commits = if state.repository.head >= 0 {
    state.repository.commits[0:state.repository.head + 1].to_array()
  } else {
    []
  }
  new_commits.push(new_commit)
  Ok({
    working_tree: state.working_tree,
    staging_area: { files: {} },
    repository: { commits: new_commits, head: new_commits.length() - 1 },
    next_commit_seq: state.next_commit_seq + 1,
  })
}

///|
fn apply_reset_soft(
  state : @model.GitState,
  n : Int,
) -> Result[@model.GitState, String] {
  let new_head = state.repository.head - n
  if new_head < -1 {
    return Err(
      "Cannot reset: only \{state.repository.head + 1} commits in history",
    )
  }
  let old_head_files : Map[String, @model.FileContent] = match
    state.repository.head_commit() {
    Some(c) => c.files
    None => {}
  }
  let new_head_files : Map[String, @model.FileContent] = if new_head >= 0 {
    state.repository.commits[new_head].files
  } else {
    {}
  }
  let new_staging = copy_file_map(state.staging_area.files)
  old_head_files.each(fn(path, content) {
    let new_head_content = new_head_files
      .get(path)
      .unwrap_or(@model.FileContent::empty())
    if content != new_head_content {
      new_staging[path] = content
    }
  })
  Ok({
    working_tree: state.working_tree,
    staging_area: { files: new_staging },
    repository: { ..state.repository, head: new_head },
    next_commit_seq: state.next_commit_seq,
  })
}

///|
fn apply_reset_mixed(
  state : @model.GitState,
  n : Int,
) -> Result[@model.GitState, String] {
  let new_head = state.repository.head - n
  if new_head < -1 {
    return Err(
      "Cannot reset: only \{state.repository.head + 1} commits in history",
    )
  }
  Ok({
    working_tree: state.working_tree,
    staging_area: { files: {} },
    repository: { ..state.repository, head: new_head },
    next_commit_seq: state.next_commit_seq,
  })
}

///|
fn apply_reset_hard(
  state : @model.GitState,
  n : Int,
) -> Result[@model.GitState, String] {
  let new_head = state.repository.head - n
  if new_head < -1 {
    return Err(
      "Cannot reset: only \{state.repository.head + 1} commits in history",
    )
  }
  let new_wt_files : Map[String, @model.FileContent] = if new_head >= 0 {
    copy_file_map(state.repository.commits[new_head].files)
  } else {
    {}
  }
  Ok({
    working_tree: { files: new_wt_files },
    staging_area: { files: {} },
    repository: { ..state.repository, head: new_head },
    next_commit_seq: state.next_commit_seq,
  })
}

///|
fn apply_restore(
  state : @model.GitState,
  file : String,
) -> Result[@model.GitState, String] {
  let restore_content = match state.staging_area.files.get(file) {
    Some(content) => content
    None => state.repository.get_file_at_head(file)
  }
  if restore_content.is_empty() && not(state.working_tree.files.contains(file)) {
    return Err("pathspec '\{file}' did not match any files")
  }
  let new_wt_files = copy_file_map(state.working_tree.files)
  if restore_content.is_empty() {
    new_wt_files.remove(file)
  } else {
    new_wt_files[file] = restore_content
  }
  Ok({
    working_tree: { files: new_wt_files },
    staging_area: state.staging_area,
    repository: state.repository,
    next_commit_seq: state.next_commit_seq,
  })
}

///|
fn apply_rm(
  state : @model.GitState,
  file : String,
) -> Result[@model.GitState, String] {
  if not(state.working_tree.files.contains(file)) {
    return Err("pathspec '\{file}' did not match any files")
  }
  let new_wt_files = copy_file_map(state.working_tree.files)
  new_wt_files.remove(file)
  let new_staging = copy_file_map(state.staging_area.files)
  new_staging[file] = @model.FileContent::empty()
  Ok({
    working_tree: { files: new_wt_files },
    staging_area: { files: new_staging },
    repository: state.repository,
    next_commit_seq: state.next_commit_seq,
  })
}

///|
pub fn apply(
  state : @model.GitState,
  op : @model.Operation,
) -> Result[@model.GitState, String] {
  match op {
    Add(file) => apply_add(state, file)
    Commit => apply_commit(state)
    ResetSoft(n) => apply_reset_soft(state, n)
    ResetMixed(n) => apply_reset_mixed(state, n)
    ResetHard(n) => apply_reset_hard(state, n)
    Restore(file) => apply_restore(state, file)
    Checkout(file) => apply_restore(state, file)
    Rm(file) => apply_rm(state, file)
  }
}

///|
pub fn execute_all(
  initial : @model.GitState,
  ops : Array[@model.Operation],
) -> Result[@model.GitState, String] {
  let mut state = initial
  for op in ops {
    match apply(state, op) {
      Ok(next) => state = next
      Err(e) => return Err(e)
    }
  }
  Ok(state)
}
