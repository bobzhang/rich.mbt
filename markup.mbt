// Port of rich/markup.py.

///|
/// A tag in console markup.
pub(all) struct Tag {
  /// The tag name, e.g. `"bold"`.
  name : String
  /// Any additional parameters after the name.
  parameters : String?
} derive(Eq, Debug)

///|
/// Upstream `str(tag)`.
pub impl Show for Tag with fn output(self, logger) {
  match self.parameters {
    None => logger.write_string(self.name)
    Some(p) => logger.write_string(self.name + " " + p)
  }
}

///|
/// The markup representation of this tag.
pub fn Tag::markup(self : Tag) -> String {
  match self.parameters {
    None => "[\{self.name}]"
    Some(p) => "[\{self.name}=\{p}]"
  }
}

///|
fn must_compile(pattern : String) -> @regex.Regex {
  @regex.compile(pattern) catch {
    _ => abort("invalid built-in regex \{pattern}")
  }
}

///|
let re_tags : @regex.Regex = must_compile("((\\\\*)\\[([a-z#/@][^[]*?)])")

///|
let re_handler : @regex.Regex = must_compile("^([\\w.]*?)(\\(.*?\\))?$")

///|
let re_escape : @regex.Regex = must_compile("(\\\\*)(\\[[a-z#/@][^[]*?])")

///|
/// Escape text so that it won't be interpreted as markup.
pub fn escape(markup : String) -> String {
  let markup = if markup.contains("[") {
    re_escape.replace_all(markup, m => {
      let backslashes = m.group(1).unwrap_or("")
      let text = m.group(2).unwrap_or("")
      backslashes + backslashes + "\\" + text
    }) catch {
      _ => markup
    }
  } else {
    markup
  }
  if markup.has_suffix("\\") && !markup.has_suffix("\\\\") {
    markup + "\\"
  } else {
    markup
  }
}

///|
/// An item of parsed markup: text or a tag at a position.
priv enum MarkupItem {
  PlainText(Int, String)
  TagAt(Int, Tag)
}

///|
fn parse_markup(markup : String) -> Array[MarkupItem] raise {
  let out = []
  let mut position = 0
  for m in re_tags.find_all(markup) {
    let full_text = m.group(1).unwrap_or("")
    let escapes = m.group(2).unwrap_or("")
    let tag_text = m.group(3).unwrap_or("")
    let mut start = m.start()
    let end = m.end()
    if start > position {
      out.push(PlainText(start, py_slice(markup, position, start)))
    }
    if escapes != "" {
      let backslashes = escapes.length() / 2
      let escaped = escapes.length() % 2
      if backslashes != 0 {
        out.push(PlainText(start, "\\".repeat(backslashes)))
        start += backslashes * 2
      }
      if escaped != 0 {
        out.push(
          PlainText(
            start,
            py_slice(full_text, escapes.length(), full_text.length()),
          ),
        )
        position = end
        continue
      }
    }
    let (text, equals, parameters) = partition(tag_text, "=")
    out.push(
      TagAt(start, {
        name: text,
        parameters: if equals {
          Some(parameters)
        } else {
          None
        },
      }),
    )
    position = end
  }
  if position < markup.length() {
    out.push(PlainText(position, py_slice(markup, position, markup.length())))
  }
  out
}

