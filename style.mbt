// Port of rich/style.py.

///|
/// A terminal style: a color, a background color and a number of attributes
/// (bold, italic, ...). Attributes have three states: on (`Some(true)`), off
/// (`Some(false)`) or not set (`None`).
pub struct Style {
  priv color_ : @color.Color?
  priv bgcolor_ : @color.Color?
  priv attributes : Int
  priv set_attributes : Int
  priv link_ : String?
  priv link_id_ : String
  priv meta_ : Map[String, Json]?
  priv null : Bool
  /// Color system (`ColorSystem::to_int`) of `ansi_codes`, or -1.
  priv mut ansi_system : Int
  /// Cached SGR parameters for `ansi_system` (upstream `_ansi`).
  priv mut ansi_codes : String
  /// Cached hash of the compared fields, 0 when not computed yet.
  priv mut hash_ : Int
  priv mut definition : String?
}

///|
/// Bit numbers of the style attributes.
let attribute_names : FixedArray[String] = [
  "bold", "dim", "italic", "underline", "blink", "blink2", "reverse", "conceal",
  "strike", "underline2", "frame", "encircle", "overline",
]

///|
/// SGR parameter for each attribute bit.
let style_map : FixedArray[String] = [
  "1", "2", "3", "4", "5", "6", "7", "8", "9", "21", "51", "52", "53",
]

///|
/// Style attribute names accepted by `Style::parse`, and the bit they map to.
let style_attributes : Map[String, Int] = {
  "dim": 1,
  "d": 1,
  "bold": 0,
  "b": 0,
  "italic": 2,
  "i": 2,
  "underline": 3,
  "u": 3,
  "blink": 4,
  "blink2": 5,
  "reverse": 6,
  "r": 6,
  "conceal": 7,
  "c": 7,
  "strike": 8,
  "s": 8,
  "underline2": 9,
  "uu": 9,
  "frame": 10,
  "encircle": 11,
  "overline": 12,
  "o": 12,
}

///|
let id_counter : Ref[Int] = Ref(initial_link_id())

///|
fn initial_link_id() -> Int {
  // upstream starts from getrandbits(24)
  (@env.now() % 16777216UL).to_int()
}

///|
fn next_link_id() -> Int {
  let id = id_counter.val
  id_counter.val = id + 1
  id
}

///|
fn meta_hash(meta : Map[String, Json]?) -> String {
  match meta {
    None => ""
    Some(m) => {
      let h = Json::object(m).stringify().hash()
      h.to_string()
    }
  }
}

///|
/// Canonical text of the meta data (upstream compares pickled bytes, so key
/// order matters).
fn meta_key(meta : Map[String, Json]?) -> String {
  match meta {
    None => ""
    Some(m) => Json::object(m).stringify()
  }
}

///|
/// Deep copy JSON (objects and arrays are mutable).
fn json_deep_copy(j : Json) -> Json {
  match j {
    Array(items) => Json::array(items.map(json_deep_copy))
    Object(m) => {
      let copy : Map[String, Json] = Map([])
      for k, v in m {
        copy[k] = json_deep_copy(v)
      }
      Json::object(copy)
    }
    _ => j
  }
}

///|
fn meta_deep_copy(meta : Map[String, Json]?) -> Map[String, Json]? {
  match meta {
    None => None
    Some(m) => {
      let copy : Map[String, Json] = Map([])
      for k, v in m {
        copy[k] = json_deep_copy(v)
      }
      Some(copy)
    }
  }
}

///|
fn non_empty(s : String?) -> String? {
  match s {
    Some("") | None => None
    s => s
  }
}

///|
fn meta_truthy(meta : Map[String, Json]?) -> Bool {
  meta is Some(m) && !m.is_empty()
}

///|
fn make_style(
  color~ : @color.Color?,
  bgcolor~ : @color.Color?,
  attributes~ : Int,
  set_attributes~ : Int,
  link~ : String?,
  link_id~ : String,
  meta~ : Map[String, Json]?,
  null~ : Bool,
  definition? : String? = None,
) -> Style {
  {
    color_: color,
    bgcolor_: bgcolor,
    attributes,
    set_attributes,
    link_: link,
    link_id_: link_id,
    meta_: meta,
    null,
    ansi_system: -1,
    ansi_codes: "",
    hash_: 0,
    definition,
  }
}

