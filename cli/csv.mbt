// The parts of Python's `csv` module rich-cli uses: `Sniffer.sniff`,
// `Sniffer.has_header` and `reader` (the `_csv` parser, non-strict,
// `QUOTE_MINIMAL`, no escape character).

///|
/// A CSV dialect (the reader-relevant attributes of `csv.Dialect`).
priv struct Dialect {
  delimiter : Char
  quotechar : Char
  doublequote : Bool
  skipinitialspace : Bool
}

///|
/// `csv.excel`.
let excel : Dialect = {
  delimiter: ',',
  quotechar: '"',
  doublequote: true,
  skipinitialspace: false,
}

///|
/// `csv.excel_tab`.
let excel_tab : Dialect = { ..excel, delimiter: '\t', }

///|
/// `csv.Error`.
priv suberror CsvError {
  CsvError(String)
}

///|
fn compile_regex(pattern : String, flags? : Int = 0) -> @regex.Regex {
  @regex.compile(pattern, flags~) catch {
    _ => abort("bad regex \{pattern}")
  }
}

///|
let budget_steps : Int = 50_000_000

///|
let quote_regexes : Array[@regex.Regex] = [
  (
    #|(?P<delim>[^\w\n"'])(?P<space> ?)(?P<quote>["']).*?(?P=quote)(?P=delim)
  ),
  (
    #|(?:^|\n)(?P<quote>["']).*?(?P=quote)(?P<delim>[^\w\n"'])(?P<space> ?)
  ),
  (
    #|(?P<delim>[^\w\n"'])(?P<space> ?)(?P<quote>["']).*?(?P=quote)(?:$|\n)
  ),
  (
    #|(?:^|\n)(?P<quote>["']).*?(?P=quote)(?:$|\n)
  ),
].map(p => compile_regex(p, flags=@regex.DOTALL | @regex.MULTILINE))

///|
/// Python's `re.escape`.
fn re_escape(s : String) -> String {
  let sb = StringBuilder()
  for c in s {
    if "()[]{}?*+-|^$\\.&~# \t\n\r\u{0b}\u{0c}".contains_char(c) {
      sb.write_char('\\')
    }
    sb.write_char(c)
  }
  sb.to_string()
}

///|
/// The first key with the largest count (Python's `max(d, key=d.get)`).
fn max_key(counts : Map[Char, Int]) -> Char? {
  let mut best : (Char, Int)? = None
  for k, v in counts {
    match best {
      Some((_, n)) if n >= v => ()
      _ => best = Some((k, v))
    }
  }
  best.map(p => p.0)
}

///|
/// `Sniffer._guess_quote_and_delimiter`:
/// (quotechar, doublequote, delimiter, skipinitialspace).
fn guess_quote_and_delimiter(
  data : String,
  delimiters : String?,
) -> (Char?, Bool, Char?, Bool) {
  let mut regex = quote_regexes[0]
  let mut matches = []
  for re in quote_regexes {
    regex = re
    matches = re.find_all(data, budget=@regex.Budget::new(budget_steps)) catch {
      _ => []
    }
    if !matches.is_empty() {
      break
    }
  }
  if matches.is_empty() {
    return (None, false, None, false)
  }
  let quotes : Map[Char, Int] = Map([])
  let delims : Map[Char, Int] = Map([])
  let mut spaces = 0
  let has_delim = regex.group_index("delim") is Some(_)
  for m in matches {
    if m.named("quote") is Some(q) && q.get_char(0) is Some(c) {
      quotes[c] = quotes.get(c).unwrap_or(0) + 1
    }
    if !has_delim {
      continue
    }
    if m.named("delim") is Some(d) &&
      d.get_char(0) is Some(c) &&
      (delimiters is None || (delimiters is Some(ds) && ds.contains_char(c))) {
      delims[c] = delims.get(c).unwrap_or(0) + 1
    }
    if m.named("space") is Some(s) && s != "" {
      spaces += 1
    }
  }
  let quotechar = max_key(quotes)
  let (delim, skipinitialspace) = match max_key(delims) {
    Some(d) => (if d == '\n' { None } else { Some(d) }, delims[d] == spaces)
    None => (None, false)
  }
  let delim_s = match delim {
    Some(d) => re_escape(d.to_string())
    None => ""
  }
  let quote_s = match quotechar {
    Some(q) => q.to_string()
    None => ""
  }
  let dq = compile_regex(
    "((\{delim_s})|^)\\W*\{quote_s}[^\{delim_s}\\n]*\{quote_s}[^\{delim_s}\\n]*\{quote_s}\\W*((\{delim_s})|$)",
    flags=@regex.MULTILINE,
  )
  let doublequote = (dq.search(data, budget=@regex.Budget::new(budget_steps)) catch {
      _ => None
    })
    is Some(_)
  (quotechar, doublequote, delim, skipinitialspace)
}

