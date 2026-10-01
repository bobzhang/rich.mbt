// Port of tests/test_table.py.

///|
fn render_tables() -> String raise {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    width=60,
    force_terminal=true,
    file~,
    legacy_windows=false,
    color_system=None,
    environ={},
  )
  let table = @rich.Table::new(
    title="test table",
    caption="table caption",
    expand=false,
  )
  table.add_column(
    header="foo",
    footer=@rich.Text::new(text="total"),
    no_wrap=true,
    overflow=Ellipsis,
  )
  table.add_column(header="bar", justify=Center)
  table.add_column(header="baz", justify=Right)
  // upstream passes None for the last cell
  table.add_row(["Averlongwordgoeshere", "banana pancakes", ""])
  assert_eq(
    @rich.Measurement::get(console, console.options(), table),
    @rich.Measurement::new(41, 48),
  )
  table.set_expand(true)
  assert_eq(
    @rich.Measurement::get(console, console.options(), table),
    @rich.Measurement::new(41, 48),
  )
  for width = 10; width < 60; width = width + 5 {
    console.print(table, width~)
  }
  table.set_expand(false)
  console.print(table, justify=Left)
  console.print(table, justify=Center)
  console.print(table, justify=Right)
  assert_eq(table.row_count(), 1)
  table.row_styles = [Def("red"), Def("yellow")]
  table.add_row(["Coffee"])
  table.add_row(["Coffee", "Chocolate", "", "cinnamon"])
  assert_eq(table.row_count(), 3)
  console.print(table)
  table.show_lines = true
  console.print(table)
  table.show_footer = true
  console.print(table)
  table.show_edge = false
  console.print(table)
  table.set_padding([1])
  console.print(table)
  table.width = Some(20)
  assert_eq(
    @rich.Measurement::get(console, console.options(), table),
    @rich.Measurement::new(20, 20),
  )
  table.set_expand(false)
  assert_eq(
    @rich.Measurement::get(console, console.options(), table),
    @rich.Measurement::new(20, 20),
  )
  table.set_expand(true)
  console.print(table)
  table.columns[0].no_wrap = true
  table.columns[1].no_wrap = true
  table.columns[2].no_wrap = true
  console.print(table)
  table.set_padding([0])
  table.width = Some(60)
  table.leading = 1
  console.print(table)
  file.getvalue()
}

