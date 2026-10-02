// Port of rich/segment.py.

///|
/// Non-printable control codes which typically translate to ANSI codes.
pub(all) enum ControlType {
  Bell
  CarriageReturn
  Home
  Clear
  ShowCursor
  HideCursor
  EnableAltScreen
  DisableAltScreen
  CursorUp
  CursorDown
  CursorForward
  CursorBackward
  CursorMoveToColumn
  CursorMoveTo
  EraseInLine
  SetWindowTitle
} derive(Eq, Hash, Debug)

///|
pub fn ControlType::to_int(self : ControlType) -> Int {
  match self {
    Bell => 1
    CarriageReturn => 2
    Home => 3
    Clear => 4
    ShowCursor => 5
    HideCursor => 6
    EnableAltScreen => 7
    DisableAltScreen => 8
    CursorUp => 9
    CursorDown => 10
    CursorForward => 11
    CursorBackward => 12
    CursorMoveToColumn => 13
    CursorMoveTo => 14
    EraseInLine => 15
    SetWindowTitle => 16
  }
}

///|
/// A control code with its parameters.
pub(all) enum ControlCode {
  Code(ControlType)
  CodeInt(ControlType, Int)
  CodeStr(ControlType, String)
  CodeXY(ControlType, Int, Int)
} derive(Eq, Hash, Debug)

///|
/// A piece of text with associated style. Segments are produced by the
/// Console render process and are ultimately converted in to strings to be
/// written to the terminal.
pub(all) struct Segment {
  text : String
  style : Style?
  control : Array[ControlCode]?
} derive(Eq)

///|
pub fn Segment::new(
  text : String,
  style? : Style,
  control? : Array[ControlCode],
) -> Segment {
  { text, style, control, }
}

///|
/// Upstream `repr(segment)`.
pub fn Segment::repr(self : Segment) -> String {
  let parts = [py_repr(self.text)]
  match self.control {
    None => if self.style is Some(s) { parts.push(s.repr()) }
    Some(control) => {
      parts.push(
        match self.style {
          Some(s) => s.repr()
          None => "None"
        },
      )
      parts.push(control_codes_repr(control))
    }
  }
  "Segment(" + parts.join(", ") + ")"
}

///|
fn control_codes_repr(codes : Array[ControlCode]) -> String {
  let items = codes.map(code => {
    match code {
      Code(t) => "(<ControlType.\{control_type_name(t)}: \{t.to_int()}>,)"
      CodeInt(t, n) =>
        "(<ControlType.\{control_type_name(t)}: \{t.to_int()}>, \{n})"
      CodeStr(t, s) =>
        "(<ControlType.\{control_type_name(t)}: \{t.to_int()}>, \{py_repr(s)})"
      CodeXY(t, x, y) =>
        "(<ControlType.\{control_type_name(t)}: \{t.to_int()}>, \{x}, \{y})"
    }
  })
  "[" + items.join(", ") + "]"
}

///|
fn control_type_name(t : ControlType) -> String {
  match t {
    Bell => "BELL"
    CarriageReturn => "CARRIAGE_RETURN"
    Home => "HOME"
    Clear => "CLEAR"
    ShowCursor => "SHOW_CURSOR"
    HideCursor => "HIDE_CURSOR"
    EnableAltScreen => "ENABLE_ALT_SCREEN"
    DisableAltScreen => "DISABLE_ALT_SCREEN"
    CursorUp => "CURSOR_UP"
    CursorDown => "CURSOR_DOWN"
    CursorForward => "CURSOR_FORWARD"
    CursorBackward => "CURSOR_BACKWARD"
    CursorMoveToColumn => "CURSOR_MOVE_TO_COLUMN"
    CursorMoveTo => "CURSOR_MOVE_TO"
    EraseInLine => "ERASE_IN_LINE"
    SetWindowTitle => "SET_WINDOW_TITLE"
  }
}

///|
pub impl Show for Segment with fn output(self, logger) {
  logger.write_string(self.repr())
}

///|
pub impl Debug for Segment with fn to_repr(self) {
  @debug.Repr(self.repr())
}

///|
/// The number of terminal cells required to display the text (0 for
/// control segments).
pub fn Segment::cell_length(self : Segment) -> Int {
  if self.has_codes() {
    0
  } else {
    @cells.cell_len(self.text)
  }
}

