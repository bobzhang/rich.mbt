// Port of rich/box.py.

///|
/// Defines characters to render boxes.
///
///     ┌─┬┐ top
///     │ ││ head
///     ├─┼┤ head_row
///     │ ││ mid
///     ├─┼┤ row
///     ├─┼┤ foot_row
///     │ ││ foot
///     └─┴┘ bottom
pub struct Box {
  /// Name of a built-in box (used for substitutions), or "".
  name : String
  box_ : String
  ascii : Bool
  top_left : String
  top : String
  top_divider : String
  top_right : String
  head_left : String
  head_vertical : String
  head_right : String
  head_row_left : String
  head_row_horizontal : String
  head_row_cross : String
  head_row_right : String
  mid_left : String
  mid_vertical : String
  mid_right : String
  row_left : String
  row_horizontal : String
  row_cross : String
  row_right : String
  foot_row_left : String
  foot_row_horizontal : String
  foot_row_cross : String
  foot_row_right : String
  foot_left : String
  foot_vertical : String
  foot_right : String
  bottom_left : String
  bottom : String
  bottom_divider : String
  bottom_right : String
}

///|
/// Create a box from 8 lines of 4 characters.
pub fn Box::new(
  box_ : String,
  ascii? : Bool = false,
  name? : String = "",
) -> Box raise RichError {
  let lines = py_splitlines(box_)
  guard lines.length() == 8 else { raise ValueError("box must have 8 lines") }
  let chars = lines.map(l => l.iter().map(c => c.to_string()).collect())
  for line in chars {
    guard line.length() == 4 else {
      raise ValueError("box lines must have 4 characters")
    }
  }
  {
    name,
    box_,
    ascii,
    top_left: chars[0][0],
    top: chars[0][1],
    top_divider: chars[0][2],
    top_right: chars[0][3],
    head_left: chars[1][0],
    head_vertical: chars[1][2],
    head_right: chars[1][3],
    head_row_left: chars[2][0],
    head_row_horizontal: chars[2][1],
    head_row_cross: chars[2][2],
    head_row_right: chars[2][3],
    mid_left: chars[3][0],
    mid_vertical: chars[3][2],
    mid_right: chars[3][3],
    row_left: chars[4][0],
    row_horizontal: chars[4][1],
    row_cross: chars[4][2],
    row_right: chars[4][3],
    foot_row_left: chars[5][0],
    foot_row_horizontal: chars[5][1],
    foot_row_cross: chars[5][2],
    foot_row_right: chars[5][3],
    foot_left: chars[6][0],
    foot_vertical: chars[6][2],
    foot_right: chars[6][3],
    bottom_left: chars[7][0],
    bottom: chars[7][1],
    bottom_divider: chars[7][2],
    bottom_right: chars[7][3],
  }
}

///|
fn builtin_box(name : String, box_ : String, ascii? : Bool = false) -> Box {
  Box::new(box_, ascii~, name~) catch {
    _ => abort("bad box")
  }
}

///|
pub impl Show for Box with fn output(self, logger) {
  logger.write_string(self.box_)
}

///|
/// Substitute this box for another if it won't render due to platform
/// issues.
pub fn Box::substitute(
  self : Box,
  options : ConsoleOptions,
  safe? : Bool = true,
) -> Box {
  let mut box_ = self
  if options.legacy_windows && safe {
    box_ = match box_.name {
      "ROUNDED" => box_square
      "MINIMAL_HEAVY_HEAD" => box_minimal
      "SIMPLE_HEAVY" => box_simple
      "HEAVY" => box_square
      "HEAVY_EDGE" => box_square
      "HEAVY_HEAD" => box_square
      _ => box_
    }
  }
  if options.ascii_only() && !box_.ascii {
    box_ = box_ascii
  }
  box_
}

///|
/// If this box uses special characters for the borders of the header,
/// return the equivalent box that does not.
pub fn Box::get_plain_headed_box(self : Box) -> Box {
  match self.name {
    "HEAVY_HEAD" => box_square
    "SQUARE_DOUBLE_HEAD" => box_square
    "MINIMAL_DOUBLE_HEAD" => box_minimal
    "MINIMAL_HEAVY_HEAD" => box_minimal
    "ASCII_DOUBLE_HEAD" => box_ascii2
    _ => self
  }
}

///|
/// Get the top of a simple box.
pub fn Box::get_top(self : Box, widths : ArrayView[Int]) -> String {
  let parts = StringBuilder()
  parts.write_string(self.top_left)
  for i, width in widths {
    parts.write_string(self.top.repeat(width))
    if i != widths.length() - 1 {
      parts.write_string(self.top_divider)
    }
  }
  parts.write_string(self.top_right)
  parts.to_string()
}

///|
/// Row levels for `Box::get_row`.
pub(all) enum RowLevel {
  Head
  Row
  Foot
  Mid
} derive(Eq, Debug)

///|
/// Get the top of a simple box.
pub fn Box::get_row(
  self : Box,
  widths : ArrayView[Int],
  level? : RowLevel = Row,
  edge? : Bool = true,
) -> String {
  let (left, horizontal, cross, right) = match level {
    Head =>
      (
        self.head_row_left,
        self.head_row_horizontal,
        self.head_row_cross,
        self.head_row_right,
      )
    Row => (self.row_left, self.row_horizontal, self.row_cross, self.row_right)
    Mid => (self.mid_left, " ", self.mid_vertical, self.mid_right)
    Foot =>
      (
        self.foot_row_left,
        self.foot_row_horizontal,
        self.foot_row_cross,
        self.foot_row_right,
      )
  }
  let parts = StringBuilder()
  if edge {
    parts.write_string(left)
  }
  for i, width in widths {
    parts.write_string(horizontal.repeat(width))
    if i != widths.length() - 1 {
      parts.write_string(cross)
    }
  }
  if edge {
    parts.write_string(right)
  }
  parts.to_string()
}

