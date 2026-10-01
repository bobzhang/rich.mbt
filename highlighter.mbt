// Port of rich/highlighter.py.

///|
/// A highlighter applies styles to text in place.
pub(open) trait Highlighter {
  fn highlight(Self, Text) -> Unit raise
}

///|
/// Highlight a string or a copy of a Text (upstream `highlighter(text)`).
pub fn &Highlighter::apply(self : &Highlighter, text : &IntoText) -> Text raise {
  let highlight_text = match text.into_text_type() {
    Str(s) => Text::new(text=s)
    Text(t) => t.copy()
  }
  self.highlight(highlight_text)
  highlight_text
}

///|
/// A highlighter that doesn't highlight.
pub struct NullHighlighter {}

///|
pub fn NullHighlighter::new() -> NullHighlighter {
  NullHighlighter::{ }
}

///|
pub impl Highlighter for NullHighlighter with fn highlight(_self, _text) {
  ()
}

///|
/// Applies highlighting from a list of regular expressions, where group
/// names are translated to styles prefixed by `base_style`.
pub struct RegexHighlighter {
  highlights : Array[@regex.Regex]
  base_style : String
}

///|
/// Create a highlighter from regular expressions (Python `re` syntax).
pub fn RegexHighlighter::new(
  highlights : Array[String],
  base_style? : String = "",
) -> RegexHighlighter raise @regex.RegexError {
  let compiled = []
  for pattern in highlights {
    compiled.push(compile_regex(pattern))
  }
  { highlights: compiled, base_style, }
}

///|
pub impl Highlighter for RegexHighlighter with fn highlight(self, text) {
  for re in self.highlights {
    text.highlight_regex(re, style_prefix=self.base_style) |> ignore
  }
}

///|
fn must_regex_highlighter(
  highlights : Array[String],
  base_style : String,
) -> RegexHighlighter {
  RegexHighlighter::new(highlights, base_style~) catch {
    _ => abort("invalid built-in highlighter regex")
  }
}

///|
let repr_highlights : Array[String] = [
  "(?P<tag_start><)(?P<tag_name>[-\\w.:|]*)(?P<tag_contents>[\\w\\W]*)(?P<tag_end>>)",
  "(?P<attrib_name>[\\w_]{1,50})=(?P<attrib_value>\"?[\\w_]+\"?)?",
  "(?P<brace>[][{}()])",
  [
    "(?P<ipv4>[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3})", "(?P<ipv6>([A-Fa-f0-9]{1,4}::?){1,7}[A-Fa-f0-9]{1,4})",
    "(?P<eui64>(?:[0-9A-Fa-f]{1,2}-){7}[0-9A-Fa-f]{1,2}|(?:[0-9A-Fa-f]{1,2}:){7}[0-9A-Fa-f]{1,2}|(?:[0-9A-Fa-f]{4}\\.){3}[0-9A-Fa-f]{4})",
    "(?P<eui48>(?:[0-9A-Fa-f]{1,2}-){5}[0-9A-Fa-f]{1,2}|(?:[0-9A-Fa-f]{1,2}:){5}[0-9A-Fa-f]{1,2}|(?:[0-9A-Fa-f]{4}\\.){2}[0-9A-Fa-f]{4})",
    "(?P<uuid>[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12})",
    "(?P<call>[\\w.]*?)\\(", "\\b(?P<bool_true>True)\\b|\\b(?P<bool_false>False)\\b|\\b(?P<none>None)\\b",
    "(?P<ellipsis>\\.\\.\\.)", "(?P<number_complex>(?<!\\w)(?:\\-?[0-9]+\\.?[0-9]*(?:e[-+]?\\d+?)?)(?:[-+](?:[0-9]+\\.?[0-9]*(?:e[-+]?\\d+)?))?j)",
    "(?P<number>(?<!\\w)\\-?[0-9]+\\.?[0-9]*(e[-+]?\\d+?)?\\b|0x[0-9a-fA-F]*)", "(?P<path>\\B(/[-\\w._+]+)*\\/)(?P<filename>[-\\w._+]*)?",
    "(?<![\\\\\\w])(?P<str>b?'''.*?(?<!\\\\)'''|b?'.*?(?<!\\\\)'|b?\\\"\\\"\\\".*?(?<!\\\\)\\\"\\\"\\\"|b?\\\".*?(?<!\\\\)\\\")",
    "(?P<url>(file|https|http|ws|wss)://[-0-9a-zA-Z$_+!`(),.?/;:&=%#~@]*)",
  ].join("|"),
]

///|
let repr_highlighter_instance : RegexHighlighter = must_regex_highlighter(
  repr_highlights, "repr.",
)

///|
/// Highlights the text typically produced from `__repr__` methods.
pub fn ReprHighlighter::new() -> RegexHighlighter {
  repr_highlighter_instance
}

///|
/// Namespace for `ReprHighlighter::new()`.
pub struct ReprHighlighter {}

