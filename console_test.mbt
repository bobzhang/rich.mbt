// Port of tests/test_console.py.

///|
fn string_console(
  width? : Int,
  height? : Int,
  color_system? : String? = Some("truecolor"),
  force_terminal? : Bool,
  legacy_windows? : Bool,
  environ? : Map[String, String] = {},
  soft_wrap? : Bool = false,
  record? : Bool = false,
  highlight? : Bool = true,
  quiet? : Bool = false,
  no_color? : Bool,
  style? : &@rich.IntoStyle,
) -> (@rich.Console, @rich.StringIO) raise {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    file~,
    width?,
    height?,
    color_system~,
    force_terminal?,
    legacy_windows?,
    environ~,
    soft_wrap~,
    record~,
    highlight~,
    quiet~,
    no_color?,
    style?,
  )
  (console, file)
}

///|
test "test_dumb_terminal" {
  let console = @rich.Console::new(force_terminal=true, environ={})
  assert_true(console.color_system() is Some(_))
  let console = @rich.Console::new(force_terminal=true, environ={
    "TERM": "dumb",
  })
  assert_eq(console.color_system(), None)
  let { width, height, } = console.size()
  assert_eq(width, 80)
  assert_eq(height, 25)
}

///|
test "test_soft_wrap" {
  let (console, file) = string_console(width=20, soft_wrap=true)
  console.print("foo ".repeat(10))
  assert_eq(file.getvalue(), "foo ".repeat(10) + "\n")
}

///|
test "test_16color_terminal" {
  let console = @rich.Console::new(
    force_terminal=true,
    environ={ "TERM": "xterm-16color" },
    legacy_windows=false,
  )
  assert_eq(console.color_system(), Some("standard"))
}

///|
test "test_truecolor_terminal" {
  let console = @rich.Console::new(force_terminal=true, legacy_windows=false, environ={
    "COLORTERM": "truecolor",
    "TERM": "xterm-16color",
  })
  assert_eq(console.color_system(), Some("truecolor"))
}

///|
test "test_kitty_terminal" {
  let console = @rich.Console::new(force_terminal=true, legacy_windows=false, environ={
    "TERM": "xterm-kitty",
  })
  assert_eq(console.color_system(), Some("256"))
}

///|
fn test_options() -> @rich.ConsoleOptions {
  {
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
}

///|
test "test_console_options_update" {
  let options = test_options()
  let options1 = options.update(width=15)
  assert_true(options1.min_width == 15 && options1.max_width == 15)
  let options2 = options.update(min_width=5, max_width=15, justify=Some(Right))
  assert_true(
    options2.min_width == 5 &&
    options2.max_width == 15 &&
    options2.justify == Some(Right),
  )
  let options_copy = options.update()
  assert_true(options_copy.max_width == options.max_width)
  assert_true(!physical_equal(options_copy, options))
}

///|
test "test_console_options_update_height" {
  let options = test_options()
  assert_eq(options.height, None)
  let render_options = options.update_height(12)
  assert_eq(options.height, None)
  assert_eq(render_options.height, Some(12))
  assert_eq(render_options.max_height, 12)
}

///|
test "test_init" {
  let console = @rich.Console::new(color_system=None)
  assert_true(console.color_system_enum() is None)
  let console = @rich.Console::new(color_system=Some("standard"))
  assert_true(console.color_system_enum() is Some(Standard))
  ignore(@rich.Console::new(color_system=Some("auto")))
}

///|
test "test_size" {
  let console = @rich.Console::new()
  let { width: w, .. } = console.size()
  assert_eq(console.width(), w)
  let console = @rich.Console::new(width=99, height=101, legacy_windows=false)
  let { width: w, height: h, } = console.size()
  assert_true(w == 99 && h == 101)
}

// test_size_can_fall_back_to_std_descriptors: mocks os.get_terminal_size.

///|
test "test_repr" {
  let console = @rich.Console::new(width=80, color_system=Some("truecolor"), environ={})
  assert_eq(console.repr(), "<console width=80 ColorSystem.TRUECOLOR>")
}

///|
test "test_print" {
  let (console, file) = string_console()
  console.print("foo")
  assert_eq(file.getvalue(), "foo\n")
}

///|
test "test_print_empty_with_end" {
  let (console, file) = string_console()
  console.print_many([], end="!")
  assert_eq(file.getvalue(), "!")
}

///|
test "test_print_multiple" {
  let (console, file) = string_console()
  console.print_many(["foo", "bar"])
  assert_eq(file.getvalue(), "foo bar\n")
}

///|
test "test_print_text" {
  let (console, file) = string_console()
  console.print(@rich.Text::new(text="foo", style="bold"))
  assert_eq(file.getvalue(), "\u{1b}[1mfoo\u{1b}[0m\n")
}

///|
test "test_print_text_multiple" {
  let (console, file) = string_console()
  console.print_many([
    @rich.Text::new(text="foo", style="bold"),
    @rich.Text::new(text="bar"),
    "baz",
  ])
  assert_eq(file.getvalue(), "\u{1b}[1mfoo\u{1b}[0m bar baz\n")
}

///|
test "test_print_json" {
  let (console, file) = string_console()
  console.print_json(json="[false, true, null, \"foo\"]", indent=Some(4))
  let expected = "\u{1b}[1m[\u{1b}[0m\n    \u{1b}[3;91mfalse\u{1b}[0m,\n    \u{1b}[3;92mtrue\u{1b}[0m,\n    \u{1b}[3;35mnull\u{1b}[0m,\n    \u{1b}[32m\"foo\"\u{1b}[0m\n\u{1b}[1m]\u{1b}[0m\n"
  assert_eq(file.getvalue(), expected)
}

// test_print_json_error: passing a non-string as JSON text is a type error.

///|
test "test_print_json_data" {
  let (console, file) = string_console()
  console.print_json(data=[false, true, null, "foo"], indent=Some(4))
  let expected = "\u{1b}[1m[\u{1b}[0m\n    \u{1b}[3;91mfalse\u{1b}[0m,\n    \u{1b}[3;92mtrue\u{1b}[0m,\n    \u{1b}[3;35mnull\u{1b}[0m,\n    \u{1b}[32m\"foo\"\u{1b}[0m\n\u{1b}[1m]\u{1b}[0m\n"
  assert_eq(file.getvalue(), expected)
}

///|
test "test_print_json_ensure_ascii" {
  let (console, file) = string_console()
  console.print_json(data={ "foo": "💩" }, ensure_ascii=false)
  let expected = "\u{1b}[1m{\u{1b}[0m\n  \u{1b}[1;34m\"foo\"\u{1b}[0m: \u{1b}[32m\"💩\"\u{1b}[0m\n\u{1b}[1m}\u{1b}[0m\n"
  assert_eq(file.getvalue(), expected)
}

///|
test "test_print_json_with_default_ensure_ascii" {
  let (console, file) = string_console()
  console.print_json(data={ "foo": "💩" })
  let expected = "\u{1b}[1m{\u{1b}[0m\n  \u{1b}[1;34m\"foo\"\u{1b}[0m: \u{1b}[32m\"💩\"\u{1b}[0m\n\u{1b}[1m}\u{1b}[0m\n"
  assert_eq(file.getvalue(), expected)
}

///|
test "test_print_json_indent_none" {
  let (console, file) = string_console()
  console.print_json(data={ "name": "apple", "count": 1 }, indent=None)
  let expected = "\u{1b}[1m{\u{1b}[0m\u{1b}[1;34m\"name\"\u{1b}[0m: \u{1b}[32m\"apple\"\u{1b}[0m, \u{1b}[1;34m\"count\"\u{1b}[0m: \u{1b}[1;36m1\u{1b}[0m\u{1b}[1m}\u{1b}[0m\n"
  assert_eq(file.getvalue(), expected)
}

// test_console_null_file: there is no sys.stdout to replace.

///|
test "test_log" {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    file~,
    width=80,
    color_system=Some("truecolor"),
    log_time_format="TIME",
    log_path=false,
    environ={},
  )
  console.log("foo", style="red")
  let expected = "\u{1b}[2;36mTIME\u{1b}[0m\u{1b}[2;36m \u{1b}[0m\u{1b}[31mfoo                                                                        \u{1b}[0m\n"
  assert_eq(file.getvalue(), expected)
}

