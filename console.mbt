// Port of rich/console.py.

///|
/// A file-like object the console writes to (upstream `IO[str]`).
pub(open) trait ConsoleFile {
  fn write(Self, String) -> Unit raise
  fn flush(Self) -> Unit raise = _
  /// Whether the file is a terminal.
  fn isatty(Self) -> Bool = _
  /// Encoding of the file, e.g. `"utf-8"`.
  fn encoding(Self) -> String = _
}

///|
impl ConsoleFile with fn flush(_self) {
  ()
}

///|
impl ConsoleFile with fn isatty(_self) {
  false
}

///|
impl ConsoleFile with fn encoding(_self) {
  "utf-8"
}

///|
/// Standard output or standard error.
pub struct StdStream {
  fd : Int
}

///|
/// The standard output stream.
pub fn StdStream::stdout() -> StdStream {
  { fd: 1, }
}

///|
/// The standard error stream.
pub fn StdStream::stderr() -> StdStream {
  { fd: 2, }
}

///|
pub impl ConsoleFile for StdStream with fn write(self, text) {
  if !@term.write_fd(self.fd, text) {
    raise WriteError("failed to write to file descriptor \{self.fd}")
  }
}

///|
pub impl ConsoleFile for StdStream with fn flush(self) {
  @term.flush_fd(self.fd)
}

///|
pub impl ConsoleFile for StdStream with fn isatty(self) {
  @term.isatty(self.fd)
}

///|
/// An in-memory text file (upstream `io.StringIO`).
pub struct StringIO {
  priv buffer : StringBuilder
  priv tty : Bool
}

///|
/// Create an in-memory file. With `isatty`, it claims to be a terminal.
pub fn StringIO::new(isatty? : Bool = false) -> StringIO {
  { buffer: StringBuilder(), tty: isatty, }
}

///|
/// Everything written so far.
pub fn StringIO::getvalue(self : StringIO) -> String {
  self.buffer.to_string()
}

///|
/// Discard the contents.
pub fn StringIO::reset(self : StringIO) -> Unit {
  self.buffer.reset()
}

///|
pub impl ConsoleFile for StringIO with fn write(self, text) {
  self.buffer.write_string(text)
}

///|
pub impl ConsoleFile for StringIO with fn isatty(self) {
  self.tty
}

///|
/// A file that discards everything (upstream `NullFile`).
pub struct NullFile {}

///|
pub fn NullFile::new() -> NullFile {
  NullFile::{ }
}

///|
pub impl ConsoleFile for NullFile with fn write(_self, _text) {
  ()
}

///|
/// Hook that may process renderables before they are rendered.
pub(open) trait RenderHook {
  fn process_renderables(Self, Array[&Renderable]) -> Array[&Renderable] raise
}

///|
/// A renderable to generate new line(s).
pub struct NewLine {
  count : Int
}

///|
pub fn NewLine::new(count? : Int = 1) -> NewLine {
  { count, }
}

///|
pub impl Renderable for NewLine with fn rich_console(self, _console, _options) {
  [Seg(Segment::new("\n".repeat(self.count)))]
}

///|
/// Render a list of lines at a given offset.
pub struct ScreenUpdate {
  lines : Array[Array[Segment]]
  x : Int
  y : Int
}

///|
pub fn ScreenUpdate::new(
  lines : Array[Array[Segment]],
  x : Int,
  y : Int,
) -> ScreenUpdate {
  { lines, x, y, }
}

///|
pub impl Renderable for ScreenUpdate with fn rich_console(
  self,
  _console,
  _options,
) {
  let out = []
  for i, line in self.lines {
    out.push(Seg(Control::move_to(self.x, self.y + i).segment))
    for seg in line {
      out.push(Seg(seg))
    }
  }
  out
}

///|
/// Takes a group of renderables and returns a renderable object that
/// renders the group.
pub struct Group {
  renderables : Array[&Renderable]
  fit : Bool
}

///|
pub fn Group::new(
  renderables : Array[&Renderable],
  fit? : Bool = true,
) -> Group {
  { renderables, fit, }
}

///|
pub impl Renderable for Group with fn rich_measure(self, console, options) {
  if self.fit {
    Some(measure_renderables(console, options, self.renderables))
  } else {
    Some({ minimum: options.max_width, maximum: options.max_width, })
  }
}

///|
pub impl Renderable for Group with fn rich_console(self, _console, _options) {
  self.renderables.map(r => Child(r))
}

///|
/// The console color system names.
fn color_system_from_name(name : String) -> @color.ColorSystem? raise RichError {
  match name {
    "standard" => Some(Standard)
    "256" => Some(EightBit)
    "truecolor" => Some(Truecolor)
    "windows" => Some(Windows)
    _ => raise ValueError("invalid color system \{py_repr(name)}")
  }
}

///|
fn color_system_name(system : @color.ColorSystem) -> String {
  match system {
    Standard => "standard"
    EightBit => "256"
    Truecolor => "truecolor"
    Windows => "windows"
  }
}

///|
/// A high level console interface.
pub(all) struct Console {
  priv mut file_ : &ConsoleFile?
  /// Use stderr rather than stdout if no file is set.
  mut stderr : Bool
  /// Suppress all output.
  mut quiet : Bool
  /// Number of spaces used to replace a tab character.
  mut tab_size : Int
  /// Record terminal output (required for the export methods).
  mut record : Bool
  /// Default soft wrap mode for `print`.
  mut soft_wrap : Bool
  /// Legacy Windows mode.
  mut legacy_windows : Bool
  /// Restrict box options that don't render on legacy Windows.
  mut safe_box : Bool
  /// Disable colors.
  mut no_color : Bool
  /// Whether the console is interactive.
  mut is_interactive : Bool
  /// Whether running in Jupyter (always false in MoonBit).
  is_jupyter : Bool
  /// Style applied to all output.
  mut style : StyleType?
  /// Default highlighter.
  mut highlighter : &Highlighter
  /// Get the current time (seconds since the epoch) for `log`.
  mut get_datetime : () -> Double
  /// Monotonic clock in seconds.
  mut get_time : () -> Double
  priv markup_ : Bool
  priv emoji_ : Bool
  priv emoji_variant : EmojiVariant?
  priv highlight_ : Bool
  priv mut width_ : Int?
  priv mut height_ : Int?
  priv color_system_ : @color.ColorSystem?
  priv force_terminal : Bool?
  priv environ : Map[String, String]?
  priv log_render : LogRender
  priv buffer : Array[Segment]
  priv mut buffer_index : Int
  priv theme_stack : ThemeStack
  priv record_buffer : Array[Segment]
  priv render_hooks : Array[&RenderHook]
  priv live_stack : Array[Int]
  priv mut is_alt_screen_ : Bool
}

