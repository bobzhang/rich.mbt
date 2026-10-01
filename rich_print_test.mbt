// Port of tests/test_rich_print.py and tests/test_json.py.
//
// The global console is shared, so each test installs a console with a
// fixed environment first (upstream relies on pytest capturing stdout).

///|
fn reset_global_console(width? : Int = 80) -> Unit raise {
  @rich.reconfigure(@rich.Console::new(width~, environ={}))
}

///|
test "test_get_console" {
  let console = @rich.get_console()
  assert_true(console.width() > 0)
}

///|
test "test_reconfigure_console" {
  // upstream: rich.reconfigure(width=100)
  @rich.reconfigure(@rich.Console::new(width=100))
  assert_eq(@rich.get_console().width(), 100)
}

///|
test "test_rich_print" {
  reset_global_console()
  let console = @rich.get_console()
  let output = @rich.StringIO::new()
  let backup_file = console.file()
  console.set_file(output)
  @rich.print_many(["foo", "bar"])
  @rich.print("foo\n")
  @rich.print("foo\n\n")
  console.set_file(backup_file)
  assert_eq(output.getvalue(), "foo bar\nfoo\n\nfoo\n\n\n")
}

///|
test "test_rich_print_json" {
  reset_global_console()
  let console = @rich.get_console()
  let result = console.capture(() => {
    @rich.print_json(json="[false, true, null, \"foo\"]", indent=Some(4))
  })
  let expected = "[\n    false,\n    true,\n    null,\n    \"foo\"\n]\n"
  assert_eq(result, expected)
}

///|
test "test_rich_print_json_round_trip" {
  reset_global_console()
  let data : Json = ["x".repeat(100), 2.0e128]
  let console = @rich.get_console()
  let result = console.capture(() => @rich.print_json(data~, indent=Some(4)))
  // json.loads(result) == data
  let result_data = @rich.JsonValue::parse(result)
  assert_eq(result_data, JArray([JString("x".repeat(100)), JFloat(2.0e128)]))
  assert_eq(result, "[\n    \"\{"x".repeat(100)}\",\n    2e+128\n]\n")
}

///|
test "test_rich_print_json_no_truncation" {
  reset_global_console()
  let console = @rich.get_console()
  let big = "200000000000000015034897383303641725494285812870481642696581820471553185048483040932908220219551607085653191007770505265335500800" // str(int(2e128))
  let result = console.capture(() => {
    @rich.print_json(json="[\"\{"x".repeat(100)}\", \{big}]", indent=Some(4))
  })
  assert_true(result.contains("x".repeat(100)))
  assert_true(result.contains(big))
}

///|
test "test_rich_print_X" {
  reset_global_console()
  let console = @rich.get_console()
  let output = @rich.StringIO::new()
  let backup_file = console.file()
  console.set_file(output)
  @rich.print("foo")
  @rich.print("fooX")
  @rich.print("fooXX")
  console.set_file(backup_file)
  assert_eq(output.getvalue(), "foo\nfooX\nfooXX\n")
}

///|
test "test_print_json_data_with_default" {
  // upstream: JSON.from_data({"date": date}, default=lambda d: d.isoformat());
  // MoonBit `Json` has no arbitrary objects, so the converted value is used.
  let json = @rich.JSON::from_data({ "date": "2021-01-01" })
  assert_eq(json.text.plain(), "{\n  \"date\": \"2021-01-01\"\n}")
}

///|
test "json string indent and console input stream" {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(file~, width=40, color_system=None)
  console.print_json(json="{\"a\":[1,{\"b\":2}]}", indent_str="\t")
  assert_eq(
    file.getvalue(),
    "{\n        \"a\": [\n                1,\n                {\n                        \"b\": 2\n                }\n        ]\n}\n",
  )
  file.reset()
  let answer = console.input(prompt="Name? ", stream=() => "Ada\n")
  assert_eq(answer, "Ada\n")
  assert_eq(file.getvalue(), "Name? ")
}