///|
test "test_render_table" {
  let expected = "test table\n┏━━━━━━┳┳┓\n┃ foo  ┃┃┃\n┡━━━━━━╇╇┩\n│ Ave… │││\n└──────┴┴┘\n  table   \n caption  \n  test table   \n┏━━━━━━━━━━━┳┳┓\n┃ foo       ┃┃┃\n┡━━━━━━━━━━━╇╇┩\n│ Averlong… │││\n└───────────┴┴┘\n table caption \n     test table     \n┏━━━━━━━━━━━━━━━━┳┳┓\n┃ foo            ┃┃┃\n┡━━━━━━━━━━━━━━━━╇╇┩\n│ Averlongwordg… │││\n└────────────────┴┴┘\n   table caption    \n       test table        \n┏━━━━━━━━━━━━━━━━━━━━━┳┳┓\n┃ foo                 ┃┃┃\n┡━━━━━━━━━━━━━━━━━━━━━╇╇┩\n│ Averlongwordgoeshe… │││\n└─────────────────────┴┴┘\n      table caption      \n          test table          \n┏━━━━━━━━━━━━━━━━━━━━━━┳━━┳━━┓\n┃ foo                  ┃  ┃  ┃\n┡━━━━━━━━━━━━━━━━━━━━━━╇━━╇━━┩\n│ Averlongwordgoeshere │  │  │\n└──────────────────────┴──┴──┘\n        table caption         \n            test table             \n┏━━━━━━━━━━━━━━━━━━━━━━┳━━━━━┳━━━━┓\n┃ foo                  ┃ bar ┃ b… ┃\n┡━━━━━━━━━━━━━━━━━━━━━━╇━━━━━╇━━━━┩\n│ Averlongwordgoeshere │ ba… │    │\n│                      │ pa… │    │\n└──────────────────────┴─────┴────┘\n           table caption           \n               test table               \n┏━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━┳━━━━━┓\n┃ foo                  ┃   bar   ┃ baz ┃\n┡━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━╇━━━━━┩\n│ Averlongwordgoeshere │ banana  │     │\n│                      │ pancak… │     │\n└──────────────────────┴─────────┴─────┘\n             table caption              \n                 test table                  \n┏━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━┳━━━━━┓\n┃ foo                  ┃     bar      ┃ baz ┃\n┡━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━━━━━╇━━━━━┩\n│ Averlongwordgoeshere │    banana    │     │\n│                      │   pancakes   │     │\n└──────────────────────┴──────────────┴─────┘\n                table caption                \n                    test table                    \n┏━━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━┳━━━━━┓\n┃ foo                   ┃       bar        ┃ baz ┃\n┡━━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━━━━━━━━━╇━━━━━┩\n│ Averlongwordgoeshere  │ banana pancakes  │     │\n└───────────────────────┴──────────────────┴─────┘\n                  table caption                   \n                      test table                       \n┏━━━━━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━┳━━━━━┓\n┃ foo                      ┃        bar         ┃ baz ┃\n┡━━━━━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━━━━━━━━━━━╇━━━━━┩\n│ Averlongwordgoeshere     │  banana pancakes   │     │\n└──────────────────────────┴────────────────────┴─────┘\n                     table caption                     \n                   test table                               \n┏━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━┳━━━━━┓            \n┃ foo                  ┃       bar       ┃ baz ┃            \n┡━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━━━━━━━━╇━━━━━┩            \n│ Averlongwordgoeshere │ banana pancakes │     │            \n└──────────────────────┴─────────────────┴─────┘            \n                 table caption                              \n                         test table                         \n      ┏━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━┳━━━━━┓      \n      ┃ foo                  ┃       bar       ┃ baz ┃      \n      ┡━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━━━━━━━━╇━━━━━┩      \n      │ Averlongwordgoeshere │ banana pancakes │     │      \n      └──────────────────────┴─────────────────┴─────┘      \n                       table caption                        \n                               test table                   \n            ┏━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━┳━━━━━┓\n            ┃ foo                  ┃       bar       ┃ baz ┃\n            ┡━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━━━━━━━━╇━━━━━┩\n            │ Averlongwordgoeshere │ banana pancakes │     │\n            └──────────────────────┴─────────────────┴─────┘\n                             table caption                  \n                        test table                         \n┏━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━┳━━━━━┳━━━━━━━━━━┓\n┃ foo                  ┃       bar       ┃ baz ┃          ┃\n┡━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━━━━━━━━╇━━━━━╇━━━━━━━━━━┩\n│ Averlongwordgoeshere │ banana pancakes │     │          │\n│ Coffee               │                 │     │          │\n│ Coffee               │    Chocolate    │     │ cinnamon │\n└──────────────────────┴─────────────────┴─────┴──────────┘\n                       table caption                       \n                        test table                         \n┏━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━┳━━━━━┳━━━━━━━━━━┓\n┃ foo                  ┃       bar       ┃ baz ┃          ┃\n┡━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━━━━━━━━╇━━━━━╇━━━━━━━━━━┩\n│ Averlongwordgoeshere │ banana pancakes │     │          │\n├──────────────────────┼─────────────────┼─────┼──────────┤\n│ Coffee               │                 │     │          │\n├──────────────────────┼─────────────────┼─────┼──────────┤\n│ Coffee               │    Chocolate    │     │ cinnamon │\n└──────────────────────┴─────────────────┴─────┴──────────┘\n                       table caption                       \n                        test table                         \n┏━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━┳━━━━━┳━━━━━━━━━━┓\n┃ foo                  ┃       bar       ┃ baz ┃          ┃\n┡━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━━━━━━━━╇━━━━━╇━━━━━━━━━━┩\n│ Averlongwordgoeshere │ banana pancakes │     │          │\n├──────────────────────┼─────────────────┼─────┼──────────┤\n│ Coffee               │                 │     │          │\n├──────────────────────┼─────────────────┼─────┼──────────┤\n│ Coffee               │    Chocolate    │     │ cinnamon │\n├──────────────────────┼─────────────────┼─────┼──────────┤\n│ total                │                 │     │          │\n└──────────────────────┴─────────────────┴─────┴──────────┘\n                       table caption                       \n                       test table                        \n foo                  ┃       bar       ┃ baz ┃          \n━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━━━━━━━━╇━━━━━╇━━━━━━━━━━\n Averlongwordgoeshere │ banana pancakes │     │          \n──────────────────────┼─────────────────┼─────┼──────────\n Coffee               │                 │     │          \n──────────────────────┼─────────────────┼─────┼──────────\n Coffee               │    Chocolate    │     │ cinnamon \n──────────────────────┼─────────────────┼─────┼──────────\n total                │                 │     │          \n                      table caption                      \n                       test table                        \n                      ┃                 ┃     ┃          \n foo                  ┃       bar       ┃ baz ┃          \n                      ┃                 ┃     ┃          \n━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━━━━━━━━╇━━━━━╇━━━━━━━━━━\n                      │                 │     │          \n Averlongwordgoeshere │ banana pancakes │     │          \n                      │                 │     │          \n──────────────────────┼─────────────────┼─────┼──────────\n                      │                 │     │          \n Coffee               │                 │     │          \n                      │                 │     │          \n──────────────────────┼─────────────────┼─────┼──────────\n                      │                 │     │          \n Coffee               │    Chocolate    │     │ cinnamon \n                      │                 │     │          \n──────────────────────┼─────────────────┼─────┼──────────\n                      │                 │     │          \n total                │                 │     │          \n                      │                 │     │          \n                      table caption                      \n     test table     \n                 ┃┃┃\n foo             ┃┃┃\n                 ┃┃┃\n━━━━━━━━━━━━━━━━━╇╇╇\n                 │││\n Averlongwordgo… │││\n                 │││\n─────────────────┼┼┼\n                 │││\n Coffee          │││\n                 │││\n─────────────────┼┼┼\n                 │││\n Coffee          │││\n                 │││\n─────────────────┼┼┼\n                 │││\n total           │││\n                 │││\n   table caption    \n      test table      \n          ┃         ┃┃\n foo      ┃   bar   ┃┃\n          ┃         ┃┃\n━━━━━━━━━━╇━━━━━━━━━╇╇\n          │         ││\n Averlon… │ banana… ││\n          │         ││\n──────────┼─────────┼┼\n          │         ││\n Coffee   │         ││\n          │         ││\n──────────┼─────────┼┼\n          │         ││\n Coffee   │ Chocol… ││\n          │         ││\n──────────┼─────────┼┼\n          │         ││\n total    │         ││\n          │         ││\n    table caption     \n                         test table                         \nfoo                      ┃        bar        ┃ baz┃         \n━━━━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━━━━━━━━━━╇━━━━╇━━━━━━━━━\nAverlongwordgoeshere     │  banana pancakes  │    │         \n                         │                   │    │         \nCoffee                   │                   │    │         \n                         │                   │    │         \nCoffee                   │     Chocolate     │    │cinnamon \n─────────────────────────┼───────────────────┼────┼─────────\ntotal                    │                   │    │         \n                       table caption                        \n"
  let result = render_tables()
  assert_eq(result, expected)
}

