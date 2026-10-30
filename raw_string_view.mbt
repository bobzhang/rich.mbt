///|
// Text offsets and span boundaries are raw UTF-16 positions, including the
// middle of a surrogate pair. Preserve the former checked String.view behavior.
fn raw_string_view(text : String, start : Int32, end : Int32) -> StringView {
  guard start >= 0 && start <= end && end <= text.length() else {
    abort("Invalid index for View")
  }
  text.unsafe_view(start~, end~)
}
