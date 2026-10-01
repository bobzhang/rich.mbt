// `py_format` (Python `str.format`), checked against CPython.

///|
test "py_format specs" {
  // '{code:>5}|{x:<4}|{y:^7}|{z:*>6}|{w:.2}|{q!r}'.format(
  //     code='ab', x='c', y='mid', z='r', w='abcdef', q='s')
  assert_eq(
    @rich.py_format("{code:>5}|{x:<4}|{y:^7}|{z:*>6}|{w:.2}|{q!r}", {
      "code": "ab",
      "x": "c",
      "y": "mid",
      "z": "r",
      "w": "abcdef",
      "q": "s",
    }),
    "   ab|c   |  mid  |*****r|ab|'s'",
  )
  assert_eq(@rich.py_format("{{a}} {a} {b}", { "a": "1" }), "{a} 1 {b}")
}

///|
test "export_html code_format with format spec" {
  let console = @rich.Console::new(
    record=true,
    width=100,
    file=@rich.NullFile::new(),
    environ={},
  )
  console.print("foo")
  assert_eq(
    console.export_html(code_format="[{code:>6}]{foreground}"),
    "[  foo\n]#000000",
  )
}
