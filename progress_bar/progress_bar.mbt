// Port of rich/progress_bar.py.

///|
/// Number of characters before the 'pulse' animation repeats.
pub let pulse_size : Int = 20

///|
/// Renders a (progress) bar. Used by `@progress`.
pub(all) struct ProgressBar {
  /// Number of steps in the bar, or `None` for a pulsing animation.
  mut total : Double?
  /// Number of steps completed.
  mut completed : Double
  /// Width of the bar, or `None` for maximum width.
  mut width : Int?
  /// Enable the pulse effect.
  mut pulse : Bool
  /// Style for the bar background.
  mut style : @rich.StyleType
  /// Style for the completed bar.
  mut complete_style : @rich.StyleType
  /// Style for a finished bar.
  mut finished_style : @rich.StyleType
  /// Style for pulsing bars.
  mut pulse_style : @rich.StyleType
  /// Time in seconds to use for the animation, or `None` to use the
  /// console clock (`console.get_time`).
  mut animation_time : Double?
}

///|
/// Create a progress bar. `total=None` renders a pulsing animation.
pub fn ProgressBar::new(
  total? : Double? = Some(100.0),
  completed? : Double = 0.0,
  width? : Int,
  pulse? : Bool = false,
  style? : &@rich.IntoStyle = "bar.back",
  complete_style? : &@rich.IntoStyle = "bar.complete",
  finished_style? : &@rich.IntoStyle = "bar.finished",
  pulse_style? : &@rich.IntoStyle = "bar.pulse",
  animation_time? : Double,
) -> ProgressBar {
  {
    total,
    completed,
    width,
    pulse,
    style: style.into_style_type(),
    complete_style: complete_style.into_style_type(),
    finished_style: finished_style.into_style_type(),
    pulse_style: pulse_style.into_style_type(),
    animation_time,
  }
}

///|
/// Upstream `repr(bar)`, e.g. `<Bar 50.0 of 100.0>`.
pub fn ProgressBar::repr(self : ProgressBar) -> String {
  let total = match self.total {
    Some(t) => @rich.py_float_repr(t)
    None => "None"
  }
  "<Bar \{@rich.py_float_repr(self.completed)} of \{total}>"
}

///|
/// Percentage complete (0-100), or `None` if the total is unknown.
pub fn ProgressBar::percentage_completed(self : ProgressBar) -> Double? {
  match self.total {
    None => None
    Some(total) => {
      let completed = self.completed / total * 100.0
      Some(@cmp.minimum(100.0, @cmp.maximum(0.0, completed)))
    }
  }
}

///|
/// Get the segments to render a pulse animation (one segment per
/// character). `color_system` is the console's color system name
/// (`console.color_system()`).
pub fn ProgressBar::get_pulse_segments(
  _self : ProgressBar,
  fore_style : @rich.Style,
  back_style : @rich.Style,
  color_system : String?,
  no_color : Bool,
  ascii? : Bool = false,
) -> Array[@rich.Segment] {
  let bar = if ascii { "-" } else { "━" }
  let segments : Array[@rich.Segment] = []
  // Upstream compares against "eight_bit", which is never a color system
  // name, so 256 color consoles get the plain pulse.
  let blend = match color_system {
    Some("standard") | Some("eight_bit") | Some("truecolor") => !no_color
    _ => false
  }
  if !blend {
    for _ in 0..<(pulse_size / 2) {
      segments.push(@rich.Segment::new(bar, style=fore_style))
    }
    for _ in 0..<(pulse_size - pulse_size / 2) {
      segments.push(
        @rich.Segment::new(if no_color { " " } else { bar }, style=back_style),
      )
    }
    return segments
  }
  let fore_color = match fore_style.color() {
    Some(c) => c.get_truecolor()
    None => @color.ColorTriplet::new(255, 0, 255)
  }
  let back_color = match back_style.color() {
    Some(c) => c.get_truecolor()
    None => @color.ColorTriplet::new(0, 0, 0)
  }
  for index in 0..<pulse_size {
    let position = index.to_double() / pulse_size.to_double()
    let fade = 0.5 + @math.cos(position * @math.PI * 2.0) / 2.0
    let color = @color.blend_rgb(fore_color, back_color, cross_fade=fade)
    segments.push(
      @rich.Segment::new(
        bar,
        style=@rich.Style::new(color=@color.Color::from_triplet(color)),
      ),
    )
  }
  segments
}

