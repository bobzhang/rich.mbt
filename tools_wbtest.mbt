// Port of tests/test_tools.py (private `_loop` helpers).

///|
test "test_loop_first" {
  let empty : Array[String] = []
  assert_eq(loop_first(empty), [])
  assert_eq(loop_first(["apples", "oranges", "pears", "lemons"]), [
    (true, "apples"),
    (false, "oranges"),
    (false, "pears"),
    (false, "lemons"),
  ])
}

///|
test "test_loop_last" {
  let empty : Array[String] = []
  assert_eq(loop_last(empty), [])
  assert_eq(loop_last(["apples", "oranges", "pears", "lemons"]), [
    (false, "apples"),
    (false, "oranges"),
    (false, "pears"),
    (true, "lemons"),
  ])
}

///|
test "test_loop_first_last" {
  let empty : Array[String] = []
  assert_eq(loop_first_last(empty), [])
  assert_eq(loop_first_last(["apples", "oranges", "pears", "lemons"]), [
    (true, false, "apples"),
    (false, false, "oranges"),
    (false, false, "pears"),
    (false, true, "lemons"),
  ])
}