///|
/// Create a new style.
pub fn Style::new(
  color? : @color.Color,
  bgcolor? : @color.Color,
  bold? : Bool,
  dim? : Bool,
  italic? : Bool,
  underline? : Bool,
  blink? : Bool,
  blink2? : Bool,
  reverse? : Bool,
  conceal? : Bool,
  strike? : Bool,
  underline2? : Bool,
  frame? : Bool,
  encircle? : Bool,
  overline? : Bool,
  link? : String,
  meta? : Map[String, Json],
) -> Style {
  let meta = meta_deep_copy(meta)
  let values = [
    bold, dim, italic, underline, blink, blink2, reverse, conceal, strike, underline2,
    frame, encircle, overline,
  ]
  let mut set_attributes = 0
  let mut attributes = 0
  for bit, v in values {
    if v is Some(on) {
      set_attributes = set_attributes | (1 << bit)
      if on {
        attributes = attributes | (1 << bit)
      }
    }
  }
  let link_id = if non_empty(link) is Some(_) || meta_truthy(meta) {
    "\{next_link_id()}\{meta_hash(meta)}"
  } else {
    ""
  }
  let null = !(set_attributes != 0 ||
    color is Some(_) ||
    bgcolor is Some(_) ||
    non_empty(link) is Some(_) ||
    meta_truthy(meta))
  make_style(
    color~,
    bgcolor~,
    attributes~,
    set_attributes~,
    link~,
    link_id~,
    meta~,
    null~,
  )
}

///|
let null_style : Style = Style::new()

///|
/// The "null" style, equivalent to `Style::new()`.
pub fn Style::null() -> Style {
  null_style
}

///|
/// Create a new style with colors and no attributes.
pub fn Style::from_color(
  color? : @color.Color,
  bgcolor? : @color.Color,
) -> Style {
  make_style(
    color~,
    bgcolor~,
    attributes=0,
    set_attributes=0,
    link=None,
    link_id="",
    meta=None,
    null=!(color is Some(_) || bgcolor is Some(_)),
  )
}

///|
/// Create a new style with meta data.
pub fn Style::from_meta(meta : Map[String, Json]?) -> Style {
  let meta = meta_deep_copy(meta)
  make_style(
    color=None,
    bgcolor=None,
    attributes=0,
    set_attributes=0,
    link=None,
    link_id="\{next_link_id()}\{meta_hash(meta)}",
    meta~,
    null=!meta_truthy(meta),
  )
}

///|
/// Create a blank style with meta information; each handler `key` is stored
/// as `"@key"`.
pub fn Style::on(
  meta? : Map[String, Json],
  handlers? : Map[String, Json],
) -> Style {
  let m : Map[String, Json] = match meta {
    Some(m) => m.copy()
    None => Map([])
  }
  if handlers is Some(h) {
    for k, v in h {
      m["@" + k] = v
    }
  }
  Style::from_meta(Some(m))
}

///|
fn Style::bit(self : Style, bit : Int) -> Bool? {
  if (self.set_attributes & (1 << bit)) != 0 {
    Some((self.attributes & (1 << bit)) != 0)
  } else {
    None
  }
}

///|
pub fn Style::bold(self : Style) -> Bool? {
  self.bit(0)
}

///|
pub fn Style::dim(self : Style) -> Bool? {
  self.bit(1)
}

///|
pub fn Style::italic(self : Style) -> Bool? {
  self.bit(2)
}

///|
pub fn Style::underline(self : Style) -> Bool? {
  self.bit(3)
}

///|
pub fn Style::blink(self : Style) -> Bool? {
  self.bit(4)
}

///|
pub fn Style::blink2(self : Style) -> Bool? {
  self.bit(5)
}

///|
pub fn Style::reverse(self : Style) -> Bool? {
  self.bit(6)
}

///|
pub fn Style::conceal(self : Style) -> Bool? {
  self.bit(7)
}