///|
test "test_log_milliseconds" {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    file~,
    width=40,
    log_time_formatter=_ => @rich.Text::new(text="TIME"),
    log_path=false,
    environ={},
  )
  console.log("foo")
  assert_eq(file.getvalue(), "TIME foo                                \n")
}

///|
test "test_print_empty" {
  let (console, file) = string_console()
  console.print_many([])
  assert_eq(file.getvalue(), "\n")
}

///|
test "test_markup_highlight" {
  let (console, file) = string_console()
  console.print("'[bold]foo[/bold]'")
  assert_eq(
    file.getvalue(),
    "\u{1b}[32m'\u{1b}[0m\u{1b}[1;32mfoo\u{1b}[0m\u{1b}[32m'\u{1b}[0m\n",
  )
}

///|
test "test_print_style" {
  let (console, file) = string_console()
  console.print("foo", style="bold")
  assert_eq(file.getvalue(), "\u{1b}[1mfoo\u{1b}[0m\n")
}

///|
test "test_show_cursor" {
  let (console, file) = string_console(
    color_system=Some("auto"),
    force_terminal=true,
    legacy_windows=false,
  )
  console.show_cursor(show=false) |> ignore
  console.print("foo")
  console.show_cursor(show=true) |> ignore
  assert_eq(file.getvalue(), "\u{1b}[?25lfoo\n\u{1b}[?25h")
}

///|
test "test_clear" {
  let (console, file) = string_console(
    color_system=Some("auto"),
    force_terminal=true,
  )
  console.clear()
  console.clear(home=false)
  assert_eq(file.getvalue(), "\u{1b}[2J\u{1b}[H" + "\u{1b}[2J")
}

///|
test "test_clear_no_terminal" {
  let (console, file) = string_console(color_system=Some("auto"))
  console.clear()
  console.clear(home=false)
  assert_eq(file.getvalue(), "")
}

///|
test "test_get_style" {
  let console = @rich.Console::new()
  assert_true(console.get_style("repr.brace") == @rich.Style::new(bold=true))
}

///|
test "test_get_style_default" {
  let console = @rich.Console::new()
  assert_true(
    console.get_style("foobar", default=Def("red")) == @rich.Style::parse("red"),
  )
}