///|
/// Get the bottom of a simple box.
pub fn Box::get_bottom(self : Box, widths : ArrayView[Int]) -> String {
  let parts = StringBuilder()
  parts.write_string(self.bottom_left)
  for i, width in widths {
    parts.write_string(self.bottom.repeat(width))
    if i != widths.length() - 1 {
      parts.write_string(self.bottom_divider)
    }
  }
  parts.write_string(self.bottom_right)
  parts.to_string()
}

///|
pub let box_ascii : Box = builtin_box(
  "ASCII",
  "+--+\n| ||\n|-+|\n| ||\n|-+|\n|-+|\n| ||\n+--+\n",
  ascii=true,
)

///|
pub let box_ascii2 : Box = builtin_box(
  "ASCII2",
  "+-++\n| ||\n+-++\n| ||\n+-++\n+-++\n| ||\n+-++\n",
  ascii=true,
)

///|
pub let box_ascii_double_head : Box = builtin_box(
  "ASCII_DOUBLE_HEAD",
  "+-++\n| ||\n+=++\n| ||\n+-++\n+-++\n| ||\n+-++\n",
  ascii=true,
)

///|
pub let box_square : Box = builtin_box(
  "SQUARE", "┌─┬┐\n│ ││\n├─┼┤\n│ ││\n├─┼┤\n├─┼┤\n│ ││\n└─┴┘\n",
)

///|
pub let box_square_double_head : Box = builtin_box(
  "SQUARE_DOUBLE_HEAD", "┌─┬┐\n│ ││\n╞═╪╡\n│ ││\n├─┼┤\n├─┼┤\n│ ││\n└─┴┘\n",
)

///|
pub let box_minimal : Box = builtin_box(
  "MINIMAL", "  ╷ \n  │ \n╶─┼╴\n  │ \n╶─┼╴\n╶─┼╴\n  │ \n  ╵ \n",
)

///|
pub let box_minimal_heavy_head : Box = builtin_box(
  "MINIMAL_HEAVY_HEAD", "  ╷ \n  │ \n╺━┿╸\n  │ \n╶─┼╴\n╶─┼╴\n  │ \n  ╵ \n",
)

///|
pub let box_minimal_double_head : Box = builtin_box(
  "MINIMAL_DOUBLE_HEAD", "  ╷ \n  │ \n ═╪ \n  │ \n ─┼ \n ─┼ \n  │ \n  ╵ \n",
)

///|
pub let box_simple : Box = builtin_box(
  "SIMPLE", "    \n    \n ── \n    \n    \n ── \n    \n    \n",
)

///|
pub let box_simple_head : Box = builtin_box(
  "SIMPLE_HEAD", "    \n    \n ── \n    \n    \n    \n    \n    \n",
)

///|
pub let box_simple_heavy : Box = builtin_box(
  "SIMPLE_HEAVY", "    \n    \n ━━ \n    \n    \n ━━ \n    \n    \n",
)

///|
pub let box_horizontals : Box = builtin_box(
  "HORIZONTALS", " ── \n    \n ── \n    \n ── \n ── \n    \n ── \n",
)

///|
pub let box_rounded : Box = builtin_box(
  "ROUNDED", "╭─┬╮\n│ ││\n├─┼┤\n│ ││\n├─┼┤\n├─┼┤\n│ ││\n╰─┴╯\n",
)

///|
pub let box_heavy : Box = builtin_box(
  "HEAVY", "┏━┳┓\n┃ ┃┃\n┣━╋┫\n┃ ┃┃\n┣━╋┫\n┣━╋┫\n┃ ┃┃\n┗━┻┛\n",
)

///|
pub let box_heavy_edge : Box = builtin_box(
  "HEAVY_EDGE", "┏━┯┓\n┃ │┃\n┠─┼┨\n┃ │┃\n┠─┼┨\n┠─┼┨\n┃ │┃\n┗━┷┛\n",
)

///|
pub let box_heavy_head : Box = builtin_box(
  "HEAVY_HEAD", "┏━┳┓\n┃ ┃┃\n┡━╇┩\n│ ││\n├─┼┤\n├─┼┤\n│ ││\n└─┴┘\n",
)

///|
pub let box_double : Box = builtin_box(
  "DOUBLE", "╔═╦╗\n║ ║║\n╠═╬╣\n║ ║║\n╠═╬╣\n╠═╬╣\n║ ║║\n╚═╩╝\n",
)

///|
pub let box_double_edge : Box = builtin_box(
  "DOUBLE_EDGE", "╔═╤╗\n║ │║\n╟─┼╢\n║ │║\n╟─┼╢\n╟─┼╢\n║ │║\n╚═╧╝\n",
)

///|
pub let box_markdown : Box = builtin_box(
  "MARKDOWN",
  "    \n| ||\n|-||\n| ||\n|-||\n|-||\n| ||\n    \n",
  ascii=true,
)
