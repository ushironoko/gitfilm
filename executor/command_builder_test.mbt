///|
test "to_git_args: all operations" {
  inspect(
    @executor.to_git_args(@model.Operation::Add("main.rs")),
    content=(
      #|{args: ["add", "main.rs"]}
    ),
  )
  inspect(
    @executor.to_git_args(@model.Operation::Commit(Some("init"))),
    content=(
      #|{args: ["commit", "-m", "init"]}
    ),
  )
  inspect(
    @executor.to_git_args(@model.Operation::Commit(None)),
    content=(
      #|{args: ["commit", "--allow-empty-message", "-m", ""]}
    ),
  )
  inspect(
    @executor.to_git_args(@model.Operation::ResetSoft(1)),
    content=(
      #|{args: ["reset", "--soft", "HEAD~1"]}
    ),
  )
  inspect(
    @executor.to_git_args(@model.Operation::ResetMixed(2)),
    content=(
      #|{args: ["reset", "--mixed", "HEAD~2"]}
    ),
  )
  inspect(
    @executor.to_git_args(@model.Operation::ResetHard(1)),
    content=(
      #|{args: ["reset", "--hard", "HEAD~1"]}
    ),
  )
  inspect(
    @executor.to_git_args(@model.Operation::Restore("main.rs")),
    content=(
      #|{args: ["restore", "main.rs"]}
    ),
  )
  inspect(
    @executor.to_git_args(@model.Operation::Checkout("main.rs")),
    content=(
      #|{args: ["checkout", "--", "main.rs"]}
    ),
  )
  inspect(
    @executor.to_git_args(@model.Operation::Rm("main.rs")),
    content=(
      #|{args: ["rm", "main.rs"]}
    ),
  )
}