///|
/// Update progress with new values. `total=None` leaves the total
/// unchanged.
pub fn ProgressBar::update(
  self : ProgressBar,
  completed : Double,
  total? : Double,
) -> Unit {
  self.completed = completed
  if total is Some(_) {
    self.total = total
  }
}

///|
fn floor_mod(a : Int, b : Int) -> Int {
  let r = a % b
  if r != 0 && (r < 0) != (b < 0) {
    r + b
  } else {
    r
  }
}

///|
fn ProgressBar::render_pulse(
  self : ProgressBar,
  console : @rich.Console,
  width : Int,
  ascii : Bool,
) -> Array[@rich.Segment] raise {
  let fore_style = console.get_style(self.pulse_style, default=Def("white"))
  let back_style = console.get_style(self.style, default=Def("black"))
  let pulse_segments = self.get_pulse_segments(
    fore_style,
    back_style,
    console.color_system(),
    console.no_color,
    ascii~,
  )
  let segment_count = pulse_segments.length()
  let current_time = match self.animation_time {
    Some(t) => t
    None => (console.get_time)()
  }
  let segments = []
  let repeats = (width.to_double() / segment_count.to_double()).to_int() + 2
  for _ in 0..<repeats {
    segments.append(pulse_segments)
  }
  let offset = floor_mod((-current_time * 15.0).to_int(), segment_count)
  let end = @cmp.minimum(offset + width, segments.length())
  segments[offset:end].to_owned()
}

///|
pub impl @rich.Renderable for ProgressBar with fn rich_console(
  self,
  console,
  options,
) {
  let width = @cmp.minimum(
    match self.width {
      Some(w) if w != 0 => w
      _ => options.max_width
    },
    options.max_width,
  )
  let ascii = options.legacy_windows || options.ascii_only()
  let should_pulse = self.pulse || self.total is None
  if should_pulse {
    return @rich.segments_to_items(self.render_pulse(console, width, ascii))
  }
  let total = self.total.unwrap()
  let completed = @cmp.minimum(total, @cmp.maximum(0.0, self.completed))
  let bar = if ascii { "-" } else { "━" }
  let half_bar_right = if ascii { " " } else { "╸" }
  let half_bar_left = if ascii { " " } else { "╺" }
  let complete_halves = if total != 0.0 {
    (width.to_double() * 2.0 * completed / total).to_int()
  } else {
    width * 2
  }
  let bar_count = complete_halves / 2
  let half_bar_count = complete_halves % 2
  let style = console.get_style(self.style)
  let is_finished = self.completed >= total
  let complete_style = console.get_style(
    if is_finished {
      self.finished_style
    } else {
      self.complete_style
    },
  )
  let out : Array[@rich.RenderItem] = []
  if bar_count != 0 {
    out.push(
      Seg(@rich.Segment::new(bar.repeat(bar_count), style=complete_style)),
    )
  }
  if half_bar_count != 0 {
    out.push(
      Seg(
        @rich.Segment::new(
          half_bar_right.repeat(half_bar_count),
          style=complete_style,
        ),
      ),
    )
  }
  if !console.no_color {
    let mut remaining_bars = width - bar_count - half_bar_count
    if remaining_bars != 0 && console.color_system() is Some(_) {
      if half_bar_count == 0 && bar_count != 0 {
        out.push(Seg(@rich.Segment::new(half_bar_left, style~)))
        remaining_bars -= 1
      }
      if remaining_bars != 0 {
        out.push(Seg(@rich.Segment::new(bar.repeat(remaining_bars), style~)))
      }
    }
  }
  out
}

///|
pub impl @rich.Renderable for ProgressBar with fn rich_measure(
  self,
  _console,
  options,
) {
  match self.width {
    Some(w) => Some(@rich.Measurement::new(w, w))
    None => Some(@rich.Measurement::new(4, options.max_width))
  }
}
