// A markdown-it compatible token stream.
//
// Upstream Rich walks the (flattened) token stream produced by
// `MarkdownIt().enable("strikethrough").enable("table")`. This package
// parses with `moonbit-community/cmark` and converts its AST into the same
// stream (see adapter_*.mbt), so the renderer can be ported literally.

///|
/// A markdown-it token, as seen by Rich after `_flatten_tokens`: inline
/// children are spliced into the stream, except for `image` tokens (whose
/// `content` is the raw alt text) and empty `inline` tokens.
pub(all) struct Token {
  /// Token type, e.g. `paragraph_open`, `text`, `fence`, `link_open`.
  type_ : String
  /// HTML tag, e.g. `p`, `h1`, `em`, `code`, `img`.
  tag : String
  /// 1 for opening tokens, -1 for closing tokens, 0 for self-closing.
  nesting : Int
  /// Text content (text, code, html, raw image label, ...).
  content : String
  /// Fence info string.
  info : String
  /// Attributes: `href` (links), `src` (images), `start` (ordered lists),
  /// `style` (table cells).
  attrs : Map[String, String]
}

///|
fn Token::make(
  type_ : String,
  tag : String,
  nesting : Int,
  content? : String = "",
  info? : String = "",
  attrs? : Map[String, String] = {},
) -> Token {
  { type_, tag, nesting, content, info, attrs }
}

///|
fn escape_field(s : String) -> String {
  let sb = StringBuilder()
  for c in s {
    match c {
      '\\' => sb.write_string("\\\\")
      '\n' => sb.write_string("\\n")
      '\t' => sb.write_string("\\t")
      _ => sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
/// A one-line description of the token (type, tag, nesting, content,
/// sorted attributes, info), used to compare against markdown-it.
pub fn Token::dump(self : Token) -> String {
  let keys = self.attrs.keys().collect()
  keys.sort()
  let attrs = keys.map(k => "\{k}=\{escape_field(self.attrs[k])}").join(";")
  "\{self.type_}\t\{self.tag}\t\{self.nesting}\t\{escape_field(self.content)}\t\{attrs}\t\{escape_field(self.info)}"
}
