// Port of rich/align.py, rich/styled.py, rich/constrain.py,
// rich/region.py, rich/screen.py and rich/pager.py.

///|
/// Align a renderable by adding spaces if necessary.
pub struct Align {
  renderable : &Renderable
  align : AlignMethod
  style : StyleType?
  vertical : VerticalAlignMethod?
  pad : Bool
  width : Int?
  height : Int?
}

///|
pub fn Align::new(
  renderable : &Renderable,
  align : AlignMethod,
  style? : &IntoStyle,
  vertical? : VerticalAlignMethod,
  pad? : Bool = true,
  width? : Int,
  height? : Int,
) -> Align {
  { renderable, align, style: style_opt(style), vertical, pad, width, height, }
}

///|
/// Align a renderable to the left.
pub fn Align::left(
  renderable : &Renderable,
  style? : &IntoStyle,
  vertical? : VerticalAlignMethod,
  pad? : Bool = true,
  width? : Int,
  height? : Int,
) -> Align {
  Align::new(renderable, Left, style?, vertical?, pad~, width?, height?)
}

///|
/// Align a renderable to the center.
pub fn Align::center(
  renderable : &Renderable,
  style? : &IntoStyle,
  vertical? : VerticalAlignMethod,
  pad? : Bool = true,
  width? : Int,
  height? : Int,
) -> Align {
  Align::new(renderable, Center, style?, vertical?, pad~, width?, height?)
}

///|
/// Align a renderable to the right.
pub fn Align::right(
  renderable : &Renderable,
  style? : &IntoStyle,
  vertical? : VerticalAlignMethod,
  pad? : Bool = true,
  width? : Int,
  height? : Int,
) -> Align {
  Align::new(renderable, Right, style?, vertical?, pad~, width?, height?)
}

///|
pub impl Renderable for Align with fn rich_console(self, console, options) {
  let align = self.align
  let width = console.measure(self.renderable, options~).maximum
  let rendered = console.render(
    Constrain::new(
      self.renderable,
      width=Some(
        match self.width {
          None => width
          Some(w) => @cmp.minimum(width, w)
        },
      ),
    ),
    options=options.update(height=None),
  )
  let lines = Segment::split_lines(rendered)
  let (width, height) = Segment::get_shape(lines)
  let lines = Segment::set_shape(lines, width, height~)
  let new_line = Segment::line()
  let excess_space = options.max_width - width
  let style = match self.style {
    Some(s) => Some(console.get_style(s))
    None => None
  }
  fn generate_segments() -> Array[Segment] {
    let out = []
    if excess_space <= 0 {
      for line in lines {
        out.append(line)
        out.push(new_line)
      }
    } else {
      match align {
        Left => {
          let pad = Segment::new(" ".repeat(excess_space), style?)
          for line in lines {
            out.append(line)
            if self.pad {
              out.push(pad)
            }
            out.push(new_line)
          }
        }
        Center => {
          let left = floor_div(excess_space, 2)
          let pad = Segment::new(" ".repeat(left), style?)
          let pad_right = Segment::new(" ".repeat(excess_space - left), style?)
          for line in lines {
            if left != 0 {
              out.push(pad)
            }
            out.append(line)
            if self.pad {
              out.push(pad_right)
            }
            out.push(new_line)
          }
        }
        Right => {
          let pad = Segment::new(" ".repeat(excess_space), style?)
          for line in lines {
            out.push(pad)
            out.append(line)
            out.push(new_line)
          }
        }
      }
    }
    out
  }

  let blank_width = match self.width {
    Some(w) if w != 0 => w
    _ => options.max_width
  }
  let blank_line = if self.pad {
    Segment::new(" ".repeat(blank_width) + "\n", style?)
  } else {
    Segment::new("\n")
  }
  fn blank_lines(count : Int) -> Array[Segment] {
    let out = []
    for _ in 0..<count {
      out.push(blank_line)
    }
    out
  }

  let vertical_height = match self.height {
    Some(h) if h != 0 => Some(h)
    _ => options.height
  }
  let mut segments = match (self.vertical, vertical_height) {
    (Some(vertical), Some(vertical_height)) =>
      match vertical {
        Top => generate_segments() + blank_lines(vertical_height - height)
        Middle => {
          let top_space = floor_div(vertical_height - height, 2)
          let bottom_space = vertical_height - top_space - height
          blank_lines(top_space) +
          generate_segments() +
          blank_lines(bottom_space)
        }
        Bottom => blank_lines(vertical_height - height) + generate_segments()
      }
    _ => generate_segments()
  }
  if self.style is Some(s) && s.to_bool() {
    let style = console.get_style(s)
    segments = Segment::apply_style(segments, style~)
  }
  segments_to_items(segments)
}

///|
pub impl Renderable for Align with fn rich_measure(self, console, options) {
  Some(Measurement::get(console, options, self.renderable))
}

///|
pub impl Renderable for Align with fn vertical_align(self) {
  self.vertical
}

///|
/// Vertically aligns a renderable.
pub struct VerticalCenter {
  renderable : &Renderable
  style : StyleType?
}

