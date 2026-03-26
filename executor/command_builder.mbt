///|
pub fn to_git_args(op : @model.Operation) -> @model.GitCommand {
  match op {
    Add(file) => { args: ["add", file] }
    Commit(Some(msg)) => { args: ["commit", "-m", msg] }
    Commit(None) => { args: ["commit", "--allow-empty-message", "-m", ""] }
    ResetSoft(n) => { args: ["reset", "--soft", "HEAD~\{n}"] }
    ResetMixed(n) => { args: ["reset", "--mixed", "HEAD~\{n}"] }
    ResetHard(n) => { args: ["reset", "--hard", "HEAD~\{n}"] }
    Restore(file) => { args: ["restore", file] }
    Checkout(file) => { args: ["checkout", "--", file] }
    Rm(file) => { args: ["rm", file] }
  }
}
