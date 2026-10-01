// Port of tests/test_tools.py and tests/test_pick.py.

///|
test "test_ratio_distribute" {
  assert_eq(@rich.ratio_distribute(10, [1]), [10])
  assert_eq(@rich.ratio_distribute(10, [1, 1]), [5, 5])
  assert_eq(@rich.ratio_distribute(12, [1, 3]), [3, 9])
  assert_eq(@rich.ratio_distribute(0, [1, 3]), [0, 0])
  assert_eq(@rich.ratio_distribute(0, [1, 3], minimums=[1, 1]), [1, 1])
  assert_eq(@rich.ratio_distribute(10, [1, 0]), [10, 0])
}

///|
test "test_pick_bool" {
  assert_eq(@rich.pick_bool([Some(false)]), false)
  assert_eq(@rich.pick_bool([Some(true)]), true)
  assert_eq(@rich.pick_bool([None]), false)
  assert_eq(@rich.pick_bool([Some(false), Some(true)]), false)
  assert_eq(@rich.pick_bool([None, Some(true)]), true)
  assert_eq(@rich.pick_bool([Some(true), None]), true)
  assert_eq(@rich.pick_bool([Some(false), None]), false)
  assert_eq(@rich.pick_bool([None, None]), false)
  assert_eq(@rich.pick_bool([None, None, Some(false), Some(true)]), false)
  assert_eq(@rich.pick_bool([None, None, Some(true), Some(false)]), true)
}

///|
test "test_loop_first" {
  let empty : Array[String] = []
  assert_eq(@rich.loop_first(empty), [])
  assert_eq(@rich.loop_first(["apples", "oranges", "pears", "lemons"]), [
    (true, "apples"),
    (false, "oranges"),
    (false, "pears"),
    (false, "lemons"),
  ])
}

///|
test "test_loop_last" {
  let empty : Array[String] = []
  assert_eq(@rich.loop_last(empty), [])
  assert_eq(@rich.loop_last(["apples", "oranges", "pears", "lemons"]), [
    (false, "apples"),
    (false, "oranges"),
    (false, "pears"),
    (true, "lemons"),
  ])
}

///|
test "test_loop_first_last" {
  let empty : Array[String] = []
  assert_eq(@rich.loop_first_last(empty), [])
  assert_eq(@rich.loop_first_last(["apples", "oranges", "pears", "lemons"]), [
    (true, false, "apples"),
    (false, false, "oranges"),
    (false, false, "pears"),
    (false, true, "lemons"),
  ])
}
