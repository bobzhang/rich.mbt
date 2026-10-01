// Port of tests/test_segment.py.

///|
fn seg(text : String, style? : @rich.Style) -> @rich.Segment {
  @rich.Segment::new(text, style?)
}

///|
fn segs_repr(segments : Array[@rich.Segment]) -> String {
  "[" + segments.map(s => s.repr()).join(", ") + "]"
}

///|
fn lines_repr(lines : Array[Array[@rich.Segment]]) -> String {
  "[" + lines.map(segs_repr).join(", ") + "]"
}

///|
test "repr" {
  inspect(seg("foo").repr(), content="Segment('foo')")
  inspect(
    @rich.Segment::new("foo", control=[CodeInt(Home, 0)]).repr(),
    content="Segment('foo', None, [(<ControlType.HOME: 3>, 0)])",
  )
}

///|
test "line" {
  assert_eq(@rich.Segment::line(), seg("\n"))
}

///|
test "apply_style" {
  let segments = [seg("foo"), seg("bar", style=@rich.Style::new(bold=true))]
  assert_true(physical_equal(@rich.Segment::apply_style(segments), segments))
  assert_eq(
    @rich.Segment::apply_style(segments, style=@rich.Style::new(italic=true)),
    [
      seg("foo", style=@rich.Style::new(italic=true)),
      seg("bar", style=@rich.Style::new(italic=true, bold=true)),
    ],
  )
}

///|
test "split_lines" {
  let lines = [seg("Hello\nWorld")]
  assert_eq(@rich.Segment::split_lines(lines), [[seg("Hello")], [seg("World")]])
}

///|
test "split_lines_terminator" {
  let lines = [seg("Hello\nWorld")]
  assert_eq(@rich.Segment::split_lines_terminator(lines), [
    ([seg("Hello")], true),
    ([seg("World")], false),
  ])
}

///|
test "split_lines_terminator_single_line" {
  let lines = [seg("Hello")]
  assert_eq(@rich.Segment::split_lines_terminator(lines), [
    ([seg("Hello")], false),
  ])
}

///|
test "split_and_crop_lines" {
  assert_eq(
    @rich.Segment::split_and_crop_lines([seg("Hello\nWorld!\n"), seg("foo")], 4),
    [[seg("Hell"), seg("\n")], [seg("Worl"), seg("\n")], [seg("foo"), seg(" ")]],
  )
}

///|
test "adjust_line_length" {
  // upstream uses arbitrary objects ("foo", "bar") as styles
  let foo = @rich.Style::new(bold=true)
  let bar = @rich.Style::new(italic=true)
  let line = [seg("Hello", style=foo)]
  assert_eq(@rich.Segment::adjust_line_length(line, 10, style=bar), [
    seg("Hello", style=foo),
    seg("     ", style=bar),
  ])
  let line = [seg("H"), seg("ello, World!")]
  assert_eq(@rich.Segment::adjust_line_length(line, 5), [seg("H"), seg("ello")])
  let line = [seg("Hello")]
  assert_eq(@rich.Segment::adjust_line_length(line, 5), line)
}

///|
test "get_line_length" {
  inspect(@rich.Segment::get_line_length([seg("foo"), seg("bar")]), content="6")
}

///|
test "get_shape" {
  assert_eq(@rich.Segment::get_shape([[seg("Hello")]]), (5, 1))
  assert_eq(@rich.Segment::get_shape([[seg("Hello")], [seg("World!")]]), (6, 2))
  assert_eq(@rich.Segment::get_shape([]), (0, 0))
}

///|
test "set_shape" {
  assert_eq(@rich.Segment::set_shape([[seg("Hello")]], 10), [
    [seg("Hello"), seg("     ")],
  ])
  assert_eq(@rich.Segment::set_shape([[seg("Hello")]], 10, height=2), [
    [seg("Hello"), seg("     ")],
    [seg(" ".repeat(10))],
  ])
}

///|
test "simplify" {
  assert_eq(@rich.Segment::simplify([seg("Hello"), seg(" "), seg("World!")]), [
    seg("Hello World!"),
  ])
  let red = @rich.Style::parse("red")
  let blue = @rich.Style::parse("blue")
  assert_eq(
    @rich.Segment::simplify([
      seg("Hello", style=red),
      seg(" ", style=red),
      seg("World!", style=blue),
    ]),
    [seg("Hello ", style=red), seg("World!", style=blue)],
  )
  assert_eq(@rich.Segment::simplify([]), [])
}

