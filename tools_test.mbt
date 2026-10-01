// Port of tests/test_tools.py (`ratio_distribute`) and tests/test_pick.py.

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