///|
let json_str_pattern : String = "(?<![\\\\\\w])(?P<str>b?\\\".*?(?<!\\\\)\\\")"

///|
let json_highlighter_base : RegexHighlighter = must_regex_highlighter(
  [
    [
      "(?P<brace>[\\{\\[\\(\\)\\]\\}])", "\\b(?P<bool_true>true)\\b|\\b(?P<bool_false>false)\\b|\\b(?P<null>null)\\b",
      "(?P<number>(?<!\\w)\\-?[0-9]+\\.?[0-9]*(e[\\-\\+]?\\d+?)?\\b|0x[0-9a-fA-F]*)",
      json_str_pattern,
    ].join("|"),
  ],
  "json.",
)

///|
/// Highlights JSON.
pub struct JSONHighlighter {}

///|
pub fn JSONHighlighter::new() -> JSONHighlighter {
  JSONHighlighter::{ }
}

///|
pub impl Highlighter for JSONHighlighter with fn highlight(_self, text) {
  json_highlighter_base.highlight(text)
  let plain = text.plain()
  let re = compile_regex(json_str_pattern)
  for m in re.find_all(plain) {
    let start = m.start()
    let end = m.end()
    let mut cursor = end
    while cursor < plain.length() {
      let c = plain[cursor]
      cursor += 1
      if c == ':' {
        text.spans().push({ start, end, style: Def("json.key"), })
      } else if c == ' ' || c == '\n' || c == '\r' || c == '\t' {
        continue
      }
      break
    }
  }
}

///|
let iso8601_highlights : Array[String] = [
  "^(?P<year>[0-9]{4})-(?P<month>1[0-2]|0[1-9])$", "^(?P<date>(?P<year>[0-9]{4})(?P<month>1[0-2]|0[1-9])(?P<day>3[01]|0[1-9]|[12][0-9]))$",
  "^(?P<date>(?P<year>[0-9]{4})-?(?P<day>36[0-6]|3[0-5][0-9]|[12][0-9]{2}|0[1-9][0-9]|00[1-9]))$",
  "^(?P<date>(?P<year>[0-9]{4})-?W(?P<week>5[0-3]|[1-4][0-9]|0[1-9]))$", "^(?P<date>(?P<year>[0-9]{4})-?W(?P<week>5[0-3]|[1-4][0-9]|0[1-9])-?(?P<day>[1-7]))$",
  "^(?P<time>(?P<hour>2[0-3]|[01][0-9]):?(?P<minute>[0-5][0-9]))$", "^(?P<time>(?P<hour>2[0-3]|[01][0-9])(?P<minute>[0-5][0-9])(?P<second>[0-5][0-9]))$",
  "^(?P<timezone>(Z|[+-](?:2[0-3]|[01][0-9])(?::?(?:[0-5][0-9]))?))$", "^(?P<time>(?P<hour>2[0-3]|[01][0-9])(?P<minute>[0-5][0-9])(?P<second>[0-5][0-9]))(?P<timezone>Z|[+-](?:2[0-3]|[01][0-9])(?::?(?:[0-5][0-9]))?)$",
  "^(?P<date>(?P<year>[0-9]{4})(?P<hyphen>-)?(?P<month>1[0-2]|0[1-9])(?(hyphen)-)(?P<day>3[01]|0[1-9]|[12][0-9])) (?P<time>(?P<hour>2[0-3]|[01][0-9])(?(hyphen):)(?P<minute>[0-5][0-9])(?(hyphen):)(?P<second>[0-5][0-9]))$",
  "^(?P<date>(?P<year>-?(?:[1-9][0-9]*)?[0-9]{4})-(?P<month>1[0-2]|0[1-9])-(?P<day>3[01]|0[1-9]|[12][0-9]))(?P<timezone>Z|[+-](?:2[0-3]|[01][0-9]):[0-5][0-9])?$",
  "^(?P<time>(?P<hour>2[0-3]|[01][0-9]):(?P<minute>[0-5][0-9]):(?P<second>[0-5][0-9])(?P<frac>\\.[0-9]+)?)(?P<timezone>Z|[+-](?:2[0-3]|[01][0-9]):[0-5][0-9])?$",
  "^(?P<date>(?P<year>-?(?:[1-9][0-9]*)?[0-9]{4})-(?P<month>1[0-2]|0[1-9])-(?P<day>3[01]|0[1-9]|[12][0-9]))T(?P<time>(?P<hour>2[0-3]|[01][0-9]):(?P<minute>[0-5][0-9]):(?P<second>[0-5][0-9])(?P<ms>\\.[0-9]+)?)(?P<timezone>Z|[+-](?:2[0-3]|[01][0-9]):[0-5][0-9])?$",
]

///|
let iso8601_highlighter_instance : RegexHighlighter = must_regex_highlighter(
  iso8601_highlights, "iso8601.",
)

///|
/// Highlights ISO8601 date time strings.
pub struct ISO8601Highlighter {}

///|
pub fn ISO8601Highlighter::new() -> RegexHighlighter {
  iso8601_highlighter_instance
}
