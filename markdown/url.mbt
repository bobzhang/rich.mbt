// URL normalization as done by markdown-it-py (`normalizeLink`,
// `normalizeLinkText`, `validateLink`), with ports of the `mdurl`
// helpers (`parse`, `format`, `encode`, `decode`) and the punycode codec
// it relies on.

///|
priv struct MdUrl {
  mut protocol : String
  mut slashes : Bool
  mut auth : String
  mut port : String
  mut hostname : String
  mut hash : String
  mut search : String
  mut pathname : String
}

///|
fn is_ascii_alnum(c : Char) -> Bool {
  c is ('a'..='z' | 'A'..='Z' | '0'..='9')
}

///|
fn is_hex_digit(c : Char) -> Bool {
  c is ('a'..='f' | 'A'..='F' | '0'..='9')
}

///|
fn hex_value(c : Char) -> Int {
  match c {
    '0'..='9' => c.to_int() - '0'.to_int()
    'a'..='f' => c.to_int() - 'a'.to_int() + 10
    'A'..='F' => c.to_int() - 'A'.to_int() + 10
    _ => 0
  }
}

///|
/// Python `str.strip()` (Unicode whitespace).
fn py_strip(s : String) -> String {
  s.trim(chars=py_whitespace).to_owned()
}

///|
let py_whitespace : String = " \t\n\r\u{0b}\u{0c}\u{1c}\u{1d}\u{1e}\u{1f}\u{85}\u{a0}\u{1680}\u{2000}\u{2001}\u{2002}\u{2003}\u{2004}\u{2005}\u{2006}\u{2007}\u{2008}\u{2009}\u{200a}\u{2028}\u{2029}\u{202f}\u{205f}\u{3000}"

///|
fn find_from(s : String, needle : Char, start : Int) -> Int {
  for i in start..<s.length() {
    if s[i] == needle.to_int().to_uint16() {
      return i
    }
  }
  -1
}

///|
fn rfind_before(s : String, needle : Char, end : Int) -> Int {
  let mut i = @cmp.minimum(end, s.length()) - 1
  while i >= 0 {
    if s[i] == needle.to_int().to_uint16() {
      return i
    }
    i -= 1
  }
  -1
}

///|
fn substr(s : String, start : Int, end? : Int) -> String {
  let end = match end {
    Some(e) => e
    None => s.length()
  }
  if start >= end {
    return ""
  }
  s.view(start_offset=start, end_offset=end).to_owned()
}

///|
fn is_hostname_part_char(c : Char) -> Bool {
  c is ('+' | 'a'..='z' | '0'..='9' | 'A'..='Z' | '_' | '-')
}

///|
fn is_hostname_part(s : String) -> Bool {
  let mut n = 0
  for c in s {
    if !is_hostname_part_char(c) {
      return false
    }
    n += 1
  }
  n <= 63
}

///|
let non_host_chars : Array[Char] = [
  '%', '/', '?', ';', '#', '\'', '{', '}', '|', '\\', '^', '`', '<', '>', '"', '`',
  ' ', '\r', '\n', '\t',
]

///|
fn is_slashed_protocol(p : String) -> Bool {
  p
  is ("http"
  | "https"
  | "ftp"
  | "gopher"
  | "file"
  | "http:"
  | "https:"
  | "ftp:"
  | "gopher:"
  | "file:")
}

///|
fn is_hostless_protocol(p : String) -> Bool {
  p is ("javascript" | "javascript:")
}

