// Port of tests/test_status.py.

///|
fn make_console() -> @rich.Console raise {
  @rich.Console::new(
    color_system=None,
    width=80,
    legacy_windows=false,
    get_time=() => 0.0,
    file=@rich.StringIO::new(),
    environ={},
  )
}

///|
test "status" {
  let console = make_console()
  let status = @status.Status::new("foo", console~)
  assert_true(physical_equal(status.console(), console))
  let previous_status_renderable = status.renderable()
  status.update(status="bar", spinner_style="red", speed=2.0)
  assert_true(physical_equal(previous_status_renderable, status.renderable()))
  status.update(spinner="dots2")
  assert_true(!physical_equal(previous_status_renderable, status.renderable()))
  status.run(() => ())
}

///|
test "renderable" {
  let console = make_console()
  let status = @status.Status::new("foo", console~)
  console.begin_capture()
  console.print(status)
  assert_eq(console.end_capture(), "⠋ foo\n")
}
