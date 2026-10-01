// GFM tables, recovered from paragraph lines with markdown-it's rules
// (markdown_it/rules_block/table.py).

///|
/// A source line of a paragraph (or setext heading).
priv struct Line {
  /// 1-based line number in the converter's source.
  line : Int
  /// Text from the first non-blank character to the end of the line
  /// (trailing blanks kept, except on the last line of the block).
  text : String
  /// Indentation in columns relative to the block's first line (negative
  /// for lazy continuation lines).
  indent : Int
  /// No inline node starts on this line: cmark may have lost its content.
  recovered : Bool
  /// The blanks before `text` on the source line.
  lead : String
}

///|
fn Converter::column(self : Converter, line : Int, pos : Int) -> Int {
  let start = self.line_starts[line - 1]
  let mut col = 0
  for i in start..<pos {
    if self.src[i] == '\t' {
      col = col + 4 - col % 4
    } else {
      col += 1
    }
  }
  col
}

///|
fn Converter::make_line(
  self : Converter,
  line : Int,
  start : Int,
  end : Int,
) -> Line {
  let mut s = start
  while s < end && self.src[s] is (' ' | '\t') {
    s += 1
  }
  let line_start = self.line_starts[line - 1]
  let mut b = s
  while b > line_start && self.src[b - 1] is (' ' | '\t') {
    b -= 1
  }
  {
    line,
    text: substr(self.src, s, end~),
    indent: self.column(line, s),
    recovered: false,
    lead: substr(self.src, b, end=s),
  }
}

///|
fn record_candidate(
  cands : Map[Int, Int],
  loc : @cmark_base.TextLoc,
  first? : Int,
) -> Unit {
  if loc.is_none() {
    return
  }
  let line = loc.first_line.0
  let pos = match first {
    Some(f) => f
    None => loc.first_ccode
  }
  match cands.get(line) {
    Some(p) if p <= pos => ()
    _ => cands[line] = pos
  }
}

///|
fn collect_line_starts(inline : @cmark.Inline, cands : Map[Int, Int]) -> Unit {
  record_candidate(cands, inline.meta().loc)
  match inline {
    Inlines(seq) =>
      for i in seq.v.iter() {
        collect_line_starts(i, cands)
      }
    Break(b) => {
      let after = b.v.layout_after.meta.loc
      if !after.is_none() {
        record_candidate(cands, after, first=after.last_ccode + 1)
      }
    }
    CodeSpan(cs) =>
      for t in cs.v.code_layout.iter() {
        record_candidate(cands, t.node.meta.loc)
      }
    RawHtml(h) =>
      for t in h.v.0.iter() {
        record_candidate(cands, t.node.meta.loc)
      }
    Emphasis(e) | StrongEmphasis(e) => collect_line_starts(e.v.inline, cands)
    ExtStrikethrough(s) => collect_line_starts(s.v.0, cands)
    Link(l) | Image(l) => {
      collect_line_starts(l.v.text, cands)
      if l.v.reference is Inline(def) {
        if def.v.dest is Some(d) {
          record_candidate(cands, d.meta.loc)
        }
        if def.v.title is Some(title) {
          for t in title.iter() {
            record_candidate(cands, t.node.meta.loc)
          }
        }
      }
    }
    _ => ()
  }
}

///|
/// The source lines of a block's inline content.
fn Converter::inline_lines(
  self : Converter,
  inline : @cmark.Inline,
  block_loc : @cmark_base.TextLoc,
) -> Array[Line] {
  let loc = if inline.meta().loc.is_none() {
    block_loc
  } else {
    inline.meta().loc
  }
  if loc.is_none() {
    return []
  }
  let cands : Map[Int, Int] = Map([])
  collect_line_starts(inline, cands)
  let first = loc.first_line.0
  let last = loc.last_line.0
  let lines : Array[Line] = []
  let mut base = 0
  for l in first..<=last {
    guard l - 1 < self.line_starts.length() else { break }
    let (start, recovered) = match cands.get(l) {
      Some(p) => (p, false)
      None => (self.content_start(l), true)
    }
    let end = if l == last && !recovered {
      loc.last_ccode + 1
    } else {
      self.line_end(start)
    }
    let line = self.make_line(l, start, @cmp.maximum(start, end))
    if l == first {
      base = line.indent
    }
    lines.push({ ..line, indent: line.indent - base, recovered, })
  }
  lines
}

