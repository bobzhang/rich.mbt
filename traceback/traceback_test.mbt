// Port of the portable parts of upstream tests/test_traceback.py. Python
// exceptions do not exist in MoonBit, so each test builds the Trace that
// `Traceback.extract` produces for the upstream test's code, using the
// scenario sources of oracle_test.mbt (`source_app`, `read_source`).

///|
fn app_frame(lineno : Int, name : String) -> @traceback.Frame {
  @traceback.Frame::new("/project/app.py", lineno, name)
}

///|
/// level1() -> level2() -> 1 / 0, as in upstream `test_handler`.
fn zero_division_stack(is_cause? : Bool = false) -> @traceback.Stack {
  @traceback.Stack::new("ZeroDivisionError", "division by zero", is_cause~, frames=[
    app_frame(8, "capture"),
    app_frame(29, "zero_division"),
    app_frame(25, "level1"),
    app_frame(19, "level2"),
    app_frame(14, "divide"),
  ])
}

///|
fn print_to_string(
  renderable : &@rich.Renderable,
  color_system? : String?,
) -> String raise {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    file~,
    width=100,
    color_system?,
    legacy_windows=false,
    environ={},
  )
  console.print(renderable)
  file.getvalue()
}

///|
fn exception_text(
  trace : @traceback.Trace,
  show_locals? : Bool = false,
  max_frames? : Int = 100,
) -> String raise {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(file~, width=100, environ={})
  @traceback.print_exception(
    console,
    trace,
    show_locals~,
    max_frames~,
    source_reader=read_source,
  )
  file.getvalue()
}

///|
fn count(haystack : String, needle : String) -> Int {
  let mut n = 0
  let mut rest = haystack[:]
  while rest.find(needle) is Some(i) {
    n += 1
    rest = rest[i + needle.length():]
  }
  n
}

///|
test "handler" {
  let trace = @traceback.Trace::new([zero_division_stack()])
  let rendered_exception = print_to_string(
    @traceback.Traceback::new(trace, source_reader=read_source),
    color_system=None,
  )
  assert_true(rendered_exception.contains("Traceback"))
  assert_true(rendered_exception.contains("ZeroDivisionError"))
  let frame_blank_line_possible_preambles = [
    // Start of the stack rendering:
    "╭─────────────────────────────── Traceback (most recent call last) ────────────────────────────────╮",
    // Each subsequent frame (starting with the file name) should then be preceded with a blank line:
    "│" + " ".repeat(98) + "│",
  ]
  let lines = rendered_exception.split("\n").map(l => l.to_owned()).collect()
  let mut frames = 0
  for i, line in lines {
    if line.has_prefix("│ /project/app.py:") {
      frames += 1
      assert_true(
        i > 0 && frame_blank_line_possible_preambles.contains(lines[i - 1]),
      )
    }
  }
  assert_eq(frames, 5)
}

///|
test "capture" {
  let trace = @traceback.Trace::from_json(
    @json.parse(
      "{\"stacks\": [{\"exc_type\": \"ZeroDivisionError\", \"exc_value\": \"division by zero\", \"frames\": []}]}",
    ),
  )
  let tb = @traceback.Traceback::new(trace)
  assert_eq(tb.trace.stacks[0].exc_type, "ZeroDivisionError")
}

///|
test "print_exception" {
  let text = exception_text(@traceback.Trace::new([zero_division_stack()]))
  assert_true(text.contains("ZeroDivisionError"))
}

///|
test "print_exception_no_msg" {
  let trace = @traceback.Trace::new([
    @traceback.Stack::new("RuntimeError", "", frames=[
      app_frame(8, "capture"),
      app_frame(33, "no_message"),
    ]),
  ])
  let text = exception_text(trace)
  assert_true(text.contains("RuntimeError"))
  assert_true(!text.contains("RuntimeError:"))
}

///|
test "print_exception_locals" {
  let locals : Map[String, @pretty.Node] = {
    "console": @pretty.traverse(@pretty.Leaf::new("<console width=100 None>")),
  }
  let trace = @traceback.Trace::new([
    @traceback.Stack::new("ZeroDivisionError", "division by zero", frames=[
      @traceback.Frame::new("/project/app.py", 8, "capture", locals~),
    ]),
  ])
  let text = exception_text(trace, show_locals=true)
  assert_true(text.contains("ZeroDivisionError"))
  assert_true(text.contains("locals"))
  assert_true(text.contains("console = <console width=100 None>"))
}

