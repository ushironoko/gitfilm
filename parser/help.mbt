///|
pub(all) struct CliOption {
  names : Array[String]
  value_hint : String?
  description : String
  required : Bool
} derive(Show)

///|
pub(all) struct OperationDef {
  syntax : String
  description : String
} derive(Show)

///|
pub fn cli_options() -> Array[CliOption] {
  [
    {
      names: ["--execute"],
      value_hint: None,
      description: "Execute git commands after simulation succeeds",
      required: false,
    },
    {
      names: ["--output-json"],
      value_hint: None,
      description: "Output simulation result as JSON (simulation mode only)",
      required: false,
    },
    {
      names: ["--help", "-h"],
      value_hint: None,
      description: "Show this help message",
      required: false,
    },
  ]
}

///|
pub fn operation_defs() -> Array[OperationDef] {
  [
    { syntax: "add <file>", description: "Stage a file from the working tree" },
    { syntax: "add .", description: "Stage all modified and untracked files" },
    { syntax: "commit", description: "Create a commit from staged files" },
    {
      syntax: "commit -m '<msg>'",
      description: "Create a commit with the given message",
    },
    {
      syntax: "reset --soft HEAD~N",
      description: "Move HEAD back N commits, keep changes staged",
    },
    {
      syntax: "reset --mixed HEAD~N",
      description: "Move HEAD back N commits, unstage changes (default)",
    },
    {
      syntax: "reset --hard HEAD~N",
      description: "Move HEAD back N commits, discard all changes",
    },
    {
      syntax: "restore <file>",
      description: "Discard working tree changes for a file",
    },
    {
      syntax: "checkout -- <file>",
      description: "Discard working tree changes (legacy syntax)",
    },
    { syntax: "rm <file>", description: "Remove a file and stage the deletion" },
  ]
}

///|
fn format_option_label(opt : CliOption) -> String {
  let names_str = opt.names
    .iter()
    .fold(init="", fn(acc, name) {
      if acc == "" {
        name
      } else {
        acc + ", " + name
      }
    })
  match opt.value_hint {
    Some(hint) => names_str + " " + hint
    None => names_str
  }
}

///|
pub fn format_help() -> String {
  let buf = StringBuilder::new()
  buf.write_string(
    "gitfilm - Emulate git operations and visualize state transitions\n\n",
  )
  buf.write_string("Usage:\n")
  buf.write_string("  gitfilm '<op1>' '<op2>' ...\n\n")
  let options = cli_options()
  buf.write_string("Options:\n")
  let mut max_opt_width = 0
  let opt_labels : Array[String] = []
  for opt in options {
    let label = format_option_label(opt)
    opt_labels.push(label)
    if label.length() > max_opt_width {
      max_opt_width = label.length()
    }
  }
  for i, opt in options {
    let label = opt_labels[i]
    let padding = " ".repeat(max_opt_width - label.length() + 2)
    let suffix = if opt.required { " (required)" } else { "" }
    buf.write_string("  \{label}\{padding}\{opt.description}\{suffix}\n")
  }
  buf.write_string("\n")
  let ops = operation_defs()
  buf.write_string("Operations:\n")
  let mut max_op_width = 0
  for op in ops {
    if op.syntax.length() > max_op_width {
      max_op_width = op.syntax.length()
    }
  }
  for op in ops {
    let padding = " ".repeat(max_op_width - op.syntax.length() + 2)
    buf.write_string("  \{op.syntax}\{padding}\{op.description}\n")
  }
  buf.write_string("\n")
  buf.write_string("Example:\n")
  buf.write_string(
    "  gitfilm 'add .' \"commit -m 'init'\" 'reset --soft HEAD~1'\n",
  )
  buf.to_string()
}
