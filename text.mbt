// Port of rich/text.py.
//
// Offsets (spans, `length`, `divide`, ...) are UTF-16 offsets.

///|
/// A marked up region in some text.
pub(all) struct Span {
  start : Int
  end : Int
  style : StyleType
} derive(Eq, Hash)

///|
pub fn Span::new(start : Int, end : Int, style : &IntoStyle) -> Span {
  { start, end, style: style.into_style_type(), }
}

///|
/// Upstream `repr(span)`, e.g. `Span(0, 5, 'bold')`.
pub impl Show for Span with fn output(self, logger) {
  logger.write_string("Span(\{self.start}, \{self.end}, \{self.style.repr()})")
}

///|
pub impl Debug for Span with fn to_repr(self) {
  @debug.Repr(self.to_string())
}

///|
/// Upstream `bool(span)`.
pub fn Span::to_bool(self : Span) -> Bool {
  self.end > self.start
}

///|
/// Split a span in to 2 from a given offset.
pub fn Span::split(self : Span, offset : Int) -> (Span, Span?) {
  if offset < self.start || offset >= self.end {
    return (self, None)
  }
  let span1 = {
    start: self.start,
    end: @cmp.minimum(self.end, offset),
    style: self.style,
  }
  let span2 = { start: span1.end, end: self.end, style: self.style, }
  (span1, Some(span2))
}

///|
/// Move start and end by a given offset.
pub fn Span::move(self : Span, offset : Int) -> Span {
  { start: self.start + offset, end: self.end + offset, style: self.style, }
}

///|
/// Crop the span at the given offset.
pub fn Span::right_crop(self : Span, offset : Int) -> Span {
  if offset >= self.end {
    return self
  }
  { start: self.start, end: @cmp.minimum(offset, self.end), style: self.style, }
}

///|
/// Extend the span by the given number of cells.
pub fn Span::extend(self : Span, cells : Int) -> Span {
  if cells != 0 {
    { start: self.start, end: self.end + cells, style: self.style, }
  } else {
    self
  }
}

///|
/// Text with color / style.
pub(all) struct Text {
  priv mut parts : Array[String]
  priv mut length_ : Int
  priv mut spans_ : Array[Span]
  /// Base style for the text.
  mut style : StyleType
  /// Justify method, or `None` for the default.
  mut justify : JustifyMethod?
  /// Overflow method, or `None` for the default.
  mut overflow : OverflowMethod?
  /// Disable wrapping, or `None` for the default.
  mut no_wrap : Bool?
  /// String to end the text with.
  mut end : String
  /// Number of spaces per tab, or `None` to use `console.tab_size`.
  mut tab_size : Int?
}

///|
/// Remove control codes that would break the layout (bell, backspace,
/// vertical tab, form feed and carriage return).
pub fn strip_control_codes(text : String) -> String {
  let mut needs = false
  for i in 0..<text.length() {
    let c = text[i].to_int()
    if c == 7 || c == 8 || c == 11 || c == 12 || c == 13 {
      needs = true
      break
    }
  }
  if !needs {
    return text
  }
  let buf = StringBuilder()
  for c in text {
    let n = c.to_int()
    if !(n == 7 || n == 8 || n == 11 || n == 12 || n == 13) {
      buf.write_char(c)
    }
  }
  buf.to_string()
}

///|
/// Replace control codes with their escaped version (e.g. "\b" becomes
/// "\\b").
pub fn escape_control_codes(text : String) -> String {
  let buf = StringBuilder()
  for c in text {
    match c.to_int() {
      7 => buf.write_string("\\a")
      8 => buf.write_string("\\b")
      11 => buf.write_string("\\v")
      12 => buf.write_string("\\f")
      13 => buf.write_string("\\r")
      _ => buf.write_char(c)
    }
  }
  buf.to_string()
}

///|
/// Create a new Text.
pub fn Text::new(
  text? : String = "",
  style? : &IntoStyle,
  justify? : JustifyMethod,
  overflow? : OverflowMethod,
  no_wrap? : Bool,
  end? : String = "\n",
  tab_size? : Int,
  spans? : Array[Span],
) -> Text {
  let sanitized = strip_control_codes(text)
  {
    parts: [sanitized],
    length_: sanitized.length(),
    spans_: match spans {
      Some(s) => s
      None => []
    },
    style: style_or_empty(style),
    justify,
    overflow,
    no_wrap,
    end,
    tab_size,
  }
}

///|
/// Length of the text (in UTF-16 code units).
pub fn Text::length(self : Text) -> Int {
  self.length_
}

///|
/// Upstream `bool(text)`.
pub fn Text::to_bool(self : Text) -> Bool {
  self.length_ != 0
}

///|
/// The text as a single string.
pub fn Text::plain(self : Text) -> String {
  if self.parts.length() != 1 {
    let joined = self.parts.join("")
    self.parts = [joined]
  }
  self.parts[0]
}

///|
/// Set the text to a new value.
pub fn Text::set_plain(self : Text, new_text : String) -> Unit {
  if new_text != self.plain() {
    let sanitized = strip_control_codes(new_text)
    self.parts = [sanitized]
    let old_length = self.length_
    self.length_ = sanitized.length()
    if old_length > self.length_ {
      self.trim_spans()
    }
  }
}

///|
/// `Show` gives the plain text, like upstream `str(text)`.
pub impl Show for Text with fn output(self, logger) {
  logger.write_string(self.plain())
}