///|
pub fn Style::strike(self : Style) -> Bool? {
  self.bit(8)
}

///|
pub fn Style::underline2(self : Style) -> Bool? {
  self.bit(9)
}

///|
pub fn Style::frame(self : Style) -> Bool? {
  self.bit(10)
}

///|
pub fn Style::encircle(self : Style) -> Bool? {
  self.bit(11)
}

///|
pub fn Style::overline(self : Style) -> Bool? {
  self.bit(12)
}

///|
/// The foreground color, if set.
pub fn Style::color(self : Style) -> @color.Color? {
  self.color_
}

///|
/// The background color, if set.
pub fn Style::bgcolor(self : Style) -> @color.Color? {
  self.bgcolor_
}

///|
/// Link URL, if set.
pub fn Style::link(self : Style) -> String? {
  self.link_
}

///|
/// The link id, used in the ANSI code for links.
pub fn Style::link_id(self : Style) -> String {
  self.link_id_
}

///|
/// Meta information (empty if not set).
pub fn Style::meta(self : Style) -> Map[String, Json] {
  match meta_deep_copy(self.meta_) {
    Some(m) => m
    None => Map([])
  }
}

///|
/// A style is "null" if it has no attributes, colors, links or meta. This is
/// the negation of upstream's `bool(style)`.
pub fn Style::is_null(self : Style) -> Bool {
  self.null
}

///|
/// Upstream `bool(style)`.
pub fn Style::to_bool(self : Style) -> Bool {
  !self.null
}

///|
/// Check if the style specified a transparent background.
pub fn Style::transparent_background(self : Style) -> Bool {
  match self.bgcolor_ {
    None => true
    Some(c) => c.is_default()
  }
}

///|
/// A Style with background only.
pub fn Style::background_style(self : Style) -> Style {
  Style::new(bgcolor?=self.bgcolor_)
}

///|
/// Re-generate the style definition from attributes (upstream `str(style)`).
pub fn Style::to_definition(self : Style) -> String {
  if self.definition is Some(d) {
    return d
  }
  let attributes = []
  let bits = self.set_attributes
  for bit in 0..<13 {
    if (bits & (1 << bit)) != 0 {
      let name = attribute_names[bit]
      if (self.attributes & (1 << bit)) != 0 {
        attributes.push(name)
      } else {
        attributes.push("not " + name)
      }
    }
  }
  if self.color_ is Some(c) {
    attributes.push(c.name)
  }
  if self.bgcolor_ is Some(c) {
    attributes.push("on")
    attributes.push(c.name)
  }
  if non_empty(self.link_) is Some(link) {
    attributes.push("link")
    attributes.push(link)
  }
  let definition = if attributes.is_empty() {
    "none"
  } else {
    attributes.join(" ")
  }
  self.definition = Some(definition)
  definition
}

///|
/// `Show` gives the style definition, like upstream `str(style)`.
pub impl Show for Style with fn output(self, logger) {
  logger.write_string(self.to_definition())
}

///|
/// Upstream `repr(style)`, e.g. `Style(color=Color('red', ...), bold=True)`.
pub fn Style::repr(self : Style) -> String {
  let parts = []
  if self.color_ is Some(c) {
    parts.push("color=\{c}")
  }
  if self.bgcolor_ is Some(c) {
    parts.push("bgcolor=\{c}")
  }
  let order = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
  for bit in order {
    if self.bit(bit) is Some(v) {
      parts.push("\{attribute_names[bit]}=\{py_bool(v)}")
    }
  }
  if self.link_ is Some(link) {
    parts.push("link=\{py_repr(link)}")
  }
  if meta_truthy(self.meta_) {
    parts.push("meta=\{py_json_repr(Json::object(self.meta_.unwrap()))}")
  }
  "Style(" + parts.join(", ") + ")"
}

///|
fn color_key(c : @color.Color?) -> Int {
  match c {
    None => 0
    Some(c) => c.hash()
  }
}

///|
pub impl Eq for Style with fn equal(self, other) {
  physical_equal(self, other) ||
  (
    self.attributes == other.attributes &&
    self.set_attributes == other.set_attributes &&
    self.color_ == other.color_ &&
    self.bgcolor_ == other.bgcolor_ &&
    self.link_ == other.link_ &&
    meta_key(self.meta_) == meta_key(other.meta_)
  )
}

