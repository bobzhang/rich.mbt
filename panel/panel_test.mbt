///|
fn render(panel : &@rich.Renderable, width? : Int = 50) -> String raise {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    file~,
    width~,
    color_system=Some("truecolor"),
    force_terminal=true,
    legacy_windows=false,
    environ={},
  )
  console.print(panel)
  file.getvalue()
}

///|
test "panel basics" {
  assert_eq(
    render(@panel.Panel::new("Hello, World", padding=[2, 4])),
    "╭────────────────────────────────────────────────╮\n│                                                │\n│                                                │\n│    Hello, World                                │\n│                                                │\n│                                                │\n╰────────────────────────────────────────────────╯\n",
  )
  assert_eq(
    render(@panel.Panel::fit("Hello, World", title="Title", subtitle="sub")),
    "╭─── Title ────╮\n│ Hello, World │\n╰──── sub ─────╯\n",
  )
}