///|
/// `mdurl.parse(url, slashes_denote_host=True)`.
fn MdUrl::parse(url : String) -> MdUrl {
  let u : MdUrl = {
    protocol: "",
    slashes: false,
    auth: "",
    port: "",
    hostname: "",
    hash: "",
    search: "",
    pathname: "",
  }
  let mut rest = py_strip(url)
  // protocol: ^([a-z0-9.+-]+:)
  let mut proto = ""
  let mut lower_proto = ""
  let mut i = 0
  while i < rest.length() {
    let c = rest[i]
    if c is ('a'..='z' | 'A'..='Z' | '0'..='9' | '.' | '+' | '-') {
      i += 1
    } else {
      break
    }
  }
  if i > 0 && i < rest.length() && rest[i] == ':' {
    proto = substr(rest, 0, end=i + 1)
    lower_proto = proto.to_lower()
    u.protocol = proto
    rest = substr(rest, i + 1)
  }
  let slashes = rest.has_prefix("//")
  if slashes && !(proto != "" && is_hostless_protocol(proto)) {
    rest = substr(rest, 2)
    u.slashes = true
  }
  if !is_hostless_protocol(proto) &&
    (slashes || (proto != "" && !is_slashed_protocol(proto))) {
    let mut host_end = -1
    for hec_char in ['/', '?', '#'] {
      let hec = find_from(rest, hec_char, 0)
      if hec != -1 && (host_end == -1 || hec < host_end) {
        host_end = hec
      }
    }
    let at_sign = if host_end == -1 {
      rfind_before(rest, '@', rest.length())
    } else {
      rfind_before(rest, '@', host_end + 1)
    }
    if at_sign != -1 {
      u.auth = substr(rest, 0, end=at_sign)
      rest = substr(rest, at_sign + 1)
    }
    host_end = -1
    for hec_char in non_host_chars {
      let hec = find_from(rest, hec_char, 0)
      if hec != -1 && (host_end == -1 || hec < host_end) {
        host_end = hec
      }
    }
    if host_end == -1 {
      host_end = rest.length()
    }
    if host_end > 0 && rest[host_end - 1] == ':' {
      host_end -= 1
    }
    let host = substr(rest, 0, end=host_end)
    rest = substr(rest, host_end)
    u.parse_host(host)
    let ipv6_hostname = u.hostname.has_prefix("[") && u.hostname.has_suffix("]")
    if !ipv6_hostname {
      let hostparts = u.hostname.split(".").map(v => v.to_owned()).to_array()
      let l = hostparts.length()
      for j in 0..<l {
        let part = hostparts[j]
        if part == "" {
          continue
        }
        if !is_hostname_part(part) {
          let newpart = StringBuilder()
          for c in part {
            newpart.write_char(if c.to_int() > 127 { 'x' } else { c })
          }
          if !is_hostname_part(newpart.to_string()) {
            let valid_parts = hostparts[:j].to_owned()
            let not_host = hostparts[j + 1:].to_owned()
            // ^([+a-z0-9A-Z_-]{0,63})(.*)$
            let mut k = 0
            let mut n = 0
            while k < part.length() && n < 63 {
              guard part.get_char(k) is Some(c) && is_hostname_part_char(c) else {
                break
              }
              k += 1
              n += 1
            }
            let tail = substr(part, k)
            if !tail.contains("\n") {
              valid_parts.push(substr(part, 0, end=k))
              not_host.insert(0, tail)
            }
            if not_host.length() > 0 {
              rest = not_host.join(".") + rest
            }
            u.hostname = valid_parts.join(".")
            break
          }
        }
      }
    }
    if u.hostname.length() > 255 {
      u.hostname = ""
    }
    if ipv6_hostname {
      u.hostname = substr(u.hostname, 1, end=u.hostname.length() - 1)
    }
  }
  let hash = find_from(rest, '#', 0)
  if hash != -1 {
    u.hash = substr(rest, hash)
    rest = substr(rest, 0, end=hash)
  }
  let qm = find_from(rest, '?', 0)
  if qm != -1 {
    u.search = substr(rest, qm)
    rest = substr(rest, 0, end=qm)
  }
  if rest != "" {
    u.pathname = rest
  }
  ignore(lower_proto)
  u
}

///|
fn MdUrl::parse_host(self : MdUrl, host : String) -> Unit {
  // PORT_PATTERN = :[0-9]*$
  let mut host = host
  let mut i = host.length()
  while i > 0 && host[i - 1] is ('0'..='9') {
    i -= 1
  }
  if i > 0 && host[i - 1] == ':' {
    let port = substr(host, i - 1)
    if port != ":" {
      self.port = substr(port, 1)
    }
    host = substr(host, 0, end=i - 1)
  }
  if host != "" {
    self.hostname = host
  }
}

///|
/// `mdurl.format`.
fn MdUrl::format(self : MdUrl) -> String {
  let sb = StringBuilder()
  sb.write_string(self.protocol)
  if self.slashes {
    sb.write_string("//")
  }
  if self.auth != "" {
    sb.write_string(self.auth + "@")
  }
  if self.hostname.contains(":") {
    sb.write_string("[" + self.hostname + "]")
  } else {
    sb.write_string(self.hostname)
  }
  if self.port != "" {
    sb.write_string(":" + self.port)
  }
  sb.write_string(self.pathname)
  sb.write_string(self.search)
  sb.write_string(self.hash)
  sb.to_string()
}

