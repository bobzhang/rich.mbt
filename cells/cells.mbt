// Port of rich/cells.py and rich/_unicode_data/__init__.py.
//
// Offsets are UTF-16 offsets into the MoonBit string; widths are computed per
// code point exactly as upstream.

///|
/// Unicode data required to measure the cell widths of glyphs.
pub struct CellTable {
  unicode_version : String
  priv widths : FixedArray[Int] // flattened (start, end, width) triples
  priv narrow_to_wide : FixedArray[Int] // sorted code points
}

///|
/// Returns `true` if the code point becomes wide when followed by U+FE0F.
pub fn CellTable::is_narrow_to_wide(self : CellTable, codepoint : Int) -> Bool {
  binary_search(self.narrow_to_wide, codepoint)
}

///|
fn binary_search(table : FixedArray[Int], value : Int) -> Bool {
  for lo = 0, hi = table.length() - 1; lo <= hi; {
    let mid = (lo + hi) >> 1
    let v = table[mid]
    if v < value {
      continue mid + 1, hi
    } else if v > value {
      continue lo, mid - 1
    } else {
      break true
    }
  } nobreak {
    false
  }
}

///|
let table_cache : Map[String, CellTable] = Map([])

///|
fn parse_version(version : String) -> (Int, Int, Int)? {
  let parts = version.split(".").collect()
  let nums = []
  for part in parts {
    let p = part.to_owned()
    // Python int() accepts surrounding whitespace and a sign
    let trimmed = p.trim(chars=" \t\n\r\u{0b}\u{0c}").to_owned()
    guard trimmed != "" else { return None }
    let s = match trimmed.strip_prefix("+") {
      Some(rest) => rest.to_owned()
      None =>
        match trimmed.strip_prefix("-") {
          Some(rest) => rest.to_owned()
          None => trimmed
        }
    }
    guard s != "" && s.iter().all(c => c >= '0' && c <= '9') else {
      return None
    }
    let n = @string.parse_int(trimmed) catch { _ => return None }
    nums.push(n)
  }
  while nums.length() < 3 {
    nums.push(0)
  }
  Some((nums[0], nums[1], nums[2]))
}

///|
fn compare_version(a : (Int, Int, Int), b : (Int, Int, Int)) -> Int {
  if a.0 != b.0 {
    return a.0.compare(b.0)
  }
  if a.1 != b.1 {
    return a.1.compare(b.1)
  }
  a.2.compare(b.2)
}

///|
/// All Unicode versions for which width tables are available, oldest first.
pub fn unicode_versions() -> Array[String] {
  versions.copy()
}

///|
/// Load a cell table for the given unicode version.
///
/// `"auto"` reads the `UNICODE_VERSION` environment variable (falling back to
/// `"latest"`); `"latest"` selects the newest table. Unknown versions select
/// the closest older version.
pub fn load(unicode_version? : String = "auto") -> CellTable {
  if table_cache.get(unicode_version) is Some(t) {
    return t
  }
  let requested = unicode_version
  let mut unicode_version = unicode_version
  if unicode_version == "auto" {
    unicode_version = @env.get_env_var("UNICODE_VERSION").unwrap_or("latest")
    if parse_version(unicode_version) is None {
      unicode_version = "latest"
    }
  }
  let version = if unicode_version == "latest" {
    versions[versions.length() - 1]
  } else {
    let (major, minor, patch) = match parse_version(unicode_version) {
      Some(v) => v
      None => parse_version(versions[versions.length() - 1]).unwrap()
    }
    let version = "\{major}.\{minor}.\{patch}"
    if versions.contains(version) {
      version
    } else {
      // bisect_left over the sorted versions
      let target = (major, minor, patch)
      let mut insert_position = versions.length()
      for i, v in versions {
        if compare_version(parse_version(v).unwrap(), target) >= 0 {
          insert_position = i
          break
        }
      }
      versions[@cmp.maximum(0, insert_position - 1)]
    }
  }
  let (widths, narrow_to_wide) = raw_table(version)
  let table = { unicode_version: version, widths, narrow_to_wide, }
  table_cache[requested] = table
  table
}

///|
let single_cell_ranges : FixedArray[(Int, Int)] = [
  (0x20, 0x7E),
  (0xA0, 0xAC),
  (0xAE, 0x002FF),
  (0x00370, 0x00482),
  (0x02500, 0x025FC),
  (0x02800, 0x028FF),
]

///|
fn is_single_cell_char(cp : Int) -> Bool {
  for range in single_cell_ranges {
    if cp >= range.0 && cp <= range.1 {
      return true
    }
  }
  false
}

