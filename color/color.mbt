// Port of rich/color.py, rich/color_triplet.py, rich/palette.py and
// rich/terminal_theme.py.

///|
/// One of the color systems supported by terminals.
pub(all) enum ColorSystem {
  Standard
  EightBit
  Truecolor
  Windows
} derive(Eq, Hash, Compare, Debug)

///|
/// Upstream `int(ColorSystem.X)`.
pub fn ColorSystem::to_int(self : ColorSystem) -> Int {
  match self {
    Standard => 1
    EightBit => 2
    Truecolor => 3
    Windows => 4
  }
}

///|
/// Upstream `repr(ColorSystem.X)`, e.g. `"ColorSystem.TRUECOLOR"`.
pub impl Show for ColorSystem with fn output(self, logger) {
  logger.write_string(
    match self {
      Standard => "ColorSystem.STANDARD"
      EightBit => "ColorSystem.EIGHT_BIT"
      Truecolor => "ColorSystem.TRUECOLOR"
      Windows => "ColorSystem.WINDOWS"
    },
  )
}

///|
/// Type of color stored in `Color`.
pub(all) enum ColorType {
  Default
  Standard
  EightBit
  Truecolor
  Windows
} derive(Eq, Hash, Compare, Debug)

///|
pub fn ColorType::to_int(self : ColorType) -> Int {
  match self {
    Default => 0
    Standard => 1
    EightBit => 2
    Truecolor => 3
    Windows => 4
  }
}

///|
/// Upstream `ColorType.X.name`, e.g. `"EIGHT_BIT"`.
pub fn ColorType::name(self : ColorType) -> String {
  match self {
    Default => "DEFAULT"
    Standard => "STANDARD"
    EightBit => "EIGHT_BIT"
    Truecolor => "TRUECOLOR"
    Windows => "WINDOWS"
  }
}

///|
pub impl Show for ColorType with fn output(self, logger) {
  logger.write_string("ColorType." + self.name())
}

///|
/// The red, green, and blue components of a color (0–255 each).
pub(all) struct ColorTriplet {
  red : Int
  green : Int
  blue : Int
} derive(Eq, Hash, Compare, Debug)

///|
pub fn ColorTriplet::new(red : Int, green : Int, blue : Int) -> ColorTriplet {
  { red, green, blue, }
}

///|
fn hex_digit(d : Int) -> Char {
  if d < 10 {
    Int::unsafe_to_char('0'.to_int() + d)
  } else {
    Int::unsafe_to_char('a'.to_int() + d - 10)
  }
}

///|
/// Python's `f"{n:02x}"`.
fn hex2(n : Int) -> String {
  let buf = StringBuilder()
  let mut v = if n < 0 { -n } else { n }
  let chars = []
  while v > 0 {
    chars.push(hex_digit(v % 16))
    v = v / 16
  }
  while chars.length() < 2 {
    chars.push('0')
  }
  if n < 0 {
    buf.write_char('-')
  }
  chars.rev_each(c => buf.write_char(c))
  buf.to_string()
}

///|
/// The color in CSS style, e.g. `"#ff0000"`.
pub fn ColorTriplet::hex(self : ColorTriplet) -> String {
  "#" + hex2(self.red) + hex2(self.green) + hex2(self.blue)
}

///|
/// The color in RGB format, e.g. `"rgb(100,23,255)"`.
pub fn ColorTriplet::rgb(self : ColorTriplet) -> String {
  "rgb(\{self.red},\{self.green},\{self.blue})"
}

///|
/// Components as floats between 0 and 1.
pub fn ColorTriplet::normalized(
  self : ColorTriplet,
) -> (Double, Double, Double) {
  (
    self.red.to_double() / 255.0,
    self.green.to_double() / 255.0,
    self.blue.to_double() / 255.0,
  )
}

///|
/// Upstream `repr(ColorTriplet)`.
pub impl Show for ColorTriplet with fn output(self, logger) {
  logger.write_string(
    "ColorTriplet(red=\{self.red}, green=\{self.green}, blue=\{self.blue})",
  )
}

///|
/// A palette of available colors.
pub struct Palette {
  priv colors : Array[(Int, Int, Int)]
  priv cache : Map[(Int, Int, Int), Int]
}

