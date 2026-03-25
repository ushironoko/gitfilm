///|
test "format_help: generates complete help text" {
  inspect(@parser.format_help(), content=(
    #|gitfilm - Emulate git operations and visualize state transitions
    #|
    #|Usage:
    #|  gitfilm --files <file1>,<file2>,... '<op1>' '<op2>' ...
    #|
    #|Options:
    #|  --files <file1>,<file2>,...  Comma-separated list of files to include in the working tree (required)
    #|  --help, -h                   Show this help message
    #|
    #|Operations:
    #|  add <file>            Stage a file from the working tree
    #|  commit                Create a commit from staged files
    #|  reset --soft HEAD~N   Move HEAD back N commits, keep changes staged
    #|  reset --mixed HEAD~N  Move HEAD back N commits, unstage changes (default)
    #|  reset --hard HEAD~N   Move HEAD back N commits, discard all changes
    #|  restore <file>        Discard working tree changes for a file
    #|  checkout -- <file>    Discard working tree changes (legacy syntax)
    #|  rm <file>             Remove a file and stage the deletion
    #|
    #|Example:
    #|  gitfilm --files main.rs,lib.rs 'add main.rs' 'commit' 'reset --soft HEAD~1'
    #|
  ))
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
