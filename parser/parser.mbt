///|
pub(all) struct ParsedInput {
  file_paths : Array[String]
  operations : Array[@model.Operation]
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
pub fn parse_operation(s : String) -> Result[@model.Operation, String] {
  let tokens = s.split(" ")
    .map(fn(sv) { sv.to_string() })
    .filter(fn(t) { t != "" })
    .collect()
  match tokens {
    ["add", file, ..] => Ok(@model.Operation::Add(file))
    ["commit", ..] => Ok(@model.Operation::Commit)
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
pub fn parse_args(args : Array[String]) -> Result[ParsedInput, String] {
  let skip_args = args[1:]
  let mut file_paths : Array[String] = []
  let op_strings : Array[String] = []
  let mut i = 0
  while i < skip_args.length() {
    if skip_args[i] == "--files" {
      if i + 1 >= skip_args.length() {
        return Err("--files requires a comma-separated file list")
      }
      file_paths = skip_args[i + 1]
        .split(",")
        .map(fn(sv) { sv.to_string() })
        .collect()
      i = i + 2
    } else {
      op_strings.push(skip_args[i])
      i = i + 1
    }
  }
  if file_paths.is_empty() {
    return Err("--files is required")
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
  Ok({ file_paths, operations })
}
