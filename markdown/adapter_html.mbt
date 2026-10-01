// markdown-it's raw HTML and autolink patterns (common/html_re.py,
// rules_inline/autolink.py), used to reject constructs cmark accepts but
// markdown-it does not.

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
  if self.joined_html.get(content) is Some(original) {
    self.push(Token::make("html_inline", "", 0, content=original))
    return
  }
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
