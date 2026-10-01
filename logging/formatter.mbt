// A replacement for Python's `logging.Formatter` (`%`-style formats).

///|
/// Formats a log record as a string (Python `logging.Formatter` with
/// `style="%"`). `fmt` uses `%(attribute)s` placeholders; `datefmt` is a
/// `strftime` format for `%(asctime)s` (and for the time column of
/// `RichHandler`).
pub struct Formatter {
  fmt : String
  datefmt : String?
}

///|
/// Create a formatter; `fmt` defaults to `"%(message)s"`.
pub fn Formatter::new(
  fmt? : String = "%(message)s",
  datefmt? : String,
) -> Formatter {
  { fmt, datefmt, }
}

///|
/// Check if the format uses the creation time of the record.
pub fn Formatter::uses_time(self : Formatter) -> Bool {
  self.fmt.contains("%(asctime)")
}

///|
/// Return the creation time of the record formatted with `datefmt`, or as
/// `%Y-%m-%d %H:%M:%S,mmm` (local time).
pub fn Formatter::format_time(
  self : Formatter,
  record : LogRecord,
  datefmt? : String,
) -> String {
  ignore(self)
  match datefmt {
    Some(datefmt) => @term.strftime(datefmt, record.created)
    None => {
      let s = @term.strftime("%Y-%m-%d %H:%M:%S", record.created)
      let ms = record.msecs().to_string()
      "\{s},\{"0".repeat(3 - ms.length())}\{ms}"
    }
  }
}

///|
priv enum FieldValue {
  S(String)
  I(Int)
  F(Double)
}

///|
fn Formatter::lookup(
  self : Formatter,
  record : LogRecord,
  key : String,
) -> FieldValue? {
  match key {
    "name" => Some(S(record.name))
    "msg" | "message" => Some(S(record.get_message()))
    "levelno" => Some(I(record.levelno))
    "levelname" => Some(S(record.levelname))
    "pathname" => Some(S(record.pathname))
    "filename" => Some(S(record.filename()))
    "module" => Some(S(record.module_()))
    "lineno" => Some(I(record.lineno))
    "funcName" => Some(S(record.func_name))
    "created" => Some(F(record.created))
    "msecs" => Some(F(record.msecs().to_double()))
    "asctime" => Some(S(self.format_time(record, datefmt?=self.datefmt)))
    "exc_text" =>
      Some(
        S(
          match record.exc_text {
            Some(t) => t
            None => "None"
          },
        ),
      )
    "stack_info" =>
      Some(
        S(
          match record.stack_info {
            Some(t) => t
            None => "None"
          },
        ),
      )
    _ =>
      match record.extra.get(key) {
        Some(v) => Some(S(v))
        None => None
      }
  }
}

///|
/// Format a field with a `%` conversion (`s`, `r`, `d`, `i`, `f`, ...).
fn format_field(
  value : FieldValue,
  flags : String,
  width : Int?,
  precision : Int?,
  conversion : Char,
) -> String {
  let body = match (conversion, value) {
    ('s', S(s)) | ('a', S(s)) =>
      match precision {
        Some(p) if p < s.length() => s.view(end_offset=p).to_owned()
        _ => s
      }
    ('r', S(s)) => @rich.py_repr(s)
    ('d' | 'i' | 'u', F(d)) => d.to_int().to_string()
    ('d' | 'i' | 'u', I(n)) => n.to_string()
    ('f' | 'F', F(d)) => @rich.py_format_fixed(d, precision.unwrap_or(6))
    ('f' | 'F', I(n)) =>
      @rich.py_format_fixed(n.to_double(), precision.unwrap_or(6))
    ('e' | 'E' | 'g' | 'G', F(d)) => @rich.py_format_g(d)
    (_, I(n)) => n.to_string()
    (_, F(d)) => @rich.py_float_repr(d)
    (_, S(s)) => s
  }
  let body = if flags.contains("+") && !body.has_prefix("-") && !(value is S(_)) {
    "+" + body
  } else {
    body
  }
  match width {
    Some(w) if w > body.length() => {
      let pad = w - body.length()
      if flags.contains("-") {
        body + " ".repeat(pad)
      } else if flags.contains("0") && !(value is S(_)) {
        if body.has_prefix("-") || body.has_prefix("+") {
          body.view(end_offset=1).to_owned() +
          "0".repeat(pad) +
          body.view(start_offset=1).to_owned()
        } else {
          "0".repeat(pad) + body
        }
      } else {
        " ".repeat(pad) + body
      }
    }
    _ => body
  }
}