///|
test "test_get_style_error" {
  let console = @rich.Console::new()
  try console.get_style("nosuchstyle") catch {
    MissingStyle(_) => ()
    e => fail("unexpected error \{e}")
  } noraise {
    _ => fail("expected MissingStyle")
  }
  try console.get_style("foo bar") catch {
    MissingStyle(_) => ()
    e => fail("unexpected error \{e}")
  } noraise {
    _ => fail("expected MissingStyle")
  }
}

// test_render_error / test_render_broken_renderable: rendering a
// non-renderable is a type error.

///|
test "test_control" {
  let (console, file) = string_console(
    color_system=Some("auto"),
    force_terminal=true,
  )
  console.control([@rich.Control::clear()])
  console.print("BAR")
  assert_eq(file.getvalue(), "\u{1b}[2JBAR\n")
}

///|
test "test_capture" {
  let console = @rich.Console::new(width=80)
  let result = console.capture(() => console.print("Hello"))
  assert_eq(result, "Hello\n")
}

// test_input / test_input_password: read from stdin.
// test_status: pending (needs the status package).

///|
test "test_justify_none" {
  let (console, file) = string_console(
    color_system=Some("auto"),
    force_terminal=true,
    width=20,
  )
  console.print("FOO")
  assert_eq(file.getvalue(), "FOO\n")
}

///|
test "test_justify_left" {
  let (console, file) = string_console(
    color_system=Some("auto"),
    force_terminal=true,
    width=20,
  )
  console.print("FOO", justify=Left)
  assert_eq(file.getvalue(), "FOO                 \n")
}

///|
test "test_justify_center" {
  let (console, file) = string_console(
    color_system=Some("auto"),
    force_terminal=true,
    width=20,
  )
  console.print("FOO", justify=Center)
  assert_eq(file.getvalue(), "        FOO         \n")
}

///|
test "test_justify_right" {
  let (console, file) = string_console(
    color_system=Some("auto"),
    force_terminal=true,
    width=20,
  )
  console.print("FOO", justify=Right)
  assert_eq(file.getvalue(), "                 FOO\n")
}

///|
fn panel_console(width : Int) -> (@rich.Console, @rich.StringIO) raise {
  string_console(
    color_system=Some("auto"),
    force_terminal=true,
    width~,
    legacy_windows=false,
  )
}

///|
test "test_justify_renderable_none" {
  let (console, file) = panel_console(20)
  console.print(@panel.Panel::new("FOO", expand=false, padding=[0]))
  assert_eq(file.getvalue(), "╭───╮\n│FOO│\n╰───╯\n")
}

///|
test "test_justify_renderable_left" {
  let (console, file) = panel_console(10)
  console.print(
    @panel.Panel::new("FOO", expand=false, padding=[0]),
    justify=Left,
  )
  assert_eq(
    file.getvalue(),
    "╭───╮     \n│FOO│     \n╰───╯     \n",
  )
}

///|
test "test_justify_renderable_center" {
  let (console, file) = panel_console(10)
  console.print(
    @panel.Panel::new("FOO", expand=false, padding=[0]),
    justify=Center,
  )
  assert_eq(
    file.getvalue(),
    "  ╭───╮   \n  │FOO│   \n  ╰───╯   \n",
  )
}

///|
test "test_justify_renderable_right" {
  let (console, file) = panel_console(20)
  console.print(
    @panel.Panel::new("FOO", expand=false, padding=[0]),
    justify=Right,
  )
  assert_eq(
    file.getvalue(),
    "               ╭───╮\n               │FOO│\n               ╰───╯\n",
  )
}

///|
fn record_console(width? : Int = 100) -> @rich.Console raise {
  @rich.Console::new(record=true, width~, file=@rich.NullFile::new(), environ={})
}

///|
test "test_export_text" {
  let console = record_console()
  console.print("[b]foo")
  let text = console.export_text()
  assert_eq(text, "foo\n")
}

///|
test "test_export_html" {
  let console = record_console()
  console.print("[b]foo <script> 'test' [link=https://example.org]Click[/link]")
  let html = console.export_html()
  let expected = "<!DOCTYPE html>\n<html>\n<head>\n<meta charset=\"UTF-8\">\n<style>\n.r1 {font-weight: bold}\n.r2 {color: #ff00ff; text-decoration-color: #ff00ff; font-weight: bold}\n.r3 {color: #008000; text-decoration-color: #008000; font-weight: bold}\nbody {\n    color: #000000;\n    background-color: #ffffff;\n}\n</style>\n</head>\n<body>\n    <pre style=\"font-family:Menlo,'DejaVu Sans Mono',consolas,'Courier New',monospace\"><code style=\"font-family:inherit\"><span class=\"r1\">foo &lt;</span><span class=\"r2\">script</span><span class=\"r1\">&gt; </span><span class=\"r3\">&#x27;test&#x27;</span><span class=\"r1\"> </span><a class=\"r1\" href=\"https://example.org\">Click</a>\n</code></pre>\n</body>\n</html>\n"
  assert_eq(html, expected)
}

///|
test "test_export_html_inline" {
  let console = record_console()
  console.print("[b]foo [link=https://example.org]Click[/link]")
  let html = console.export_html(inline_styles=true)
  let expected = "<!DOCTYPE html>\n<html>\n<head>\n<meta charset=\"UTF-8\">\n<style>\n\nbody {\n    color: #000000;\n    background-color: #ffffff;\n}\n</style>\n</head>\n<body>\n    <pre style=\"font-family:Menlo,'DejaVu Sans Mono',consolas,'Courier New',monospace\"><code style=\"font-family:inherit\"><span style=\"font-weight: bold\">foo </span><span style=\"font-weight: bold\"><a href=\"https://example.org\">Click</a></span>\n</code></pre>\n</body>\n</html>\n"
  assert_eq(html, expected)
}

