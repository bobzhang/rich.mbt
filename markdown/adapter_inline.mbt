// Inline conversion of cmark inlines into markdown-it tokens, including
// markdown-it's `~~strikethrough~~` (rules_inline/strikethrough.py), which
// strict CommonMark leaves as text.

///|
priv struct Delim {
  token : Int
  mut end : Int
  mut open : Bool
  mut close : Bool
}

///|
priv struct InlineConv {
  /// The source the inline locations refer to.
  src : String
  defs : Map[String, @cmark.LabelDef]
  /// Whether `src` is an inline snippet (continuation lines indented by 4).
  snippet : Bool
  /// Content column of the innermost container when it is a list item
  /// (-1 otherwise).
  list_indent : Int
  /// Whether `<` were escaped in the snippet (see escape_unmatched_html).
  mut escaped_lt : Bool
  out : Array[Token]
  scopes : Array[Array[Delim]]
}

///|
fn InlineConv::new(
  src : String,
  defs : Map[String, @cmark.LabelDef],
  snippet~ : Bool,
  list_indent? : Int = -1,
) -> InlineConv {
  { src, defs, snippet, list_indent, escaped_lt: false, out: [], scopes: [], }
}

///|
fn InlineConv::new_scope(self : InlineConv) -> Int {
  self.scopes.push([])
  self.scopes.length() - 1
}

///|
fn InlineConv::push(self : InlineConv, token : Token) -> Unit {
  self.out.push(token)
}

///|
fn InlineConv::push_text(self : InlineConv, s : String) -> Unit {
  if s != "" {
    self.out.push(Token::make("text", "", 0, content=s))
  }
}

///|
fn InlineConv::slice(self : InlineConv, first : Int, last : Int) -> String {
  let s = substr(self.src, first, end=last + 1)
  let s = if self.snippet { s.replace_all(old="\n    ", new="\n") } else { s }
  if self.escaped_lt {
    s.replace_all(old="\\<", new="<")
  } else {
    s
  }
}

///|
fn InlineConv::inline(
  self : InlineConv,
  inline : @cmark.Inline,
  scope : Int,
) -> Unit {
  match inline {
    Inlines(seq) =>
      for i in seq.v.iter() {
        self.inline(i, scope)
      }
    Text(t) => self.text(t.v, t.meta.loc, scope)
    Break(b) =>
      match b.v.ty {
        Soft => self.push(Token::make("softbreak", "br", 0))
        Hard => self.push(Token::make("hardbreak", "br", 0))
      }
    CodeSpan(c) => self.code_span(c.v)
    Emphasis(e) => {
      self.push(Token::make("em_open", "em", 1))
      self.inline(e.v.inline, self.new_scope())
      self.push(Token::make("em_close", "em", -1))
    }
    StrongEmphasis(e) => {
      // markdown-it turns the outer delimiter characters of `**` into empty
      // text tokens (merged with adjacent text afterwards).
      self.push(Token::make("text", "", 0))
      self.push(Token::make("strong_open", "strong", 1))
      self.inline(e.v.inline, self.new_scope())
      self.push(Token::make("strong_close", "strong", -1))
      self.push(Token::make("text", "", 0))
    }
    Link(l) => self.link(l, scope)
    Image(l) => self.image(l)
    Autolink(a) => {
      // markdown-it does not resolve entities in autolinks
      let loc = a.meta.loc
      let url = if loc.is_none() {
        a.v.link.v
      } else {
        self.slice(loc.first_ccode + 1, loc.last_ccode - 1)
      }
      let href = if a.v.is_email {
        normalize_link("mailto:" + url)
      } else {
        normalize_link(url)
      }
      if !validate_link(href) {
        // not an autolink for markdown-it: the content is plain text
        let text = @cmark_char.utf_16_clean_unesc_unref(
          StringBuilder(),
          url,
          first=0,
          last=url.length() - 1,
        )
        self.push_text("<" + text + ">")
      } else {
        self.push(Token::make("link_open", "a", 1, attrs={ "href": href }))
        self.push_text(normalize_link_text(url))
        self.push(Token::make("link_close", "a", -1))
      }
    }
    RawHtml(h) => self.raw_html(self.layout_lines(h.v.0).join("\n"))
    // extensions: not produced in strict mode
    ExtStrikethrough(_) | ExtMathSpan(_) => ()
  }
}

