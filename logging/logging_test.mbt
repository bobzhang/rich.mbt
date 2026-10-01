// Port of tests/test_logging.py. Records are passed to the handlers
// directly (or through `@logging.Logger`) instead of Python's logging
// module; exceptions are given as text / a renderable.

///|
fn term_console(
  width : Int,
  color_system? : String? = Some("truecolor"),
) -> (@rich.Console, @rich.StringIO) raise {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    file~,
    width~,
    color_system~,
    force_terminal=true,
    legacy_windows=false,
    environ={},
  )
  (console, file)
}

///|
/// Replace the random ids of terminal links (`ESC ]8;id=123;`) with 0.
fn normalize_links(s : String) -> String {
  let out = StringBuilder()
  let mut rest = s[:]
  while rest.find("]8;id=") is Some(i) {
    out.write_string(rest[:i + 6].to_owned())
    out.write_char('0')
    let mut j = i + 6
    while j < rest.length() && rest[j] is ('0'..='9') {
      j += 1
    }
    rest = rest[j:]
  }
  out.write_string(rest.to_owned())
  out.to_string()
}

///|
/// A stand-in for `Traceback.from_exception(ZeroDivisionError)`.
fn fake_traceback() -> &@rich.Renderable {
  @rich.Text::from_markup(
    "[b]Traceback[/b] (most recent call last)\n[red]ZeroDivisionError[/]: division by zero",
  ) catch {
    _ => @rich.Text::new()
  }
}

///|
test "exception" {
  let (console, file) = term_console(140, color_system=None)
  let handler_with_tracebacks = @logging.RichHandler::new(
    console~,
    enable_link_path=false,
    rich_tracebacks=true,
  )
  handler_with_tracebacks.set_formatter(
    Some(@logging.Formatter::new(fmt="FORMATTER %(message)s %(asctime)s")),
  )
  let log = @logging.Logger::new(name="rich", handlers=[handler_with_tracebacks])
  log.error("foo")
  log.exception(
    "message",
    exc_text="Traceback (most recent call last):\nZeroDivisionError: division by zero",
    traceback=fake_traceback(),
  )
  let render = file.getvalue()
  assert_true(render.contains("FORMATTER foo"))
  assert_true(render.contains("ZeroDivisionError"))
  assert_true(render.contains("message"))
  assert_true(render.contains("division by zero"))
  // the traceback renderable replaces the formatted exception text
  assert_false(render.contains("most recent call last):"))
}

///|
test "exception_with_extra_lines" {
  let (console, file) = term_console(140, color_system=None)
  let handler_extra_lines = @logging.RichHandler::new(
    console~,
    enable_link_path=false,
    markup=true,
    rich_tracebacks=true,
  )
  let log = @logging.Logger::new(name="rich", handlers=[handler_extra_lines])
  log.exception("message", traceback=fake_traceback())
  let render = file.getvalue()
  assert_true(render.contains("ZeroDivisionError"))
  assert_true(render.contains("message"))
  assert_true(render.contains("division by zero"))
}

///|
test "exception without rich tracebacks uses the formatted text" {
  let (console, file) = term_console(140, color_system=None)
  let handler = @logging.RichHandler::new(console~, enable_link_path=false)
  let log = @logging.Logger::new(name="rich", handlers=[handler])
  log.exception(
    "message",
    exc_text="Traceback (most recent call last):\nZeroDivisionError: division by zero",
    traceback=fake_traceback(),
  )
  let render = file.getvalue()
  assert_true(render.contains("most recent call last):"))
  assert_true(render.contains("ZeroDivisionError: division by zero"))
}

///|
test "markup_and_highlight" {
  let (console, file) = term_console(140)
  let handler = @logging.RichHandler::new(console~)
  // Check defaults are as expected
  assert_false(handler.markup)
  handler.set_formatter(
    Some(@logging.Formatter::new(fmt="FORMATTER %(message)s %(asctime)s")),
  )
  let log = @logging.Logger::new(name="rich", handlers=[handler])
  let log_message = "foo 3.141 127.0.0.1 [red]alert[/red]"
  log.error(log_message)
  let render_fancy = file.getvalue()
  assert_true(render_fancy.contains("FORMATTER"))
  assert_false(render_fancy.contains(log_message))
  assert_true(render_fancy.contains("red"))
  let file = @rich.StringIO::new()
  handler.console.set_file(file)
  log.error(log_message, markup=true)
  let render_markup = file.getvalue()
  assert_true(render_markup.contains("FORMATTER"))
  assert_false(render_markup.contains(log_message))
  assert_false(render_markup.contains("red"))
  let file = @rich.StringIO::new()
  handler.console.set_file(file)
  log.error(log_message, highlighter=@rich.NullHighlighter::new())
  let render_plain = file.getvalue()
  assert_true(render_plain.contains("FORMATTER"))
  assert_true(render_plain.contains(log_message))
}

///|
test "logger levels and source location" {
  let (console, file) = term_console(80, color_system=None)
  let handler = @logging.RichHandler::new(
    level=@logging.INFO,
    console~,
    show_time=false,
    enable_link_path=false,
  )
  let log = @logging.Logger::new(name="app", handlers=[handler])
  log.debug("hidden by the handler")
  log.info("shown")
  log.level = @logging.ERROR
  log.warning("hidden by the logger")
  log.critical("critical")
  let lines = file.getvalue().split("\n").map(l => l.to_owned()).collect()
  assert_eq(lines.length(), 3)
  assert_true(lines[0].has_prefix("INFO     shown "))
  assert_true(lines[0].contains("logging_test.mbt:"))
  assert_true(lines[1].has_prefix("CRITICAL critical "))
  inspect(@logging.get_level_name(25), content="Level 25")
  debug_inspect(@logging.level_from_name("WARN"), content="Some(30)")
}

///|
test "formatter" {
  let record = @logging.LogRecord::new(
    name="db",
    @logging.WARNING,
    "disk full",
    pathname="/srv/app/store.py",
    lineno=7,
    func_name="save",
    created=1700000000.5,
    exc_text="Traceback\nOSError",
    extra={ "user": "bob" },
  )
  let f = @logging.Formatter::new(
    fmt="%(levelname)-8s|%(name)s|%(filename)s:%(lineno)03d|%(module)s.%(funcName)s|%(user)s|%(msecs)d|%(created).1f|%(message)r",
    datefmt="%Y",
  )
  inspect(
    f.format(record),
    content=(
      #|WARNING |db|store.py:007|store.save|bob|500|1700000000.5|'disk full'
      #|Traceback
      #|OSError
    ),
  )
  try f.format_message({ ..record, extra: {}, }) catch {
    e => inspect(e, content="Formatting field not found in record: 'user'")
  } noraise {
    _ => fail("expected an error")
  }
}
