// Port of tests/test_markup.py.

///|
/// Render markup and format it like `scripts/gen_markup_tests.py` (meta
/// tuples are shown as lists).
fn render_case(markup : String) -> String {
  try @rich.render_markup(markup) catch {
    MarkupError(msg) => "MarkupError: " + msg
    e => "unexpected error: \{e}"
  } noraise {
    t => {
      let spans = t
        .spans()
        .map(span => {
          match span.style {
            Def(s) => "Span(\{span.start}, \{span.end}, \{@rich.py_repr(s)})"
            Style(st) =>
              "Span(\{span.start}, \{span.end}, meta=\{@rich.py_json_repr(Json::object(st.meta()))})"
          }
        })
      "<text \{@rich.py_repr(t.plain())} [\{spans.join(", ")}] \{t.style.repr()}>"
    }
  }
}

///|
/// Upstream `RE_TAGS.match(s)`: does a tag start at position 0?
fn re_tags_match(s : String) -> Bool {
  match @rich.parse_markup(s) {
    [TagAt(0, _), ..] => true
    _ => false
  }
}

///|
fn tag(name : String, parameters? : String) -> @rich.Tag {
  { name, parameters, }
}

///|
test "re_no_match" {
  for s in ["[True]", "[False]", "[None]", "[1]", "[2]", "[]"] {
    assert_false(re_tags_match(s))
  }
}

///|
test "re_match" {
  for
    s in [
      "[true]", "[false]", "[none]", "[color(1)]", "[#ff00ff]", "[/]", "[@]", "[@foo]",
      "[@foo=bar]",
    ] {
    assert_true(re_tags_match(s))
  }
}

///|
test "escape" {
  // Potential tags
  inspect(@rich.escape("foo[bar]"), content="foo\\[bar]")
  inspect(@rich.escape("foo\\[bar]"), content="foo\\\\\\[bar]")
  // Not tags (escape not required)
  inspect(@rich.escape("[5]"), content="[5]")
  inspect(@rich.escape("\\[5]"), content="\\[5]")
  // Test @ escape
  inspect(@rich.escape("[@foo]"), content="\\[@foo]")
  inspect(@rich.escape("[@]"), content="\\[@]")
  // https://github.com/Textualize/rich/issues/2187
  inspect(@rich.escape("[nil, [nil]]"), content="[nil, \\[nil]]")
}

///|
test "escape_backslash_end" {
  // https://github.com/Textualize/rich/issues/2987
  let value = "C:\\"
  assert_eq(@rich.escape(value), "C:\\\\")
  let escaped_tags = "[red]\{@rich.escape(value)}[/red]"
  assert_eq(escaped_tags, "[red]C:\\\\[/red]")
  let escaped_text = @rich.Text::from_markup(escaped_tags)
  assert_eq(escaped_text.plain(), "C:\\")
  assert_eq(escaped_text.spans(), [@rich.Span::new(0, 3, "red")])
}

///|
test "render_escape" {
  let console = @rich.Console::new(
    width=80,
    color_system=None,
    file=@rich.StringIO::new(),
    environ={},
  )
  console.begin_capture()
  console.print_many([
    @rich.escape("[red]"),
    @rich.escape("\\[red]"),
    @rich.escape("\\\\[red]"),
    @rich.escape("\\\\\\[red]"),
  ])
  let result = console.end_capture()
  assert_eq(result, "[red] \\[red] \\\\[red] \\\\\\[red]\n")
}

///|
test "parse" {
  let result = @rich.parse_markup("[foo]hello[/foo][bar]world[/]\\[escaped]")
  assert_eq(result, [
    TagAt(0, tag("foo")),
    PlainText(10, "hello"),
    TagAt(10, tag("/foo")),
    TagAt(16, tag("bar")),
    PlainText(26, "world"),
    TagAt(26, tag("/")),
    PlainText(29, "[escaped]"),
  ])
}

///|
test "parse_link" {
  let result = @rich.parse_markup("[link=foo]bar[/link]")
  assert_eq(result, [
    TagAt(0, tag("link", parameters="foo")),
    PlainText(13, "bar"),
    TagAt(13, tag("/link")),
  ])
}

///|
test "render" {
  let result = @rich.render_markup("[bold]FOO[/bold]")
  inspect(result, content="FOO")
  assert_eq(result.spans(), [@rich.Span::new(0, 3, "bold")])
}

///|
test "render_not_tags" {
  let result = @rich.render_markup(
    "[[1], [1,2,3,4], [\"hello\"], [None], [False], [True]] []",
  )
  assert_eq(
    result.plain(),
    "[[1], [1,2,3,4], [\"hello\"], [None], [False], [True]] []",
  )
  assert_eq(result.spans(), [])
}