///|
/// Create a console.
///
/// `color_system` is `Some("auto")` (detect), `Some("standard")`,
/// `Some("256")`, `Some("truecolor")`, `Some("windows")`, or `None` for no
/// color. `environ` replaces the process environment (for testing).
/// `log_time_formatter` (upstream: a callable `log_time_format`) formats
/// the time of `log` instead of `log_time_format`.
pub fn Console::new(
  color_system? : String? = Some("auto"),
  force_terminal? : Bool,
  force_jupyter? : Bool,
  force_interactive? : Bool,
  soft_wrap? : Bool = false,
  theme? : Theme,
  stderr? : Bool = false,
  file? : &ConsoleFile,
  quiet? : Bool = false,
  width? : Int,
  height? : Int,
  style? : &IntoStyle,
  no_color? : Bool,
  tab_size? : Int = 8,
  record? : Bool = false,
  markup? : Bool = true,
  emoji? : Bool = true,
  emoji_variant? : EmojiVariant,
  highlight? : Bool = true,
  log_time? : Bool = true,
  log_path? : Bool = true,
  log_time_format? : String = "[%X]",
  log_time_formatter? : (Double) -> Text,
  highlighter? : &Highlighter,
  legacy_windows? : Bool,
  safe_box? : Bool = true,
  get_datetime? : () -> Double,
  get_time? : () -> Double,
  environ? : Map[String, String],
) -> Console raise RichError {
  let is_jupyter = force_jupyter.unwrap_or(false)
  fn getenv(name : String) -> String? {
    match environ {
      Some(env) => env.get(name)
      None => @env.get_env_var(name)
    }
  }

  let legacy_windows = legacy_windows.unwrap_or(false)
  let mut width = width
  let mut height = height
  if width is None {
    if getenv("COLUMNS") is Some(columns) && is_digits(columns) {
      width = Some(
        parse_int_or(columns, 80) - (if legacy_windows { 1 } else { 0 }),
      )
    }
  }
  if height is None {
    if getenv("LINES") is Some(lines) && is_digits(lines) {
      height = Some(parse_int_or(lines, 25))
    }
  }
  let console : Console = {
    file_: file,
    stderr,
    quiet,
    tab_size,
    record,
    soft_wrap,
    legacy_windows,
    safe_box,
    no_color: false,
    is_interactive: false,
    is_jupyter,
    style: style_opt(style),
    highlighter: match highlighter {
      Some(h) => h
      None => ReprHighlighter::new()
    },
    get_datetime: match get_datetime {
      Some(f) => f
      None => @term.time
    },
    get_time: match get_time {
      Some(f) => f
      None => @term.monotonic
    },
    markup_: markup,
    emoji_: emoji,
    emoji_variant,
    highlight_: highlight,
    width_: width,
    height_: height,
    color_system_: None,
    force_terminal,
    environ,
    log_render: LogRender::new(
      show_time=log_time,
      show_path=log_path,
      time_format=log_time_format,
      time_formatter?=log_time_formatter,
    ),
    buffer: [],
    buffer_index: 0,
    theme_stack: ThemeStack::new(theme.unwrap_or(default_theme)),
    record_buffer: [],
    render_hooks: [],
    live_stack: [],
    is_alt_screen_: false,
  }
  let color_system = match color_system {
    None => None
    Some("auto") => console.detect_color_system()
    Some(name) => color_system_from_name(name)
  }
  let console = { ..console, color_system_: color_system, }
  console.no_color = match no_color {
    Some(b) => b
    None => console.getenv("NO_COLOR").unwrap_or("") != ""
  }
  let mut force_interactive = force_interactive
  if force_interactive is None {
    match console.getenv("TTY_INTERACTIVE") {
      Some("0") => force_interactive = Some(false)
      Some("1") => force_interactive = Some(true)
      _ => ()
    }
  }
  console.is_interactive = match force_interactive {
    Some(b) => b
    None => console.is_terminal() && !console.is_dumb_terminal()
  }
  console
}

///|
fn is_digits(s : String) -> Bool {
  s != "" && s.iter().all(c => c >= '0' && c <= '9')
}

///|
fn parse_int_or(s : String, default : Int) -> Int {
  @string.parse_int(s) catch {
    _ => default
  }
}

///|
fn Console::getenv(self : Console, name : String) -> String? {
  match self.environ {
    Some(env) => env.get(name)
    None => @env.get_env_var(name)
  }
}

///|
/// Upstream `repr(console)`.
pub fn Console::repr(self : Console) -> String {
  let cs = match self.color_system_ {
    Some(c) => c.to_string()
    None => "None"
  }
  "<console width=\{self.width()} \{cs}>"
}

///|
/// The file the console writes to.
pub fn Console::file(self : Console) -> &ConsoleFile {
  match self.file_ {
    Some(f) => f
    None => if self.stderr { StdStream::stderr() } else { StdStream::stdout() }
  }
}

///|
/// Set a new file to write to.
pub fn Console::set_file(self : Console, file : &ConsoleFile) -> Unit {
  self.file_ = Some(file)
}

