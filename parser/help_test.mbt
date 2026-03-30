///|
test "format_help: generates complete help text" {
  inspect(
    @parser.format_help(),
    content=(
      #|gitfilm - Emulate git operations and visualize state transitions
      #|
      #|Usage:
      #|  gitfilm '<op1>' '<op2>' ...
      #|
      #|Options:
      #|  --execute      Execute git commands after simulation succeeds
      #|  --output-json  Output simulation result as JSON (simulation mode only)
      #|  --help, -h     Show this help message
      #|
      #|Operations:
      #|  add <file>            Stage a file from the working tree
      #|  add .                 Stage all modified and untracked files
      #|  commit                Create a commit from staged files
      #|  commit -m '<msg>'     Create a commit with the given message
      #|  reset --soft HEAD~N   Move HEAD back N commits, keep changes staged
      #|  reset --mixed HEAD~N  Move HEAD back N commits, unstage changes (default)
      #|  reset --hard HEAD~N   Move HEAD back N commits, discard all changes
      #|  restore <file>        Discard working tree changes for a file
      #|  checkout -- <file>    Discard working tree changes (legacy syntax)
      #|  rm <file>             Remove a file and stage the deletion
      #|
      #|Example:
      #|  gitfilm 'add .' "commit -m 'init'" 'reset --soft HEAD~1'
      #|
    ),
  )
}

///|
test "operation_defs: all syntax examples are parseable" {
  for def in @parser.operation_defs() {
    let concrete = def.syntax
      .replace(old="<file>", new="test.rs")
      .replace(old="HEAD~N", new="HEAD~1")
    assert_true(@parser.parse_operation(concrete) is Ok(_))
  }
}
