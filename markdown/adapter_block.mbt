// Block-level conversion of a cmark AST into markdown-it tokens.
//
// The document is parsed in strict CommonMark mode. markdown-it's GFM
// tables are recovered from paragraph lines (adapter_table.mbt), the
// block rules where markdown-it differs from CommonMark are applied in
// adapter_reparse.mbt, and inline content is converted (with
// markdown-it's strikethrough) in adapter_inline.mbt.

///|
priv struct Converter {
  /// The source the AST locations refer to.
  src : String
  /// Offsets of the start of each line (index 0 is line 1).
  line_starts : Array[Int]
  defs : Map[String, @cmark.LabelDef]
  out : Array[Token]
  /// Number of enclosing block quotes.
  mut quote_depth : Int
  /// Number of enclosing list items.
  mut list_depth : Int
  /// Content column of the list item that is the innermost container (-1
  /// when there is none).
  mut list_indent : Int
}

///|
fn parse_cmark(src : String, defs : Map[String, @cmark.LabelDef]) -> @cmark.Doc {
  @cmark.Doc::from_string(src, defs~, locs=true, layout=true, strict=true)
}

///|
fn compute_line_starts(src : String) -> Array[Int] {
  let starts = [0]
  for i in 0..<src.length() {
    if src[i] == '\n' {
      starts.push(i + 1)
    }
  }
  starts
}

///|
fn Converter::new(
  src : String,
  defs : Map[String, @cmark.LabelDef],
  out : Array[Token],
) -> Converter {
  let line_starts = compute_line_starts(src)
  {
    src,
    line_starts,
    defs,
    out,
    quote_depth: 0,
    list_depth: 0,
    list_indent: -1,
  }
}

///|
/// Convert the content of a document, block quote or list item.
fn Converter::container_content(self : Converter, block : @cmark.Block) -> Unit {
  match block {
    Blocks(seq) => self.blocks(seq.v.to_array())
    b => self.blocks([b])
  }
}

///|
fn Converter::parse(self : Converter, src : String) -> @cmark.Doc {
  parse_cmark(src, self.defs)
}

///|
/// markdown-it input normalization: CRLF / CR to LF, NUL to U+FFFD.
fn normalize_source(s : String) -> String {
  if !s.contains("\r") && !s.contains("\u{0}") {
    return s
  }
  let sb = StringBuilder()
  let n = s.length()
  let mut i = 0
  while i < n {
    let c = s[i]
    if c == '\r' {
      sb.write_char('\n')
      if i + 1 < n && s[i + 1] == '\n' {
        i += 1
      }
    } else if c == 0 {
      sb.write_char('\u{FFFD}')
    } else {
      sb.write_char(c.to_int().unsafe_to_char())
    }
    i += 1
  }
  sb.to_string()
}

///|
/// Parse markdown into the flattened markdown-it token stream Rich renders
/// (`MarkdownIt().enable("strikethrough").enable("table")` followed by
/// `Markdown._flatten_tokens`).
pub fn parse_tokens(markup : String) -> Array[Token] {
  let src = normalize_source(markup)
  let doc = parse_cmark(src, Map([]))
  let conv = Converter::new(src, doc.defs, [])
  conv.container_content(doc.block)
  conv.out
}

///|
fn Converter::push(self : Converter, token : Token) -> Unit {
  self.out.push(token)
}

///|
fn Converter::block(self : Converter, block : @cmark.Block) -> Unit {
  match block {
    Blocks(seq) => self.blocks(seq.v.to_array())
    BlankLine(_) | LinkRefDefinition(_) => ()
    BlockQuote(q) => {
      self.push(Token::make("blockquote_open", "blockquote", 1))
      self.quote_depth += 1
      let list_indent = self.list_indent
      self.list_indent = -1
      self.container_content(q.v.block)
      self.list_indent = list_indent
      self.quote_depth -= 1
      self.push(Token::make("blockquote_close", "blockquote", -1))
    }
    CodeBlock(cb) => self.code_block(cb.v)
    Heading(h) => self.heading(h)
    HtmlBlock(h) => {
      let content = StringBuilder()
      for line in h.v.0.iter() {
        content.write_string(line.v)
        content.write_char('\n')
      }
      let content = self.drop_final_newline(content.to_string(), h.v.0)
      self.push(Token::make("html_block", "", 0, content~))
    }
    List(l) => self.list(l.v)
    Paragraph(p) => self.paragraph(p)
    ThematicBreak(_) => self.push(Token::make("hr", "hr", 0))
    // extensions: not produced in strict mode
    ExtMathBlock(_) | ExtTable(_) | ExtFootnoteDefinition(_) => ()
  }
}