///|
/// Upstream `repr(text)`.
pub fn Text::repr(self : Text) -> String {
  "<text \{py_repr(self.plain())} [\{self.spans_.map(s => s.to_string()).join(", ")}] \{self.style.repr()}>"
}

///|
pub impl Debug for Text with fn to_repr(self) {
  @debug.Repr(self.repr())
}

///|
/// Two texts are equal if they have the same plain text and spans.
pub impl Eq for Text with fn equal(self, other) {
  self.plain() == other.plain() && self.spans_ == other.spans_
}

///|
/// Concatenate (upstream `text + other`).
pub impl Add for Text with fn add(self, other) {
  let result = self.copy()
  if other.length_ != 0 {
    result.append_text(other) |> ignore
  }
  result
}

///|
/// Concatenate a string or Text (upstream `text + other`).
pub fn Text::concat(self : Text, other : &IntoText) -> Text {
  let result = self.copy()
  (result.append(other) |> ignore) catch {
    _ => ()
  }
  result
}

///|
/// Upstream `other in text`.
pub fn Text::contains(self : Text, other : &IntoText) -> Bool {
  match other.into_text_type() {
    Str(s) => self.plain().contains(s)
    Text(t) => self.plain().contains(t.plain())
  }
}

///|
/// The character at `offset` as a Text (upstream `text[offset]`).
pub fn Text::at(self : Text, offset : Int) -> Text {
  let plain = self.plain()
  let offset = if offset < 0 { plain.length() + offset } else { offset }
  let spans = []
  for span in self.spans_ {
    if span.end > offset && offset >= span.start {
      spans.push({ start: 0, end: 1, style: span.style, })
    }
  }
  Text::new(
    text=plain.view(start_offset=offset, end_offset=offset + 1).to_owned(),
    spans~,
    end="",
  )
}

///|
/// A slice of the text (upstream `text[start:stop]`, Python slice
/// semantics for negative and out-of-range indices).
pub fn Text::slice(self : Text, start? : Int, stop? : Int) -> Text {
  let length = self.plain().length()
  fn clamp(i : Int?, default : Int) -> Int {
    match i {
      None => default
      Some(i) =>
        if i < 0 {
          @cmp.maximum(0, length + i)
        } else {
          @cmp.minimum(i, length)
        }
    }
  }

  let start = clamp(start, 0)
  let stop = clamp(stop, length)
  let lines = self.divide([start, stop])
  lines.get(1)
}

///|
/// The number of cells required to render this text.
pub fn Text::cell_len(self : Text) -> Int {
  @cells.cell_len(self.plain())
}

///|
/// Console markup that renders this Text.
pub fn Text::markup(self : Text) -> String {
  let output = []
  let plain = self.plain()
  let markup_spans : Array[(Int, Bool, StyleType, Int)] = []
  let mut order = 0
  fn add(offset : Int, closing : Bool, style : StyleType) {
    markup_spans.push((offset, closing, style, order))
    order += 1
  }

  add(0, false, self.style)
  for span in self.spans_ {
    add(span.start, false, span.style)
  }
  for span in self.spans_ {
    add(span.end, true, span.style)
  }
  add(plain.length(), true, self.style)
  stable_sort_by(markup_spans, (a, b) => {
    let c = a.0.compare(b.0)
    if c != 0 {
      c
    } else {
      a.1.compare(b.1)
    }
  })
  let mut position = 0
  for item in markup_spans {
    let (offset, closing, style, _) = item
    if offset > position {
      output.push(
        escape(plain.view(start_offset=position, end_offset=offset).to_owned()),
      )
      position = offset
    }
    if style.to_bool() {
      output.push(if closing { "[/\{style}]" } else { "[\{style}]" })
    }
  }
  output.join("")
}

///|
/// Stable sort (insertion sort for short arrays, merge sort otherwise).
fn[T] stable_sort_by(xs : Array[T], cmp : (T, T) -> Int) -> Unit {
  let n = xs.length()
  if n < 2 {
    return
  }
  if n <= 16 {
    for i in 1..<n {
      let x = xs[i]
      let mut j = i - 1
      while j >= 0 && cmp(xs[j], x) > 0 {
        xs[j + 1] = xs[j]
        j -= 1
      }
      xs[j + 1] = x
    }
    return
  }
  let mid = n / 2
  let left = xs[0:mid].to_owned()
  let right = xs[mid:n].to_owned()
  stable_sort_by(left, cmp)
  stable_sort_by(right, cmp)
  let mut i = 0
  let mut j = 0
  let mut k = 0
  while i < left.length() && j < right.length() {
    if cmp(right[j], left[i]) < 0 {
      xs[k] = right[j]
      j += 1
    } else {
      xs[k] = left[i]
      i += 1
    }
    k += 1
  }
  while i < left.length() {
    xs[k] = left[i]
    i += 1
    k += 1
  }
  while j < right.length() {
    xs[k] = right[j]
    j += 1
    k += 1
  }
}

///|
/// Create a Text instance from console markup.
pub fn Text::from_markup(
  text : String,
  style? : &IntoStyle,
  emoji? : Bool = true,
  emoji_variant? : EmojiVariant,
  justify? : JustifyMethod,
  overflow? : OverflowMethod,
  end? : String = "\n",
) -> Text raise RichError {
  let rendered = render_markup(
    text,
    style=style_or_empty(style),
    emoji~,
    emoji_variant?,
  )
  rendered.justify = justify
  rendered.overflow = overflow
  rendered.end = end
  rendered
}