///|
test "filter_control" {
  let control_code : @rich.ControlCode = CodeInt(Home, 0)
  let segments = [seg("foo"), @rich.Segment::new("bar", control=[control_code])]
  assert_eq(@rich.Segment::filter_control(segments), [seg("foo")])
  assert_eq(@rich.Segment::filter_control(segments, is_control=true), [
    @rich.Segment::new("bar", control=[control_code]),
  ])
}

///|
test "strip_styles" {
  let segments = [seg("foo", style=@rich.Style::new(bold=true))]
  assert_eq(@rich.Segment::strip_styles(segments), [seg("foo")])
}

///|
test "strip_links" {
  let segments = [
    seg(
      "foo",
      style=@rich.Style::new(bold=true, link="https://www.example.org"),
    ),
  ]
  assert_eq(@rich.Segment::strip_links(segments), [
    seg("foo", style=@rich.Style::new(bold=true)),
  ])
  // a null style is replaced by None
  assert_eq(
    @rich.Segment::strip_links([seg("foo", style=@rich.Style::null())]),
    [seg("foo")],
  )
}

///|
test "remove_color" {
  let segments = [
    seg("foo", style=@rich.Style::new(bold=true, color=color("red"))),
    seg("bar"),
  ]
  assert_eq(@rich.Segment::remove_color(segments), [
    seg("foo", style=@rich.Style::new(bold=true)),
    seg("bar"),
  ])
}

///|
test "is_control" {
  let bold = @rich.Style::new(bold=true)
  assert_false(seg("foo", style=bold).is_control())
  assert_true(@rich.Segment::new("foo", style=bold, control=[]).is_control())
  assert_true(
    @rich.Segment::new("foo", style=bold, control=[CodeInt(Home, 0)]).is_control(),
  )
}

///|
test "bool" {
  assert_true(seg("foo").to_bool())
  assert_false(seg("").to_bool())
}

///|
fn render_items(items : Array[@rich.RenderItem]) -> Array[@rich.Segment] {
  items.map(item => {
    match item {
      Seg(s) => s
      Child(_) => abort("unexpected child")
    }
  })
}

///|
test "segments_renderable" {
  let console = @rich.Console::new()
  let segments = @rich.Segments::new([seg("foo")])
  assert_eq(render_items(segments.rich_console(console, console.options())), [
    seg("foo"),
  ])
  let segments = @rich.Segments::new([seg("foo")], new_lines=true)
  assert_eq(render_items(segments.rich_console(console, console.options())), [
    seg("foo"),
    @rich.Segment::line(),
  ])
}

///|
test "divide" {
  let bold = @rich.Style::new(bold=true)
  let italic = @rich.Style::new(italic=true)
  let segments = [seg("Hello", style=bold), seg(" World!", style=italic)]
  assert_eq(@rich.Segment::divide(segments, []), [])
  assert_eq(@rich.Segment::divide([], [1]), [[]])
  assert_eq(@rich.Segment::divide(segments, [1]), [[seg("H", style=bold)]])
  assert_eq(@rich.Segment::divide(segments, [1, 2]), [
    [seg("H", style=bold)],
    [seg("e", style=bold)],
  ])
  assert_eq(@rich.Segment::divide(segments, [1, 2, 12]), [
    [seg("H", style=bold)],
    [seg("e", style=bold)],
    [seg("llo", style=bold), seg(" World!", style=italic)],
  ])
  assert_eq(@rich.Segment::divide(segments, [4, 20]), [
    [seg("Hell", style=bold)],
    [seg("o", style=bold), seg(" World!", style=italic)],
  ])
}