///|
fn Console::detect_color_system(self : Console) -> @color.ColorSystem? {
  if self.is_jupyter {
    return Some(Truecolor)
  }
  if !self.is_terminal() || self.is_dumb_terminal() {
    return None
  }
  let color_term = py_strip(self.getenv("COLORTERM").unwrap_or("")).to_lower()
  if color_term == "truecolor" || color_term == "24bit" {
    return Some(Truecolor)
  }
  let term = py_strip(self.getenv("TERM").unwrap_or("")).to_lower()
  let colors = match term.rev_find("-") {
    Some(i) => py_slice(term, i + 1, term.length())
    None => term
  }
  match colors {
    "kitty" | "256color" => Some(EightBit)
    "16color" => Some(Standard)
    _ => Some(Standard)
  }
}

///|
/// Enter a buffer context: all output is buffered until the matching
/// `exit_buffer`.
pub fn Console::enter_buffer(self : Console) -> Unit {
  self.buffer_index += 1
}

///|
/// Leave a buffer context, and render content if required.
pub fn Console::exit_buffer(self : Console) -> Unit raise {
  self.buffer_index -= 1
  self.check_buffer()
}

///|
/// Run `f` with output buffered (upstream `with console:`).
pub fn Console::buffered(self : Console, f : () -> Unit raise) -> Unit raise {
  self.enter_buffer()
  {
    errdefer self.exit_buffer()
    f()
  }
  self.exit_buffer()
}

///|
/// Register a live display. Returns `true` if it is the top-most one.
pub fn Console::set_live(self : Console, live_id : Int) -> Bool {
  self.live_stack.push(live_id)
  self.live_stack.length() == 1
}

///|
/// Remove the top-most live display.
pub fn Console::clear_live(self : Console) -> Unit {
  ignore(self.live_stack.pop())
}

///|
/// The ids of the active live displays (innermost last).
pub fn Console::live_stack(self : Console) -> Array[Int] {
  self.live_stack.copy()
}

///|
/// Add a new render hook to the stack.
pub fn Console::push_render_hook(self : Console, hook : &RenderHook) -> Unit {
  self.render_hooks.push(hook)
}

///|
/// Pop the last render hook from the stack.
pub fn Console::pop_render_hook(self : Console) -> Unit {
  ignore(self.render_hooks.pop())
}

///|
/// Begin capturing console output. Call `end_capture` to exit capture mode
/// and return output.
pub fn Console::begin_capture(self : Console) -> Unit {
  self.enter_buffer()
}

///|
/// End capture mode and return captured string.
pub fn Console::end_capture(self : Console) -> String raise {
  let render_result = self.render_buffer(self.buffer)
  self.buffer.clear()
  self.exit_buffer()
  render_result
}

///|
/// Capture the output of `f` instead of writing it to the console.
pub fn Console::capture(self : Console, f : () -> Unit raise) -> String raise {
  self.begin_capture()
  {
    errdefer {
      self.buffer.clear()
      self.buffer_index -= 1
    }
    f()
  }
  self.end_capture()
}

///|
/// Push a new theme on to the top of the stack.
pub fn Console::push_theme(
  self : Console,
  theme : Theme,
  inherit_styles? : Bool = true,
) -> Unit {
  self.theme_stack.push_theme(theme, inherit_styles~)
}

///|
/// Remove theme from top of stack, restoring previous theme.
pub fn Console::pop_theme(self : Console) -> Unit raise RichError {
  self.theme_stack.pop_theme()
}

///|
/// Use a different theme for the duration of `f`.
pub fn Console::use_theme(
  self : Console,
  theme : Theme,
  f : () -> Unit raise,
  inherit_styles? : Bool = true,
) -> Unit raise {
  self.push_theme(theme, inherit_styles~)
  {
    errdefer self.pop_theme()
    f()
  }
  self.pop_theme()
}

///|
/// The color system name: `"standard"`, `"256"`, `"truecolor"`,
/// `"windows"`, or `None`.
pub fn Console::color_system(self : Console) -> String? {
  self.color_system_.map(color_system_name)
}

///|
/// The detected or configured color system.
pub fn Console::color_system_enum(self : Console) -> @color.ColorSystem? {
  self.color_system_
}

///|
/// The encoding of the console file, e.g. `"utf-8"`.
pub fn Console::encoding(self : Console) -> String {
  let e = self.file().encoding()
  if e == "" {
    "utf-8"
  } else {
    e.to_lower()
  }
}

///|
/// Check if the console is writing to a terminal.
pub fn Console::is_terminal(self : Console) -> Bool {
  if self.force_terminal is Some(f) {
    return f
  }
  if self.is_jupyter {
    return false
  }
  match self.getenv("TTY_COMPATIBLE") {
    Some("0") => return false
    Some("1") => return true
    _ => ()
  }
  if self.getenv("FORCE_COLOR") is Some(force_color) {
    return force_color != ""
  }
  self.file().isatty()
}

///|
/// Detect dumb terminal.
pub fn Console::is_dumb_terminal(self : Console) -> Bool {
  let term = self.getenv("TERM").unwrap_or("").to_lower()
  let is_dumb = term == "dumb" || term == "unknown"
  self.is_terminal() && is_dumb
}

///|
/// Default console options.
pub fn Console::options(self : Console) -> ConsoleOptions {
  let size = self.size()
  {
    max_height: size.height,
    size,
    legacy_windows: self.legacy_windows,
    min_width: 1,
    max_width: size.width,
    encoding: self.encoding(),
    is_terminal: self.is_terminal(),
    justify: None,
    overflow: None,
    no_wrap: Some(false),
    highlight: None,
    markup: None,
    height: None,
  }
}

///|
/// The size of the console.
pub fn Console::size(self : Console) -> ConsoleDimensions {
  let lw = if self.legacy_windows { 1 } else { 0 }
  if self.width_ is Some(w) && self.height_ is Some(h) {
    return { width: w - lw, height: h, }
  }
  if self.is_dumb_terminal() {
    return { width: 80, height: 25, }
  }
  let mut width : Int? = None
  let mut height : Int? = None
  for fd in [0, 1, 2] {
    if @term.terminal_size(fd) is Some((w, h)) {
      width = Some(w)
      height = Some(h)
      break
    }
  }
  if self.getenv("COLUMNS") is Some(columns) && is_digits(columns) {
    width = Some(parse_int_or(columns, 80))
  }
  if self.getenv("LINES") is Some(lines) && is_digits(lines) {
    height = Some(parse_int_or(lines, 25))
  }
  let width = match width {
    Some(w) if w != 0 => w
    _ => 80
  }
  let height = match height {
    Some(h) if h != 0 => h
    _ => 25
  }
  {
    width: match self.width_ {
      None => width - lw
      Some(w) => w
    },
    height: match self.height_ {
      None => height
      Some(h) => h
    },
  }
}