///|
test "render_link" {
  let result = @rich.render_markup("[link=foo]FOO[/link]")
  inspect(result, content="FOO")
  assert_eq(result.spans(), [@rich.Span::new(0, 3, "link foo")])
}

///|
test "render_combine" {
  let result = @rich.render_markup("[green]X[blue]Y[/blue]Z[/green]")
  inspect(result, content="XYZ")
  assert_eq(result.spans(), [
    @rich.Span::new(0, 3, "green"),
    @rich.Span::new(1, 2, "blue"),
  ])
}

///|
test "render_overlap" {
  let result = @rich.render_markup("[green]X[bold]Y[/green]Z[/bold]")
  inspect(result, content="XYZ")
  assert_eq(result.spans(), [
    @rich.Span::new(0, 2, "green"),
    @rich.Span::new(1, 3, "bold"),
  ])
}

///|
test "adjoint" {
  let result = @rich.render_markup("[red][blue]B[/blue]R[/red]")
  assert_eq(result.spans(), [
    @rich.Span::new(0, 2, "red"),
    @rich.Span::new(0, 1, "blue"),
  ])
}

///|
test "render_close" {
  let result = @rich.render_markup("[bold]X[/]Y")
  inspect(result, content="XY")
  assert_eq(result.spans(), [@rich.Span::new(0, 1, "bold")])
}

///|
test "render_close_ambiguous" {
  let result = @rich.render_markup("[green]X[bold]Y[/]Z[/]")
  inspect(result, content="XYZ")
  assert_eq(result.spans(), [
    @rich.Span::new(0, 3, "green"),
    @rich.Span::new(1, 2, "bold"),
  ])
}

///|
test "markup_error" {
  for markup in ["foo[/]", "foo[/bar]", "[foo]hello[/bar]"] {
    try @rich.render_markup(markup) catch {
      MarkupError(_) => ()
      e => fail("unexpected \{e}")
    } noraise {
      _ => fail("expected MarkupError for \{markup}")
    }
  }
}

///|
test "markup_escape" {
  let result = @rich.render_markup("[dim white][url=[/]").plain()
  assert_eq(result, "[url=")
}

///|
test "escape_escape" {
  // Escaped escapes (i.e. double backslash) should be treated as literal
  assert_eq(@rich.render_markup("\\\\[bold]FOO").plain(), "\\FOO")
  // Single backslash makes the tag literal
  assert_eq(@rich.render_markup("\\[bold]FOO").plain(), "[bold]FOO")
  // Double backslash produces a backslash
  assert_eq(
    @rich.render_markup("\\\\[bold]some text[/]").plain(),
    "\\some text",
  )
  // Triple backslash parsed as literal backslash plus escaped tag
  assert_eq(
    @rich.render_markup("\\\\\\[bold]some text\\[/]").plain(),
    "\\[bold]some text[/]",
  )
  // Backslash escaping only happens when preceding a tag
  assert_eq(@rich.render_markup("\\\\").plain(), "\\\\")
  assert_eq(@rich.render_markup("\\\\\\\\").plain(), "\\\\\\\\")
}

///|
test "events" {
  let result = @rich.render_markup(
    "[@click]Hello[/@click] [@click='view.toggle', 'left']World[/]",
  )
  inspect(result, content="Hello World")
}

///|
test "events_broken" {
  for markup in ["[@click=sdfwer(sfs)]foo[/]", "[@click='view.toggle]foo[/]"] {
    try @rich.render_markup(markup) catch {
      MarkupError(_) => ()
      e => fail("unexpected \{e}")
    } noraise {
      _ => fail("expected MarkupError for \{markup}")
    }
  }
}

///|
test "render_meta" {
  let console = @rich.Console::new(file=@rich.StringIO::new(), environ={})
  fn meta(markup : String) -> Json raise {
    let text = @rich.render_markup(markup)
    Json::object(text.get_style_at_offset(console, 3).meta())
  }

  // upstream tuples are JSON arrays
  json_inspect(meta("foo[@click=close]bar[/]baz"), content={
    "@click": ["close", []],
  })
  json_inspect(meta("foo[@click=close()]bar[/]baz"), content={
    "@click": ["close", []],
  })
  json_inspect(meta("foo[@click=close('dialog')]bar[/]baz"), content={
    "@click": ["close", ["dialog"]],
  })
  json_inspect(meta("foo[@click=close('dialog', 3)]bar[/]baz"), content={
    "@click": ["close", ["dialog", 3]],
  })
  json_inspect(meta("foo[@click=(1, 2, 3)]bar[/]baz"), content={
    "@click": [1, 2, 3],
  })
}

///|
test "tag" {
  inspect(tag("bold"), content="bold")
  inspect(tag("link", parameters="foo"), content="link foo")
  inspect(tag("bold").markup(), content="[bold]")
  inspect(tag("link", parameters="foo").markup(), content="[link=foo]")
}
