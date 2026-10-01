// Port of rich/panel.py.

///|
/// A console renderable that draws a border around its contents.
pub(all) struct Panel {
  mut renderable : &@rich.Renderable
  mut box_ : @rich.Box
  mut title : @rich.TextType?
  mut title_align : @rich.AlignMethod
  mut subtitle : @rich.TextType?
  mut subtitle_align : @rich.AlignMethod
  mut safe_box : Bool?
  mut expand : Bool
  mut style : @rich.StyleType
  mut border_style : @rich.StyleType
  mut width : Int?
  mut height : Int?
  mut padding : Array[Int]
  mut highlight : Bool
}

///|
pub fn Panel::new(
  renderable : &@rich.Renderable,
  box_? : @rich.Box = @rich.box_rounded,
  title? : &@rich.IntoText,
  title_align? : @rich.AlignMethod = Center,
  subtitle? : &@rich.IntoText,
  subtitle_align? : @rich.AlignMethod = Center,
  safe_box? : Bool,
  expand? : Bool = true,
  style? : &@rich.IntoStyle,
  border_style? : &@rich.IntoStyle,
  width? : Int,
  height? : Int,
  padding? : ArrayView[Int] = [0, 1],
  highlight? : Bool = false,
) -> Panel {
  {
    renderable,
    box_,
    title: title.map(t => t.into_text_type()),
    title_align,
    subtitle: subtitle.map(t => t.into_text_type()),
    subtitle_align,
    safe_box,
    expand,
    style: match style {
      Some(s) => s.into_style_type()
      None => Def("none")
    },
    border_style: match border_style {
      Some(s) => s.into_style_type()
      None => Def("none")
    },
    width,
    height,
    padding: padding.to_owned(),
    highlight,
  }
}

///|
/// An alternative constructor that sets `expand=false`.
pub fn Panel::fit(
  renderable : &@rich.Renderable,
  box_? : @rich.Box = @rich.box_rounded,
  title? : &@rich.IntoText,
  title_align? : @rich.AlignMethod = Center,
  subtitle? : &@rich.IntoText,
  subtitle_align? : @rich.AlignMethod = Center,
  safe_box? : Bool,
  style? : &@rich.IntoStyle,
  border_style? : &@rich.IntoStyle,
  width? : Int,
  height? : Int,
  padding? : ArrayView[Int] = [0, 1],
  highlight? : Bool = false,
) -> Panel {
  Panel::new(
    renderable,
    box_~,
    title?,
    title_align~,
    subtitle?,
    subtitle_align~,
    safe_box?,
    style?,
    border_style?,
    width?,
    height?,
    padding~,
    highlight~,
    expand=false,
  )
}

