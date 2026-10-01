// Port of tests/test_cells.py. Span offsets are UTF-16 offsets.

///|
test "get_character_cell_size" {
  assert_eq(@cells.get_character_cell_size('\u{0}'), 0)
  assert_eq(@cells.get_character_cell_size('\u{200d}'), 0)
  assert_eq(@cells.get_character_cell_size('a'), 1)
  assert_eq(@cells.get_character_cell_size('💩'), 2)
  assert_eq(@cells.codepoint_cell_size(917999 + 1), 0)
}

///|
test "cell_len long and short strings" {
  assert_eq(@cells.cell_len("abc".repeat(200)), 600)
  assert_eq(@cells.cell_len("a".repeat(512)), 512)
  assert_eq(@cells.cell_len("abc".repeat(100)), 300)
  assert_eq(@cells.cell_len("a".repeat(511)), 511)
}

///|
test "set_cell_size" {
  assert_eq(@cells.set_cell_size("foo", 0), "")
  assert_eq(@cells.set_cell_size("f", 0), "")
  assert_eq(@cells.set_cell_size("", 0), "")
  assert_eq(@cells.set_cell_size("😽😽", 0), "")
  assert_eq(@cells.set_cell_size("foo", 2), "fo")
  assert_eq(@cells.set_cell_size("foo", 3), "foo")
  assert_eq(@cells.set_cell_size("foo", 4), "foo ")
  assert_eq(@cells.set_cell_size("😽😽", 4), "😽😽")
  assert_eq(@cells.set_cell_size("😽😽", 3), "😽 ")
  assert_eq(@cells.set_cell_size("😽😽", 2), "😽")
  assert_eq(@cells.set_cell_size("😽😽", 1), " ")
  assert_eq(@cells.set_cell_size("😽😽", 5), "😽😽 ")
}

///|
test "set_cell_size infinite" {
  for size in 0..<38 {
    assert_eq(
      @cells.cell_len(
        @cells.set_cell_size(
          "เป็นเกมที่ต้องมีความอดทนมากที่สุดตั้งเเต่เคยเล่นมา",
          size,
        ),
      ),
      size,
    )
  }
}

///|
test "split_text" {
  let fm = "👩\u{200d}🔧"
  let cases : Array[(String, Int, String, String)] = [
    ("", -1, "", ""),
    ("x", -1, "", "x"),
    ("x", 1, "x", ""),
    ("x", 2, "x", ""),
    ("", 0, "", ""),
    ("", 1, "", ""),
    ("a", 0, "", "a"),
    ("a", 1, "a", ""),
    ("💩", 0, "", "💩"),
    ("💩", 1, " ", " "),
    ("💩", 2, "💩", ""),
    ("💩x", 1, " ", " x"),
    ("💩x", 2, "💩", "x"),
    ("💩x", 3, "💩x", ""),
    (fm, 0, "", fm),
    (fm, 1, " ", " "),
    (fm, 2, fm, ""),
    (fm + "x", 1, " ", " x"),
    (fm + "x", 2, fm, "x"),
    (fm + "x", 3, fm + "x", ""),
    ("xxxxxxxxxxxxxxx💩💩", 10, "xxxxxxxxxx", "xxxxx💩💩"),
    ("xxxxxxxxxxxxxxx💩💩", 15, "xxxxxxxxxxxxxxx", "💩💩"),
    ("xxxxxxxxxxxxxxx💩💩", 16, "xxxxxxxxxxxxxxx ", " 💩"),
    ("💩💩", 3, "💩 ", " "),
    ("💩💩xxxxxxxxxx", 2, "💩", "💩xxxxxxxxxx"),
    ("💩💩xxxxxxxxxx", 3, "💩 ", " xxxxxxxxxx"),
    ("💩💩xxxxxxxxxx", 4, "💩💩", "xxxxxxxxxx"),
  ]
  for case in cases {
    let (text, offset, left, right) = case
    assert_eq(@cells.split_text(text, offset), (left, right))
  }
}

