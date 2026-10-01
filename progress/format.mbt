// A subset of Python's `str.format(task=task)` used by `TextColumn` and
// friends: replacement fields `{task.<attribute>}` and
// `{task.fields[<name>]}` with optional `!s`/`!r` conversion and a format
// spec (`[[fill]align][sign][0][width][,|_][.precision][type]`, types
// `s d f F % e E g G x X o b` and none).

///|
/// A Python value produced by a replacement field.
priv enum PyValue {
  PyStr(String)
  PyInt(Int64)
  PyFloat(Double)
  PyBool(Bool)
  PyNone
}

///|
fn PyValue::str(self : PyValue) -> String {
  match self {
    PyStr(s) => s
    PyInt(i) => i.to_string()
    PyFloat(d) => @rich.py_float_repr(d)
    PyBool(b) => if b { "True" } else { "False" }
    PyNone => "None"
  }
}

///|
fn PyValue::repr(self : PyValue) -> String {
  match self {
    PyStr(s) => @rich.py_repr(s)
    _ => self.str()
  }
}

///|
/// A task quantity: upstream keeps Python ints for counts given as ints
/// (`advance(1)`, `total=100`), so integral values are shown as ints.
fn quantity(d : Double) -> PyValue {
  if d == d.floor() && d.abs() < 9007199254740992.0 {
    PyInt(d.to_int64())
  } else {
    PyFloat(d)
  }
}

///|
fn opt_quantity(d : Double?) -> PyValue {
  match d {
    Some(d) => quantity(d)
    None => PyNone
  }
}

///|
fn opt_float(d : Double?) -> PyValue {
  match d {
    Some(d) => PyFloat(d)
    None => PyNone
  }
}

///|
fn json_value(j : Json) -> PyValue {
  match j {
    Null => PyNone
    True => PyBool(true)
    False => PyBool(false)
    Number(n, ..) =>
      if n == n.floor() && n.abs() < 9007199254740992.0 {
        PyInt(n.to_int64())
      } else {
        PyFloat(n)
      }
    String(s) => PyStr(s)
    _ => PyStr(j.stringify())
  }
}

///|
/// Look up `task.<attr>` (and `task.fields[<key>]`).
fn task_attribute(task : Task, field : String) -> PyValue raise @rich.RichError {
  guard field.strip_prefix("task.") is Some(attr) else {
    raise ValueError("unknown format field \{@rich.py_repr(field)}")
  }
  let attr = attr.to_owned()
  if attr.strip_prefix("fields[") is Some(rest) &&
    rest.strip_suffix("]") is Some(key) {
    let key = key.to_owned()
    match task.fields.get(key) {
      Some(v) => return json_value(v)
      None => raise ValueError("KeyError: \{@rich.py_repr(key)}")
    }
  }
  match attr {
    "id" => PyInt(task.id.to_int64())
    "description" => PyStr(task.description)
    "total" => opt_quantity(task.total)
    "completed" => quantity(task.completed)
    "finished_time" => opt_float(task.finished_time)
    "visible" => PyBool(task.visible)
    "start_time" => opt_float(task.start_time)
    "stop_time" => opt_float(task.stop_time)
    "finished_speed" => opt_float(task.finished_speed)
    "started" => PyBool(task.started())
    "remaining" => opt_quantity(task.remaining())
    "elapsed" => opt_float(task.elapsed())
    "finished" => PyBool(task.finished())
    "percentage" => PyFloat(task.percentage())
    "speed" => opt_float(task.speed())
    "time_remaining" =>
      match task.time_remaining() {
        Some(t) if !task.finished() => PyInt(t.to_int64())
        t => opt_float(t)
      }
    _ =>
      raise ValueError("'Task' object has no attribute \{@rich.py_repr(attr)}")
  }
}

///|
/// Format `template` with Python's `str.format(task=task)`.
pub fn format_task(
  template : String,
  task : Task,
) -> String raise @rich.RichError {
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
      // find the matching '}' (format specs may not nest here)
      let mut j = i + 1
      let mut depth = 0
      while j < n && !(template[j] == '}' && depth == 0) {
        if template[j] == '[' {
          depth += 1
        } else if template[j] == ']' {
          depth -= 1
        }
        j += 1
      }
      guard j < n else {
        raise ValueError("Single '{' encountered in format string")
      }
      let inner = template.view(start_offset=i + 1, end_offset=j).to_owned()
      buf.write_string(format_field(inner, task))
      i = j + 1
    } else if c == '}' {
      guard i + 1 < n && template[i + 1] == '}' else {
        raise ValueError("Single '}' encountered in format string")
      }
      buf.write_char('}')
      i += 2
    } else {
      buf.write_char(c.to_int().unsafe_to_char())
      i += 1
    }
  }
  buf.to_string()
}