///|
/// Check if the segment contains control codes.
pub fn Segment::is_control(self : Segment) -> Bool {
  self.control is Some(_)
}

///|
/// Upstream `bool(segment.control)`: the segment has at least one control
/// code. Most of the segment helpers test this (rather than `is_control`).
pub fn Segment::has_codes(self : Segment) -> Bool {
  match self.control {
    Some(c) => !c.is_empty()
    None => false
  }
}

///|
/// Upstream `bool(segment)`: the segment contains text.
pub fn Segment::to_bool(self : Segment) -> Bool {
  self.text != ""
}

///|
/// Split a segment in to two at a given cell position. If the cut point
/// falls in the middle of a 2-cell wide character then it is replaced by two
/// spaces, to preserve the display width.
pub fn Segment::split_cells(self : Segment, cut : Int) -> (Segment, Segment) {
  let { text, style, control, } = self
  if @cells.is_single_cell_widths(text) {
    if cut >= text.length() {
      return (self, { text: "", style, control, })
    }
    return (
      { text: text.view(end_offset=cut).to_owned(), style, control, },
      { text: text.view(start_offset=cut).to_owned(), style, control, },
    )
  }
  split_cells_slow(self, cut)
}

///|
fn split_cells_slow(segment : Segment, cut : Int) -> (Segment, Segment) {
  let { text, style, control, } = segment
  let cell_length = segment.cell_length()
  if cut >= cell_length {
    return (segment, { text: "", style, control, })
  }
  // Work in code points as upstream does.
  let chars = text.to_array()
  let n = chars.length()
  fn join(a : Int, b : Int) -> String {
    String::from_array(chars[a:b])
  }

  let mut pos = (cut.to_double() / cell_length.to_double() * n.to_double()).to_int()
  while true {
    let before = join(0, pos)
    let cell_pos = @cells.cell_len(before)
    let out_by = cell_pos - cut
    if out_by == 0 {
      return (
        { text: before, style, control, },
        { text: join(pos, n), style, control, },
      )
    }
    if out_by == -1 &&
      pos < n &&
      @cells.get_character_cell_size(chars[pos]) == 2 {
      return (
        { text: join(0, pos) + " ", style, control, },
        { text: " " + join(pos + 1, n), style, control, },
      )
    }
    if out_by == 1 &&
      pos > 0 &&
      @cells.get_character_cell_size(chars[pos - 1]) == 2 {
      return (
        { text: join(0, pos - 1) + " ", style, control, },
        { text: " " + join(pos, n), style, control, },
      )
    }
    if cell_pos < cut {
      pos += 1
    } else {
      pos -= 1
    }
  }
  panic()
}

///|
/// Make a new line segment.
pub fn Segment::line() -> Segment {
  { text: "\n", style: None, control: None, }
}

///|
/// Apply style(s) to segments: each style is replaced by
/// `style + segment.style + post_style`.
pub fn Segment::apply_style(
  segments : Array[Segment],
  style? : Style,
  post_style? : Style,
) -> Array[Segment] {
  let mut result = segments
  if style is Some(style) && style.to_bool() {
    result = result.map(seg => {
      text: seg.text,
      style: if seg.has_codes() {
        None
      } else {
        Some(style.add_opt(seg.style))
      },
      control: seg.control,
    })
  }
  if post_style is Some(post_style) && post_style.to_bool() {
    result = result.map(seg => {
      text: seg.text,
      style: if seg.has_codes() {
        None
      } else {
        match seg.style {
          Some(s) if s.to_bool() => Some(s + post_style)
          _ => Some(post_style)
        }
      },
      control: seg.control,
    })
  }
  result
}

///|
/// Filter segments by their `is_control` attribute.
pub fn Segment::filter_control(
  segments : Array[Segment],
  is_control? : Bool = false,
) -> Array[Segment] {
  segments.filter(s => s.has_codes() == is_control)
}

///|
/// Split a sequence of segments in to a list of lines.
pub fn Segment::split_lines(segments : Array[Segment]) -> Array[Array[Segment]] {
  Segment::split_lines_terminator(segments).map(x => x.0)
}

