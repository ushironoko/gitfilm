///|
fn gitfilm_exec_ffi(
  _program : Bytes,
  _cwd : Bytes,
  _args_joined : Bytes,
  _separator : Bytes,
) -> Bytes {
  abort("process execution is only supported on native target")
}

///|
fn gitfilm_last_exit_code_ffi() -> Int {
  abort("process execution is only supported on native target")
}