///|
test "syntax_error" {
  let trace = @traceback.Trace::new([
    @traceback.Stack::new(
      "SyntaxError",
      "'(' was never closed (<string>, line 1)",
      syntax_error=@traceback.SyntaxErrorInfo::new(
        offset=1,
        filename="<string>",
        line="(2+2",
        lineno=1,
        msg="'(' was never closed",
      ),
      frames=[app_frame(8, "capture"), app_frame(65, "syntax_error")],
    ),
  ])
  let text = exception_text(trace)
  assert_true(text.contains("SyntaxError"))
  assert_true(text.contains("▲"))
}

///|
test "nested_exception" {
  let value_error_message = "ValueError because of ZeroDivisionError"
  let trace = @traceback.Trace::new([
    @traceback.Stack::new("ValueError", value_error_message, frames=[
      app_frame(8, "capture"),
      app_frame(40, "nested"),
    ]),
    zero_division_stack(),
  ])
  let text = exception_text(trace)
  for
    msg in [
      value_error_message, "ZeroDivisionError", "ValueError", "During handling of the above exception",
    ] {
    assert_true(text.contains(msg))
  }
  // ZeroDivisionError should come before ValueError
  assert_true(
    text.find("ZeroDivisionError").unwrap() < text.find("ValueError").unwrap(),
  )
}

///|
test "caused_exception" {
  let value_error_message = "ValueError caused by ZeroDivisionError"
  let trace = @traceback.Trace::new([
    @traceback.Stack::new("ValueError", value_error_message, frames=[
      app_frame(8, "capture"),
      app_frame(47, "caused"),
    ]),
    zero_division_stack(is_cause=true),
  ])
  let text = exception_text(trace)
  for
    msg in [
      value_error_message, "ZeroDivisionError", "ValueError", "The above exception was the direct cause",
    ] {
    assert_true(text.contains(msg))
  }
  assert_true(
    text.find("ZeroDivisionError").unwrap() < text.find("ValueError").unwrap(),
  )
}

///|
test "filename_with_bracket" {
  let trace = @traceback.Trace::new([
    @traceback.Stack::new("ZeroDivisionError", "division by zero", frames=[
      app_frame(74, "string_code"),
      @traceback.Frame::new("<string>", 1, "<module>"),
    ]),
  ])
  assert_true(exception_text(trace).contains("<string>"))
}

///|
test "filename_not_a_file" {
  let trace = @traceback.Trace::new([
    @traceback.Stack::new("ZeroDivisionError", "division by zero", frames=[
      app_frame(78, "not_a_file"),
      @traceback.Frame::new("string", 1, "<module>"),
    ]),
  ])
  assert_true(exception_text(trace).contains("string"))
}

///|
test "traceback_console_theme_applies" {
  let (r, g, b) = (123, 234, 123)
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    file~,
    force_terminal=true,
    width=100,
    environ={ "COLORTERM": "truecolor" },
    theme=@rich.Theme::new(styles={ "traceback.title": "rgb(\{r},\{g},\{b})" }),
  )
  @traceback.print_exception(
    console,
    @traceback.Trace::new([zero_division_stack()]),
    source_reader=read_source,
  )
  assert_true(
    file.getvalue().contains("\u{1b}[38;2;\{r};\{g};\{b}mTraceback \u{1b}[0m"),
  )
}

///|
test "broken_str" {
  // upstream's `safe_str` gives this message when `str(exception)` fails
  let trace = @traceback.Trace::new([
    @traceback.Stack::new("BrokenStr", "<exception str() failed>", frames=[
      app_frame(8, "capture"),
    ]),
  ])
  assert_true(exception_text(trace).contains("<exception str() failed>"))
}

///|
test "guess_lexer" {
  assert_eq(@traceback.Traceback::guess_lexer("foo.py", "code"), "python")
  let code_python = "#! usr/bin/env python\nimport this"
  assert_eq(@traceback.Traceback::guess_lexer("foo", code_python), "python")
  assert_eq(@traceback.Traceback::guess_lexer("foo", "foo\nbnar"), "text")
  // no extension and no new line: upstream's `str.index` raises
  try @traceback.Traceback::guess_lexer("foo", "no newline") catch {
    err => inspect(err, content="substring not found")
  } noraise {
    _ => fail("expected to fail")
  }
}