///|
let expected_svg : String = "<svg class=\"rich-terminal\" viewBox=\"0 0 1238 74.4\" xmlns=\"http://www.w3.org/2000/svg\">\n    <!-- Generated with Rich https://www.textualize.io -->\n    <style>\n\n    @font-face {\n        font-family: \"Fira Code\";\n        src: local(\"FiraCode-Regular\"),\n                url(\"https://cdnjs.cloudflare.com/ajax/libs/firacode/6.2.0/woff2/FiraCode-Regular.woff2\") format(\"woff2\"),\n                url(\"https://cdnjs.cloudflare.com/ajax/libs/firacode/6.2.0/woff/FiraCode-Regular.woff\") format(\"woff\");\n        font-style: normal;\n        font-weight: 400;\n    }\n    @font-face {\n        font-family: \"Fira Code\";\n        src: local(\"FiraCode-Bold\"),\n                url(\"https://cdnjs.cloudflare.com/ajax/libs/firacode/6.2.0/woff2/FiraCode-Bold.woff2\") format(\"woff2\"),\n                url(\"https://cdnjs.cloudflare.com/ajax/libs/firacode/6.2.0/woff/FiraCode-Bold.woff\") format(\"woff\");\n        font-style: bold;\n        font-weight: 700;\n    }\n\n    .terminal-3526644552-matrix {\n        font-family: Fira Code, monospace;\n        font-size: 20px;\n        line-height: 24.4px;\n        font-variant-east-asian: full-width;\n    }\n\n    .terminal-3526644552-title {\n        font-size: 18px;\n        font-weight: bold;\n        font-family: arial;\n    }\n\n    .terminal-3526644552-r1 { fill: #608ab1;font-weight: bold }\n.terminal-3526644552-r2 { fill: #c5c8c6 }\n    </style>\n\n    <defs>\n    <clipPath id=\"terminal-3526644552-clip-terminal\">\n      <rect x=\"0\" y=\"0\" width=\"1219.0\" height=\"23.4\" />\n    </clipPath>\n    \n    </defs>\n\n    <rect fill=\"#292929\" stroke=\"rgba(255,255,255,0.35)\" stroke-width=\"1\" x=\"1\" y=\"1\" width=\"1236\" height=\"72.4\" rx=\"8\"/><text class=\"terminal-3526644552-title\" fill=\"#c5c8c6\" text-anchor=\"middle\" x=\"618\" y=\"27\">Rich</text>\n            <g transform=\"translate(26,22)\">\n            <circle cx=\"0\" cy=\"0\" r=\"7\" fill=\"#ff5f57\"/>\n            <circle cx=\"22\" cy=\"0\" r=\"7\" fill=\"#febc2e\"/>\n            <circle cx=\"44\" cy=\"0\" r=\"7\" fill=\"#28c840\"/>\n            </g>\n        \n    <g transform=\"translate(9, 41)\" clip-path=\"url(#terminal-3526644552-clip-terminal)\">\n    <rect fill=\"#cc555a\" x=\"0\" y=\"1.5\" width=\"36.6\" height=\"24.65\" shape-rendering=\"crispEdges\"/>\n    <g class=\"terminal-3526644552-matrix\">\n    <text class=\"terminal-3526644552-r1\" x=\"0\" y=\"20\" textLength=\"36.6\" clip-path=\"url(#terminal-3526644552-line-0)\">foo</text><text class=\"terminal-3526644552-r2\" x=\"48.8\" y=\"20\" textLength=\"61\" clip-path=\"url(#terminal-3526644552-line-0)\">Click</text><text class=\"terminal-3526644552-r2\" x=\"1220\" y=\"20\" textLength=\"12.2\" clip-path=\"url(#terminal-3526644552-line-0)\">\n</text>\n    </g>\n    </g>\n</svg>\n"

///|
test "test_export_svg" {
  let console = record_console()
  console.print(
    "[b red on blue reverse]foo[/] [blink][link=https://example.org]Click[/link]",
  )
  let svg = console.export_svg()
  assert_eq(svg, expected_svg)
}

///|
test "test_export_svg_specified_unique_id" {
  let expected = expected_svg.replace_all(
    old="terminal-3526644552",
    new="given-id",
  )
  let console = record_console()
  console.print(
    "[b red on blue reverse]foo[/] [blink][link=https://example.org]Click[/link]",
  )
  let svg = console.export_svg(unique_id="given-id")
  assert_eq(svg, expected)
}

///|
fn temp_path(name : String) -> String {
  let dir = match @env.get_env_var("TMPDIR") {
    Some(d) if d != "" => d
    _ => "/tmp"
  }
  let dir = if dir.has_suffix("/") { dir } else { dir + "/" }
  dir + "rich_mbt_\{name}"
}

///|
#cfg(any(target="native", target="llvm"))
test "test_save_svg" {
  let console = record_console()
  console.print(
    "[b red on blue reverse]foo[/] [blink][link=https://example.org]Click[/link]",
  )
  let export_path = temp_path("example.svg")
  console.save_svg(export_path)
  assert_eq(@term.read_file(export_path), Some(expected_svg))
}