///|
fn format_field(inner : String, task : Task) -> String raise @rich.RichError {
  // split off the format spec (first ':' outside brackets) and conversion
  let mut depth = 0
  let mut colon = -1
  for k in 0..<inner.length() {
    let c = inner[k]
    if c == '[' {
      depth += 1
    } else if c == ']' {
      depth -= 1
    } else if c == ':' && depth == 0 {
      colon = k
      break
    }
  }
  let (field, spec) = if colon >= 0 {
    (
      inner.view(end_offset=colon).to_owned(),
      inner.view(start_offset=colon + 1).to_owned(),
    )
  } else {
    (inner, "")
  }
  let (field, conversion) = if field.length() >= 2 &&
    field[field.length() - 2] == '!' {
    (
      field.view(end_offset=field.length() - 2).to_owned(),
      Some(field[field.length() - 1]),
    )
  } else {
    (field, None)
  }
  let value = task_attribute(task, field)
  let value = match conversion {
    None => value
    Some('s') => PyStr(value.str())
    Some('r') | Some('a') => PyStr(value.repr())
    Some(_) => raise ValueError("Unknown conversion specifier")
  }
  format_value(value, spec)
}

///|
priv struct FormatSpec {
  fill : Char
  align : Char?
  sign : Char
  width : Int
  grouping : Char?
  precision : Int?
  type_ : Char?
}

///|
fn parse_spec(spec : String) -> FormatSpec raise @rich.RichError {
  let chars = spec.to_array()
  let n = chars.length()
  let mut i = 0
  let mut fill = ' '
  let mut align : Char? = None
  fn is_align(c : Char) -> Bool {
    c == '<' || c == '>' || c == '^' || c == '='
  }

  if n >= 2 && is_align(chars[1]) {
    fill = chars[0]
    align = Some(chars[1])
    i = 2
  } else if n >= 1 && is_align(chars[0]) {
    align = Some(chars[0])
    i = 1
  }
  let mut sign = '-'
  if i < n && (chars[i] == '+' || chars[i] == '-' || chars[i] == ' ') {
    sign = chars[i]
    i += 1
  }
  if i < n && chars[i] == '#' {
    i += 1
  }
  if i < n && chars[i] == '0' {
    if align is None {
      fill = '0'
      align = Some('=')
    }
    i += 1
  }
  let mut width = 0
  while i < n && chars[i] >= '0' && chars[i] <= '9' {
    width = width * 10 + (chars[i].to_int() - '0'.to_int())
    i += 1
  }
  let mut grouping : Char? = None
  if i < n && (chars[i] == ',' || chars[i] == '_') {
    grouping = Some(chars[i])
    i += 1
  }
  let mut precision : Int? = None
  if i < n && chars[i] == '.' {
    i += 1
    let mut p = 0
    let start = i
    while i < n && chars[i] >= '0' && chars[i] <= '9' {
      p = p * 10 + (chars[i].to_int() - '0'.to_int())
      i += 1
    }
    guard i > start else {
      raise ValueError("Format specifier missing precision")
    }
    precision = Some(p)
  }
  let mut type_ : Char? = None
  if i < n {
    type_ = Some(chars[i])
    i += 1
  }
  guard i == n else {
    raise ValueError("Invalid format specifier \{@rich.py_repr(spec)}")
  }
  { fill, align, sign, width, grouping, precision, type_, }
}

///|
fn pad(
  body : String,
  sign : String,
  spec : FormatSpec,
  default_align : Char,
) -> String {
  let length = body.length() + sign.length()
  if length >= spec.width {
    return sign + body
  }
  let padding = spec.width - length
  let fill = spec.fill.to_string()
  match spec.align.unwrap_or(default_align) {
    '<' => sign + body + fill.repeat(padding)
    '^' => {
      let left = padding / 2
      fill.repeat(left) + sign + body + fill.repeat(padding - left)
    }
    '=' => sign + fill.repeat(padding) + body
    _ => fill.repeat(padding) + sign + body
  }
}

