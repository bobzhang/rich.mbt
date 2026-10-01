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