///|
pub fn Palette::new(colors : Array[(Int, Int, Int)]) -> Palette {
  { colors, cache: Map([]), }
}

///|
pub fn Palette::length(self : Palette) -> Int {
  self.colors.length()
}

///|
pub fn Palette::at(self : Palette, number : Int) -> ColorTriplet {
  let (r, g, b) = self.colors[number]
  { red: r, green: g, blue: b, }
}

///|
pub fn Palette::colors(self : Palette) -> Array[(Int, Int, Int)] {
  self.colors.copy()
}

///|
/// Find a color from a palette that most closely matches a given color.
pub fn Palette::match_color(self : Palette, color : ColorTriplet) -> Int {
  let key = (color.red, color.green, color.blue)
  if self.cache.get(key) is Some(index) {
    return index
  }
  let red1 = color.red
  let green1 = color.green
  let blue1 = color.blue
  let mut min_index = 0
  let mut min_distance = 0
  for index, c in self.colors {
    let (red2, green2, blue2) = c
    let red_mean = floor_div(red1 + red2, 2)
    let red = red1 - red2
    let green = green1 - green2
    let blue = blue1 - blue2
    // sqrt is monotonic: comparing the squared distances picks the same index
    let distance = (((512 + red_mean) * red * red) >> 8) +
      4 * green * green +
      (((767 - red_mean) * blue * blue) >> 8)
    if index == 0 || distance < min_distance {
      min_distance = distance
      min_index = index
    }
  }
  self.cache[key] = min_index
  min_index
}

///|
fn floor_div(a : Int, b : Int) -> Int {
  let q = a / b
  if a % b != 0 && (a < 0) != (b < 0) {
    q - 1
  } else {
    q
  }
}

///|
/// A color theme used when exporting console content.
pub struct TerminalTheme {
  background_color : ColorTriplet
  foreground_color : ColorTriplet
  ansi_colors : Palette
}

///|
/// `normal` holds 8 normal intensity colors; `bright` the 8 bright ones (or
/// `normal` again when omitted).
pub fn TerminalTheme::new(
  background : (Int, Int, Int),
  foreground : (Int, Int, Int),
  normal : Array[(Int, Int, Int)],
  bright? : Array[(Int, Int, Int)],
) -> TerminalTheme {
  let colors = normal.copy()
  match bright {
    Some(b) if !b.is_empty() => colors.append(b)
    _ => colors.append(normal)
  }
  {
    background_color: {
      red: background.0,
      green: background.1,
      blue: background.2,
    },
    foreground_color: {
      red: foreground.0,
      green: foreground.1,
      blue: foreground.2,
    },
    ansi_colors: Palette::new(colors),
  }
}

///|
/// Error raised when a color definition can not be parsed.
pub suberror ColorParseError {
  ColorParseError(String)
} derive(Debug)

///|
pub impl Show for ColorParseError with fn output(self, logger) {
  match self {
    ColorParseError(message) => logger.write_string(message)
  }
}

///|
/// Terminal color definition.
pub(all) struct Color {
  /// The name of the color (typically the input to `Color::parse`).
  name : String
  /// The type of the color.
  type_ : ColorType
  /// The color number, if a standard color.
  number : Int?
  /// A triplet of color components, if an RGB color.
  triplet : ColorTriplet?
} derive(Eq, Hash, Debug)

///|
pub fn Color::new(
  name : String,
  type_ : ColorType,
  number? : Int,
  triplet? : ColorTriplet,
) -> Color {
  { name, type_, number, triplet, }
}

///|
/// Upstream `repr(Color)`, e.g.
/// `Color('red', ColorType.STANDARD, number=1)`.
pub impl Show for Color with fn output(self, logger) {
  logger.write_string("Color(")
  logger.write_string(py_repr_str(self.name))
  logger.write_string(", ")
  logger.write_string("ColorType." + self.type_.name())
  if self.number is Some(n) {
    logger.write_string(", number=\{n}")
  }
  if self.triplet is Some(t) {
    logger.write_string(", triplet=\{t}")
  }
  logger.write_string(")")
}

