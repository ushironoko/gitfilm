///|
fn run(args : Array[String]) -> Result[String, String] {
  let parsed = match @parser.parse_args(args) {
    Ok(p) => p
    Err(e) => return Err(e)
  }
  let file_contents : Map[String, @model.FileContent] = {}
  for path in parsed.file_paths {
    try {
      let content = @fs.read_file_to_string(path)
      file_contents[path] = @model.FileContent::from_string(content)
    } catch {
      e => return Err("Cannot read file '\{path}': \{e}")
    }
  }
  let initial_state : @model.GitState = {
    working_tree: { files: file_contents },
    staging_area: { files: {} },
    repository: { commits: [], head: -1 },
    next_commit_seq: 1,
  }
  let final_state = match @emulator.execute_all(
      initial_state, parsed.operations,
    ) {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  Ok(
    @renderer.render_comparison(initial_state, final_state, parsed.operations),
  )
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
