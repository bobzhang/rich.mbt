// markdown-it's raw HTML and autolink patterns (common/html_re.py,
// rules_inline/autolink.py). Its HTML comment pattern is stricter than
// CommonMark 0.31's (`<!-- a --->` is not a comment, and `<!--->` does
// not end one), so raw HTML cmark accepts is checked against it.

///|
let html_tag_pattern : String =
  #|^(?:<[A-Za-z][A-Za-z0-9\-]*(?:\s+[a-zA-Z_:][a-zA-Z0-9:._-]*(?:\s*=\s*(?:[^"'=<>`\x00-\x20]+|'[^']*'|"[^"]*"))?)*\s*\/?>|<\/[A-Za-z][A-Za-z0-9\-]*\s*>|<!---?>|<!--(?:[^-]|-[^-]|--[^>])*-->|<[?][\s\S]*?[?]>|<![A-Za-z][^>]*>|<!\[CDATA\[[\s\S]*?\]\]>)

///|
let autolink_pattern : String =
  #|^([a-zA-Z][a-zA-Z0-9+.\-]{1,31}):([^<>\x00-\x20]*)$

///|
let email_pattern : String =
  #|^([a-zA-Z0-9.!#$%&\'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*)$

///|
let html_tag_re : @regex.Regex? = compile_opt(html_tag_pattern)

///|
let autolink_re : @regex.Regex? = compile_opt(autolink_pattern)

///|
let email_re : @regex.Regex? = compile_opt(email_pattern)

///|
fn compile_opt(pattern : String) -> @regex.Regex? {
  try @regex.compile(pattern) catch {
    _ => None
  } noraise {
    re => Some(re)
  }
}

///|
/// End of the match of `re` at the start of `s` (0 when none).
fn match_length(re : @regex.Regex, s : String) -> Int {
  try re.match_at(s, 0) catch {
    _ => 0
  } noraise {
    Some(m) => m.end()
    None => 0
  }
}

///|
fn regex_full_match(re : @regex.Regex?, s : String) -> Bool {
  guard re is Some(re) else { return true }
  s != "" && match_length(re, s) == s.length()
}

///|
/// Emit raw inline HTML as markdown-it would tokenize it: an
/// `html_inline` token for the part matching its tag pattern, text for
/// the rest.
fn InlineConv::raw_html(self : InlineConv, content : String) -> Unit {
  let matched = match html_tag_re {
    None => content.length()
    Some(re) => match_length(re, content)
  }
  if matched > 0 {
    self.push(
      Token::make("html_inline", "", 0, content=substr(content, 0, end=matched)),
    )
  }
  let rest = substr(content, matched)
  for i, line in rest.split("\n").to_array() {
    if i > 0 {
      self.push(Token::make("softbreak", "br", 0))
    }
    let text = if i > 0 {
      line.trim_start(chars=" \t").to_owned()
    } else {
      line.to_owned()
    }
    self.push_text(text)
  }
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
/// markdown-it's HTML comment pattern is stricter than CommonMark 0.31's
/// (`<!-- a --->` is not a comment for it), and where it rejects raw HTML
/// it goes on to find HTML or autolinks inside it. Escape each `<`
/// (outside code spans) at which markdown-it finds neither raw HTML nor an
/// autolink, so that cmark reads the inline `content` as markdown-it does.
/// Returns the escaped content and whether anything was escaped.
fn escape_unmatched_html(content : String) -> (String, Bool) {
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
      let html_len = match html_tag_re {
        Some(re) => match_length(re, substr(content, i))
        None => 0
      }
      if html_len > 0 {
        sb.write_string(substr(content, i, end=i + html_len))
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