///|
test "divide_complex" {
  let map = "[on orange4]          [on green]XX[on orange4]          \n" +
    "                        \n" +
    "                        \n" +
    "                        \n" +
    "              [bright_red on black]Y[on orange4]        \n" +
    "[on green]X[on orange4]                  [on green]X[on orange4]  \n" +
    " [on green]X[on orange4]                   [on green]X\n" +
    "[on orange4]                        \n" +
    "          [on green]XX[on orange4]          \n"
  let text = @rich.Text::from_markup(map)
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    color_system=Some("truecolor"),
    width=30,
    force_terminal=true,
    file~,
    legacy_windows=false,
    environ={},
  )
  console.print(text)
  assert_eq(
    file.getvalue(),
    "\u{1b}[48;5;94m          \u{1b}[0m\u{1b}[42mXX\u{1b}[0m\u{1b}[48;5;94m          \u{1b}[0m\n\u{1b}[48;5;94m                        \u{1b}[0m\n\u{1b}[48;5;94m                        \u{1b}[0m\n\u{1b}[48;5;94m                        \u{1b}[0m\n\u{1b}[48;5;94m              \u{1b}[0m\u{1b}[91;40mY\u{1b}[0m\u{1b}[91;48;5;94m        \u{1b}[0m\n\u{1b}[91;42mX\u{1b}[0m\u{1b}[91;48;5;94m                  \u{1b}[0m\u{1b}[91;42mX\u{1b}[0m\u{1b}[91;48;5;94m  \u{1b}[0m\n\u{1b}[91;48;5;94m \u{1b}[0m\u{1b}[91;42mX\u{1b}[0m\u{1b}[91;48;5;94m                   \u{1b}[0m\u{1b}[91;42mX\u{1b}[0m\n\u{1b}[91;48;5;94m                        \u{1b}[0m\n\u{1b}[91;48;5;94m          \u{1b}[0m\u{1b}[91;42mXX\u{1b}[0m\u{1b}[91;48;5;94m          \u{1b}[0m\n\n",
  )
}

///|
test "divide_emoji" {
  let bold = @rich.Style::new(bold=true)
  let italic = @rich.Style::new(italic=true)
  let segments = [seg("Hello", style=bold), seg("💩💩💩", style=italic)]
  assert_eq(@rich.Segment::divide(segments, [7]), [
    [seg("Hello", style=bold), seg("💩", style=italic)],
  ])
  assert_eq(@rich.Segment::divide(segments, [8]), [
    [seg("Hello", style=bold), seg("💩 ", style=italic)],
  ])
  assert_eq(@rich.Segment::divide(segments, [9]), [
    [seg("Hello", style=bold), seg("💩💩", style=italic)],
  ])
  assert_eq(@rich.Segment::divide(segments, [8, 11]), [
    [seg("Hello", style=bold), seg("💩 ", style=italic)],
    [seg(" 💩", style=italic)],
  ])
  assert_eq(@rich.Segment::divide(segments, [9, 11]), [
    [seg("Hello", style=bold), seg("💩💩", style=italic)],
    [seg("💩", style=italic)],
  ])
}

///|
test "divide_edge" {
  let segments = [seg("foo"), seg("bar"), seg("baz")]
  assert_eq(@rich.Segment::divide(segments, [1, 3, 9]), [
    [seg("f")],
    [seg("oo")],
    [seg("bar"), seg("baz")],
  ])
}

///|
test "divide_edge_2" {
  let segments = [
    seg("╭─"),
    seg("────── Placeholder ───────"),
    seg("─╮"),
  ]
  assert_eq(@rich.Segment::divide(segments, [30, 60]), [segments, []])
}

///|
test "split_cells_emoji" {
  let cases : Array[(String, Int, String, String)] = [
    ("XX", 4, "XX", ""),
    ("X", 1, "X", ""),
    ("💩", 1, " ", " "),
    ("XY", 1, "X", "Y"),
    ("💩X", 1, " ", " X"),
    ("💩💩", 1, " ", " 💩"),
    ("X💩Y", 2, "X ", " Y"),
    ("X💩YZ", 2, "X ", " YZ"),
    ("X💩💩Z", 2, "X ", " 💩Z"),
    ("X💩💩Z", 3, "X💩", "💩Z"),
    ("X💩💩Z", 4, "X💩 ", " Z"),
    ("X💩💩Z", 5, "X💩💩", "Z"),
    ("X💩💩Z", 6, "X💩💩Z", ""),
    ("XYZABC💩💩", 6, "XYZABC", "💩💩"),
    ("XYZABC💩💩", 7, "XYZABC ", " 💩"),
    ("XYZABC💩💩", 8, "XYZABC💩", "💩"),
    ("XYZABC💩💩", 9, "XYZABC💩 ", " "),
    ("XYZABC💩💩", 10, "XYZABC💩💩", ""),
    ("💩💩💩💩💩", 3, "💩 ", " 💩💩💩"),
    ("💩💩💩💩💩", 4, "💩💩", "💩💩💩"),
    ("💩X💩Y💩Z💩A💩", 4, "💩X ", " Y💩Z💩A💩"),
    ("XYZABC", 4, "XYZA", "BC"),
    ("XYZABC", 5, "XYZAB", "C"),
    ("a1あ１１bcdaef", 9, "a1あ１１b", "cdaef"),
  ]
  for case in cases {
    let (text, split, left, right) = case
    assert_eq(seg(text).split_cells(split), (seg(left), seg(right)))
  }
}