///|
/// Render console markup in to a Text instance.
pub fn render_markup(
  markup : String,
  style? : StyleType = Def(""),
  emoji? : Bool = true,
  emoji_variant? : EmojiVariant,
) -> Text raise RichError {
  let variant = emoji_variant.map(v => v.to_string())
  fn emoji_replace(s : String) -> String {
    @emoji.replace(s, default_variant?=variant)
  }

  if !markup.contains("[") {
    return Text::new(
      text=if emoji { emoji_replace(markup) } else { markup },
      style~,
    )
  }
  let text = Text::new(style~)
  let style_stack : Array[(Int, Tag)] = []
  let spans : Array[Span] = []
  let items = parse_markup(markup) catch { e => raise MarkupError("\{e}") }
  for item in items {
    match item {
      PlainText(_, plain_text) => {
        let plain_text = plain_text.replace_all(old="\\[", new="[")
        text.append_str(
          if emoji {
            emoji_replace(plain_text)
          } else {
            plain_text
          },
        )
        |> ignore
      }
      TagAt(position, tag) =>
        if tag.name.has_prefix("/") {
          let style_name = py_strip(py_slice(tag.name, 1, tag.name.length()))
          let (start, open_tag) = if style_name != "" {
            let style_name = Style::normalize(style_name)
            let mut found = None
            let mut i = style_stack.length() - 1
            while i >= 0 {
              if style_stack[i].1.name == style_name {
                found = Some(style_stack.remove(i))
                break
              }
              i -= 1
            }
            match found {
              Some(f) => f
              None =>
                raise MarkupError(
                  "closing tag '\{tag.markup()}' at position \{position} doesn't match any open tag",
                )
            }
          } else {
            match style_stack.pop() {
              Some(f) => f
              None =>
                raise MarkupError(
                  "closing tag '[/]' at position \{position} has nothing to close",
                )
            }
          }
          if open_tag.name.has_prefix("@") {
            let meta_params : Json = match open_tag.parameters {
              Some(p) if p != "" => {
                let mut handler_name = ""
                let mut parameters = py_strip(p)
                let handler_match = re_handler.match_at(parameters, 0) catch {
                  _ => None
                }
                if handler_match is Some(m) {
                  handler_name = m.group(1).unwrap_or("")
                  parameters = m.group(2).unwrap_or("()")
                }
                let value = literal_eval(parameters) catch {
                  e =>
                    raise MarkupError(
                      "error parsing \{py_repr(parameters)} in \{py_repr(p)}; \{e}",
                    )
                }
                if handler_name != "" {
                  let params = match value {
                    PyTuple(items) => items
                    v => [v]
                  }
                  Json::array([
                    Json::string(handler_name),
                    Json::array(params.map(v => v.to_json())),
                  ])
                } else {
                  value.to_json()
                }
              }
              _ => Json::array([])
            }
            spans.push({
              start,
              end: text.length(),
              style: Style(
                Style::new(meta=Map::from_array([(open_tag.name, meta_params)])),
              ),
            })
          } else {
            spans.push({
              start,
              end: text.length(),
              style: Def(open_tag.to_string()),
            })
          }
        } else {
          let normalized_tag = {
            name: Style::normalize(tag.name),
            parameters: tag.parameters,
          }
          style_stack.push((text.length(), normalized_tag))
        }
    }
  }
  let text_length = text.length()
  while style_stack.pop() is Some((start, tag)) {
    let style = tag.to_string()
    if style != "" {
      spans.push({ start, end: text_length, style: Def(style), })
    }
  }
  spans.rev_in_place()
  stable_sort_by(spans, (a, b) => a.start.compare(b.start))
  text.set_spans(spans)
  text
}

///|
/// Emoji variants.
pub(all) enum EmojiVariant {
  Emoji
  Text
} derive(Eq, Debug)

///|
pub fn EmojiVariant::to_string(self : EmojiVariant) -> String {
  match self {
    Emoji => "emoji"
    Text => "text"
  }
}

///|
/// A Python literal value (as parsed by `ast.literal_eval`).
pub(all) enum PyValue {
  PyNone
  PyBool(Bool)
  PyInt(Int64)
  PyFloat(Double)
  PyStr(String)
  PyTuple(Array[PyValue])
  PyList(Array[PyValue])
  PyDict(Array[(PyValue, PyValue)])
} derive(Eq, Debug)

///|
/// Convert to JSON: tuples and lists become arrays, dicts objects (keys
/// stringified).
pub impl ToJson for PyValue with fn to_json(self) {
  match self {
    PyNone => Json::null()
    PyBool(b) => Json::boolean(b)
    PyInt(n) => Json::number(n.to_double())
    PyFloat(f) => Json::number(f)
    PyStr(s) => Json::string(s)
    PyTuple(items) | PyList(items) => Json::array(items.map(v => v.to_json()))
    PyDict(items) => {
      let m : Map[String, Json] = Map([])
      for kv in items {
        let key = match kv.0 {
          PyStr(s) => s
          k => k.to_json().stringify()
        }
        m[key] = kv.1.to_json()
      }
      Json::object(m)
    }
  }
}

///|
priv struct LitParser {
  src : String
  mut pos : Int
}

///|
fn LitParser::skip_ws(self : LitParser) -> Unit {
  while self.pos < self.src.length() &&
        (
          self.src[self.pos] == ' ' ||
          self.src[self.pos] == '\t' ||
          self.src[self.pos] == '\n'
        ) {
    self.pos += 1
  }
}

///|
fn LitParser::peek(self : LitParser) -> UInt16? {
  if self.pos < self.src.length() {
    Some(self.src[self.pos])
  } else {
    None
  }
}

///|
fn LitParser::expect(self : LitParser, c : UInt16) -> Unit raise RichError {
  self.skip_ws()
  if self.peek() is Some(d) && d == c {
    self.pos += 1
  } else {
    raise ValueError("invalid syntax")
  }
}