///|
#cfg(any(target="native", target="llvm"))
test "test_save_text" {
  let console = record_console()
  console.print("foo")
  let export_path = temp_path("rich.txt")
  console.save_text(export_path)
  assert_eq(@term.read_file(export_path), Some("foo\n"))
}

///|
#cfg(any(target="native", target="llvm"))
test "test_save_html" {
  let expected = "<!DOCTYPE html>\n<html>\n<head>\n<meta charset=\"UTF-8\">\n<style>\n\nbody {\n    color: #000000;\n    background-color: #ffffff;\n}\n</style>\n</head>\n<body>\n    <pre style=\"font-family:Menlo,'DejaVu Sans Mono',consolas,'Courier New',monospace\"><code style=\"font-family:inherit\">foo\n</code></pre>\n</body>\n</html>\n"
  let console = record_console()
  console.print("foo")
  let export_path = temp_path("example.html")
  console.save_html(export_path)
  assert_eq(@term.read_file(export_path), Some(expected))
}

///|
test "test_no_wrap" {
  let (console, file) = string_console(width=10, color_system=Some("auto"))
  console.print("foo bar baz egg", no_wrap=true)
  assert_eq(file.getvalue(), "foo bar ba\n")
}

///|
test "test_soft_wrap_print" {
  let (console, file) = string_console(width=10, color_system=Some("auto"))
  console.print("foo bar baz egg", soft_wrap=true)
  assert_eq(file.getvalue(), "foo bar baz egg\n")
}

// test_unicode_error: files are always UTF-8.

///|
test "test_bell" {
  let console = @rich.Console::new(force_terminal=true, environ={})
  console.begin_capture()
  console.bell()
  assert_eq(console.end_capture(), "\u{07}")
}

///|
struct MockPager {
  content : Ref[String?]
}

///|
impl @rich.Pager for MockPager with fn show(self, content) {
  self.content.val = Some(content)
}

///|
test "test_pager" {
  let console = @rich.Console::new(width=80, environ={})
  let pager_content : Ref[String?] = Ref(None)
  let pager = MockPager::{ content: pager_content, }
  console.pager(() => console.print("[bold]Hello World"), pager~)
  assert_eq(pager_content.val, Some("Hello World\n"))
  console.pager(
    () => console.print("[bold link https:/example.org]Hello World"),
    pager~,
    styles=true,
    links=false,
  )
  assert_eq(pager_content.val, Some("Hello World\n"))
}

///|
test "test_out" {
  let console = @rich.Console::new(width=10, environ={})
  console.begin_capture()
  console.out_many(Array::make(5, "foo bar"), sep=".", end="X")
  assert_eq(console.end_capture(), "foo bar.foo bar.foo bar.foo bar.foo barX")
}

///|
test "test_render_group" {
  let renderables : Array[&@rich.Renderable] = []
  for _ in 0..<4 {
    renderables.push(
      @rich.Group::new(["one", "two", "three", "four"], fit=false),
    )
  }
  let console = @rich.Console::new(width=42, environ={})
  let { minimum: min_width, .. } = @rich.measure_renderables(
    console,
    console.options(),
    renderables,
  )
  assert_eq(min_width, 42)
}

///|
test "test_render_group_fit" {
  let renderables : Array[&@rich.Renderable] = []
  for _ in 0..<4 {
    renderables.push(@rich.Group::new(["one", "two", "three", "four"]))
  }
  let console = @rich.Console::new(width=42, environ={})
  let { minimum: min_width, .. } = @rich.measure_renderables(
    console,
    console.options(),
    renderables,
  )
  assert_eq(min_width, 5)
}

///|
test "test_get_time" {
  let console = @rich.Console::new(get_time=() => 99.0, get_datetime=() => {
    142214400.0
  })
  assert_eq((console.get_time)(), 99.0)
  assert_eq((console.get_datetime)(), 142214400.0)
}

///|
test "test_console_style" {
  let (console, file) = string_console(force_terminal=true, style="red")
  console.print("foo")
  assert_eq(file.getvalue(), "\u{1b}[31mfoo\u{1b}[0m\n")
}

///|
test "test_no_color" {
  let (console, file) = string_console(force_terminal=true, no_color=true)
  console.print("[bold magenta on red]FOO")
  assert_eq(file.getvalue(), "\u{1b}[1mFOO\u{1b}[0m\n")
}

///|
test "test_quiet" {
  let (console, file) = string_console(quiet=true)
  console.print("Hello, World!")
  assert_eq(file.getvalue(), "")
}

///|
test "test_screen" {
  let console = @rich.Console::new(
    color_system=None,
    force_terminal=true,
    force_interactive=true,
    environ={},
  )
  let result = console.capture(() => {
    console.screen(_ => console.print("Don't panic"))
  })
  let expected = "\u{1b}[?1049h\u{1b}[H\u{1b}[?25lDon't panic\n\u{1b}[?1049l\u{1b}[?25h"
  assert_eq(result, expected)
}