///|
/// Set a new size for the terminal.
pub fn Console::set_size(self : Console, width : Int, height : Int) -> Unit {
  self.width_ = Some(width)
  self.height_ = Some(height)
}

///|
/// The width of the console.
pub fn Console::width(self : Console) -> Int {
  self.size().width
}

///|
/// Set the width of the console.
pub fn Console::set_width(self : Console, width : Int) -> Unit {
  self.width_ = Some(width)
}

///|
/// The height of the console.
pub fn Console::height(self : Console) -> Int {
  self.size().height
}

///|
/// Set the height of the console.
pub fn Console::set_height(self : Console, height : Int) -> Unit {
  self.height_ = Some(height)
}

///|
/// Play a 'bell' sound (if supported by the terminal).
pub fn Console::bell(self : Console) -> Unit raise {
  self.control([Control::bell()])
}

///|
/// Write new line(s).
pub fn Console::line(self : Console, count? : Int = 1) -> Unit raise {
  guard count >= 0 else { raise ValueError("count must be >= 0") }
  self.print(NewLine::new(count~))
}

///|
/// Clear the screen.
pub fn Console::clear(self : Console, home? : Bool = true) -> Unit raise {
  if home {
    self.control([Control::clear(), Control::home()])
  } else {
    self.control([Control::clear()])
  }
}

///|
/// Show or hide the cursor.
pub fn Console::show_cursor(self : Console, show? : Bool = true) -> Bool raise {
  if self.is_terminal() {
    self.control([Control::show_cursor(show)])
    true
  } else {
    false
  }
}

///|
/// Enable or disable the alternative screen mode. Returns `true` if the
/// control codes were written.
pub fn Console::set_alt_screen(
  self : Console,
  enable? : Bool = true,
) -> Bool raise {
  if self.is_terminal() && !self.legacy_windows {
    self.control([Control::alt_screen(enable)])
    self.is_alt_screen_ = enable
    true
  } else {
    false
  }
}

///|
/// Check if the alt screen was enabled.
pub fn Console::is_alt_screen(self : Console) -> Bool {
  self.is_alt_screen_
}

///|
/// Set the title of the console terminal window.
pub fn Console::set_window_title(self : Console, title : String) -> Bool raise {
  if self.is_terminal() {
    self.control([Control::title(title)])
    true
  } else {
    false
  }
}

///|
/// A context that enables the alternate screen (upstream `ScreenContext`,
/// returned by `console.screen()`).
pub struct ScreenContext {
  console : Console
  hide_cursor : Bool
  screen : Screen
  priv mut changed : Bool
}

///|
/// Create a screen context; call `enter` / `exit`, or use `Console::screen`.
pub fn Console::screen_context(
  self : Console,
  hide_cursor? : Bool = true,
  style? : &IntoStyle,
) -> ScreenContext {
  {
    console: self,
    hide_cursor,
    screen: Screen::new([], style=style_or_empty(style)),
    changed: false,
  }
}

///|
/// Update the screen with new renderables (and / or a new style).
pub fn ScreenContext::update(
  self : ScreenContext,
  renderables? : Array[&Renderable] = [],
  style? : &IntoStyle,
) -> Unit raise {
  if renderables.length() > 0 {
    self.screen.renderable = if renderables.length() > 1 {
      (Group::new(renderables) : &Renderable)
    } else {
      renderables[0]
    }
  }
  if style is Some(style) {
    self.screen.style = Some(style.into_style_type())
  }
  self.console.print(self.screen, end="")
}

///|
/// Enable the alternate screen (and hide the cursor).
pub fn ScreenContext::enter(self : ScreenContext) -> Unit raise {
  self.changed = self.console.set_alt_screen(enable=true)
  if self.changed && self.hide_cursor {
    self.console.show_cursor(show=false) |> ignore
  }
}

///|
/// Restore the normal screen (and the cursor).
pub fn ScreenContext::exit(self : ScreenContext) -> Unit raise {
  if self.changed {
    self.console.set_alt_screen(enable=false) |> ignore
    if self.hide_cursor {
      self.console.show_cursor(show=true) |> ignore
    }
  }
}

///|
/// Run `f` in the alternate screen (upstream `with console.screen() as
/// screen:`).
pub fn Console::screen(
  self : Console,
  f : (ScreenContext) -> Unit raise,
  hide_cursor? : Bool = true,
  style? : &IntoStyle,
) -> Unit raise {
  let context = self.screen_context(hide_cursor~, style?)
  context.enter()
  {
    errdefer context.exit()
    f(context)
  }
  context.exit()
}

///|
/// Measure a renderable.
pub fn Console::measure(
  self : Console,
  renderable : &Renderable,
  options? : ConsoleOptions,
) -> Measurement raise {
  Measurement::get(
    self,
    options.unwrap_or_else(() => self.options()),
    renderable,
  )
}

///|
/// Render an object in to segments.
pub fn Console::render(
  self : Console,
  renderable : &Renderable,
  options? : ConsoleOptions,
) -> Array[Segment] raise {
  let out = []
  self.render_into(
    renderable,
    options.unwrap_or_else(() => self.options()),
    out,
    0,
  )
  out
}

