// Port of tests/test_layout.py.

///|
test "no layout" {
  let layout = @layout.Layout::new()
  try
    layout.split(
      [@layout.Layout::new(), @layout.Layout::new()],
      splitter="nope",
    )
  catch {
    NoSplitter(msg) => assert_eq(msg, "No splitter called 'nope'")
    e => fail("unexpected error \{e}")
  } noraise {
    _ => fail("expected NoSplitter")
  }
}

///|
test "add split" {
  let layout = @layout.Layout::new()
  layout.split([@layout.Layout::new(), @layout.Layout::new()])
  assert_eq(layout.children().length(), 2)
  layout.add_split([@layout.Layout::new(name="foo")])
  assert_eq(layout.children().length(), 3)
  assert_eq(layout.children()[2].name, Some("foo"))
}

///|
test "unsplit" {
  let layout = @layout.Layout::new()
  layout.split([@layout.Layout::new(), @layout.Layout::new()])
  assert_eq(layout.children().length(), 2)
  layout.unsplit()
  assert_eq(layout.children().length(), 0)
}

///|
test "render" {
  let layout = @layout.Layout::new(name="root")
  inspect(layout, content="Layout(name='root')")
  layout.split_column([
    @layout.Layout::new(name="top"),
    @layout.Layout::new(name="bottom"),
  ])
  let top = layout["top"]
  let panel = @panel.Panel::new("foo")
  top.update(panel)
  // upstream: `top.renderable is panel` (trait objects are re-boxed on some
  // backends, so compare the rendering instead of identity)
  let console = @rich.Console::new(width=20, file=@rich.StringIO::new())
  assert_eq(
    console.capture(() => console.print(top.renderable())),
    console.capture(() => console.print(panel)),
  )
  layout["bottom"].split_row([
    @layout.Layout::new(name="left"),
    @layout.Layout::new(name="right"),
  ])
  assert_eq(layout["root"].name, Some("root"))
  assert_eq(layout["left"].name, Some("left"))
  assert_eq(layout.map().length(), 0)
  try top["asdasd"] catch {
    KeyError(msg) => assert_eq(msg, "No layout with name 'asdasd'")
    e => fail("unexpected error \{e}")
  } noraise {
    _ => fail("expected KeyError")
  }
  layout["left"].update("foobar")
  let console = @rich.Console::new(width=60, color_system=None, environ={})
  let result = console.capture(() => console.print(layout, height=10))
  let expected = "╭──────────────────────────────────────────────────────────╮\n│ foo                                                      │\n│                                                          │\n│                                                          │\n╰──────────────────────────────────────────────────────────╯\nfoobar                        ╭───── 'right' (30 x 5) ─────╮\n                              │                            │\n                              │    Layout(name='right')    │\n                              │                            │\n                              ╰────────────────────────────╯\n"
  assert_eq(result, expected)
  assert_eq(layout.map().length(), 3)
}

///|
test "tree" {
  let layout = @layout.Layout::new(name="root")
  layout.split([
    @layout.Layout::new(renderable="foo", size=2),
    @layout.Layout::new(renderable="bar", name="bar"),
  ])
  layout["bar"].split_row([@layout.Layout::new(), @layout.Layout::new()])
  let console = @rich.Console::new(width=60, color_system=None, environ={})
  let tree = layout.tree()
  let result = console.capture(() => console.print(tree, height=10))
  let expected = "⬍ Layout(name='root')\n├── ⬍ Layout(size=2)\n└── ⬌ Layout(name='bar')\n    ├── ⬍ Layout()\n    └── ⬍ Layout()\n"
  assert_eq(result, expected)
}

///|
test "refresh screen" {
  let layout = @layout.Layout::new()
  layout.split_row([
    @layout.Layout::new(name="foo"),
    @layout.Layout::new(name="bar"),
  ])
  let console = @rich.Console::new(
    force_terminal=true,
    width=20,
    height=5,
    file=@rich.StringIO::new(),
    environ={},
  )
  ignore(console.capture(() => console.print(layout)))
  let mut result = ""
  console.screen(_ => {
    result = console.capture(() => layout.refresh_screen(console, "foo"))
  })
  let expected = "\u{1b}[1;1H\u{1b}[34m╭─\u{1b}[0m\u{1b}[34m \u{1b}[0m\u{1b}[32m'foo'\u{1b}[0m\u{1b}[34m─╮\u{1b}[0m\u{1b}[2;1H\u{1b}[34m│\u{1b}[0m \u{1b}[1;35mLayout\u{1b}[0m \u{1b}[34m│\u{1b}[0m\u{1b}[3;1H\u{1b}[34m│\u{1b}[0m \u{1b}[1m(\u{1b}[0m      \u{1b}[34m│\u{1b}[0m\u{1b}[4;1H\u{1b}[34m│\u{1b}[0m     \u{1b}[33mna\u{1b}[0m \u{1b}[34m│\u{1b}[0m\u{1b}[5;1H\u{1b}[34m╰────────╯\u{1b}[0m"
  assert_eq(result, expected)
}
