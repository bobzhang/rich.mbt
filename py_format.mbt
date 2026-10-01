// Python `str.format` for the export templates (`code_format`).

///|
fn is_format_align(c : Char) -> Bool {
  c == '<' || c == '>' || c == '^' || c == '='
}

///|
/// Apply a Python format spec (`[[fill]align][0][width][.precision][s]`) to
/// a string value.
fn py_format_spec(value : String, spec : String) -> String {
  let chars : Array[Char] = spec.iter().collect()
  let n = chars.length()
  let mut i = 0
  let mut fill = ' '
  let mut align : Char? = None
  if n >= 2 && is_format_align(chars[1]) {
    fill = chars[0]
    align = Some(chars[1])
    i = 2
  } else if n >= 1 && is_format_align(chars[0]) {
    align = Some(chars[0])
    i = 1
  }
  // sign and alternate form are not meaningful for strings
  while i < n &&
        (
          chars[i] == '+' ||
          chars[i] == '-' ||
          chars[i] == ' ' ||
          chars[i] == '#'
        ) {
    i += 1
  }
  if i < n && chars[i] == '0' && align is None {
    fill = '0'
    i += 1
  }
  let mut width = 0
  while i < n && chars[i] >= '0' && chars[i] <= '9' {
    width = width * 10 + (chars[i].to_int() - '0'.to_int())
    i += 1
  }
  let mut precision : Int? = None
  if i < n && chars[i] == '.' {
    i += 1
    let mut p = 0
    while i < n && chars[i] >= '0' && chars[i] <= '9' {
      p = p * 10 + (chars[i].to_int() - '0'.to_int())
      i += 1
    }
    precision = Some(p)
  }
  let value_chars : Array[Char] = value.iter().collect()
  let value_chars = match precision {
    Some(p) if p < value_chars.length() => value_chars[0:p].to_owned()
    _ => value_chars
  }
  let text = String::from_array(value_chars)
  let padding = width - value_chars.length()
  if padding <= 0 {
    return text
  }
  let fill_str = fill.to_string()
  match align {
    Some('>') => fill_str.repeat(padding) + text
    Some('^') => {
      let left = padding / 2
      fill_str.repeat(left) + text + fill_str.repeat(padding - left)
    }
    _ => text + fill_str.repeat(padding)
  }
}

///|
/// Python `str.format` with named fields: `{name}`, `{name!r}`,
/// `{name:spec}` (string format specs: fill, alignment, width, precision),
/// and `{{` / `}}` escapes. Unknown fields are left as they are.
pub fn py_format(template : String, fields : Map[String, String]) -> String {
  let buf = StringBuilder()
  let n = template.length()
  let mut i = 0
  while i < n {
    let c = template[i]
    if c == '{' {
      if i + 1 < n && template[i + 1] == '{' {
        buf.write_char('{')
        i += 2
        continue
      }
      match template.view(start_offset=i).find("}") {
        Some(j) => {
          let field = py_slice(template, i + 1, i + j)
          let (name_conv, spec) = match field.find(":") {
            Some(k) =>
              (
                py_slice(field, 0, k),
                Some(py_slice(field, k + 1, field.length())),
              )
            None => (field, None)
          }
          let (name, conversion) = match name_conv.find("!") {
            Some(k) =>
              (
                py_slice(name_conv, 0, k),
                Some(py_slice(name_conv, k + 1, name_conv.length())),
              )
            None => (name_conv, None)
          }
          match fields.get(name) {
            Some(v) => {
              let v = match conversion {
                Some("r") | Some("a") => py_repr(v)
                _ => v
              }
              let v = match spec {
                Some(spec) => py_format_spec(v, spec)
                None => v
              }
              buf.write_string(v)
            }
            None => buf.write_string(py_slice(template, i, i + j + 1))
          }
          i += j + 1
        }
        None => {
          buf.write_char('{')
          i += 1
        }
      }
    } else if c == '}' && i + 1 < n && template[i + 1] == '}' {
      buf.write_char('}')
      i += 2
    } else {
      buf.write_char(c.to_int().unsafe_to_char())
      i += 1
    }
  }
  buf.to_string()
}
