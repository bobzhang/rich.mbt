// Port of tests/test_containers.py.

///|
fn containers_console() -> @rich.Console raise {
  @rich.Console::new(file=@rich.StringIO::new(), width=80, environ={})
}

///|
test "renderables_measure" {
  let console = containers_console()
  let text = @rich.Text::new(text="foo")
  let renderables = @rich.Renderables::new(renderables=[text])
  let result = renderables.rich_measure(console, console.options())
  assert_eq(result, Some(@rich.Measurement::new(3, 3)))
  inspect(renderables.renderables.length(), content="1")
  match renderables.renderables[0].text_kind() {
    Text(t) => assert_true(physical_equal(t, text))
    _ => fail("expected the Text")
  }
}

///|
test "renderables_empty" {
  let console = containers_console()
  let renderables = @rich.Renderables::new()
  let result = renderables.rich_measure(console, console.options())
  assert_eq(result, Some(@rich.Measurement::new(1, 1)))
}

///|
test "lines_rich_console" {
  let console = containers_console()
  let lines = @rich.Lines::new([@rich.Text::new(text="foo")])
  let result = lines.rich_console(console, console.options())
  inspect(result.length(), content="1")
  match result[0] {
    Child(r) =>
      match r.text_kind() {
        Text(t) => assert_eq(t, @rich.Text::new(text="foo"))
        _ => fail("expected a Text")
      }
    Seg(_) => fail("expected a Text")
  }
}

///|
test "lines_justify" {
  let console = containers_console()
  let lines1 = @rich.Lines::new([
    @rich.Text::new(text="foo", style="b"),
    @rich.Text::new(text="test", style="b"),
  ])
  lines1.justify(console, 10, justify=Left)
  assert_eq(lines1.lines, [
    @rich.Text::new(text="foo       "),
    @rich.Text::new(text="test      "),
  ])
  lines1.justify(console, 10, justify=Center)
  assert_eq(lines1.lines, [
    @rich.Text::new(text="   foo    "),
    @rich.Text::new(text="   test   "),
  ])
  lines1.justify(console, 10, justify=Right)
  assert_eq(lines1.lines, [
    @rich.Text::new(text="       foo"),
    @rich.Text::new(text="      test"),
  ])
  let lines2 = @rich.Lines::new([
    @rich.Text::new(text="foo bar", style="b"),
    @rich.Text::new(text="test", style="b"),
  ])
  lines2.justify(console, 7, justify=Full)
  assert_eq(lines2.lines, [
    @rich.Text::new(text="foo bar", spans=[
      @rich.Span::new(0, 3, "b"),
      @rich.Span::new(3, 4, @rich.Style::parse("bold")),
      @rich.Span::new(4, 7, "b"),
    ]),
    @rich.Text::new(text="test"),
  ])
}

///|
test "lines copies its input" {
  let source = [@rich.Text::new(text="a")]
  let lines = @rich.Lines::new(source)
  lines.append(@rich.Text::new(text="b"))
  inspect(source.length(), content="1")
  inspect(lines.length(), content="2")
}

///|
test "lines repr" {
  let lines = @rich.Lines::new([@rich.Text::new(text="a", style="bold")])
  inspect(lines.repr(), content="Lines([<text 'a' [] 'bold'>])")
}
