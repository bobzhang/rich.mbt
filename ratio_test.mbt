// Port of tests/test_ratio.py.

///|
test "test_ratio_reduce" {
  let cases : Array[(Int, Array[Int], Array[Int], Array[Int], Array[Int])] = [
    (20, [2, 4], [20, 20], [5, 5], [-2, -8]),
    (20, [2, 4], [1, 1], [5, 5], [4, 4]),
    (20, [2, 4], [1, 1], [2, 2], [1, 1]),
    (3, [2, 4], [3, 3], [2, 2], [1, 0]),
    (3, [2, 4], [3, 3], [0, 0], [-1, -2]),
    (3, [0, 0], [3, 3], [4, 4], [4, 4]),
  ]
  for case in cases {
    let (total, ratios, maximums, values, result) = case
    assert_eq(@rich.ratio_reduce(total, ratios, maximums, values), result)
  }
}

///|
fn edge(size? : Int, ratio? : Int = 1, minimum_size? : Int = 1) -> @rich.Edge {
  { size, ratio, minimum_size, }
}

///|
test "test_ratio_resolve" {
  assert_eq(@rich.ratio_resolve(100, []), [])
  assert_eq(@rich.ratio_resolve(100, [edge(size=100), edge(ratio=1)]), [100, 1])
  assert_eq(@rich.ratio_resolve(100, [edge(ratio=1)]), [100])
  assert_eq(@rich.ratio_resolve(100, [edge(ratio=1), edge(ratio=1)]), [50, 50])
  assert_eq(
    @rich.ratio_resolve(100, [edge(size=20), edge(ratio=1), edge(ratio=1)]),
    [20, 40, 40],
  )
  assert_eq(
    @rich.ratio_resolve(100, [edge(size=40), edge(ratio=2), edge(ratio=1)]),
    [40, 40, 20],
  )
  assert_eq(
    @rich.ratio_resolve(100, [
      edge(size=40),
      edge(ratio=2),
      edge(ratio=1, minimum_size=25),
    ]),
    [40, 35, 25],
  )
  assert_eq(
    @rich.ratio_resolve(100, [edge(ratio=1), edge(ratio=1), edge(ratio=1)]),
    [33, 33, 34],
  )
  assert_eq(
    @rich.ratio_resolve(50, [
      edge(size=30),
      edge(ratio=1, minimum_size=10),
      edge(size=30),
    ]),
    [30, 10, 30],
  )
  assert_eq(
    @rich.ratio_resolve(110, [edge(ratio=1), edge(ratio=1), edge(ratio=1)]),
    [36, 37, 37],
  )
}