///|
test "guess_lexer_yaml_j2" {
  // https://github.com/Textualize/rich/issues/2018
  let code =
    #|foobar:
    #|    something: {{ raiser() }}
    #|    else: {{ 5 + 5 }}
    #|
  let lexer = @traceback.Traceback::guess_lexer("test.yaml.j2", code)
  assert_true(lexer == "text" || lexer == "YAML+Jinja")
}

///|
test "recursive" {
  let frames = [app_frame(8, "capture"), app_frame(61, "recursion")]
  for _ in 0..<13 {
    frames.push(app_frame(53, "recursive"))
    frames.push(app_frame(57, "recursive2"))
  }
  frames.push(app_frame(52, "recursive"))
  let trace = @traceback.Trace::new([
    @traceback.Stack::new(
      "RecursionError",
      "maximum recursion depth exceeded",
      frames~,
    ),
  ])
  let result = exception_text(trace, max_frames=6)
  assert_true(result.contains("frames hidden"))
  assert_true(count(result, "in recursive ") < 4)
}

///|
test "suppress" {
  let traceback = @traceback.Traceback::new(
    @traceback.Trace::new([zero_division_stack()]),
    suppress=["/usr/lib/python3/site-packages/pytest", "foo"],
  )
  assert_eq(traceback.suppress.length(), 2)
  assert_true(traceback.suppress[0].contains("pytest"))
  assert_true(traceback.suppress[1].contains("foo"))
  // paths are normalized
  let traceback = @traceback.Traceback::new(@traceback.Trace::new([]), suppress=[
    "/a/./b//c/../d/",
  ])
  assert_eq(traceback.suppress, ["/a/b/d"])
}

///|
test "traceback_finely_grained" {
  // Check that last instruction survives loading
  let trace = @traceback.Trace::from_json(
    @json.parse(
      (
        #|{"stacks": [{"exc_type": "ZeroDivisionError", "exc_value": "division by zero",
        #| "frames": [{"filename": "/project/app.py", "lineno": 14, "name": "divide",
        #|   "line": "", "locals": null, "last_instruction": [[14, 11], [14, 16]]}]}]}
      ),
    ),
  )
  guard trace.stacks.last() is Some(stack) &&
    stack.frames.last() is Some(frame) &&
    frame.last_instruction is Some((start, end)) else {
    fail("no last instruction")
  }
  assert_eq(start.0, end.0)
  assert_eq((start, end), ((14, 11), (14, 16)))
}

///|
test "notes" {
  let stack = zero_division_stack()
  let trace = @traceback.Trace::new([{ ..stack, notes: ["Hello", "World"], }])
  assert_eq(trace.stacks[0].notes, ["Hello", "World"])
  let text = exception_text(trace)
  assert_true(text.contains("[NOTE] Hello\n[NOTE] World\n"))
}

///|
test "json round trip" {
  let locals : Map[String, @pretty.Node] = {
    "x": @pretty.traverse([1, 2, 3]),
    "s": @pretty.traverse("text"),
  }
  let trace = @traceback.Trace::new([
    @traceback.Stack::new(
      "ValueError",
      "bad",
      frames=[
        @traceback.Frame::new(
          "/project/app.py",
          14,
          "divide",
          line="return a / b",
          locals~,
          last_instruction=((14, 11), (14, 16)),
        ),
      ],
      notes=["note"],
    ),
    @traceback.Stack::new(
      "SyntaxError",
      "invalid syntax",
      is_cause=true,
      syntax_error=@traceback.SyntaxErrorInfo::new(
        offset=3,
        filename="/project/bad.py",
        line="x = = 1",
        lineno=1,
        msg="invalid syntax",
      ),
    ),
  ])
  let json = trace.to_json()
  let again = @traceback.Trace::from_json(json)
  assert_eq(again.to_json().stringify(), json.stringify())
  assert_eq(
    print_to_string(
      @traceback.Traceback::new(again, source_reader=read_source),
      color_system=None,
    ),
    print_to_string(
      @traceback.Traceback::new(trace, source_reader=read_source),
      color_system=None,
    ),
  )
}

///|
test "print_error" {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(file~, width=60, environ={})
  @traceback.print_error(
    console,
    @rich.ValueError("bad value"),
    exc_type="ValueError",
  )
  inspect(file.getvalue(), content="ValueError: bad value\n")
}
