// Port of tests/test_block_bar.py plus differential cases computed with
// upstream Rich.

///|
/// Upstream tests/render.py `render`.
fn render(renderable : &@rich.Renderable, width? : Int = 100) -> String raise {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    width~,
    file~,
    color_system=Some("truecolor"),
    legacy_windows=false,
    environ={},
  )
  console.print(renderable)
  file.getvalue()
}

///|
test "repr" {
  let bar = @bar.Bar::new(100, 11, 62, width=50)
  assert_eq(bar.repr(), "Bar(100, 11, 62)")
  inspect(bar, content="Bar(100, 11, 62)")
  inspect(@bar.Bar::new(2.5, 0.5, 1.25), content="Bar(2.5, 0.5, 1.25)")
}

///|
test "render" {
  let bar = @bar.Bar::new(100, 11, 62, width=50)
  assert_eq(
    render(bar),
    "\u{1b}[39;49m     ▐█████████████████████████                   \u{1b}[0m\n",
  )
  let bar = @bar.Bar::new(100, 12, 57, width=50)
  assert_eq(
    render(bar),
    "\u{1b}[39;49m      ██████████████████████▌                     \u{1b}[0m\n",
  )
  // begin after end
  let bar = @bar.Bar::new(100, 60, 40, width=50)
  assert_eq(
    render(bar),
    "\u{1b}[39;49m                                                  \u{1b}[0m\n",
  )
}

///|
test "measure" {
  let console = @rich.Console::new(width=120, environ={})
  let bar = @bar.Bar::new(100, 11, 62)
  let measurement = @rich.Measurement::get(console, console.options(), bar)
  assert_eq(measurement.minimum, 4)
  assert_eq(measurement.maximum, 120)
  let fixed = @bar.Bar::new(100, 11, 62, width=30)
  assert_eq(
    @rich.Measurement::get(console, console.options(), fixed),
    @rich.Measurement::new(30, 30),
  )
}

///|
test "zero total" {
  // Shouldn't throw zero division error
  let bar = @bar.Bar::new(0, 0, 0)
  ignore(render(bar))
}

///|
test "differential" {
  let cases : Array[(Double, Double, Double, Int, String, String, String)] = [
    (
      10, 0, 10, 20, "default", "default", "\u{1b}[39;49m████████████████████\u{1b}[0m\n",
    ),
    (
      10, 2.5, 7.25, 30, "red", "blue", "\u{1b}[31;44m       ▐█████████████▊        \u{1b}[0m\n",
    ),
    (
      3, 1, 2, 7, "#ff0000", "default", "\u{1b}[38;2;255;0;0;49m  ██▋  \u{1b}[0m\n",
    ),
    (
      100, 0, 1, 40, "default", "default", "\u{1b}[39;49m▍                                       \u{1b}[0m\n",
    ),
    (
      100, 99, 100, 40, "green", "default", "\u{1b}[32;49m                                       ▐\u{1b}[0m\n",
    ),
    (
      1, 0.3, 0.31, 13, "default", "black", "\u{1b}[39;40m   ▕         \u{1b}[0m\n",
    ),
    (
      50, -5, 70, 25, "default", "default", "\u{1b}[39;49m█████████████████████████\u{1b}[0m\n",
    ),
    (7, 3, 3, 9, "default", "default", "\u{1b}[39;49m         \u{1b}[0m\n"),
  ]
  for case in cases {
    let (size, begin, end, width, color, bgcolor, expected) = case
    let bar = @bar.Bar::new(size, begin, end, width~, color~, bgcolor~)
    assert_eq(render(bar), expected)
  }
  // No width: use the maximum width.
  assert_eq(
    render(@bar.Bar::new(10, 2, 6), width=24),
    "\u{1b}[39;49m    ▕█████████▍         \u{1b}[0m\n",
  )
}

///|
test "color objects" {
  let bar = @bar.Bar::new(
    3,
    1,
    2,
    width=7,
    color=@color.Color::parse("#ff0000"),
  )
  assert_eq(render(bar), "\u{1b}[38;2;255;0;0;49m  ██▋  \u{1b}[0m\n")
}