///|
/// Python `repr()` of a string (single quotes unless the string contains a
/// single quote and no double quote).
fn py_repr_str(s : String) -> String {
  let quote = if s.contains("'") && !s.contains("\"") { '"' } else { '\'' }
  let buf = StringBuilder()
  buf.write_char(quote)
  for c in s {
    match c {
      '\\' => buf.write_string("\\\\")
      '\n' => buf.write_string("\\n")
      '\r' => buf.write_string("\\r")
      '\t' => buf.write_string("\\t")
      _ =>
        if c == quote {
          buf.write_char('\\')
          buf.write_char(c)
        } else {
          buf.write_char(c)
        }
    }
  }
  buf.write_char(quote)
  buf.to_string()
}

///|
/// The native color system for this color.
pub fn Color::system(self : Color) -> ColorSystem {
  match self.type_ {
    Default | Standard => Standard
    EightBit => EightBit
    Truecolor => Truecolor
    Windows => Windows
  }
}

///|
/// Check if the color is ultimately defined by the system.
pub fn Color::is_system_defined(self : Color) -> Bool {
  !(self.system() is (EightBit | Truecolor))
}

///|
/// Check if the color is a default color.
pub fn Color::is_default(self : Color) -> Bool {
  self.type_ is Default
}

///|
/// Get an equivalent color triplet for this color.
pub fn Color::get_truecolor(
  self : Color,
  theme? : TerminalTheme,
  foreground? : Bool = true,
) -> ColorTriplet {
  let theme = theme.unwrap_or(default_terminal_theme)
  match self.type_ {
    Truecolor => self.triplet.unwrap()
    EightBit => eight_bit_palette.at(self.number.unwrap())
    Standard => theme.ansi_colors.at(self.number.unwrap())
    Windows => windows_palette.at(self.number.unwrap())
    Default =>
      if foreground {
        theme.foreground_color
      } else {
        theme.background_color
      }
  }
}

///|
/// Create a Color from its 8-bit ANSI number.
pub fn Color::from_ansi(number : Int) -> Color {
  {
    name: "color(\{number})",
    type_: if number < 16 {
      Standard
    } else {
      EightBit
    },
    number: Some(number),
    triplet: None,
  }
}

///|
/// Create a truecolor RGB color from a triplet of values.
pub fn Color::from_triplet(triplet : ColorTriplet) -> Color {
  {
    name: triplet.hex(),
    type_: Truecolor,
    number: None,
    triplet: Some(triplet),
  }
}

///|
/// Create a truecolor from three color components in the range 0–255.
/// Components are truncated towards zero like Python's `int()`.
pub fn Color::from_rgb(red : Double, green : Double, blue : Double) -> Color {
  Color::from_triplet({
    red: red.to_int(),
    green: green.to_int(),
    blue: blue.to_int(),
  })
}

///|
/// A Color instance representing the default color.
pub fn Color::default() -> Color {
  { name: "default", type_: Default, number: None, triplet: None, }
}

///|
let parse_cache : Map[String, Color] = Map([])

///|
/// Python `str.isspace()` for a single character (also what `\s` matches).
fn is_py_space(c : Char) -> Bool {
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
  let chars = s.to_array()
  let mut start = 0
  let mut end = chars.length()
  while start < end && is_py_space(chars[start]) {
    start += 1
  }
  while end > start && is_py_space(chars[end - 1]) {
    end -= 1
  }
  String::from_array(chars[start:end])
}

///|
/// The zero of each run of ten Unicode decimal digits (category Nd).
let decimal_zeros : FixedArray[Int] = [
  0x30, 0x660, 0x6F0, 0x7C0, 0x966, 0x9E6, 0xA66, 0xAE6, 0xB66, 0xBE6, 0xC66, 0xCE6,
  0xD66, 0xDE6, 0xE50, 0xED0, 0xF20, 0x1040, 0x1090, 0x17E0, 0x1810, 0x1946, 0x19D0,
  0x1A80, 0x1A90, 0x1B50, 0x1BB0, 0x1C40, 0x1C50, 0xA620, 0xA8D0, 0xA900, 0xA9D0,
  0xA9F0, 0xAA50, 0xABF0, 0xFF10, 0x104A0, 0x10D30, 0x10D40, 0x11066, 0x110F0, 0x11136,
  0x111D0, 0x112F0, 0x11450, 0x114D0, 0x11650, 0x116C0, 0x116D0, 0x116DA, 0x11730,
  0x118E0, 0x11950, 0x11BF0, 0x11C50, 0x11D50, 0x11DA0, 0x11F50, 0x16130, 0x16A60,
  0x16AC0, 0x16B50, 0x16D70, 0x1CCF0, 0x1D7CE, 0x1D7D8, 0x1D7E2, 0x1D7EC, 0x1D7F6,
  0x1E140, 0x1E2F0, 0x1E4F0, 0x1E5F1, 0x1E950, 0x1FBF0,
]

