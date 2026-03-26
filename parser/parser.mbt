///|
pub(all) struct ParsedInput {
  operations : Array[@model.Operation]
  execute : Bool
} derive(Show)

///|
fn parse_head_ref(s : String) -> Result[Int, String] {
  if s == "HEAD" {
    Ok(0)
  } else if s.has_prefix("HEAD~") {
    try {
      let n_str = s[5:].to_string()
      let n = @strconv.parse_int(n_str)
      if n > 0 {
        Ok(n)
      } else {
        Err("Invalid HEAD reference: \{s}")
      }
    } catch {
      _ => Err("Invalid HEAD reference: \{s}")
    }
  } else {
    Err("Invalid HEAD reference: \{s}")
  }
}

///|
pub fn tokenize(s : String) -> Array[String] {
  let tokens : Array[String] = []
  let buf = StringBuilder::new()
  let mut in_single = false
  let mut in_double = false
  for c in s {
    if in_single {
      if c == '\'' {
        in_single = false
      } else {
        buf.write_char(c)
      }
    } else if in_double {
      if c == '"' {
        in_double = false
      } else {
        buf.write_char(c)
      }
    } else if c == '\'' {
      in_single = true
    } else if c == '"' {
      in_double = true
    } else if c == ' ' {
      let token = buf.to_string()
      if token != "" {
        tokens.push(token)
      }
      buf.reset()
    } else {
      buf.write_char(c)
    }
  }
  let last = buf.to_string()
  if last != "" {
    tokens.push(last)
  }
  tokens
}

///|
pub fn parse_operation(s : String) -> Result[@model.Operation, String] {
  let tokens = tokenize(s)
  match tokens {
    ["add", file, ..] => Ok(@model.Operation::Add(file))
    ["commit"] => Ok(@model.Operation::Commit(None))
    ["commit", "-m", .. rest] if rest.length() > 0 => {
      let msg = rest.join(" ")
      Ok(@model.Operation::Commit(Some(msg)))
    }
    ["reset", "--soft", head_ref, ..] =>
      parse_head_ref(head_ref).map(fn(n) { @model.Operation::ResetSoft(n) })
    ["reset", "--mixed", head_ref, ..] =>
      parse_head_ref(head_ref).map(fn(n) { @model.Operation::ResetMixed(n) })
    ["reset", "--hard", head_ref, ..] =>
      parse_head_ref(head_ref).map(fn(n) { @model.Operation::ResetHard(n) })
    ["reset", head_ref, ..] =>
      parse_head_ref(head_ref).map(fn(n) { @model.Operation::ResetMixed(n) })
    ["restore", file, ..] => Ok(@model.Operation::Restore(file))
    ["checkout", "--", file, ..] => Ok(@model.Operation::Checkout(file))
    ["rm", file, ..] => Ok(@model.Operation::Rm(file))
    _ => Err("Unknown operation: \{s}")
  }
}

///|
pub fn should_show_help(args : Array[String]) -> Bool {
  let skip_args = args[1:]
  if skip_args.is_empty() {
    return true
  }
  for a in skip_args {
    if a == "--help" || a == "-h" {
      return true
    }
  }
  false
}

///|
pub fn parse_args(args : Array[String]) -> Result[ParsedInput, String] {
  let skip_args = args[1:]
  let op_strings : Array[String] = []
  let mut execute = false
  for a in skip_args {
    if a == "--execute" {
      execute = true
    } else {
      op_strings.push(a)
    }
  }
  if op_strings.is_empty() {
    return Err("At least one operation is required")
  }
  let operations : Array[@model.Operation] = []
  for s in op_strings {
    match parse_operation(s) {
      Ok(op) => operations.push(op)
      Err(e) => return Err(e)
    }
  }
  if execute {
    for op in operations {
      match op {
        Commit(None) =>
          return Err(
            "--execute requires commit message: use 'commit -m \"message\"'",
          )
        _ => ()
      }
    }
  }
  Ok({ operations, execute })
}
