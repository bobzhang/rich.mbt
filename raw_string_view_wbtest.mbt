///|
test "text offsets preserve raw surrogate halves" {
  let text = "😀z"
  let first = Text::new(text~).at(0).plain()
  let second = Text::new(text~).at(1).plain()
  assert_eq(first.length(), 1)
  assert_eq(second.length(), 1)
  assert_eq(first.unsafe_get(0), text.unsafe_get(0))
  assert_eq(second.unsafe_get(0), text.unsafe_get(1))
  assert_eq(py_slice(text, 1, 2), second)
}
