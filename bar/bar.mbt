// Port of rich/bar.py.

///|
/// Left-aligned block characters for 1/8 to 7/8 (the right-aligned
/// characters exist only for 1/8 and 4/8).
let begin_block_elements : Array[String] = [
  "█", "█", "█", "▐", "▐", "▐", "▕", "▕",
]

///|
let end_block_elements : Array[String] = [
  " ", "▏", "▎", "▍", "▌", "▋", "▊", "▉",
]

///|
let full_block : String = "█"

///|
/// A color or a color definition (upstream `Union[Color, str]`).
pub(open) trait IntoColor {
  fn into_color(Self) -> @color.Color raise @color.ColorParseError
}

///|
pub impl IntoColor for String with fn into_color(self) {
  @color.Color::parse(self)
}

///|
pub impl IntoColor for @color.Color with fn into_color(self) {
  self
}

///|
/// Renders a solid block bar.
pub(all) struct Bar {
  /// Value for the end of the bar.
  mut size : Double
  /// Begin point (between 0 and size, inclusive).
  mut begin : Double
  /// End point (between 0 and size, inclusive).
  mut end : Double
  /// Width of the bar, or `None` for maximum width.
  mut width : Int?
  mut style : @rich.Style
}

///|
/// Create a bar. `color` and `bgcolor` default to `"default"`.
pub fn Bar::new(
  size : Double,
  begin : Double,
  end : Double,
  width? : Int,
  color? : &IntoColor = "default",
  bgcolor? : &IntoColor = "default",
) -> Bar raise @color.ColorParseError {
  {
    size,
    begin: @cmp.maximum(begin, 0.0),
    end: @cmp.minimum(end, size),
    width,
    style: @rich.Style::new(
      color=color.into_color(),
      bgcolor=bgcolor.into_color(),
    ),
  }
}

///|
/// Python `repr` of a number that may have been an int: integral values
/// print without a fractional part.
fn num_repr(d : Double) -> String {
  if d == d.floor() && d.abs() < 1.0e15 {
    d.to_int64().to_string()
  } else {
    @rich.py_float_repr(d)
  }
}

///|
/// Upstream `repr(bar)`.
pub fn Bar::repr(self : Bar) -> String {
  "Bar(\{num_repr(self.size)}, \{num_repr(self.begin)}, \{num_repr(self.end)})"
}

///|
pub impl Show for Bar with fn output(self, logger) {
  logger.write_string(self.repr())
}

///|
pub impl @rich.Renderable for Bar with fn rich_console(self, _console, options) {
  let width = @cmp.minimum(
    self.width.unwrap_or(options.max_width),
    options.max_width,
  )
  if self.begin >= self.end {
    return [
      Seg(@rich.Segment::new(" ".repeat(width), style=self.style)),
      Seg(@rich.Segment::line()),
    ]
  }
  let w = width.to_double()
  let prefix_complete_eights = (w * 8.0 * self.begin / self.size).to_int()
  let prefix_bar_count = prefix_complete_eights / 8
  let prefix_eights_count = prefix_complete_eights % 8
  let body_complete_eights = (w * 8.0 * self.end / self.size).to_int()
  let body_bar_count = body_complete_eights / 8
  let body_eights_count = body_complete_eights % 8
  // When start and end fall into the same cell, we ideally should render
  // a symbol that's "center-aligned", but there is no good symbol in
  // Unicode. In this case, we fall back to right-aligned block symbol for
  // simplicity.
  let mut prefix = " ".repeat(prefix_bar_count)
  if prefix_eights_count != 0 {
    prefix += begin_block_elements[prefix_eights_count]
  }
  let mut body = full_block.repeat(body_bar_count)
  if body_eights_count != 0 {
    body += end_block_elements[body_eights_count]
  }
  let suffix = " ".repeat(width - body.length())
  let body_rest = if prefix.length() >= body.length() {
    ""
  } else {
    body.view(start_offset=prefix.length()).to_owned()
  }
  [
    Seg(@rich.Segment::new(prefix + body_rest + suffix, style=self.style)),
    Seg(@rich.Segment::line()),
  ]
}

///|
pub impl @rich.Renderable for Bar with fn rich_measure(self, _console, options) {
  match self.width {
    Some(w) => Some(@rich.Measurement::new(w, w))
    None => Some(@rich.Measurement::new(4, options.max_width))
  }
}