///|
/// Split segments in to lines, with a flag that indicates whether the line
/// was terminated by a new line.
pub fn Segment::split_lines_terminator(
  segments : Array[Segment],
) -> Array[(Array[Segment], Bool)] {
  let lines = []
  let mut line = []
  for segment in segments {
    let text = segment.text
    if !segment.has_codes() && text.contains_char('\n') {
      let n = text.length()
      let mut pos = 0
      while pos < n {
        let nl = match text.view(start_offset=pos).find("\n") {
          Some(i) => pos + i
          None => n
        }
        if nl > pos {
          line.push({
            text: text.unsafe_substring(start=pos, end=nl),
            style: segment.style,
            control: None,
          })
        }
        if nl < n {
          lines.push((line, true))
          line = []
        }
        pos = nl + 1
      }
    } else {
      line.push(segment)
    }
  }
  if !line.is_empty() {
    lines.push((line, false))
  }
  lines
}

///|
/// Python `str.partition(sep)`.
fn partition(s : String, sep : String) -> (String, Bool, String) {
  match s.find(sep) {
    Some(i) =>
      (
        s.view(end_offset=i).to_owned(),
        true,
        s.view(start_offset=i + sep.length()).to_owned(),
      )
    None => (s, false, "")
  }
}

///|
/// Split segments in to lines, and crop lines greater than a given length.
pub fn Segment::split_and_crop_lines(
  segments : Array[Segment],
  length : Int,
  style? : Style,
  pad? : Bool = true,
  include_new_lines? : Bool = true,
) -> Array[Array[Segment]] {
  let lines = []
  let mut line = []
  let new_line_segment = Segment::line()
  for segment in segments {
    let text = segment.text
    if !segment.has_codes() && text.contains_char('\n') {
      // walk the newlines by index (slicing off the rest each time would be
      // quadratic in the number of lines)
      let n = text.length()
      let mut pos = 0
      while pos < n {
        let nl = match text.view(start_offset=pos).find("\n") {
          Some(i) => pos + i
          None => n
        }
        if nl > pos {
          let piece = if pos == 0 && nl == n {
            text
          } else {
            text.unsafe_substring(start=pos, end=nl)
          }
          line.push({ text: piece, style: segment.style, control: None, })
        }
        if nl < n {
          let cropped_line = adjust_line_length_owned(line, length, style, pad)
          if include_new_lines {
            cropped_line.push(new_line_segment)
          }
          lines.push(cropped_line)
          line = []
        }
        pos = nl + 1
      }
    } else {
      line.push(segment)
    }
  }
  if !line.is_empty() {
    lines.push(adjust_line_length_owned(line, length, style, pad))
  }
  lines
}

///|
/// Adjust a line to a given width (cropping or padding as required).
pub fn Segment::adjust_line_length(
  line : Array[Segment],
  length : Int,
  style? : Style,
  pad? : Bool = true,
) -> Array[Segment] {
  adjust_line_length_owned(line.copy(), length, style, pad)
}

///|
/// `adjust_line_length` for a line the caller hands over: it is reused for
/// the result instead of being copied.
fn adjust_line_length_owned(
  line : Array[Segment],
  length : Int,
  style : Style?,
  pad : Bool,
) -> Array[Segment] {
  let mut line_length = 0
  for segment in line {
    line_length += segment.cell_length()
  }
  if line_length < length {
    if pad {
      line.push({
        text: space_string(length - line_length),
        style,
        control: None,
      })
    }
    line
  } else if line_length > length {
    let new_line = []
    line_length = 0
    for segment in line {
      let segment_length = segment.cell_length()
      if line_length + segment_length < length || segment.has_codes() {
        new_line.push(segment)
        line_length += segment_length
      } else {
        let text = @cells.set_cell_size(segment.text, length - line_length)
        new_line.push({ text, style: segment.style, control: None, })
        break
      }
    }
    new_line
  } else {
    line
  }
}

///|
/// Get the length of a line of segments (assumes no new lines).
pub fn Segment::get_line_length(line : ArrayView[Segment]) -> Int {
  let mut total = 0
  for segment in line {
    if !segment.has_codes() {
      total += @cells.cell_len(segment.text)
    }
  }
  total
}

///|
/// Get the shape (enclosing rectangle) of a list of lines.
pub fn Segment::get_shape(lines : Array[Array[Segment]]) -> (Int, Int) {
  let mut max_width = 0
  for line in lines {
    max_width = @cmp.maximum(max_width, Segment::get_line_length(line))
  }
  (max_width, lines.length())
}