///|
fn InlineConv::link_dest(self : InlineConv, l : @cmark.InlineLink) -> String? {
  match l.reference_definition(self.defs) {
    Some(LinkDef(def)) =>
      match def.v.dest {
        Some(d) => Some(d.v)
        None => Some("")
      }
    _ => None
  }
}

///|
fn InlineConv::link(
  self : InlineConv,
  l : @cmark.Node[@cmark.InlineLink],
  scope : Int,
) -> Unit {
  let dest = self.link_dest(l.v)
  let href = normalize_link(dest.unwrap_or(""))
  if dest is None || !validate_link(href) {
    // markdown-it does not produce a link: the brackets stay text.
    self.push_text("[")
    self.inline(l.v.text, scope)
    let text_loc = l.v.text.meta().loc
    let loc = l.meta.loc
    if !loc.is_none() && !text_loc.is_none() {
      // the location of an empty or compound text covers its `[` and `]`
      let after = if text_loc.first_ccode == loc.first_ccode {
        text_loc.last_ccode
      } else {
        text_loc.last_ccode + 1
      }
      self.push_text(self.slice(after, loc.last_ccode))
    }
    return
  }
  self.push(Token::make("link_open", "a", 1, attrs={ "href": href }))
  self.inline(l.v.text, self.new_scope())
  self.push(Token::make("link_close", "a", -1))
}

///|
fn InlineConv::image(
  self : InlineConv,
  l : @cmark.Node[@cmark.InlineLink],
) -> Unit {
  let dest = self.link_dest(l.v)
  let src = normalize_link(dest.unwrap_or(""))
  let loc = l.meta.loc
  if dest is None || !validate_link(src) {
    if !loc.is_none() {
      self.push_text(self.slice(loc.first_ccode, loc.last_ccode))
    }
    return
  }
  let text_loc = l.v.text.meta().loc
  let label = if l.v.text.is_empty() || text_loc.is_none() {
    ""
  } else if !loc.is_none() && text_loc.first_ccode == loc.first_ccode {
    // the location of a compound label covers its `![` and `]`
    self.slice(text_loc.first_ccode + 2, text_loc.last_ccode - 1)
  } else {
    self.slice(text_loc.first_ccode, text_loc.last_ccode)
  }
  self.push(Token::make("image", "img", 0, content=label, attrs={ "src": src }))
}

///|
fn char_before(s : String, pos : Int) -> Char {
  if pos <= 0 {
    return ' '
  }
  let c = s[pos - 1].to_int()
  if c >= 0xDC00 && c <= 0xDFFF && pos >= 2 {
    let h = s[pos - 2].to_int()
    if h >= 0xD800 && h <= 0xDBFF {
      return (0x10000 + ((h - 0xD800) << 10) + (c - 0xDC00)).unsafe_to_char()
    }
  }
  c.unsafe_to_char()
}

///|
fn char_at(s : String, pos : Int) -> Char {
  if pos >= s.length() {
    return ' '
  }
  s.get_char(pos).unwrap_or(s[pos].to_int().unsafe_to_char())
}

///|
/// markdown-it `isWhiteSpace`.
fn md_is_whitespace(c : Char) -> Bool {
  let code = c.to_int()
  (code >= 0x2000 && code <= 0x200A) ||
  code
  is (0x09
  | 0x0A
  | 0x0B
  | 0x0C
  | 0x0D
  | 0x20
  | 0xA0
  | 0x1680
  | 0x202F
  | 0x205F
  | 0x3000)
}

///|
fn md_is_punct(c : Char) -> Bool {
  (c.to_int() < 128 && @cmark_char.is_ascii_punctuation(c)) ||
  @cmark.is_punctuation(c)
}

///|
/// markdown-it `scanDelims(start, canSplitWord=True)` for a run of `count`
/// markers at `start`: (can_open, can_close).
fn scan_delims(src : String, start : Int, count : Int) -> (Bool, Bool) {
  let last = char_before(src, start)
  let next = char_at(src, start + count)
  let last_punct = md_is_punct(last)
  let next_punct = md_is_punct(next)
  let last_ws = md_is_whitespace(last)
  let next_ws = md_is_whitespace(next)
  let left = !(next_ws || (next_punct && !(last_ws || last_punct)))
  let right = !(last_ws || (last_punct && !(next_ws || next_punct)))
  (left, right)
}