///|
test "test_screen_update" {
  let console = @rich.Console::new(
    width=20,
    height=4,
    color_system=Some("truecolor"),
    force_terminal=true,
    environ={},
  )
  let result = console.capture(() => {
    console.screen(screen => {
      screen.update(renderables=["foo"], style="blue")
      screen.update(renderables=["bar"])
      screen.update()
    })
  })
  let expected = "\u{1b}[?1049h\u{1b}[H\u{1b}[?25l\u{1b}[34mfoo\u{1b}[0m\u{1b}[34m                 \u{1b}[0m\n\u{1b}[34m                    \u{1b}[0m\n\u{1b}[34m                    \u{1b}[0m\n\u{1b}[34m                    \u{1b}[0m\u{1b}[34mbar\u{1b}[0m\u{1b}[34m                 \u{1b}[0m\n\u{1b}[34m                    \u{1b}[0m\n\u{1b}[34m                    \u{1b}[0m\n\u{1b}[34m                    \u{1b}[0m\u{1b}[34mbar\u{1b}[0m\u{1b}[34m                 \u{1b}[0m\n\u{1b}[34m                    \u{1b}[0m\n\u{1b}[34m                    \u{1b}[0m\n\u{1b}[34m                    \u{1b}[0m\u{1b}[?1049l\u{1b}[?25h"
  assert_eq(result, expected)
}

///|
test "test_height" {
  let console = @rich.Console::new(width=80, height=46)
  assert_eq(console.height(), 46)
}

///|
test "test_columns_env" {
  let console = @rich.Console::new(
    environ={ "COLUMNS": "314" },
    legacy_windows=false,
  )
  assert_eq(console.width(), 314)
  // width take precedence
  let console = @rich.Console::new(
    width=40,
    environ={ "COLUMNS": "314" },
    legacy_windows=false,
  )
  assert_eq(console.width(), 40)
  // Should not fail
  ignore(
    @rich.Console::new(
      width=40,
      environ={ "COLUMNS": "broken" },
      legacy_windows=false,
    ),
  )
}

///|
test "test_lines_env" {
  let console = @rich.Console::new(environ={ "LINES": "220" })
  assert_eq(console.height(), 220)
  // height take precedence
  let console = @rich.Console::new(height=40, environ={ "LINES": "220" })
  assert_eq(console.height(), 40)
  // Should not fail
  ignore(@rich.Console::new(width=40, environ={ "LINES": "broken" }))
}

///|
test "test_screen_update_class" {
  let screen_update = @rich.ScreenUpdate::new(
    [[@rich.Segment::new("foo")], [@rich.Segment::new("bar")]],
    5,
    10,
  )
  assert_eq(screen_update.x, 5)
  assert_eq(screen_update.y, 10)
  let console = @rich.Console::new(force_terminal=true, environ={})
  console.begin_capture()
  console.print(screen_update)
  let result = console.end_capture()
  assert_eq(result, "\u{1b}[11;6Hfoo\u{1b}[12;6Hbar")
}

///|
test "test_is_alt_screen" {
  let console = @rich.Console::new(force_terminal=true, environ={})
  assert_true(!console.is_alt_screen())
  let inside = Ref(false)
  console.capture(() => {
    console.screen(_ => inside.val = console.is_alt_screen())
  })
  |> ignore
  assert_true(inside.val)
  assert_true(!console.is_alt_screen())
}

///|
test "test_set_console_title" {
  let console = @rich.Console::new(force_terminal=true, environ={})
  let result = console.capture(() => console.set_window_title("hello") |> ignore)
  assert_eq(result, "\u{1b}]0;hello\u{07}")
}

///|
test "test_update_screen" {
  let console = @rich.Console::new(force_terminal=true, width=20, height=5, environ={})
  try console.update_screen("foo") catch {
    @rich.NoAltScreen(_) => ()
    e => fail("unexpected error \{e}")
  } noraise {
    _ => fail("expected NoAltScreen")
  }
  console.begin_capture()
  console.screen(_ => {
    console.update_screen("foo")
    console.update_screen("bar", region={ x: 2, y: 3, width: 8, height: 4, })
  })
  let result = console.end_capture()
  let expected = "\u{1b}[?1049h\u{1b}[H\u{1b}[?25l\u{1b}[1;1Hfoo                 \u{1b}[2;1H                    \u{1b}[3;1H                    \u{1b}[4;1H                    \u{1b}[5;1H                    \u{1b}[4;3Hbar     \u{1b}[5;3H        \u{1b}[6;3H        \u{1b}[7;3H        \u{1b}[?1049l\u{1b}[?25h"
  assert_eq(result, expected)
}

///|
test "test_update_screen_lines" {
  let console = @rich.Console::new(force_terminal=true, width=20, height=5, environ={})
  try console.update_screen_lines([]) catch {
    @rich.NoAltScreen(_) => ()
    e => fail("unexpected error \{e}")
  } noraise {
    _ => fail("expected NoAltScreen")
  }
}

///|
test "test_update_options_markup" {
  let console = @rich.Console::new()
  let options = console.options()
  assert_eq(options.update(markup=Some(false)).markup, Some(false))
  assert_eq(options.update(markup=Some(true)).markup, Some(true))
}

///|
test "test_print_width_zero" {
  let console = @rich.Console::new(width=80)
  let result = console.capture(() => console.print("Hello", width=0))
  assert_eq(result, "")
}

///|
test "test_size_properties" {
  let console = @rich.Console::new(width=80, height=25, legacy_windows=false)
  assert_eq(console.size(), { width: 80, height: 25, })
  console.set_size(10, 20)
  assert_eq(console.size(), { width: 10, height: 20, })
  console.set_width(5)
  assert_eq(console.size(), { width: 5, height: 20, })
  console.set_height(10)
  assert_eq(console.size(), { width: 5, height: 10, })
}