///|
/// The value of a Unicode decimal digit (what Python's `\d` matches and
/// `int()` accepts), or `None`.
fn decimal_value(c : Char) -> Int? {
  let n = c.to_int()
  for zero in decimal_zeros {
    if n >= zero && n < zero + 10 {
      return Some(n - zero)
    }
  }
  None
}

///|
/// Python `int(s, base)` for bases 10 and 16: surrounding whitespace, an
/// optional sign and single underscores between digits are allowed.
fn py_int_base(s : String, base : Int) -> Int? {
  let chars = py_strip(s).to_array()
  let mut i = 0
  let mut negative = false
  if i < chars.length() && chars[i] is ('+' | '-') {
    negative = chars[i] == '-'
    i += 1
  }
  if i >= chars.length() {
    return None
  }
  let mut value = 0
  let mut last_underscore = true
  while i < chars.length() {
    let c = chars[i]
    let digit = match c {
      '_' if !last_underscore => {
        last_underscore = true
        i += 1
        continue
      }
      'a'..='f' if base == 16 => c.to_int() - 'a'.to_int() + 10
      'A'..='F' if base == 16 => c.to_int() - 'A'.to_int() + 10
      _ =>
        match decimal_value(c) {
          Some(d) => d
          None => return None
        }
    }
    value = value * base + digit
    last_underscore = false
    i += 1
  }
  if last_underscore {
    return None
  }
  Some(if negative { -value } else { value })
}

///|
fn all_chars(s : StringView, pred : (Char) -> Bool) -> Bool {
  for c in s {
    if !pred(c) {
      return false
    }
  }
  true
}

///|
/// Python `int(s)` for decimal strings (surrounding whitespace allowed).
fn py_int(s : String) -> Int? {
  py_int_base(s, 10)
}

///|
fn hex_value(s : StringView) -> Int {
  let mut v = 0
  for c in s {
    let d = match c {
      '0'..='9' => c.to_int() - '0'.to_int()
      'a'..='f' => c.to_int() - 'a'.to_int() + 10
      'A'..='F' => c.to_int() - 'A'.to_int() + 10
      _ => 0
    }
    v = v * 16 + d
  }
  v
}

///|
/// Parse a color definition: a color name (`"red"`, `"bright_blue"`,
/// `"grey50"`), `"default"`, `"#rrggbb"`, `"color(N)"` or `"rgb(r,g,b)"`.
pub fn Color::parse(color : String) -> Color raise ColorParseError {
  if parse_cache.get(color) is Some(c) {
    return c
  }
  let result = parse_color(color)
  parse_cache[color] = result
  result
}