// test_not_renderable: cells are statically typed renderables.

///|
test "test_init_append_column" {
  let header_names = ["header1", "header2", "header3"]
  let table = @rich.Table::new(
    headers=header_names.map(h => (h : &@rich.IntoColumn)),
  )
  assert_eq(table.columns.length(), 3)
  for i, column in table.columns {
    assert_true(column.header.text_kind() is Str(h) && h == header_names[i])
  }
  let test_columns = header_names.map(h => @rich.Column::new(header=h))
  let table = @rich.Table::new(
    headers=test_columns.map(c => (c : &@rich.IntoColumn)),
  )
  assert_eq(table.columns.length(), 3)
  for i, column in table.columns {
    assert_true(column.header.text_kind() is Str(h) && h == header_names[i])
  }
}

///|
test "test_rich_measure" {
  let console = @rich.Console::new(width=80, environ={})
  assert_eq(
    @rich.Table::new(headers=["test_header"], width=-1).rich_measure(
      console,
      console.options(),
    ),
    Some(@rich.Measurement::new(0, 0)),
  )
  assert_eq(
    @rich.Table::new(headers=["test_header"]).rich_measure(
      console,
      console.options().update_width(10),
    ),
    Some(@rich.Measurement::new(10, 10)),
  )
}

///|
test "test_min_width" {
  let table = @rich.Table::new(headers=["foo"], min_width=30)
  table.add_row(["bar"])
  let console = @rich.Console::new(width=80, environ={})
  assert_eq(
    table.rich_measure(console, console.options().update_width(100)),
    Some(@rich.Measurement::new(30, 30)),
  )
  let console = @rich.Console::new(color_system=None, width=80, environ={})
  console.begin_capture()
  console.print(table)
  let output = console.end_capture()
  for line in output.split("\n") {
    if line != "" {
      assert_eq(line.length(), 30)
    }
  }
}

