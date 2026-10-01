// Port of tests/test_style.py.

///|
fn color(name : String) -> @color.Color {
  @color.Color::parse(name) catch {
    _ => abort("bad color")
  }
}

///|
fn parse_style(s : String) -> @rich.Style raise @rich.RichError {
  @rich.Style::parse(s)
}

///|
test "str" {
  inspect(@rich.Style::new(bold=false), content="not bold")
  inspect(
    @rich.Style::new(color=color("red"), bold=false),
    content="not bold red",
  )
  inspect(
    @rich.Style::new(color=color("red"), bold=false, italic=true),
    content="not bold italic red",
  )
  inspect(@rich.Style::new(), content="none")
  inspect(@rich.Style::new(bold=true), content="bold")
  inspect(@rich.Style::new(color=color("red"), bold=true), content="bold red")
  inspect(
    @rich.Style::new(color=color("red"), bgcolor=color("black"), bold=true),
    content="bold red on black",
  )
  let all_styles = @rich.Style::new(
    color=color("red"),
    bgcolor=color("black"),
    bold=true,
    dim=true,
    italic=true,
    underline=true,
    blink=true,
    blink2=true,
    reverse=true,
    conceal=true,
    strike=true,
    underline2=true,
    frame=true,
    encircle=true,
    overline=true,
  )
  inspect(
    all_styles,
    content="bold dim italic underline blink blink2 reverse conceal strike underline2 frame encircle overline red on black",
  )
  inspect(@rich.Style::new(link="foo"), content="link foo")
}

///|
test "ansi_codes" {
  let all_styles = @rich.Style::new(
    color=color("red"),
    bgcolor=color("black"),
    bold=true,
    dim=true,
    italic=true,
    underline=true,
    blink=true,
    blink2=true,
    reverse=true,
    conceal=true,
    strike=true,
    underline2=true,
    frame=true,
    encircle=true,
    overline=true,
  )
  assert_eq(
    all_styles.render(text="x"),
    "\u{1b}[1;2;3;4;5;6;7;8;9;21;51;52;53;31;40mx\u{1b}[0m",
  )
}

///|
test "repr" {
  inspect(
    @rich.Style::new(bold=true, color=color("red")).repr(),
    content="Style(color=Color('red', ColorType.STANDARD, number=1), bold=True)",
  )
}

///|
test "eq" {
  assert_true(
    @rich.Style::new(bold=true, color=color("red")) ==
    @rich.Style::new(bold=true, color=color("red")),
  )
  assert_true(
    @rich.Style::new(bold=true, color=color("red")) !=
    @rich.Style::new(bold=true, color=color("green")),
  )
}

///|
test "hash" {
  let _ : Int = @rich.Style::new().hash()
}

///|
test "empty" {
  assert_true(@rich.Style::null() == @rich.Style::new())
}

///|
test "bool" {
  assert_false(@rich.Style::new().to_bool())
  assert_true(@rich.Style::new(bold=true).to_bool())
  assert_true(@rich.Style::new(color=color("red")).to_bool())
  assert_false(parse_style("").to_bool())
}

///|
test "color_property" {
  assert_eq(
    @rich.Style::new(color=color("red")).color(),
    Some(@color.Color::new("red", Standard, number=1)),
  )
}

///|
test "bgcolor_property" {
  assert_eq(
    @rich.Style::new(bgcolor=color("black")).bgcolor(),
    Some(@color.Color::new("black", Standard, number=0)),
  )
}

///|
test "parse" {
  assert_true(parse_style("") == @rich.Style::new())
  assert_true(parse_style("red") == @rich.Style::new(color=color("red")))
  assert_true(parse_style("not bold") == @rich.Style::new(bold=false))
  assert_true(
    parse_style("bold red on black") ==
    @rich.Style::new(color=color("red"), bgcolor=color("black"), bold=true),
  )
  assert_true(
    parse_style("bold link https://example.org") ==
    @rich.Style::new(bold=true, link="https://example.org"),
  )
  for bad in ["on", "on nothing", "rgb(999,999,999)", "not monkey", "link"] {
    try parse_style(bad) catch {
      StyleSyntaxError(_) => ()
      e => fail("unexpected error \{e}")
    } noraise {
      _ => fail("expected StyleSyntaxError for \{bad}")
    }
  }
}

///|
test "parse errors" {
  // messages (checked against the Python oracle)
  fn msg(s : String) -> String {
    try parse_style(s) catch {
      e => e.to_string()
    } noraise {
      _ => "no error"
    }
  }

  inspect(msg("on"), content="color expected after 'on'")
  inspect(
    msg("on nothing"),
    content="unable to parse 'nothing' as background color; 'nothing' is not a valid color",
  )
  inspect(
    msg("rgb(999,999,999)"),
    content="unable to parse 'rgb(999,999,999)' as color; color components must be <= 255 in 'rgb(999,999,999)'",
  )
  inspect(
    msg("not monkey"),
    content="expected style attribute after 'not', found 'monkey'",
  )
  inspect(msg("link"), content="URL expected after 'link'")
  inspect(
    msg("not BOLD"),
    content="expected style attribute after 'not', found 'BOLD'",
  )
}

///|
test "link_id" {
  assert_eq(@rich.Style::new().link_id(), "")
  assert_eq(parse_style("").link_id(), "")
  assert_eq(parse_style("red").link_id(), "")
  let style = parse_style("red link https://example.org")
  assert_true(style.link_id().length() > 1)
}

