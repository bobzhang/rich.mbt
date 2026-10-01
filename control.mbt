// Port of rich/control.py.

///|
fn format_control_code(code : ControlCode) -> String {
  match code {
    Code(Bell) => "\u{07}"
    Code(CarriageReturn) => "\r"
    Code(Home) => "\u{1b}[H"
    Code(Clear) => "\u{1b}[2J"
    Code(EnableAltScreen) => "\u{1b}[?1049h"
    Code(DisableAltScreen) => "\u{1b}[?1049l"
    Code(ShowCursor) => "\u{1b}[?25h"
    Code(HideCursor) => "\u{1b}[?25l"
    CodeInt(CursorUp, n) => "\u{1b}[\{n}A"
    CodeInt(CursorDown, n) => "\u{1b}[\{n}B"
    CodeInt(CursorForward, n) => "\u{1b}[\{n}C"
    CodeInt(CursorBackward, n) => "\u{1b}[\{n}D"
    CodeInt(CursorMoveToColumn, n) => "\u{1b}[\{n + 1}G"
    CodeInt(EraseInLine, n) => "\u{1b}[\{n}K"
    CodeXY(CursorMoveTo, x, y) => "\u{1b}[\{y + 1};\{x + 1}H"
    CodeStr(SetWindowTitle, title) => "\u{1b}]0;\{title}\u{07}"
    _ => abort("invalid control code")
  }
}

///|
/// A renderable that inserts a control code (non printable but may move
/// cursor).
pub struct Control {
  segment : Segment
}

///|
pub fn Control::new(codes : Array[ControlCode]) -> Control {
  let rendered = codes.map(format_control_code).join("")
  { segment: { text: rendered, style: None, control: Some(codes), }, }
}

///|
/// Ring the 'bell'.
pub fn Control::bell() -> Control {
  Control::new([Code(Bell)])
}

///|
/// Move cursor to 'home' position.
pub fn Control::home() -> Control {
  Control::new([Code(Home)])
}

///|
/// Move cursor relative to current position.
pub fn Control::move_(x? : Int = 0, y? : Int = 0) -> Control {
  let codes = []
  if x != 0 {
    codes.push(
      CodeInt(if x > 0 { CursorForward } else { CursorBackward }, x.abs()),
    )
  }
  if y != 0 {
    codes.push(CodeInt(if y > 0 { CursorDown } else { CursorUp }, y.abs()))
  }
  Control::new(codes)
}

///|
/// Move to the given column, optionally add offset to row.
pub fn Control::move_to_column(x : Int, y? : Int = 0) -> Control {
  if y != 0 {
    Control::new([
      CodeInt(CursorMoveToColumn, x),
      CodeInt(if y > 0 { CursorDown } else { CursorUp }, y.abs()),
    ])
  } else {
    Control::new([CodeInt(CursorMoveToColumn, x)])
  }
}

///|
/// Move cursor to absolute position.
pub fn Control::move_to(x : Int, y : Int) -> Control {
  Control::new([CodeXY(CursorMoveTo, x, y)])
}

///|
/// Clear the screen.
pub fn Control::clear() -> Control {
  Control::new([Code(Clear)])
}

///|
/// Show or hide the cursor.
pub fn Control::show_cursor(show : Bool) -> Control {
  Control::new([Code(if show { ShowCursor } else { HideCursor })])
}

///|
/// Enable or disable alt screen.
pub fn Control::alt_screen(enable : Bool) -> Control {
  if enable {
    Control::new([Code(EnableAltScreen), Code(Home)])
  } else {
    Control::new([Code(DisableAltScreen)])
  }
}

///|
/// Set the terminal window title.
pub fn Control::title(title : String) -> Control {
  Control::new([CodeStr(SetWindowTitle, title)])
}

///|
pub impl Show for Control with fn output(self, logger) {
  logger.write_string(self.segment.text)
}

///|
pub impl Renderable for Control with fn rich_console(self, _console, _options) {
  if self.segment.text != "" {
    [Seg(self.segment)]
  } else {
    []
  }
}