///|
fn group(digits : String, grouping : Char?) -> String {
  match grouping {
    None => digits
    Some(',') => @rich.py_group_thousands(digits)
    Some(_) => @rich.py_group_thousands(digits).replace_all(old=",", new="_")
  }
}

///|
fn sign_of(negative : Bool, spec : FormatSpec) -> String {
  if negative {
    "-"
  } else if spec.sign == '+' {
    "+"
  } else if spec.sign == ' ' {
    " "
  } else {
    ""
  }
}

///|
fn format_exponent(d : Double, precision : Int, upper : Bool) -> String {
  // d >= 0
  if d == 0.0 {
    let mantissa = @rich.py_format_fixed(0.0, precision)
    return mantissa + (if upper { "E+00" } else { "e+00" })
  }
  let mut exp = @math.log10(d).floor().to_int()
  let mut mantissa = d / @math.pow(10.0, exp.to_double())
  let mut m = @rich.py_format_fixed(mantissa, precision)
  if m.has_prefix("10") {
    exp += 1
    mantissa = d / @math.pow(10.0, exp.to_double())
    m = @rich.py_format_fixed(mantissa, precision)
  }
  let e = exp.abs()
  let es = if e < 10 { "0\{e}" } else { e.to_string() }
  m + (if upper { "E" } else { "e" }) + (if exp < 0 { "-" } else { "+" }) + es
}

///|
fn format_float(d : Double, spec : FormatSpec) -> String raise @rich.RichError {
  let negative = d < 0.0 || (d == 0.0 && 1.0 / d < 0.0)
  let a = d.abs()
  let body = match spec.type_ {
    Some('f') | Some('F') =>
      group(
        @rich.py_format_fixed(a, spec.precision.unwrap_or(6)),
        spec.grouping,
      )
    Some('%') =>
      group(
        @rich.py_format_fixed(a * 100.0, spec.precision.unwrap_or(6)),
        spec.grouping,
      ) +
      "%"
    Some('e') => format_exponent(a, spec.precision.unwrap_or(6), false)
    Some('E') => format_exponent(a, spec.precision.unwrap_or(6), true)
    Some('g') | Some('G') | None =>
      match (spec.type_, spec.precision) {
        (None, None) => group(@rich.py_float_repr(a), spec.grouping)
        _ => group(@rich.py_format_g(a), spec.grouping)
      }
    Some(t) =>
      raise ValueError("Unknown format code '\{t}' for object of type 'float'")
  }
  pad(body, sign_of(negative, spec), spec, '>')
}

///|
fn format_int(i : Int64, spec : FormatSpec) -> String raise @rich.RichError {
  match spec.type_ {
    Some('f' | 'F' | '%' | 'e' | 'E' | 'g' | 'G') =>
      return format_float(i.to_double(), spec)
    _ => ()
  }
  let negative = i < 0L
  let a = i.abs()
  let body = match spec.type_ {
    None | Some('d') | Some('n') => group(a.to_string(), spec.grouping)
    Some('x') => a.to_string(radix=16)
    Some('X') => a.to_string(radix=16).to_upper()
    Some('o') => a.to_string(radix=8)
    Some('b') => a.to_string(radix=2)
    Some(t) =>
      raise ValueError("Unknown format code '\{t}' for object of type 'int'")
  }
  pad(body, sign_of(negative, spec), spec, '>')
}

///|
/// Python `format(value, spec)`.
fn format_value(value : PyValue, spec : String) -> String raise @rich.RichError {
  if spec == "" {
    return value.str()
  }
  let spec = parse_spec(spec)
  match value {
    PyStr(s) => {
      match spec.type_ {
        None | Some('s') => ()
        Some(t) =>
          raise ValueError(
            "Unknown format code '\{t}' for object of type 'str'",
          )
      }
      let s = match spec.precision {
        Some(p) if p < s.length() => s.view(end_offset=p).to_owned()
        _ => s
      }
      pad(s, "", spec, '<')
    }
    PyInt(i) => format_int(i, spec)
    PyBool(b) => format_int(if b { 1L } else { 0L }, spec)
    PyFloat(d) => format_float(d, spec)
    PyNone =>
      raise ValueError(
        "unsupported format string passed to NoneType.__format__",
      )
  }
}
