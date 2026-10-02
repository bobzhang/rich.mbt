// markdown-it block rules that differ from CommonMark: its table rule is
// tried before any other block rule, and a link reference definition is a
// block of its own. Where they apply, source lines are re-parsed as
// markdown-it would split them.

///|
/// Convert a sequence of sibling blocks.
fn Converter::blocks(self : Converter, blocks : Array[@cmark.Block]) -> Unit {
  for i, b in blocks {
    if self.list_depth == 0 && self.table_takes_over(blocks, i) {
      return
    }
    if self.list_depth == 0 && self.after_link_definition(blocks, i) {
      return
    }
    self.block(b)
  }
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
fn block_first_line(b : @cmark.Block) -> Int? {
  let loc = b.meta().loc
  if loc.is_none() {
    None
  } else {
    Some(loc.first_line.0)
  }
}

///|
fn block_last_line(b : @cmark.Block) -> Int {
  let loc = b.meta().loc
  if loc.is_none() {
    -1
  } else {
    loc.last_line.0
  }
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
    lines.push({ ..line, indent, })
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
      guard block_first_line(b) is Some(first) else { return false }
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
  self.split_tables(self.source_lines(first, last))
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
    block_first_line(next) is Some(first) &&
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
