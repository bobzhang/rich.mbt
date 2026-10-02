// Port of rich/padding.py.

///|
/// Draw space around content.
pub struct Padding {
  renderable : &Renderable
  top : Int
  right : Int
  bottom : Int
  left : Int
  style : StyleType
  expand : Bool
}

///|
/// Padding dimensions: 1 value (all sides), 2 values (top/bottom,
/// left/right) or 4 values (top, right, bottom, left).
pub fn unpack_padding(
  pad : ArrayView[Int],
) -> (Int, Int, Int, Int) raise RichError {
  match pad {
    [p] => (p, p, p, p)
    [top, right] => (top, right, top, right)
    [top, right, bottom, left] => (top, right, bottom, left)
    _ =>
      raise ValueError(
        "1, 2 or 4 integers required for padding; \{pad.length()} given",
      )
  }
}

///|
pub fn Padding::new(
  renderable : &Renderable,
  pad? : ArrayView[Int] = [0, 0, 0, 0],
  style? : &IntoStyle,
  expand? : Bool = true,
) -> Padding raise RichError {
  let (top, right, bottom, left) = unpack_padding(pad)
  {
    renderable,
    top,
    right,
    bottom,
    left,
    style: match style {
      Some(s) => s.into_style_type()
      None => Def("none")
    },
    expand,
  }
}

///|
/// Make padding instance to render an indent.
pub fn Padding::indent(renderable : &Renderable, level : Int) -> Padding {
  {
    renderable,
    top: 0,
    right: 0,
    bottom: 0,
    left: level,
    style: Def("none"),
    expand: false,
  }
}

///|
pub fn Padding::repr(self : Padding) -> String {
  "Padding(..., (\{self.top},\{self.right},\{self.bottom},\{self.left}))"
}

///|
pub impl Renderable for Padding with fn rich_console(self, console, options) {
  let style = console.get_style(self.style)
  let width = if self.expand {
    options.max_width
  } else {
    @cmp.minimum(
      Measurement::get(console, options, self.renderable).maximum +
      self.left +
      self.right,
      options.max_width,
    )
  }
  let mut render_options = options.update_width(width - self.left - self.right)
  if render_options.height is Some(h) {
    render_options = render_options.update_height(h - self.top - self.bottom)
  }
  let lines = console.render_lines(
    self.renderable,
    options=render_options,
    style~,
    pad=true,
  )
  let out = []
  let left = if self.left != 0 {
    Some(Segment::new(space_string(self.left), style~))
  } else {
    None
  }
  let right = if self.right != 0 {
    [Segment::new(space_string(self.right), style~), Segment::line()]
  } else {
    [Segment::line()]
  }
  let blank_line = Segment::new(space_string(width) + "\n", style~)
  for _ in 0..<self.top {
    out.push(Seg(blank_line))
  }
  for line in lines {
    if left is Some(l) {
      out.push(Seg(l))
    }
    for s in line {
      out.push(Seg(s))
    }
    for s in right {
      out.push(Seg(s))
    }
  }
  for _ in 0..<self.bottom {
    out.push(Seg(blank_line))
  }
  out
}

///|
pub impl Renderable for Padding with fn rich_measure(self, console, options) {
  let max_width = options.max_width
  let extra_width = self.left + self.right
  if max_width - extra_width < 1 {
    return Some({ minimum: max_width, maximum: max_width, })
  }
  let m = Measurement::get(console, options, self.renderable)
  Some(
    { minimum: m.minimum + extra_width, maximum: m.maximum + extra_width, }.with_maximum(
      max_width,
    ),
  )
}