///|
/// Emit a text node, splitting out `~` runs as strikethrough delimiters.
fn InlineConv::text(
  self : InlineConv,
  v : String,
  loc : @cmark_base.TextLoc,
  scope : Int,
) -> Unit {
  if !v.contains("~") || loc.is_none() {
    self.push_text(v)
    return
  }
  let src = self.src
  let last = loc.last_ccode
  let buf = StringBuilder()
  let mut r = loc.first_ccode
  let mut j = 0
  let vn = v.length()
  while r <= last && j < vn {
    let c = src[r]
    if c == '\\' &&
      r + 1 <= last &&
      src[r + 1].to_int() < 128 &&
      @cmark_char.is_ascii_punctuation(src[r + 1].to_int().unsafe_to_char()) &&
      v[j] == src[r + 1] {
      buf.write_char(src[r + 1].to_int().unsafe_to_char())
      r += 2
      j += 1
    } else if c == '~' && v[j] == '~' {
      let mut e = r
      while e <= last && src[e] == '~' {
        e += 1
      }
      let count = e - r
      if count < 2 {
        buf.write_char('~')
      } else {
        self.push_text(buf.to_string())
        buf.reset()
        let (can_open, can_close) = scan_delims(src, r, count)
        let mut len = count
        if len % 2 == 1 {
          self.push(Token::make("text", "", 0, content="~"))
          len -= 1
        }
        for _ in 0..<(len / 2) {
          self.push(Token::make("text", "", 0, content="~~"))
          self.scopes[scope].push({
            token: self.out.length() - 1,
            end: -1,
            open: can_open,
            close: can_close,
          })
        }
      }
      r = e
      j += count
    } else if c == '&' && self.entity_at(r, last) is Some((semi, decoded)) {
      // an entity: its decoded text is in `v`
      guard substr(v, j, end=@cmp.minimum(vn, j + decoded.length())) == decoded else {
        break
      }
      buf.write_string(decoded)
      r = semi + 1
      j += decoded.length()
    } else if c == v[j] {
      buf.write_char(c.to_int().unsafe_to_char())
      r += 1
      j += 1
    } else {
      break
    }
  }
  if j < vn {
    buf.write_string(substr(v, j))
  }
  self.push_text(buf.to_string())
}

///|
/// The entity reference starting at `src[r]` (`&...;`, ending at or before
/// `last`): the offset of its `;` and its decoded text.
fn InlineConv::entity_at(
  self : InlineConv,
  r : Int,
  last : Int,
) -> (Int, String)? {
  let src = self.src
  let mut semi = r + 1
  while semi <= last && semi - r <= 32 && src[semi] != ';' {
    semi += 1
  }
  guard semi <= last && src[semi] == ';' else { return None }
  let raw = substr(src, r, end=semi + 1)
  let decoded = @cmark_char.utf_16_clean_unref(
    StringBuilder(),
    src,
    first=r,
    last=semi,
  )
  if decoded == raw {
    None
  } else {
    Some((semi, decoded))
  }
}

///|
/// markdown-it `balance_pairs` (processDelimiters) for one scope; all
/// delimiters are `~~` with length 0.
fn process_delimiters(delimiters : Array[Delim]) -> Unit {
  let maximum = delimiters.length()
  let mut header_idx = 0
  let mut last_token_idx = -2
  let jumps : Array[Int] = []
  let openers_bottom = [-1, -1, -1, -1, -1, -1]
  let mut closer_idx = 0
  while closer_idx < maximum {
    let closer = delimiters[closer_idx]
    jumps.push(0)
    if last_token_idx != closer.token - 1 {
      header_idx = closer_idx
    }
    last_token_idx = closer.token
    if !closer.close {
      closer_idx += 1
      continue
    }
    let bottom_idx = if closer.open { 3 } else { 0 }
    let min_opener_idx = openers_bottom[bottom_idx]
    let mut opener_idx = header_idx - jumps[header_idx] - 1
    let mut new_min_opener_idx = opener_idx
    while opener_idx > min_opener_idx {
      let opener = delimiters[opener_idx]
      if opener.open && opener.end < 0 {
        // length 0: never an "odd match"
        let last_jump = if opener_idx > 0 && !delimiters[opener_idx - 1].open {
          jumps[opener_idx - 1] + 1
        } else {
          0
        }
        jumps[closer_idx] = closer_idx - opener_idx + last_jump
        jumps[opener_idx] = last_jump
        closer.open = false
        opener.end = closer_idx
        opener.close = false
        new_min_opener_idx = -1
        last_token_idx = -2
        break
      }
      opener_idx -= jumps[opener_idx] + 1
    }
    if new_min_opener_idx != -1 {
      openers_bottom[bottom_idx] = new_min_opener_idx
    }
    closer_idx += 1
  }
}

