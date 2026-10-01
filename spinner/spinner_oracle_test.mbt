// Differential tests: expected output computed with upstream Rich 15.0.0
// (scripts/progress_oracle.py).

///|
test "oracle spinner frames" {
  let spinner = @spinner.Spinner::new("dots", speed=1.0, style="red")
  let frames = [0.0, 0.05, 0.13, 0.5, 1.37, 10.0].map(t => {
    guard spinner.render(t).text_kind() is Text(t) else { abort("text") }
    t.plain()
  })
  assert_eq(frames, ["⠋", "⠋", "⠙", "⠦", "⠧", "⠴"])
  let spinner = @spinner.Spinner::new("dots", speed=2.5, style="red")
  let frames = [0.0, 0.05, 0.13, 0.5, 1.37, 10.0].map(t => {
    guard spinner.render(t).text_kind() is Text(t) else { abort("text") }
    t.plain()
  })
  assert_eq(frames, ["⠋", "⠙", "⠼", "⠴", "⠹", "⠹"])
  let spinner = @spinner.Spinner::new("line", speed=1.0, style="red")
  let frames = [0.0, 0.05, 0.13, 0.5, 1.37, 10.0].map(t => {
    guard spinner.render(t).text_kind() is Text(t) else { abort("text") }
    t.plain()
  })
  assert_eq(frames, ["-", "-", "\\", "/", "|", "-"])
  let spinner = @spinner.Spinner::new("line", speed=2.5, style="red")
  let frames = [0.0, 0.05, 0.13, 0.5, 1.37, 10.0].map(t => {
    guard spinner.render(t).text_kind() is Text(t) else { abort("text") }
    t.plain()
  })
  assert_eq(frames, ["-", "-", "|", "\\", "|", "-"])
  let spinner = @spinner.Spinner::new("earth", speed=1.0, style="red")
  let frames = [0.0, 0.05, 0.13, 0.5, 1.37, 10.0].map(t => {
    guard spinner.render(t).text_kind() is Text(t) else { abort("text") }
    t.plain()
  })
  assert_eq(frames, ["🌍 ", "🌍 ", "🌍 ", "🌏 ", "🌎 ", "🌎 "])
  let spinner = @spinner.Spinner::new("earth", speed=2.5, style="red")
  let frames = [0.0, 0.05, 0.13, 0.5, 1.37, 10.0].map(t => {
    guard spinner.render(t).text_kind() is Text(t) else { abort("text") }
    t.plain()
  })
  assert_eq(frames, ["🌍 ", "🌍 ", "🌎 ", "🌍 ", "🌎 ", "🌍 "])
  let spinner = @spinner.Spinner::new("arc", speed=1.0, style="red")
  let frames = [0.0, 0.05, 0.13, 0.5, 1.37, 10.0].map(t => {
    guard spinner.render(t).text_kind() is Text(t) else { abort("text") }
    t.plain()
  })
  assert_eq(frames, ["◜", "◜", "◠", "◟", "◠", "◡"])
  let spinner = @spinner.Spinner::new("arc", speed=2.5, style="red")
  let frames = [0.0, 0.05, 0.13, 0.5, 1.37, 10.0].map(t => {
    guard spinner.render(t).text_kind() is Text(t) else { abort("text") }
    t.plain()
  })
  assert_eq(frames, ["◜", "◠", "◞", "◜", "◡", "◡"])
  let spinner = @spinner.Spinner::new("aesthetic", speed=1.0, style="red")
  let frames = [0.0, 0.05, 0.13, 0.5, 1.37, 10.0].map(t => {
    guard spinner.render(t).text_kind() is Text(t) else { abort("text") }
    t.plain()
  })
  assert_eq(frames, [
    "▰▱▱▱▱▱▱", "▰▱▱▱▱▱▱", "▰▰▱▱▱▱▱", "▰▰▰▰▰▰▰",
    "▰▰▱▱▱▱▱", "▰▰▰▰▰▰▱",
  ])
  let spinner = @spinner.Spinner::new("aesthetic", speed=2.5, style="red")
  let frames = [0.0, 0.05, 0.13, 0.5, 1.37, 10.0].map(t => {
    guard spinner.render(t).text_kind() is Text(t) else { abort("text") }
    t.plain()
  })
  assert_eq(frames, [
    "▰▱▱▱▱▱▱", "▰▰▱▱▱▱▱", "▰▰▰▰▰▱▱", "▰▱▱▱▱▱▱",
    "▰▰▰▱▱▱▱", "▰▱▱▱▱▱▱",
  ])
  let spinner = @spinner.Spinner::new("bouncingBall", speed=1.0, style="red")
  let frames = [0.0, 0.05, 0.13, 0.5, 1.37, 10.0].map(t => {
    guard spinner.render(t).text_kind() is Text(t) else { abort("text") }
    t.plain()
  })
  assert_eq(frames, [
    "( ●    )", "( ●    )", "(  ●   )", "(   ●  )", "(  ●   )", "(    ● )",
  ])
  let spinner = @spinner.Spinner::new("bouncingBall", speed=2.5, style="red")
  let frames = [0.0, 0.05, 0.13, 0.5, 1.37, 10.0].map(t => {
    guard spinner.render(t).text_kind() is Text(t) else { abort("text") }
    t.plain()
  })
  assert_eq(frames, [
    "( ●    )", "(  ●   )", "(     ●)", "(    ● )", "(   ●  )", "(   ●  )",
  ])
  let spinner = @spinner.Spinner::new("toggle13", speed=1.0, style="red")
  let frames = [0.0, 0.05, 0.13, 0.5, 1.37, 10.0].map(t => {
    guard spinner.render(t).text_kind() is Text(t) else { abort("text") }
    t.plain()
  })
  assert_eq(frames, ["=", "=", "*", "=", "-", "-"])
  let spinner = @spinner.Spinner::new("toggle13", speed=2.5, style="red")
  let frames = [0.0, 0.05, 0.13, 0.5, 1.37, 10.0].map(t => {
    guard spinner.render(t).text_kind() is Text(t) else { abort("text") }
    t.plain()
  })
  assert_eq(frames, ["=", "*", "*", "=", "=", "="])
  let spinner = @spinner.Spinner::new("material", speed=1.0, style="red")
  let frames = [0.0, 0.05, 0.13, 0.5, 1.37, 10.0].map(t => {
    guard spinner.render(t).text_kind() is Text(t) else { abort("text") }
    t.plain()
  })
  assert_eq(frames, [
    "█▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁", "███▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁",
    "████████▁▁▁▁▁▁▁▁▁▁▁▁", "▁▁▁▁▁▁▁█████████████",
    "▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁███", "▁▁▁▁▁▁▁▁▁▁▁▁████████",
  ])
  let spinner = @spinner.Spinner::new("material", speed=2.5, style="red")
  let frames = [0.0, 0.05, 0.13, 0.5, 1.37, 10.0].map(t => {
    guard spinner.render(t).text_kind() is Text(t) else { abort("text") }
    t.plain()
  })
  assert_eq(frames, [
    "█▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁", "████████▁▁▁▁▁▁▁▁▁▁▁▁",
    "▁▁▁██████████████▁▁▁", "▁▁▁▁▁▁▁▁▁▁▁▁███████▁",
    "▁██████████████▁▁▁▁▁", "▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁",
  ])
}

