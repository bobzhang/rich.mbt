// Python string helpers used by Syntax: textwrap.dedent, str.expandtabs,
// os.path.splitext, str.isspace.

///|
/// Python `str.isspace` for one character.
fn is_py_space(c : Char) -> Bool {
  match c {
    ' ' | '\t' | '\n' | '\r' | '\u{0b}' | '\u{0c}' => true
    '\u{1c}'..='\u{1f}' | '\u{85}' | '\u{a0}' | '\u{1680}' => true
    '\u{2000}'..='\u{200a}' | '\u{2028}' | '\u{2029}' | '\u{202f}' => true
    '\u{205f}' | '\u{3000}' => true
    _ => false
  }
}

///|
/// Python `str.isspace` (false for the empty string).
fn py_isspace(s : StringView) -> Bool {
  if s.length() == 0 {
    return false
  }
  for c in s {
    if !is_py_space(c) {
      return false
    }
  }
  true
}

///|
/// Python string ordering (lexicographic by code point).
fn py_str_lt(a : String, b : String) -> Bool {
  let ia = a.iter()
  let ib = b.iter()
  for ;; {
    match (ia.next(), ib.next()) {
      (None, None) => return false
      (None, Some(_)) => return true
      (Some(_), None) => return false
      (Some(x), Some(y)) => if x != y { return x < y }
    }
  }
}

///|
/// Python 3.14 `textwrap.dedent`: remove any common leading whitespace
/// (spaces and tabs) from every line; whitespace-only lines become empty.
pub fn dedent(text : String) -> String {
  if text == "" {
    return text
  }
  if py_isspace(text) {
    let n = text.iter().filter(c => c == '\n').count()
    return "\n".repeat(n)
  }
  let lines = text.split("\n").map(l => l.to_owned()).collect()
  let non_blank = lines.filter(l => l != "" && !py_isspace(l))
  let mut l1 = ""
  let mut l2 = ""
  for i, l in non_blank {
    if i == 0 || py_str_lt(l, l1) {
      l1 = l
    }
    if i == 0 || py_str_lt(l2, l) {
      l2 = l
    }
  }
  // Python iterates code points, but leading whitespace is ASCII, so UTF-16
  // indices agree up to the first non-space character.
  let mut margin = 0
  for i in 0..<l1.length() {
    margin = i
    let c = l1[i]
    if c != l2[i] || !(c == ' ' || c == '\t') {
      break
    }
  }
  lines
  .map(l => {
    if py_isspace(l) {
      ""
    } else {
      l.unsafe_substring(start=@cmp.minimum(margin, l.length()), end=l.length())
    }
  })
  .join("\n")
}

///|
/// Python `str.expandtabs(tabsize)`.
pub fn expandtabs(s : String, tab_size : Int) -> String {
  if !s.contains("\t") {
    return s
  }
  let buf = StringBuilder()
  let mut col = 0
  for c in s {
    match c {
      '\t' =>
        if tab_size > 0 {
          let n = tab_size - col % tab_size
          for _ in 0..<n {
            buf.write_char(' ')
          }
          col += n
        }
      '\n' | '\r' => {
        buf.write_char(c)
        col = 0
      }
      _ => {
        buf.write_char(c)
        col += 1
      }
    }
  }
  buf.to_string()
}

///|
/// Python `os.path.splitext` (POSIX): `(root, ext)`.
pub fn splitext(path : String) -> (String, String) {
  let sep = match path.rev_find("/") {
    Some(i) => i + 1
    None => 0
  }
  match path.rev_find(".") {
    Some(dot) if dot >= sep => {
      // skip leading dots of the file name
      let mut i = sep
      while i < dot && path[i] == '.' {
        i += 1
      }
      if i < dot {
        (
          path.unsafe_substring(start=0, end=dot),
          path.unsafe_substring(start=dot, end=path.length()),
        )
      } else {
        (path, "")
      }
    }
    _ => (path, "")
  }
}
