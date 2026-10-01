// Port of upstream tests/test_syntax.py (expected strings are in
// upstream_expected_test.mbt).

///|
fn render(
  renderable : &@rich.Renderable,
  no_wrap? : Bool = false,
) -> String raise {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    width=100,
    file~,
    color_system=Some("truecolor"),
    legacy_windows=false,
    environ={},
  )
  console.print(renderable, no_wrap~)
  file.getvalue()
}

///|
fn assert_style(actual : @rich.Style, expected : @rich.Style) -> Unit raise {
  if actual != expected {
    fail("\{actual.repr()} != \{expected.repr()}")
  }
}

///|
test "blank_lines" {
  let syntax = @syntax.Syntax::new(
    "\n\nimport this\n\n",
    "python",
    theme="ascii_light",
    code_width=30,
    line_numbers=true,
  )
  assert_eq(render(syntax), expected_blank_lines)
}

///|
test "python_render" {
  let syntax = @panel.Panel::fit(
    @syntax.Syntax::new(
      code,
      "python",
      line_numbers=true,
      line_range=(Some(2), Some(10)),
      theme="monokai",
      code_width=60,
      word_wrap=true,
    ),
    padding=[0],
  )
  assert_eq(render(syntax), expected_python_render)
}

///|
test "python_render_simple" {
  let syntax = @syntax.Syntax::new(
    code,
    "python",
    line_numbers=false,
    theme="monokai",
    code_width=60,
    word_wrap=false,
  )
  assert_eq(render(syntax), expected_python_render_simple)
}

///|
test "python_render_simple_passing_lexer_instance" {
  let syntax = @syntax.Syntax::new(
    code,
    @lexers.python_lexer(),
    line_numbers=false,
    theme="monokai",
    code_width=60,
    word_wrap=false,
  )
  assert_eq(
    render(syntax),
    expected_python_render_simple_passing_lexer_instance,
  )
}

///|
test "python_render_simple_indent_guides" {
  let syntax = @syntax.Syntax::new(
    code,
    "python",
    line_numbers=false,
    theme="ansi_light",
    code_width=60,
    word_wrap=false,
    indent_guides=true,
  )
  assert_eq(render(syntax), expected_python_render_simple_indent_guides)
}

///|
test "python_render_line_range_indent_guides" {
  let syntax = @syntax.Syntax::new(
    code,
    "python",
    line_numbers=false,
    theme="ansi_light",
    code_width=60,
    word_wrap=false,
    line_range=(Some(2), Some(3)),
    indent_guides=true,
  )
  assert_eq(render(syntax), expected_python_render_line_range_indent_guides)
}

///|
test "python_render_indent_guides" {
  let syntax = @panel.Panel::fit(
    @syntax.Syntax::new(
      code,
      "python",
      line_numbers=true,
      line_range=(Some(2), Some(10)),
      theme="monokai",
      code_width=60,
      word_wrap=true,
      indent_guides=true,
    ),
    padding=[0],
  )
  assert_eq(render(syntax), expected_python_render_indent_guides)
}

///|
test "pygments_syntax_theme_non_str" {
  let style = @syntax.PygmentsSyntaxTheme::from_style(@styles.Style::new([]))
  assert_eq(
    @syntax.SyntaxTheme::get_background_style(style).bgcolor(),
    Some(@color.Color::parse("#ffffff")),
  )
}

///|
test "pygments_syntax_theme" {
  let style = @syntax.PygmentsSyntaxTheme::new("default")
  assert_style(
    @syntax.SyntaxTheme::get_style_for_token(style, @token.from_string("abc")),
    @rich.Style::parse("none"),
  )
}

///|
test "get_line_color_none" {
  let style = @syntax.PygmentsSyntaxTheme::new("default")
  style.background_style = @rich.Style::new()
  let syntax = @syntax.Syntax::new(
    code,
    "python",
    line_numbers=true,
    line_range=(Some(2), Some(10)),
    theme=style,
    code_width=60,
    word_wrap=true,
    background_color="red",
  )
  assert_eq(syntax.get_line_numbers_color(), @color.Color::default())
}