///|
test "split_cells_mixed" {
  let segments = [
    seg("早乙女リリエル (CV: 徳井青）"),
    seg("メイド・イン・きゅんクチュアリ☆    "),
    seg(
      "TVアニメ「メルクストーリア -無気力少年と瓶の中の少女-」 主題歌CD",
    ),
    seg("南無阿弥JKうらめしや?！     "),
    seg("メルク (CV: 水瀬いのり)     "),
    seg(" メルク (CV: 水瀬いのり)     "),
    seg("  メルク (CV: 水瀬いのり)     "),
    seg("  メルク (CV: 水瀬いのり)      "),
  ]
  for segment in segments {
    for c in segment.text {
      assert_true(@cells.cell_len(c.to_string()) > 0)
    }
    for position in 0..<=segment.cell_length() {
      let (left, right) = segment.split_cells(position)
      assert_eq(@cells.cell_len(left.text), position)
      assert_eq(@cells.cell_len(right.text), segment.cell_length() - position)
    }
  }
}

///|
test "split_cells_doubles" {
  let test_ = seg("早".repeat(20))
  for position in 1..<test_.cell_length() {
    let (left, right) = test_.split_cells(position)
    assert_eq(@cells.cell_len(left.text), position)
    assert_eq(@cells.cell_len(right.text), test_.cell_length() - position)
  }
}

///|
test "split_cells_single" {
  let test_ = seg("A".repeat(20))
  for position in 1..<test_.cell_length() {
    let (left, right) = test_.split_cells(position)
    assert_eq(@cells.cell_len(left.text), position)
    assert_eq(@cells.cell_len(right.text), test_.cell_length() - position)
  }
}

///|
test "segment_lines_renderable" {
  let console = @rich.Console::new()
  let lines = [[seg("hello"), seg(" "), seg("world")], [seg("foo")]]
  let segment_lines = @rich.SegmentLines::new(lines)
  assert_eq(
    render_items(segment_lines.rich_console(console, console.options())),
    [seg("hello"), seg(" "), seg("world"), seg("foo")],
  )
  let segment_lines = @rich.SegmentLines::new(lines, new_lines=true)
  assert_eq(
    render_items(segment_lines.rich_console(console, console.options())),
    [seg("hello"), seg(" "), seg("world"), seg("\n"), seg("foo"), seg("\n")],
  )
}

///|
test "align_top" {
  let lines = [[seg("X")]]
  let style = @rich.Style::new()
  assert_eq(@rich.Segment::align_top(lines, 3, 1, Some(style)), lines)
  assert_eq(@rich.Segment::align_top(lines, 3, 3, Some(style)), [
    [seg("X")],
    [seg("   ", style~)],
    [seg("   ", style~)],
  ])
}

///|
test "align_middle" {
  let lines = [[seg("X")]]
  let style = @rich.Style::new()
  assert_eq(@rich.Segment::align_middle(lines, 3, 1, Some(style)), lines)
  assert_eq(@rich.Segment::align_middle(lines, 3, 3, Some(style)), [
    [seg("   ", style~)],
    [seg("X")],
    [seg("   ", style~)],
  ])
}

///|
test "align_bottom" {
  let lines = [[seg("X")]]
  let style = @rich.Style::new()
  assert_eq(@rich.Segment::align_bottom(lines, 3, 1, Some(style)), lines)
  assert_eq(@rich.Segment::align_bottom(lines, 3, 3, Some(style)), [
    [seg("   ", style~)],
    [seg("   ", style~)],
    [seg("X")],
  ])
}

///|
test "lines repr helper" {
  inspect(lines_repr([[seg("a")], []]), content="[[Segment('a')], []]")
}
