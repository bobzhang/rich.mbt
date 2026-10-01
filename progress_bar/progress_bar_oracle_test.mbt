// Differential tests: expected output computed with upstream Rich 15.0.0
// (scripts/progress_oracle.py).

///|
test "oracle progress bar" {
  {
    let file = @rich.StringIO::new()
    let console = @rich.Console::new(
      file~,
      width=24,
      color_system=Some("truecolor"),
      legacy_windows=false,
      no_color=false,
      force_terminal=true,
      environ={},
    )
    let cases : Array[(Double?, Double, Int?, Bool, Double?)] = [
      (Some(100.0), 0.0, None, false, None),
      (Some(100.0), 33.0, Some(20), false, None),
      (Some(100.0), 34.0, Some(20), false, None),
      (Some(7.0), 7.0, Some(10), false, None),
      (Some(7.0), 9.0, None, false, None),
      (Some(0.0), 0.0, Some(12), false, None),
      (Some(100.0), -5.0, Some(8), false, None),
      (None, 0.0, Some(15), false, Some(1.234)),
      (Some(100.0), 50.0, Some(30), true, Some(0.5)),
    ]
    for case in cases {
      let (total, completed, width, pulse, animation_time) = case
      let bar = @progress_bar.ProgressBar::new(
        total~,
        completed~,
        width?,
        pulse~,
        animation_time?,
      )
      console.print(bar)
      console.print("|")
    }
    assert_eq(
      file.getvalue(),
      "\u{1b}[38;5;237m━━━━━━━━━━━━━━━━━━━━━━━━\u{1b}[0m|\n\u{1b}[38;2;249;38;114m━━━━━━\u{1b}[0m\u{1b}[38;2;249;38;114m╸\u{1b}[0m\u{1b}[38;5;237m━━━━━━━━━━━━━\u{1b}[0m|\n\u{1b}[38;2;249;38;114m━━━━━━\u{1b}[0m\u{1b}[38;2;249;38;114m╸\u{1b}[0m\u{1b}[38;5;237m━━━━━━━━━━━━━\u{1b}[0m|\n\u{1b}[38;2;114;156;31m━━━━━━━━━━\u{1b}[0m|\n\u{1b}[38;2;114;156;31m━━━━━━━━━━━━━━━━━━━━━━━━\u{1b}[0m|\n\u{1b}[38;2;114;156;31m━━━━━━━━━━━━\u{1b}[0m|\n\u{1b}[38;5;237m━━━━━━━━\u{1b}[0m|\n\u{1b}[38;2;76;56;63m━\u{1b}[0m\u{1b}[38;2;97;53;69m━\u{1b}[0m\u{1b}[38;2;123;51;77m━\u{1b}[0m\u{1b}[38;2;153;48;86m━\u{1b}[0m\u{1b}[38;2;183;44;94m━\u{1b}[0m\u{1b}[38;2;209;42;102m━\u{1b}[0m\u{1b}[38;2;230;39;108m━\u{1b}[0m\u{1b}[38;2;244;38;112m━\u{1b}[0m\u{1b}[38;2;249;38;114m━\u{1b}[0m\u{1b}[38;2;244;38;112m━\u{1b}[0m\u{1b}[38;2;230;39;108m━\u{1b}[0m\u{1b}[38;2;209;42;102m━\u{1b}[0m\u{1b}[38;2;183;44;94m━\u{1b}[0m\u{1b}[38;2;153;48;86m━\u{1b}[0m\u{1b}[38;2;123;51;77m━\u{1b}[0m|\n\u{1b}[38;2;209;42;102m━\u{1b}[0m\u{1b}[38;2;183;44;94m━\u{1b}[0m\u{1b}[38;2;153;48;86m━\u{1b}[0m\u{1b}[38;2;123;51;77m━\u{1b}[0m\u{1b}[38;2;97;53;69m━\u{1b}[0m\u{1b}[38;2;76;56;63m━\u{1b}[0m\u{1b}[38;2;62;57;59m━\u{1b}[0m\u{1b}[38;2;58;58;58m━\u{1b}[0m\u{1b}[38;2;62;57;59m━\u{1b}[0m\u{1b}[38;2;76;56;63m━\u{1b}[0m\u{1b}[38;2;97;53;69m━\u{1b}[0m\u{1b}[38;2;123;51;77m━\u{1b}[0m\u{1b}[38;2;153;48;86m━\u{1b}[0m\u{1b}[38;2;183;44;94m━\u{1b}[0m\u{1b}[38;2;209;42;102m━\u{1b}[0m\u{1b}[38;2;230;39;108m━\u{1b}[0m\u{1b}[38;2;244;38;112m━\u{1b}[0m\u{1b}[38;2;249;38;114m━\u{1b}[0m\u{1b}[38;2;244;38;112m━\u{1b}[0m\u{1b}[38;2;230;39;108m━\u{1b}[0m\u{1b}[38;2;209;42;102m━\u{1b}[0m\u{1b}[38;2;183;44;94m━\u{1b}[0m\u{1b}[38;2;153;48;86m━\u{1b}[0m\u{1b}[38;2;123;51;77m━\u{1b}[0m|\n",
    )
  }
  {
    let file = @rich.StringIO::new()
    let console = @rich.Console::new(
      file~,
      width=24,
      color_system=Some("truecolor"),
      legacy_windows=false,
      no_color=true,
      force_terminal=true,
      environ={},
    )
    let cases : Array[(Double?, Double, Int?, Bool, Double?)] = [
      (Some(100.0), 0.0, None, false, None),
      (Some(100.0), 33.0, Some(20), false, None),
      (Some(100.0), 34.0, Some(20), false, None),
      (Some(7.0), 7.0, Some(10), false, None),
      (Some(7.0), 9.0, None, false, None),
      (Some(0.0), 0.0, Some(12), false, None),
      (Some(100.0), -5.0, Some(8), false, None),
      (None, 0.0, Some(15), false, Some(1.234)),
      (Some(100.0), 50.0, Some(30), true, Some(0.5)),
    ]
    for case in cases {
      let (total, completed, width, pulse, animation_time) = case
      let bar = @progress_bar.ProgressBar::new(
        total~,
        completed~,
        width?,
        pulse~,
        animation_time?,
      )
      console.print(bar)
      console.print("|")
    }
    assert_eq(
      file.getvalue(),
      "|\n━━━━━━╸|\n━━━━━━╸|\n━━━━━━━━━━|\n━━━━━━━━━━━━━━━━━━━━━━━━|\n━━━━━━━━━━━━|\n|\n━━━━━━━━       |\n       ━━━━━━━━━━       |\n",
    )
  }
  {
    let file = @rich.StringIO::new()
    let console = @rich.Console::new(
      file~,
      width=24,
      color_system=Some("truecolor"),
      legacy_windows=true,
      no_color=false,
      force_terminal=true,
      environ={},
    )
    let cases : Array[(Double?, Double, Int?, Bool, Double?)] = [
      (Some(100.0), 0.0, None, false, None),
      (Some(100.0), 33.0, Some(20), false, None),
      (Some(100.0), 34.0, Some(20), false, None),
      (Some(7.0), 7.0, Some(10), false, None),
      (Some(7.0), 9.0, None, false, None),
      (Some(0.0), 0.0, Some(12), false, None),
      (Some(100.0), -5.0, Some(8), false, None),
      (None, 0.0, Some(15), false, Some(1.234)),
      (Some(100.0), 50.0, Some(30), true, Some(0.5)),
    ]
    for case in cases {
      let (total, completed, width, pulse, animation_time) = case
      let bar = @progress_bar.ProgressBar::new(
        total~,
        completed~,
        width?,
        pulse~,
        animation_time?,
      )
      console.print(bar)
      console.print("|")
    }
    assert_eq(
      file.getvalue(),
      "\u{1b}[38;5;237m------------------------\u{1b}[0m|\n\u{1b}[38;2;249;38;114m------\u{1b}[0m\u{1b}[38;2;249;38;114m \u{1b}[0m\u{1b}[38;5;237m-------------\u{1b}[0m|\n\u{1b}[38;2;249;38;114m------\u{1b}[0m\u{1b}[38;2;249;38;114m \u{1b}[0m\u{1b}[38;5;237m-------------\u{1b}[0m|\n\u{1b}[38;2;114;156;31m----------\u{1b}[0m|\n\u{1b}[38;2;114;156;31m------------------------\u{1b}[0m|\n\u{1b}[38;2;114;156;31m------------\u{1b}[0m|\n\u{1b}[38;5;237m--------\u{1b}[0m|\n\u{1b}[38;2;76;56;63m-\u{1b}[0m\u{1b}[38;2;97;53;69m-\u{1b}[0m\u{1b}[38;2;123;51;77m-\u{1b}[0m\u{1b}[38;2;153;48;86m-\u{1b}[0m\u{1b}[38;2;183;44;94m-\u{1b}[0m\u{1b}[38;2;209;42;102m-\u{1b}[0m\u{1b}[38;2;230;39;108m-\u{1b}[0m\u{1b}[38;2;244;38;112m-\u{1b}[0m\u{1b}[38;2;249;38;114m-\u{1b}[0m\u{1b}[38;2;244;38;112m-\u{1b}[0m\u{1b}[38;2;230;39;108m-\u{1b}[0m\u{1b}[38;2;209;42;102m-\u{1b}[0m\u{1b}[38;2;183;44;94m-\u{1b}[0m\u{1b}[38;2;153;48;86m-\u{1b}[0m\u{1b}[38;2;123;51;77m-\u{1b}[0m|\n\u{1b}[38;2;209;42;102m-\u{1b}[0m\u{1b}[38;2;183;44;94m-\u{1b}[0m\u{1b}[38;2;153;48;86m-\u{1b}[0m\u{1b}[38;2;123;51;77m-\u{1b}[0m\u{1b}[38;2;97;53;69m-\u{1b}[0m\u{1b}[38;2;76;56;63m-\u{1b}[0m\u{1b}[38;2;62;57;59m-\u{1b}[0m\u{1b}[38;2;58;58;58m-\u{1b}[0m\u{1b}[38;2;62;57;59m-\u{1b}[0m\u{1b}[38;2;76;56;63m-\u{1b}[0m\u{1b}[38;2;97;53;69m-\u{1b}[0m\u{1b}[38;2;123;51;77m-\u{1b}[0m\u{1b}[38;2;153;48;86m-\u{1b}[0m\u{1b}[38;2;183;44;94m-\u{1b}[0m\u{1b}[38;2;209;42;102m-\u{1b}[0m\u{1b}[38;2;230;39;108m-\u{1b}[0m\u{1b}[38;2;244;38;112m-\u{1b}[0m\u{1b}[38;2;249;38;114m-\u{1b}[0m\u{1b}[38;2;244;38;112m-\u{1b}[0m\u{1b}[38;2;230;39;108m-\u{1b}[0m\u{1b}[38;2;209;42;102m-\u{1b}[0m\u{1b}[38;2;183;44;94m-\u{1b}[0m\u{1b}[38;2;153;48;86m-\u{1b}[0m\u{1b}[38;2;123;51;77m-\u{1b}[0m|\n",
    )
  }
  {
    let file = @rich.StringIO::new()
    let console = @rich.Console::new(
      file~,
      width=24,
      color_system=Some("truecolor"),
      legacy_windows=true,
      no_color=true,
      force_terminal=true,
      environ={},
    )
    let cases : Array[(Double?, Double, Int?, Bool, Double?)] = [
      (Some(100.0), 0.0, None, false, None),
      (Some(100.0), 33.0, Some(20), false, None),
      (Some(100.0), 34.0, Some(20), false, None),
      (Some(7.0), 7.0, Some(10), false, None),
      (Some(7.0), 9.0, None, false, None),
      (Some(0.0), 0.0, Some(12), false, None),
      (Some(100.0), -5.0, Some(8), false, None),
      (None, 0.0, Some(15), false, Some(1.234)),
      (Some(100.0), 50.0, Some(30), true, Some(0.5)),
    ]
    for case in cases {
      let (total, completed, width, pulse, animation_time) = case
      let bar = @progress_bar.ProgressBar::new(
        total~,
        completed~,
        width?,
        pulse~,
        animation_time?,
      )
      console.print(bar)
      console.print("|")
    }
    assert_eq(
      file.getvalue(),
      "|\n------ |\n------ |\n----------|\n------------------------|\n------------|\n|\n--------       |\n       ----------       |\n",
    )
  }
  {
    let file = @rich.StringIO::new()
    let console = @rich.Console::new(
      file~,
      width=24,
      color_system=Some("256"),
      legacy_windows=false,
      no_color=false,
      force_terminal=true,
      environ={},
    )
    let cases : Array[(Double?, Double, Int?, Bool, Double?)] = [
      (Some(100.0), 0.0, None, false, None),
      (Some(100.0), 33.0, Some(20), false, None),
      (Some(100.0), 34.0, Some(20), false, None),
      (Some(7.0), 7.0, Some(10), false, None),
      (Some(7.0), 9.0, None, false, None),
      (Some(0.0), 0.0, Some(12), false, None),
      (Some(100.0), -5.0, Some(8), false, None),
      (None, 0.0, Some(15), false, Some(1.234)),
      (Some(100.0), 50.0, Some(30), true, Some(0.5)),
    ]
    for case in cases {
      let (total, completed, width, pulse, animation_time) = case
      let bar = @progress_bar.ProgressBar::new(
        total~,
        completed~,
        width?,
        pulse~,
        animation_time?,
      )
      console.print(bar)
      console.print("|")
    }
    assert_eq(
      file.getvalue(),
      "\u{1b}[38;5;237m━━━━━━━━━━━━━━━━━━━━━━━━\u{1b}[0m|\n\u{1b}[38;5;197m━━━━━━\u{1b}[0m\u{1b}[38;5;197m╸\u{1b}[0m\u{1b}[38;5;237m━━━━━━━━━━━━━\u{1b}[0m|\n\u{1b}[38;5;197m━━━━━━\u{1b}[0m\u{1b}[38;5;197m╸\u{1b}[0m\u{1b}[38;5;237m━━━━━━━━━━━━━\u{1b}[0m|\n\u{1b}[38;5;70m━━━━━━━━━━\u{1b}[0m|\n\u{1b}[38;5;70m━━━━━━━━━━━━━━━━━━━━━━━━\u{1b}[0m|\n\u{1b}[38;5;70m━━━━━━━━━━━━\u{1b}[0m|\n\u{1b}[38;5;237m━━━━━━━━\u{1b}[0m|\n\u{1b}[38;5;197m━\u{1b}[0m\u{1b}[38;5;197m━\u{1b}[0m\u{1b}[38;5;197m━\u{1b}[0m\u{1b}[38;5;197m━\u{1b}[0m\u{1b}[38;5;197m━\u{1b}[0m\u{1b}[38;5;197m━\u{1b}[0m\u{1b}[38;5;197m━\u{1b}[0m\u{1b}[38;5;197m━\u{1b}[0m\u{1b}[38;5;237m━\u{1b}[0m\u{1b}[38;5;237m━\u{1b}[0m\u{1b}[38;5;237m━\u{1b}[0m\u{1b}[38;5;237m━\u{1b}[0m\u{1b}[38;5;237m━\u{1b}[0m\u{1b}[38;5;237m━\u{1b}[0m\u{1b}[38;5;237m━\u{1b}[0m|\n\u{1b}[38;5;237m━\u{1b}[0m\u{1b}[38;5;237m━\u{1b}[0m\u{1b}[38;5;237m━\u{1b}[0m\u{1b}[38;5;237m━\u{1b}[0m\u{1b}[38;5;237m━\u{1b}[0m\u{1b}[38;5;237m━\u{1b}[0m\u{1b}[38;5;237m━\u{1b}[0m\u{1b}[38;5;197m━\u{1b}[0m\u{1b}[38;5;197m━\u{1b}[0m\u{1b}[38;5;197m━\u{1b}[0m\u{1b}[38;5;197m━\u{1b}[0m\u{1b}[38;5;197m━\u{1b}[0m\u{1b}[38;5;197m━\u{1b}[0m\u{1b}[38;5;197m━\u{1b}[0m\u{1b}[38;5;197m━\u{1b}[0m\u{1b}[38;5;197m━\u{1b}[0m\u{1b}[38;5;197m━\u{1b}[0m\u{1b}[38;5;237m━\u{1b}[0m\u{1b}[38;5;237m━\u{1b}[0m\u{1b}[38;5;237m━\u{1b}[0m\u{1b}[38;5;237m━\u{1b}[0m\u{1b}[38;5;237m━\u{1b}[0m\u{1b}[38;5;237m━\u{1b}[0m\u{1b}[38;5;237m━\u{1b}[0m|\n",
    )
  }
  {
    let file = @rich.StringIO::new()
    let console = @rich.Console::new(
      file~,
      width=24,
      color_system=Some("256"),
      legacy_windows=false,
      no_color=true,
      force_terminal=true,
      environ={},
    )
    let cases : Array[(Double?, Double, Int?, Bool, Double?)] = [
      (Some(100.0), 0.0, None, false, None),
      (Some(100.0), 33.0, Some(20), false, None),
      (Some(100.0), 34.0, Some(20), false, None),
      (Some(7.0), 7.0, Some(10), false, None),
      (Some(7.0), 9.0, None, false, None),
      (Some(0.0), 0.0, Some(12), false, None),
      (Some(100.0), -5.0, Some(8), false, None),
      (None, 0.0, Some(15), false, Some(1.234)),
      (Some(100.0), 50.0, Some(30), true, Some(0.5)),
    ]
    for case in cases {
      let (total, completed, width, pulse, animation_time) = case
      let bar = @progress_bar.ProgressBar::new(
        total~,
        completed~,
        width?,
        pulse~,
        animation_time?,
      )
      console.print(bar)
      console.print("|")
    }
    assert_eq(
      file.getvalue(),
      "|\n━━━━━━╸|\n━━━━━━╸|\n━━━━━━━━━━|\n━━━━━━━━━━━━━━━━━━━━━━━━|\n━━━━━━━━━━━━|\n|\n━━━━━━━━       |\n       ━━━━━━━━━━       |\n",
    )
  }
  {
    let file = @rich.StringIO::new()
    let console = @rich.Console::new(
      file~,
      width=24,
      color_system=Some("256"),
      legacy_windows=true,
      no_color=false,
      force_terminal=true,
      environ={},
    )
    let cases : Array[(Double?, Double, Int?, Bool, Double?)] = [
      (Some(100.0), 0.0, None, false, None),
      (Some(100.0), 33.0, Some(20), false, None),
      (Some(100.0), 34.0, Some(20), false, None),
      (Some(7.0), 7.0, Some(10), false, None),
      (Some(7.0), 9.0, None, false, None),
      (Some(0.0), 0.0, Some(12), false, None),
      (Some(100.0), -5.0, Some(8), false, None),
      (None, 0.0, Some(15), false, Some(1.234)),
      (Some(100.0), 50.0, Some(30), true, Some(0.5)),
    ]
    for case in cases {
      let (total, completed, width, pulse, animation_time) = case
      let bar = @progress_bar.ProgressBar::new(
        total~,
        completed~,
        width?,
        pulse~,
        animation_time?,
      )
      console.print(bar)
      console.print("|")
    }
    assert_eq(
      file.getvalue(),
      "\u{1b}[38;5;237m------------------------\u{1b}[0m|\n\u{1b}[38;5;197m------\u{1b}[0m\u{1b}[38;5;197m \u{1b}[0m\u{1b}[38;5;237m-------------\u{1b}[0m|\n\u{1b}[38;5;197m------\u{1b}[0m\u{1b}[38;5;197m \u{1b}[0m\u{1b}[38;5;237m-------------\u{1b}[0m|\n\u{1b}[38;5;70m----------\u{1b}[0m|\n\u{1b}[38;5;70m------------------------\u{1b}[0m|\n\u{1b}[38;5;70m------------\u{1b}[0m|\n\u{1b}[38;5;237m--------\u{1b}[0m|\n\u{1b}[38;5;197m-\u{1b}[0m\u{1b}[38;5;197m-\u{1b}[0m\u{1b}[38;5;197m-\u{1b}[0m\u{1b}[38;5;197m-\u{1b}[0m\u{1b}[38;5;197m-\u{1b}[0m\u{1b}[38;5;197m-\u{1b}[0m\u{1b}[38;5;197m-\u{1b}[0m\u{1b}[38;5;197m-\u{1b}[0m\u{1b}[38;5;237m-\u{1b}[0m\u{1b}[38;5;237m-\u{1b}[0m\u{1b}[38;5;237m-\u{1b}[0m\u{1b}[38;5;237m-\u{1b}[0m\u{1b}[38;5;237m-\u{1b}[0m\u{1b}[38;5;237m-\u{1b}[0m\u{1b}[38;5;237m-\u{1b}[0m|\n\u{1b}[38;5;237m-\u{1b}[0m\u{1b}[38;5;237m-\u{1b}[0m\u{1b}[38;5;237m-\u{1b}[0m\u{1b}[38;5;237m-\u{1b}[0m\u{1b}[38;5;237m-\u{1b}[0m\u{1b}[38;5;237m-\u{1b}[0m\u{1b}[38;5;237m-\u{1b}[0m\u{1b}[38;5;197m-\u{1b}[0m\u{1b}[38;5;197m-\u{1b}[0m\u{1b}[38;5;197m-\u{1b}[0m\u{1b}[38;5;197m-\u{1b}[0m\u{1b}[38;5;197m-\u{1b}[0m\u{1b}[38;5;197m-\u{1b}[0m\u{1b}[38;5;197m-\u{1b}[0m\u{1b}[38;5;197m-\u{1b}[0m\u{1b}[38;5;197m-\u{1b}[0m\u{1b}[38;5;197m-\u{1b}[0m\u{1b}[38;5;237m-\u{1b}[0m\u{1b}[38;5;237m-\u{1b}[0m\u{1b}[38;5;237m-\u{1b}[0m\u{1b}[38;5;237m-\u{1b}[0m\u{1b}[38;5;237m-\u{1b}[0m\u{1b}[38;5;237m-\u{1b}[0m\u{1b}[38;5;237m-\u{1b}[0m|\n",
    )
  }
  {
    let file = @rich.StringIO::new()
    let console = @rich.Console::new(
      file~,
      width=24,
      color_system=Some("256"),
      legacy_windows=true,
      no_color=true,
      force_terminal=true,
      environ={},
    )
    let cases : Array[(Double?, Double, Int?, Bool, Double?)] = [
      (Some(100.0), 0.0, None, false, None),
      (Some(100.0), 33.0, Some(20), false, None),
      (Some(100.0), 34.0, Some(20), false, None),
      (Some(7.0), 7.0, Some(10), false, None),
      (Some(7.0), 9.0, None, false, None),
      (Some(0.0), 0.0, Some(12), false, None),
      (Some(100.0), -5.0, Some(8), false, None),
      (None, 0.0, Some(15), false, Some(1.234)),
      (Some(100.0), 50.0, Some(30), true, Some(0.5)),
    ]
    for case in cases {
      let (total, completed, width, pulse, animation_time) = case
      let bar = @progress_bar.ProgressBar::new(
        total~,
        completed~,
        width?,
        pulse~,
        animation_time?,
      )
      console.print(bar)
      console.print("|")
    }
    assert_eq(
      file.getvalue(),
      "|\n------ |\n------ |\n----------|\n------------------------|\n------------|\n|\n--------       |\n       ----------       |\n",
    )
  }
  {
    let file = @rich.StringIO::new()
    let console = @rich.Console::new(
      file~,
      width=24,
      color_system=Some("standard"),
      legacy_windows=false,
      no_color=false,
      force_terminal=true,
      environ={},
    )
    let cases : Array[(Double?, Double, Int?, Bool, Double?)] = [
      (Some(100.0), 0.0, None, false, None),
      (Some(100.0), 33.0, Some(20), false, None),
      (Some(100.0), 34.0, Some(20), false, None),
      (Some(7.0), 7.0, Some(10), false, None),
      (Some(7.0), 9.0, None, false, None),
      (Some(0.0), 0.0, Some(12), false, None),
      (Some(100.0), -5.0, Some(8), false, None),
      (None, 0.0, Some(15), false, Some(1.234)),
      (Some(100.0), 50.0, Some(30), true, Some(0.5)),
    ]
    for case in cases {
      let (total, completed, width, pulse, animation_time) = case
      let bar = @progress_bar.ProgressBar::new(
        total~,
        completed~,
        width?,
        pulse~,
        animation_time?,
      )
      console.print(bar)
      console.print("|")
    }
    assert_eq(
      file.getvalue(),
      "\u{1b}[90m━━━━━━━━━━━━━━━━━━━━━━━━\u{1b}[0m|\n\u{1b}[91m━━━━━━\u{1b}[0m\u{1b}[91m╸\u{1b}[0m\u{1b}[90m━━━━━━━━━━━━━\u{1b}[0m|\n\u{1b}[91m━━━━━━\u{1b}[0m\u{1b}[91m╸\u{1b}[0m\u{1b}[90m━━━━━━━━━━━━━\u{1b}[0m|\n\u{1b}[90m━━━━━━━━━━\u{1b}[0m|\n\u{1b}[90m━━━━━━━━━━━━━━━━━━━━━━━━\u{1b}[0m|\n\u{1b}[90m━━━━━━━━━━━━\u{1b}[0m|\n\u{1b}[90m━━━━━━━━\u{1b}[0m|\n\u{1b}[90m━\u{1b}[0m\u{1b}[90m━\u{1b}[0m\u{1b}[90m━\u{1b}[0m\u{1b}[90m━\u{1b}[0m\u{1b}[35m━\u{1b}[0m\u{1b}[91m━\u{1b}[0m\u{1b}[91m━\u{1b}[0m\u{1b}[91m━\u{1b}[0m\u{1b}[91m━\u{1b}[0m\u{1b}[91m━\u{1b}[0m\u{1b}[91m━\u{1b}[0m\u{1b}[91m━\u{1b}[0m\u{1b}[35m━\u{1b}[0m\u{1b}[90m━\u{1b}[0m\u{1b}[90m━\u{1b}[0m|\n\u{1b}[91m━\u{1b}[0m\u{1b}[35m━\u{1b}[0m\u{1b}[90m━\u{1b}[0m\u{1b}[90m━\u{1b}[0m\u{1b}[90m━\u{1b}[0m\u{1b}[90m━\u{1b}[0m\u{1b}[90m━\u{1b}[0m\u{1b}[90m━\u{1b}[0m\u{1b}[90m━\u{1b}[0m\u{1b}[90m━\u{1b}[0m\u{1b}[90m━\u{1b}[0m\u{1b}[90m━\u{1b}[0m\u{1b}[90m━\u{1b}[0m\u{1b}[35m━\u{1b}[0m\u{1b}[91m━\u{1b}[0m\u{1b}[91m━\u{1b}[0m\u{1b}[91m━\u{1b}[0m\u{1b}[91m━\u{1b}[0m\u{1b}[91m━\u{1b}[0m\u{1b}[91m━\u{1b}[0m\u{1b}[91m━\u{1b}[0m\u{1b}[35m━\u{1b}[0m\u{1b}[90m━\u{1b}[0m\u{1b}[90m━\u{1b}[0m|\n",
    )
  }
  {
    let file = @rich.StringIO::new()
    let console = @rich.Console::new(
      file~,
      width=24,
      color_system=Some("standard"),
      legacy_windows=false,
      no_color=true,
      force_terminal=true,
      environ={},
    )
    let cases : Array[(Double?, Double, Int?, Bool, Double?)] = [
      (Some(100.0), 0.0, None, false, None),
      (Some(100.0), 33.0, Some(20), false, None),
      (Some(100.0), 34.0, Some(20), false, None),
      (Some(7.0), 7.0, Some(10), false, None),
      (Some(7.0), 9.0, None, false, None),
      (Some(0.0), 0.0, Some(12), false, None),
      (Some(100.0), -5.0, Some(8), false, None),
      (None, 0.0, Some(15), false, Some(1.234)),
      (Some(100.0), 50.0, Some(30), true, Some(0.5)),
    ]
    for case in cases {
      let (total, completed, width, pulse, animation_time) = case
      let bar = @progress_bar.ProgressBar::new(
        total~,
        completed~,
        width?,
        pulse~,
        animation_time?,
      )
      console.print(bar)
      console.print("|")
    }
    assert_eq(
      file.getvalue(),
      "|\n━━━━━━╸|\n━━━━━━╸|\n━━━━━━━━━━|\n━━━━━━━━━━━━━━━━━━━━━━━━|\n━━━━━━━━━━━━|\n|\n━━━━━━━━       |\n       ━━━━━━━━━━       |\n",
    )
  }
  {
    let file = @rich.StringIO::new()
    let console = @rich.Console::new(
      file~,
      width=24,
      color_system=Some("standard"),
      legacy_windows=true,
      no_color=false,
      force_terminal=true,
      environ={},
    )
    let cases : Array[(Double?, Double, Int?, Bool, Double?)] = [
      (Some(100.0), 0.0, None, false, None),
      (Some(100.0), 33.0, Some(20), false, None),
      (Some(100.0), 34.0, Some(20), false, None),
      (Some(7.0), 7.0, Some(10), false, None),
      (Some(7.0), 9.0, None, false, None),
      (Some(0.0), 0.0, Some(12), false, None),
      (Some(100.0), -5.0, Some(8), false, None),
      (None, 0.0, Some(15), false, Some(1.234)),
      (Some(100.0), 50.0, Some(30), true, Some(0.5)),
    ]
    for case in cases {
      let (total, completed, width, pulse, animation_time) = case
      let bar = @progress_bar.ProgressBar::new(
        total~,
        completed~,
        width?,
        pulse~,
        animation_time?,
      )
      console.print(bar)
      console.print("|")
    }
    assert_eq(
      file.getvalue(),
      "\u{1b}[90m------------------------\u{1b}[0m|\n\u{1b}[91m------\u{1b}[0m\u{1b}[91m \u{1b}[0m\u{1b}[90m-------------\u{1b}[0m|\n\u{1b}[91m------\u{1b}[0m\u{1b}[91m \u{1b}[0m\u{1b}[90m-------------\u{1b}[0m|\n\u{1b}[90m----------\u{1b}[0m|\n\u{1b}[90m------------------------\u{1b}[0m|\n\u{1b}[90m------------\u{1b}[0m|\n\u{1b}[90m--------\u{1b}[0m|\n\u{1b}[90m-\u{1b}[0m\u{1b}[90m-\u{1b}[0m\u{1b}[90m-\u{1b}[0m\u{1b}[90m-\u{1b}[0m\u{1b}[35m-\u{1b}[0m\u{1b}[91m-\u{1b}[0m\u{1b}[91m-\u{1b}[0m\u{1b}[91m-\u{1b}[0m\u{1b}[91m-\u{1b}[0m\u{1b}[91m-\u{1b}[0m\u{1b}[91m-\u{1b}[0m\u{1b}[91m-\u{1b}[0m\u{1b}[35m-\u{1b}[0m\u{1b}[90m-\u{1b}[0m\u{1b}[90m-\u{1b}[0m|\n\u{1b}[91m-\u{1b}[0m\u{1b}[35m-\u{1b}[0m\u{1b}[90m-\u{1b}[0m\u{1b}[90m-\u{1b}[0m\u{1b}[90m-\u{1b}[0m\u{1b}[90m-\u{1b}[0m\u{1b}[90m-\u{1b}[0m\u{1b}[90m-\u{1b}[0m\u{1b}[90m-\u{1b}[0m\u{1b}[90m-\u{1b}[0m\u{1b}[90m-\u{1b}[0m\u{1b}[90m-\u{1b}[0m\u{1b}[90m-\u{1b}[0m\u{1b}[35m-\u{1b}[0m\u{1b}[91m-\u{1b}[0m\u{1b}[91m-\u{1b}[0m\u{1b}[91m-\u{1b}[0m\u{1b}[91m-\u{1b}[0m\u{1b}[91m-\u{1b}[0m\u{1b}[91m-\u{1b}[0m\u{1b}[91m-\u{1b}[0m\u{1b}[35m-\u{1b}[0m\u{1b}[90m-\u{1b}[0m\u{1b}[90m-\u{1b}[0m|\n",
    )
  }
  {
    let file = @rich.StringIO::new()
    let console = @rich.Console::new(
      file~,
      width=24,
      color_system=Some("standard"),
      legacy_windows=true,
      no_color=true,
      force_terminal=true,
      environ={},
    )
    let cases : Array[(Double?, Double, Int?, Bool, Double?)] = [
      (Some(100.0), 0.0, None, false, None),
      (Some(100.0), 33.0, Some(20), false, None),
      (Some(100.0), 34.0, Some(20), false, None),
      (Some(7.0), 7.0, Some(10), false, None),
      (Some(7.0), 9.0, None, false, None),
      (Some(0.0), 0.0, Some(12), false, None),
      (Some(100.0), -5.0, Some(8), false, None),
      (None, 0.0, Some(15), false, Some(1.234)),
      (Some(100.0), 50.0, Some(30), true, Some(0.5)),
    ]
    for case in cases {
      let (total, completed, width, pulse, animation_time) = case
      let bar = @progress_bar.ProgressBar::new(
        total~,
        completed~,
        width?,
        pulse~,
        animation_time?,
      )
      console.print(bar)
      console.print("|")
    }
    assert_eq(
      file.getvalue(),
      "|\n------ |\n------ |\n----------|\n------------------------|\n------------|\n|\n--------       |\n       ----------       |\n",
    )
  }
  {
    let file = @rich.StringIO::new()
    let console = @rich.Console::new(
      file~,
      width=24,
      color_system=None,
      legacy_windows=false,
      no_color=false,
      force_terminal=true,
      environ={},
    )
    let cases : Array[(Double?, Double, Int?, Bool, Double?)] = [
      (Some(100.0), 0.0, None, false, None),
      (Some(100.0), 33.0, Some(20), false, None),
      (Some(100.0), 34.0, Some(20), false, None),
      (Some(7.0), 7.0, Some(10), false, None),
      (Some(7.0), 9.0, None, false, None),
      (Some(0.0), 0.0, Some(12), false, None),
      (Some(100.0), -5.0, Some(8), false, None),
      (None, 0.0, Some(15), false, Some(1.234)),
      (Some(100.0), 50.0, Some(30), true, Some(0.5)),
    ]
    for case in cases {
      let (total, completed, width, pulse, animation_time) = case
      let bar = @progress_bar.ProgressBar::new(
        total~,
        completed~,
        width?,
        pulse~,
        animation_time?,
      )
      console.print(bar)
      console.print("|")
    }
    assert_eq(
      file.getvalue(),
      "|\n━━━━━━╸|\n━━━━━━╸|\n━━━━━━━━━━|\n━━━━━━━━━━━━━━━━━━━━━━━━|\n━━━━━━━━━━━━|\n|\n━━━━━━━━━━━━━━━|\n━━━━━━━━━━━━━━━━━━━━━━━━|\n",
    )
  }
  {
    let file = @rich.StringIO::new()
    let console = @rich.Console::new(
      file~,
      width=24,
      color_system=None,
      legacy_windows=false,
      no_color=true,
      force_terminal=true,
      environ={},
    )
    let cases : Array[(Double?, Double, Int?, Bool, Double?)] = [
      (Some(100.0), 0.0, None, false, None),
      (Some(100.0), 33.0, Some(20), false, None),
      (Some(100.0), 34.0, Some(20), false, None),
      (Some(7.0), 7.0, Some(10), false, None),
      (Some(7.0), 9.0, None, false, None),
      (Some(0.0), 0.0, Some(12), false, None),
      (Some(100.0), -5.0, Some(8), false, None),
      (None, 0.0, Some(15), false, Some(1.234)),
      (Some(100.0), 50.0, Some(30), true, Some(0.5)),
    ]
    for case in cases {
      let (total, completed, width, pulse, animation_time) = case
      let bar = @progress_bar.ProgressBar::new(
        total~,
        completed~,
        width?,
        pulse~,
        animation_time?,
      )
      console.print(bar)
      console.print("|")
    }
    assert_eq(
      file.getvalue(),
      "|\n━━━━━━╸|\n━━━━━━╸|\n━━━━━━━━━━|\n━━━━━━━━━━━━━━━━━━━━━━━━|\n━━━━━━━━━━━━|\n|\n━━━━━━━━       |\n       ━━━━━━━━━━       |\n",
    )
  }
  {
    let file = @rich.StringIO::new()
    let console = @rich.Console::new(
      file~,
      width=24,
      color_system=None,
      legacy_windows=true,
      no_color=false,
      force_terminal=true,
      environ={},
    )
    let cases : Array[(Double?, Double, Int?, Bool, Double?)] = [
      (Some(100.0), 0.0, None, false, None),
      (Some(100.0), 33.0, Some(20), false, None),
      (Some(100.0), 34.0, Some(20), false, None),
      (Some(7.0), 7.0, Some(10), false, None),
      (Some(7.0), 9.0, None, false, None),
      (Some(0.0), 0.0, Some(12), false, None),
      (Some(100.0), -5.0, Some(8), false, None),
      (None, 0.0, Some(15), false, Some(1.234)),
      (Some(100.0), 50.0, Some(30), true, Some(0.5)),
    ]
    for case in cases {
      let (total, completed, width, pulse, animation_time) = case
      let bar = @progress_bar.ProgressBar::new(
        total~,
        completed~,
        width?,
        pulse~,
        animation_time?,
      )
      console.print(bar)
      console.print("|")
    }
    assert_eq(
      file.getvalue(),
      "|\n------ |\n------ |\n----------|\n------------------------|\n------------|\n|\n---------------|\n------------------------|\n",
    )
  }
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    file~,
    width=24,
    color_system=None,
    legacy_windows=true,
    no_color=true,
    force_terminal=true,
    environ={},
  )
  let cases : Array[(Double?, Double, Int?, Bool, Double?)] = [
    (Some(100.0), 0.0, None, false, None),
    (Some(100.0), 33.0, Some(20), false, None),
    (Some(100.0), 34.0, Some(20), false, None),
    (Some(7.0), 7.0, Some(10), false, None),
    (Some(7.0), 9.0, None, false, None),
    (Some(0.0), 0.0, Some(12), false, None),
    (Some(100.0), -5.0, Some(8), false, None),
    (None, 0.0, Some(15), false, Some(1.234)),
    (Some(100.0), 50.0, Some(30), true, Some(0.5)),
  ]
  for case in cases {
    let (total, completed, width, pulse, animation_time) = case
    let bar = @progress_bar.ProgressBar::new(
      total~,
      completed~,
      width?,
      pulse~,
      animation_time?,
    )
    console.print(bar)
    console.print("|")
  }
  assert_eq(
    file.getvalue(),
    "|\n------ |\n------ |\n----------|\n------------------------|\n------------|\n|\n--------       |\n       ----------       |\n",
  )
}
