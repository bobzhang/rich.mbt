// Port of tests/test_padding.py.

///|
test "test_repr" {
  let padding = @rich.Padding::new("foo", pad=[1, 2])
  assert_eq(padding.repr(), "Padding(..., (1,2,1,2))")
}

///|
test "test_indent" {
  let indent_result = @rich.Padding::indent("test", 4)
  assert_eq(indent_result.top, 0)
  assert_eq(indent_result.right, 0)
  assert_eq(indent_result.bottom, 0)
  assert_eq(indent_result.left, 4)
}

///|
test "test_unpack" {
  assert_eq(@rich.unpack_padding([3]), (3, 3, 3, 3))
  assert_eq(@rich.unpack_padding([3, 4]), (3, 4, 3, 4))
  assert_eq(@rich.unpack_padding([3, 4, 5, 6]), (3, 4, 5, 6))
  try @rich.unpack_padding([1, 2, 3]) catch {
    ValueError(_) => ()
    e => fail("unexpected error \{e}")
  } noraise {
    _ => fail("expected ValueError")
  }
}

///|
test "test_expand_false" {
  let console = @rich.Console::new(width=100, color_system=None)
  console.begin_capture()
  console.print(@rich.Padding::new("foo", pad=[1], expand=false))
  assert_eq(console.end_capture(), "     \n foo \n     \n")
}

///|
test "test_rich_console" {
  let renderable = "test renderable"
  let style = @rich.Style::parse("red")
  let options : @rich.ConsoleOptions = {
    size: { width: 80, height: 25, },
    max_height: 25,
    legacy_windows: false,
    min_width: 10,
    max_width: 20,
    is_terminal: false,
    encoding: "utf-8",
    justify: None,
    overflow: None,
    no_wrap: Some(false),
    highlight: None,
    markup: None,
    height: None,
  }
  let expected_outputs = [
    @rich.Segment::new(renderable, style~),
    @rich.Segment::new(" ".repeat(20 - renderable.length()), style~),
    @rich.Segment::new("\n"),
  ]
  let items = @rich.Padding::new(renderable, style~).rich_console(
    @rich.Console::new(),
    options,
  )
  for i, expected in expected_outputs {
    guard items[i] is Seg(output) else { fail("expected a segment") }
    assert_eq(output, expected)
  }
}
