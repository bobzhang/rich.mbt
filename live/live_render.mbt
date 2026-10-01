// Port of rich/live_render.py.

///|
/// How to handle a renderable that is too tall for the console.
pub(all) enum VerticalOverflowMethod {
  Crop
  Ellipsis
  Visible
} derive(Eq, Debug)

///|
pub fn VerticalOverflowMethod::to_string(
  self : VerticalOverflowMethod,
) -> String {
  match self {
    Crop => "crop"
    Ellipsis => "ellipsis"
    Visible => "visible"
  }
}

///|
/// Parse a vertical overflow method name (`"crop"`, `"ellipsis"`,
/// `"visible"`).
pub fn VerticalOverflowMethod::parse(s : String) -> VerticalOverflowMethod? {
  match s {
    "crop" => Some(Crop)
    "ellipsis" => Some(Ellipsis)
    "visible" => Some(Visible)
    _ => None
  }
}

///|
/// A renderable that may be updated, and that remembers the shape of its
/// last render so the cursor can be moved back over it.
pub(all) struct LiveRender {
  /// The renderable being displayed.
  mut renderable : &@rich.Renderable
  /// Style applied to the renderable.
  mut style : @rich.StyleType
  /// How to handle a renderable taller than the console.
  mut vertical_overflow : VerticalOverflowMethod
  /// `(width, height)` of the last render (upstream `_shape`).
  mut shape : (Int, Int)?
}

///|
pub fn LiveRender::new(
  renderable : &@rich.Renderable,
  style? : &@rich.IntoStyle = "",
  vertical_overflow? : VerticalOverflowMethod = Ellipsis,
) -> LiveRender {
  {
    renderable,
    style: style.into_style_type(),
    vertical_overflow,
    shape: None,
  }
}

///|
/// The number of lines in the last render (0 if nothing was rendered).
pub fn LiveRender::last_render_height(self : LiveRender) -> Int {
  match self.shape {
    None => 0
    Some((_, height)) => height
  }
}

///|
/// Set a new renderable.
pub fn LiveRender::set_renderable(
  self : LiveRender,
  renderable : &@rich.Renderable,
) -> Unit {
  self.renderable = renderable
}

///|
/// Control codes to move the cursor to the beginning of the live render.
pub fn LiveRender::position_cursor(self : LiveRender) -> @rich.Control {
  match self.shape {
    Some((_, height)) => {
      let codes : Array[@rich.ControlCode] = [
        Code(CarriageReturn),
        CodeInt(EraseInLine, 2),
      ]
      for _ in 0..<(height - 1) {
        codes.push(CodeInt(CursorUp, 1))
        codes.push(CodeInt(EraseInLine, 2))
      }
      @rich.Control::new(codes)
    }
    None => @rich.Control::new([])
  }
}

///|
/// Control codes to clear the render and restore the cursor to its
/// previous position.
pub fn LiveRender::restore_cursor(self : LiveRender) -> @rich.Control {
  match self.shape {
    Some((_, height)) => {
      let codes : Array[@rich.ControlCode] = [Code(CarriageReturn)]
      for _ in 0..<height {
        codes.push(CodeInt(CursorUp, 1))
        codes.push(CodeInt(EraseInLine, 2))
      }
      @rich.Control::new(codes)
    }
    None => @rich.Control::new([])
  }
}

///|
/// Python `lines[:end]` (negative `end` counts from the end).
fn[T] py_head(xs : Array[T], end : Int) -> Array[T] {
  let n = xs.length()
  let end = if end < 0 {
    @cmp.maximum(0, n + end)
  } else {
    @cmp.minimum(end, n)
  }
  xs[:end].to_owned()
}

///|
pub impl @rich.Renderable for LiveRender with fn rich_console(
  self,
  console,
  options,
) {
  let style = console.get_style(self.style)
  let mut lines = console.render_lines(
    self.renderable,
    options~,
    style~,
    pad=false,
  )
  let mut shape = @rich.Segment::get_shape(lines)
  let (_, height) = shape
  if height > options.size.height {
    match self.vertical_overflow {
      Crop => {
        lines = py_head(lines, options.size.height)
        shape = @rich.Segment::get_shape(lines)
      }
      Ellipsis => {
        lines = py_head(lines, options.size.height - 1)
        let overflow_text = @rich.Text::new(
          text="...",
          overflow=Crop,
          justify=Center,
          end="",
          style="live.ellipsis",
        )
        lines.push(console.render(overflow_text))
        shape = @rich.Segment::get_shape(lines)
      }
      Visible => ()
    }
  }
  self.shape = Some(shape)
  let out : Array[@rich.RenderItem] = []
  let new_line = @rich.Segment::line()
  let n = lines.length()
  for i, line in lines {
    for segment in line {
      out.push(Seg(segment))
    }
    if i != n - 1 {
      out.push(Seg(new_line))
    }
  }
  out
}
