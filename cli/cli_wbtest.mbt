///|
test "py_is_complex matches Python's complex()" {
  // computed with CPython 3.14
  let cases = [
    ("1", true),
    ("-2.5", true),
    (" 3 ", true),
    ("1e5", true),
    ("1_000", true),
    ("1__0", false),
    ("_1", false),
    ("1_", false),
    (".5", true),
    ("5.", true),
    (".", false),
    ("j", true),
    ("+j", true),
    ("-J", true),
    ("2j", true),
    ("1+2j", true),
    ("1-j", true),
    ("(1+2j)", true),
    (" ( 3 ) ", true),
    ("inf", true),
    ("-Infinity", true),
    ("nanj", true),
    ("1+infj", true),
    ("abc", false),
    ("", false),
    ("1 + 2j", false),
    ("1e", false),
    ("1e+", false),
    ("0x10", false),
    ("(1", false),
    ("1)", false),
    ("1.5e-3J", true),
  ]
  for case in cases {
    assert_eq(py_is_complex(case.0), case.1, msg=case.0)
  }
}

///|
test "get_close_matches matches difflib" {
  debug_inspect(
    get_close_matches("--colour", [
      "--color", "--colors", "--column", "--clue", "--col",
    ]),
    content=(
      #|["--color", "--colors", "--col"]
    ),
  )
  debug_inspect(
    get_close_matches("--tex-left", [
      "--text-left", "--text-right", "--text-center", "--text-full", "--left",
    ]),
    content=(
      #|["--text-left", "--left"]
    ),
  )
}

///|
test "is_number" {
  let numbers = ["1", "-1", "1.5", "-.5", "10.", "-", "."]
  let others = ["1e5", "1,000", "abc", "1.2.3", " 1"]
  assert_true(numbers.all(is_number))
  assert_true(!others.any(is_number))
}

///|
test "csv reader" {
  let rows = csv_read("a,\"b,c\",\"d \"\"e\"\"\"\n\n1,2\n\"open\nquote", excel)
  debug_inspect(
    rows,
    content=(
      #|[["a", "b,c", "d \"e\""], [], ["1", "2"], ["open\nquote"]]
    ),
  )
  let dialect = sniff("x;y;z\n1;2;3\n4;5;6\n")
  inspect(dialect.delimiter, content=";")
  inspect(has_header("name,age\nann,31\nbob,42\n"), content="true")
  inspect(has_header("1,2\n3,4\n5,6\n"), content="false")
}

///|
test "count_lines like str.splitlines" {
  inspect(count_lines(""), content="0")
  inspect(count_lines("a"), content="1")
  inspect(count_lines("a\n"), content="1")
  inspect(count_lines("a\n\nb"), content="3")
  inspect(count_lines("a\r\nb\rc\u{2028}d"), content="4")
}

///|
test "splitext" {
  inspect(splitext_ext("dir/file.tar.gz"), content=".gz")
  inspect(splitext_ext(".bashrc"), content="")
  inspect(splitext_ext("a.b/README"), content="")
  inspect(url_path("https://example.com/x/y.md?raw=1#top"), content="/x/y.md")
}