///|
/// Create a Text instance from a string containing ANSI escape codes.
pub fn Text::from_ansi(
  text : String,
  style? : &IntoStyle,
  justify? : JustifyMethod,
  overflow? : OverflowMethod,
  no_wrap? : Bool,
  end? : String = "\n",
  tab_size? : Int = 8,
) -> Text {
  let joiner = Text::new(
    text="\n",
    justify?,
    overflow?,
    no_wrap?,
    end~,
    tab_size~,
    style=style_or_empty(style),
  )
  let decoder = AnsiDecoder::new()
  joiner.join(decoder.decode(text))
}

///|
/// Construct a Text instance with a pre-applied style. A style applied in
/// this way won't be used to pad the text when it is justified.
pub fn Text::styled(
  text : String,
  style? : &IntoStyle,
  justify? : JustifyMethod,
  overflow? : OverflowMethod,
) -> Text {
  let styled_text = Text::new(text~, justify?, overflow?)
  styled_text.stylize(style_or_empty(style))
  styled_text
}

///|
/// A part for `Text::assemble`: a string, a Text, or a `(string, style)`
/// tuple.
pub(open) trait TextPart {
  fn append_to(Self, Text) -> Unit
}

///|
pub impl TextPart for String with fn append_to(self, text) {
  text.append_str(self) |> ignore
}

///|
pub impl TextPart for Text with fn append_to(self, text) {
  if self.length_ != 0 {
    text.append_text(self) |> ignore
  }
}

///|
pub impl[S : IntoStyle] TextPart for (String, S) with fn append_to(self, text) {
  text.append_str(self.0, style=self.1.into_style_type()) |> ignore
}

///|
/// Construct a text instance by combining strings, Texts and
/// `(string, style)` tuples.
pub fn Text::assemble(
  parts : ArrayView[&TextPart],
  style? : &IntoStyle,
  justify? : JustifyMethod,
  overflow? : OverflowMethod,
  no_wrap? : Bool,
  end? : String = "\n",
  tab_size? : Int = 8,
  meta? : Map[String, Json],
) -> Text {
  let text = Text::new(
    style=style_or_empty(style),
    justify?,
    overflow?,
    no_wrap?,
    end~,
    tab_size~,
  )
  for part in parts {
    part.append_to(text)
  }
  if meta is Some(meta) && !meta.is_empty() {
    text.apply_meta(meta)
  }
  text
}

///|
/// The spans (a reference to the internal list).
pub fn Text::spans(self : Text) -> Array[Span] {
  self.spans_
}

///|
/// Replace the spans (copied).
pub fn Text::set_spans(self : Text, spans : Array[Span]) -> Unit {
  self.spans_ = spans.copy()
}

///|
/// A new Text instance with copied metadata (but not the string or spans).
pub fn Text::blank_copy(self : Text, plain? : String = "") -> Text {
  {
    parts: [strip_control_codes(plain)],
    length_: strip_control_codes(plain).length(),
    spans_: [],
    style: self.style,
    justify: self.justify,
    overflow: self.overflow,
    no_wrap: self.no_wrap,
    end: self.end,
    tab_size: self.tab_size,
  }
}

///|
/// A copy of this instance.
pub fn Text::copy(self : Text) -> Text {
  let copy = self.blank_copy(plain=self.plain())
  copy.spans_ = self.spans_.copy()
  copy
}

///|
fn Text::normalize_range(self : Text, start : Int, end : Int?) -> (Int, Int)? {
  let length = self.length_
  let start = if start < 0 { length + start } else { start }
  let end = match end {
    None => length
    Some(e) => if e < 0 { length + e } else { e }
  }
  if start >= length || end <= start {
    None
  } else {
    Some((start, @cmp.minimum(length, end)))
  }
}

///|
/// Apply a style to the text, or a portion of the text (negative offsets
/// count from the end).
pub fn Text::stylize(
  self : Text,
  style : &IntoStyle,
  start? : Int = 0,
  end? : Int,
) -> Unit {
  let style = style.into_style_type()
  if style.to_bool() {
    if self.normalize_range(start, end) is Some((start, end)) {
      self.spans_.push({ start, end, style, })
    }
  }
}

///|
/// Apply a style before other styles already present.
pub fn Text::stylize_before(
  self : Text,
  style : &IntoStyle,
  start? : Int = 0,
  end? : Int,
) -> Unit {
  let style = style.into_style_type()
  if style.to_bool() {
    if self.normalize_range(start, end) is Some((start, end)) {
      self.spans_.insert(0, { start, end, style, })
    }
  }
}

///|
/// Apply metadata to the text, or a portion of the text.
pub fn Text::apply_meta(
  self : Text,
  meta : Map[String, Json],
  start? : Int = 0,
  end? : Int,
) -> Unit {
  let style = Style::from_meta(Some(meta))
  self.stylize(style, start~, end?)
}

///|
/// Apply event handlers (used by Textual). Each handler key is prefixed
/// with "@".
pub fn Text::on(
  self : Text,
  meta? : Map[String, Json],
  handlers? : Map[String, Json],
) -> Text {
  self.stylize(Style::on(meta?, handlers?))
  self
}

///|
/// Remove a suffix if it exists.
pub fn Text::remove_suffix(self : Text, suffix : String) -> Unit {
  if self.plain().has_suffix(suffix) {
    self.right_crop(amount=suffix.length())
  }
}