///|
let encode_default_chars : String = ";/?:@&=+$,-_.!~*'()#"

///|
fn write_pct(sb : StringBuilder, b : Int) -> Unit {
  let digits = "0123456789ABCDEF"
  sb.write_char('%')
  sb.write_char(digits.get_char(b >> 4).unwrap())
  sb.write_char(digits.get_char(b & 15).unwrap())
}

///|
fn write_utf8_pct(sb : StringBuilder, c : Int) -> Unit {
  if c < 0x80 {
    write_pct(sb, c)
  } else if c < 0x800 {
    write_pct(sb, 0xC0 | (c >> 6))
    write_pct(sb, 0x80 | (c & 0x3F))
  } else if c < 0x10000 {
    write_pct(sb, 0xE0 | (c >> 12))
    write_pct(sb, 0x80 | ((c >> 6) & 0x3F))
    write_pct(sb, 0x80 | (c & 0x3F))
  } else {
    write_pct(sb, 0xF0 | (c >> 18))
    write_pct(sb, 0x80 | ((c >> 12) & 0x3F))
    write_pct(sb, 0x80 | ((c >> 6) & 0x3F))
    write_pct(sb, 0x80 | (c & 0x3F))
  }
}

///|
/// `mdurl.encode` with the default exclude set.
fn mdurl_encode(s : String) -> String {
  let sb = StringBuilder()
  let l = s.length()
  let mut i = 0
  while i < l {
    let code = s[i].to_int()
    if code == 0x25 &&
      i + 2 < l &&
      is_hex_digit(s[i + 1].to_int().unsafe_to_char()) &&
      is_hex_digit(s[i + 2].to_int().unsafe_to_char()) {
      sb.write_string(substr(s, i, end=i + 3))
      i += 3
      continue
    }
    if code < 128 {
      let ch = code.unsafe_to_char()
      if is_ascii_alnum(ch) || encode_default_chars.contains_char(ch) {
        sb.write_char(ch)
      } else {
        write_pct(sb, code)
      }
      i += 1
      continue
    }
    if code >= 0xD800 && code <= 0xDFFF {
      if code <= 0xDBFF && i + 1 < l {
        let next = s[i + 1].to_int()
        if next >= 0xDC00 && next <= 0xDFFF {
          let cp = 0x10000 + ((code - 0xD800) << 10) + (next - 0xDC00)
          write_utf8_pct(sb, cp)
          i += 2
          continue
        }
      }
      sb.write_string("%EF%BF%BD")
      i += 1
      continue
    }
    write_utf8_pct(sb, code)
    i += 1
  }
  sb.to_string()
}