///|
fn Console::render_into(
  self : Console,
  renderable : &Renderable,
  options : ConsoleOptions,
  out : Array[Segment],
  depth : Int,
) -> Unit raise {
  if options.max_width < 1 {
    return
  }
  if depth > 1000 {
    raise NotRenderableError("maximum render depth exceeded")
  }
  // Strings and Text (whose `text_kind` is not `NotText`, see
  // `Renderable::text_kind`) render straight into `out`.
  match renderable.text_kind() {
    Text(t) => {
      t.render_console_into(self, options, out)
      return
    }
    Str(s) => {
      self
      .render_str(s, highlight=options.highlight, markup=options.markup)
      .render_console_into(self, options, out)
      return
    }
    NotText => ()
  }
  let items = renderable.rich_console(self, options)
  // one copy shared by all the children, made when the first one is seen
  let mut child_options = None
  for item in items {
    match item {
      Seg(s) => out.push(s)
      Child(r) => {
        let opts = match child_options {
          Some(o) => o
          None => {
            let o = options.reset_height()
            child_options = Some(o)
            o
          }
        }
        self.render_into(r, opts, out, depth + 1)
      }
    }
  }
}

///|
/// Render objects in to a list of lines.
pub fn Console::render_lines(
  self : Console,
  renderable : &Renderable,
  options? : ConsoleOptions,
  style? : Style,
  pad? : Bool = true,
  new_lines? : Bool = false,
) -> Array[Array[Segment]] raise {
  let render_options = options.unwrap_or_else(() => self.options())
  let mut rendered = self.render(renderable, options=render_options)
  if style is Some(s) && s.to_bool() {
    rendered = Segment::apply_style(rendered, style=s)
  }
  let mut lines = Segment::split_and_crop_lines(
    rendered,
    render_options.max_width,
    include_new_lines=new_lines,
    pad~,
    style?,
  )
  if render_options.height is Some(h) {
    let h = @cmp.maximum(0, h)
    if lines.length() > h {
      lines = lines[0:h].to_owned()
    }
    let extra_lines = h - lines.length()
    if extra_lines > 0 {
      let pad_line = if new_lines {
        [
          Segment::new(space_string(render_options.max_width), style?),
          Segment::new("\n"),
        ]
      } else {
        [Segment::new(space_string(render_options.max_width), style?)]
      }
      for _ in 0..<extra_lines {
        lines.push(pad_line)
      }
    }
  }
  lines
}

///|
/// Convert a string to a Text instance (markup, emoji and highlighting
/// follow the console defaults unless overridden).
pub fn Console::render_str(
  self : Console,
  text : String,
  style? : &IntoStyle,
  justify? : JustifyMethod,
  overflow? : OverflowMethod,
  emoji? : Bool?,
  markup? : Bool?,
  highlight? : Bool?,
  highlighter? : &Highlighter,
) -> Text raise {
  let emoji = emoji.unwrap_or(None)
  let markup = markup.unwrap_or(None)
  let highlight = highlight.unwrap_or(None)
  let emoji_enabled = emoji == Some(true) || (emoji is None && self.emoji_)
  let markup_enabled = markup == Some(true) || (markup is None && self.markup_)
  let highlight_enabled = highlight == Some(true) ||
    (highlight is None && self.highlight_)
  let style = style_or_empty(style)
  let rich_text = if markup_enabled {
    let t = render_markup(
      text,
      style~,
      emoji=emoji_enabled,
      emoji_variant?=self.emoji_variant,
    )
    t.justify = justify
    t.overflow = overflow
    t
  } else {
    Text::new(
      text=if emoji_enabled {
        @emoji.replace(
          text,
          default_variant?=self.emoji_variant.map(v => v.to_string()),
        )
      } else {
        text
      },
      justify?,
      overflow?,
      style~,
    )
  }
  if highlight_enabled {
    let h = match highlighter {
      Some(h) => h
      None => self.highlighter
    }
    let highlight_text = h.apply(rich_text.plain())
    highlight_text.copy_styles(rich_text)
    return highlight_text
  }
  rich_text
}

///|
/// Get a Style instance by its theme name or parse a definition.
pub fn Console::get_style(
  self : Console,
  name : &IntoStyle,
  default? : StyleType,
) -> Style raise RichError {
  match name.into_style_type() {
    Style(s) => s
    Def(name) => {
      let result = match self.theme_stack.get(name) {
        Some(s) => s
        None =>
          Style::parse(name) catch {
            error =>
              match default {
                Some(d) => return self.get_style(d)
                None =>
                  raise MissingStyle(
                    "Failed to get style \{py_repr(name)}; \{error}",
                  )
              }
          }
      }
      if result.link() is Some(link) && link != "" {
        result.copy()
      } else {
        result
      }
    }
  }
}

///|
/// Combine a number of renderables and text into a list of renderables.
fn Console::collect_renderables(
  self : Console,
  objects : ArrayView[&Renderable],
  sep : String,
  end : String,
  justify? : JustifyMethod,
  emoji? : Bool,
  markup? : Bool,
  highlight? : Bool,
) -> Array[&Renderable] raise {
  let renderables : Array[&Renderable] = []
  let text : Array[Text] = []
  fn append(renderable : &Renderable) -> Unit {
    match justify {
      Some(Left) => renderables.push(Align::new(renderable, Left))
      Some(Center) => renderables.push(Align::new(renderable, Center))
      Some(Right) => renderables.push(Align::new(renderable, Right))
      _ => renderables.push(renderable)
    }
  }

  let highlighter : &Highlighter = if highlight == Some(true) ||
    (highlight is None && self.highlight_) {
    self.highlighter
  } else {
    NullHighlighter::new()
  }
  fn check_text() {
    if !text.is_empty() {
      let sep_text = Text::new(text=sep, justify?, end~)
      append(sep_text.join(text))
      text.clear()
    }
  }

  for renderable in objects {
    match renderable.text_kind() {
      Str(s) =>
        text.push(self.render_str(s, emoji~, markup~, highlight~, highlighter~))
      Text(t) => text.push(t)
      NotText => {
        check_text()
        append(renderable)
      }
    }
  }
  check_text()
  if self.style is Some(style) {
    let style = self.get_style(style)
    return renderables.map(r => (Styled::new(r, style) : &Renderable))
  }
  renderables
}

