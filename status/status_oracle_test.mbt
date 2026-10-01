// Differential tests: expected output computed with upstream Rich 15.0.0
// (scripts/progress_oracle.py).

///|
test "oracle status render" {
  let t = Ref(0.0)
  let file = @rich.StringIO::new()
  let c = @rich.Console::new(
    file~,
    width=40,
    color_system=Some("truecolor"),
    force_terminal=true,
    legacy_windows=false,
    get_time=() => t.val,
    environ={},
  )
  let status = @status.Status::new("[bold]Working", console=c, spinner="arc")
  for i in 0..<4 {
    c.print(status)
    t.val += 0.1
    if i == 1 {
      status.update(status="Still [i]working", spinner_style="yellow")
    }
    if i == 2 {
      status.update(spinner="dots", speed=2.0)
    }
  }
  assert_eq(
    file.getvalue(),
    "\u{1b}[32m◜\u{1b}[0m \u{1b}[1mWorking\u{1b}[0m\n\u{1b}[32m◠\u{1b}[0m \u{1b}[1mWorking\u{1b}[0m\n\u{1b}[33m◝\u{1b}[0m Still \u{1b}[3mworking\u{1b}[0m\n\u{1b}[33m⠋\u{1b}[0m Still \u{1b}[3mworking\u{1b}[0m\n",
  )
}