///|
/// Set the shape of a list of lines (enclosing rectangle).
pub fn Segment::set_shape(
  lines : Array[Array[Segment]],
  width : Int,
  height? : Int,
  style? : Style,
  new_lines? : Bool = false,
) -> Array[Array[Segment]] {
  let height = match height {
    Some(h) if h != 0 => h
    _ => lines.length()
  }
  let blank = if new_lines {
    [Segment::new(space_string(width) + "\n", style?)]
  } else {
    [Segment::new(space_string(width), style?)]
  }
  // upstream adjusts *all* lines (the slice assignment replaces the
  // truncated list), so `height` only ever adds lines
  let shaped_lines = lines.map(line => {
    Segment::adjust_line_length(line, width, style?)
  })
  while shaped_lines.length() < height {
    shaped_lines.push(blank)
  }
  shaped_lines
}

///|
fn blank_line(width : Int, style : Style?, new_lines : Bool) -> Segment {
  if new_lines {
    { text: space_string(width) + "\n", style, control: None, }
  } else {
    { text: space_string(width), style, control: None, }
  }
}

///|
/// Align lines to top (adds extra lines to bottom as required).
pub fn Segment::align_top(
  lines : Array[Array[Segment]],
  width : Int,
  height : Int,
  style : Style?,
  new_lines? : Bool = false,
) -> Array[Array[Segment]] {
  let extra_lines = height - lines.length()
  if extra_lines == 0 {
    return lines.copy()
  }
  let result = py_head(lines, height)
  let blank = blank_line(width, style, new_lines)
  for _ in 0..<extra_lines {
    result.push([blank])
  }
  result
}

///|
/// Align lines to bottom (adds extra lines above as required).
pub fn Segment::align_bottom(
  lines : Array[Array[Segment]],
  width : Int,
  height : Int,
  style : Style?,
  new_lines? : Bool = false,
) -> Array[Array[Segment]] {
  let extra_lines = height - lines.length()
  if extra_lines == 0 {
    return lines.copy()
  }
  let blank = blank_line(width, style, new_lines)
  let result = []
  for _ in 0..<extra_lines {
    result.push([blank])
  }
  result.append(py_head(lines, height))
  result
}

///|
/// Align lines to middle (adds extra lines above and below as required).
pub fn Segment::align_middle(
  lines : Array[Array[Segment]],
  width : Int,
  height : Int,
  style : Style?,
  new_lines? : Bool = false,
) -> Array[Array[Segment]] {
  let extra_lines = height - lines.length()
  if extra_lines == 0 {
    return lines.copy()
  }
  let blank = blank_line(width, style, new_lines)
  let top_lines = floor_div(extra_lines, 2)
  let bottom_lines = extra_lines - top_lines
  let result = []
  for _ in 0..<top_lines {
    result.push([blank])
  }
  result.append(py_head(lines, height))
  for _ in 0..<bottom_lines {
    result.push([blank])
  }
  result
}

///|
/// Python `xs[:n]`.
fn[T] py_head(xs : Array[T], n : Int) -> Array[T] {
  let len = xs.length()
  let end = if n < 0 { @cmp.maximum(0, len + n) } else { @cmp.minimum(n, len) }
  xs[0:end].to_owned()
}

///|
/// Python floor division.
fn floor_div(a : Int, b : Int) -> Int {
  let q = a / b
  if a % b != 0 && (a < 0) != (b < 0) {
    q - 1
  } else {
    q
  }
}

///|
/// Python modulo.
fn py_mod(a : Int, b : Int) -> Int {
  let r = a % b
  if r != 0 && (r < 0) != (b < 0) {
    r + b
  } else {
    r
  }
}

///|
/// Simplify segments by combining contiguous segments with the same style.
pub fn Segment::simplify(segments : Array[Segment]) -> Array[Segment] {
  guard segments is [first, .. rest] else { return [] }
  let result = []
  let mut last_segment = first
  for segment in rest {
    if last_segment.style == segment.style && !segment.has_codes() {
      last_segment = {
        text: last_segment.text + segment.text,
        style: last_segment.style,
        control: None,
      }
    } else {
      result.push(last_segment)
      last_segment = segment
    }
  }
  result.push(last_segment)
  result
}

