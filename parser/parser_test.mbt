///|
test "parse_operation: all valid patterns" {
  inspect(
    @parser.parse_operation("add main.rs"),
    content=(
      #|Ok(Add("main.rs"))
    ),
  )
  inspect(
    @parser.parse_operation("add ."),
    content=(
      #|Ok(Add("."))
    ),
  )
  inspect(
    @parser.parse_operation("commit"),
    content=(
      #|Ok(Commit(None))
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
test "parse_operation: commit with message" {
  inspect(
    @parser.parse_operation("commit -m 'initial commit'"),
    content=(
      #|Ok(Commit(Some("initial commit")))
    ),
  )
  inspect(
    @parser.parse_operation("commit -m init"),
    content=(
      #|Ok(Commit(Some("init")))
    ),
  )
}

///|
test "tokenize: quotes handling" {
  inspect(
    @parser.tokenize("commit -m 'initial commit'"),
    content=(
      #|["commit", "-m", "initial commit"]
    ),
  )
  inspect(
    @parser.tokenize("add 'my file.rs'"),
    content=(
      #|["add", "my file.rs"]
    ),
  )
  inspect(
    @parser.tokenize("commit -m \"hello world\""),
    content=(
      #|["commit", "-m", "hello world"]
    ),
  )
  inspect(
    @parser.tokenize("simple command"),
    content=(
      #|["simple", "command"]
    ),
  )
}

///|
test "parse_args: basic usage" {
  inspect(
    @parser.parse_args(["gitfilm", "add main.rs", "commit"]),
    content=(
      #|Ok({operations: [Add("main.rs"), Commit(None)], execute: false, output_json: false})
    ),
  )
}

///|
test "parse_args: with --execute flag" {
  inspect(
    @parser.parse_args([
      "gitfilm", "add main.rs", "commit -m 'init'", "--execute",
    ]),
    content=(
      #|Ok({operations: [Add("main.rs"), Commit(Some("init"))], execute: true, output_json: false})
    ),
  )
}

///|
test "parse_args: --execute with Commit(None) is error" {
  inspect(
    @parser.parse_args(["gitfilm", "add main.rs", "commit", "--execute"]),
    content=(
      #|Err("--execute requires commit message: use 'commit -m \"message\"'")
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
test "parse_args: error cases" {
  inspect(
    @parser.parse_args(["gitfilm"]),
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
    @parser.should_show_help(["gitfilm", "add .", "--help"]),
    content="true",
  )
}

///|
test "should_show_help: normal args without help" {
  inspect(@parser.should_show_help(["gitfilm", "add main.rs"]), content="false")
}

///|
test "parse_args: with --output-json flag" {
  inspect(
    @parser.parse_args(["gitfilm", "add main.rs", "commit", "--output-json"]),
    content=(
      #|Ok({operations: [Add("main.rs"), Commit(None)], execute: false, output_json: true})
    ),
  )
}

///|
test "parse_args: --output-json with --execute is error" {
  inspect(
    @parser.parse_args([
      "gitfilm", "add main.rs", "commit -m 'init'", "--output-json", "--execute",
    ]),
    content=(
      #|Err("--output-json cannot be used with --execute")
    ),
  )
}
