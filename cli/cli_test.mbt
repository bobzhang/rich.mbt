///|
let env : Map[String, String] = { "COLUMNS": "40" }

///|
test "parse_args" {
  guard @cli.parse_args(["x.py", "-ng", "-w30", "--theme=monokai"], environ=env)
    is Run(options) else {
    fail("expected options")
  }
  inspect(options.resource, content="x.py")
  inspect(options.line_numbers && options.guides, content="true")
  inspect(options.width, content="30")
  inspect(options.theme, content="monokai")
  debug_inspect(options.input(), content="File(\"x.py\")")
  debug_inspect(
    @cli.parse_args(["--print=x"], environ=env),
    content=(
      #|UsageError("Option '--print' does not take a value.", usage=false)
    ),
  )
  debug_inspect(
    @cli.parse_args(["-z"], environ=env),
    content=(
      #|UsageError("No such option '-z'.", usage=true)
    ),
  )
  debug_inspect(
    @cli.parse_args(["a", "b", "c"], environ=env),
    content=(
      #|UsageError("Got unexpected extra arguments (b c)", usage=true)
    ),
  )
  debug_inspect(
    @cli.parse_args(["--help", "-w", "x"], environ=env),
    content="Help",
  )
}

///|
test "RICH_THEME sets the default theme" {
  guard @cli.parse_args(["x.py"], environ={ "RICH_THEME": "dracula" })
    is Run(options) else {
    fail("expected options")
  }
  inspect(options.theme, content="dracula")
  guard @cli.parse_args(["x.py", "--theme", "monokai"], environ={
      "RICH_THEME": "dracula",
    })
    is Run(options) else {
    fail("expected options")
  }
  inspect(options.theme, content="monokai")
}

///|
test "input" {
  fn input(args : Array[String]) -> @cli.Input raise {
    guard @cli.parse_args(args, environ=env) is Run(options) else {
      fail("expected options")
    }
    options.input()
  }

  debug_inspect(input(["hello", "-p"]), content="NoInput")
  debug_inspect(input(["-", "-p"]), content="Stdin")
  debug_inspect(input(["-", "-u"]), content="Stdin")
  debug_inspect(input(["-", "-m"]), content="Stdin")
  debug_inspect(input([]), content="NoInput")
  debug_inspect(input(["https://example.com/a.md"]), content="NoInput")
  debug_inspect(input(["data.csv"]), content="File(\"data.csv\")")
  debug_inspect(input(["data.csv", "-v"]), content="NoInput")
}

///|
test "unsupported features" {
  let out = @cli.run(["https://example.com/README.md"], environ=env)
  inspect(out.exit_code, content="255")
  inspect(
    out.stderr,
    content=(
      #|unable to read 
      #|https://example.com/README.md: fetching 
      #|URLs is not supported
      #|
    ),
  )
  let out = @cli.run(["--inspect", "1+1"], environ=env)
  inspect(
    out.stderr,
    content=(
      #|unable to eval '1+1': --inspect (Python 
      #|objects) is not supported
      #|
    ),
  )
}

///|
test "rst is shown as highlighted source" {
  let out = @cli.run(
    ["doc.rst"],
    files={ "doc.rst": "Title\n=====\n\nText.\n" },
    environ=env,
  )
  inspect(
    out.stdout,
    content=(
      #|Title
      #|=====
      #|
      #|Text.
      #|
      #|
    ),
  )
}

///|
test "pager" {
  let out = @cli.run(
    ["x.py", "--pager", "-n"],
    files={ "x.py": "print(1)\n" },
    environ=env,
  )
  inspect(out.stdout, content="")
  inspect(
    out.pager.unwrap_or("<none>"),
    content=(
      #|  1 print(1)                           
      #|  2                                    
      #|
    ),
  )
}

///|
test "error_text" {
  inspect(
    @cli.error_text(
      "failed to save HTML",
      error="[Errno 2] No such file or directory: 'nodir/x.html'",
      environ=env,
    ),
    content=(
      #|failed to save HTML: [Errno 2] No such 
      #|file or directory: 'nodir/x.html'
      #|
    ),
  )
}
