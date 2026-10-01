// Port of rich/json.py, with a JSON parser/serializer that follows
// Python's `json.loads` / `json.dumps` formatting.

///|
/// A JSON value that keeps object key order and the text of numbers (so
/// that `1` and `1.0` are printed back as Python would).
pub(all) enum JsonValue {
  JNull
  JBool(Bool)
  /// An integer, as decimal text.
  JInt(String)
  JFloat(Double)
  JString(String)
  JArray(Array[JsonValue])
  JObject(Array[(String, JsonValue)])
} derive(Eq, Debug)

///|
priv struct JsonParser {
  src : String
  mut pos : Int
}

///|
fn JsonParser::error(self : JsonParser, msg : String) -> RichError {
  ValueError("\{msg}: char \{self.pos}")
}

///|
fn JsonParser::ws(self : JsonParser) -> Unit {
  while self.pos < self.src.length() &&
        (
          self.src[self.pos] == ' ' ||
          self.src[self.pos] == '\t' ||
          self.src[self.pos] == '\n' ||
          self.src[self.pos] == '\r'
        ) {
    self.pos += 1
  }
}

///|
fn JsonParser::starts(self : JsonParser, s : String) -> Bool {
  self.src.view(start_offset=self.pos).has_prefix(s)
}

///|
fn JsonParser::value(self : JsonParser) -> JsonValue raise RichError {
  self.ws()
  guard self.pos < self.src.length() else {
    raise self.error("Expecting value")
  }
  let c = self.src[self.pos]
  match c {
    '{' => {
      self.pos += 1
      let items : Array[(String, JsonValue)] = []
      self.ws()
      if self.pos < self.src.length() && self.src[self.pos] == '}' {
        self.pos += 1
        return JObject(items)
      }
      while true {
        self.ws()
        guard self.pos < self.src.length() && self.src[self.pos] == '"' else {
          raise self.error("Expecting property name enclosed in double quotes")
        }
        let key = self.string()
        self.ws()
        guard self.pos < self.src.length() && self.src[self.pos] == ':' else {
          raise self.error("Expecting ':' delimiter")
        }
        self.pos += 1
        let v = self.value()
        // duplicate keys: the last value wins, at the first position
        match items.search_by(kv => kv.0 == key) {
          Some(i) => items[i] = (key, v)
          None => items.push((key, v))
        }
        self.ws()
        guard self.pos < self.src.length() else {
          raise self.error("Expecting ',' delimiter")
        }
        if self.src[self.pos] == ',' {
          self.pos += 1
        } else if self.src[self.pos] == '}' {
          self.pos += 1
          break
        } else {
          raise self.error("Expecting ',' delimiter")
        }
      }
      JObject(items)
    }
    '[' => {
      self.pos += 1
      let items = []
      self.ws()
      if self.pos < self.src.length() && self.src[self.pos] == ']' {
        self.pos += 1
        return JArray(items)
      }
      while true {
        items.push(self.value())
        self.ws()
        guard self.pos < self.src.length() else {
          raise self.error("Expecting ',' delimiter")
        }
        if self.src[self.pos] == ',' {
          self.pos += 1
        } else if self.src[self.pos] == ']' {
          self.pos += 1
          break
        } else {
          raise self.error("Expecting ',' delimiter")
        }
      }
      JArray(items)
    }
    '"' => JString(self.string())
    _ =>
      if self.starts("null") {
        self.pos += 4
        JNull
      } else if self.starts("true") {
        self.pos += 4
        JBool(true)
      } else if self.starts("false") {
        self.pos += 5
        JBool(false)
      } else if self.starts("NaN") {
        self.pos += 3
        JFloat(@double.not_a_number)
      } else if self.starts("Infinity") {
        self.pos += 8
        JFloat(@double.infinity)
      } else if self.starts("-Infinity") {
        self.pos += 9
        JFloat(@double.neg_infinity)
      } else {
        self.number()
      }
  }
}