///|
/// Non-overlapping occurrences of `sub` in `s` (`str.count`).
fn count_sub(s : String, sub : String) -> Int {
  let mut n = 0
  let mut i = 0
  while s.view(start_offset=i).find(sub[:]) is Some(j) {
    n += 1
    i = i + j + sub.length()
  }
  n
}

///|
/// `Sniffer._guess_delimiter`: (delimiter, skipinitialspace).
fn guess_delimiter(data : String, delimiters : String?) -> (Char?, Bool) {
  let lines = data
    .split("\n")
    .filter(l => l != "")
    .map(l => l.to_owned())
    .to_array()
  let chunk_length = @cmp.minimum(10, lines.length())
  let mut iteration = 0
  // char -> (frequency -> count), both in insertion order
  let char_frequency : Map[Char, Map[Int, Int]] = Map([])
  let modes : Map[Char, (Int, Int)] = Map([])
  let delims : Map[Char, (Int, Int)] = Map([])
  let mut start = 0
  let mut end = chunk_length
  fn skip_space(d : Char) -> Bool {
    count_sub(lines[0], d.to_string()) == count_sub(lines[0], "\{d} ")
  }

  while start < lines.length() {
    iteration += 1
    for i in start..<@cmp.minimum(end, lines.length()) {
      let counts : Map[Char, Int] = Map([])
      for c in lines[i] {
        counts[c] = counts.get(c).unwrap_or(0) + 1
      }
      for code in 0..<127 {
        let c = code.unsafe_to_char()
        let freq = counts.get(c).unwrap_or(0)
        let meta = match char_frequency.get(c) {
          Some(m) => m
          None => {
            let m : Map[Int, Int] = Map([])
            char_frequency[c] = m
            m
          }
        }
        meta[freq] = meta.get(freq).unwrap_or(0) + 1
      }
    }
    for c, meta in char_frequency {
      let items = meta.to_array()
      if items.length() == 1 && items[0].0 == 0 {
        continue
      }
      if items.length() > 1 {
        let mut best = 0
        for i, item in items {
          if item.1 > items[best].1 {
            best = i
          }
        }
        let mode = items[best]
        let mut others = 0
        for i, item in items {
          if i != best {
            others += item.1
          }
        }
        modes[c] = (mode.0, mode.1 - others)
      } else {
        modes[c] = items[0]
      }
    }
    let total = @cmp.minimum(chunk_length * iteration, lines.length()).to_double()
    let mut consistency = 1.0
    let threshold = 0.9
    while delims.length() == 0 && consistency >= threshold {
      for k, v in modes {
        if v.0 > 0 &&
          v.1 > 0 &&
          v.1.to_double() / total >= consistency &&
          (
            delimiters is None ||
            (delimiters is Some(ds) && ds.contains_char(k))
          ) {
          delims[k] = v
        }
      }
      consistency -= 0.01
    }
    if delims.length() == 1 {
      let d = delims.keys().collect()[0]
      return (Some(d), skip_space(d))
    }
    start = end
    end += chunk_length
  }
  if delims.length() == 0 {
    return (None, false)
  }
  if delims.length() > 1 {
    for d in [',', '\t', ';', ' ', ':'] {
      if delims.contains(d) {
        return (Some(d), skip_space(d))
      }
    }
  }
  let items = delims.to_array()
  items.sort_by((p, q) => {
    let c = p.1.compare(q.1)
    if c != 0 {
      c
    } else {
      p.0.compare(q.0)
    }
  })
  let d = items[items.length() - 1].0
  (Some(d), skip_space(d))
}

///|
/// `Sniffer().sniff(sample, delimiters)`.
fn sniff(sample : String, delimiters? : String) -> Dialect raise CsvError {
  let (quotechar, doublequote, delimiter, skipinitialspace) = guess_quote_and_delimiter(
    sample, delimiters,
  )
  let (delimiter, skipinitialspace) = match delimiter {
    Some(_) => (delimiter, skipinitialspace)
    None => guess_delimiter(sample, delimiters)
  }
  guard delimiter is Some(delimiter) else {
    raise CsvError("Could not determine delimiter")
  }
  {
    delimiter,
    quotechar: quotechar.unwrap_or('"'),
    doublequote,
    skipinitialspace,
  }
}

///|
priv enum ColumnType {
  Unknown
  Complex
  Length(Int)
} derive(Eq)

