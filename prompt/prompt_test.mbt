// Port of tests/test_prompt.py.

///|
/// Upstream `Console(file=io.StringIO())` (not a terminal, so no styles).
fn plain_console(
  markup? : Bool = true,
) -> (@rich.Console, @rich.StringIO) raise {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(file~, width=80, markup~, environ={})
  (console, file)
}

///|
test "prompt_str" {
  let (console, file) = plain_console()
  let name = @prompt.Prompt::ask(
    "what is your name",
    console~,
    choices=["foo", "bar"],
    default="baz",
    stream=@prompt.InputStream::new("egg\nfoo"),
  )
  assert_eq(name, "foo")
  let expected = "what is your name [foo/bar] (baz): Please select one of the available options\nwhat is your name [foo/bar] (baz): "
  assert_eq(file.getvalue(), expected)
}

///|
test "prompt_str_case_insensitive" {
  let (console, file) = plain_console()
  let name = @prompt.Prompt::ask(
    "what is your name",
    console~,
    choices=["foo", "bar"],
    default="baz",
    case_sensitive=false,
    stream=@prompt.InputStream::new("egg\nFoO"),
  )
  assert_eq(name, "foo")
  let expected = "what is your name [foo/bar] (baz): Please select one of the available options\nwhat is your name [foo/bar] (baz): "
  assert_eq(file.getvalue(), expected)
}

///|
test "prompt_str_default" {
  let (console, file) = plain_console()
  let name = @prompt.Prompt::ask(
    "what is your name",
    console~,
    default="Will",
    stream=@prompt.InputStream::new(""),
  )
  assert_eq(name, "Will")
  assert_eq(file.getvalue(), "what is your name (Will): ")
}

///|
test "prompt_int" {
  let (console, file) = plain_console()
  let number = @prompt.IntPrompt::ask(
    "Enter a number",
    console~,
    stream=@prompt.InputStream::new("foo\n100"),
  )
  assert_eq(number, 100)
  assert_eq(
    file.getvalue(),
    "Enter a number: Please enter a valid integer number\nEnter a number: ",
  )
}

///|
test "prompt_confirm_no" {
  let (console, file) = plain_console()
  let answer = @prompt.Confirm::ask(
    "continue",
    console~,
    stream=@prompt.InputStream::new("foo\nNO\nn"),
  )
  assert_eq(answer, false)
  let expected = "continue [y/n]: Please enter Y or N\ncontinue [y/n]: Please enter Y or N\ncontinue [y/n]: "
  assert_eq(file.getvalue(), expected)
}

///|
test "prompt_confirm_yes" {
  let (console, file) = plain_console()
  let answer = @prompt.Confirm::ask(
    "continue",
    console~,
    stream=@prompt.InputStream::new("foo\nNO\ny"),
  )
  assert_eq(answer, true)
  let expected = "continue [y/n]: Please enter Y or N\ncontinue [y/n]: Please enter Y or N\ncontinue [y/n]: "
  assert_eq(file.getvalue(), expected)
}

///|
test "prompt_confirm_default" {
  let (console, file) = plain_console()
  let answer = @prompt.Confirm::ask(
    "continue",
    console~,
    stream=@prompt.InputStream::new("foo\nNO\ny"),
    default=true,
  )
  assert_eq(answer, true)
  let expected = "continue [y/n] (y): Please enter Y or N\ncontinue [y/n] (y): Please enter Y or N\ncontinue [y/n] (y): "
  assert_eq(file.getvalue(), expected)
}

///|
test "prompt_confirm_markup" {
  let (console, file) = plain_console(markup=false)
  let answer = @prompt.Confirm::ask(
    "continue",
    console~,
    stream=@prompt.InputStream::new("foo\nNO\ny"),
    default=true,
  )
  assert_eq(answer, true)
  let expected = "continue [y/n] (y): Please enter Y or N\ncontinue [y/n] (y): Please enter Y or N\ncontinue [y/n] (y): "
  assert_eq(file.getvalue(), expected)
}