///|
/// Format the message part of the record (Python `formatMessage`):
/// substitute the `%(attribute)` placeholders of `fmt`. Raises
/// `ValueError` for unknown attributes.
pub fn Formatter::format_message(
  self : Formatter,
  record : LogRecord,
) -> String raise @rich.RichError {
  let fmt = self.fmt
  let out = StringBuilder()
  let n = fmt.length()
  let mut i = 0
  while i < n {
    let c = fmt[i]
    if c != '%' {
      out.write_char(c.to_int().unsafe_to_char())
      i += 1
      continue
    }
    if i + 1 < n && fmt[i + 1] == '%' {
      out.write_char('%')
      i += 2
      continue
    }
    guard i + 1 < n && fmt[i + 1] == '(' else {
      raise @rich.ValueError("Invalid format '\{fmt}' for '%' style")
    }
    guard fmt.find_from(")", i + 2) is Some(close) else {
      raise @rich.ValueError("Invalid format '\{fmt}' for '%' style")
    }
    let key = fmt.view(start_offset=i + 2, end_offset=close).to_owned()
    let mut j = close + 1
    let flags = StringBuilder()
    while j < n && fmt[j] is ('#' | '0' | '+' | ' ' | '-') {
      flags.write_char(fmt[j].to_int().unsafe_to_char())
      j += 1
    }
    let mut width : Int? = None
    while j < n && fmt[j] is ('0'..='9') {
      width = Some(width.unwrap_or(0) * 10 + (fmt[j].to_int() - '0'.to_int()))
      j += 1
    }
    let mut precision : Int? = None
    if j < n && fmt[j] == '.' {
      j += 1
      precision = Some(0)
      while j < n && fmt[j] is ('0'..='9') {
        precision = Some(
          precision.unwrap_or(0) * 10 + (fmt[j].to_int() - '0'.to_int()),
        )
        j += 1
      }
    }
    guard j < n else {
      raise @rich.ValueError("Invalid format '\{fmt}' for '%' style")
    }
    let conversion = fmt[j].to_int().unsafe_to_char()
    guard self.lookup(record, key) is Some(value) else {
      raise @rich.ValueError("Formatting field not found in record: '\{key}'")
    }
    out.write_string(
      format_field(value, flags.to_string(), width, precision, conversion),
    )
    i = j + 1
  }
  out.to_string()
}

///|
/// Format the record as text (Python `Formatter.format`): the formatted
/// message followed by the exception text and the stack information.
pub fn Formatter::format(
  self : Formatter,
  record : LogRecord,
) -> String raise @rich.RichError {
  let mut s = self.format_message(record)
  if record.exc_text is Some(exc_text) && exc_text != "" {
    if !s.has_suffix("\n") {
      s = s + "\n"
    }
    s = s + exc_text
  }
  if record.stack_info is Some(stack_info) && stack_info != "" {
    if !s.has_suffix("\n") {
      s = s + "\n"
    }
    s = s + stack_info
  }
  s
}

///|
/// Find `needle` in `self` at or after `start`.
fn String::find_from(self : String, needle : String, start : Int) -> Int? {
  match self.view(start_offset=start).find(needle) {
    Some(i) => Some(start + i)
    None => None
  }
}