///|
pub impl Hash for Style with fn hash_combine(self, hasher) {
  hasher.combine(self.hash_value())
}

///|
/// Hash of the fields compared by `Eq`, computed once (styles are immutable).
fn Style::hash_value(self : Style) -> Int {
  if self.hash_ != 0 {
    return self.hash_
  }
  let hasher = Hasher()
  hasher.combine(color_key(self.color_))
  hasher.combine(color_key(self.bgcolor_))
  hasher.combine(self.attributes)
  hasher.combine(self.set_attributes)
  hasher.combine(self.link_.unwrap_or(""))
  hasher.combine(meta_key(self.meta_))
  let h = hasher.finalize()
  let h = if h == 0 { 1 } else { h }
  self.hash_ = h
  h
}

///|
/// Generate ANSI codes for this style.
fn Style::make_ansi_codes(
  self : Style,
  color_system : @color.ColorSystem,
) -> String {
  let key = color_system.to_int()
  if self.ansi_system == key {
    return self.ansi_codes
  }
  let sgr = []
  let attributes = self.attributes & self.set_attributes
  if attributes != 0 {
    for bit in 0..<13 {
      if (attributes & (1 << bit)) != 0 {
        sgr.push(style_map[bit])
      }
    }
  }
  if self.color_ is Some(c) {
    sgr.append(c.downgrade(color_system).get_ansi_codes())
  }
  if self.bgcolor_ is Some(c) {
    sgr.append(c.downgrade(color_system).get_ansi_codes(foreground=false))
  }
  let codes = sgr.join(";")
  self.ansi_system = key
  self.ansi_codes = codes
  codes
}

///|
let normalize_cache : @memo.Memo[String, String] = @memo.Memo::new(1024)

///|
/// Normalize a style definition so that styles with the same effect have
/// the same string representation.
pub fn Style::normalize(style : String) -> String {
  if normalize_cache.get(style) is Some(s) {
    return s
  }
  let result = Style::parse(style).to_definition() catch {
    _ => @pystr.lower(py_strip(style))
  }
  normalize_cache.set(style, result)
  result
}

///|
let parse_cache : @memo.Memo[String, Style] = @memo.Memo::new(4096)

///|
fn split_words(s : String) -> Array[String] {
  let words = []
  for_each_word(s, (start, end) => words.push(s.unsafe_substring(start~, end~)))
  words
}

///|
/// Call `f(start, end)` for each maximal run of non-whitespace code units
/// (Python `str.split()`; whitespace characters are all in the BMP, so
/// scanning UTF-16 code units is exact).
fn for_each_word(s : String, f : (Int, Int) -> Unit) -> Unit {
  let n = s.length()
  let mut i = 0
  while i < n {
    while i < n && is_py_space_unit(s.unsafe_get(i).to_int()) {
      i += 1
    }
    let start = i
    while i < n && !is_py_space_unit(s.unsafe_get(i).to_int()) {
      i += 1
    }
    if i > start {
      f(start, i)
    }
  }
}

///|
/// `is_py_whitespace` for a UTF-16 code unit (surrogates are not spaces).
fn is_py_space_unit(u : Int) -> Bool {
  if u < 0x80 {
    u == 0x20 || (u >= 0x09 && u <= 0x0d) || (u >= 0x1c && u <= 0x1f)
  } else {
    is_py_whitespace(u.unsafe_to_char())
  }
}

///|
/// Python `str.isspace()` for a single character.
fn is_py_whitespace(c : Char) -> Bool {
  match c {
    ' ' | '\t' | '\n' | '\r' | '\u{0b}' | '\u{0c}' => true
    '\u{1c}' | '\u{1d}' | '\u{1e}' | '\u{1f}' | '\u{85}' | '\u{a0}' => true
    '\u{1680}'
    | '\u{2028}'
    | '\u{2029}'
    | '\u{202f}'
    | '\u{205f}'
    | '\u{3000}' => true
    _ => c.to_int() >= 0x2000 && c.to_int() <= 0x200a
  }
}

