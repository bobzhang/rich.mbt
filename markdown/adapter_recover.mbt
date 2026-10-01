// Work-around for a cmark bug: when an inline raw HTML candidate (`<a`,
// `<!--`, ...) continues past the end of a line and then fails to match,
// cmark drops the rest of the paragraph (its line iterator is consumed
// and not restored). The lost lines are found as source lines not covered
// by any leaf block; the paragraph is then re-parsed from its lines with
// the offending `<` escaped (markdown-it treats them as text anyway).

///|
fn Converter::mark_range(self : Converter, loc : @cmark_base.TextLoc) -> Unit {
  if loc.is_none() {
    return
  }
  for l in loc.first_line.0..<=loc.last_line.0 {
    if l >= 0 && l < self.covered.length() {
      self.covered[l] = true
    }
  }
}

///|
fn Converter::mark_covered(self : Converter, block : @cmark.Block) -> Unit {
  match block {
    Blocks(seq) =>
      for b in seq.v.iter() {
        self.mark_covered(b)
      }
    BlockQuote(q) => self.mark_covered(q.v.block)
    List(l) =>
      for item in l.v.items.iter() {
        let loc = item.meta.loc
        if !loc.is_none() {
          let first = loc.first_line.0
          if first >= 0 && first < self.covered.length() {
            self.covered[first] = true
          }
        }
        self.mark_covered(item.v.block)
      }
    // the paragraph's own location may include the lost lines
    Paragraph(p) if !p.v.inline.meta().loc.is_none() =>
      self.mark_range(p.v.inline.meta().loc)
    HtmlBlock(h) => {
      // the block's own location may miss its first lines
      self.mark_range(h.meta.loc)
      for line in h.v.0.iter() {
        self.mark_range(line.meta.loc)
      }
    }
    b => self.mark_range(b.meta().loc)
  }
}

///|
/// Source lines lost by cmark after the paragraph `lines`.
fn Converter::lost_lines_after(
  self : Converter,
  lines : Array[Line],
) -> Array[Line] {
  guard lines.last() is Some(last) && last.text.contains("<") else { return [] }
  let result : Array[Line] = []
  let mut l = last.line + 1
  while l <= self.line_starts.length() && l < self.covered.length() {
    if self.covered[l] {
      break
    }
    let pos = self.content_start(l)
    let end = self.line_end(pos)
    if pos >= end {
      break
    }
    result.push({
      line: l,
      text: substr(self.src, pos, end~),
      indent: 0,
      recovered: true,
    })
    l += 1
  }
  result
}

///|
/// Start of the content of source line `l`: after blanks and the block
/// quote markers of the enclosing quotes.
fn Converter::content_start(self : Converter, l : Int) -> Int {
  let start = self.line_starts[l - 1]
  let end = self.line_end(start)
  let mut pos = start
  while pos < end && self.src[pos] is (' ' | '\t') {
    pos += 1
  }
  for _ in 0..<self.quote_depth {
    if pos < end && self.src[pos] == '>' {
      pos += 1
      while pos < end && self.src[pos] is (' ' | '\t') {
        pos += 1
      }
    }
  }
  pos
}

///|
/// markdown-it's autolink rule at `content[i] == '<'`: whether a valid
/// autolink starts there.
fn autolink_at(content : String, i : Int) -> Bool {
  let n = content.length()
  let mut pos = i + 1
  while pos < n {
    let c = content[pos]
    if c == '<' {
      return false
    }
    if c == '>' {
      break
    }
    pos += 1
  }
  if pos >= n {
    return false
  }
  let url = substr(content, i + 1, end=pos)
  regex_full_match(autolink_re, url) || regex_full_match(email_re, url)
}