///|
/// Get the style of a character at the given offset.
pub fn Text::get_style_at_offset(
  self : Text,
  console : Console,
  offset : Int,
) -> Style raise {
  let offset = if offset < 0 { self.length_ + offset } else { offset }
  let mut style = console.get_style(self.style).copy()
  for span in self.spans_ {
    if span.end > offset && offset >= span.start {
      style = style + console.get_style(span.style, default=Def(""))
    }
  }
  style
}

///|
/// Extend the Text given number of spaces where the spaces have the same
/// style as the last character.
pub fn Text::extend_style(self : Text, spaces : Int) -> Unit {
  if spaces <= 0 {
    return
  }
  let new_spaces = " ".repeat(spaces)
  if !self.spans_.is_empty() {
    let end_offset = self.length_
    self.spans_ = self.spans_.map(span => {
      if span.end >= end_offset {
        span.extend(spaces)
      } else {
        span
      }
    })
    self.parts.push(new_spaces)
    self.length_ += spaces
  } else {
    self.set_plain(self.plain() + new_spaces)
  }
}

///|
let regex_cache : Map[(String, Int), @regex.Regex] = Map([])

///|
/// Compile a regular expression (Python `re` syntax), with caching.
pub fn compile_regex(
  pattern : String,
  flags? : Int = 0,
) -> @regex.Regex raise @regex.RegexError {
  let key = (pattern, flags)
  match regex_cache.get(key) {
    Some(re) => re
    None => {
      let re = @regex.compile(pattern, flags~)
      regex_cache[key] = re
      re
    }
  }
}

///|
/// Highlight text with a regular expression, where group names are
/// translated to styles. `style` applies to the whole match; `style_fn`
/// computes the whole-match style from the matched text. Returns the number
/// of matches.
pub fn Text::highlight_regex(
  self : Text,
  re_highlight : @regex.Regex,
  style? : &IntoStyle,
  style_fn? : (String) -> StyleType?,
  style_prefix? : String = "",
) -> Int raise @regex.RegexError {
  let mut count = 0
  let plain = self.plain()
  let names = re_highlight.group_names()
  let style = style_opt(style)
  for m in re_highlight.find_all(plain) {
    let start = m.start()
    let end = m.end()
    let match_style = match (style, style_fn) {
      (_, Some(f)) =>
        f(plain.view(start_offset=start, end_offset=end).to_owned())
      (Some(s), None) => if s.to_bool() { Some(s) } else { None }
      (None, None) => None
    }
    if match_style is Some(s) && end > start {
      self.spans_.push({ start, end, style: s, })
    }
    count += 1
    for name_index in names {
      let (name, index) = name_index
      let start = m.start(group=index)
      let end = m.end(group=index)
      if start != -1 && end > start {
        self.spans_.push({ start, end, style: Def(style_prefix + name), })
      }
    }
  }
  count
}

///|
/// Like `highlight_regex`, compiling `pattern` first.
pub fn Text::highlight_pattern(
  self : Text,
  pattern : String,
  style? : &IntoStyle,
  style_prefix? : String = "",
) -> Int raise @regex.RegexError {
  self.highlight_regex(compile_regex(pattern), style?, style_prefix~)
}

///|
/// Python `re.escape`.
pub fn regex_escape(s : String) -> String {
  let buf = StringBuilder()
  for c in s {
    let n = c.to_int()
    let special = n < 128 && !(c is ('a'..='z' | 'A'..='Z' | '0'..='9' | '_'))
    if special {
      buf.write_char('\\')
    }
    buf.write_char(c)
  }
  buf.to_string()
}

///|
/// Highlight words with a style. Returns the number of words highlighted.
pub fn Text::highlight_words(
  self : Text,
  words : ArrayView[String],
  style : &IntoStyle,
  case_sensitive? : Bool = true,
) -> Int raise @regex.RegexError {
  let re_words = words.map(regex_escape).join("|")
  let style = style.into_style_type()
  let re = compile_regex(
    re_words,
    flags=if case_sensitive { 0 } else { @regex.IGNORECASE },
  )
  let mut count = 0
  for m in re.find_all(self.plain()) {
    self.spans_.push({ start: m.start(), end: m.end(), style, })
    count += 1
  }
  count
}

///|
/// Python `str.rstrip()`.
fn py_rstrip(s : String) -> String {
  let mut end = s.length()
  while end > 0 && is_py_whitespace(s[end - 1].to_int().unsafe_to_char()) {
    end -= 1
  }
  if end == s.length() {
    s
  } else {
    s.view(end_offset=end).to_owned()
  }
}

///|
/// Strip whitespace from end of text.
pub fn Text::rstrip(self : Text) -> Unit {
  self.set_plain(py_rstrip(self.plain()))
}

///|
/// Remove whitespace beyond a certain width at the end of the text.
pub fn Text::rstrip_end(self : Text, size : Int) -> Unit {
  // upstream compares the length in code points with `size` (in cells)
  let text_length = self.plain().char_length()
  if text_length > size {
    let excess = text_length - size
    let plain = self.plain()
    let mut whitespace_count = 0
    while whitespace_count < plain.length() &&
          is_py_whitespace(
            plain[plain.length() - 1 - whitespace_count]
            .to_int()
            .unsafe_to_char(),
          ) {
      whitespace_count += 1
    }
    if whitespace_count > 0 {
      self.right_crop(amount=@cmp.minimum(whitespace_count, excess))
    }
  }
}

///|
/// Set new length of the text, clipping or padding as required.
pub fn Text::set_length(self : Text, new_length : Int) -> Unit {
  let length = self.length_
  if length != new_length {
    if length < new_length {
      self.pad_right(new_length - length)
    } else {
      self.right_crop(amount=length - new_length)
    }
  }
}