///|
test "get_html_style" {
  let html_style = @rich.Style::new(
    reverse=true,
    dim=true,
    color=color("red"),
    bgcolor=color("blue"),
    bold=true,
    italic=true,
    underline=true,
    strike=true,
    overline=true,
  ).get_html_style()
  inspect(
    html_style,
    content="color: #7f7fbf; text-decoration-color: #7f7fbf; background-color: #800000; font-weight: bold; font-style: italic; text-decoration: underline; text-decoration: line-through; text-decoration: overline",
  )
}

///|
test "chain" {
  assert_true(
    @rich.Style::chain([
      @rich.Style::new(color=color("red")),
      @rich.Style::new(bold=true),
    ]) ==
    @rich.Style::new(color=color("red"), bold=true),
  )
}

///|
test "copy" {
  let style = @rich.Style::new(
    color=color("red"),
    bgcolor=color("black"),
    italic=true,
  )
  assert_true(style == style.copy())
  assert_false(physical_equal(style, style.copy()))
}

///|
test "render" {
  inspect(
    @rich.Style::new(color=color("red")).render(text="foo", color_system=None),
    content="foo",
  )
  assert_eq(
    @rich.Style::new(color=color("red"), bgcolor=color("black"), bold=true).render(
      text="foo",
    ),
    "\u{1b}[1;31;40mfoo\u{1b}[0m",
  )
  inspect(@rich.Style::new().render(text="foo"), content="foo")
}

///|
test "add" {
  assert_true(
    @rich.Style::new(color=color("red")).add_opt(None) ==
    @rich.Style::new(color=color("red")),
  )
}

///|
test "iadd" {
  let mut style = @rich.Style::new(color=color("red"))
  style = style + @rich.Style::new(bold=true)
  assert_true(style == @rich.Style::new(color=color("red"), bold=true))
  style = style.add_opt(None)
  assert_true(style == @rich.Style::new(color=color("red"), bold=true))
}

///|
test "style_stack" {
  let stack = @rich.StyleStack::new(@rich.Style::new(color=color("red")))
  inspect(
    stack.repr(),
    content="<stylestack [Style(color=Color('red', ColorType.STANDARD, number=1))]>",
  )
  assert_true(stack.current() == @rich.Style::new(color=color("red")))
  stack.push(@rich.Style::new(bold=true))
  assert_true(
    stack.current() == @rich.Style::new(color=color("red"), bold=true),
  )
  stack.pop() |> ignore
  assert_true(stack.current() == @rich.Style::new(color=color("red")))
}

///|
test "pick_first" {
  try @rich.Style::pick_first([]) catch {
    ValueError(msg) =>
      inspect(msg, content="expected at least one non-None style")
    e => fail("unexpected \{e}")
  } noraise {
    _ => fail("expected ValueError")
  }
  inspect(
    @rich.Style::pick_first([None, Some(Def("bold")), Some(Def("red"))]),
    content="bold",
  )
}

///|
test "background_style" {
  assert_true(
    @rich.Style::new(bold=true, color=color("yellow"), bgcolor=color("red")).background_style() ==
    @rich.Style::new(bgcolor=color("red")),
  )
}

///|
test "without_color" {
  let style = @rich.Style::new(
    bold=true,
    color=color("red"),
    bgcolor=color("blue"),
  )
  let colorless_style = style.without_color()
  assert_eq(colorless_style.color(), None)
  assert_eq(colorless_style.bgcolor(), None)
  assert_eq(colorless_style.bold(), Some(true))
  let null_style = @rich.Style::null()
  assert_true(null_style.without_color() == null_style)
}

///|
test "meta" {
  let mut style = @rich.Style::new(bold=true, meta={ "foo": "bar" })
  assert_eq(style.meta()["foo"], "bar")
  style = style + @rich.Style::new(meta={ "egg": "baz" })
  assert_eq(style.meta(), { "foo": "bar", "egg": "baz" })
  inspect(
    style.repr(),
    content="Style(bold=True, meta={'foo': 'bar', 'egg': 'baz'})",
  )
}

///|
test "from_meta" {
  let style = @rich.Style::from_meta(Some({ "foo": "bar" }))
  assert_eq(style.color(), None)
  assert_eq(style.bold(), None)
}

///|
test "on" {
  let style = @rich.Style::on(meta={ "foo": "bar" }, handlers={
      "click": "CLICK",
    }) +
    @rich.Style::new(color=color("red"))
  assert_eq(style.meta(), { "foo": "bar", "@click": "CLICK" })
}

///|
test "clear_meta_and_links" {
  let style = parse_style("bold red on black link https://example.org") +
    @rich.Style::on(handlers={ "click": "CLICK" })
  assert_eq(style.meta(), { "@click": "CLICK" })
  assert_eq(style.link(), Some("https://example.org"))
  assert_eq(style.color(), Some(color("red")))
  assert_eq(style.bgcolor(), Some(color("black")))
  assert_eq(style.bold(), Some(true))
  assert_true(style.italic() is (None | Some(false)))
  let clear_style = style.clear_meta_and_links()
  assert_eq(clear_style.meta(), {})
  assert_eq(clear_style.link(), None)
  assert_eq(clear_style.color(), Some(color("red")))
  assert_eq(clear_style.bgcolor(), Some(color("black")))
  assert_eq(clear_style.bold(), Some(true))
  assert_true(clear_style.italic() is (None | Some(false)))
}

///|
test "normalize" {
  // differential cases (Python oracle)
  inspect(@rich.Style::normalize("bold  red"), content="bold red")
  inspect(@rich.Style::normalize("B I"), content="bold italic")
  inspect(@rich.Style::normalize(" FOO bar "), content="foo bar")
  inspect(@rich.Style::normalize("on red bold"), content="bold on red")
}
