// Differential tests: expected output computed with upstream Rich 15.0.0
// (scripts/progress_oracle.py).

///|
test "oracle nested live" {
  let file = @rich.StringIO::new()
  let c = @rich.Console::new(
    file~,
    width=30,
    height=10,
    force_terminal=true,
    legacy_windows=false,
    color_system=None,
    environ={},
  )
  let a = @live.Live::new(renderable="outer", console=c, auto_refresh=false)
  let b = @live.Live::new(renderable="inner", console=c, auto_refresh=false)
  a.start(refresh=true)
  b.start(refresh=true)
  b.update("inner2", refresh=true)
  c.print("hello")
  b.stop()
  a.update("outer2", refresh=true)
  a.stop()
  assert_eq(
    file.getvalue(),
    "\u{1b}[?25louter\r\u{1b}[2Kouter\ninner2\r\u{1b}[2K\u{1b}[1A\u{1b}[2Khello\nouter\ninner2\r\u{1b}[2K\u{1b}[1A\u{1b}[2Kinner2\nouter\ninner2\r\u{1b}[2K\u{1b}[1A\u{1b}[2Kouter2\r\u{1b}[2Kouter2\n\u{1b}[?25h",
  )
}

///|
test "oracle live file transient=False" {
  let file = @rich.StringIO::new()
  let c = @rich.Console::new(
    file~,
    width=30,
    height=10,
    force_terminal=false,
    legacy_windows=false,
    color_system=None,
    environ={},
  )
  let live = @live.Live::new(
    renderable="[bold]x",
    console=c,
    auto_refresh=false,
    transient=false,
  )
  live.run(() => {
    live.update("[red]y[/red] z", refresh=true)
    c.print("between")
    live.update(@rich.Text::new(text="final"))
  })
  assert_eq(file.getvalue(), "between\nfinal")
}

///|
test "oracle live file transient=True" {
  let file = @rich.StringIO::new()
  let c = @rich.Console::new(
    file~,
    width=30,
    height=10,
    force_terminal=false,
    legacy_windows=false,
    color_system=None,
    environ={},
  )
  let live = @live.Live::new(
    renderable="[bold]x",
    console=c,
    auto_refresh=false,
    transient=true,
  )
  live.run(() => {
    live.update("[red]y[/red] z", refresh=true)
    c.print("between")
    live.update(@rich.Text::new(text="final"))
  })
  assert_eq(file.getvalue(), "between\n")
}

///|
test "oracle live screen updates" {
  let file = @rich.StringIO::new()
  let c = @rich.Console::new(
    file~,
    width=12,
    height=4,
    force_terminal=true,
    legacy_windows=false,
    color_system=Some("truecolor"),
    environ={},
  )
  let live = @live.Live::new(
    renderable=@rich.Text::new(text="start", style="green"),
    console=c,
    auto_refresh=false,
    screen=true,
  )
  live.run(() => {
    live.update("[b]line1\nline2\nline3\nline4\nline5", refresh=true)
    live.update("bye", refresh=true)
  })
  assert_eq(
    file.getvalue(),
    "\u{1b}[?1049h\u{1b}[H\u{1b}[?25l\u{1b}[H\u{1b}[32mstart\u{1b}[0m       \n            \n            \n            \u{1b}[H\u{1b}[1mline1\u{1b}[0m       \n\u{1b}[1mline2\u{1b}[0m       \n\u{1b}[1mline3\u{1b}[0m       \n\u{1b}[1mline4\u{1b}[0m       \u{1b}[Hbye         \n            \n            \n            \u{1b}[?25h\u{1b}[?1049l",
  )
}

///|
test "oracle live ellipsis styled" {
  let file = @rich.StringIO::new()
  let c = @rich.Console::new(
    file~,
    width=12,
    height=4,
    force_terminal=true,
    legacy_windows=false,
    color_system=Some("truecolor"),
    environ={},
  )
  let live = @live.Live::new(console=c, auto_refresh=false)
  live.run(() => {
    live.update("a\nb\nc\nd\ne\nf", refresh=true)
    c.print("[u]log line")
  })
  assert_eq(
    file.getvalue(),
    "\u{1b}[?25la\nb\nc\n\u{1b}[1;31m    ...     \u{1b}[0m\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[4mlog line\u{1b}[0m\na\nb\nc\n\u{1b}[1;31m    ...     \u{1b}[0m\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2Ka\nb\nc\nd\ne\nf\n\u{1b}[?25h",
  )
}