///|
pub impl Renderable for Text with fn rich_console(self, console, options) {
  let tab_size = match self.tab_size {
    None => console.tab_size
    Some(t) => t
  }
  let justify = self.justify.unwrap_or(options.justify.unwrap_or(Default))
  let overflow = self.overflow.unwrap_or(options.overflow.unwrap_or(Fold))
  let lines = self.wrap(
    console,
    options.max_width,
    justify~,
    overflow~,
    tab_size=if tab_size == 0 { 8 } else { tab_size },
    no_wrap=pick_bool([self.no_wrap, options.no_wrap, Some(false)]),
  )
  let all_lines = Text::new(text="\n").join(lines.lines)
  segments_to_items(all_lines.render(console, end=self.end))
}

///|
pub impl Renderable for Text with fn rich_measure(self, _console, _options) {
  let text = self.plain()
  let lines = py_splitlines(text)
  let mut max_text_width = 0
  for line in lines {
    max_text_width = @cmp.maximum(max_text_width, @cells.cell_len(line))
  }
  let words = split_words(text)
  let min_text_width = if words.is_empty() {
    max_text_width
  } else {
    let mut m = 0
    for word in words {
      m = @cmp.maximum(m, @cells.cell_len(word))
    }
    m
  }
  Some({ minimum: min_text_width, maximum: max_text_width, })
}

///|
pub impl Renderable for Text with fn text_kind(self) {
  Text(self)
}

///|
/// Python `str.splitlines()` (without keepends).
fn py_splitlines(s : String) -> Array[String] {
  let lines = []
  let buf = StringBuilder()
  let n = s.length()
  let mut i = 0
  let mut pending = false
  while i < n {
    let c = s[i].to_int()
    let is_break = c == 0x0a ||
      c == 0x0d ||
      c == 0x0b ||
      c == 0x0c ||
      c == 0x1c ||
      c == 0x1d ||
      c == 0x1e ||
      c == 0x85 ||
      c == 0x2028 ||
      c == 0x2029
    if is_break {
      lines.push(buf.to_string())
      buf.reset()
      pending = false
      if c == 0x0d && i + 1 < n && s[i + 1].to_int() == 0x0a {
        i += 1
      }
    } else {
      buf.write_char(c.unsafe_to_char())
      pending = true
    }
    i += 1
  }
  if pending {
    lines.push(buf.to_string())
  }
  lines
}

///|
/// Render the text as Segments.
pub fn Text::render(
  self : Text,
  console : Console,
  end? : String = "",
) -> Array[Segment] raise {
  let text = self.plain()
  let result = []
  if self.spans_.is_empty() {
    result.push(Segment::new(text))
    if end != "" {
      result.push(Segment::new(end))
    }
    return result
  }
  let null = Def("")
  let style_map : Map[Int, Style] = Map([])
  for i, span in self.spans_ {
    style_map[i + 1] = console.get_style(span.style, default=null)
  }
  style_map[0] = console.get_style(self.style, default=null)
  let spans : Array[(Int, Bool, Int)] = [(0, false, 0)]
  for i, span in self.spans_ {
    spans.push((span.start, false, i + 1))
  }
  for i, span in self.spans_ {
    spans.push((span.end, true, i + 1))
  }
  spans.push((text.length(), true, 0))
  stable_sort_by(spans, (a, b) => {
    let c = a.0.compare(b.0)
    if c != 0 {
      c
    } else {
      a.1.compare(b.1)
    }
  })
  let stack : Array[Int] = []
  let style_cache : Map[String, Style] = Map([])
  fn get_current_style() -> Style {
    let ids = stack.copy()
    ids.sort()
    let key = ids.map(i => i.to_string()).join(",")
    match style_cache.get(key) {
      Some(s) => s
      None => {
        let styles = ids.map(i => style_map[i])
        let s = Style::combine(styles)
        style_cache[key] = s
        s
      }
    }
  }

  for i in 0..<(spans.length() - 1) {
    let (offset, leaving, style_id) = spans[i]
    let next_offset = spans[i + 1].0
    if leaving {
      match stack.search(style_id) {
        Some(idx) => stack.remove(idx) |> ignore
        None => ()
      }
    } else {
      stack.push(style_id)
    }
    if next_offset > offset {
      result.push(
        Segment::new(
          text.view(start_offset=offset, end_offset=next_offset).to_owned(),
          style=get_current_style(),
        ),
      )
    }
  }
  if end != "" {
    result.push(Segment::new(end))
  }
  result
}

///|
/// Join texts together with this instance as the separator.
pub fn Text::join(self : Text, lines : ArrayView[Text]) -> Text {
  let new_text = self.blank_copy()
  let items : Array[Text] = []
  if self.plain() != "" {
    for i, line in lines {
      items.push(line)
      if i != lines.length() - 1 {
        items.push(self)
      }
    }
  } else {
    for line in lines {
      items.push(line)
    }
  }
  let mut offset = 0
  let new_parts = []
  for text in items {
    new_parts.push(text.plain())
    if text.style.to_bool() {
      new_text.spans_.push({
        start: offset,
        end: offset + text.length_,
        style: text.style,
      })
    }
    for span in text.spans_ {
      new_text.spans_.push({
        start: offset + span.start,
        end: offset + span.end,
        style: span.style,
      })
    }
    offset += text.length_
  }
  new_text.parts.append(new_parts)
  new_text.length_ = offset
  new_text
}