///|
fn JsonParser::number(self : JsonParser) -> JsonValue raise RichError {
  let start = self.pos
  let n = self.src.length()
  fn is_digit(i : Int) -> Bool {
    i < n && self.src[i] >= '0' && self.src[i] <= '9'
  }

  if self.pos < n && self.src[self.pos] == '-' {
    self.pos += 1
  }
  if !is_digit(self.pos) {
    raise self.error("Expecting value")
  }
  if self.src[self.pos] == '0' {
    self.pos += 1
  } else {
    while is_digit(self.pos) {
      self.pos += 1
    }
  }
  let mut is_float = false
  if self.pos < n && self.src[self.pos] == '.' && is_digit(self.pos + 1) {
    is_float = true
    self.pos += 1
    while is_digit(self.pos) {
      self.pos += 1
    }
  }
  if self.pos < n && (self.src[self.pos] == 'e' || self.src[self.pos] == 'E') {
    let save = self.pos
    self.pos += 1
    if self.pos < n && (self.src[self.pos] == '+' || self.src[self.pos] == '-') {
      self.pos += 1
    }
    if is_digit(self.pos) {
      is_float = true
      while is_digit(self.pos) {
        self.pos += 1
      }
    } else {
      self.pos = save
    }
  }
  let text = py_slice(self.src, start, self.pos)
  if is_float {
    JFloat(@string.parse_double(text)) catch {
      _ => raise self.error("Expecting value")
    }
  } else {
    // normalise "-0" like Python's int()
    JInt(if text == "-0" { "0" } else { text })
  }
}

///|
fn JsonParser::string(self : JsonParser) -> String raise RichError {
  self.pos += 1
  let buf = StringBuilder()
  let n = self.src.length()
  while true {
    guard self.pos < n else {
      raise self.error("Unterminated string starting at")
    }
    let c = self.src[self.pos]
    if c == '"' {
      self.pos += 1
      break
    }
    if c == '\\' {
      guard self.pos + 1 < n else { raise self.error("Invalid \\escape") }
      let e = self.src[self.pos + 1]
      self.pos += 2
      match e {
        '"' => buf.write_char('"')
        '\\' => buf.write_char('\\')
        '/' => buf.write_char('/')
        'b' => buf.write_char('\u{08}')
        'f' => buf.write_char('\u{0c}')
        'n' => buf.write_char('\n')
        'r' => buf.write_char('\r')
        't' => buf.write_char('\t')
        'u' => {
          guard self.pos + 4 <= n else {
            raise self.error("Invalid \\uXXXX escape")
          }
          let mut v = 0
          for i in 0..<4 {
            let h = self.src[self.pos + i].to_int()
            let d = if h >= '0'.to_int() && h <= '9'.to_int() {
              h - '0'.to_int()
            } else if h >= 'a'.to_int() && h <= 'f'.to_int() {
              h - 'a'.to_int() + 10
            } else if h >= 'A'.to_int() && h <= 'F'.to_int() {
              h - 'A'.to_int() + 10
            } else {
              raise self.error("Invalid \\uXXXX escape")
            }
            v = v * 16 + d
          }
          self.pos += 4
          // UTF-16 code unit (surrogates combine naturally in MoonBit)
          buf.write_char(v.unsafe_to_char())
        }
        _ => raise self.error("Invalid \\escape")
      }
      continue
    }
    if c.to_int() < 0x20 {
      raise self.error("Invalid control character at")
    }
    buf.write_char(c.to_int().unsafe_to_char())
    self.pos += 1
  }
  buf.to_string()
}

///|
/// Parse JSON text (Python `json.loads`).
pub fn JsonValue::parse(text : String) -> JsonValue raise RichError {
  let p = JsonParser::{ src: text, pos: 0, }
  let v = p.value()
  p.ws()
  if p.pos != text.length() {
    raise p.error("Extra data")
  }
  v
}

///|
/// Convert a MoonBit `Json` value. Integral numbers without a textual
/// representation are treated as integers.
pub fn JsonValue::from_json(json : Json) -> JsonValue {
  match json {
    Null => JNull
    True => JBool(true)
    False => JBool(false)
    Number(d, repr~) =>
      match repr {
        Some(r) if !(r.contains(".") || r.contains("e") || r.contains("E")) =>
          JInt(r)
        Some(_) => JFloat(d)
        None =>
          if d == d.floor() && d.abs() < 9007199254740992.0 {
            JInt(d.to_int64().to_string())
          } else {
            JFloat(d)
          }
      }
    String(s) => JString(s)
    Array(items) => JArray(items.map(JsonValue::from_json))
    Object(m) => {
      let items = []
      for k, v in m {
        items.push((k, JsonValue::from_json(v)))
      }
      JObject(items)
    }
  }
}

///|
/// Python `json.dumps` string encoding.
fn json_encode_string(s : String, ensure_ascii : Bool) -> String {
  let buf = StringBuilder()
  buf.write_char('"')
  for i in 0..<s.length() {
    let c = s[i].to_int()
    match c {
      0x22 => buf.write_string("\\\"")
      0x5c => buf.write_string("\\\\")
      0x0a => buf.write_string("\\n")
      0x0d => buf.write_string("\\r")
      0x09 => buf.write_string("\\t")
      0x08 => buf.write_string("\\b")
      0x0c => buf.write_string("\\f")
      _ =>
        if c < 0x20 || (ensure_ascii && c > 0x7e) {
          buf.write_string("\\u")
          let hex = "0123456789abcdef"
          for shift in [12, 8, 4, 0] {
            buf.write_char(hex[(c >> shift) & 15].to_int().unsafe_to_char())
          }
        } else {
          buf.write_char(c.unsafe_to_char())
        }
    }
  }
  buf.write_char('"')
  buf.to_string()
}