///|
fn parse_color(original_color : String) -> Color raise ColorParseError {
  let color = py_strip(@pystr.lower(original_color))
  if color == "default" {
    return { name: color, type_: Default, number: None, triplet: None, }
  }
  if ansi_color_names.get(color) is Some(color_number) {
    return {
      name: color,
      type_: if color_number < 16 {
        Standard
      } else {
        EightBit
      },
      number: Some(color_number),
      triplet: None,
    }
  }
  // RE_COLOR = ^\#([0-9a-f]{6})$|color\(([0-9]{1,3})\)$|rgb\(([\d\s,]+)\)$
  // (`$` also matches before a final newline)
  let body = match color.strip_suffix("\n") {
    Some(b) => b.to_owned()
    None => color
  }
  if body.strip_prefix("#") is Some(h) &&
    h.length() == 6 &&
    all_chars(h, c => c is ('0'..='9' | 'a'..='f')) {
    let triplet : ColorTriplet = {
      red: hex_value(h.view(start_offset=0, end_offset=2)),
      green: hex_value(h.view(start_offset=2, end_offset=4)),
      blue: hex_value(h.view(start_offset=4, end_offset=6)),
    }
    return {
      name: color,
      type_: Truecolor,
      number: None,
      triplet: Some(triplet),
    }
  }
  if body.strip_prefix("color(") is Some(rest) &&
    rest.strip_suffix(")") is Some(inner) {
    if inner.length() >= 1 &&
      inner.length() <= 3 &&
      all_chars(inner, c => c is ('0'..='9')) {
      let number = hex_free_int(inner)
      if number > 255 {
        raise ColorParseError(
          "color number must be <= 255 in \{py_repr_str(color)}",
        )
      }
      return {
        name: color,
        type_: if number < 16 {
          Standard
        } else {
          EightBit
        },
        number: Some(number),
        triplet: None,
      }
    }
  }
  if body.strip_prefix("rgb(") is Some(rest) &&
    rest.strip_suffix(")") is Some(inner) {
    if inner.length() >= 1 &&
      all_chars(inner, c => {
        c is ('0'..='9' | ',') || is_unicode_digit(c) || is_py_space(c)
      }) {
      let components = inner
        .to_owned()
        .split(",")
        .map(v => v.to_owned())
        .collect()
      if components.length() != 3 {
        raise ColorParseError(
          "expected three components in \{py_repr_str(original_color)}",
        )
      }
      let values = []
      for component in components {
        match py_int(component) {
          Some(v) => values.push(v)
          None =>
            raise ColorParseError(
              "invalid literal for int() with base 10: \{py_repr_str(component)}",
            )
        }
      }
      let triplet : ColorTriplet = {
        red: values[0],
        green: values[1],
        blue: values[2],
      }
      if values.iter().any(v => v > 255) {
        raise ColorParseError(
          "color components must be <= 255 in \{py_repr_str(original_color)}",
        )
      }
      return {
        name: color,
        type_: Truecolor,
        number: None,
        triplet: Some(triplet),
      }
    }
  }
  raise ColorParseError("\{py_repr_str(original_color)} is not a valid color")
}

///|
fn is_unicode_digit(c : Char) -> Bool {
  decimal_value(c) is Some(_)
}

///|
fn hex_free_int(s : StringView) -> Int {
  let mut v = 0
  for c in s {
    v = v * 10 + (c.to_int() - '0'.to_int())
  }
  v
}

///|
/// Get the ANSI escape codes for this color.
pub fn Color::get_ansi_codes(
  self : Color,
  foreground? : Bool = true,
) -> Array[String] {
  match self.type_ {
    Default => [if foreground { "39" } else { "49" }]
    Windows | Standard => {
      let number = self.number.unwrap()
      let (fore, back) = if number < 8 { (30, 40) } else { (82, 92) }
      [(if foreground { fore + number } else { back + number }).to_string()]
    }
    EightBit =>
      [
        if foreground {
          "38"
        } else {
          "48"
        },
        "5",
        self.number.unwrap().to_string(),
      ]
    Truecolor => {
      let t = self.triplet.unwrap()
      [
        if foreground {
          "38"
        } else {
          "48"
        },
        "2",
        t.red.to_string(),
        t.green.to_string(),
        t.blue.to_string(),
      ]
    }
  }
}

///|
/// Python's `round()` (round half to even) for a non-negative double.
pub fn py_round(x : Double) -> Int {
  let f = x.floor()
  let diff = x - f
  if diff > 0.5 {
    f.to_int() + 1
  } else if diff < 0.5 {
    f.to_int()
  } else if f.to_int() % 2 == 0 {
    f.to_int()
  } else {
    f.to_int() + 1
  }
}