///|
/// markdown-it strikethrough `_postProcess` for one scope.
fn InlineConv::post_process(
  self : InlineConv,
  delimiters : Array[Delim],
) -> Unit {
  let lone_markers : Array[Int] = []
  for start_delim in delimiters {
    if start_delim.end == -1 {
      continue
    }
    let end_delim = delimiters[start_delim.end]
    self.out[start_delim.token] = Token::make("s_open", "s", 1)
    self.out[end_delim.token] = Token::make("s_close", "s", -1)
    let prev = self.out[end_delim.token - 1]
    if prev.type_ == "text" && prev.content == "~" {
      lone_markers.push(end_delim.token - 1)
    }
  }
  while lone_markers.pop() is Some(i) {
    let mut j = i + 1
    while j < self.out.length() && self.out[j].type_ == "s_close" {
      j += 1
    }
    j -= 1
    if i != j {
      let token = self.out[j]
      self.out[j] = self.out[i]
      self.out[i] = token
    }
  }
}

///|
/// Resolve strikethrough and merge adjacent text tokens.
fn InlineConv::finish(self : InlineConv) -> Array[Token] {
  for scope in self.scopes {
    process_delimiters(scope)
  }
  for scope in self.scopes {
    self.post_process(scope)
  }
  let result : Array[Token] = []
  for t in self.out {
    if t.type_ == "text" &&
      result.length() > 0 &&
      result[result.length() - 1].type_ == "text" {
      let prev = result[result.length() - 1]
      result[result.length() - 1] = {
        ..prev,
        content: prev.content + t.content,
      }
    } else {
      result.push(t)
    }
  }
  result
}

///|
/// Convert the inline content of a paragraph or heading.
fn Converter::inline_block(
  self : Converter,
  inline : @cmark.Inline,
  loc : @cmark_base.TextLoc,
) -> Unit {
  if inline.is_empty() {
    self.push(Token::make("inline", "", 0))
    return
  }
  let lines = self.inline_lines(inline, loc)
  if has_foreign_html(inline) || has_unicode_blank_edges(lines) {
    self.inline_text(self.lines_source(lines))
    return
  }
  let conv = InlineConv::new(
    self.src,
    self.defs,
    snippet=false,
    list_indent=self.list_indent,
  )
  conv.inline(inline, conv.new_scope())
  for t in conv.finish() {
    self.push(t)
  }
}

///|
/// markdown-it-py strips the inline source of a block with `str.strip()`,
/// which also removes the Unicode blanks (U+00A0, ...) that CommonMark
/// keeps as text: the source is then re-parsed stripped.
fn has_unicode_blank_edges(lines : Array[Line]) -> Bool {
  guard lines.length() > 0 else { return false }
  let first = lines[0].text
  // the blanks before a line break are not text
  let last = lines[lines.length() - 1].text.trim_end(chars=" \t")
  first.trim_start(chars=py_whitespace).length() != first.length() ||
  last.trim_end(chars=py_whitespace).length() != last.length()
}

///|
/// Whether `inline` holds raw HTML that markdown-it's pattern rejects
/// (markdown-it then finds HTML or autolinks inside it): the content is
/// then re-parsed after escape_unmatched_html.
fn has_foreign_html(inline : @cmark.Inline) -> Bool {
  match inline {
    Inlines(seq) => seq.v.iter().any(has_foreign_html)
    RawHtml(h) =>
      !regex_full_match(
        html_tag_re,
        h.v.0.iter().map(t => t.blanks + t.node.v).collect().join("\n"),
      )
    Emphasis(e) | StrongEmphasis(e) => has_foreign_html(e.v.inline)
    Link(l) | Image(l) => has_foreign_html(l.v.text)
    _ => false
  }
}

