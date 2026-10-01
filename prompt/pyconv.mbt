// Python conversions used by the prompts: `str.strip()`, `int(str)` and
// `float(str)`.

///|
/// Python `str.isspace` for a single character.
fn is_py_space(c : Char) -> Bool {
  match c.to_int() {
    0x09..=0x0D | 0x1C..=0x20 | 0x85 | 0xA0 | 0x1680 => true
    0x2000..=0x200A | 0x2028 | 0x2029 | 0x202F | 0x205F | 0x3000 => true
    _ => false
  }
}

///|
/// Python `str.strip()` (strip whitespace from both ends).
fn py_strip(s : String) -> String {
  let chars = s.to_array()
  let mut start = 0
  let mut end = chars.length()
  while start < end && is_py_space(chars[start]) {
    start += 1
  }
  while end > start && is_py_space(chars[end - 1]) {
    end -= 1
  }
  if start == 0 && end == chars.length() {
    s
  } else {
    String::from_array(chars[start:end])
  }
}

///|
/// Python `int(s)` for base 10 (`None` where Python raises `ValueError`).
/// Surrounding whitespace, a sign and single underscores between digits are
/// accepted. Values that do not fit in an `Int` are rejected.
fn py_int(s : String) -> Int? {
  let s = py_strip(s)
  let chars = s.to_array()
  let n = chars.length()
  let mut i = 0
  if i < n && (chars[i] == '+' || chars[i] == '-') {
    i += 1
  }
  if i >= n || !(chars[i] is ('0'..='9')) {
    return None
  }
  let mut prev_underscore = false
  for j in i..<n {
    match chars[j] {
      '0'..='9' => prev_underscore = false
      '_' if !prev_underscore => prev_underscore = true
      _ => return None
    }
  }
  if prev_underscore {
    return None
  }
  Some(@string.parse_int(s)) catch {
    _ => None
  }
}

///|
/// Python `float(s)` (`None` where Python raises `ValueError`).
fn py_float(s : String) -> Double? {
  let s = py_strip(s)
  Some(@string.parse_double(s)) catch {
    _ => None
  }
}
