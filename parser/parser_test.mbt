///|
test "parse_operation: all valid patterns" {
  inspect(
    @parser.parse_operation("add main.rs"),
    content=(
      #|Ok(Add("main.rs"))
    ),
  )
  inspect(
    @parser.parse_operation("commit"),
    content=(
      #|Ok(Commit)
    ),
  )
  inspect(
    @parser.parse_operation("reset --soft HEAD~1"),
    content=(
      #|Ok(ResetSoft(1))
    ),
  )
  inspect(
    @parser.parse_operation("reset --soft HEAD~3"),
    content=(
      #|Ok(ResetSoft(3))
    ),
  )
  inspect(
    @parser.parse_operation("reset --mixed HEAD~1"),
    content=(
      #|Ok(ResetMixed(1))
    ),
  )
  inspect(
    @parser.parse_operation("reset HEAD~1"),
    content=(
      #|Ok(ResetMixed(1))
    ),
  )
  inspect(
    @parser.parse_operation("reset --hard HEAD~1"),
    content=(
      #|Ok(ResetHard(1))
    ),
  )
  inspect(
    @parser.parse_operation("restore main.rs"),
    content=(
      #|Ok(Restore("main.rs"))
    ),
  )
  inspect(
    @parser.parse_operation("checkout -- main.rs"),
    content=(
      #|Ok(Checkout("main.rs"))
    ),
  )
  inspect(
    @parser.parse_operation("rm main.rs"),
    content=(
      #|Ok(Rm("main.rs"))
    ),
  )
}

///|
test "parse_operation: error cases" {
  inspect(
    @parser.parse_operation("merge main"),
    content=(
      #|Err("Unknown operation: merge main")
    ),
  )
  inspect(
    @parser.parse_operation("reset --soft HEAD~abc"),
    content=(
      #|Err("Invalid HEAD reference: HEAD~abc")
    ),
  )
  inspect(
    @parser.parse_operation("reset --soft HEAD~0"),
    content=(
      #|Err("Invalid HEAD reference: HEAD~0")
    ),
  )
}

///|
test "parse_args: basic usage" {
  let args = ["git-film", "--files", "main.rs,lib.rs", "add main.rs", "commit"]
  inspect(
    @parser.parse_args(args),
    content=(
      #|Ok({file_paths: ["main.rs", "lib.rs"], operations: [Add("main.rs"), Commit]})
    ),
  )
}

///|
test "parse_args: error cases" {
  inspect(
    @parser.parse_args(["git-film", "add main.rs"]),
    content=(
      #|Err("--files is required")
    ),
  )
  inspect(
    @parser.parse_args(["git-film", "--files", "main.rs"]),
    content=(
      #|Err("At least one operation is required")
    ),
  )
}

///|
test "should_show_help: no args" {
  inspect(@parser.should_show_help(["gitfilm"]), content="true")
}

///|
test "should_show_help: --help flag" {
  inspect(@parser.should_show_help(["gitfilm", "--help"]), content="true")
}

///|
test "should_show_help: -h flag" {
  inspect(@parser.should_show_help(["gitfilm", "-h"]), content="true")
}

///|
test "should_show_help: --help mixed with other args" {
  inspect(
    @parser.should_show_help(["gitfilm", "--files", "main.rs", "--help"]),
    content="true",
  )
}

///|
test "should_show_help: normal args without help" {
  inspect(
    @parser.should_show_help(["gitfilm", "--files", "main.rs", "add main.rs"]),
    content="false",
  )
}
