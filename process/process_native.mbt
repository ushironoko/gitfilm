///|
#borrow(program, cwd, args_joined, separator)
extern "C" fn gitfilm_exec_ffi(
  program : Bytes,
  cwd : Bytes,
  args_joined : Bytes,
  separator : Bytes,
) -> Bytes = "gitfilm_exec"

///|
extern "C" fn gitfilm_last_exit_code_ffi() -> Int = "gitfilm_last_exit_code"