///|
/// Python's `colorsys.rgb_to_hls`.
pub fn rgb_to_hls(
  r : Double,
  g : Double,
  b : Double,
) -> (Double, Double, Double) {
  let maxc = @cmp.maximum(r, @cmp.maximum(g, b))
  let minc = @cmp.minimum(r, @cmp.minimum(g, b))
  let sumc = maxc + minc
  let rangec = maxc - minc
  let l = sumc / 2.0
  if minc == maxc {
    return (0.0, l, 0.0)
  }
  let s = if l <= 0.5 { rangec / sumc } else { rangec / (2.0 - maxc - minc) }
  let rc = (maxc - r) / rangec
  let gc = (maxc - g) / rangec
  let bc = (maxc - b) / rangec
  let h = if r == maxc {
    bc - gc
  } else if g == maxc {
    2.0 + rc - bc
  } else {
    4.0 + gc - rc
  }
  let h = h / 6.0
  // Python's % on floats takes the sign of the divisor
  let h = h - (h / 1.0).floor()
  (h, l, s)
}

///|
/// Downgrade a color system to a system with fewer colors.
pub fn Color::downgrade(self : Color, system : ColorSystem) -> Color {
  if self.type_ is Default || self.type_.to_int() == system.to_int() {
    return self
  }
  match system {
    EightBit if self.system() is Truecolor => {
      let t = self.triplet.unwrap()
      let (r, g, b) = t.normalized()
      let (_, l, s) = rgb_to_hls(r, g, b)
      if s < 0.15 {
        let gray = py_round(l * 25.0)
        let color_number = if gray == 0 {
          16
        } else if gray == 25 {
          231
        } else {
          231 + gray
        }
        return {
          name: self.name,
          type_: EightBit,
          number: Some(color_number),
          triplet: None,
        }
      }
      fn six(v : Int) -> Double {
        if v < 95 {
          v.to_double() / 95.0
        } else {
          1.0 + (v - 95).to_double() / 40.0
        }
      }

      let color_number = 16 +
        36 * py_round(six(t.red)) +
        6 * py_round(six(t.green)) +
        py_round(six(t.blue))
      {
        name: self.name,
        type_: EightBit,
        number: Some(color_number),
        triplet: None,
      }
    }
    Standard => {
      let triplet = if self.system() is Truecolor {
        self.triplet.unwrap()
      } else {
        eight_bit_palette.at(self.number.unwrap())
      }
      let color_number = standard_palette.match_color(triplet)
      {
        name: self.name,
        type_: Standard,
        number: Some(color_number),
        triplet: None,
      }
    }
    Windows => {
      let triplet = if self.system() is Truecolor {
        self.triplet.unwrap()
      } else {
        let number = self.number.unwrap()
        if number < 16 {
          return {
            name: self.name,
            type_: Windows,
            number: Some(number),
            triplet: None,
          }
        }
        eight_bit_palette.at(number)
      }
      let color_number = windows_palette.match_color(triplet)
      {
        name: self.name,
        type_: Windows,
        number: Some(color_number),
        triplet: None,
      }
    }
    _ => self
  }
}

///|
/// Parse six hex characters in to an RGB triplet.
///
/// Aborts on invalid hex digits (upstream raises `ValueError`).
pub fn parse_rgb_hex(hex_color : String) -> ColorTriplet {
  guard hex_color.length() == 6 else { abort("must be 6 characters") }
  fn component(start : Int) -> Int {
    let s = hex_color.view(start_offset=start, end_offset=start + 2).to_owned()
    match py_int_base(s, 16) {
      Some(v) => v
      None => abort("invalid literal for int() with base 16: \{py_repr_str(s)}")
    }
  }

  { red: component(0), green: component(2), blue: component(4), }
}

///|
/// Blend one RGB color in to another.
pub fn blend_rgb(
  color1 : ColorTriplet,
  color2 : ColorTriplet,
  cross_fade? : Double = 0.5,
) -> ColorTriplet {
  fn mix(a : Int, b : Int) -> Int {
    (a.to_double() + (b - a).to_double() * cross_fade).to_int()
  }

  {
    red: mix(color1.red, color2.red),
    green: mix(color1.green, color2.green),
    blue: mix(color1.blue, color2.blue),
  }
}

///|
/// The value of a Unicode decimal digit (category Nd), as accepted by
/// Python's `int()`, e.g. `'٣'` → `Some(3)`.
pub fn unicode_decimal_value(c : Char) -> Int? {
  decimal_value(c)
}