///|
test "highlight_background_color" {
  let syntax = @syntax.Syntax::new(
    code,
    "python",
    line_numbers=true,
    line_range=(Some(2), Some(10)),
    theme="foo",
    code_width=60,
    word_wrap=true,
    background_color="red",
  )
  guard syntax.highlight(code).style is Style(style) else {
    fail("not a Style")
  }
  assert_style(style, @rich.Style::parse("on red"))
}

///|
test "get_number_styles" {
  let syntax = @syntax.Syntax::new(
    code,
    "python",
    theme="monokai",
    line_numbers=true,
  )
  let console = @rich.Console::new(color_system=Some("windows"), environ={})
  let (background, number, highlight_number) = syntax.get_number_styles(console)
  assert_style(background, @rich.Style::parse("on #272822"))
  assert_style(number, @rich.Style::parse("dim on #272822"))
  assert_style(highlight_number, @rich.Style::parse("not dim on #272822"))
}

///|
test "get_style_for_token" {
  let style = @syntax.PygmentsSyntaxTheme::new("default")
  style.style_cache = Map::from_array([(@token.text, @rich.Style::new())])
  let syntax = @syntax.Syntax::new(
    code,
    "python",
    line_numbers=true,
    line_range=(Some(2), Some(10)),
    theme=style,
    code_width=60,
    word_wrap=true,
    background_color="red",
  )
  assert_eq(syntax.get_line_numbers_color(), @color.Color::default())
}

///|
test "option_no_wrap" {
  let syntax = @syntax.Syntax::new(
    code,
    "python",
    line_numbers=true,
    line_range=(Some(2), Some(10)),
    code_width=60,
    word_wrap=false,
    background_color="red",
  )
  assert_eq(render(syntax, no_wrap=true), expected_option_no_wrap)
}

///|
test "syntax_highlight_ranges" {
  let syntax = @syntax.Syntax::new(
    code,
    "python",
    line_numbers=true,
    word_wrap=false,
  )
  let stylized_ranges : Array[(@rich.Style, (Int, Int), (Int, Int))] = [
    // overline the 2nd char of the 1st line:
    (@rich.Style::new(overline=true), (1, 1), (1, 2)),
    (
      @rich.Style::new(underline=true),
      (1, "def loop_".length()),
      (1, "def loop_first_last".length()),
    ),
    (
      @rich.Style::new(bold=true),
      (1, "def loop_first".length()),
      (3, "    iter_values = iter".length()),
    ),
    (
      @rich.Style::new(strike=true),
      (9, "    for ".length()),
      (9, "    for value in".length()),
    ),
    (
      @rich.Style::new(reverse=true),
      (6, "    except ".length()),
      (6, "    except StopIteration".length()),
    ),
    // `column_index` is out of range: should be clamped to the line length:
    (
      @rich.Style::new(bold=true),
      (10, "       yield first,".length()),
      (10, 300),
    ),
    // For this one the end `line_number` is out of range, so it should have no impact:
    (@rich.Style::new(bold=true), (1, 1), (30, 2)),
  ]
  for range in stylized_ranges {
    let (style, start, end) = range
    syntax.stylize_range(style, start, end)
  }
  assert_eq(render(syntax, no_wrap=true), expected_syntax_highlight_ranges)
}

///|
test "ansi_theme" {
  let style = @rich.Style::parse("red")
  let theme = @syntax.ANSISyntaxTheme::new(
    Map::from_array([(@token.from_string("foo.bar"), style)]),
  )
  assert_style(
    @syntax.SyntaxTheme::get_style_for_token(
      theme,
      @token.from_string("foo.bar.baz"),
    ),
    style,
  )
  assert_style(
    @syntax.SyntaxTheme::get_background_style(theme),
    @rich.Style::new(),
  )
}

///|
#cfg(target="native")
fn with_temp_file(
  suffix : String,
  content : String,
  f : (String) -> Unit raise,
) -> Unit raise {
  let path = "/tmp/rich_mbt_syntax_test_\{suffix}"
  assert_true(@fs.write_file(path, content))
  defer @fs.remove_file(path) |> ignore
  f(path)
}