///|
/// `mdurl.decode(s, exclude)`.
fn mdurl_decode(s : String, exclude : String) -> String {
  let sb = StringBuilder()
  let l = s.length()
  let mut i = 0
  fn is_pct(j : Int) -> Bool {
    j + 2 < l &&
    s[j] == '%' &&
    is_hex_digit(s[j + 1].to_int().unsafe_to_char()) &&
    is_hex_digit(s[j + 2].to_int().unsafe_to_char())
  }

  while i < l {
    if !is_pct(i) {
      sb.write_char(s[i].to_int().unsafe_to_char())
      i += 1
      continue
    }
    // collect the run of %XX
    let bytes : Array[Int] = []
    let mut j = i
    while is_pct(j) {
      bytes.push(
        hex_value(s[j + 1].to_int().unsafe_to_char()) * 16 +
        hex_value(s[j + 2].to_int().unsafe_to_char()),
      )
      j += 3
    }
    let seq = substr(s, i, end=j)
    // decode
    let n = bytes.length()
    let mut k = 0
    while k < n {
      let b1 = bytes[k]
      if b1 < 0x80 {
        let ch = b1.unsafe_to_char()
        if exclude.contains_char(ch) {
          sb.write_string(substr(seq, k * 3, end=k * 3 + 3).to_upper())
        } else {
          sb.write_char(ch)
        }
        k += 1
        continue
      }
      if (b1 & 0xE0) == 0xC0 && k + 1 < n {
        let b2 = bytes[k + 1]
        if (b2 & 0xC0) == 0x80 {
          let cp = ((b1 & 0x1F) << 6) | (b2 & 0x3F)
          if cp < 0x80 {
            sb.write_string("\u{FFFD}\u{FFFD}")
          } else {
            sb.write_char(cp.unsafe_to_char())
          }
          k += 2
          continue
        }
      }
      if (b1 & 0xF0) == 0xE0 && k + 2 < n {
        let b2 = bytes[k + 1]
        let b3 = bytes[k + 2]
        if (b2 & 0xC0) == 0x80 && (b3 & 0xC0) == 0x80 {
          let cp = ((b1 & 0x0F) << 12) | ((b2 & 0x3F) << 6) | (b3 & 0x3F)
          if cp < 0x800 || (cp >= 0xD800 && cp <= 0xDFFF) {
            sb.write_string("\u{FFFD}\u{FFFD}\u{FFFD}")
          } else {
            sb.write_char(cp.unsafe_to_char())
          }
          k += 3
          continue
        }
      }
      if (b1 & 0xF8) == 0xF0 && k + 3 < n {
        let b2 = bytes[k + 1]
        let b3 = bytes[k + 2]
        let b4 = bytes[k + 3]
        if (b2 & 0xC0) == 0x80 && (b3 & 0xC0) == 0x80 && (b4 & 0xC0) == 0x80 {
          let cp = ((b1 & 0x07) << 18) |
            ((b2 & 0x3F) << 12) |
            ((b3 & 0x3F) << 6) |
            (b4 & 0x3F)
          if cp < 0x10000 || cp > 0x10FFFF {
            sb.write_string("\u{FFFD}\u{FFFD}\u{FFFD}\u{FFFD}")
          } else {
            sb.write_char(cp.unsafe_to_char())
          }
          k += 4
          continue
        }
      }
      sb.write_char('\u{FFFD}')
      k += 1
    }
    i = j
  }
  sb.to_string()
}

// --- punycode (RFC 3492), as Python's "punycode" codec ---

///|
fn punycode_digit(d : Int) -> Char {
  if d < 26 {
    (d + 'a'.to_int()).unsafe_to_char()
  } else {
    (d - 26 + '0'.to_int()).unsafe_to_char()
  }
}

///|
fn punycode_adapt(delta : Int, numpoints : Int, first : Bool) -> Int {
  let mut delta = if first { delta / 700 } else { delta / 2 }
  delta += delta / numpoints
  let mut k = 0
  while delta > (36 - 1) * 26 / 2 {
    delta = delta / (36 - 1)
    k += 36
  }
  k + 36 * delta / (delta + 38)
}

///|
fn punycode_encode(s : String) -> String {
  let cps : Array[Int] = []
  for c in s {
    cps.push(c.to_int())
  }
  let out = StringBuilder()
  let mut b = 0
  for c in cps {
    if c < 0x80 {
      out.write_char(c.unsafe_to_char())
      b += 1
    }
  }
  if b > 0 {
    out.write_char('-')
  }
  let mut n = 128
  let mut delta = 0
  let mut bias = 72
  let mut h = b
  while h < cps.length() {
    let mut m = 0x7FFFFFFF
    for c in cps {
      if c >= n && c < m {
        m = c
      }
    }
    delta += (m - n) * (h + 1)
    n = m
    for c in cps {
      if c < n {
        delta += 1
      }
      if c == n {
        let mut q = delta
        let mut k = 36
        while true {
          let t = if k <= bias {
            1
          } else if k >= bias + 26 {
            26
          } else {
            k - bias
          }
          if q < t {
            break
          }
          out.write_char(punycode_digit(t + (q - t) % (36 - t)))
          q = (q - t) / (36 - t)
          k += 36
        }
        out.write_char(punycode_digit(q))
        bias = punycode_adapt(delta, h + 1, h == b)
        delta = 0
        h += 1
      }
    }
    delta += 1
    n += 1
  }
  out.to_string()
}