///|
/// `Sniffer().has_header(sample)`.
fn has_header(sample : String) -> Bool raise CsvError {
  let rows = csv_read(sample, sniff(sample))
  guard rows.length() > 0 else { raise CsvError("empty sample") }
  let header = rows[0]
  let column_types : Map[Int, ColumnType] = Map([])
  for i in 0..<header.length() {
    column_types[i] = Unknown
  }
  let mut checked = 0
  for row in rows[1:] {
    if checked > 20 {
      break
    }
    checked += 1
    if row.length() != header.length() {
      continue
    }
    for col in column_types.keys().collect() {
      let this_type = if py_is_complex(row[col]) {
        Complex
      } else {
        Length(row[col].char_length())
      }
      let current = column_types[col]
      if this_type != current {
        if current is Unknown {
          column_types[col] = this_type
        } else {
          column_types.remove(col)
        }
      }
    }
  }
  let mut votes = 0
  for col, col_type in column_types {
    let ok = match col_type {
      Length(n) => header[col].char_length() != n
      Complex => !py_is_complex(header[col])
      Unknown => true
    }
    votes += if ok { 1 } else { -1 }
  }
  votes > 0
}

///|
priv enum ParserState {
  StartRecord
  StartField
  InField
  InQuotedField
  QuoteInQuotedField
  EatCrnl
} derive(Eq)

///|
/// `list(csv.reader(io.StringIO(text), dialect))`.
fn csv_read(
  text : String,
  dialect : Dialect,
) -> Array[Array[String]] raise CsvError {
  let rows : Array[Array[String]] = []
  let mut fields : Array[String] = []
  let field = StringBuilder()
  let mut field_len = 0
  let mut state = StartRecord
  fn save_field() {
    fields.push(field.to_string())
    field.reset()
    field_len = 0
  }

  fn add_char(c : Char) {
    field.write_char(c)
    field_len += 1
  }

  // `None` is the end of a line (EOL)
  fn process(c : Char?) -> Unit raise CsvError {
    let eol = c is None
    let nl = c is Some('\n' | '\r')
    if state == StartRecord {
      if eol {
        return
      } else if nl {
        state = EatCrnl
        return
      }
      state = StartField
    }
    match state {
      StartField =>
        if nl || eol {
          save_field()
          state = if eol { StartRecord } else { EatCrnl }
        } else if c == Some(dialect.quotechar) {
          state = InQuotedField
        } else if c == Some(' ') && dialect.skipinitialspace {
          ()
        } else if c == Some(dialect.delimiter) {
          save_field()
        } else {
          add_char(c.unwrap())
          state = InField
        }
      InField =>
        if nl || eol {
          save_field()
          state = if eol { StartRecord } else { EatCrnl }
        } else if c == Some(dialect.delimiter) {
          save_field()
          state = StartField
        } else {
          add_char(c.unwrap())
        }
      InQuotedField =>
        if eol {
          ()
        } else if c == Some(dialect.quotechar) {
          state = if dialect.doublequote { QuoteInQuotedField } else { InField }
        } else {
          add_char(c.unwrap())
        }
      QuoteInQuotedField =>
        if c == Some(dialect.quotechar) {
          add_char(dialect.quotechar)
          state = InQuotedField
        } else if c == Some(dialect.delimiter) {
          save_field()
          state = StartField
        } else if nl || eol {
          save_field()
          state = if eol { StartRecord } else { EatCrnl }
        } else {
          add_char(c.unwrap())
          state = InField
        }
      EatCrnl =>
        if nl {
          ()
        } else if eol {
          state = StartRecord
        } else {
          raise CsvError(
            "new-line character seen in unquoted field - do you need to open the file with newline=''?",
          )
        }
      StartRecord => ()
    }
  }

  // `io.StringIO` iterates lines split after "\n"
  let lines = []
  let mut line_start = 0
  for i in 0..<text.length() {
    if text[i] == '\n' {
      lines.push(text.view(start_offset=line_start, end_offset=i + 1))
      line_start = i + 1
    }
  }
  if line_start < text.length() {
    lines.push(text.view(start_offset=line_start))
  }
  let mut index = 0
  for ;; {
    fields = []
    state = StartRecord
    field.reset()
    field_len = 0
    for ;; {
      if index >= lines.length() {
        // end of input
        if field_len != 0 || state == InQuotedField {
          save_field()
          rows.push(fields)
        }
        return rows
      }
      for c in lines[index] {
        if c == '\u{0}' {
          raise CsvError("line contains NUL")
        }
        process(Some(c))
      }
      process(None)
      index += 1
      if state == StartRecord {
        break
      }
    }
    rows.push(fields)
  }
}