///|
#cfg(target="native")
test "from_path" {
  with_temp_file("example.py", "import this\n", path => {
    let syntax = @syntax.Syntax::from_path(path)
    assert_eq(syntax.lexer().map(l => l.name()), Some("Python"))
    assert_eq(syntax.code, "import this\n")
  })
}

///|
#cfg(target="native")
test "from_path_unknown_lexer" {
  with_temp_file("example.nosuchtype", "import this\n", path => {
    let syntax = @syntax.Syntax::from_path(path)
    assert_true(syntax.lexer() is None)
    assert_eq(syntax.code, "import this\n")
  })
}

///|
#cfg(target="native")
test "from_path_lexer_override" {
  with_temp_file("example2.nosuchtype", "import this\n", path => {
    let syntax = @syntax.Syntax::from_path(path, lexer="rust")
    assert_eq(syntax.lexer().map(l => l.name()), Some("Rust"))
    assert_eq(syntax.code, "import this\n")
  })
}

///|
#cfg(target="native")
test "from_path_lexer_override_invalid_lexer" {
  with_temp_file("example3.nosuchtype", "import this\n", path => {
    let syntax = @syntax.Syntax::from_path(path, lexer="blah")
    assert_true(syntax.lexer() is None)
    assert_eq(syntax.code, "import this\n")
  })
}

///|
test "syntax_guess_lexer" {
  assert_eq(@syntax.Syntax::guess_lexer("banana.py"), "python")
  assert_eq(
    @syntax.Syntax::guess_lexer("banana.py", code="import this"),
    "python",
  )
  assert_eq(
    @syntax.Syntax::guess_lexer("banana.html", code="<a href='#'>hello</a>"),
    "html",
  )
  assert_eq(
    @syntax.Syntax::guess_lexer("banana.html", code="<%= @foo %>"),
    "rhtml",
  )
  assert_eq(
    @syntax.Syntax::guess_lexer("banana.html", code="{{something|filter:3}}"),
    "html+django",
  )
}

///|
test "syntax_padding" {
  let syntax = @syntax.Syntax::new("x = 1", "python", padding=[1, 3])
  let console = @rich.Console::new(
    width=20,
    file=@rich.StringIO::new(),
    color_system=Some("truecolor"),
    legacy_windows=false,
    record=true,
    environ={},
  )
  console.print(syntax)
  let output = console.export_text()
  assert_eq(output, expected_syntax_padding)
}

///|
test "syntax_measure" {
  let console = @rich.Console::new(environ={})
  let code = @syntax.Syntax::new("Hello, World", "python")
  assert_eq(
    @rich.Renderable::rich_measure(code, console, console.options()),
    Some(@rich.Measurement::new(0, 12)),
  )
  let code = @syntax.Syntax::new("Hello, World", "python", line_numbers=true)
  assert_eq(
    @rich.Renderable::rich_measure(code, console, console.options()),
    Some(@rich.Measurement::new(3, 16)),
  )
  let code = @syntax.Syntax::new(
    "Hello, World",
    "python",
    code_width=20,
    line_numbers=true,
  )
  assert_eq(
    @rich.Renderable::rich_measure(code, console, console.options()),
    Some(@rich.Measurement::new(3, 24)),
  )
  let code = @syntax.Syntax::new("", "python", code_width=20, line_numbers=true)
  assert_eq(
    @rich.Renderable::rich_measure(code, console, console.options()),
    Some(@rich.Measurement::new(3, 24)),
  )
}

///|
test "background_color_override_includes_padding" {
  let syntax = @syntax.Syntax::new(
    "x = 1",
    "python",
    padding=[1, 3],
    background_color="red",
  )
  assert_eq(render(syntax), expected_background_color_override_includes_padding)
}

///|
test "padding_plus_wrap" {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(width=24, file~, legacy_windows=false, environ={})
  let syntax = @syntax.Syntax::new(
    "'Hello, World. This should wrap.'",
    "python",
    padding=[0, 3],
    word_wrap=true,
  )
  console.print(syntax)
  assert_eq(file.getvalue(), expected_padding_plus_wrap)
}