///|
/// Returns `true` if every character of `text` is known to be a single cell
/// wide (common Western scripts, box drawing, braille).
pub fn is_single_cell_widths(text : StringView) -> Bool {
  for i in 0..<text.length() {
    let cu = text.unsafe_get(i).to_int()
    // printable ASCII first: by far the most common case
    if (cu < 0x20 || cu > 0x7E) && !is_single_cell_char(cu) {
      return false
    }
  }
  true
}

///|
fn table_lookup(table : CellTable, codepoint : Int) -> Int {
  let widths = table.widths
  let count = widths.length() / 3
  if codepoint > widths[(count - 1) * 3 + 1] {
    return 1
  }
  for lo = 0, hi = count - 1; lo <= hi; {
    let index = (lo + hi) >> 1
    let start = widths[index * 3]
    let end = widths[index * 3 + 1]
    if codepoint < start {
      continue lo, index - 1
    } else if codepoint > end {
      continue index + 1, hi
    } else {
      break widths[index * 3 + 2]
    }
  } nobreak {
    1
  }
}

///|
/// Get the cell size of a code point (0, 1 or 2).
pub fn codepoint_cell_size(
  codepoint : Int,
  unicode_version? : String = "auto",
) -> Int {
  cell_size_in(load(unicode_version~), codepoint)
}

///|
/// `codepoint_cell_size` with the table already loaded.
fn cell_size_in(table : CellTable, codepoint : Int) -> Int {
  if (codepoint != 0 && codepoint < 32) ||
    (codepoint >= 0x7F && codepoint < 0xA0) {
    return 0
  }
  table_lookup(table, codepoint)
}

///|
/// Get the cell size of a character (0, 1 or 2).
pub fn get_character_cell_size(
  character : Char,
  unicode_version? : String = "auto",
) -> Int {
  codepoint_cell_size(character.to_int(), unicode_version~)
}

///|
const ZWJ : Int = 0x200D

///|
const VS16 : Int = 0xFE0F

///|
/// Get the cell length of a string (length as it appears in the terminal).
pub fn cell_len(text : StringView, unicode_version? : String = "auto") -> Int {
  if is_single_cell_widths(text) {
    return text.length()
  }
  let mut has_special = false
  for c in text {
    if c.to_int() == ZWJ || c.to_int() == VS16 {
      has_special = true
      break
    }
  }
  let table = load(unicode_version~)
  if !has_special {
    let mut total = 0
    for c in text {
      total += cell_size_in(table, c.to_int())
    }
    return total
  }
  let mut total_width = 0
  let mut last_measured : Int? = None
  let mut skip_next = false
  for c in text {
    let cp = c.to_int()
    if skip_next {
      // upstream skips the code point that follows a zero width joiner
      skip_next = false
    } else if cp == ZWJ {
      skip_next = true
    } else if cp == VS16 {
      if last_measured is Some(last) {
        if table.is_narrow_to_wide(last) {
          total_width += 1
        }
        last_measured = None
      }
    } else {
      let w = cell_size_in(table, cp)
      if w != 0 {
        last_measured = Some(cp)
        total_width += w
      }
    }
  }
  total_width
}

///|
/// Decode `text` into code points and the UTF-16 offset of each one
/// (with a final entry equal to `text.length()`).
fn decode(text : StringView) -> (Array[Int], Array[Int]) {
  let cps = []
  let offsets = []
  let mut offset = 0
  for c in text {
    cps.push(c.to_int())
    offsets.push(offset)
    offset += if c.to_int() > 0xFFFF { 2 } else { 1 }
  }
  offsets.push(offset)
  (cps, offsets)
}

///|
/// Divide text into spans that define a single grapheme, and additionally
/// return the cell length of the whole string.
///
/// Each span is `(start, end, cell_length)` where `start`/`end` are UTF-16
/// offsets. Spans cover every index of the string with no gaps.
pub fn split_graphemes(
  text : StringView,
  unicode_version? : String = "auto",
) -> (Array[(Int, Int, Int)], Int) {
  let table = load(unicode_version~)
  let (cps, offsets) = decode(text)
  let count = cps.length()
  let spans : Array[(Int, Int, Int)] = []
  let mut index = 0
  let mut last_measured : Int? = None
  let mut total_width = 0
  while index < count {
    let cp = cps[index]
    if cp == ZWJ || cp == VS16 {
      if spans.is_empty() {
        spans.push((index, index + 1, 0))
        index += 1
        continue
      }
      if cp == ZWJ {
        index += if index < count - 1 { 2 } else { 1 }
        let (start, _, cell_length) = spans[spans.length() - 1]
        spans[spans.length() - 1] = (start, index, cell_length)
      } else {
        index += 1
        let (start, _, cell_length) = spans[spans.length() - 1]
        let mut cell_length = cell_length
        if last_measured is Some(last) && table.is_narrow_to_wide(last) {
          last_measured = None
          cell_length += 1
          total_width += 1
        }
        spans[spans.length() - 1] = (start, index, cell_length)
      }
      continue
    }
    let width = cell_size_in(table, cp)
    if width != 0 {
      last_measured = Some(cp)
      spans.push((index, index + 1, width))
      total_width += width
      index += 1
    } else if !spans.is_empty() {
      let (start, _, cell_length) = spans[spans.length() - 1]
      index += 1
      spans[spans.length() - 1] = (start, index, cell_length)
    } else {
      spans.push((index, index + 1, 0))
      index += 1
    }
  }
  let mapped = spans.map(span => (offsets[span.0], offsets[span.1], span.2))
  (mapped, total_width)
}