///|
/// Escape each `<` (outside code spans) at which markdown-it finds neither
/// raw HTML nor an autolink, so that cmark does not try (and fail) to
/// parse raw HTML there. Raw HTML spanning lines is joined into one line,
/// recording the original text in `joined_html`.
fn escape_unmatched_html(
  content : String,
  joined_html : Map[String, String],
) -> (String, Bool) {
  guard content.contains("<") else { return (content, false) }
  let sb = StringBuilder()
  let n = content.length()
  let mut changed = false
  let mut i = 0
  while i < n {
    let c = content[i]
    if c == '\\' && i + 1 < n {
      sb.write_string(substr(content, i, end=i + 2))
      i += 2
      continue
    }
    if c == '`' {
      // a code span: skip to the matching backtick run
      let mut j = i
      while j < n && content[j] == '`' {
        j += 1
      }
      let run = j - i
      let mut k = j
      let mut close = -1
      while k < n {
        if content[k] == '`' {
          let mut e = k
          while e < n && content[e] == '`' {
            e += 1
          }
          if e - k == run {
            close = e
            break
          }
          k = e
        } else {
          k += 1
        }
      }
      let end = if close < 0 { j } else { close }
      sb.write_string(substr(content, i, end~))
      i = end
      continue
    }
    if c == '<' {
      let rest = substr(content, i)
      let html_len = match html_tag_re {
        Some(re) => match_length(re, rest)
        None => 0
      }
      if html_len > 0 {
        // cmark fails on some raw HTML spanning lines (and then drops
        // the rest of the paragraph): keep such HTML on one line.
        let html = substr(content, i, end=i + html_len)
        if html.contains("\n") {
          let joined = html.replace_all(old="\n", new=" ")
          joined_html[joined] = html
          sb.write_string(joined)
        } else {
          sb.write_string(html)
        }
        i += html_len
        continue
      }
      if !autolink_at(content, i) {
        sb.write_char('\\')
        changed = true
      }
    }
    sb.write_char(c.to_int().unsafe_to_char())
    i += 1
  }
  (sb.to_string(), changed)
}

///|
/// Convert a sequence of sibling blocks.
///
/// Works around a cmark bug: a lazy continuation line of a paragraph in a
/// list item that starts with a complete HTML tag (an HTML block of type
/// 7, which cannot interrupt a paragraph) is parsed as an HTML block after
/// the list (or the block quote holding it). Its lines are appended to the
/// paragraph instead.
fn Converter::blocks(self : Converter, blocks : Array[@cmark.Block]) -> Unit {
  let mut skip = -1
  for i, b in blocks {
    if i == skip {
      continue
    }
    if self.list_depth == 0 && self.table_takes_over(blocks, i) {
      return
    }
    if self.list_depth == 0 && self.after_link_definition(blocks, i) {
      return
    }
    if b is (List(_) | BlockQuote(_)) &&
      blocks.get(i + 1) is Some(HtmlBlock(h)) &&
      self.lazy_html_lines(b.meta().loc, h.v.0) is Some((lines, rest)) {
      self.lazy_lines = lines
      self.lazy_after = lines[0].line - 1
      self.block(b)
      // a paragraph took the lazy lines: skip the HTML block, and parse
      // the lines after the first one interrupting the paragraph
      let consumed = self.lazy_after == -1
      self.lazy_lines = []
      self.lazy_after = -1
      if consumed {
        skip = i + 1
        if rest.length() > 0 {
          self.reparse_lines(rest)
        }
      }
      continue
    }
    self.block(b)
  }
}

///|
/// The lines of an HTML block that directly follows a list (or quote)
/// ending on the previous line, when they are lazy paragraph continuation
/// lines: (the lazy lines, the lines from the first one that interrupts a
/// paragraph).
fn Converter::lazy_html_lines(
  self : Converter,
  container_loc : @cmark_base.TextLoc,
  html : @cmark.Seq[@cmark.Node[String]],
) -> (Array[Line], Array[Line])? {
  guard !container_loc.is_none() && html.length() > 0 else { return None }
  let first = html[0].meta.loc
  guard !first.is_none() && first.first_line.0 == container_loc.last_line.0 + 1 else {
    return None
  }
  // only HTML blocks of type 7 (which cannot interrupt a paragraph)
  let text = html[0].v.trim_start(chars=" \t").to_owned()
  match
    @cmark_base.LineType::html_block_start(
      text,
      last=text.length() - 1,
      start=0,
    ) {
    HtmlBlockLine(EndBlank7) => ()
    _ => return None
  }
  let last_node = html[html.length() - 1].meta.loc
  guard !last_node.is_none() else { return None }
  let all = self.source_lines(first.first_line.0, last_node.last_line.0)
  let mut k = 1
  while k < all.length() && !interrupts_paragraph(all[k]) {
    k += 1
  }
  Some((all[:k].to_owned(), all[k:].to_owned()))
}

///|
/// A list marker at the start of `s`: (ordered, number, empty item).
fn list_marker(s : String) -> (Bool, Int, Bool)? {
  let n = s.length()
  guard n > 0 else { return None }
  if s[0] is ('*' | '-' | '+') {
    guard n == 1 || is_str_space(s[1]) else { return None }
    return Some((false, 0, py_strip(substr(s, 1)) == ""))
  }
  let mut i = 0
  let mut number = 0
  while i < n && i < 9 && s[i] is ('0'..='9') {
    number = number * 10 + (s[i].to_int() - '0'.to_int())
    i += 1
  }
  guard i > 0 && i < n && s[i] is ('.' | ')') else { return None }
  guard i + 1 == n || is_str_space(s[i + 1]) else { return None }
  Some((true, number, py_strip(substr(s, i + 1)) == ""))
}

