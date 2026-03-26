///|
test "validate_ops_commit_safety: reset within range passes" {
  let ops = [
    @model.Operation::Commit(Some("first")),
    Commit(Some("second")),
    ResetSoft(1),
  ]
  inspect(validate_ops_commit_safety(0, ops), content="Ok(())")
}

///|
test "validate_ops_commit_safety: reset exactly at root is rejected" {
  let ops = [@model.Operation::ResetHard(1)]
  let err =
    #|Err("step 1: --execute does not support resetting past the root commit")
  inspect(validate_ops_commit_safety(1, ops), content=err)
}

///|
test "validate_ops_commit_safety: reset past root after commits is rejected" {
  let ops : Array[@model.Operation] = [
    Add("a.rs"),
    Commit(Some("first")),
    Commit(Some("second")),
    ResetHard(3),
  ]
  let err =
    #|Err("step 4: --execute does not support resetting past the root commit")
  inspect(validate_ops_commit_safety(0, ops), content=err)
}

///|
test "validate_ops_commit_safety: chained resets within range" {
  let ops : Array[@model.Operation] = [ResetSoft(1), ResetMixed(1)]
  inspect(validate_ops_commit_safety(3, ops), content="Ok(())")
}

///|
test "validate_ops_commit_safety: chained resets exceed count" {
  let ops : Array[@model.Operation] = [ResetSoft(1), ResetMixed(2)]
  let err =
    #|Err("step 2: --execute does not support resetting past the root commit")
  inspect(validate_ops_commit_safety(3, ops), content=err)
}

///|
test "validate_ops_commit_safety: commit then partial reset passes" {
  let ops : Array[@model.Operation] = [Commit(Some("new")), ResetHard(1)]
  inspect(validate_ops_commit_safety(1, ops), content="Ok(())")
}

///|
test "validate_ops_commit_safety: commit then full reset is rejected" {
  let ops : Array[@model.Operation] = [Commit(Some("new")), ResetHard(2)]
  let err =
    #|Err("step 2: --execute does not support resetting past the root commit")
  inspect(validate_ops_commit_safety(1, ops), content=err)
}

///|
test "validate_ops_commit_safety: non-reset ops pass freely" {
  let ops : Array[@model.Operation] = [
    Add("a.rs"),
    Restore("a.rs"),
    Checkout("a.rs"),
    Rm("a.rs"),
  ]
  inspect(validate_ops_commit_safety(0, ops), content="Ok(())")
}

///|
test "validate_ops_commit_safety: zero initial commits skips reset check" {
  let ops = [@model.Operation::ResetSoft(1)]
  inspect(validate_ops_commit_safety(0, ops), content="Ok(())")
}

///|
test "validate_ops_commit_safety: mixed reset modes within range" {
  let ops : Array[@model.Operation] = [
    Commit(Some("a")),
    Commit(Some("b")),
    Commit(Some("c")),
    ResetSoft(1),
    Commit(Some("d")),
    ResetHard(1),
    ResetMixed(1),
  ]
  inspect(validate_ops_commit_safety(0, ops), content="Ok(())")
}

///|
test "validate_ops_commit_safety: mid-sequence rejection stops early" {
  let ops : Array[@model.Operation] = [
    Commit(Some("a")),
    ResetSoft(1),
    Commit(Some("b")),
  ]
  let err =
    #|Err("step 2: --execute does not support resetting past the root commit")
  inspect(validate_ops_commit_safety(0, ops), content=err)
}
