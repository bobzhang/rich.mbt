// Port of tests/test_bar.py.

///|
fn render(
  renderable : &@rich.Renderable,
  no_wrap? : Bool = false,
) -> String raise {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    width=100,
    file~,
    color_system=Some("truecolor"),
    legacy_windows=false,
    environ={},
  )
  console.print(renderable, no_wrap~)
  file.getvalue()
}

///|
test "init" {
  let bar = @progress_bar.ProgressBar::new(completed=50.0)
  inspect(bar.repr(), content="<Bar 50.0 of 100.0>")
  assert_eq(bar.percentage_completed(), Some(50.0))
}

///|
test "update" {
  let bar = @progress_bar.ProgressBar::new()
  assert_eq(bar.completed, 0.0)
  assert_eq(bar.total, Some(100.0))
  bar.update(10.0, total=20.0)
  assert_eq(bar.completed, 10.0)
  assert_eq(bar.total, Some(20.0))
  assert_eq(bar.percentage_completed(), Some(50.0))
  bar.update(100.0)
  assert_eq(bar.percentage_completed(), Some(100.0))
}

///|
test "render" {
  let bar = @progress_bar.ProgressBar::new(completed=11.0, width=50)
  assert_eq(
    render(bar),
    "\u{1b}[38;2;249;38;114m━━━━━\u{1b}[0m\u{1b}[38;2;249;38;114m╸\u{1b}[0m\u{1b}[38;5;237m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\u{1b}[0m",
  )
  bar.update(12.0)
  assert_eq(
    render(bar),
    "\u{1b}[38;2;249;38;114m━━━━━━\u{1b}[0m\u{1b}[38;5;237m╺\u{1b}[0m\u{1b}[38;5;237m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\u{1b}[0m",
  )
}

///|
test "measure" {
  let console = @rich.Console::new(width=120, environ={})
  let bar = @progress_bar.ProgressBar::new()
  let measurement = @rich.Renderable::rich_measure(
    bar,
    console,
    console.options(),
  ).unwrap()
  assert_eq(measurement.minimum, 4)
  assert_eq(measurement.maximum, 120)
}

///|
test "zero_total" {
  // Shouldn't throw zero division error
  let bar = @progress_bar.ProgressBar::new(total=Some(0.0))
  ignore(render(bar))
}