///|
/// Whether Python's `complex(text)` accepts `text`.
fn py_is_complex(text : String) -> Bool {
  let chars = text.to_array()
  let mut lo = 0
  let mut hi = chars.length()
  while lo < hi && is_py_space(chars[lo]) {
    lo += 1
  }
  while hi > lo && is_py_space(chars[hi - 1]) {
    hi -= 1
  }
  if lo < hi && chars[lo] == '(' {
    if chars[hi - 1] != ')' {
      return false
    }
    lo += 1
    hi -= 1
    while lo < hi && is_py_space(chars[lo]) {
      lo += 1
    }
    while hi > lo && is_py_space(chars[hi - 1]) {
      hi -= 1
    }
  }
  let s = chars[lo:hi]
  let n = s.length()
  fn is_j(i : Int) -> Bool {
    i < n && (s[i] == 'j' || s[i] == 'J')
  }

  match parse_py_float(s, 0) {
    Some(end1) => {
      if end1 == n {
        return true
      }
      if is_j(end1) {
        return end1 + 1 == n
      }
      if s[end1] == '+' || s[end1] == '-' {
        match parse_py_float(s, end1) {
          Some(end2) => is_j(end2) && end2 + 1 == n
          None => is_j(end1 + 1) && end1 + 2 == n
        }
      } else {
        false
      }
    }
    None => {
      let mut p = 0
      if p < n && (s[p] == '+' || s[p] == '-') {
        p += 1
      }
      is_j(p) && p + 1 == n
    }
  }
}

///|
fn is_py_space(c : Char) -> Bool {
  c
  is (' '
  | '\t'
  | '\n'
  | '\r'
  | '\u{0b}'
  | '\u{0c}'
  | '\u{1c}'..='\u{1f}'
  | '\u{85}'
  | '\u{a0}'
  | '\u{1680}'
  | '\u{2000}'..='\u{200a}'
  | '\u{2028}'
  | '\u{2029}'
  | '\u{202f}'
  | '\u{205f}'
  | '\u{3000}')
}

///|
/// Parse a Python float literal (with sign, underscores between digits,
/// `inf`/`infinity`/`nan`) at `start`; the end offset, if any.
fn parse_py_float(s : ArrayView[Char], start : Int) -> Int? {
  let n = s.length()
  let mut i = start
  if i < n && (s[i] == '+' || s[i] == '-') {
    i += 1
  }
  // inf / infinity / nan
  for word in ["infinity", "inf", "nan"] {
    let w = word.to_array()
    if i + w.length() <= n {
      let mut ok = true
      for k in 0..<w.length() {
        let ch = s[i + k]
        let lower = if ch >= 'A' && ch <= 'Z' {
          (ch.to_int() + 32).unsafe_to_char()
        } else {
          ch
        }
        if lower != w[k] {
          ok = false
          break
        }
      }
      if ok {
        return Some(i + w.length())
      }
    }
  }
  fn digits(p : Int) -> Int {
    // digit (_? digit)*; returns the end (p if none)
    if !(p < n && s[p] is ('0'..='9')) {
      return p
    }
    let mut q = p + 1
    while q < n {
      if s[q] is ('0'..='9') {
        q += 1
      } else if s[q] == '_' && q + 1 < n && s[q + 1] is ('0'..='9') {
        q += 2
      } else {
        break
      }
    }
    q
  }

  let int_end = digits(i)
  let mut p = int_end
  let mut has_digits = int_end > i
  if p < n && s[p] == '.' {
    let frac_end = digits(p + 1)
    has_digits = has_digits || frac_end > p + 1
    p = frac_end
  }
  if !has_digits {
    return None
  }
  if p < n && (s[p] == 'e' || s[p] == 'E') {
    let mut q = p + 1
    if q < n && (s[q] == '+' || s[q] == '-') {
      q += 1
    }
    let exp_end = digits(q)
    if exp_end > q {
      p = exp_end
    }
  }
  Some(p)
}

///|
/// Read CSV data with the dialect rich-cli sniffs (`render_csv`).
fn sniff_csv(
  resource : String,
  data : String,
) -> (Dialect, Bool) raise CsvError {
  let sample = take_chars(data, 1024)
  try {
    let dialect = sniff(sample, delimiters=",\t|;")
    (dialect, has_header(sample))
  } catch {
    CsvError(_) as e => {
      let lower = resource.to_lower()
      if lower.has_suffix(".csv") {
        (excel, true)
      } else if lower.has_suffix(".tsv") {
        (excel_tab, true)
      } else {
        raise e
      }
    }
  }
}

///|
/// The first `n` code points of `s` (Python's `s[:n]`).
fn take_chars(s : String, n : Int) -> String {
  let mut count = 0
  for i in 0..<s.length() {
    let c = s[i]
    if !(c >= 0xDC00 && c <= 0xDFFF) {
      if count == n {
        return s.view(end_offset=i).to_owned()
      }
      count += 1
    }
  }
  s
}