///|
/// Draw a line with an optional centered title.
pub fn Console::rule(
  self : Console,
  title? : &IntoText,
  characters? : String = "─",
  style? : &IntoStyle,
  align? : AlignMethod = Center,
) -> Unit raise {
  let rule = Rule::new(
    title=match title {
      Some(t) => t
      None => ""
    },
    characters~,
    style=match style {
      Some(s) => s
      None => "rule.line"
    },
    align~,
  )
  self.print(rule)
}

///|
/// Insert non-printing control codes.
pub fn Console::control(
  self : Console,
  controls : ArrayView[Control],
) -> Unit raise {
  if !self.is_dumb_terminal() {
    self.enter_buffer()
    for c in controls {
      self.buffer.push(c.segment)
    }
    self.exit_buffer()
  }
}

///|
/// Low-level output: no pretty printing, wrapping or markup, but optional
/// highlighting and a basic style.
pub fn Console::out(
  self : Console,
  text : String,
  end? : String = "\n",
  style? : &IntoStyle,
  highlight? : Bool,
) -> Unit raise {
  self.out_many([text], end~, style?, highlight?)
}

///|
/// Low-level output of several strings joined with `sep` (upstream
/// `out(*objects, sep=...)`).
pub fn Console::out_many(
  self : Console,
  objects : ArrayView[String],
  sep? : String = " ",
  end? : String = "\n",
  style? : &IntoStyle,
  highlight? : Bool,
) -> Unit raise {
  let raw_output = objects.iter().join(sep)
  self.print(
    raw_output,
    style?,
    highlight?,
    emoji=false,
    markup=false,
    no_wrap=true,
    overflow=Ignore,
    crop=false,
    end~,
  )
}

///|
/// Print to the console.
pub fn Console::print(
  self : Console,
  object : &Renderable,
  sep? : String = " ",
  end? : String = "\n",
  style? : &IntoStyle,
  justify? : JustifyMethod,
  overflow? : OverflowMethod,
  no_wrap? : Bool,
  emoji? : Bool,
  markup? : Bool,
  highlight? : Bool,
  width? : Int,
  height? : Int,
  crop? : Bool = true,
  soft_wrap? : Bool,
  new_line_start? : Bool = false,
) -> Unit raise {
  self.print_many(
    [object],
    sep~,
    end~,
    style?,
    justify?,
    overflow?,
    no_wrap?,
    emoji?,
    markup?,
    highlight?,
    width?,
    height?,
    crop~,
    soft_wrap?,
    new_line_start~,
  )
}

///|
/// Print several objects to the console. Adjacent strings and Texts are
/// joined with `sep`; other renderables are printed on their own.
pub fn Console::print_many(
  self : Console,
  objects : ArrayView[&Renderable],
  sep? : String = " ",
  end? : String = "\n",
  style? : &IntoStyle,
  justify? : JustifyMethod,
  overflow? : OverflowMethod,
  no_wrap? : Bool,
  emoji? : Bool,
  markup? : Bool,
  highlight? : Bool,
  width? : Int,
  height? : Int,
  crop? : Bool = true,
  soft_wrap? : Bool,
  new_line_start? : Bool = false,
) -> Unit raise {
  let objects : ArrayView[&Renderable] = if objects.length() == 0 {
    if end == "\n" {
      [NewLine::new()]
    } else {
      [""]
    }
  } else {
    objects
  }
  let soft_wrap = soft_wrap.unwrap_or(self.soft_wrap)
  let mut no_wrap = no_wrap
  let mut overflow = overflow
  let mut crop = crop
  if soft_wrap {
    if no_wrap is None {
      no_wrap = Some(true)
    }
    if overflow is None {
      overflow = Some(Ignore)
    }
    crop = false
  }
  let render_hooks = self.render_hooks.copy()
  self.enter_buffer()
  {
    errdefer self.exit_buffer()
    let mut renderables = self.collect_renderables(
      objects,
      sep,
      end,
      justify?,
      emoji?,
      markup?,
      highlight?,
    )
    for hook in render_hooks {
      renderables = hook.process_renderables(renderables)
    }
    let render_options = self
      .options()
      .update(
        justify~,
        overflow~,
        width?=width.map(w => @cmp.minimum(w, self.width())),
        height~,
        no_wrap~,
        markup~,
        highlight~,
      )
    let new_segments : Array[Segment] = []
    match style {
      None =>
        for renderable in renderables {
          self.render_into(renderable, render_options, new_segments, 0)
        }
      Some(style) => {
        let render_style = self.get_style(style)
        let new_line = Segment::line()
        for renderable in renderables {
          for
            item in Segment::split_lines_terminator(
              self.render(renderable, options=render_options),
            ) {
            let (line, add_new_line) = item
            new_segments.append(Segment::apply_style(line, style=render_style))
            if add_new_line {
              new_segments.push(new_line)
            }
          }
        }
      }
    }
    if new_line_start {
      let joined = new_segments.map(s => s.text).join("")
      if py_splitlines(joined).length() > 1 {
        new_segments.insert(0, Segment::line())
      }
    }
    if crop {
      for
        line in Segment::split_and_crop_lines(
          new_segments,
          self.width(),
          pad=false,
        ) {
        self.buffer.append(line)
      }
    } else {
      self.buffer.append(new_segments)
    }
  }
  self.exit_buffer()
}

///|
/// Pretty print JSON. `json` is a JSON string; otherwise `data` is encoded.
pub fn Console::print_json(
  self : Console,
  json? : String,
  data? : Json,
  indent? : Int? = Some(2),
  indent_str? : String,
  highlight? : Bool = true,
  ensure_ascii? : Bool = false,
  sort_keys? : Bool = false,
) -> Unit raise {
  let renderable = match json {
    Some(j) =>
      JSON::new(j, indent~, indent_str?, highlight~, ensure_ascii~, sort_keys~)
    None =>
      JSON::from_data(
        data.unwrap_or(Json::null()),
        indent~,
        indent_str?,
        highlight~,
        ensure_ascii~,
        sort_keys~,
      )
  }
  self.print(renderable, soft_wrap=true)
}

