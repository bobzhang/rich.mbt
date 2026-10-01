// Port of tests/test_rule.py and tests/test_rule_in_table.py.

///|
test "test_rule" {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    width=16,
    file~,
    force_terminal=true,
    legacy_windows=false,
    environ={},
  )
  console.print(@rich.Rule::new())
  console.print(@rich.Rule::new(title="foo"))
  console.rule(title=@rich.Text::new(text="foo", style="bold"))
  console.rule(title="foobarbazeggfoobarbazegg")
  let expected = "\u{1b}[92m────────────────\u{1b}[0m\n" +
    "\u{1b}[92m───── \u{1b}[0mfoo\u{1b}[92m ──────\u{1b}[0m\n" +
    "\u{1b}[92m───── \u{1b}[0m\u{1b}[1mfoo\u{1b}[0m\u{1b}[92m ──────\u{1b}[0m\n" +
    "\u{1b}[92m─ \u{1b}[0mfoobarbazeg…\u{1b}[92m ─\u{1b}[0m\n"
  assert_eq(file.getvalue(), expected)
}

// test_rule_error: `align` is an enum, so invalid values cannot be passed.

///|
test "test_rule_align" {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(width=16, file~, legacy_windows=false, environ={})
  console.rule(title="foo")
  console.rule(title="foo", align=Left)
  console.rule(title="foo", align=Center)
  console.rule(title="foo", align=Right)
  console.rule()
  let expected = "───── foo ──────\nfoo ────────────\n───── foo ──────\n──────────── foo\n────────────────\n"
  assert_eq(file.getvalue(), expected)
}

///|
test "test_rule_cjk" {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    width=16,
    file~,
    force_terminal=true,
    color_system=None,
    legacy_windows=false,
    environ={},
  )
  console.rule(title="欢迎！")
  assert_eq(file.getvalue(), "──── 欢迎！ ────\n")
}

///|
fn rule_console(width : Int) -> (@rich.Console, @rich.StringIO) raise {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(width~, file~, record=true, environ={})
  (console, file)
}

///|
test "test_rule_not_enough_space_for_title_text" {
  let cases : Array[(@rich.AlignMethod, String)] = [
    (Center, "───\n"),
    (Left, "… ─\n"),
    (Right, "─ …\n"),
  ]
  for case in cases {
    let (align, outcome) = case
    let (console, file) = rule_console(3)
    console.rule(title="Hello!", align~)
    assert_eq(file.getvalue(), outcome)
  }
}

///|
test "test_rule_center_aligned_title_not_enough_space_for_rule" {
  let (console, file) = rule_console(4)
  console.rule(title="ABCD")
  assert_eq(file.getvalue(), "────\n")
}

///|
test "test_rule_side_aligned_not_enough_space_for_rule" {
  for align in [@rich.AlignMethod::Left, Right] {
    let (console, file) = rule_console(2)
    console.rule(title="ABCD", align~)
    assert_eq(file.getvalue(), "──\n")
  }
}

///|
test "test_rule_just_enough_width_available_for_title" {
  let cases : Array[(@rich.AlignMethod, String)] = [
    (Center, "─ … ─\n"),
    (Left, "AB… ─\n"),
    (Right, "─ AB…\n"),
  ]
  for case in cases {
    let (align, outcome) = case
    let (console, file) = rule_console(5)
    console.rule(title="ABCD", align~)
    assert_eq(file.getvalue(), outcome)
  }
}

///|
test "test_characters" {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    width=16,
    file~,
    force_terminal=true,
    color_system=None,
    legacy_windows=false,
    environ={},
  )
  console.rule(characters="+*")
  console.rule(title="foo", characters="+*")
  console.print(@rich.Rule::new(characters=".,"))
  let expected = "+*+*+*+*+*+*+*+*\n" +
    "+*+*+ foo +*+*+*\n" +
    ".,.,.,.,.,.,.,.,\n"
  assert_eq(file.getvalue(), expected)
}

///|
test "test_repr" {
  let rule = @rich.Rule::new(title="foo")
  assert_eq(rule.repr(), "Rule('foo', '─')")
}

///|
test "test_error" {
  let result = try? @rich.Rule::new(characters="")
  assert_true(result is Err(ValueError(_)))
}

///|
test "test_rule_in_unexpanded_table" {
  for expand in [None, Some(false)] {
    let file = @rich.StringIO::new()
    let console = @rich.Console::new(width=32, file~, legacy_windows=false, environ={})
    let table = @rich.Table::new(
      box_=@rich.box_ascii,
      show_header=false,
      expand?,
    )
    table.add_column()
    table.add_column()
    table.add_row(["COL1", "COL2"])
    table.add_row(["COL1", @rich.Rule::new()])
    table.add_row(["COL1", "COL2"])
    console.print(table)
    let expected =
      #|+-------------+
      #|| COL1 | COL2 |
      #|| COL1 | ──── |
      #|| COL1 | COL2 |
      #|+-------------+
      #|
    assert_eq(file.getvalue(), expected)
  }
}

///|
test "test_rule_in_expanded_table" {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(width=32, file~, legacy_windows=false, environ={})
  let table = @rich.Table::new(
    box_=@rich.box_ascii,
    expand=true,
    show_header=false,
  )
  table.add_column()
  table.add_column()
  table.add_row(["COL1", "COL2"])
  // upstream: Rule(style=None)
  table.add_row(["COL1", @rich.Rule::new(style="")])
  table.add_row(["COL1", "COL2"])
  console.print(table)
  let expected =
    #|+------------------------------+
    #|| COL1          | COL2         |
    #|| COL1          | ──────────── |
    #|| COL1          | COL2         |
    #|+------------------------------+
    #|
  assert_eq(file.getvalue(), expected)
}

///|
test "test_rule_in_ratio_table" {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(width=32, file~, legacy_windows=false, environ={})
  let table = @rich.Table::new(
    box_=@rich.box_ascii,
    expand=true,
    show_header=false,
  )
  table.add_column(ratio=1)
  table.add_column()
  table.add_row(["COL1", "COL2"])
  table.add_row(["COL1", @rich.Rule::new(style="")])
  table.add_row(["COL1", "COL2"])
  console.print(table)
  let expected =
    #|+------------------------------+
    #|| COL1                  | COL2 |
    #|| COL1                  | ──── |
    #|| COL1                  | COL2 |
    #|+------------------------------+
    #|
  assert_eq(file.getvalue(), expected)
}