///|
/// Convert tabs to spaces.
pub fn Text::expand_tabs(self : Text, tab_size? : Int) -> Unit {
  if !self.plain().contains("\t") {
    return
  }
  let tab_size = match tab_size {
    Some(t) => t
    None => self.tab_size.unwrap_or(8)
  }
  let new_text : Array[Text] = []
  for line in self.split(separator="\n", include_separator=true).lines {
    if !line.plain().contains("\t") {
      new_text.push(line)
    } else {
      let mut cell_position = 0
      let parts = line.split(separator="\t", include_separator=true)
      for part in parts.lines {
        if part.plain().has_suffix("\t") {
          let last = part.parts[part.parts.length() - 1]
          part.parts[part.parts.length() - 1] = last
            .view(end_offset=last.length() - 1)
            .to_owned() +
            " "
          cell_position += part.cell_len()
          let tab_remainder = py_mod(cell_position, tab_size)
          if tab_remainder != 0 {
            let spaces = tab_size - tab_remainder
            part.extend_style(spaces)
            cell_position += spaces
          }
        } else {
          cell_position += part.cell_len()
        }
        new_text.push(part)
      }
    }
  }
  let result = Text::new().join(new_text)
  self.parts = [result.plain()]
  self.length_ = self.plain().length()
  self.spans_ = result.spans_.copy()
}

///|
/// Truncate text if it is longer than a given width.
pub fn Text::truncate(
  self : Text,
  max_width : Int,
  overflow? : OverflowMethod,
  pad? : Bool = false,
) -> Unit {
  let overflow = overflow.unwrap_or(self.overflow.unwrap_or(Fold))
  if overflow != Ignore {
    let length = @cells.cell_len(self.plain())
    if length > max_width {
      if overflow == Ellipsis {
        self.set_plain(
          @cells.set_cell_size(self.plain(), max_width - 1) + "…",
        )
      } else {
        self.set_plain(@cells.set_cell_size(self.plain(), max_width))
      }
    }
    if pad && length < max_width {
      let spaces = max_width - length
      self.parts = [self.plain() + " ".repeat(spaces)]
      self.length_ = self.plain().length()
    }
  }
}

///|
/// Remove or modify any spans that are over the end of the text.
fn Text::trim_spans(self : Text) -> Unit {
  let max_offset = self.plain().length()
  let spans = []
  for span in self.spans_ {
    if span.start < max_offset {
      spans.push(
        if span.end < max_offset {
          span
        } else {
          {
            start: span.start,
            end: @cmp.minimum(max_offset, span.end),
            style: span.style,
          }
        },
      )
    }
  }
  self.spans_ = spans
}

///|
/// Pad left and right with a given number of characters.
pub fn Text::pad(self : Text, count : Int, character? : Char = ' ') -> Unit {
  if count != 0 {
    let pad_characters = py_char_repeat(character, count)
    self.set_plain(pad_characters + self.plain() + pad_characters)
    let shift = count * char_utf16_len(character)
    self.spans_ = self.spans_.map(span => span.move(shift))
  }
}

///|
/// Python `character * count` (empty for negative counts).
fn py_char_repeat(character : Char, count : Int) -> String {
  if count <= 0 {
    ""
  } else {
    String::make(count, character)
  }
}

///|
fn char_utf16_len(c : Char) -> Int {
  if c.to_int() > 0xFFFF {
    2
  } else {
    1
  }
}

///|
/// Pad the left with a given character. As upstream, a negative `count`
/// adds nothing but still moves the spans.
pub fn Text::pad_left(
  self : Text,
  count : Int,
  character? : Char = ' ',
) -> Unit {
  if count != 0 {
    self.set_plain(py_char_repeat(character, count) + self.plain())
    let shift = count * char_utf16_len(character)
    self.spans_ = self.spans_.map(span => span.move(shift))
  }
}

///|
/// Pad the right with a given character.
pub fn Text::pad_right(
  self : Text,
  count : Int,
  character? : Char = ' ',
) -> Unit {
  if count != 0 {
    self.set_plain(self.plain() + py_char_repeat(character, count))
  }
}

///|
/// Align text to a given width.
pub fn Text::align(
  self : Text,
  align : AlignMethod,
  width : Int,
  character? : Char = ' ',
) -> Unit {
  self.truncate(width)
  let excess_space = width - @cells.cell_len(self.plain())
  if excess_space != 0 {
    match align {
      Left => self.pad_right(excess_space, character~)
      Center => {
        let left = floor_div(excess_space, 2)
        self.pad_left(left, character~)
        self.pad_right(excess_space - left, character~)
      }
      Right => self.pad_left(excess_space, character~)
    }
  }
}

///|
/// Append a string with an optional style.
pub fn Text::append_str(
  self : Text,
  text : String,
  style? : &IntoStyle,
) -> Text {
  if text.length() != 0 {
    let sanitized = strip_control_codes(text)
    self.parts.push(sanitized)
    let offset = self.length_
    let text_length = sanitized.length()
    match style_opt(style) {
      Some(s) if s.to_bool() =>
        self.spans_.push({ start: offset, end: offset + text_length, style: s, })
      _ => ()
    }
    self.length_ += text_length
  }
  self
}

///|
/// Append a string or Text, with an optional style (only for strings).
pub fn Text::append(
  self : Text,
  text : &IntoText,
  style? : &IntoStyle,
) -> Text raise RichError {
  match text.into_text_type() {
    Str(s) => self.append_str(s, style?)
    Text(t) => {
      if t.length_ == 0 {
        return self
      }
      if style is Some(_) {
        raise ValueError("style must not be set when appending Text instance")
      }
      self.append_text(t)
    }
  }
}