///|
fn make_title(title : @rich.TextType?) -> @rich.Text? raise {
  match title {
    Some(t) if t.to_bool() => {
      let title_text = match t {
        Str(s) => @rich.Text::from_markup(s)
        Text(t) => t.copy()
      }
      title_text.end = ""
      title_text.set_plain(title_text.plain().replace_all(old="\n", new=" "))
      title_text.no_wrap = Some(true)
      title_text.expand_tabs()
      title_text.pad(1)
      Some(title_text)
    }
    _ => None
  }
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
pub impl @rich.Renderable for Panel with fn rich_console(self, console, options) {
  let (top, right, bottom, left) = @rich.unpack_padding(self.padding)
  let renderable : &@rich.Renderable = if top != 0 ||
    right != 0 ||
    bottom != 0 ||
    left != 0 {
    (
      @rich.Padding::new(self.renderable, pad=[top, right, bottom, left]) :
      &@rich.Renderable)
  } else {
    self.renderable
  }
  let style = console.get_style(self.style)
  let border_style = style + console.get_style(self.border_style)
  let width = match self.width {
    None => options.max_width
    Some(w) => @cmp.minimum(options.max_width, w)
  }
  let safe_box = match self.safe_box {
    None => console.safe_box
    Some(b) => b
  }
  let box_ = self.box_.substitute(options, safe=safe_box)
  fn align_text(
    text : @rich.Text,
    width : Int,
    align : @rich.AlignMethod,
    character : String,
    style : @rich.Style,
  ) -> @rich.Text raise {
    let text = text.copy()
    text.truncate(width)
    let excess_space = width - @cells.cell_len(text.plain())
    if text.style.to_bool() {
      text.stylize(console.get_style(text.style))
    }
    if excess_space != 0 {
      match align {
        Left =>
          @rich.Text::assemble(
            [text, (character.repeat(excess_space), style)],
            no_wrap=true,
            end="",
          )
        Center => {
          let left = floor_div(excess_space, 2)
          @rich.Text::assemble(
            [
              (character.repeat(left), style),
              text,
              (character.repeat(excess_space - left), style),
            ],
            no_wrap=true,
            end="",
          )
        }
        Right =>
          @rich.Text::assemble(
            [(character.repeat(excess_space), style), text],
            no_wrap=true,
            end="",
          )
      }
    } else {
      text
    }
  }

  let title_text = make_title(self.title)
  if title_text is Some(t) {
    t.stylize_before(border_style)
  }
  let mut child_width = if self.expand {
    width - 2
  } else {
    console.measure(renderable, options=options.update_width(width - 2)).maximum
  }
  let mut child_height = match self.height {
    Some(h) if h != 0 => Some(h)
    _ =>
      match options.height {
        Some(h) if h != 0 => Some(h)
        _ => None
      }
  }
  if child_height is Some(h) {
    child_height = Some(h - 2)
  }
  if title_text is Some(t) {
    child_width = @cmp.minimum(
      options.max_width - 2,
      @cmp.maximum(child_width, t.cell_len() + 2),
    )
  }
  let width = child_width + 2
  let child_options = options.update(
    width=child_width,
    height=child_height,
    highlight=Some(self.highlight),
  )
  let lines = console.render_lines(renderable, options=child_options, style~)
  let line_start = @rich.Segment::new(box_.mid_left, style=border_style)
  let line_end = @rich.Segment::new(box_.mid_right, style=border_style)
  let new_line = @rich.Segment::line()
  let out : Array[@rich.RenderItem] = []
  match title_text {
    Some(t) if width > 4 => {
      let t = align_text(t, width - 4, self.title_align, box_.top, border_style)
      out.push(
        Seg(@rich.Segment::new(box_.top_left + box_.top, style=border_style)),
      )
      for s in console.render(t, options=child_options.update_width(width - 4)) {
        out.push(Seg(s))
      }
      out.push(
        Seg(@rich.Segment::new(box_.top + box_.top_right, style=border_style)),
      )
    }
    _ =>
      out.push(
        Seg(@rich.Segment::new(box_.get_top([width - 2]), style=border_style)),
      )
  }
  out.push(Seg(new_line))
  for line in lines {
    out.push(Seg(line_start))
    for s in line {
      out.push(Seg(s))
    }
    out.push(Seg(line_end))
    out.push(Seg(new_line))
  }
  let subtitle_text = make_title(self.subtitle)
  if subtitle_text is Some(t) {
    t.stylize_before(border_style)
  }
  match subtitle_text {
    Some(t) if width > 4 => {
      let t = align_text(
        t,
        width - 4,
        self.subtitle_align,
        box_.bottom,
        border_style,
      )
      out.push(
        Seg(
          @rich.Segment::new(box_.bottom_left + box_.bottom, style=border_style),
        ),
      )
      for s in console.render(t, options=child_options.update_width(width - 4)) {
        out.push(Seg(s))
      }
      out.push(
        Seg(
          @rich.Segment::new(
            box_.bottom + box_.bottom_right,
            style=border_style,
          ),
        ),
      )
    }
    _ =>
      out.push(
        Seg(
          @rich.Segment::new(box_.get_bottom([width - 2]), style=border_style),
        ),
      )
  }
  out.push(Seg(new_line))
  out
}

///|
pub impl @rich.Renderable for Panel with fn rich_measure(self, console, options) {
  let title = make_title(self.title)
  let (_, right, _, left) = @rich.unpack_padding(self.padding)
  let padding = left + right
  let renderables : Array[&@rich.Renderable] = match title {
    Some(t) => [self.renderable, t]
    None => [self.renderable]
  }
  let width = match self.width {
    None =>
      @rich.measure_renderables(
        console,
        options.update_width(options.max_width - padding - 2),
        renderables,
      ).maximum +
      padding +
      2
    Some(w) => w
  }
  Some(@rich.Measurement::new(width, width))
}