///|
test "chop_cells" {
  assert_eq(@cells.chop_cells("abcdefghijk", 3), ["abc", "def", "ghi", "jk"])
  assert_eq(@cells.chop_cells("ありがとう", 3), [
    "あ", "り", "が", "と", "う",
  ])
  assert_eq(@cells.chop_cells("あ1り234が5と6う78", 3), [
    "あ1", "り2", "34", "が5", "と6", "う7", "8",
  ])
  for text in ["", "\u{1b}", "\u{1b}\u{1b}", "\u{1b}\u{1b}\u{1b}"] {
    assert_eq(@cells.chop_cells(text, 3), [])
  }
}

///|
test "is_single_cell_widths" {
  for
    c in "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~ " {
    assert_true(@cells.is_single_cell_widths(c.to_string()))
  }
  for
    c in "┌─┬┐│ ││├─┼┤│ ││├─┼┤├─┼┤│ ││└─┴┘" {
    assert_true(@cells.is_single_cell_widths(c.to_string()))
  }
  for c in "💩😽わさび" {
    assert_true(!@cells.is_single_cell_widths(c.to_string()))
  }
}

///|
test "split_graphemes" {
  // (text, spans in UTF-16 offsets, cell length)
  let cases : Array[(String, Array[(Int, Int, Int)], Int)] = [
    ("", [], 0),
    ("a", [(0, 1, 1)], 1),
    ("ab", [(0, 1, 1), (1, 2, 1)], 2),
    ("💩", [(0, 2, 2)], 2),
    ("わさび", [(0, 1, 2), (1, 2, 2), (2, 3, 2)], 6),
    ("👩\u{200d}🔧", [(0, 5, 2)], 2),
    ("a👩\u{200d}🔧", [(0, 1, 1), (1, 6, 2)], 3),
    ("a👩\u{200d}🔧b", [(0, 1, 1), (1, 6, 2), (6, 7, 1)], 4),
    ("⬇", [(0, 1, 1)], 1),
    ("⬇\u{fe0f}", [(0, 2, 2)], 2),
    ("♻", [(0, 1, 1)], 1),
    ("♻\u{fe0f}", [(0, 2, 2)], 2),
    ("♻♻\u{fe0f}", [(0, 1, 1), (1, 3, 2)], 3),
    ("\u{1b}", [(0, 1, 0)], 0),
    ("\u{1b}\u{1b}", [(0, 2, 0)], 0),
    ("\u{fe0f}", [(0, 1, 0)], 0),
    ("\u{fe0f}\u{fe0f}", [(0, 2, 0)], 0),
    ("\u{200d}", [(0, 1, 0)], 0),
    ("\u{200d}\u{200d}", [(0, 2, 0)], 0),
    ("\u{1b}\u{fe0f}", [(0, 2, 0)], 0),
    ("\u{200d}\u{fe0f}", [(0, 2, 0)], 0),
  ]
  for case in cases {
    let (text, spans, length) = case
    assert_eq(@cells.cell_len(text), length)
    assert_eq(@cells.split_graphemes(text), (spans, length))
  }
}

///|
test "nerd font, zwj, non printable" {
  assert_eq(@cells.cell_len("\u{f024d}"), 1)
  assert_eq(@cells.cell_len(""), 0)
  assert_eq(@cells.cell_len("\u{200d}"), 0)
  assert_eq(@cells.cell_len("1\u{200d}"), 1)
  assert_eq(@cells.cell_len("1\u{200d}2"), 1)
  for i in 0..<31 {
    assert_eq(@cells.cell_len(Int::unsafe_to_char(i).to_string()), 0)
  }
}

///|
test "unicode versions" {
  assert_eq(@cells.load(unicode_version="latest").unicode_version, "17.0.0")
  assert_eq(@cells.load(unicode_version="4").unicode_version, "4.1.0")
  assert_eq(@cells.load(unicode_version="12.5").unicode_version, "12.1.0")
  assert_eq(@cells.load(unicode_version="1.0").unicode_version, "4.1.0")
  assert_eq(@cells.load(unicode_version="foo").unicode_version, "17.0.0")
}