///|
fn slice(text : StringView, start : Int, end : Int) -> String {
  text.view(start_offset=start, end_offset=end).to_owned()
}

///|
fn split_text_impl(
  text : StringView,
  cell_position : Int,
  unicode_version : String,
) -> (String, String) {
  if cell_position <= 0 {
    return ("", text.to_owned())
  }
  let (spans, cell_length) = split_graphemes(text, unicode_version~)
  let n = text.length()
  if cell_length == 0 {
    return (text.to_owned(), "")
  }
  let mut offset = (cell_position.to_double() /
  cell_length.to_double() *
  spans.length().to_double()).to_int()
  let mut left_size = 0
  for i in 0..<@cmp.minimum(offset, spans.length()) {
    left_size += spans[i].2
  }
  while true {
    if left_size == cell_position {
      if offset >= spans.length() {
        return (text.to_owned(), "")
      }
      let split_index = spans[offset].0
      return (slice(text, 0, split_index), slice(text, split_index, n))
    }
    if left_size < cell_position {
      let (start, end, cell_size) = spans[offset]
      if left_size + cell_size > cell_position {
        return (slice(text, 0, start) + " ", " " + slice(text, end, n))
      }
      offset += 1
      left_size += cell_size
    } else {
      let (start, end, cell_size) = spans[offset - 1]
      if left_size - cell_size < cell_position {
        return (slice(text, 0, start) + " ", " " + slice(text, end, n))
      }
      offset -= 1
      left_size -= cell_size
    }
  }
  panic()
}

///|
/// Split text by cell position.
///
/// If the cell position falls within a double width character, it is
/// converted to two spaces.
pub fn split_text(
  text : StringView,
  cell_position : Int,
  unicode_version? : String = "auto",
) -> (String, String) {
  if is_single_cell_widths(text) {
    let n = text.length()
    let p = if cell_position < 0 {
      @cmp.maximum(0, n + cell_position)
    } else {
      @cmp.minimum(cell_position, n)
    }
    return (slice(text, 0, p), slice(text, p, n))
  }
  split_text_impl(text, cell_position, unicode_version)
}

///|
/// Adjust a string by cropping or padding with spaces such that it fits
/// within the given number of cells.
pub fn set_cell_size(
  text : StringView,
  total : Int,
  unicode_version? : String = "auto",
) -> String {
  if is_single_cell_widths(text) {
    let size = text.length()
    if size < total {
      return text.to_owned() + " ".repeat(total - size)
    }
    let p = if total < 0 { @cmp.maximum(0, size + total) } else { total }
    return slice(text, 0, p)
  }
  if total <= 0 {
    return ""
  }
  let cell_size = cell_len(text)
  if cell_size == total {
    return text.to_owned()
  }
  if cell_size < total {
    return text.to_owned() + " ".repeat(total - cell_size)
  }
  split_text_impl(text, total, unicode_version).0
}

///|
/// Split text into lines such that each line fits within the available
/// (cell) width.
pub fn chop_cells(
  text : StringView,
  width : Int,
  unicode_version? : String = "auto",
) -> Array[String] {
  if is_single_cell_widths(text) {
    // Python `range(0, len(text), width)`
    if width == 0 {
      abort("range() arg 3 must not be zero")
    }
    let n = text.length()
    let lines = []
    if width < 0 {
      return lines
    }
    let mut index = 0
    while index < n {
      lines.push(slice(text, index, @cmp.minimum(index + width, n)))
      index += width
    }
    return lines
  }
  let (spans, _) = split_graphemes(text, unicode_version~)
  let mut line_size = 0
  let lines = []
  let mut line_offset = 0
  for span in spans {
    let (start, _, cell_size) = span
    if line_size + cell_size > width {
      lines.push(slice(text, line_offset, start))
      line_offset = start
      line_size = 0
    }
    line_size += cell_size
  }
  if line_size != 0 {
    lines.push(slice(text, line_offset, text.length()))
  }
  lines
}