///|
/// Append another Text instance. Unlike `append`, an empty Text with a
/// style adds an empty span (as upstream).
pub fn Text::append_text(self : Text, text : Text) -> Text {
  let text_length = self.length_
  if text.style.to_bool() {
    self.spans_.push({
      start: text_length,
      end: text_length + text.length_,
      style: text.style,
    })
  }
  self.parts.push(text.plain())
  for span in text.spans_.copy() {
    self.spans_.push({
      start: span.start + text_length,
      end: span.end + text_length,
      style: span.style,
    })
  }
  self.length_ += text.length_
  self
}

///|
/// Append `(content, style)` tokens.
pub fn Text::append_tokens(
  self : Text,
  tokens : ArrayView[(String, StyleType?)],
) -> Text {
  let mut offset = self.length_
  for token in tokens {
    let content = strip_control_codes(token.0)
    self.parts.push(content)
    if token.1 is Some(style) && style.to_bool() {
      self.spans_.push({ start: offset, end: offset + content.length(), style, })
    }
    offset += content.length()
  }
  self.length_ = offset
  self
}

///|
/// Copy styles from another Text instance (must be the same length).
pub fn Text::copy_styles(self : Text, text : Text) -> Unit {
  self.spans_.append(text.spans_)
}

///|
fn find_all_str(text : String, sep : String) -> Array[(Int, Int)] {
  let out = []
  let mut pos = 0
  while pos <= text.length() {
    match text.view(start_offset=pos).find(sep) {
      Some(i) => {
        let start = pos + i
        out.push((start, start + sep.length()))
        pos = start + sep.length()
      }
      None => break
    }
  }
  out
}

///|
/// Split rich text in to lines, preserving styles.
pub fn Text::split(
  self : Text,
  separator? : String = "\n",
  include_separator? : Bool = false,
  allow_blank? : Bool = false,
) -> Lines {
  guard separator != "" else { abort("separator must not be empty") }
  let text = self.plain()
  if !text.contains(separator) {
    return Lines::new([self.copy()])
  }
  let matches = find_all_str(text, separator)
  let lines = if include_separator {
    self.divide(matches.map(m => m.1))
  } else {
    let offsets = []
    for m in matches {
      offsets.push(m.0)
      offsets.push(m.1)
    }
    Lines::new(
      self.divide(offsets).lines.filter(line => line.plain() != separator),
    )
  }
  if !allow_blank && text.has_suffix(separator) {
    lines.pop() |> ignore
  }
  lines
}

///|
/// Divide text into a number of lines at given offsets.
pub fn Text::divide(self : Text, offsets : ArrayView[Int]) -> Lines {
  if offsets.length() == 0 {
    return Lines::new([self.copy()])
  }
  let text = self.plain()
  let text_length = text.length()
  let divide_offsets = [0]
  for o in offsets {
    divide_offsets.push(o)
  }
  divide_offsets.push(text_length)
  let line_ranges = []
  for i in 0..<(divide_offsets.length() - 1) {
    line_ranges.push((divide_offsets[i], divide_offsets[i + 1]))
  }
  let new_lines = Lines::new(
    line_ranges.map(range => {
      Text::new(
        text=py_slice(text, range.0, range.1),
        style=self.style,
        justify?=self.justify,
        overflow?=self.overflow,
      )
    }),
  )
  if self.spans_.is_empty() {
    return new_lines
  }
  let line_count = line_ranges.length()
  for span in self.spans_ {
    let span_start = span.start
    let span_end = span.end
    let mut lower_bound = 0
    let mut upper_bound = line_count
    let mut start_line_no = floor_div(lower_bound + upper_bound, 2)
    let mut line_end = 0
    while true {
      let (line_start, le) = line_ranges[start_line_no]
      line_end = le
      if span_start < line_start {
        upper_bound = start_line_no - 1
      } else if span_start > line_end {
        lower_bound = start_line_no + 1
      } else {
        break
      }
      start_line_no = floor_div(lower_bound + upper_bound, 2)
    }
    let end_line_no = if span_end < line_end {
      start_line_no
    } else {
      let mut end_line_no = start_line_no
      lower_bound = start_line_no
      upper_bound = line_count
      while true {
        let (line_start, le) = line_ranges[end_line_no]
        if span_end < line_start {
          upper_bound = end_line_no - 1
        } else if span_end > le {
          lower_bound = end_line_no + 1
        } else {
          break
        }
        end_line_no = floor_div(lower_bound + upper_bound, 2)
      }
      end_line_no
    }
    for line_no in start_line_no..<=end_line_no {
      let (line_start, line_end) = line_ranges[line_no]
      let new_start = @cmp.maximum(0, span_start - line_start)
      let new_end = @cmp.minimum(span_end - line_start, line_end - line_start)
      if new_end > new_start {
        new_lines.lines[line_no].spans_.push({
          start: new_start,
          end: new_end,
          style: span.style,
        })
      }
    }
  }
  new_lines
}

///|
/// Python `s[a:b]` (with clamping of out-of-range and negative indices).
fn py_slice(s : String, a : Int, b : Int) -> String {
  let n = s.length()
  let a = if a < 0 { @cmp.maximum(0, n + a) } else { @cmp.minimum(a, n) }
  let b = if b < 0 { @cmp.maximum(0, n + b) } else { @cmp.minimum(b, n) }
  if a >= b {
    ""
  } else {
    s.view(start_offset=a, end_offset=b).to_owned()
  }
}