///|
test "oracle spinner console" {
  let t = Ref(0.0)
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    file~,
    width=30,
    color_system=Some("truecolor"),
    force_terminal=true,
    legacy_windows=false,
    get_time=() => t.val,
    environ={},
  )
  let s = @spinner.Spinner::new(
    "dots2",
    text=@rich.Text::new(text="working", style="bold"),
    style="green",
  )
  let r = @spinner.Spinner::new("line", text=@rich.Rule::new(title="x"))
  for step in 0..<5 {
    console.print(s)
    console.print(r)
    if step == 2 {
      s.update(text="[blue]phase 2", speed=3.0, style="magenta")
    }
    t.val += 0.09
  }
  assert_eq(
    file.getvalue(),
    "\u{1b}[32m⣾\u{1b}[0m \u{1b}[1mworking\u{1b}[0m\n- \u{1b}[92m─\u{1b}[0m\n\u{1b}[32m⣽\u{1b}[0m \u{1b}[1mworking\u{1b}[0m\n- \u{1b}[92m─\u{1b}[0m\n\u{1b}[32m⣻\u{1b}[0m \u{1b}[1mworking\u{1b}[0m\n\\ \u{1b}[92m─\u{1b}[0m\n\u{1b}[35m⢿\u{1b}[0m \u{1b}[34mphase 2\u{1b}[0m\n| \u{1b}[92m─\u{1b}[0m\n\u{1b}[35m⣯\u{1b}[0m \u{1b}[34mphase 2\u{1b}[0m\n| \u{1b}[92m─\u{1b}[0m\n",
  )
}