///|
/// Update the screen at a given offset (alt screen only).
pub fn Console::update_screen(
  self : Console,
  renderable : &Renderable,
  region? : Region,
  options? : ConsoleOptions,
) -> Unit raise {
  if !self.is_alt_screen() {
    raise NoAltScreen("Alt screen must be enabled to call update_screen")
  }
  let render_options = options.unwrap_or_else(() => self.options())
  let (x, y, render_options) = match region {
    None =>
      (
        0,
        0,
        render_options.update_dimensions(
          render_options.max_width,
          match render_options.height {
            Some(h) if h != 0 => h
            _ => self.height()
          },
        ),
      )
    Some(r) => (r.x, r.y, render_options.update_dimensions(r.width, r.height))
  }
  let lines = self.render_lines(renderable, options=render_options)
  self.update_screen_lines(lines, x~, y~)
}

///|
/// Update lines of the screen at a given offset (alt screen only).
pub fn Console::update_screen_lines(
  self : Console,
  lines : Array[Array[Segment]],
  x? : Int = 0,
  y? : Int = 0,
) -> Unit raise {
  if !self.is_alt_screen() {
    raise NoAltScreen("Alt screen must be enabled to call update_screen")
  }
  let screen_update = ScreenUpdate::new(lines, x, y)
  let segments = self.render(screen_update)
  self.buffer.append(segments)
  self.check_buffer()
}

///|
/// Log rich content to the terminal, with the time and the caller location.
#callsite(autofill(loc))
pub fn Console::log(
  self : Console,
  object : &Renderable,
  sep? : String = " ",
  end? : String = "\n",
  style? : &IntoStyle,
  justify? : JustifyMethod,
  emoji? : Bool,
  markup? : Bool,
  highlight? : Bool,
  loc~ : SourceLoc,
) -> Unit raise {
  self.log_many(
    [object],
    sep~,
    end~,
    style?,
    justify?,
    emoji?,
    markup?,
    highlight?,
    loc~,
  )
}

///|
/// Split a `SourceLoc` (`path:line:col-line:col`) into `(path, line)`.
fn parse_source_loc(loc : SourceLoc) -> (String, Int) {
  let s = loc.to_string()
  let parts : Array[String] = s.split(":").map(p => p.to_owned()).collect()
  if parts.length() >= 4 {
    let path = parts[0:parts.length() - 3].to_owned().join(":")
    (path, parse_int_or(parts[parts.length() - 3], 0))
  } else {
    (s, 0)
  }
}

///|
/// Log several objects (see `log`).
#callsite(autofill(loc))
pub fn Console::log_many(
  self : Console,
  objects : ArrayView[&Renderable],
  sep? : String = " ",
  end? : String = "\n",
  style? : &IntoStyle,
  justify? : JustifyMethod,
  emoji? : Bool,
  markup? : Bool,
  highlight? : Bool,
  loc~ : SourceLoc,
) -> Unit raise {
  let objects : ArrayView[&Renderable] = if objects.length() == 0 {
    [NewLine::new()]
  } else {
    objects
  }
  let render_hooks = self.render_hooks.copy()
  self.enter_buffer()
  {
    errdefer self.exit_buffer()
    let mut renderables = self.collect_renderables(
      objects,
      sep,
      end,
      justify?,
      emoji?,
      markup?,
      highlight?,
    )
    if style is Some(style) {
      let style = style.into_style_type()
      renderables = renderables.map(r => (Styled::new(r, style) : &Renderable))
    }
    let (filename, line_no) = parse_source_loc(loc)
    let link_path = if filename.has_prefix("<") { None } else { Some(filename) }
    let path = match filename.rev_find("/") {
      Some(i) => py_slice(filename, i + 1, filename.length())
      None => filename
    }
    renderables = [
      self.log_render.render(
        self,
        renderables,
        log_time=(self.get_datetime)(),
        path~,
        line_no~,
        link_path?,
      ),
    ]
    for hook in render_hooks {
      renderables = hook.process_renderables(renderables)
    }
    let new_segments = []
    let render_options = self.options()
    for renderable in renderables {
      new_segments.append(self.render(renderable, options=render_options))
    }
    for
      line in Segment::split_and_crop_lines(
        new_segments,
        self.width(),
        pad=false,
      ) {
      self.buffer.append(line)
    }
  }
  self.exit_buffer()
}

///|
/// Check if the buffer may be rendered, and render it if it can.
fn Console::check_buffer(self : Console) -> Unit raise {
  if self.quiet {
    self.buffer.clear()
    return
  }
  self.write_buffer()
}

///|
/// Write the buffer to the output file.
fn Console::write_buffer(self : Console) -> Unit raise {
  if self.record && self.buffer_index == 0 {
    self.record_buffer.append(self.buffer)
  }
  if self.buffer_index == 0 {
    let text = self.render_buffer(self.buffer)
    self.buffer.clear()
    let file = self.file()
    if text != "" {
      file.write(text)
    }
    file.flush()
  }
}

///|
/// Render buffered output to a string.
fn Console::render_buffer(self : Console, buffer : Array[Segment]) -> String {
  let output = StringBuilder()
  let color_system = self.color_system_
  let legacy_windows = self.legacy_windows
  let not_terminal = !self.is_terminal()
  let buffer = if self.no_color && color_system is Some(_) {
    Segment::remove_color(buffer)
  } else {
    buffer
  }
  for segment in buffer {
    match segment.style {
      Some(style) if style.to_bool() =>
        style.render_to(output, segment.text, color_system, legacy_windows)
      _ =>
        if !(not_terminal && segment.has_codes()) {
          output.write_string(segment.text)
        }
    }
  }
  output.to_string()
}

