///|
fn make_initial_state(
  files : Map[String, @model.FileContent],
) -> @model.GitState {
  {
    working_tree: { files, },
    staging_area: { files: {} },
    repository: { commits: [], head: -1 },
    next_commit_seq: 1,
  }
}

///|
fn make_files(
  entries : Array[(String, String)],
) -> Map[String, @model.FileContent] {
  let files : Map[String, @model.FileContent] = {}
  for entry in entries {
    files[entry.0] = @model.FileContent::from_string(entry.1)
  }
  files
}

// --- scenario: add ---

///|
test "scenario: add stages file" {
  let state = make_initial_state(make_files([("main.rs", "fn main() {}")]))
  inspect(
    @emulator.apply(state, @model.Operation::Add("main.rs")),
    content=(
      #|Ok({working_tree: {files: {"main.rs": {lines: ["fn main() {}"]}}}, staging_area: {files: {"main.rs": {lines: ["fn main() {}"]}}}, repository: {commits: [], head: -1}, next_commit_seq: 1})
    ),
  )
}

///|
test "scenario: add non-existent file" {
  let state = make_initial_state({})
  inspect(
    @emulator.apply(state, @model.Operation::Add("missing.rs")),
    content=(
      #|Err("pathspec 'missing.rs' did not match any files")
    ),
  )
}

// --- scenario: add -> commit ---

///|
test "scenario: add then commit" {
  let state = make_initial_state(make_files([("main.rs", "fn main() {}")]))
  let s1 = @emulator.apply(state, @model.Operation::Add("main.rs")).unwrap()
  inspect(
    @emulator.apply(s1, @model.Operation::Commit),
    content=(
      #|Ok({working_tree: {files: {"main.rs": {lines: ["fn main() {}"]}}}, staging_area: {files: {}}, repository: {commits: [{id: "c000001", files: {"main.rs": {lines: ["fn main() {}"]}}, parent: None}], head: 0}, next_commit_seq: 2})
    ),
  )
}

///|
test "scenario: commit with empty staging" {
  let state = make_initial_state({})
  inspect(
    @emulator.apply(state, @model.Operation::Commit),
    content=(
      #|Err("nothing to commit, staging area is empty")
    ),
  )
}

// --- scenario: add -> commit -> reset --soft ---

///|
test "scenario: add, commit, reset --soft" {
  let state = make_initial_state(make_files([("main.rs", "v1")]))
  inspect(
    @emulator.execute_all(state, [
      @model.Operation::Add("main.rs"),
      @model.Operation::Commit,
      @model.Operation::ResetSoft(1),
    ]),
    content=(
      #|Ok({working_tree: {files: {"main.rs": {lines: ["v1"]}}}, staging_area: {files: {"main.rs": {lines: ["v1"]}}}, repository: {commits: [{id: "c000001", files: {"main.rs": {lines: ["v1"]}}, parent: None}], head: -1}, next_commit_seq: 2})
    ),
  )
}

// --- scenario: add -> commit -> reset --mixed ---

///|
test "scenario: add, commit, reset --mixed" {
  let state = make_initial_state(make_files([("main.rs", "v1")]))
  inspect(
    @emulator.execute_all(state, [
      @model.Operation::Add("main.rs"),
      @model.Operation::Commit,
      @model.Operation::ResetMixed(1),
    ]),
    content=(
      #|Ok({working_tree: {files: {"main.rs": {lines: ["v1"]}}}, staging_area: {files: {}}, repository: {commits: [{id: "c000001", files: {"main.rs": {lines: ["v1"]}}, parent: None}], head: -1}, next_commit_seq: 2})
    ),
  )
}

// --- scenario: add -> commit -> reset --hard ---

///|
test "scenario: add, commit, reset --hard" {
  let state = make_initial_state(make_files([("main.rs", "v1")]))
  inspect(
    @emulator.execute_all(state, [
      @model.Operation::Add("main.rs"),
      @model.Operation::Commit,
      @model.Operation::ResetHard(1),
    ]),
    content=(
      #|Ok({working_tree: {files: {}}, staging_area: {files: {}}, repository: {commits: [{id: "c000001", files: {"main.rs": {lines: ["v1"]}}, parent: None}], head: -1}, next_commit_seq: 2})
    ),
  )
}

// --- scenario: add -> commit -> restore ---

///|
test "scenario: add, commit, modify, restore" {
  let state = make_initial_state(make_files([("main.rs", "original")]))
  let s1 = @emulator.execute_all(state, [
    @model.Operation::Add("main.rs"),
    @model.Operation::Commit,
  ]).unwrap()
  // Simulate working tree modification after commit
  s1.working_tree.files["main.rs"] = @model.FileContent::from_string("modified")
  inspect(
    @emulator.apply(s1, @model.Operation::Restore("main.rs")),
    content=(
      #|Ok({working_tree: {files: {"main.rs": {lines: ["original"]}}}, staging_area: {files: {}}, repository: {commits: [{id: "c000001", files: {"main.rs": {lines: ["original"]}}, parent: None}], head: 0}, next_commit_seq: 2})
    ),
  )
}

///|
test "scenario: restore non-existent" {
  let state = make_initial_state({})
  inspect(
    @emulator.apply(state, @model.Operation::Restore("missing.rs")),
    content=(
      #|Err("pathspec 'missing.rs' did not match any files")
    ),
  )
}

// --- scenario: rm ---

///|
test "scenario: rm stages deletion" {
  let state = make_initial_state(make_files([("main.rs", "content")]))
  inspect(
    @emulator.apply(state, @model.Operation::Rm("main.rs")),
    content=(
      #|Ok({working_tree: {files: {}}, staging_area: {files: {"main.rs": {lines: []}}}, repository: {commits: [], head: -1}, next_commit_seq: 1})
    ),
  )
}

///|
test "scenario: rm non-existent" {
  let state = make_initial_state({})
  inspect(
    @emulator.apply(state, @model.Operation::Rm("missing.rs")),
    content=(
      #|Err("pathspec 'missing.rs' did not match any files")
    ),
  )
}

// --- scenario: full chain ---

///|
test "scenario: full chain add, commit, reset --soft" {
  let state = make_initial_state(
    make_files([("main.rs", "line1\nline2"), ("lib.rs", "pub fn add() {}")]),
  )
  inspect(
    @emulator.execute_all(state, [
      @model.Operation::Add("main.rs"),
      @model.Operation::Add("lib.rs"),
      @model.Operation::Commit,
      @model.Operation::ResetSoft(1),
    ]),
    content=(
      #|Ok({working_tree: {files: {"main.rs": {lines: ["line1", "line2"]}, "lib.rs": {lines: ["pub fn add() {}"]}}}, staging_area: {files: {"main.rs": {lines: ["line1", "line2"]}, "lib.rs": {lines: ["pub fn add() {}"]}}}, repository: {commits: [{id: "c000001", files: {"main.rs": {lines: ["line1", "line2"]}, "lib.rs": {lines: ["pub fn add() {}"]}}, parent: None}], head: -1}, next_commit_seq: 2})
    ),
  )
}

///|
test "scenario: chain stops on error" {
  let state = make_initial_state({})
  inspect(
    @emulator.execute_all(state, [
      @model.Operation::Add("missing.rs"),
      @model.Operation::Commit,
    ]),
    content=(
      #|Err("pathspec 'missing.rs' did not match any files")
    ),
  )
}
