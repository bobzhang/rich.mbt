///|
/// Replace the random ids of terminal hyperlinks.
fn normalize_links(s : String) -> String {
  let re = @regex.compile("id=[\\d\\.\\-]*?;.*?\u{1b}") catch {
    _ => abort("regex")
  }
  re.replace_all(s, _ => "id=0;foo\u{1b}") catch {
    _ => s
  }
}

///|
/// Run an oracle case.
fn run_case(
  args : Array[String],
  stdin : String,
  width : Int,
  tty : Bool,
) -> @cli.Output {
  let files : Map[String, String] = Map::from_array(fixtures)
  let environ = { "COLUMNS": width.to_string(), "COLORTERM": "truecolor" }
  @cli.run(args, files~, stdin~, environ~, stdout_isatty=tty, stderr_isatty=tty)
}

///|
test "rich-cli oracle" {
  let failures = []
  for case in oracle_cases {
    let (name, args, stdin, width, tty, stdout, stderr, code, exports) = case
    let output = run_case(args, stdin, width, tty)
    if normalize_links(output.stdout) != normalize_links(stdout) ||
      output.stderr != stderr ||
      output.exit_code != code ||
      output.exports.length() != exports.length() {
      failures.push(name)
      continue
    }
    for i, exported in exports {
      if output.exports[i].path != exported.0 ||
        output.exports[i].contents != exported.1 {
        failures.push("\{name} (export \{exported.0})")
      }
    }
  }
  debug_inspect(failures, content="[]")
}
