///|
test "FileContent::empty" {
  inspect(
    @model.FileContent::empty(),
    content=(
      #|{lines: []}
    ),
  )
}

///|
test "FileContent::from_string multiline" {
  inspect(
    @model.FileContent::from_string("line1\nline2\nline3"),
    content=(
      #|{lines: ["line1", "line2", "line3"]}
    ),
  )
}

///|
test "FileContent::from_string single line" {
  inspect(
    @model.FileContent::from_string("hello"),
    content=(
      #|{lines: ["hello"]}
    ),
  )
}

///|
test "FileContent::is_empty" {
  inspect(
    @model.FileContent::empty().is_empty(),
    content=(
      #|true
    ),
  )
  inspect(
    @model.FileContent::from_string("hello").is_empty(),
    content=(
      #|false
    ),
  )
}

///|
test "diff_summary: partial change" {
  let old = @model.FileContent::from_string("line1\nline2\nline3")
  let new_ = @model.FileContent::from_string("line1\nline4\nline3")
  inspect(
    @model.diff_summary(old, new_),
    content=(
      #|{added: 1, removed: 1}
    ),
  )
}

///|
test "diff_summary: all added" {
  let old = @model.FileContent::empty()
  let new_ = @model.FileContent::from_string("line1\nline2")
  inspect(
    @model.diff_summary(old, new_),
    content=(
      #|{added: 2, removed: 0}
    ),
  )
}

///|
test "diff_summary: all removed" {
  let old = @model.FileContent::from_string("line1\nline2")
  let new_ = @model.FileContent::empty()
  inspect(
    @model.diff_summary(old, new_),
    content=(
      #|{added: 0, removed: 2}
    ),
  )
}

///|
test "generate_commit_id" {
  inspect(
    @model.generate_commit_id(1),
    content=(
      #|c000001
    ),
  )
  inspect(
    @model.generate_commit_id(42),
    content=(
      #|c000042
    ),
  )
  inspect(
    @model.generate_commit_id(999999),
    content=(
      #|c999999
    ),
  )
}

///|
test "Repository::head_commit empty" {
  let repo : @model.Repository = { commits: [], head: -1 }
  inspect(
    repo.head_commit(),
    content=(
      #|None
    ),
  )
}

///|
test "Repository::head_commit with commit" {
  let commit : @model.Commit = {
    id: "c000001",
    message: (None : String?),
    files: {},
    parent: (None : String?),
  }
  let repo : @model.Repository = { commits: [commit], head: 0 }
  inspect(
    repo.head_commit(),
    content=(
      #|Some({id: "c000001", message: None, files: {}, parent: None})
    ),
  )
}

///|
test "Repository::get_file_at_head found" {
  let files : Map[String, @model.FileContent] = {}
  files["test.rs"] = { lines: ["hello"] }
  let commit : @model.Commit = {
    id: "c000001",
    message: (None : String?),
    files,
    parent: (None : String?),
  }
  let repo : @model.Repository = { commits: [commit], head: 0 }
  inspect(
    repo.get_file_at_head("test.rs"),
    content=(
      #|{lines: ["hello"]}
    ),
  )
}

///|
test "Repository::get_file_at_head missing" {
  let commit : @model.Commit = {
    id: "c000001",
    message: (None : String?),
    files: {},
    parent: (None : String?),
  }
  let repo : @model.Repository = { commits: [commit], head: 0 }
  inspect(
    repo.get_file_at_head("missing.rs"),
    content=(
      #|{lines: []}
    ),
  )
}
