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
fn is_py_space(c : Char) -> Bool {
  c is (' ' | '\t' | '\n' | '\r' | '\u{0b}' | '\u{0c}')
}

///|
fn py_strip(s : String) -> String {
  s.trim(chars=" \t\n\r\u{0b}\u{0c}").to_owned()
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
  let t = py_strip(s)
  if t == "" || !all_chars(t, c => c >= '0' && c <= '9') {
    return None
  }
  Some(@string.parse_int(t)) catch {
    _ => None
  }
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
  let color = py_strip(original_color.to_lower())
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
  let body = if color.has_suffix("\n") {
    color.view(end_offset=color.length() - 1).to_owned()
  } else {
    color
  }
  if body.length() == 7 &&
    body.has_prefix("#") &&
    all_chars(body.view(start_offset=1), c => c is ('0'..='9' | 'a'..='f')) {
    let h = body.view(start_offset=1)
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
  if body.has_prefix("color(") && body.has_suffix(")") {
    let inner = body.view(start_offset=6, end_offset=body.length() - 1)
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
  if body.has_prefix("rgb(") && body.has_suffix(")") {
    let inner = body.view(start_offset=4, end_offset=body.length() - 1)
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
fn is_unicode_digit(_c : Char) -> Bool {
  false
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
pub fn parse_rgb_hex(hex_color : String) -> ColorTriplet {
  guard hex_color.length() == 6 else { abort("must be 6 characters") }
  {
    red: hex_value(hex_color.view(start_offset=0, end_offset=2)),
    green: hex_value(hex_color.view(start_offset=2, end_offset=4)),
    blue: hex_value(hex_color.view(start_offset=4, end_offset=6)),
  }
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