///|
test "test_no_columns" {
  let console = @rich.Console::new(color_system=None, width=80, environ={})
  console.begin_capture()
  console.print(@rich.Table::new())
  let output = console.end_capture()
  assert_eq(output, "\n")
}

///|
test "test_get_row_style" {
  let console = @rich.Console::new(width=80, environ={})
  let table = @rich.Table::new()
  table.add_row(["foo"])
  table.add_row(["bar"], style="on red")
  assert_true(table.get_row_style(console, 0) == @rich.Style::parse(""))
  assert_true(table.get_row_style(console, 1) == @rich.Style::parse("on red"))
}

///|
test "test_vertical_align_top" {
  let console = @rich.Console::new(width=80, environ={})
  fn make_table(
    vertical_align : @rich.VerticalAlignMethod,
  ) -> @rich.Table raise {
    let table = @rich.Table::new(show_header=false, box_=@rich.box_square)
    table.add_column(vertical=vertical_align)
    table.add_row(["foo", ["bar", "bar", "bar", "bar", "bar"].join("\n")])
    table
  }

  let result = console.capture(() => {
    console.print(make_table(Top))
    console.print_many([])
    console.print(make_table(Middle))
    console.print_many([])
    console.print(make_table(Bottom))
    console.print_many([])
  })
  let expected = "┌─────┬─────┐\n│ foo │ bar │\n│     │ bar │\n│     │ bar │\n│     │ bar │\n│     │ bar │\n└─────┴─────┘\n\n┌─────┬─────┐\n│     │ bar │\n│     │ bar │\n│ foo │ bar │\n│     │ bar │\n│     │ bar │\n└─────┴─────┘\n\n┌─────┬─────┐\n│     │ bar │\n│     │ bar │\n│     │ bar │\n│     │ bar │\n│ foo │ bar │\n└─────┴─────┘\n\n"
  assert_eq(result, expected)
}