///|
/// Remove all links from segments.
pub fn Segment::strip_links(segments : Array[Segment]) -> Array[Segment] {
  segments.map(segment => {
    match segment.style {
      _ if segment.has_codes() => segment
      None => segment
      Some(style) =>
        {
          text: segment.text,
          style: if style.to_bool() {
            Some(style.update_link(None))
          } else {
            None
          },
          control: None,
        }
    }
  })
}

///|
/// Remove all styles from segments.
pub fn Segment::strip_styles(segments : Array[Segment]) -> Array[Segment] {
  segments.map(segment => {
    text: segment.text,
    style: None,
    control: segment.control,
  })
}

///|
/// Remove all color from segments.
pub fn Segment::remove_color(segments : Array[Segment]) -> Array[Segment] {
  let cache : Map[Style, Style] = Map([])
  segments.map(segment => {
    match segment.style {
      Some(style) if style.to_bool() => {
        let colorless = match cache.get(style) {
          Some(s) => s
          None => {
            let s = style.without_color()
            cache[style] = s
            s
          }
        }
        {
          text: segment.text,
          style: Some(colorless),
          control: segment.control,
        }
      }
      _ => { text: segment.text, style: None, control: segment.control, }
    }
  })
}

///|
/// Divide segments in to portions at the given cell positions.
pub fn Segment::divide(
  segments : Array[Segment],
  cuts : Array[Int],
) -> Array[Array[Segment]] {
  let result = []
  let split_segments = []
  let mut cut_index = 0
  fn next_cut() -> Int {
    if cut_index < cuts.length() {
      let c = cuts[cut_index]
      cut_index += 1
      c
    } else {
      -1
    }
  }

  let mut cut = -1
  while true {
    cut = next_cut()
    if cut == -1 {
      return result
    }
    if cut != 0 {
      break
    }
    result.push([])
  }
  let mut pos = 0
  for seg in segments {
    let mut segment = seg
    while segment.text != "" {
      let end_pos = if segment.has_codes() {
        pos
      } else {
        pos + @cells.cell_len(segment.text)
      }
      if end_pos < cut {
        split_segments.push(segment)
        pos = end_pos
        break
      }
      if end_pos == cut {
        split_segments.push(segment)
        result.push(split_segments.copy())
        split_segments.clear()
        pos = end_pos
        cut = next_cut()
        if cut == -1 {
          if !split_segments.is_empty() {
            result.push(split_segments.copy())
          }
          return result
        }
        break
      } else {
        let (before, after) = segment.split_cells(cut - pos)
        segment = after
        split_segments.push(before)
        result.push(split_segments.copy())
        split_segments.clear()
        pos = cut
      }
      cut = next_cut()
      if cut == -1 {
        if !split_segments.is_empty() {
          result.push(split_segments.copy())
        }
        return result
      }
    }
  }
  result.push(split_segments.copy())
  result
}

///|
/// A simple renderable to render a list of segments.
pub struct Segments {
  segments : Array[Segment]
  new_lines : Bool
}

///|
/// With `new_lines`, a new line is added after each segment.
pub fn Segments::new(
  segments : Array[Segment],
  new_lines? : Bool = false,
) -> Segments {
  { segments: segments.copy(), new_lines, }
}

///|
pub impl Renderable for Segments with fn rich_console(self, _console, _options) {
  let out = []
  for segment in self.segments {
    out.push(Seg(segment))
    if self.new_lines {
      out.push(Seg(Segment::line()))
    }
  }
  out
}

///|
/// A renderable to render lines of segments.
pub struct SegmentLines {
  lines : Array[Array[Segment]]
  new_lines : Bool
}

///|
/// With `new_lines`, a new line is added after each line.
pub fn SegmentLines::new(
  lines : Array[Array[Segment]],
  new_lines? : Bool = false,
) -> SegmentLines {
  { lines: lines.copy(), new_lines, }
}

///|
pub impl Renderable for SegmentLines with fn rich_console(
  self,
  _console,
  _options,
) {
  let out = []
  for line in self.lines {
    for segment in line {
      out.push(Seg(segment))
    }
    if self.new_lines {
      out.push(Seg(Segment::line()))
    }
  }
  out
}
