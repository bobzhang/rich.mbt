// Port of tests/test_align.py.

///|
fn plain_console(
  width? : Int,
  height? : Int,
) -> (@rich.Console, @rich.StringIO) raise {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(file~, width?, height?, environ={})
  (console, file)
}

// test_bad_align_legal: alignment methods are enums, so illegal values
// cannot be constructed.

///|
test "test_repr" {
  ignore(@rich.Align::new("foo", Left))
  ignore(@rich.Align::new("foo", Center))
  ignore(@rich.Align::new("foo", Right))
}

///|
test "test_align_left" {
  let (console, file) = plain_console(width=10)
  console.print(@rich.Align::new("foo", Left))
  assert_eq(file.getvalue(), "foo       \n")
}

///|
test "test_align_center" {
  let (console, file) = plain_console(width=10)
  console.print(@rich.Align::new("foo", Center))
  assert_eq(file.getvalue(), "   foo    \n")
}

///|
test "test_align_right" {
  let (console, file) = plain_console(width=10)
  console.print(@rich.Align::new("foo", Right))
  assert_eq(file.getvalue(), "       foo\n")
}

///|
test "test_align_top" {
  let (console, file) = plain_console(width=10)
  console.print(@rich.Align::new("foo", Left, vertical=Top), height=5)
  let expected = "foo       \n          \n          \n          \n          \n"
  assert_eq(file.getvalue(), expected)
}

///|
test "test_align_middle" {
  let (console, file) = plain_console(width=10)
  console.print(@rich.Align::new("foo", Left, vertical=Middle), height=5)
  let expected = "          \n          \nfoo       \n          \n          \n"
  assert_eq(file.getvalue(), expected)
}

///|
test "test_align_bottom" {
  let (console, file) = plain_console(width=10)
  console.print(@rich.Align::new("foo", Left, vertical=Bottom), height=5)
  let expected = "          \n          \n          \n          \nfoo       \n"
  assert_eq(file.getvalue(), expected)
}

///|
test "test_align_center_middle" {
  let (console, file) = plain_console(width=10)
  console.print(@rich.Align::new("foo\nbar", Center, vertical=Middle), height=5)
  let expected = "          \n   foo    \n   bar    \n          \n          \n"
  assert_eq(file.getvalue(), expected)
}

///|
test "test_align_fit" {
  let (console, file) = plain_console(width=10)
  console.print(@rich.Align::new("foobarbaze", Center))
  assert_eq(file.getvalue(), "foobarbaze\n")
}

///|
test "test_align_right_style" {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    file~,
    width=10,
    color_system=Some("truecolor"),
    force_terminal=true,
    environ={},
  )
  console.print(@rich.Align::new("foo", Right, style="on blue"))
  assert_eq(
    file.getvalue(),
    "\u{1b}[44m       \u{1b}[0m\u{1b}[44mfoo\u{1b}[0m\n",
  )
}

///|
test "test_measure" {
  let (console, _) = plain_console(width=20)
  let m = @rich.Measurement::get(
    console,
    console.options(),
    @rich.Align::new("foo bar", Left),
  )
  assert_eq(m.minimum, 3)
  assert_eq(m.maximum, 7)
}

///|
test "test_align_no_pad" {
  let (console, file) = plain_console(width=10)
  console.print(@rich.Align::new("foo", Center, pad=false))
  console.print(@rich.Align::new("foo", Left, pad=false))
  assert_eq(file.getvalue(), "   foo\nfoo\n")
}

///|
test "test_align_width" {
  let (console, file) = plain_console(width=40)
  let words = "Deep in the human unconscious is a pervasive need for a logical universe that makes sense. But the real universe is always one step beyond logic"
  console.print(@rich.Align::new(words, Center, width=30))
  let expected = "     Deep in the human unconscious      \n     is a pervasive need for a          \n     logical universe that makes        \n     sense. But the real universe       \n     is always one step beyond          \n     logic                              \n"
  assert_eq(file.getvalue(), expected)
}

///|
test "test_shortcuts" {
  assert_eq(@rich.Align::left("foo").align, Left)
  assert_eq(@rich.Align::left("foo").renderable.text_kind() is Str("foo"), true)
  assert_eq(@rich.Align::right("foo").align, Right)
  assert_eq(
    @rich.Align::right("foo").renderable.text_kind() is Str("foo"),
    true,
  )
  assert_eq(@rich.Align::center("foo").align, Center)
  assert_eq(
    @rich.Align::center("foo").renderable.text_kind() is Str("foo"),
    true,
  )
}

///|
test "test_vertical_center" {
  let console = @rich.Console::new(color_system=None, height=6, environ={})
  console.begin_capture()
  let vertical_center = @rich.VerticalCenter::new("foo")
  console.print(vertical_center)
  let result = console.end_capture()
  let expected = "   \n   \nfoo\n   \n   \n   \n"
  assert_eq(result, expected)
  assert_eq(
    @rich.Measurement::get(console, console.options(), vertical_center),
    @rich.Measurement::new(3, 3),
  )
}