///|
/// Display a prompt and wait for input from the user.
///
/// `stream` replaces stdin: it is called once and returns the next line like
/// Python's `stream.readline()` (with its newline, `""` at end of input);
/// as upstream, the result is then returned as is.
pub fn Console::input(
  self : Console,
  prompt? : &IntoText,
  markup? : Bool = true,
  emoji? : Bool = true,
  password? : Bool = false,
  stream? : () -> String raise,
) -> String raise {
  if prompt is Some(prompt) && prompt.into_text_type().to_bool() {
    match prompt.into_text_type() {
      Str(s) => self.print(s, markup~, emoji~, end="")
      Text(t) => self.print(t, markup~, emoji~, end="")
    }
  }
  if stream is Some(readline) {
    return readline()
  }
  match @term.read_line(echo=!password) {
    Some(line) => {
      if password {
        // the newline was not echoed
        self.file().write("\n")
      }
      match line.strip_suffix("\n") {
        Some(l) => l.to_owned()
        None => line
      }
    }
    None => raise ValueError("EOF when reading a line")
  }
}

///|
/// Generate text from console contents (requires `record=true`).
pub fn Console::export_text(
  self : Console,
  clear? : Bool = true,
  styles? : Bool = false,
) -> String {
  guard self.record else {
    abort(
      "To export console contents set record=True in the constructor or instance",
    )
  }
  let buf = StringBuilder()
  if styles {
    for segment in self.record_buffer {
      match segment.style {
        Some(style) if style.to_bool() =>
          buf.write_string(style.render(text=segment.text))
        _ => buf.write_string(segment.text)
      }
    }
  } else {
    for segment in self.record_buffer {
      if !segment.has_codes() {
        buf.write_string(segment.text)
      }
    }
  }
  if clear {
    self.record_buffer.clear()
  }
  buf.to_string()
}

///|
/// Generate text from console contents and save it to a file.
pub fn Console::save_text(
  self : Console,
  path : String,
  clear? : Bool = true,
  styles? : Bool = false,
) -> Unit raise {
  let text = self.export_text(clear~, styles~)
  if !@term.write_file(path, text) {
    raise WriteError("unable to write \{path}")
  }
}

///|
/// The default HTML template.
pub let console_html_format : String =
  #|<!DOCTYPE html>
  #|<html>
  #|<head>
  #|<meta charset="UTF-8">
  #|<style>
  #|{stylesheet}
  #|body {{
  #|    color: {foreground};
  #|    background-color: {background};
  #|}}
  #|</style>
  #|</head>
  #|<body>
  #|    <pre style="font-family:Menlo,'DejaVu Sans Mono',consolas,'Courier New',monospace"><code style="font-family:inherit">{code}</code></pre>
  #|</body>
  #|</html>
  #|

///|
/// Python `html.escape(text)`.
pub fn html_escape(text : String) -> String {
  @pystr.html_escape(text)
}

///|
/// Generate HTML from console contents (requires `record=true`).
pub fn Console::export_html(
  self : Console,
  theme? : @color.TerminalTheme,
  clear? : Bool = true,
  code_format? : String,
  inline_styles? : Bool = false,
) -> String {
  guard self.record else {
    abort(
      "To export console contents set record=True in the constructor or instance",
    )
  }
  let fragments = StringBuilder()
  let theme = theme.unwrap_or(@color.default_terminal_theme)
  let mut stylesheet = ""
  let render_code_format = code_format.unwrap_or(console_html_format)
  let segments = Segment::filter_control(Segment::simplify(self.record_buffer))
  if inline_styles {
    for segment in segments {
      let mut text = html_escape(segment.text)
      match segment.style {
        Some(style) if style.to_bool() => {
          let rule = style.get_html_style(theme~)
          if style.link() is Some(link) && link != "" {
            text = "<a href=\"\{link}\">\{text}</a>"
          }
          if rule != "" {
            text = "<span style=\"\{rule}\">\{text}</span>"
          }
        }
        _ => ()
      }
      fragments.write_string(text)
    }
  } else {
    let styles : Map[String, Int] = Map([])
    for segment in segments {
      let mut text = html_escape(segment.text)
      match segment.style {
        Some(style) if style.to_bool() => {
          let rule = style.get_html_style(theme~)
          let style_number = match styles.get(rule) {
            Some(n) => n
            None => {
              let n = styles.length() + 1
              styles[rule] = n
              n
            }
          }
          if style.link() is Some(link) && link != "" {
            text = "<a class=\"r\{style_number}\" href=\"\{link}\">\{text}</a>"
          } else {
            text = "<span class=\"r\{style_number}\">\{text}</span>"
          }
        }
        _ => ()
      }
      fragments.write_string(text)
    }
    let rules = []
    for rule, number in styles {
      if rule != "" {
        rules.push(".r\{number} {\{rule}}")
      }
    }
    stylesheet = rules.join("\n")
  }
  let rendered_code = py_format(render_code_format, {
    "code": fragments.to_string(),
    "stylesheet": stylesheet,
    "foreground": theme.foreground_color.hex(),
    "background": theme.background_color.hex(),
  })
  if clear {
    self.record_buffer.clear()
  }
  rendered_code
}

///|
/// Generate HTML from console contents and write it to a file.
pub fn Console::save_html(
  self : Console,
  path : String,
  theme? : @color.TerminalTheme,
  clear? : Bool = true,
  code_format? : String,
  inline_styles? : Bool = false,
) -> Unit raise {
  let html = self.export_html(theme?, clear~, code_format?, inline_styles~)
  if !@term.write_file(path, html) {
    raise WriteError("unable to write \{path}")
  }
}

///|
/// Run `f`, then send everything it printed to a pager.
pub fn Console::pager(
  self : Console,
  f : () -> Unit raise,
  pager? : &Pager,
  styles? : Bool = false,
  links? : Bool = false,
) -> Unit raise {
  let pager : &Pager = match pager {
    Some(p) => p
    None => SystemPager::new()
  }
  self.enter_buffer()
  {
    errdefer {
      self.buffer.clear()
      self.buffer_index -= 1
    }
    f()
  }
  let mut buffer = self.buffer.copy()
  if !styles {
    buffer = Segment::strip_styles(buffer)
  } else if !links {
    buffer = Segment::strip_links(buffer)
  }
  let content = self.render_buffer(buffer)
  self.buffer.clear()
  self.buffer_index -= 1
  pager.show(content)
}