///|
/// Remove a number of characters from the end of the text.
pub fn Text::right_crop(self : Text, amount? : Int = 1) -> Unit {
  let plain = self.plain()
  let max_offset = plain.length() - amount
  let spans = []
  for span in self.spans_ {
    if span.start < max_offset {
      spans.push(
        if span.end < max_offset {
          span
        } else {
          {
            start: span.start,
            end: @cmp.minimum(max_offset, span.end),
            style: span.style,
          }
        },
      )
    }
  }
  self.spans_ = spans
  // Python `plain[:-amount]` (amount 0 gives an empty string)
  self.parts = [py_slice(plain, 0, -amount)]
  self.length_ -= amount
}

///|
/// Word wrap the text.
pub fn Text::wrap(
  self : Text,
  console : Console,
  width : Int,
  justify? : JustifyMethod,
  overflow? : OverflowMethod,
  tab_size? : Int = 8,
  no_wrap? : Bool,
) -> Lines raise {
  let wrap_justify = justify.unwrap_or(self.justify.unwrap_or(Default))
  let wrap_overflow = overflow.unwrap_or(self.overflow.unwrap_or(Fold))
  let no_wrap = pick_bool([no_wrap, self.no_wrap, Some(false)]) ||
    overflow is Some(Ignore)
  let lines = Lines::new([])
  for line in self.split(allow_blank=true).lines {
    if line.plain().contains("\t") {
      line.expand_tabs(tab_size~)
    }
    let new_lines = if no_wrap {
      if overflow is Some(Ignore) {
        lines.append(line)
        continue
      }
      Lines::new([line])
    } else {
      let offsets = divide_line(line.plain(), width, fold=wrap_overflow == Fold)
      let new_lines = line.divide(offsets)
      for l in new_lines.lines {
        l.rstrip_end(width)
      }
      new_lines
    }
    new_lines.justify(
      console,
      width,
      justify=wrap_justify,
      overflow=wrap_overflow,
    )
    for l in new_lines.lines {
      l.truncate(width, overflow=wrap_overflow)
    }
    lines.extend(new_lines.lines)
  }
  lines
}

///|
/// Fit the text in to given width by chopping in to lines.
pub fn Text::fit(self : Text, width : Int) -> Lines {
  let lines = Lines::new([])
  for line in self.split().lines {
    line.set_length(width)
    lines.append(line)
  }
  lines
}

///|
fn gcd(a : Int, b : Int) -> Int {
  let mut a = if a < 0 { -a } else { a }
  let mut b = if b < 0 { -b } else { b }
  while b != 0 {
    let t = a % b
    a = b
    b = t
  }
  a
}

///|
/// Auto-detect indentation of code.
pub fn Text::detect_indentation(self : Text) -> Int {
  let indentations : Map[Int, Unit] = Map([])
  for line in self.plain().split("\n") {
    let mut n = 0
    while n < line.length() && line[n] == ' ' {
      n += 1
    }
    indentations[n] = ()
  }
  let evens = []
  for indent, _ in indentations {
    if indent % 2 == 0 {
      evens.push(indent)
    }
  }
  if evens.is_empty() {
    return 1
  }
  let mut result = evens[0]
  for i in 1..<evens.length() {
    result = gcd(result, evens[i])
  }
  if result == 0 {
    1
  } else {
    result
  }
}

///|
/// The UTF-16 offset of the `n`th code point of `s` (clamped to the end).
fn utf16_offset_of_codepoint(s : String, n : Int) -> Int {
  let mut offset = 0
  let mut count = 0
  while count < n && offset < s.length() {
    let c = s[offset].to_int()
    offset += if c >= 0xD800 && c <= 0xDBFF && offset + 1 < s.length() {
      2
    } else {
      1
    }
    count += 1
  }
  offset
}

///|
/// Add indent guide lines to text.
pub fn Text::with_indent_guides(
  self : Text,
  indent_size? : Int,
  character? : String = "│",
  style? : &IntoStyle,
) -> Text {
  let style = match style {
    Some(s) => s.into_style_type()
    None => Def("dim green")
  }
  let indent_size = match indent_size {
    None => self.detect_indentation()
    Some(i) => i
  }
  let text = self.copy()
  text.expand_tabs()
  let indent_line = character + " ".repeat(indent_size - 1)
  let new_lines : Array[Text] = []
  let mut blank_lines = 0
  for line in text.split(allow_blank=true).lines {
    let plain = line.plain()
    let mut n = 0
    while n < plain.length() && plain[n] == ' ' {
      n += 1
    }
    if n == plain.length() {
      blank_lines += 1
      continue
    }
    let full_indents = n / indent_size
    let remaining_space = n % indent_size
    let new_indent = indent_line.repeat(full_indents) +
      " ".repeat(remaining_space)
    // upstream slices the line by the (code point) length of the new indent
    let skip = utf16_offset_of_codepoint(plain, new_indent.char_length())
    line.set_plain(new_indent + py_slice(plain, skip, plain.length()))
    line.stylize(style, start=0, end=new_indent.length())
    if blank_lines != 0 {
      for _ in 0..<blank_lines {
        new_lines.push(Text::new(text=new_indent, style~))
      }
      blank_lines = 0
    }
    new_lines.push(line)
  }
  if blank_lines != 0 {
    for _ in 0..<blank_lines {
      new_lines.push(Text::new(text="", style~))
    }
  }
  text.blank_copy(plain="\n").join(new_lines)
}