///|
/// Whether `line` starts a block that interrupts a paragraph.
fn interrupts_paragraph(line : Line) -> Bool {
  if line.indent >= 4 {
    return false
  }
  if list_marker(line.text) is Some((ordered, number, empty)) {
    return !empty && (!ordered || number == 1)
  }
  terminates_table(line)
}

///|
fn Converter::first_line(self : Converter, b : @cmark.Block) -> Int? {
  ignore(self)
  match b {
    HtmlBlock(h) =>
      match h.v.0.get(0) {
        Some(n) if !n.meta.loc.is_none() => Some(n.meta.loc.first_line.0)
        _ => None
      }
    b => {
      let loc = b.meta().loc
      if loc.is_none() {
        None
      } else {
        Some(loc.first_line.0)
      }
    }
  }
}

///|
fn block_last_line(b : @cmark.Block) -> Int {
  let loc = b.meta().loc
  let mut last = if loc.is_none() { -1 } else { loc.last_line.0 }
  if b is Paragraph(p) {
    let l = p.v.inline.meta().loc
    if !l.is_none() && l.last_line.0 > last {
      last = l.last_line.0
    }
  }
  last
}

///|
/// The source lines `first..=last`, with the markers of the enclosing block
/// quotes removed; indentation is relative to the quote content.
fn Converter::source_lines(
  self : Converter,
  first : Int,
  last : Int,
) -> Array[Line] {
  let lines : Array[Line] = []
  for l in first..<=last {
    guard l >= 1 && l - 1 < self.line_starts.length() else { break }
    let start = self.line_starts[l - 1]
    let end = self.line_end(start)
    let mut marker_end = start
    for _ in 0..<self.quote_depth {
      let mut pos = marker_end
      while pos < end && pos - marker_end < 3 && self.src[pos] == ' ' {
        pos += 1
      }
      guard pos < end && self.src[pos] == '>' else { break }
      pos += 1
      if pos < end && self.src[pos] is (' ' | '\t') {
        pos += 1
      }
      marker_end = pos
    }
    let line = self.make_line(l, marker_end, end)
    let indent = line.indent - self.column(l, marker_end)
    lines.push({ ..line, indent, recovered: true, })
  }
  lines
}

///|
/// markdown-it tries its table rule before any other block rule: when a
/// block cmark parsed (a list, heading, quote, ...) starts with a table
/// header and delimiter row, or a setext heading holds a table, the table
/// (and its body rows, which may extend over the following blocks) wins.
/// The lines from that block to the end of the container are then
/// re-parsed from the table on. Returns whether that happened.
fn Converter::table_takes_over(
  self : Converter,
  blocks : Array[@cmark.Block],
  i : Int,
) -> Bool {
  let b = blocks[i]
  let first = match b {
    BlankLine(_) | Paragraph(_) | LinkRefDefinition(_) | Blocks(_) =>
      return false
    Heading(h) if h.v.layout is Setext(_) => {
      guard self.setext_lines(h) is Some(lines) &&
        lines.iter().any(l => l.text.contains("|")) else {
        return false
      }
      let mut found = false
      for k in 0..<(lines.length() - 1) {
        if table_start(lines, k) is Some(_) {
          found = true
          break
        }
      }
      guard found else { return false }
      lines[0].line
    }
    _ => {
      guard self.first_line(b) is Some(first) else { return false }
      let pair = self.source_lines(first, first + 1)
      guard pair.length() == 2 && table_start(pair, 0) is Some(_) else {
        return false
      }
      first
    }
  }
  let mut last = first
  for b in blocks[i:] {
    last = @cmp.maximum(last, block_last_line(b))
  }
  self.split_tables(self.source_lines(first, last), b.meta().loc)
}

///|
/// markdown-it parses a link reference definition as a block of its own:
/// the following lines start new blocks, while CommonMark keeps them in the
/// paragraph the definition started (where e.g. indented code or a list
/// starting at 2 cannot interrupt it). Re-parse those lines as blocks.
fn Converter::after_link_definition(
  self : Converter,
  blocks : Array[@cmark.Block],
  i : Int,
) -> Bool {
  guard blocks[i] is LinkRefDefinition(def) &&
    blocks.get(i + 1) is Some(next) &&
    next is (Paragraph(_) | Heading(_)) else {
    return false
  }
  let def_loc = def.meta.loc
  guard !def_loc.is_none() &&
    self.first_line(next) is Some(first) &&
    first == def_loc.last_line.0 + 1 else {
    return false
  }
  let mut last = first
  for b in blocks[i + 1:] {
    last = @cmp.maximum(last, block_last_line(b))
  }
  self.reparse_lines(self.source_lines(first, last))
  true
}
