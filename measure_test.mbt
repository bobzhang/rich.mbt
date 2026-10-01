// Port of tests/test_measure.py.

///|
test "test_span" {
  let measurement = @rich.Measurement::new(10, 100)
  assert_eq(measurement.span(), 90)
}

///|
test "test_measure_renderables" {
  let console = @rich.Console::new()
  assert_eq(
    @rich.measure_renderables(console, console.options(), []),
    @rich.Measurement::new(0, 0),
  )
  // upstream passes the string "hello", measured as a sequence of characters
  assert_eq(
    @rich.measure_renderables(console, console.options().update_width(0), [
      "h", "e", "l", "l", "o",
    ]),
    @rich.Measurement::new(0, 0),
  )
}

///|
test "test_clamp" {
  let measurement = @rich.Measurement::new(20, 100)
  assert_eq(
    measurement.clamp(min_width=10, max_width=50),
    @rich.Measurement::new(20, 50),
  )
  assert_eq(
    measurement.clamp(min_width=30, max_width=50),
    @rich.Measurement::new(30, 50),
  )
  assert_eq(measurement.clamp(max_width=50), @rich.Measurement::new(20, 50))
  assert_eq(measurement.clamp(min_width=30), @rich.Measurement::new(30, 100))
  assert_eq(measurement.clamp(), @rich.Measurement::new(20, 100))
}
