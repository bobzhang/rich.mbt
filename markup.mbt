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
/// `str(tag)` without going through `Show`.
fn Tag::style_text(self : Tag) -> String {
  match self.parameters {
    None => self.name
    Some(p) => self.name + " " + p
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
/// An item of parsed markup (upstream `_parse` yields
/// `(position, text, tag)` tuples): text or a tag, at a position.
pub(all) enum MarkupItem {
  PlainText(Int, String)
  TagAt(Int, Tag)
} derive(Eq, Debug)

///|
/// Parse markup in to a list of text and tag items (upstream
/// `markup._parse`).
pub fn parse_markup(markup : String) -> Array[MarkupItem] {
  let out = []
  let mut position = 0
  let n = markup.length()
  // Hand-written equivalent of `re_tags.finditer(markup)`, i.e. the regex
  // `((\\*)\[([a-z#/@][^[]*?)])`: a run of backslashes, `[`, a tag start
  // character and the shortest run of non-`[` characters up to `]`.
  let mut p = 0
  while p < n {
    let c = markup.unsafe_get(p).to_int()
    if c != '\\' && c != '[' {
      p += 1
      continue
    }
    let mut q = p
    while q < n && markup.unsafe_get(q).to_int() == '\\' {
      q += 1
    }
    let tag_start = q + 1
    if q >= n ||
      markup.unsafe_get(q).to_int() != '[' ||
      tag_start >= n ||
      !is_tag_start(markup.unsafe_get(tag_start).to_int()) {
      p += 1
      continue
    }
    let mut r = tag_start + 1
    while r < n {
      let d = markup.unsafe_get(r).to_int()
      if d == '[' || d == ']' {
        break
      }
      r += 1
    }
    if r >= n || markup.unsafe_get(r).to_int() != ']' {
      p += 1
      continue
    }
    // match: whole `p..r+1`, escapes `p..q`, tag text `tag_start..r`
    let end = r + 1
    let escapes_length = q - p
    let mut start = p
    p = end
    if start > position {
      out.push(
        PlainText(start, markup.unsafe_substring(start=position, end=start)),
      )
    }
    if escapes_length != 0 {
      let backslashes = escapes_length / 2
      let escaped = escapes_length % 2
      if backslashes != 0 {
        out.push(PlainText(start, "\\".repeat(backslashes)))
        start += backslashes * 2
      }
      if escaped != 0 {
        out.push(PlainText(start, markup.unsafe_substring(start=q, end~)))
        position = end
        continue
      }
    }
    let tag_text = markup.unsafe_substring(start=tag_start, end=r)
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
/// `[a-z#/@]`: the first character of a markup tag.
fn is_tag_start(c : Int) -> Bool {
  (c >= 'a' && c <= 'z') || c == '#' || c == '/' || c == '@'
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
  let items = parse_markup(markup)
  for item in items {
    match item {
      PlainText(_, plain_text) => {
        let plain_text = if plain_text.contains("\\[") {
          plain_text.replace_all(old="\\[", new="[")
        } else {
          plain_text
        }
        text.append_str(
          if emoji {
            // as upstream, the variant only applies to markup without tags
            @emoji.replace(plain_text)
          } else {
            plain_text
          },
        )
        |> ignore
      }
      TagAt(position, tag) =>
        if tag.name.strip_prefix("/") is Some(closing) {
          let style_name = py_strip(closing.to_owned())
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
                let value = literal_eval_impl(parameters) catch {
                  LitSyntax(msg) =>
                    raise MarkupError(
                      "error parsing \{py_repr(parameters)} in \{py_repr(p)}; \{msg}",
                    )
                  LitValue(msg) =>
                    raise MarkupError("error parsing \{py_repr(p)}; \{msg}")
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
              style: Def(open_tag.style_text()),
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
    let style = tag.style_text()
    if style != "" {
      spans.push({ start, end: text_length, style: Def(style), })
    }
  }
  spans.rev_in_place()
  stable_sort_by(spans, (a, b) => a.start.compare(b.start))
  text.spans_ = spans
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