///|
test "test_print_newline_start" {
  let console = @rich.Console::new(width=80, height=25)
  console.begin_capture()
  console.print("Foo", new_line_start=true)
  console.print("Foo\nbar\n", new_line_start=true)
  let result = console.end_capture()
  assert_eq(result, "Foo\n\nFoo\nbar\n\n")
}

// test_is_terminal_broken_file: `isatty` cannot raise.

///|
test "test_detect_color_system" {
  let console = @rich.Console::new(
    environ={ "TERM": "rxvt-unicode-256color" },
    force_terminal=true,
  )
  assert_true(console.color_system_enum() is Some(EightBit))
}

///|
struct Panels {}

///|
impl @rich.Renderable for Panels with fn rich_console(_self, _console, _options) {
  [Child(@panel.Panel::new("foo")), Child(@panel.Panel::new("bar"))]
}

///|
test "test_reset_height" {
  let console = @rich.Console::new(
    force_terminal=true,
    color_system=Some("truecolor"),
    width=20,
    height=40,
    legacy_windows=false,
    environ={},
  )
  let result = console.capture(() => {
    console.print(@panel.Panel::new(Panels::{ }), height=12)
  })
  let expected = "╭──────────────────╮\n│ ╭──────────────╮ │\n│ │ foo          │ │\n│ ╰──────────────╯ │\n│ ╭──────────────╮ │\n│ │ bar          │ │\n│ ╰──────────────╯ │\n│                  │\n│                  │\n│                  │\n│                  │\n╰──────────────────╯\n"
  assert_eq(result, expected)
}

///|
test "test_render_lines_height_minus_vertical_pad_is_negative" {
  let console = @rich.Console::new(
    force_terminal=true,
    color_system=Some("truecolor"),
    width=20,
    height=40,
    legacy_windows=false,
    environ={},
  )
  let options = console.options().update_height(1)
  // Ensuring that no exception is raised...
  console.render_lines(@rich.Padding::new("hello", pad=[1, 0]), options~)
  |> ignore
}

///|
test "test_recording_no_stdout_and_no_stderr_files" {
  let console = @rich.Console::new(
    record=true,
    file=@rich.NullFile::new(),
    width=80,
    environ={},
  )
  console.print("hello world")
  let text = console.export_text()
  assert_eq(text, "hello world\n")
}

///|
test "test_capturing_no_stdout_and_no_stderr_files" {
  let console = @rich.Console::new(file=@rich.NullFile::new(), width=80, environ={})
  let result = console.capture(() => console.print("hello world"))
  assert_eq(result, "hello world\n")
}

///|
test "test_force_color_jupyter" {
  // FORCE_COLOR above doesn't happen in a Jupyter kernel
  let console = @rich.Console::new(
    file=@rich.StringIO::new(),
    environ={ "FORCE_COLOR": "1" },
    force_jupyter=true,
  )
  assert_true(!console.is_terminal())
}

///|
test "test_force_color" {
  let console = @rich.Console::new(file=@rich.StringIO::new(), environ={
    "FORCE_COLOR": "1",
    "TERM": "xterm-256color",
    "COLORTERM": "truecolor",
  })
  assert_true(
    console.color_system() is Some("truecolor") ||
    console.color_system() is Some("windows"),
  )
}

///|
test "test_reenable_highlighting" {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    file~,
    environ={
      "FORCE_COLOR": "1",
      "TERM": "xterm-256color",
      "COLORTERM": "truecolor",
    },
    highlight=false,
  )
  console.print("[1, 2, 3]")
  console.print("[1, 2, 3]", highlight=true)
  let lines = file.getvalue().split("\n").map(s => s.to_owned()).collect()
  // First line not highlighted
  assert_eq(lines[0], "[1, 2, 3]")
  // Second line highlighted
  assert_eq(
    lines[1],
    "\u{1b}[1m[\u{1b}[0m\u{1b}[1;36m1\u{1b}[0m, \u{1b}[1;36m2\u{1b}[0m, \u{1b}[1;36m3\u{1b}[0m\u{1b}[1m]\u{1b}[0m",
  )
}

// test_brokenpipeerror: runs `python -m rich` in a subprocess.

///|
test "test_capture_and_record" {
  let console = record_console(width=80)
  console.print("[blue underline]Print 0")
  let capture_content = console.capture(() => {
    console.print("[blue underline]Print 1")
    console.print("[blue underline]Print 2")
    console.print("[blue underline]Print 3")
    console.print("[blue underline]Print 4")
  })
  assert_eq(capture_content, "Print 1\nPrint 2\nPrint 3\nPrint 4\n")
  let recorded_content = console.export_text()
  assert_eq(recorded_content, "Print 0\n")
}

///|
test "test_tty_interactive" {
  // Bytes file, not interactive
  let console = @rich.Console::new(file=@rich.StringIO::new(), environ={})
  assert_true(!console.is_interactive)
  // Bytes file, force interactive
  let console = @rich.Console::new(file=@rich.StringIO::new(), environ={
    "TTY_INTERACTIVE": "1",
  })
  assert_true(console.is_interactive)
  // Force tty compatible, should be interactive
  let console = @rich.Console::new(file=@rich.StringIO::new(), environ={
    "TTY_COMPATIBLE": "1",
  })
  assert_true(console.is_interactive)
  // Force tty compatible, force not interactive
  let console = @rich.Console::new(file=@rich.StringIO::new(), environ={
    "TTY_COMPATIBLE": "1",
    "TTY_INTERACTIVE": "0",
  })
  assert_true(!console.is_interactive)
  // Bytes file, Unknown value of TTY_INTERACTIVE should still auto-detect
  let console = @rich.Console::new(file=@rich.StringIO::new(), environ={
    "TTY_INTERACTIVE": "foo",
  })
  assert_true(!console.is_interactive)
}

