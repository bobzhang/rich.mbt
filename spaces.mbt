///|
/// Strings of 0 to 255 spaces, shared (strings are immutable): padding is
/// built for almost every rendered line.
let space_strings : FixedArray[String] = FixedArray::makei(256, n => {
  String::make(n, ' ')
})

///|
/// `" ".repeat(n)`.
fn space_string(n : Int) -> String {
  if n >= 0 && n < space_strings.length() {
    space_strings[n]
  } else {
    " ".repeat(n)
  }
}
