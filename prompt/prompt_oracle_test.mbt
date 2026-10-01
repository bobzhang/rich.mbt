// Differential cases computed with upstream Rich 15.0.0 (truecolor
// terminal console, responses read from an `io.StringIO` stream).

///|
fn term_console() -> (@rich.Console, @rich.StringIO) raise {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    file~,
    width=80,
    color_system=Some("truecolor"),
    force_terminal=true,
    legacy_windows=false,
    environ={},
  )
  (console, file)
}

///|
test "oracle: case insensitive choice returns the original choice" {
  let (console, file) = term_console()
  let r = @prompt.Prompt::ask(
    "Enter a [b]fruit[/b]",
    console~,
    choices=["apple", "Orange"],
    default="apple",
    case_sensitive=false,
    stream=@prompt.InputStream::new("x\n ORANGE \n"),
  )
  assert_eq(r, "Orange")
  assert_eq(
    file.getvalue(),
    "Enter a \u{1b}[1mfruit\u{1b}[0m \u{1b}[1;35m[apple/Orange]\u{1b}[0m \u{1b}[1;36m(apple)\u{1b}[0m: \u{1b}[31mPlease select one of the available options\u{1b}[0m\nEnter a \u{1b}[1mfruit\u{1b}[0m \u{1b}[1;35m[apple/Orange]\u{1b}[0m \u{1b}[1;36m(apple)\u{1b}[0m: ",
  )
}

///|
test "oracle: int prompt with default and emoji" {
  let (console, file) = term_console()
  let r = @prompt.IntPrompt::ask(
    ":rocket: number",
    console~,
    default=5,
    stream=@prompt.InputStream::new("1.5\n+1_0\n"),
  )
  assert_eq(r, 10)
  assert_eq(
    file.getvalue(),
    "🚀 number \u{1b}[1;36m(5)\u{1b}[0m: \u{1b}[31mPlease enter a valid integer number\u{1b}[0m\n🚀 number \u{1b}[1;36m(5)\u{1b}[0m: ",
  )
  let (console, file) = term_console()
  let r = @prompt.IntPrompt::ask(
    "n",
    console~,
    stream=@prompt.InputStream::new("0x10\n010\n"),
  )
  assert_eq(r, 10)
  assert_eq(
    file.getvalue(),
    "n: \u{1b}[31mPlease enter a valid integer number\u{1b}[0m\nn: ",
  )
}

///|
test "oracle: float prompt" {
  // end of stream -> default
  let (console, file) = term_console()
  let r = @prompt.FloatPrompt::ask(
    "temp",
    console~,
    default=1.0,
    stream=@prompt.InputStream::new("abc\n"),
  )
  assert_eq(r, 1.0)
  assert_eq(
    file.getvalue(),
    "temp \u{1b}[1;36m(1.0)\u{1b}[0m: \u{1b}[31mPlease enter a number\u{1b}[0m\ntemp \u{1b}[1;36m(1.0)\u{1b}[0m: ",
  )
  let (console, file) = term_console()
  let r = @prompt.FloatPrompt::ask(
    "temp",
    console~,
    default=1.0,
    stream=@prompt.InputStream::new("abc\n 2.5e1\n"),
  )
  assert_eq(r, 25.0)
  assert_eq(
    file.getvalue(),
    "temp \u{1b}[1;36m(1.0)\u{1b}[0m: \u{1b}[31mPlease enter a number\u{1b}[0m\ntemp \u{1b}[1;36m(1.0)\u{1b}[0m: ",
  )
}

///|
test "oracle: confirm with a Text prompt and hidden choices" {
  let (console, file) = term_console()
  let r = @prompt.Confirm::ask(
    @rich.Text::new(text="Go?", style="red"),
    console~,
    default=false,
    show_choices=false,
    stream=@prompt.InputStream::new(""),
  )
  assert_eq(r, false)
  assert_eq(
    file.getvalue(),
    "\u{1b}[31mGo? \u{1b}[0m\u{1b}[1;36m(n)\u{1b}[0m\u{1b}[31m: \u{1b}[0m",
  )
  let (console, file) = term_console()
  let r = @prompt.Confirm::ask(
    "ok",
    console~,
    choices=["oui", "non"],
    stream=@prompt.InputStream::new(" NON \n"),
  )
  assert_eq(r, false)
  assert_eq(file.getvalue(), "ok \u{1b}[1;35m[oui/non]\u{1b}[0m: ")
}

///|
test "oracle: show_default=false, int choices, empty line" {
  let (console, file) = term_console()
  let r = @prompt.Prompt::ask(
    "name",
    console~,
    default="x",
    show_default=false,
    choices=["a", "b"],
    stream=@prompt.InputStream::new("c\na\n"),
  )
  assert_eq(r, "a")
  assert_eq(
    file.getvalue(),
    "name \u{1b}[1;35m[a/b]\u{1b}[0m: \u{1b}[31mPlease select one of the available options\u{1b}[0m\nname \u{1b}[1;35m[a/b]\u{1b}[0m: ",
  )
  let (console, file) = term_console()
  let r = @prompt.IntPrompt::ask(
    "n",
    console~,
    choices=["1", "2"],
    stream=@prompt.InputStream::new("3\n2\n"),
  )
  assert_eq(r, 2)
  assert_eq(
    file.getvalue(),
    "n \u{1b}[1;35m[1/2]\u{1b}[0m: \u{1b}[31mPlease select one of the available options\u{1b}[0m\nn \u{1b}[1;35m[1/2]\u{1b}[0m: ",
  )
  // a stream line "\n" is not the empty string: no default -> ""
  let (console, file) = term_console()
  let r = @prompt.Prompt::ask(
    "n",
    console~,
    stream=@prompt.InputStream::new("\n"),
  )
  assert_eq(r, "")
  assert_eq(file.getvalue(), "n: ")
}

///|
test "injectable input function and custom process_response" {
  let (console, file) = term_console()
  let answers = ["", "7", "42"]
  let seen : Array[String] = []
  let get_input : @prompt.InputFn = (_console, prompt, password, _stream) => {
    seen.push("\{prompt.plain()}|\{password}")
    answers.remove(0)
  }
  let p = @prompt.IntPrompt::new("Pick", console~, password=true, get_input~)
  p.process_response_fn = Some((p, value) => {
    let n = p.convert_response(value)
    if n < 10 {
      raise @prompt.InvalidResponse(Str("[red]too small"))
    }
    n
  })
  assert_eq(p.call(), 42)
  assert_eq(seen, ["Pick: |true", "Pick: |true", "Pick: |true"])
  assert_eq(
    file.getvalue(),
    "\u{1b}[31mPlease enter a valid integer number\u{1b}[0m\n\u{1b}[31mtoo small\u{1b}[0m\n",
  )
  assert_eq(p.make_prompt(default=3).plain(), "Pick (3): ")
}

///|
test "InputStream readline" {
  let s = @prompt.InputStream::new("a\nbc\n\nd")
  assert_eq(s.readline(), "a\n")
  assert_eq(s.readline(), "bc\n")
  assert_eq(s.readline(), "\n")
  assert_eq(s.readline(), "d")
  assert_eq(s.readline(), "")
}