///|
/// Python `str.strip()`.
fn py_strip(s : String) -> String {
  let mut start = 0
  let mut end = s.length()
  while start < end && is_py_space_unit(s.unsafe_get(start).to_int()) {
    start += 1
  }
  while end > start && is_py_space_unit(s.unsafe_get(end - 1).to_int()) {
    end -= 1
  }
  if start == 0 && end == s.length() {
    s
  } else {
    s.unsafe_substring(start~, end~)
  }
}

///|
/// Parse a style definition such as `"bold red on white"`.
pub fn Style::parse(style_definition : String) -> Style raise RichError {
  if parse_cache.get(style_definition) is Some(s) {
    return s
  }
  let style = parse_style(style_definition)
  parse_cache.set(style_definition, style)
  style
}

///|
fn parse_style(style_definition : String) -> Style raise RichError {
  if py_strip(style_definition) == "none" || style_definition == "" {
    return Style::null()
  }
  let mut color : @color.Color? = None
  let mut bgcolor : @color.Color? = None
  let mut attributes = 0
  let mut set_attributes = 0
  let mut link : String? = None
  let words = split_words(style_definition)
  let mut i = 0
  fn next_word() -> String {
    if i < words.length() {
      let w = words[i]
      i += 1
      w
    } else {
      ""
    }
  }

  while i < words.length() {
    let original_word = next_word()
    let word = @pystr.lower(original_word)
    if word == "on" {
      let word = next_word()
      if word == "" {
        raise StyleSyntaxError("color expected after 'on'")
      }
      let c = @color.Color::parse(word) catch {
        e =>
          raise StyleSyntaxError(
            "unable to parse \{py_repr(word)} as background color; \{e}",
          )
      }
      bgcolor = Some(c)
    } else if word == "not" {
      let word = next_word()
      match style_attributes.get(word) {
        None =>
          raise StyleSyntaxError(
            "expected style attribute after 'not', found \{py_repr(word)}",
          )
        Some(bit) => {
          set_attributes = set_attributes | (1 << bit)
          attributes = attributes & (1 << bit).lnot()
        }
      }
    } else if word == "link" {
      let word = next_word()
      if word == "" {
        raise StyleSyntaxError("URL expected after 'link'")
      }
      link = Some(word)
    } else if style_attributes.get(word) is Some(bit) {
      set_attributes = set_attributes | (1 << bit)
      attributes = attributes | (1 << bit)
    } else {
      let c = @color.Color::parse(word) catch {
        e =>
          raise StyleSyntaxError(
            "unable to parse \{py_repr(word)} as color; \{e}",
          )
      }
      color = Some(c)
    }
  }
  let link_id = if non_empty(link) is Some(_) {
    "\{next_link_id()}"
  } else {
    ""
  }
  make_style(
    color~,
    bgcolor~,
    attributes~,
    set_attributes~,
    link~,
    link_id~,
    meta=None,
    null=!(set_attributes != 0 ||
      color is Some(_) ||
      bgcolor is Some(_) ||
      non_empty(link) is Some(_)),
  )
}

///|
/// Get a CSS style rule.
pub fn Style::get_html_style(
  self : Style,
  theme? : @color.TerminalTheme,
) -> String {
  let theme = theme.unwrap_or(@color.default_terminal_theme)
  let css = []
  let mut color = self.color_
  let mut bgcolor = self.bgcolor_
  if self.reverse() is Some(true) {
    let tmp = color
    color = bgcolor
    bgcolor = tmp
  }
  if self.dim() is Some(true) {
    let foreground_color = match color {
      None => theme.foreground_color
      Some(c) => c.get_truecolor(theme~)
    }
    color = Some(
      @color.Color::from_triplet(
        @color.blend_rgb(
          foreground_color,
          theme.background_color,
          cross_fade=0.5,
        ),
      ),
    )
  }
  if color is Some(c) {
    let theme_color = c.get_truecolor(theme~)
    css.push("color: \{theme_color.hex()}")
    css.push("text-decoration-color: \{theme_color.hex()}")
  }
  if bgcolor is Some(c) {
    let theme_color = c.get_truecolor(theme~, foreground=false)
    css.push("background-color: \{theme_color.hex()}")
  }
  if self.bold() is Some(true) {
    css.push("font-weight: bold")
  }
  if self.italic() is Some(true) {
    css.push("font-style: italic")
  }
  if self.underline() is Some(true) {
    css.push("text-decoration: underline")
  }
  if self.strike() is Some(true) {
    css.push("text-decoration: line-through")
  }
  if self.overline() is Some(true) {
    css.push("text-decoration: overline")
  }
  css.join("; ")
}