///|
fn is_str_space(c : UInt16) -> Bool {
  c is (' ' | '\t')
}

///|
/// markdown-it `escapedSplit`.
fn escaped_split(s : String) -> Array[String] {
  let result : Array[String] = []
  let mut pos = 0
  let max = s.length()
  let mut is_escaped = false
  let mut last_pos = 0
  let mut current = StringBuilder()
  while pos < max {
    let ch = s[pos]
    if ch == '|' {
      if !is_escaped {
        current.write_string(substr(s, last_pos, end=pos))
        result.push(current.to_string())
        current = StringBuilder()
        last_pos = pos + 1
      } else {
        current.write_string(substr(s, last_pos, end=pos - 1))
        last_pos = pos
      }
    }
    is_escaped = ch == '\\'
    pos += 1
  }
  current.write_string(substr(s, last_pos))
  result.push(current.to_string())
  result
}

///|
fn split_cells(text : String) -> Array[String] {
  let columns = escaped_split(text)
  if columns.length() > 0 && columns[0] == "" {
    columns.remove(0) |> ignore
  }
  if columns.length() > 0 && columns[columns.length() - 1] == "" {
    columns.pop() |> ignore
  }
  columns
}

///|
/// `^:?-+:?$`
fn is_header_cell(t : String) -> Bool {
  let n = t.length()
  let mut i = 0
  if i < n && t[i] == ':' {
    i += 1
  }
  let dash_start = i
  while i < n && t[i] == '-' {
    i += 1
  }
  if i == dash_start {
    return false
  }
  if i < n && t[i] == ':' {
    i += 1
  }
  i == n
}

///|
/// Column alignments of a delimiter row, or `None` if `line` is not one.
fn delimiter_row(line : Line) -> Array[String]? {
  if line.indent < 0 || line.indent >= 4 {
    return None
  }
  let s = line.text
  let n = s.length()
  if n < 2 {
    return None
  }
  let first = s[0]
  if !(first is ('|' | '-' | ':')) {
    return None
  }
  let second = s[1]
  if !(second is ('|' | '-' | ':')) && !is_str_space(second) {
    return None
  }
  if first == '-' && is_str_space(second) {
    return None
  }
  for i in 2..<n {
    let ch = s[i]
    if !(ch is ('|' | '-' | ':')) && !is_str_space(ch) {
      return None
    }
  }
  let columns = s.split("|").map(v => v.to_owned()).to_array()
  let aligns : Array[String] = []
  for i, c in columns {
    let t = py_strip(c)
    if t == "" {
      if i == 0 || i == columns.length() - 1 {
        continue
      }
      return None
    }
    if !is_header_cell(t) {
      return None
    }
    if t[t.length() - 1] == ':' {
      aligns.push(if t[0] == ':' { "center" } else { "right" })
    } else if t[0] == ':' {
      aligns.push("left")
    } else {
      aligns.push("")
    }
  }
  Some(aligns)
}

///|
/// If a table starts at `lines[i]`: its header cells and alignments.
fn table_start(lines : Array[Line], i : Int) -> (Array[String], Array[String])? {
  guard i + 1 < lines.length() else { None }
  guard lines[i].indent >= 0 && lines[i].indent < 4 else { None }
  guard delimiter_row(lines[i + 1]) is Some(aligns) else { None }
  let header = py_strip(lines[i].text)
  guard header.contains("|") else { None }
  let columns = split_cells(header)
  guard columns.length() > 0 && columns.length() == aligns.length() else {
    None
  }
  Some((columns, aligns))
}

