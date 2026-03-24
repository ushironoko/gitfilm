///|
fn make_state(
  wt_files : Map[String, @model.FileContent],
  sa_files : Map[String, @model.FileContent],
  commits : Array[@model.Commit],
  head : Int
) -> @model.GitState {
  {
    working_tree: { files: wt_files },
    staging_area: { files: sa_files },
    repository: { commits, head },
    next_commit_seq: commits.length() + 1,
  }
}

///|
fn make_files(entries : Array[(String, String)]) -> Map[String, @model.FileContent] {
  let files : Map[String, @model.FileContent] = {}
  for entry in entries {
    files[entry.0] = @model.FileContent::from_string(entry.1)
  }
  files
}

///|
test "render: empty state" {
  let state = make_state({}, {}, [], -1)
  inspect(@renderer.render_state(state, "prev"), content=(
    #|=== prev ===
    #|[Working Tree]  (empty)
    #|[Staging Area]  (empty)
    #|[Repository]    (no commits)
    #|
  ))
}

///|
test "render: untracked files" {
  let state = make_state(
    make_files([("main.rs", "fn main() {}"), ("lib.rs", "pub fn add() {}")]),
    {},
    [],
    -1,
  )
  inspect(@renderer.render_state(state, "prev"), content=(
    #|=== prev ===
    #|[Working Tree]  lib.rs: untracked
    #|                main.rs: untracked
    #|[Staging Area]  (empty)
    #|[Repository]    (no commits)
    #|
  ))
}

///|
test "render: staged files" {
  let wt = make_files([("main.rs", "fn main() {}")])
  let sa = make_files([("main.rs", "fn main() {}")])
  let state = make_state(wt, sa, [], -1)
  inspect(@renderer.render_state(state, "after add"), content=(
    #|=== after add ===
    #|[Working Tree]  main.rs: clean
    #|[Staging Area]  main.rs: staged    (+1 -0)
    #|[Repository]    (no commits)
    #|
  ))
}

///|
test "render: committed files" {
  let wt = make_files([("main.rs", "fn main() {}")])
  let commit : @model.Commit = {
    id: "c000001",
    files: make_files([("main.rs", "fn main() {}")]),
    parent: (None : String?),
  }
  let state = make_state(wt, {}, [commit], 0)
  inspect(@renderer.render_state(state, "after commit"), content=(
    #|=== after commit ===
    #|[Working Tree]  main.rs: clean
    #|[Staging Area]  (empty)
    #|[Repository]    main.rs: committed (c000001)
    #|
  ))
}

///|
test "render: comparison prev/next" {
  let prev = make_state(
    make_files([("main.rs", "v1")]),
    {},
    [],
    -1,
  )
  let commit : @model.Commit = {
    id: "c000001",
    files: make_files([("main.rs", "v1")]),
    parent: (None : String?),
  }
  let next = make_state(
    make_files([("main.rs", "v1")]),
    {},
    [commit],
    0,
  )
  let ops = [@model.Operation::Add("main.rs"), @model.Operation::Commit]
  inspect(@renderer.render_comparison(prev, next, ops), content=(
    #|=== prev ===
    #|[Working Tree]  main.rs: untracked
    #|[Staging Area]  (empty)
    #|[Repository]    (no commits)
    #|
    #|=== next (after: Add("main.rs"), Commit) ===
    #|[Working Tree]  main.rs: clean
    #|[Staging Area]  (empty)
    #|[Repository]    main.rs: committed (c000001)
    #|
  ))
}

///|
test "render: full scenario add, commit, reset --soft" {
  let initial = make_state(
    make_files([("main.rs", "line1\nline2"), ("lib.rs", "pub fn x() {}")]),
    {},
    [],
    -1,
  )
  let ops = [
    @model.Operation::Add("main.rs"),
    @model.Operation::Add("lib.rs"),
    @model.Operation::Commit,
    @model.Operation::ResetSoft(1),
  ]
  let final_state = @emulator.execute_all(initial, ops).unwrap()
  inspect(@renderer.render_comparison(initial, final_state, ops), content=(
    #|=== prev ===
    #|[Working Tree]  lib.rs: untracked
    #|                main.rs: untracked
    #|[Staging Area]  (empty)
    #|[Repository]    (no commits)
    #|
    #|=== next (after: Add("main.rs"), Add("lib.rs"), Commit, ResetSoft(1)) ===
    #|[Working Tree]  lib.rs: clean
    #|                main.rs: clean
    #|[Staging Area]  lib.rs: staged    (+1 -0)
    #|                main.rs: staged    (+2 -0)
    #|[Repository]    (no commits)
    #|
  ))
}