///|
/// Python `json.dumps`. `indent` is the number of spaces (None for a
/// single line); `sort_keys` sorts object keys.
pub fn JsonValue::dumps(
  self : JsonValue,
  indent? : Int? = None,
  ensure_ascii? : Bool = true,
  sort_keys? : Bool = false,
) -> String {
  let buf = StringBuilder()
  let item_sep = if indent is None { ", " } else { "," }
  fn go(v : JsonValue, level : Int) -> Unit {
    match v {
      JNull => buf.write_string("null")
      JBool(b) => buf.write_string(if b { "true" } else { "false" })
      JInt(s) => buf.write_string(s)
      JFloat(d) =>
        buf.write_string(
          if d.is_nan() {
            "NaN"
          } else if d.is_pos_inf() {
            "Infinity"
          } else if d.is_neg_inf() {
            "-Infinity"
          } else {
            py_float_repr(d)
          },
        )
      JString(s) => buf.write_string(json_encode_string(s, ensure_ascii))
      JArray(items) => {
        if items.is_empty() {
          buf.write_string("[]")
          return
        }
        buf.write_char('[')
        for i, item in items {
          if i > 0 {
            buf.write_string(item_sep)
          }
          if indent is Some(n) {
            buf.write_char('\n')
            buf.write_string(" ".repeat(n * (level + 1)))
          }
          go(item, level + 1)
        }
        if indent is Some(n) {
          buf.write_char('\n')
          buf.write_string(" ".repeat(n * level))
        }
        buf.write_char(']')
      }
      JObject(items) => {
        if items.is_empty() {
          buf.write_string("{}")
          return
        }
        let items = if sort_keys {
          let sorted = items.copy()
          stable_sort_by(sorted, (a, b) => a.0.compare(b.0))
          sorted
        } else {
          items
        }
        buf.write_char('{')
        for i, kv in items {
          if i > 0 {
            buf.write_string(item_sep)
          }
          if indent is Some(n) {
            buf.write_char('\n')
            buf.write_string(" ".repeat(n * (level + 1)))
          }
          buf.write_string(json_encode_string(kv.0, ensure_ascii))
          buf.write_string(": ")
          go(kv.1, level + 1)
        }
        if indent is Some(n) {
          buf.write_char('\n')
          buf.write_string(" ".repeat(n * level))
        }
        buf.write_char('}')
      }
    }
  }

  go(self, 0)
  buf.to_string()
}

///|
/// A renderable which pretty prints JSON.
pub struct JSON {
  text : Text
}

///|
/// Pretty print a JSON string.
pub fn JSON::new(
  json : String,
  indent? : Int? = Some(2),
  highlight? : Bool = true,
  ensure_ascii? : Bool = false,
  sort_keys? : Bool = false,
) -> JSON raise {
  let data = JsonValue::parse(json)
  JSON::from_value(data, indent~, highlight~, ensure_ascii~, sort_keys~)
}

///|
/// Pretty print a MoonBit `Json` value.
pub fn JSON::from_data(
  data : Json,
  indent? : Int? = Some(2),
  highlight? : Bool = true,
  ensure_ascii? : Bool = false,
  sort_keys? : Bool = false,
) -> JSON raise {
  JSON::from_value(
    JsonValue::from_json(data),
    indent~,
    highlight~,
    ensure_ascii~,
    sort_keys~,
  )
}

///|
/// Pretty print a `JsonValue`.
pub fn JSON::from_value(
  data : JsonValue,
  indent? : Int? = Some(2),
  highlight? : Bool = true,
  ensure_ascii? : Bool = false,
  sort_keys? : Bool = false,
) -> JSON raise {
  let json = data.dumps(indent~, ensure_ascii~, sort_keys~)
  let highlighter : &Highlighter = if highlight {
    (JSONHighlighter::new() : &Highlighter)
  } else {
    (NullHighlighter::new() : &Highlighter)
  }
  let text = highlighter.apply(json)
  text.no_wrap = Some(true)
  text.overflow = None
  { text, }
}

///|
pub impl Renderable for JSON with fn rich_console(self, _console, _options) {
  [Child(self.text)]
}

///|
pub impl Renderable for JSON with fn rich_measure(self, console, options) {
  self.text.rich_measure(console, options)
}