///|
fn Converter::code_block(self : Converter, cb : @cmark.CodeBlock) -> Unit {
  let content = StringBuilder()
  for line in cb.code {
    content.write_string(line.v)
    content.write_char('\n')
  }
  match cb.layout {
    Indented =>
      self.push(
        Token::make("code_block", "code", 0, content=content.to_string()),
      )
    Fenced(layout) => {
      // markdown-it keeps the raw text after the fence marker as `info`.
      let loc = layout.opening_fence.meta.loc
      let info = if loc.is_none() {
        cb.info_string.map(i => i.v).unwrap_or("")
      } else {
        let mut start = loc.first_ccode
        let n = self.src.length()
        while start < n && self.src[start] is (' ' | '\t') {
          start += 1
        }
        if start < n {
          let fence = self.src[start]
          while start < n && self.src[start] == fence {
            start += 1
          }
        }
        substr(self.src, start, end=self.line_end(start))
      }
      let content = if layout.closing_fence is None {
        self.drop_final_newline(content.to_string(), cb.code)
      } else {
        content.to_string()
      }
      self.push(Token::make("fence", "code", 0, content~, info~))
    }
  }
}

///|
/// markdown-it gives no final newline to a block whose last line ends the
/// source without one.
fn Converter::drop_final_newline(
  self : Converter,
  content : String,
  lines : @cmark.Seq[@cmark.Node[String]],
) -> String {
  guard lines.length() > 0 && !self.src.has_suffix("\n") else { return content }
  let last = lines[lines.length() - 1].meta.loc
  if !last.is_none() && last.last_ccode + 1 >= self.src.length() {
    substr(content, 0, end=content.length() - 1)
  } else {
    content
  }
}

///|
/// Offset of the end of the line containing `pos` (before the newline).
fn Converter::line_end(self : Converter, pos : Int) -> Int {
  let n = self.src.length()
  let mut i = pos
  while i < n && self.src[i] != '\n' {
    i += 1
  }
  i
}

///|
fn Converter::list(self : Converter, l : @cmark.BlockList) -> Unit {
  let (open, close, tag, attrs) : (String, String, String, Map[String, String]) = match
    l.ty {
    Unordered(_) => ("bullet_list_open", "bullet_list_close", "ul", {})
    Ordered(start, _) =>
      (
        "ordered_list_open",
        "ordered_list_close",
        "ol",
        if start != 1 {
          { "start": start.to_string() }
        } else {
          {}
        },
      )
  }
  self.push(Token::make(open, tag, 1, attrs~))
  for item in l.items.iter() {
    self.push(Token::make("list_item_open", "li", 1))
    self.list_depth += 1
    let list_indent = self.list_indent
    let marker = item.v.marker.meta.loc
    self.list_indent = if marker.is_none() {
      -1
    } else {
      self.column(marker.first_line.0, marker.first_ccode) +
      item.v.marker.v.length() +
      item.v.after_marker
    }
    self.container_content(item.v.block)
    self.list_indent = list_indent
    self.list_depth -= 1
    self.push(Token::make("list_item_close", "li", -1))
  }
  self.push(Token::make(close, tag, -1))
}

///|
fn Converter::heading(
  self : Converter,
  h : @cmark.Node[@cmark.BlockHeading],
) -> Unit {
  let heading = h.v
  if heading.layout is Setext(_) {
    // A setext heading whose content holds a GFM table: markdown-it parses
    // the table first (the underline then ends it or becomes a row).
    if self.setext_lines(h) is Some(all) && self.split_tables(all) {
      return
    }
  }
  let tag = "h\{heading.level}"
  self.push(Token::make("heading_open", tag, 1))
  self.inline_block(heading.inline, h.meta.loc)
  self.push(Token::make("heading_close", tag, -1))
}

///|
/// The content lines of a setext heading followed by its underline.
fn Converter::setext_lines(
  self : Converter,
  h : @cmark.Node[@cmark.BlockHeading],
) -> Array[Line]? {
  let lines = self.inline_lines(h.v.inline, h.meta.loc)
  let last_line = h.meta.loc.last_line.0
  guard last_line - 1 < self.line_starts.length() &&
    lines.length() > 0 &&
    lines.length() + lines[0].line == last_line else {
    return None
  }
  let start = self.content_start(last_line)
  let all = lines.copy()
  all.push(self.make_line(last_line, start, self.line_end(start)))
  Some(all)
}

///|
fn Converter::paragraph(
  self : Converter,
  p : @cmark.Node[@cmark.BlockParagraph],
) -> Unit {
  let lines = self
    .inline_lines(p.v.inline, p.meta.loc)
    .map(l => { ..l, indent: l.indent + p.v.leading_indent, })
  if self.split_tables(lines) {
    return
  }
  self.push(Token::make("paragraph_open", "p", 1))
  self.inline_block(p.v.inline, p.meta.loc)
  self.push(Token::make("paragraph_close", "p", -1))
}
