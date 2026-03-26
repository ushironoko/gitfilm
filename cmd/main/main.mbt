///|
fn run(args : Array[String]) -> Result[String, String] {
  if @parser.should_show_help(args) {
    return Ok(@parser.format_help())
  }
  let parsed = match @parser.parse_args(args) {
    Ok(p) => p
    Err(e) => return Err(e)
  }
  if parsed.execute {
    match @executor.execute(parsed.operations) {
      Ok(log) => Ok(log)
      Err(e) => Err(e)
    }
  } else {
    match @executor.simulate(parsed.operations) {
      Ok(result) =>
        Ok(@renderer.render_from_sim_result(result, parsed.operations))
      Err(e) => Err(e)
    }
  }
}

///|
fn main {
  let args = @sys.get_cli_args()
  match run(args) {
    Ok(output) => println(output)
    Err(e) => {
      println("Error: \{e}")
      @sys.exit(1)
    }
  }
}