///|
fn LitParser::parse_value(self : LitParser) -> PyValue raise RichError {
  self.skip_ws()
  guard self.peek() is Some(c) else { raise ValueError("unexpected EOF") }
  match c {
    '(' => {
      self.pos += 1
      let (items, trailing_comma) = self.parse_items(')')
      if items.length() == 1 && !trailing_comma {
        items[0]
      } else {
        PyTuple(items)
      }
    }
    '[' => {
      self.pos += 1
      let (items, _) = self.parse_items(']')
      PyList(items)
    }
    '{' => {
      self.pos += 1
      let items = []
      self.skip_ws()
      if self.peek() is Some('}') {
        self.pos += 1
        return PyDict(items)
      }
      while true {
        let k = self.parse_value()
        self.expect(':')
        let v = self.parse_value()
        items.push((k, v))
        self.skip_ws()
        match self.peek() {
          Some(',') => {
            self.pos += 1
            self.skip_ws()
            if self.peek() is Some('}') {
              self.pos += 1
              break
            }
          }
          Some('}') => {
            self.pos += 1
            break
          }
          _ => raise ValueError("invalid syntax")
        }
      }
      PyDict(items)
    }
    '\'' | '"' => {
      let buf = StringBuilder()
      while self.peek() is Some(q) && (q == '\'' || q == '"') {
        buf.write_string(self.parse_string())
        self.skip_ws()
      }
      PyStr(buf.to_string())
    }
    _ => self.parse_atom()
  }
}

///|
fn LitParser::parse_items(
  self : LitParser,
  close : UInt16,
) -> (Array[PyValue], Bool) raise RichError {
  let items = []
  let mut trailing_comma = false
  self.skip_ws()
  if self.peek() is Some(c) && c == close {
    self.pos += 1
    return (items, false)
  }
  while true {
    items.push(self.parse_value())
    self.skip_ws()
    match self.peek() {
      Some(',') => {
        self.pos += 1
        trailing_comma = true
        self.skip_ws()
        if self.peek() is Some(c) && c == close {
          self.pos += 1
          break
        }
        trailing_comma = false
      }
      Some(c) if c == close => {
        self.pos += 1
        break
      }
      _ => raise ValueError("invalid syntax")
    }
  }
  (items, trailing_comma)
}

///|
fn LitParser::parse_string(self : LitParser) -> String raise RichError {
  let quote = self.src[self.pos]
  // triple quotes
  let triple = self.pos + 2 < self.src.length() &&
    self.src[self.pos + 1] == quote &&
    self.src[self.pos + 2] == quote
  self.pos += if triple { 3 } else { 1 }
  let buf = StringBuilder()
  while true {
    guard self.pos < self.src.length() else {
      raise ValueError("unterminated string literal")
    }
    let c = self.src[self.pos]
    if c == quote {
      if triple {
        if self.pos + 2 < self.src.length() &&
          self.src[self.pos + 1] == quote &&
          self.src[self.pos + 2] == quote {
          self.pos += 3
          break
        }
      } else {
        self.pos += 1
        break
      }
    }
    if c == '\\' && self.pos + 1 < self.src.length() {
      let e = self.src[self.pos + 1]
      self.pos += 2
      match e {
        'n' => buf.write_char('\n')
        't' => buf.write_char('\t')
        'r' => buf.write_char('\r')
        '\\' => buf.write_char('\\')
        '\'' => buf.write_char('\'')
        '"' => buf.write_char('"')
        '0' => buf.write_char('\u{0}')
        _ => {
          buf.write_char('\\')
          buf.write_char(e.to_int().unsafe_to_char())
        }
      }
      continue
    }
    buf.write_char(c.to_int().unsafe_to_char())
    self.pos += 1
  }
  buf.to_string()
}

///|
fn LitParser::parse_atom(self : LitParser) -> PyValue raise RichError {
  let start = self.pos
  while self.pos < self.src.length() {
    let c = self.src[self.pos]
    if c is (',' | ')' | ']' | '}' | ':' | ' ' | '\t' | '\n') {
      break
    }
    self.pos += 1
  }
  let atom = py_slice(self.src, start, self.pos)
  match atom {
    "None" => PyNone
    "True" => PyBool(true)
    "False" => PyBool(false)
    _ => {
      let s = atom.replace_all(old="_", new="")
      if s.contains(".") || s.contains("e") || s.contains("E") {
        if s.has_prefix("0x") || s.has_prefix("0X") {
          PyInt(@string.parse_int64(s, base=0)) catch {
            _ => raise ValueError("malformed node or string")
          }
        } else {
          PyFloat(@string.parse_double(s)) catch {
            _ => raise ValueError("malformed node or string")
          }
        }
      } else {
        PyInt(@string.parse_int64(s, base=0)) catch {
          _ => raise ValueError("malformed node or string")
        }
      }
    }
  }
}

///|
/// A subset of Python's `ast.literal_eval`: numbers, strings, `True`,
/// `False`, `None`, tuples, lists and dicts.
pub fn literal_eval(source : String) -> PyValue raise RichError {
  let p = LitParser::{ src: source, pos: 0, }
  let v = p.parse_value()
  p.skip_ws()
  if p.pos != source.length() {
    raise ValueError("invalid syntax")
  }
  v
}