///|
fn punycode_decode(s : String) -> String? {
  let output : Array[Int] = []
  let basic_end = match s.rev_find("-") {
    Some(i) => i
    None => 0
  }
  for i in 0..<basic_end {
    let c = s[i].to_int()
    if c >= 0x80 {
      return None
    }
    output.push(c)
  }
  let mut n = 128
  let mut i = 0
  let mut bias = 72
  let mut pos = if basic_end > 0 { basic_end + 1 } else { 0 }
  while pos < s.length() {
    let oldi = i
    let mut w = 1
    let mut k = 36
    while true {
      if pos >= s.length() {
        return None
      }
      let c = s[pos].to_int()
      pos += 1
      let digit = if c >= '0'.to_int() && c <= '9'.to_int() {
        c - '0'.to_int() + 26
      } else if c >= 'a'.to_int() && c <= 'z'.to_int() {
        c - 'a'.to_int()
      } else if c >= 'A'.to_int() && c <= 'Z'.to_int() {
        c - 'A'.to_int()
      } else {
        return None
      }
      i += digit * w
      let t = if k <= bias { 1 } else if k >= bias + 26 { 26 } else { k - bias }
      if digit < t {
        break
      }
      w *= 36 - t
      k += 36
    }
    let len = output.length() + 1
    bias = punycode_adapt(i - oldi, len, oldi == 0)
    n += i / len
    i = i % len
    if n > 0x10FFFF || (n >= 0xD800 && n <= 0xDFFF) {
      return None
    }
    output.insert(i, n)
    i += 1
  }
  let sb = StringBuilder()
  for c in output {
    sb.write_char(c.unsafe_to_char())
  }
  Some(sb.to_string())
}

///|
/// `_punycode.map_domain`: split on `@` (keep local part) and on the
/// label separators `.`, `。`, `．`, `｡`.
fn map_domain(s : String, f : (String) -> String?) -> String? {
  let parts = s.split("@").map(v => v.to_owned()).to_array()
  let mut result = ""
  let mut s = s
  if parts.length() > 1 {
    result = parts[0] + "@"
    s = parts[1]
  }
  let labels : Array[String] = []
  let cur = StringBuilder()
  for c in s {
    if c is ('.' | '\u{3002}' | '\u{FF0E}' | '\u{FF61}') {
      labels.push(cur.to_string())
      cur.reset()
    } else {
      cur.write_char(c)
    }
  }
  labels.push(cur.to_string())
  let mapped : Array[String] = []
  for label in labels {
    guard f(label) is Some(m) else { return None }
    mapped.push(m)
  }
  Some(result + mapped.join("."))
}

///|
fn has_non_ascii(s : String) -> Bool {
  for c in s {
    if c.to_int() > 0x7E {
      return true
    }
  }
  false
}

///|
fn punycode_to_ascii(s : String) -> String? {
  map_domain(s, label => {
    if has_non_ascii(label) {
      Some("xn--" + punycode_encode(label))
    } else {
      Some(label)
    }
  })
}

///|
fn punycode_to_unicode(s : String) -> String? {
  map_domain(s, label => {
    if label.has_prefix("xn--") {
      punycode_decode(substr(label, 4).to_lower())
    } else {
      Some(label)
    }
  })
}

///|
fn recode_hostname(u : MdUrl) -> Bool {
  u.hostname != "" && u.protocol is ("" | "http:" | "https:" | "mailto:")
}

///|
/// markdown-it `normalizeLink`.
pub fn normalize_link(url : String) -> String {
  let parsed = MdUrl::parse(url)
  if recode_hostname(parsed) {
    if punycode_to_ascii(parsed.hostname) is Some(h) {
      parsed.hostname = h
    }
  }
  mdurl_encode(parsed.format())
}

///|
/// markdown-it `normalizeLinkText` (used for autolink text).
pub fn normalize_link_text(url : String) -> String {
  let parsed = MdUrl::parse(url)
  if recode_hostname(parsed) {
    if punycode_to_unicode(parsed.hostname) is Some(h) {
      parsed.hostname = h
    }
  }
  mdurl_decode(parsed.format(), ";/?:@&=+$,#%")
}

///|
/// markdown-it `validateLink`: reject `javascript:`, `vbscript:`, `file:`
/// and non-image `data:` URLs.
pub fn validate_link(url : String) -> Bool {
  let url = py_strip(url).to_lower()
  let bad = url.has_prefix("vbscript:") ||
    url.has_prefix("javascript:") ||
    url.has_prefix("file:") ||
    url.has_prefix("data:")
  if !bad {
    return true
  }
  url.has_prefix("data:image/gif;") ||
  url.has_prefix("data:image/png;") ||
  url.has_prefix("data:image/jpeg;") ||
  url.has_prefix("data:image/webp;")
}