///|
test "test_table_show_header_false_substitution" {
  let cases : Array[(@rich.Box?, String)] = [
    (None, " 1  2 \n 3  4 \n"),
    (
      Some(@rich.box_heavy_head),
      "┌───┬───┐\n│ 1 │ 2 │\n│ 3 │ 4 │\n└───┴───┘\n",
    ),
    (
      Some(@rich.box_square_double_head),
      "┌───┬───┐\n│ 1 │ 2 │\n│ 3 │ 4 │\n└───┴───┘\n",
    ),
    (
      Some(@rich.box_minimal_double_head),
      "    ╷    \n  1 │ 2  \n  3 │ 4  \n    ╵    \n",
    ),
    (
      Some(@rich.box_minimal_heavy_head),
      "    ╷    \n  1 │ 2  \n  3 │ 4  \n    ╵    \n",
    ),
    (
      Some(@rich.box_ascii_double_head),
      "+---+---+\n| 1 | 2 |\n| 3 | 4 |\n+---+---+\n",
    ),
  ]
  for case in cases {
    let (box_, result) = case
    let table = match box_ {
      Some(b) => @rich.Table::new(show_header=false, box_=b)
      None => @rich.Table::new(show_header=false, no_box=true)
    }
    table.add_column()
    table.add_column()
    table.add_row(["1", "2"])
    table.add_row(["3", "4"])
    let console = @rich.Console::new(
      record=true,
      width=80,
      file=@rich.NullFile::new(),
      environ={},
    )
    console.print(table)
    let output = console.export_text()
    assert_eq(output, result)
  }
}

///|
test "test_section" {
  let table = @rich.Table::new(headers=["foo"])
  table.add_section() // Null-op
  table.add_row(["row1"])
  table.add_row(["row2"], end_section=true)
  table.add_row(["row3"])
  table.add_row(["row4"])
  table.add_section()
  table.add_row(["row5"])
  table.add_section() // Null-op
  let console = @rich.Console::new(
    width=80,
    force_terminal=true,
    color_system=Some("truecolor"),
    legacy_windows=false,
    record=true,
    file=@rich.NullFile::new(),
    environ={},
  )
  console.print(table)
  let output = console.export_text()
  let expected = "┏━━━━━━┓\n┃ foo  ┃\n┡━━━━━━┩\n│ row1 │\n│ row2 │\n├──────┤\n│ row3 │\n│ row4 │\n├──────┤\n│ row5 │\n└──────┘\n"
  assert_eq(output, expected)
}

