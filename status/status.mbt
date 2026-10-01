// Port of rich/status.py.

///|
/// Displays a status indicator with a 'spinner' animation.
///
/// Upstream `console.status(...)` is `Status::new(..., console=console)`.
pub(all) struct Status {
  /// The status renderable (str or Text typically).
  mut status : &@rich.Renderable
  /// Style of the spinner.
  mut spinner_style : @rich.StyleType
  /// Speed factor of the spinner animation.
  mut speed : Double
  priv mut spinner : @spinner.Spinner
  priv live : @live.Live
}

///|
/// Create a status display.
///
/// * `status`: a status renderable (str or Text typically).
/// * `console`: defaults to the global console.
/// * `spinner`: name of the spinner animation (see `@spinner.spinner_names`).
/// * `spinner_style`: style of the spinner.
/// * `speed`: speed factor for the spinner animation.
/// * `refresh_per_second`: number of refreshes per second.
pub fn Status::new(
  status : &@rich.Renderable,
  console? : @rich.Console,
  spinner? : String = "dots",
  spinner_style? : &@rich.IntoStyle = "status.spinner",
  speed? : Double = 1.0,
  refresh_per_second? : Double = 12.5,
) -> Status raise @rich.RichError {
  let spinner_style = spinner_style.into_style_type()
  let spinner = @spinner.Spinner::new(
    spinner,
    text=status,
    style=spinner_style,
    speed~,
  )
  let live = @live.Live::new(
    renderable=spinner,
    console?,
    refresh_per_second~,
    transient=true,
  )
  { status, spinner_style, speed, spinner, live, }
}

///|
/// The spinner being displayed.
pub fn Status::renderable(self : Status) -> @spinner.Spinner {
  self.spinner
}

///|
/// The console used by the status display.
pub fn Status::console(self : Status) -> @rich.Console {
  self.live.console
}

///|
/// The live display used to show the status.
pub fn Status::live(self : Status) -> @live.Live {
  self.live
}

///|
/// Update the status. Omitted arguments are left unchanged. A new
/// `spinner` name replaces the spinner and refreshes the display;
/// otherwise the display is refreshed if auto refresh is due.
pub fn Status::update(
  self : Status,
  status? : &@rich.Renderable,
  spinner? : String,
  spinner_style? : &@rich.IntoStyle,
  speed? : Double,
) -> Unit raise {
  if status is Some(s) {
    self.status = s
  }
  if spinner_style is Some(s) {
    self.spinner_style = s.into_style_type()
  }
  if speed is Some(s) {
    self.speed = s
  }
  if spinner is Some(name) {
    self.spinner = @spinner.Spinner::new(
      name,
      text=self.status,
      style=self.spinner_style,
      speed=self.speed,
    )
    self.live.update(self.spinner, refresh=true)
  } else {
    self.spinner.update(
      text=self.status,
      style=self.spinner_style,
      speed=self.speed,
    )
    self.live.tick()
  }
}

///|
/// Start the status animation.
pub fn Status::start(self : Status) -> Unit raise {
  self.live.start()
}

///|
/// Stop the spinner animation.
pub fn Status::stop(self : Status) -> Unit raise {
  self.live.stop()
}

///|
/// Refresh the display if it is due (see `@live.Live::tick`). Call this
/// from long running work to animate the spinner.
pub fn Status::tick(self : Status) -> Unit raise {
  self.live.tick()
}

///|
/// Run `f` with the status displayed (upstream `with console.status(...)`).
pub fn Status::run(self : Status, f : () -> Unit raise) -> Unit raise {
  self.start()
  {
    errdefer self.stop()
    f()
  }
  self.stop()
}

///|
pub impl @rich.Renderable for Status with fn rich_console(
  self,
  _console,
  _options,
) {
  [Child(self.spinner)]
}
