// Port of tests/test_control.py.

///|
test "test_control" {
  let control = @rich.Control::new([Code(Bell)])
  assert_eq(control.to_string(), "\u{07}")
}

///|
test "test_strip_control_codes" {
  assert_eq(@rich.strip_control_codes(""), "")
  assert_eq(@rich.strip_control_codes("foo\rbar"), "foobar")
  assert_eq(
    @rich.strip_control_codes("Fear is the mind killer"),
    "Fear is the mind killer",
  )
}

///|
test "test_escape_control_codes" {
  assert_eq(@rich.escape_control_codes(""), "")
  assert_eq(@rich.escape_control_codes("foo\rbar"), "foo\\rbar")
  assert_eq(
    @rich.escape_control_codes("Fear is the mind killer"),
    "Fear is the mind killer",
  )
}

///|
test "test_control_move_to" {
  let control = @rich.Control::move_to(5, 10)
  assert_eq(
    control.segment,
    @rich.Segment::new("\u{1b}[11;6H", control=[CodeXY(CursorMoveTo, 5, 10)]),
  )
}

///|
test "test_control_move" {
  assert_eq(
    @rich.Control::move(x=0, y=0).segment,
    @rich.Segment::new("", control=[]),
  )
  let control = @rich.Control::move(x=3, y=4)
  assert_eq(
    control.segment,
    @rich.Segment::new("\u{1b}[3C\u{1b}[4B", control=[
      CodeInt(CursorForward, 3),
      CodeInt(CursorDown, 4),
    ]),
  )
}

///|
test "test_move_to_column" {
  assert_eq(
    @rich.Control::move_to_column(10, y=20).segment,
    @rich.Segment::new("\u{1b}[11G\u{1b}[20B", control=[
      CodeInt(CursorMoveToColumn, 10),
      CodeInt(CursorDown, 20),
    ]),
  )
  assert_eq(
    @rich.Control::move_to_column(10, y=-20).segment,
    @rich.Segment::new("\u{1b}[11G\u{1b}[20A", control=[
      CodeInt(CursorMoveToColumn, 10),
      CodeInt(CursorUp, 20),
    ]),
  )
}

///|
test "test_title" {
  let control_segment = @rich.Control::title("hello").segment
  assert_eq(
    control_segment,
    @rich.Segment::new("\u{1b}]0;hello\u{07}", control=[
      CodeStr(SetWindowTitle, "hello"),
    ]),
  )
}