///|
struct FakeFile {
  tty : Bool
  called_isatty : Ref[Bool]
}

///|
impl @rich.ConsoleFile for FakeFile with fn write(_self, _text) {
  ()
}

///|
impl @rich.ConsoleFile for FakeFile with fn isatty(self) {
  self.called_isatty.val = true
  self.tty
}

///|
fn fake_file(tty : Bool) -> FakeFile {
  { tty, called_isatty: Ref(false), }
}

///|
struct AsciiFile {
  buffer : StringBuilder
}

///|
impl @rich.ConsoleFile for AsciiFile with fn write(self, text) {
  self.buffer.write_string(text)
}

///|
impl @rich.ConsoleFile for AsciiFile with fn encoding(_self) {
  "ascii"
}

///|
test "ascii encoding substitutes boxes and rules" {
  // computed with upstream Rich and a file whose encoding is "ascii"
  let file = AsciiFile::{ buffer: StringBuilder(), }
  let console = @rich.Console::new(
    file~,
    width=20,
    color_system=None,
    legacy_windows=false,
    environ={},
  )
  assert_eq(console.encoding(), "ascii")
  let table = @rich.Table::new(headers=["a", "b"])
  table.add_row(["1", "2"])
  console.print(table)
  console.rule(title="x")
  console.print(@rich.Rule::new(characters="*"))
  console.print("café")
  assert_eq(
    file.buffer.to_string(),
    "+-------+\n| a | b |\n|---+---|\n| 1 | 2 |\n+-------+\n-------- x ---------\n********************\ncafé\n",
  )
}

///|
test "legacy windows boxes and windows colors" {
  // computed with upstream Rich
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    file~,
    width=20,
    color_system=Some("windows"),
    force_terminal=true,
    legacy_windows=true,
    environ={},
  )
  assert_eq(console.size(), { width: 20, height: 25, })
  let table = @rich.Table::new(headers=["a", "b"], border_style="#ff8800")
  table.add_row(["[on #123456]1", "[bold bright_red]2"])
  console.print(table)
  console.rule(title="x")
  assert_eq(
    file.getvalue(),
    "\u{1b}[33m┌───┬───┐\u{1b}[0m\n\u{1b}[33m│\u{1b}[0m\u{1b}[1m \u{1b}[0m\u{1b}[1ma\u{1b}[0m\u{1b}[1m \u{1b}[0m\u{1b}[33m│\u{1b}[0m\u{1b}[1m \u{1b}[0m\u{1b}[1mb\u{1b}[0m\u{1b}[1m \u{1b}[0m\u{1b}[33m│\u{1b}[0m\n\u{1b}[33m├───┼───┤\u{1b}[0m\n\u{1b}[33m│\u{1b}[0m \u{1b}[40m1\u{1b}[0m \u{1b}[33m│\u{1b}[0m \u{1b}[1;91m2\u{1b}[0m \u{1b}[33m│\u{1b}[0m\n\u{1b}[33m└───┴───┘\u{1b}[0m\n\u{1b}[92m──────── \u{1b}[0mx\u{1b}[92m ─────────\u{1b}[0m\n",
  )
}

///|
test "test_tty_compatible" {
  // Console file is not a TTY
  let file = fake_file(false)
  let console = @rich.Console::new(file~, environ={})
  // Not a TTY, so is_terminal should be False
  assert_true(!console.is_terminal())
  // Should have called isatty to auto-detect tty support
  assert_true(file.called_isatty.val)

  // Not a terminal
  let file = fake_file(false)
  let console = @rich.Console::new(file~, environ={ "TTY_COMPATIBLE": "1" })
  // env TTY_COMPATIBLE=1 should report that it is a terminal
  assert_true(console.is_terminal())
  // Should not have called file.isattry
  assert_true(!file.called_isatty.val)

  // File is a fake TTY
  let file = fake_file(true)
  let console = @rich.Console::new(file~, environ={})
  // Should report True
  assert_true(console.is_terminal())
  // Should have auto-detected
  assert_true(file.called_isatty.val)

  // File is a fake TTY
  let file = fake_file(true)
  let console = @rich.Console::new(file~, environ={ "TTY_COMPATIBLE": "" })
  // Blank TTY_COMPATIBLE should auto-detect, so is_terminal is True
  assert_true(console.is_terminal())
  // Should have auto-detected
  assert_true(file.called_isatty.val)

  // File is a fake TTY
  let file = fake_file(true)
  let console = @rich.Console::new(file~, environ={
    "TTY_COMPATIBLE": "whatever",
  })
  // Any pother value should auto-detect
  assert_true(console.is_terminal())
  // Should have auto-detected
  assert_true(file.called_isatty.val)

  // TTY_COMPATIBLE should override file.isattry
  let file = fake_file(true)
  let console = @rich.Console::new(file~, environ={ "TTY_COMPATIBLE": "0" })
  // Should report that it is *not* a terminal
  assert_true(!console.is_terminal())
  // Should not have auto-detected
  assert_true(!file.called_isatty.val)
}