///|
/// Combine styles from left to right.
pub fn Style::combine(styles : ArrayView[Style]) -> Style {
  guard styles is [first, .. rest] else { abort("expected at least one style") }
  let mut result = first
  for s in rest {
    result = result + s
  }
  result
}

///|
/// Combine styles from left to right (upstream `Style.chain(*styles)`).
pub fn Style::chain(styles : Array[Style]) -> Style {
  Style::combine(styles)
}

///|
/// Get a copy of this style (links get a new link id).
pub fn Style::copy(self : Style) -> Style {
  if self.null {
    return null_style
  }
  let style = make_style(
    color=self.color_,
    bgcolor=self.bgcolor_,
    attributes=self.attributes,
    set_attributes=self.set_attributes,
    link=self.link_,
    link_id=if non_empty(self.link_) is Some(_) {
      "\{next_link_id()}"
    } else {
      ""
    },
    meta=self.meta_,
    null=false,
    definition=self.definition,
  )
  style.ansi_system = self.ansi_system
  style.ansi_codes = self.ansi_codes
  style
}

///|
/// `copy()` for internal callers that do not depend on the copy being a
/// distinct object: styles are immutable, so without a link (id) the copy
/// would be indistinguishable from `self`.
fn Style::copy_value(self : Style) -> Style {
  if self.link_id_ == "" && non_empty(self.link_) is None {
    self
  } else {
    self.copy()
  }
}

///|
/// Get a copy of the style with color removed.
pub fn Style::without_color(self : Style) -> Style {
  if self.null {
    return null_style
  }
  make_style(
    color=None,
    bgcolor=None,
    attributes=self.attributes,
    set_attributes=self.set_attributes,
    link=self.link_,
    link_id=if non_empty(self.link_) is Some(_) {
      "\{next_link_id()}"
    } else {
      ""
    },
    meta=None,
    null=false,
  )
}

///|
/// Get a copy of this style with link and meta information removed.
pub fn Style::clear_meta_and_links(self : Style) -> Style {
  if self.null {
    return null_style
  }
  let style = make_style(
    color=self.color_,
    bgcolor=self.bgcolor_,
    attributes=self.attributes,
    set_attributes=self.set_attributes,
    link=None,
    link_id="",
    meta=None,
    null=false,
    // the cached definition mentions the link: do not reuse it (upstream does)
  )
  style.ansi_system = self.ansi_system
  style.ansi_codes = self.ansi_codes
  style
}

///|
/// Get a copy with a different value for link.
pub fn Style::update_link(self : Style, link : String?) -> Style {
  let style = make_style(
    color=self.color_,
    bgcolor=self.bgcolor_,
    attributes=self.attributes,
    set_attributes=self.set_attributes,
    link~,
    link_id=if non_empty(link) is Some(_) { "\{next_link_id()}" } else { "" },
    meta=self.meta_,
    null=false,
    // the cached definition mentions the link: do not reuse it (upstream does)
  )
  style.ansi_system = self.ansi_system
  style.ansi_codes = self.ansi_codes
  style
}

///|
/// Render the ANSI codes for the style around `text`. With `color_system`
/// `None` the text is returned unstyled.
pub fn Style::render(
  self : Style,
  text? : String = "",
  color_system? : @color.ColorSystem? = Some(Truecolor),
  legacy_windows? : Bool = false,
) -> String {
  guard text != "" && color_system is Some(color_system) else { return text }
  let attrs = self.make_ansi_codes(color_system)
  let rendered = if attrs != "" {
    "\u{1b}[\{attrs}m\{text}\u{1b}[0m"
  } else {
    text
  }
  match non_empty(self.link_) {
    Some(link) if !legacy_windows =>
      "\u{1b}]8;id=\{self.link_id_};\{link}\u{1b}\\\{rendered}\u{1b}]8;;\u{1b}\\"
    _ => rendered
  }
}