///|
test "test_placement_table_box_elements" {
  let cases : Array[(Bool, Bool, String)] = [
    (
      false,
      false,
      (
        #|abbbbbcbbbbbbbbbcbbbbcbbbbbd
        #|1Dec  2Skywalker2275M2375M 3
        #|4May  5Solo     5275M5393M 6
        #|ijjjjjkjjjjjjjjjkjjjjkjjjjjl
        #|7Dec  8Last Jedi8262M81333M9
        #|qrrrrrsrrrrrrrrrsrrrrsrrrrrt
        #|
      ),
    ),
    (
      true,
      false,
      (
        #|abbbbbcbbbbbbbbbcbbbbcbbbbbd
        #|1Month2Nickname 2Cost2Gross3
        #|efffffgfffffffffgffffgfffffh
        #|4Dec  5Skywalker5275M5375M 6
        #|4May  5Solo     5275M5393M 6
        #|ijjjjjkjjjjjjjjjkjjjjkjjjjjl
        #|7Dec  8Last Jedi8262M81333M9
        #|qrrrrrsrrrrrrrrrsrrrrsrrrrrt
        #|
      ),
    ),
    (
      false,
      true,
      (
        #|abbbbbcbbbbbbbbbcbbbbcbbbbbd
        #|1Dec  2Skywalker2275M2375M 3
        #|4May  5Solo     5275M5393M 6
        #|ijjjjjkjjjjjjjjjkjjjjkjjjjjl
        #|4Dec  5Last Jedi5262M51333M6
        #|mnnnnnonnnnnnnnnonnnnonnnnnp
        #|7MONTH8NICKNAME 8COST8GROSS9
        #|qrrrrrsrrrrrrrrrsrrrrsrrrrrt
        #|
      ),
    ),
    (
      true,
      true,
      (
        #|abbbbbcbbbbbbbbbcbbbbcbbbbbd
        #|1Month2Nickname 2Cost2Gross3
        #|efffffgfffffffffgffffgfffffh
        #|4Dec  5Skywalker5275M5375M 6
        #|4May  5Solo     5275M5393M 6
        #|ijjjjjkjjjjjjjjjkjjjjkjjjjjl
        #|4Dec  5Last Jedi5262M51333M6
        #|mnnnnnonnnnnnnnnonnnnonnnnnp
        #|7MONTH8NICKNAME 8COST8GROSS9
        #|qrrrrrsrrrrrrrrrsrrrrsrrrrrt
        #|
      ),
    ),
  ]
  // upstream patches the attributes of box.ASCII in place
  let box_ = @rich.Box::new(
    "abcd\n1 23\nefgh\n4 56\nijkl\nmnop\n7 89\nqrst\n",
    ascii=true,
  )
  for case in cases {
    let (show_header, show_footer, expected) = case
    let table = @rich.Table::new(box_~, show_header~, show_footer~, padding=[0])
    table.add_column(header="Month", footer="MONTH", width=5)
    table.add_column(header="Nickname", footer="NICKNAME", width=9)
    table.add_column(header="Cost", footer="COST", width=4)
    table.add_column(header="Gross", footer="GROSS", width=5)
    table.add_row(["Dec", "Skywalker", "275M", "375M"])
    table.add_row(["May", "Solo", "275M", "393M"])
    table.add_section()
    table.add_row(["Dec", "Last Jedi", "262M", "1333M"])
    let console = @rich.Console::new(
      record=true,
      width=28,
      file=@rich.NullFile::new(),
      environ={},
    )
    console.print(table)
    let output = console.export_text()
    assert_eq(output, expected)
  }
}

///|
test "test_columns_highlight_added_by_add_row" {
  let table = @rich.Table::new(show_header=false, highlight=true)
  table.add_row(["1", "'FOO'"])
  assert_eq(table.columns[0].highlight, table.highlight)
  assert_eq(table.columns[1].highlight, table.highlight)
  let console = @rich.Console::new(
    record=true,
    width=80,
    file=@rich.NullFile::new(),
    environ={},
  )
  console.print(table)
  let output = console.export_text(styles=true)
  let expected = "┌───┬───────┐\n│ \u{1b}[1;36m1\u{1b}[0m │ \u{1b}[32m'FOO'\u{1b}[0m │\n└───┴───────┘\n"
  assert_eq(output, expected)
}

///|
test "test_padding_width" {
  let table = @rich.Table::grid(padding=[0, 1])
  for _ in 0..<3 {
    table.add_column(width=3)
  }
  table.add_row(["aaa", "aaa", "aaa"])
  let console = @rich.Console::new(
    record=true,
    width=80,
    file=@rich.NullFile::new(),
    environ={},
  )
  console.print(table)
  let output = console.export_text(styles=true)
  assert_eq(output, "aaa aaa aaa\n")
}

///|
test "string headers inherit table highlight" {
  // Table("n", highlight=True); add_row("123") (computed with upstream Rich)
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    file~,
    width=40,
    color_system=Some("truecolor"),
    force_terminal=true,
    legacy_windows=false,
    environ={},
  )
  let table = @rich.Table::new(headers=["n"], highlight=true)
  table.add_row(["123"])
  console.print(table)
  assert_eq(
    file.getvalue(),
    "┏━━━━━┓\n┃\u{1b}[1m \u{1b}[0m\u{1b}[1mn  \u{1b}[0m\u{1b}[1m \u{1b}[0m┃\n┡━━━━━┩\n│ \u{1b}[1;36m123\u{1b}[0m │\n└─────┘\n",
  )
}
