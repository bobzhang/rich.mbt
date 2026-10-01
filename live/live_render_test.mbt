// Port of tests/test_live_render.py.

///|
fn live_render() -> @live.LiveRender {
  @live.LiveRender::new("my string")
}

///|
test "renderable" {
  let live_render = live_render()
  assert_true(live_render.renderable.text_kind() is Str("my string"))
  live_render.set_renderable("another string")
  assert_true(live_render.renderable.text_kind() is Str("another string"))
}

///|
test "position_cursor" {
  let live_render = live_render()
  assert_eq(live_render.position_cursor().to_string(), "")
  live_render.shape = Some((80, 2))
  assert_eq(
    live_render.position_cursor().to_string(),
    "\r\u{1b}[2K\u{1b}[1A\u{1b}[2K",
  )
}

///|
test "restore_cursor" {
  let live_render = live_render()
  assert_eq(live_render.restore_cursor().to_string(), "")
  live_render.shape = Some((80, 2))
  assert_eq(
    live_render.restore_cursor().to_string(),
    "\r\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K",
  )
}

///|
test "rich_console" {
  let live_render = live_render()
  let options : @rich.ConsoleOptions = {
    size: { width: 80, height: 25, },
    max_height: 25,
    legacy_windows: false,
    min_width: 10,
    max_width: 20,
    is_terminal: false,
    encoding: "utf-8",
    justify: None,
    overflow: None,
    no_wrap: None,
    highlight: None,
    markup: None,
    height: None,
  }
  let console = @rich.Console::new(file=@rich.StringIO::new(), environ={})
  fn segments(items : Array[@rich.RenderItem]) -> Array[@rich.Segment] {
    items.map(item => {
      match item {
        Seg(s) => s
        Child(_) => abort("unexpected child")
      }
    })
  }

  let rich_console = @rich.Renderable::rich_console(
    live_render, console, options,
  )
  assert_true(segments(rich_console) == [@rich.Segment::new("my string")])
  live_render.style = Def("red")
  let rich_console = @rich.Renderable::rich_console(
    live_render, console, options,
  )
  assert_true(
    segments(rich_console) ==
    [@rich.Segment::new("my string", style=@rich.Style::parse("red"))],
  )
}