///|
/// The inline source of block `lines`, as markdown-it sees it: lines
/// joined with `\n`, keeping the indentation of continuation lines (only
/// known outside containers), stripped.
fn Converter::lines_source(self : Converter, lines : ArrayView[Line]) -> String {
  let top = self.quote_depth == 0 && self.list_depth == 0
  let parts = lines
    .iter()
    .mapi((k, l) => if top && k > 0 { l.lead + l.text } else { l.text })
    .collect()
  py_strip(parts.join("\n"))
}

///|
/// The lines of a multi-line inline (code span, raw HTML) as markdown-it
/// sees them: continuation lines keep their indentation beyond the
/// content column of an enclosing list item (snippet lines carry 4 extra
/// blanks).
fn InlineConv::layout_lines(
  self : InlineConv,
  layout : @cmark.Seq[@cmark.Tight],
) -> Array[String] {
  layout
  .to_array()
  .mapi((k, t) => {
    let loc = t.node.meta.loc
    let blanks = if k == 0 {
      ""
    } else if self.snippet {
      if t.blanks.length() >= 4 {
        substr(t.blanks, 4)
      } else {
        t.blanks
      }
    } else if self.list_indent >= 0 && !loc.is_none() {
      // cmark keeps the whole indentation of a lazy continuation line
      let mut start = loc.first_ccode
      while start > 0 && self.src[start - 1] != '\n' {
        start -= 1
      }
      let mut col = 0
      for i in start..<loc.first_ccode {
        col = if self.src[i] == '\t' { col + 4 - col % 4 } else { col + 1 }
      }
      " ".repeat(@cmp.maximum(0, col - self.list_indent))
    } else {
      t.blanks
    }
    blanks + t.node.v
  })
}

///|
/// markdown-it's code span content: line endings become spaces, keeping
/// the indentation of continuation lines; one surrounding space is
/// stripped from each side when both are present.
fn InlineConv::code_span(self : InlineConv, c : @cmark.InlineCodeSpan) -> Unit {
  let mut content = self.layout_lines(c.code_layout).join(" ")
  if content.length() >= 2 &&
    content.has_prefix(" ") &&
    content.has_suffix(" ") &&
    py_strip(content) != "" {
    content = substr(content, 1, end=content.length() - 1)
  }
  self.push(Token::make("code_inline", "code", 0, content~))
}

///|
/// Parse `content` (the inline source of a block, lines separated by
/// `\n`) and convert it. Empty content gives an empty `inline` token, as
/// markdown-it's flattening does.
fn Converter::inline_text(self : Converter, content : String) -> Unit {
  if content == "" {
    self.push(Token::make("inline", "", 0))
    return
  }
  // A dummy first line keeps the content a paragraph continuation, and the
  // indentation keeps its lines from starting blocks.
  let (escaped, escaped_lt) = escape_unmatched_html(content)
  let snippet = "x\n" +
    escaped.split("\n").map(l => "    " + l.to_owned()).join("\n")
  let doc = self.parse(snippet)
  let conv = InlineConv::new(snippet, self.defs, snippet=true)
  conv.escaped_lt = escaped_lt
  let scope = conv.new_scope()
  guard first_paragraph(doc.block) is Some(p) else {
    self.push(Token::make("text", "", 0, content~))
    return
  }
  let items = match p.inline {
    Inlines(seq) => seq.v.to_array()
    i => [i]
  }
  // drop the dummy "x" and the soft break after it
  for k, item in items {
    if k >= 2 {
      conv.inline(item, scope)
    }
  }
  for t in conv.finish() {
    self.push(t)
  }
}

///|
fn first_paragraph(block : @cmark.Block) -> @cmark.BlockParagraph? {
  match block {
    Paragraph(p) => Some(p.v)
    Blocks(seq) => {
      for b in seq.v.iter() {
        if first_paragraph(b) is Some(p) {
          return Some(p)
        }
      }
      None
    }
    _ => None
  }
}
