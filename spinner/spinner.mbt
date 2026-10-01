// Port of rich/spinner.py.

///|
/// A spinner animation.
///
/// The frame shown depends on the time passed to `render` (when printed,
/// `console.get_time()`), so a spinner animates whenever it is re-rendered,
/// e.g. by a `Live` display.
pub(all) struct Spinner {
  /// Renderable displayed to the right of the spinner.
  mut text : &@rich.Renderable
  /// Name of the spinner animation.
  name : String
  /// Animation frames.
  frames : Array[String]
  /// Interval between frames, in milliseconds.
  interval : Double
  /// Time of the first render, or `None` if not rendered yet.
  mut start_time : Double?
  /// Style of the animation.
  mut style : @rich.StyleType?
  /// Speed factor.
  mut speed : Double
  /// Frame offset (used when the speed changes).
  mut frame_no_offset : Double
  priv mut update_speed : Double
}

///|
/// Create a spinner. `name` is one of `spinner_names()`; a string `text`
/// is parsed as console markup.
///
/// Raises `ValueError` (upstream `KeyError`) for an unknown spinner name.
pub fn Spinner::new(
  name : String,
  text? : &@rich.Renderable = "",
  style? : &@rich.IntoStyle,
  speed? : Double = 1.0,
) -> Spinner raise @rich.RichError {
  guard spinners.get(name) is Some((interval, frames)) else {
    raise ValueError("no spinner called \{@rich.py_repr(name)}")
  }
  {
    text: markup_text(text),
    name,
    frames: frames.copy(),
    interval,
    start_time: None,
    style: style.map(s => s.into_style_type()),
    speed,
    frame_no_offset: 0.0,
    update_speed: 0.0,
  }
}

///|
/// Names of all the spinner animations (in upstream order).
pub fn spinner_names() -> Array[String] {
  spinners.keys().collect()
}

///|
fn markup_text(
  text : &@rich.Renderable,
) -> &@rich.Renderable raise @rich.RichError {
  match text.text_kind() {
    Str(s) => @rich.Text::from_markup(s) as &@rich.Renderable
    _ => text
  }
}

///|
/// Python truthiness of a renderable (strings and Text are false when
/// empty, other objects are true).
fn truthy(r : &@rich.Renderable) -> Bool {
  match r.text_kind() {
    Str(s) => s != ""
    Text(t) => t.length() > 0
    NotText => true
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
/// Render the spinner for a given time (in seconds).
pub fn Spinner::render(self : Spinner, time : Double) -> &@rich.Renderable {
  if self.start_time is None {
    self.start_time = Some(time)
  }
  let start_time = self.start_time.unwrap()
  let frame_no = (time - start_time) * self.speed / (self.interval / 1000.0) +
    self.frame_no_offset
  let index = floor_mod(frame_no.to_int(), self.frames.length())
  let frame = @rich.Text::new(
    text=self.frames[index],
    style=self.style.unwrap_or(Def("")),
  )
  if self.update_speed != 0.0 {
    self.frame_no_offset = frame_no
    self.start_time = Some(time)
    self.speed = self.update_speed
    self.update_speed = 0.0
  }
  if !truthy(self.text) {
    return frame
  }
  match self.text.text_kind() {
    Str(s) => @rich.Text::assemble([frame, " ", s]) as &@rich.Renderable
    Text(t) => @rich.Text::assemble([frame, " ", t])
    NotText => {
      let table = @rich.Table::grid(padding=[1]) catch {
        _ => abort("unreachable: grid with valid padding")
      }
      table.add_row([frame, self.text])
      table
    }
  }
}

///|
/// Update attributes of a spinner after it has been started. Falsy
/// values (empty text, empty style, zero speed) leave the attribute
/// unchanged.
pub fn Spinner::update(
  self : Spinner,
  text? : &@rich.Renderable = "",
  style? : &@rich.IntoStyle,
  speed? : Double,
) -> Unit raise @rich.RichError {
  if truthy(text) {
    self.text = markup_text(text)
  }
  if style is Some(s) && s.into_style_type().to_bool() {
    self.style = Some(s.into_style_type())
  }
  if speed is Some(s) && s != 0.0 {
    self.update_speed = s
  }
}

///|
pub impl @rich.Renderable for Spinner with fn rich_console(
  self,
  console,
  _options,
) {
  [Child(self.render((console.get_time)()))]
}

///|
pub impl @rich.Renderable for Spinner with fn rich_measure(
  self,
  console,
  options,
) {
  let text = self.render(0.0)
  Some(@rich.Measurement::get(console, options, text))
}