///|
pub fn VerticalCenter::new(
  renderable : &Renderable,
  style? : &IntoStyle,
) -> VerticalCenter {
  { renderable, style: style_opt(style), }
}

///|
pub impl Renderable for VerticalCenter with fn rich_console(
  self,
  console,
  options,
) {
  let style = match self.style {
    Some(s) => Some(console.get_style(s))
    None => None
  }
  let lines = console.render_lines(
    self.renderable,
    options=options.update(height=None),
    pad=false,
  )
  let (width, _) = Segment::get_shape(lines)
  let new_line = Segment::line()
  let height = match options.height {
    Some(h) if h != 0 => h
    _ => options.size.height
  }
  let top_space = floor_div(height - lines.length(), 2)
  let bottom_space = height - top_space - lines.length()
  let blank_line = Segment::new(" ".repeat(width), style?)
  let out = []
  for _ in 0..<top_space {
    out.push(Seg(blank_line))
    out.push(Seg(new_line))
  }
  for line in lines {
    for s in line {
      out.push(Seg(s))
    }
    out.push(Seg(new_line))
  }
  for _ in 0..<bottom_space {
    out.push(Seg(blank_line))
    out.push(Seg(new_line))
  }
  out
}

///|
pub impl Renderable for VerticalCenter with fn rich_measure(
  self,
  console,
  options,
) {
  Some(Measurement::get(console, options, self.renderable))
}

///|
/// Apply a style to a renderable.
pub struct Styled {
  renderable : &Renderable
  style : StyleType
}

///|
pub fn Styled::new(renderable : &Renderable, style : &IntoStyle) -> Styled {
  { renderable, style: style.into_style_type(), }
}

///|
pub impl Renderable for Styled with fn rich_console(self, console, options) {
  let style = console.get_style(self.style)
  let rendered = console.render(self.renderable, options~)
  segments_to_items(Segment::apply_style(rendered, style~))
}

///|
pub impl Renderable for Styled with fn rich_measure(self, console, options) {
  Some(Measurement::get(console, options, self.renderable))
}

///|
/// Constrain the width of a renderable to a given number of characters.
pub struct Constrain {
  renderable : &Renderable
  width : Int?
}

///|
pub fn Constrain::new(
  renderable : &Renderable,
  width? : Int? = Some(80),
) -> Constrain {
  { renderable, width, }
}

///|
pub impl Renderable for Constrain with fn rich_console(self, console, options) {
  match self.width {
    None => [Child(self.renderable)]
    Some(w) => {
      let child_options = options.update_width(
        @cmp.minimum(w, options.max_width),
      )
      segments_to_items(console.render(self.renderable, options=child_options))
    }
  }
}

///|
pub impl Renderable for Constrain with fn rich_measure(self, console, options) {
  let options = match self.width {
    Some(w) => options.update_width(w)
    None => options
  }
  Some(Measurement::get(console, options, self.renderable))
}

///|
/// Defines a rectangular region of the screen.
pub(all) struct Region {
  x : Int
  y : Int
  width : Int
  height : Int
} derive(Eq, Debug)

///|
/// A renderable that fills the terminal screen and crops excess.
pub struct Screen {
  renderable : &Renderable
  style : StyleType?
  application_mode : Bool
}

///|
pub fn Screen::new(
  renderables : Array[&Renderable],
  style? : &IntoStyle,
  application_mode? : Bool = false,
) -> Screen {
  {
    renderable: Group::new(renderables),
    style: style_opt(style),
    application_mode,
  }
}

///|
pub impl Renderable for Screen with fn rich_console(self, console, options) {
  let { width, height, } = options.size
  let style = match self.style {
    Some(s) if s.to_bool() => Some(console.get_style(s))
    _ => None
  }
  let render_options = options.update(width~, height=Some(height))
  let lines = console.render_lines(
    self.renderable,
    options=render_options,
    style?,
    pad=true,
  )
  let lines = Segment::set_shape(lines, width, height~, style?)
  let new_line = if self.application_mode {
    Segment::new("\n\r")
  } else {
    Segment::line()
  }
  let out = []
  for i, line in lines {
    for s in line {
      out.push(Seg(s))
    }
    if i != lines.length() - 1 {
      out.push(Seg(new_line))
    }
  }
  out
}

///|
/// Base trait for a pager.
pub(open) trait Pager {
  fn show(Self, String) -> Unit raise
}

///|
/// Uses the pager installed on the system (`$PAGER`, or `less -r`).
pub struct SystemPager {
  command : String?
}

///|
pub fn SystemPager::new(command? : String) -> SystemPager {
  { command, }
}

///|
pub impl Pager for SystemPager with fn show(self, content) {
  let command = match self.command {
    Some(c) => c
    None =>
      match @env.get_env_var("PAGER") {
        Some(p) if p != "" => p
        _ => "less -r"
      }
  }
  if !@term.pipe_to(command, content) {
    // no pager available: print directly
    if !@term.write_fd(1, content) {
      raise WriteError("unable to run pager")
    }
  }
}