///|
test "pulse" {
  let bar = @progress_bar.ProgressBar::new(pulse=true, animation_time=10.0)
  assert_eq(
    render(bar),
    "\u{1b}[38;2;249;38;114m━\u{1b}[0m\u{1b}[38;2;244;38;112m━\u{1b}[0m\u{1b}[38;2;230;39;108m━\u{1b}[0m\u{1b}[38;2;209;42;102m━\u{1b}[0m\u{1b}[38;2;183;44;94m━\u{1b}[0m\u{1b}[38;2;153;48;86m━\u{1b}[0m\u{1b}[38;2;123;51;77m━\u{1b}[0m\u{1b}[38;2;97;53;69m━\u{1b}[0m\u{1b}[38;2;76;56;63m━\u{1b}[0m\u{1b}[38;2;62;57;59m━\u{1b}[0m\u{1b}[38;2;58;58;58m━\u{1b}[0m\u{1b}[38;2;62;57;59m━\u{1b}[0m\u{1b}[38;2;76;56;63m━\u{1b}[0m\u{1b}[38;2;97;53;69m━\u{1b}[0m\u{1b}[38;2;123;51;77m━\u{1b}[0m\u{1b}[38;2;153;48;86m━\u{1b}[0m\u{1b}[38;2;183;44;94m━\u{1b}[0m\u{1b}[38;2;209;42;102m━\u{1b}[0m\u{1b}[38;2;230;39;108m━\u{1b}[0m\u{1b}[38;2;244;38;112m━\u{1b}[0m\u{1b}[38;2;249;38;114m━\u{1b}[0m\u{1b}[38;2;244;38;112m━\u{1b}[0m\u{1b}[38;2;230;39;108m━\u{1b}[0m\u{1b}[38;2;209;42;102m━\u{1b}[0m\u{1b}[38;2;183;44;94m━\u{1b}[0m\u{1b}[38;2;153;48;86m━\u{1b}[0m\u{1b}[38;2;123;51;77m━\u{1b}[0m\u{1b}[38;2;97;53;69m━\u{1b}[0m\u{1b}[38;2;76;56;63m━\u{1b}[0m\u{1b}[38;2;62;57;59m━\u{1b}[0m\u{1b}[38;2;58;58;58m━\u{1b}[0m\u{1b}[38;2;62;57;59m━\u{1b}[0m\u{1b}[38;2;76;56;63m━\u{1b}[0m\u{1b}[38;2;97;53;69m━\u{1b}[0m\u{1b}[38;2;123;51;77m━\u{1b}[0m\u{1b}[38;2;153;48;86m━\u{1b}[0m\u{1b}[38;2;183;44;94m━\u{1b}[0m\u{1b}[38;2;209;42;102m━\u{1b}[0m\u{1b}[38;2;230;39;108m━\u{1b}[0m\u{1b}[38;2;244;38;112m━\u{1b}[0m\u{1b}[38;2;249;38;114m━\u{1b}[0m\u{1b}[38;2;244;38;112m━\u{1b}[0m\u{1b}[38;2;230;39;108m━\u{1b}[0m\u{1b}[38;2;209;42;102m━\u{1b}[0m\u{1b}[38;2;183;44;94m━\u{1b}[0m\u{1b}[38;2;153;48;86m━\u{1b}[0m\u{1b}[38;2;123;51;77m━\u{1b}[0m\u{1b}[38;2;97;53;69m━\u{1b}[0m\u{1b}[38;2;76;56;63m━\u{1b}[0m\u{1b}[38;2;62;57;59m━\u{1b}[0m\u{1b}[38;2;58;58;58m━\u{1b}[0m\u{1b}[38;2;62;57;59m━\u{1b}[0m\u{1b}[38;2;76;56;63m━\u{1b}[0m\u{1b}[38;2;97;53;69m━\u{1b}[0m\u{1b}[38;2;123;51;77m━\u{1b}[0m\u{1b}[38;2;153;48;86m━\u{1b}[0m\u{1b}[38;2;183;44;94m━\u{1b}[0m\u{1b}[38;2;209;42;102m━\u{1b}[0m\u{1b}[38;2;230;39;108m━\u{1b}[0m\u{1b}[38;2;244;38;112m━\u{1b}[0m\u{1b}[38;2;249;38;114m━\u{1b}[0m\u{1b}[38;2;244;38;112m━\u{1b}[0m\u{1b}[38;2;230;39;108m━\u{1b}[0m\u{1b}[38;2;209;42;102m━\u{1b}[0m\u{1b}[38;2;183;44;94m━\u{1b}[0m\u{1b}[38;2;153;48;86m━\u{1b}[0m\u{1b}[38;2;123;51;77m━\u{1b}[0m\u{1b}[38;2;97;53;69m━\u{1b}[0m\u{1b}[38;2;76;56;63m━\u{1b}[0m\u{1b}[38;2;62;57;59m━\u{1b}[0m\u{1b}[38;2;58;58;58m━\u{1b}[0m\u{1b}[38;2;62;57;59m━\u{1b}[0m\u{1b}[38;2;76;56;63m━\u{1b}[0m\u{1b}[38;2;97;53;69m━\u{1b}[0m\u{1b}[38;2;123;51;77m━\u{1b}[0m\u{1b}[38;2;153;48;86m━\u{1b}[0m\u{1b}[38;2;183;44;94m━\u{1b}[0m\u{1b}[38;2;209;42;102m━\u{1b}[0m\u{1b}[38;2;230;39;108m━\u{1b}[0m\u{1b}[38;2;244;38;112m━\u{1b}[0m\u{1b}[38;2;249;38;114m━\u{1b}[0m\u{1b}[38;2;244;38;112m━\u{1b}[0m\u{1b}[38;2;230;39;108m━\u{1b}[0m\u{1b}[38;2;209;42;102m━\u{1b}[0m\u{1b}[38;2;183;44;94m━\u{1b}[0m\u{1b}[38;2;153;48;86m━\u{1b}[0m\u{1b}[38;2;123;51;77m━\u{1b}[0m\u{1b}[38;2;97;53;69m━\u{1b}[0m\u{1b}[38;2;76;56;63m━\u{1b}[0m\u{1b}[38;2;62;57;59m━\u{1b}[0m\u{1b}[38;2;58;58;58m━\u{1b}[0m\u{1b}[38;2;62;57;59m━\u{1b}[0m\u{1b}[38;2;76;56;63m━\u{1b}[0m\u{1b}[38;2;97;53;69m━\u{1b}[0m\u{1b}[38;2;123;51;77m━\u{1b}[0m\u{1b}[38;2;153;48;86m━\u{1b}[0m\u{1b}[38;2;183;44;94m━\u{1b}[0m\u{1b}[38;2;209;42;102m━\u{1b}[0m\u{1b}[38;2;230;39;108m━\u{1b}[0m\u{1b}[38;2;244;38;112m━\u{1b}[0m",
  )
}

///|
test "get_pulse_segments" {
  let bar = @progress_bar.ProgressBar::new()
  let segments = bar.get_pulse_segments(
    @rich.Style::parse("red"),
    @rich.Style::parse("yellow"),
    None,
    false,
    ascii=false,
  )
  let expected : Array[@rich.Segment] = []
  for _ in 0..<10 {
    expected.push(@rich.Segment::new("━", style=@rich.Style::parse("red")))
  }
  for _ in 0..<10 {
    expected.push(@rich.Segment::new("━", style=@rich.Style::parse("yellow")))
  }
  assert_true(segments == expected)
}
