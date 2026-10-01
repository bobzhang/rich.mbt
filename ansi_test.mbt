// Port of tests/test_ansi.py.

///|
fn ansi_console() -> @rich.Console raise {
  @rich.Console::new(
    file=@rich.StringIO::new(),
    width=80,
    force_terminal=true,
    legacy_windows=false,
    color_system=Some("truecolor"),
    environ={},
  )
}

///|
/// `repr(plain)` and spans with `str(style)` (see scripts/gen_ansi_tests.py).
fn ansi_text_repr(t : @rich.Text) -> String {
  let spans = t
    .spans()
    .map(s => {
      "Span(\{s.start}, \{s.end}, \{@rich.py_repr(s.style.to_string())})"
    })
  "\{@rich.py_repr(t.plain())} [\{spans.join(", ")}]"
}

///|
test "decode" {
  let console = ansi_console()
  console.begin_capture()
  console.print("Hello")
  console.print("[b]foo[/b]")
  console.print("[link http://example.org]bar")
  console.print("[#ff0000 on color(200)]red")
  console.print("[color(200) on #ff0000]red")
  let terminal_codes = console.end_capture()
  let decoder = @rich.AnsiDecoder::new()
  let lines = decoder.decode(terminal_codes)
  fn styled(s : String, style : String) -> @rich.Text raise {
    @rich.Text::new(text=s, spans=[
      @rich.Span::new(0, 3, @rich.Style::parse(style)),
    ])
  }

  assert_eq(lines, [
    @rich.Text::new(text="Hello"),
    styled("foo", "bold"),
    styled("bar", "link http://example.org"),
    styled("red", "#ff0000 on color(200)"),
    styled("red", "color(200) on #ff0000"),
    @rich.Text::new(text=""),
  ])
}

///|
test "decode_example" {
  let ansi_text = "\u{1b}[01m\u{1b}[KC:\\Users\\stefa\\AppData\\Local\\Temp\\tmp3ydingba:\u{1b}[m\u{1b}[K In function '\u{1b}[01m\u{1b}[Kmain\u{1b}[m\u{1b}[K':\n\u{1b}[01m\u{1b}[KC:\\Users\\stefa\\AppData\\Local\\Temp\\tmp3ydingba:3:5:\u{1b}[m\u{1b}[K \u{1b}[01;35m\u{1b}[Kwarning: \u{1b}[m\u{1b}[Kunused variable '\u{1b}[01m\u{1b}[Ka\u{1b}[m\u{1b}[K' [\u{1b}[01;35m\u{1b}[K-Wunused-variable\u{1b}[m\u{1b}[K]\n    3 | int \u{1b}[01;35m\u{1b}[Ka\u{1b}[m\u{1b}[K=1;\n      |     \u{1b}[01;35m\u{1b}[K^\u{1b}[m\u{1b}[K\n"
  let text = @rich.Text::from_ansi(ansi_text)
  let console = ansi_console()
  let result = console.capture(() => console.print(text))
  assert_eq(
    result, "\u{1b}[1mC:\\Users\\stefa\\AppData\\Local\\Temp\\tmp3ydingba:\u{1b}[0m In function '\u{1b}[1mmain\u{1b}[0m':\n\u{1b}[1mC:\\Users\\stefa\\AppData\\Local\\Temp\\tmp3ydingba:3:5:\u{1b}[0m \u{1b}[1;35mwarning: \u{1b}[0munused variable '\u{1b}[1ma\u{1b}[0m' \n[\u{1b}[1;35m-Wunused-variable\u{1b}[0m]\n    3 | int \u{1b}[1;35ma\u{1b}[0m=1;\n      |     \u{1b}[1;35m^\u{1b}[0m\n\n",
  )
}

///|
test "decode_issue_2688" {
  let cases = [
    (
      "\u{1b}[31mFound 4 errors in 2 files (checked 18 source files)\u{1b}(B\u{1b}[m\n",
      "Found 4 errors in 2 files (checked 18 source files)\n",
    ),
    ("Hallo", "Hallo"),
    ("\u{1b}(BHallo", "Hallo"),
    ("\u{1b}(JHallo", "Hallo"),
    ("\u{1b}(BHal\u{1b}(Jlo", "Hallo"),
  ]
  for case in cases {
    let (ansi, expected_text) = case
    assert_eq(@rich.Text::from_ansi(ansi).plain(), expected_text)
  }
}

///|
test "strip_private_escape_sequences" {
  for code in "0123456789:;<=>?" {
    let text = @rich.Text::from_ansi("\u{1b}\{code}x")
    let console = @rich.Console::new(
      file=@rich.StringIO::new(),
      force_terminal=true,
      environ={},
    )
    let output = console.capture(() => console.print(text))
    assert_eq(output, "x\n")
  }
}

///|
test "decode_newlines" {
  for
    s in [
      "", "\n", "\n\n", "Hello", "\nHello", "Hello\n", "Hello\n\n", "Hello\nWorld",
      "Hello\n\nWorld", "Hello\nWorld\n", "Hello\nWorld\n\n", "\nHello\nWorld\n\n",
    ] {
    assert_eq(@rich.Text::from_ansi(s).plain(), s)
  }
}