///|
fn Style::add_style(self : Style, style : Style) -> Style {
  if style.null {
    return self
  }
  if self.null {
    return style
  }
  // Without meta the result only depends on the fields compared by `Eq`
  // (and is copied by `+` when it has a link), so it can be memoized like
  // upstream's `lru_cache`d `_add`.
  if self.meta_ is None && style.meta_ is None {
    let key = (self, style)
    match add_cache.get(key) {
      Some(combined) => return combined
      None => {
        let combined = self.add_style_uncached(style)
        add_cache.set(key, combined)
        return combined
      }
    }
  }
  self.add_style_uncached(style)
}

///|
/// Memo table of `Style::add_style` (upstream `lru_cache(maxsize=1024)`).
let add_cache : @memo.Memo[(Style, Style), Style] = @memo.Memo::new(1024)

///|
fn Style::add_style_uncached(self : Style, style : Style) -> Style {
  let meta = if meta_truthy(self.meta_) && meta_truthy(style.meta_) {
    let m = self.meta_.unwrap().copy()
    for k, v in style.meta_.unwrap() {
      m[k] = v
    }
    Some(m)
  } else if meta_truthy(self.meta_) {
    self.meta_
  } else if meta_truthy(style.meta_) {
    style.meta_
  } else {
    // `self._meta or style._meta`: an empty meta is still a value
    match self.meta_ {
      Some(m) if !m.is_empty() => self.meta_
      _ => style.meta_
    }
  }
  make_style(
    color=match style.color_ {
      Some(_) => style.color_
      None => self.color_
    },
    bgcolor=match style.bgcolor_ {
      Some(_) => style.bgcolor_
      None => self.bgcolor_
    },
    attributes=(self.attributes & style.set_attributes.lnot()) |
      (style.attributes & style.set_attributes),
    set_attributes=self.set_attributes | style.set_attributes,
    link=match non_empty(style.link_) {
      Some(_) => style.link_
      None => self.link_
    },
    link_id=if style.link_id_ != "" { style.link_id_ } else { self.link_id_ },
    meta~,
    null=false,
  )
}

///|
/// Combine two styles; attributes of `other` take precedence.
pub impl Add for Style with fn add(self, other) {
  let combined = self.add_style(other)
  if non_empty(combined.link_) is Some(_) {
    combined.copy()
  } else {
    combined
  }
}

///|
/// Combine with an optional style (upstream `style + None`).
pub fn Style::add_opt(self : Style, other : Style?) -> Style {
  match other {
    None => self
    Some(other) => self + other
  }
}

///|
/// Pick the first non-`None` style (upstream `Style.pick_first`).
pub fn Style::pick_first(
  values : ArrayView[StyleType?],
) -> StyleType raise RichError {
  for value in values {
    if value is Some(v) {
      return v
    }
  }
  raise ValueError("expected at least one non-None style")
}

///|
/// Upstream `repr(stack)`.
pub fn StyleStack::repr(self : StyleStack) -> String {
  "<stylestack [" + self.stack.map(s => s.repr()).join(", ") + "]>"
}

///|
/// A stack of styles.
pub struct StyleStack {
  priv stack : Array[Style]
}

///|
pub fn StyleStack::new(default_style : Style) -> StyleStack {
  { stack: [default_style], }
}

///|
/// The Style at the top of the stack.
pub fn StyleStack::current(self : StyleStack) -> Style {
  self.stack[self.stack.length() - 1]
}

///|
/// Push a new style on to the stack, combined with the current style.
pub fn StyleStack::push(self : StyleStack, style : Style) -> Unit {
  self.stack.push(self.current() + style)
}

///|
/// Pop the last style and return the new current style.
pub fn StyleStack::pop(self : StyleStack) -> Style {
  ignore(self.stack.pop())
  self.current()
}