///|
/// markdown-it block rules that terminate a table body (the "blockquote"
/// terminator list: fence, blockquote, hr, list, html_block, heading).
fn terminates_table(line : Line) -> Bool {
  if line.indent >= 4 {
    return false
  }
  let s = line.text
  let n = s.length()
  if n == 0 {
    return false
  }
  let c = s[0]
  // fence
  if c is ('`' | '~') {
    let mut i = 0
    while i < n && s[i] == c {
      i += 1
    }
    if i >= 3 && !(c == '`' && substr(s, i).contains("`")) {
      return true
    }
  }
  // blockquote
  if c == '>' {
    return true
  }
  // hr
  if c is ('*' | '-' | '_') {
    let mut cnt = 0
    let mut ok = true
    for i in 0..<n {
      let ch = s[i]
      if ch == c {
        cnt += 1
      } else if !is_str_space(ch) {
        ok = false
        break
      }
    }
    if ok && cnt >= 3 {
      return true
    }
  }
  // bullet list
  if c is ('*' | '-' | '+') && (n == 1 || is_str_space(s[1])) {
    return true
  }
  // ordered list
  if c is ('0'..='9') && n >= 2 {
    let mut i = 1
    while i < n && s[i] is ('0'..='9') && i < 10 {
      i += 1
    }
    if i < 10 && i < n && s[i] is ('.' | ')') {
      if i + 1 >= n || is_str_space(s[i + 1]) {
        return true
      }
    }
  }
  // html block (types 1-6 can terminate)
  if c == '<' {
    match @cmark_base.LineType::html_block_start(s, last=n - 1, start=0) {
      HtmlBlockLine(EndBlank7) => ()
      HtmlBlockLine(_) => return true
      _ => ()
    }
  }
  // heading
  if c == '#' {
    let mut level = 1
    let mut i = 1
    while i < n && s[i] == '#' && level <= 6 {
      level += 1
      i += 1
    }
    if level <= 6 && (i >= n || is_str_space(s[i])) {
      return true
    }
  }
  false
}

///|
let max_autocompleted_cells : Int = 0x10000

///|
/// Split block `lines` into paragraph / table / remaining blocks as
/// markdown-it would. Returns `false` (emitting nothing) when the lines
/// hold no table.
fn Converter::split_tables(self : Converter, lines : Array[Line]) -> Bool {
  guard lines.iter().any(l => l.text.contains("|")) else { return false }
  let n = lines.length()
  let mut found = None
  for i in 0..<(n - 1) {
    if table_start(lines, i) is Some(t) {
      found = Some((i, t))
      break
    }
  }
  guard found is Some((start, (header, aligns))) else { return false }
  if start > 0 {
    self.push(Token::make("paragraph_open", "p", 1))
    self.inline_text(self.lines_source(lines[:start]))
    self.push(Token::make("paragraph_close", "p", -1))
  }
  let column_count = header.length()
  fn cell_attrs(i : Int) -> Map[String, String] {
    if aligns[i] != "" {
      { "style": "text-align:" + aligns[i] }
    } else {
      {}
    }
  }

  self.push(Token::make("table_open", "table", 1))
  self.push(Token::make("thead_open", "thead", 1))
  self.push(Token::make("tr_open", "tr", 1))
  for i in 0..<column_count {
    self.push(Token::make("th_open", "th", 1, attrs=cell_attrs(i)))
    self.inline_text(py_strip(header[i]))
    self.push(Token::make("th_close", "th", -1))
  }
  self.push(Token::make("tr_close", "tr", -1))
  self.push(Token::make("thead_close", "thead", -1))
  let mut next = start + 2
  let mut autocompleted = 0
  while next < n {
    let line = lines[next]
    if line.indent < 0 || terminates_table(line) {
      break
    }
    let text = py_strip(line.text)
    if text == "" || line.indent >= 4 {
      break
    }
    let columns = split_cells(text)
    autocompleted += column_count - columns.length()
    if autocompleted > max_autocompleted_cells {
      break
    }
    if next == start + 2 {
      self.push(Token::make("tbody_open", "tbody", 1))
    }
    self.push(Token::make("tr_open", "tr", 1))
    for i in 0..<column_count {
      self.push(Token::make("td_open", "td", 1, attrs=cell_attrs(i)))
      let content = if i < columns.length() { py_strip(columns[i]) } else { "" }
      self.inline_text(content)
      self.push(Token::make("td_close", "td", -1))
    }
    self.push(Token::make("tr_close", "tr", -1))
    next += 1
  }
  if next > start + 2 {
    self.push(Token::make("tbody_close", "tbody", -1))
  }
  self.push(Token::make("table_close", "table", -1))
  if next < n {
    // markdown-it starts new blocks at the line that ended the table.
    self.reparse_lines(lines[next:])
  }
  true
}

///|
/// Parse `lines` as a fresh sequence of blocks.
fn Converter::reparse_lines(self : Converter, lines : ArrayView[Line]) -> Unit {
  let rest = lines
    .iter()
    .map(l => " ".repeat(@cmp.maximum(l.indent, 0)) + l.text)
    .collect()
    .join("\n")
  let doc = self.parse(rest)
  let sub = Converter::new(rest, self.defs, self.labels, self.out)
  sub.document(doc.block)
}
