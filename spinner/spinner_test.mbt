// Port of tests/test_spinner.py.

///|
test "spinner_create" {
  ignore(@spinner.Spinner::new("dots"))
  try @spinner.Spinner::new("foobar") catch {
    e => inspect(e, content="no spinner called 'foobar'")
  } noraise {
    _ => fail("expected to fail")
  }
}

///|
test "spinner_render" {
  let time = Ref(0.0)
  let console = @rich.Console::new(
    width=80,
    color_system=None,
    force_terminal=true,
    get_time=() => time.val,
    environ={},
  )
  console.begin_capture()
  let spinner = @spinner.Spinner::new("dots", text="Foo")
  console.print(spinner)
  time.val += 80.0 / 1000.0
  console.print(spinner)
  let result = console.end_capture()
  assert_eq(result, "⠋ Foo\n⠙ Foo\n")
}

///|
test "spinner_update" {
  let time = Ref(0.0)
  let console = @rich.Console::new(
    width=20,
    force_terminal=true,
    get_time=() => time.val,
    environ={},
  )
  console.begin_capture()
  let spinner = @spinner.Spinner::new("dots")
  console.print(spinner)
  let rule = @rich.Rule::new(title="Bar")
  spinner.update(text=rule)
  time.val += 80.0 / 1000.0
  console.print(spinner)
  let result = console.end_capture()
  assert_eq(result, "⠋\n⠙ \u{1b}[92m─\u{1b}[0m\n")
}

///|
test "rich_measure" {
  let console = @rich.Console::new(
    width=80,
    color_system=None,
    force_terminal=true,
    environ={},
  )
  let spinner = @spinner.Spinner::new("dots", text="Foo")
  let m = @rich.Measurement::get(console, console.options(), spinner)
  assert_eq(m.minimum, 3)
  assert_eq(m.maximum, 5)
}

///|
test "spinner_markup" {
  let spinner = @spinner.Spinner::new("dots", text="[bold]spinning[/bold]")
  guard spinner.text.text_kind() is Text(t) else { fail("expected Text") }
  assert_eq(t.plain(), "spinning")
}
