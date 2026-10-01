// Port of tests/test_styled.py, tests/test_constrain.py and
// tests/test_screen.py.

///|
test "test_styled" {
  let styled_foo = @rich.Styled::new("foo", "on red")
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(file~, force_terminal=true, environ={})
  assert_eq(
    @rich.Measurement::get(console, console.options(), styled_foo),
    @rich.Measurement::new(3, 3),
  )
  console.print(styled_foo)
  assert_eq(file.getvalue(), "\u{1b}[41mfoo\u{1b}[0m\n")
}

///|
test "test_width_of_none" {
  let console = @rich.Console::new()
  let constrain = @rich.Constrain::new(@rich.Text::new(text="foo"), width=None)
  let m = constrain
    .rich_measure(console, console.options().update_width(80))
    .unwrap()
  assert_eq(m.minimum, 3)
  assert_eq(m.maximum, 3)
}

///|
test "test_screen" {
  let console = @rich.Console::new(
    color_system=None,
    width=20,
    height=5,
    legacy_windows=false,
  )
  let result = console.capture(() => {
    console.print(@rich.Screen::new(["foo\nbar\nbaz\nfoo\nbar\nbaz\u{0c}oo"]))
  })
  let expected = "foo                 \nbar                 \nbaz                 \nfoo                 \nbar                 "
  assert_eq(result, expected)
}
