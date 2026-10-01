// Port of the `ProgressColumn` classes of rich/progress.py.

///|
/// State shared by all progress columns (upstream `ProgressColumn`
/// attributes): the table column, the refresh limit and the render cache.
pub(all) struct ColumnState {
  priv table_column : @rich.Column?
  /// Minimum time (seconds) between re-renders of a task that has not
  /// completed any steps, or `None` to always re-render.
  mut max_refresh : Double?
  priv renderable_cache : Map[Int, (Double, &@rich.Renderable)]
}

///|
pub fn ColumnState::new(
  table_column? : @rich.Column,
  max_refresh? : Double,
) -> ColumnState {
  { table_column, max_refresh, renderable_cache: {}, }
}

///|
/// A widget to use in a progress display (upstream abstract class
/// `ProgressColumn`).
///
/// Implement `render` and `column_state` (return a `ColumnState` stored in
/// the column). Strings are columns too: they are formatted with
/// `format_task` (upstream `Progress("text {task.description}", ...)`).
pub(open) trait ProgressColumn {
  /// Return a renderable for the given task.
  fn render(Self, Task) -> &@rich.Renderable raise
  /// The column state (table column, refresh limit, cache).
  fn column_state(Self) -> ColumnState
  /// Get a table column, used to build the tasks table.
  fn get_table_column(Self) -> @rich.Column = _
  /// Get a renderable for the given task, re-using the last one if it was
  /// rendered less than `max_refresh` seconds ago (upstream `__call__`).
  fn call(Self, Task) -> &@rich.Renderable raise = _
}

///|
impl ProgressColumn with fn get_table_column(self) {
  match self.column_state().table_column {
    Some(c) => c
    None => @rich.Column::new()
  }
}

///|
impl ProgressColumn with fn call(self, task) {
  let state = self.column_state()
  let current_time = task.get_time()
  if state.max_refresh is Some(max_refresh) && task.completed == 0.0 {
    if state.renderable_cache.get(task.id) is Some((timestamp, renderable)) &&
      timestamp + max_refresh > current_time {
      return renderable
    }
  }
  let renderable = self.render(task)
  state.renderable_cache[task.id] = (current_time, renderable)
  renderable
}

///|
/// A format string column (upstream passes `str` columns to `Progress`).
pub impl ProgressColumn for String with fn render(self, task) {
  format_task(self, task)
}

///|
pub impl ProgressColumn for String with fn column_state(_self) {
  ColumnState::new()
}

///|
pub impl ProgressColumn for String with fn get_table_column(_self) {
  @rich.Column::new(no_wrap=true)
}

///|
pub impl ProgressColumn for String with fn call(self, task) {
  format_task(self, task)
}

///|
/// A column to insert an arbitrary renderable.
pub(all) struct RenderableColumn {
  /// The renderable to display.
  mut renderable : &@rich.Renderable
  /// Column state.
  state : ColumnState
}

///|
pub fn RenderableColumn::new(
  renderable? : &@rich.Renderable = "",
  table_column? : @rich.Column,
) -> RenderableColumn {
  { renderable, state: ColumnState::new(table_column?), }
}

///|
pub impl ProgressColumn for RenderableColumn with fn render(self, _task) {
  self.renderable
}

///|
pub impl ProgressColumn for RenderableColumn with fn column_state(self) {
  self.state
}

///|
/// A column with a 'spinner' animation.
pub(all) struct SpinnerColumn {
  /// The spinner.
  mut spinner : @spinner.Spinner
  /// Text used when the task is finished.
  mut finished_text : @rich.Text
  /// Column state.
  state : ColumnState
}

///|
/// Create a spinner column. `finished_text` (a string is parsed as markup)
/// is shown when the task is finished.
pub fn SpinnerColumn::new(
  spinner_name? : String = "dots",
  style? : &@rich.IntoStyle = "progress.spinner",
  speed? : Double = 1.0,
  finished_text? : &@rich.IntoText = " ",
  table_column? : @rich.Column,
) -> SpinnerColumn raise @rich.RichError {
  let spinner = @spinner.Spinner::new(spinner_name, style~, speed~)
  let finished_text = match finished_text.into_text_type() {
    Str(s) => @rich.Text::from_markup(s)
    Text(t) => t
  }
  { spinner, finished_text, state: ColumnState::new(table_column?), }
}

///|
/// Set a new spinner.
pub fn SpinnerColumn::set_spinner(
  self : SpinnerColumn,
  spinner_name : String,
  spinner_style? : &@rich.IntoStyle = "progress.spinner",
  speed? : Double = 1.0,
) -> Unit raise @rich.RichError {
  self.spinner = @spinner.Spinner::new(
    spinner_name,
    style=spinner_style,
    speed~,
  )
}

///|
pub impl ProgressColumn for SpinnerColumn with fn render(self, task) {
  if task.finished() {
    self.finished_text as &@rich.Renderable
  } else {
    self.spinner.render(task.get_time())
  }
}

///|
pub impl ProgressColumn for SpinnerColumn with fn column_state(self) {
  self.state
}

///|
/// A column containing text (a format string, see `format_task`).
pub(all) struct TextColumn {
  /// Format string, e.g. `"[progress.description]{task.description}"`.
  mut text_format : String
  /// Text justification.
  mut justify : @rich.JustifyMethod
  /// Style of the text.
  mut style : @rich.StyleType
  /// Parse the formatted text as markup.
  mut markup : Bool
  /// Highlighter applied to the text.
  mut highlighter : &@rich.Highlighter?
  /// Column state.
  state : ColumnState
}

///|
pub fn TextColumn::new(
  text_format : String,
  style? : &@rich.IntoStyle = "none",
  justify? : @rich.JustifyMethod = Left,
  markup? : Bool = true,
  highlighter? : &@rich.Highlighter,
  table_column? : @rich.Column,
) -> TextColumn {
  {
    text_format,
    justify,
    style: style.into_style_type(),
    markup,
    highlighter,
    state: ColumnState::new(
      table_column=table_column.unwrap_or(@rich.Column::new(no_wrap=true)),
    ),
  }
}

///|
fn make_text(
  text : String,
  markup : Bool,
  style : @rich.StyleType,
  justify : @rich.JustifyMethod,
  highlighter : &@rich.Highlighter?,
) -> @rich.Text raise {
  let text = if markup {
    @rich.Text::from_markup(text, style~, justify~)
  } else {
    @rich.Text::new(text~, style~, justify~)
  }
  if highlighter is Some(h) {
    h.highlight(text)
  }
  text
}

///|
/// Render the text for a task.
pub fn TextColumn::render(self : TextColumn, task : Task) -> @rich.Text raise {
  make_text(
    format_task(self.text_format, task),
    self.markup,
    self.style,
    self.justify,
    self.highlighter,
  )
}

///|
pub impl ProgressColumn for TextColumn with fn render(self, task) {
  TextColumn::render(self, task)
}

///|
pub impl ProgressColumn for TextColumn with fn column_state(self) {
  self.state
}

///|
/// Renders a visual progress bar.
pub(all) struct BarColumn {
  /// Width of the bar, or `None` for full width.
  mut bar_width : Int?
  /// Style for the bar background.
  mut style : @rich.StyleType
  /// Style for the completed bar.
  mut complete_style : @rich.StyleType
  /// Style for a finished bar.
  mut finished_style : @rich.StyleType
  /// Style for pulsing bars.
  mut pulse_style : @rich.StyleType
  /// Column state.
  state : ColumnState
}

///|
/// Create a bar column. `bar_width=None` renders a full width bar.
pub fn BarColumn::new(
  bar_width? : Int? = Some(40),
  style? : &@rich.IntoStyle = "bar.back",
  complete_style? : &@rich.IntoStyle = "bar.complete",
  finished_style? : &@rich.IntoStyle = "bar.finished",
  pulse_style? : &@rich.IntoStyle = "bar.pulse",
  table_column? : @rich.Column,
) -> BarColumn {
  {
    bar_width,
    style: style.into_style_type(),
    complete_style: complete_style.into_style_type(),
    finished_style: finished_style.into_style_type(),
    pulse_style: pulse_style.into_style_type(),
    state: ColumnState::new(table_column?),
  }
}

///|
/// Get a progress bar widget for a task.
pub fn BarColumn::render(
  self : BarColumn,
  task : Task,
) -> @progress_bar.ProgressBar {
  @progress_bar.ProgressBar::new(
    total=task.total.map(t => @cmp.maximum(0.0, t)),
    completed=@cmp.maximum(0.0, task.completed),
    width?=self.bar_width.map(w => @cmp.maximum(1, w)),
    pulse=!task.started(),
    animation_time=task.get_time(),
    style=self.style,
    complete_style=self.complete_style,
    finished_style=self.finished_style,
    pulse_style=self.pulse_style,
  )
}

///|
pub impl ProgressColumn for BarColumn with fn render(self, task) {
  BarColumn::render(self, task)
}

///|
pub impl ProgressColumn for BarColumn with fn column_state(self) {
  self.state
}

///|
/// Python `str(timedelta(seconds=n))` for `n >= 0`.
fn format_timedelta(seconds : Int64) -> String {
  let days = seconds / 86400L
  let rem = seconds % 86400L
  let hours = rem / 3600L
  let minutes = rem % 3600L / 60L
  let secs = rem % 60L
  let hms = "\{hours}:\{pad2(minutes)}:\{pad2(secs)}"
  if days == 0L {
    hms
  } else {
    "\{days} day\{if days == 1L { "" } else { "s" }}, \{hms}"
  }
}

///|
fn pad2(n : Int64) -> String {
  if n < 10L {
    "0\{n}"
  } else {
    n.to_string()
  }
}

///|
/// Renders time elapsed.
pub(all) struct TimeElapsedColumn {
  /// Column state.
  state : ColumnState
}

///|
pub fn TimeElapsedColumn::new(
  table_column? : @rich.Column,
) -> TimeElapsedColumn {
  { state: ColumnState::new(table_column?), }
}

///|
/// Show time elapsed.
pub fn TimeElapsedColumn::render(
  _self : TimeElapsedColumn,
  task : Task,
) -> @rich.Text {
  let elapsed = if task.finished() {
    task.finished_time
  } else {
    task.elapsed()
  }
  match elapsed {
    None => @rich.Text::new(text="-:--:--", style="progress.elapsed")
    Some(elapsed) => {
      let delta = format_timedelta(@cmp.maximum(0L, elapsed.to_int64()))
      @rich.Text::new(text=delta, style="progress.elapsed")
    }
  }
}

///|
pub impl ProgressColumn for TimeElapsedColumn with fn render(self, task) {
  TimeElapsedColumn::render(self, task)
}

///|
pub impl ProgressColumn for TimeElapsedColumn with fn column_state(self) {
  self.state
}

///|
/// Show task progress as a percentage (or the speed when the total is
/// unknown and `show_speed` is set).
pub(all) struct TaskProgressColumn {
  /// Format for percentage display.
  mut text_format : String
  /// Format if percentage is unknown.
  mut text_format_no_percentage : String
  /// Text justification.
  mut justify : @rich.JustifyMethod
  /// Style of output.
  mut style : @rich.StyleType
  /// Enable markup.
  mut markup : Bool
  /// Highlighter to apply to output.
  mut highlighter : &@rich.Highlighter?
  /// Show speed if total is unknown.
  mut show_speed : Bool
  /// Column state.
  state : ColumnState
}

///|
pub fn TaskProgressColumn::new(
  text_format? : String = "[progress.percentage]{task.percentage:>3.0f}%",
  text_format_no_percentage? : String = "",
  style? : &@rich.IntoStyle = "none",
  justify? : @rich.JustifyMethod = Left,
  markup? : Bool = true,
  highlighter? : &@rich.Highlighter,
  table_column? : @rich.Column,
  show_speed? : Bool = false,
) -> TaskProgressColumn {
  {
    text_format,
    text_format_no_percentage,
    justify,
    style: style.into_style_type(),
    markup,
    highlighter,
    show_speed,
    state: ColumnState::new(
      table_column=table_column.unwrap_or(@rich.Column::new(no_wrap=true)),
    ),
  }
}

///|
/// Render the speed in iterations per second.
pub fn TaskProgressColumn::render_speed(speed : Double?) -> @rich.Text {
  match speed {
    None => @rich.Text::new(text="", style="progress.percentage")
    Some(speed) => {
      let (unit, suffix) = @rich.pick_unit_and_suffix(
        speed.to_int64(),
        ["", "×10³", "×10⁶", "×10⁹", "×10¹²"],
        1000L,
      )
      let data_speed = speed / unit.to_double()
      @rich.Text::new(
        text="\{@rich.py_format_fixed(data_speed, 1)}\{suffix} it/s",
        style="progress.percentage",
      )
    }
  }
}

///|
/// Render the percentage (or speed) for a task.
pub fn TaskProgressColumn::render(
  self : TaskProgressColumn,
  task : Task,
) -> @rich.Text raise {
  if task.total is None && self.show_speed {
    return TaskProgressColumn::render_speed(
      match task.finished_speed {
        Some(s) if s != 0.0 => Some(s)
        _ => task.speed()
      },
    )
  }
  let text_format = if task.total is None {
    self.text_format_no_percentage
  } else {
    self.text_format
  }
  make_text(
    format_task(text_format, task),
    self.markup,
    self.style,
    self.justify,
    self.highlighter,
  )
}

///|
pub impl ProgressColumn for TaskProgressColumn with fn render(self, task) {
  TaskProgressColumn::render(self, task)
}

///|
pub impl ProgressColumn for TaskProgressColumn with fn column_state(self) {
  self.state
}

///|
/// Renders estimated time remaining.
pub(all) struct TimeRemainingColumn {
  /// Render MM:SS when time remaining is less than an hour.
  mut compact : Bool
  /// Render time elapsed when the task is finished.
  mut elapsed_when_finished : Bool
  /// Column state (refreshes at most twice a second to prevent jitter).
  state : ColumnState
}

///|
pub fn TimeRemainingColumn::new(
  compact? : Bool = false,
  elapsed_when_finished? : Bool = false,
  table_column? : @rich.Column,
) -> TimeRemainingColumn {
  {
    compact,
    elapsed_when_finished,
    state: ColumnState::new(table_column?, max_refresh=0.5),
  }
}

///|
/// Show time remaining.
pub fn TimeRemainingColumn::render(
  self : TimeRemainingColumn,
  task : Task,
) -> @rich.Text {
  let (task_time, style) = if self.elapsed_when_finished && task.finished() {
    (task.finished_time, "progress.elapsed")
  } else {
    (task.time_remaining(), "progress.remaining")
  }
  if task.total is None {
    return @rich.Text::new(text="", style~)
  }
  match task_time {
    None =>
      @rich.Text::new(
        text=if self.compact { "--:--" } else { "-:--:--" },
        style~,
      )
    Some(task_time) => {
      let t = task_time.to_int64()
      let minutes = floor_div(t, 60L)
      let seconds = t - minutes * 60L
      let hours = floor_div(minutes, 60L)
      let minutes = minutes - hours * 60L
      let formatted = if self.compact && hours == 0L {
        "\{pad2(minutes)}:\{pad2(seconds)}"
      } else {
        "\{hours}:\{pad2(minutes)}:\{pad2(seconds)}"
      }
      @rich.Text::new(text=formatted, style~)
    }
  }
}

///|
fn floor_div(a : Int64, b : Int64) -> Int64 {
  let q = a / b
  if a % b != 0L && (a < 0L) != (b < 0L) {
    q - 1L
  } else {
    q
  }
}

///|
pub impl ProgressColumn for TimeRemainingColumn with fn render(self, task) {
  TimeRemainingColumn::render(self, task)
}

///|
pub impl ProgressColumn for TimeRemainingColumn with fn column_state(self) {
  self.state
}

///|
/// Renders completed filesize.
pub(all) struct FileSizeColumn {
  /// Column state.
  state : ColumnState
}

///|
pub fn FileSizeColumn::new(table_column? : @rich.Column) -> FileSizeColumn {
  { state: ColumnState::new(table_column?), }
}

///|
/// Show data completed.
pub fn FileSizeColumn::render(
  _self : FileSizeColumn,
  task : Task,
) -> @rich.Text {
  let data_size = @rich.filesize_decimal(task.completed.to_int64())
  @rich.Text::new(text=data_size, style="progress.filesize")
}

///|
pub impl ProgressColumn for FileSizeColumn with fn render(self, task) {
  FileSizeColumn::render(self, task)
}

///|
pub impl ProgressColumn for FileSizeColumn with fn column_state(self) {
  self.state
}

///|
/// Renders total filesize.
pub(all) struct TotalFileSizeColumn {
  /// Column state.
  state : ColumnState
}

///|
pub fn TotalFileSizeColumn::new(
  table_column? : @rich.Column,
) -> TotalFileSizeColumn {
  { state: ColumnState::new(table_column?), }
}

///|
/// Show total data size.
pub fn TotalFileSizeColumn::render(
  _self : TotalFileSizeColumn,
  task : Task,
) -> @rich.Text {
  let data_size = match task.total {
    Some(total) => @rich.filesize_decimal(total.to_int64())
    None => ""
  }
  @rich.Text::new(text=data_size, style="progress.filesize.total")
}

///|
pub impl ProgressColumn for TotalFileSizeColumn with fn render(self, task) {
  TotalFileSizeColumn::render(self, task)
}

///|
pub impl ProgressColumn for TotalFileSizeColumn with fn column_state(self) {
  self.state
}

///|
/// Renders completed count/total, e.g. `  10/1000`.
///
/// Best for bounded tasks with int quantities. The completed count is
/// padded so the width does not change as the task progresses.
pub(all) struct MofNCompleteColumn {
  /// Text to separate completed and total values.
  mut separator : String
  /// Column state.
  state : ColumnState
}

///|
pub fn MofNCompleteColumn::new(
  separator? : String = "/",
  table_column? : @rich.Column,
) -> MofNCompleteColumn {
  { separator, state: ColumnState::new(table_column?), }
}

///|
/// Show completed/total.
pub fn MofNCompleteColumn::render(
  self : MofNCompleteColumn,
  task : Task,
) -> @rich.Text {
  let completed = task.completed.to_int64().to_string()
  let total = match task.total {
    Some(t) => t.to_int64().to_string()
    None => "?"
  }
  let total_width = total.length()
  let padded = if completed.length() < total_width {
    " ".repeat(total_width - completed.length()) + completed
  } else {
    completed
  }
  @rich.Text::new(
    text="\{padded}\{self.separator}\{total}",
    style="progress.download",
  )
}

///|
pub impl ProgressColumn for MofNCompleteColumn with fn render(self, task) {
  MofNCompleteColumn::render(self, task)
}

///|
pub impl ProgressColumn for MofNCompleteColumn with fn column_state(self) {
  self.state
}

///|
/// Renders file size downloaded and total, e.g. `0.5/2.3 GB`.
pub(all) struct DownloadColumn {
  /// Use binary units, KiB, MiB etc.
  mut binary_units : Bool
  /// Column state.
  state : ColumnState
}

///|
pub fn DownloadColumn::new(
  binary_units? : Bool = false,
  table_column? : @rich.Column,
) -> DownloadColumn {
  { binary_units, state: ColumnState::new(table_column?), }
}

///|
/// Calculate common unit for completed and total.
pub fn DownloadColumn::render(self : DownloadColumn, task : Task) -> @rich.Text {
  let completed = task.completed.to_int64()
  let unit_and_suffix_calculation_base = match task.total {
    Some(t) => t.to_int64()
    None => completed
  }
  let (unit, suffix) = if self.binary_units {
    @rich.pick_unit_and_suffix(
      unit_and_suffix_calculation_base,
      ["bytes", "KiB", "MiB", "GiB", "TiB", "PiB", "EiB", "ZiB", "YiB"],
      1024L,
    )
  } else {
    @rich.pick_unit_and_suffix(
      unit_and_suffix_calculation_base,
      ["bytes", "kB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"],
      1000L,
    )
  }
  let precision = if unit == 1L { 0 } else { 1 }
  let completed_ratio = completed.to_double() / unit.to_double()
  let completed_str = @rich.py_group_thousands(
    @rich.py_format_fixed(completed_ratio, precision),
  )
  let total_str = match task.total {
    Some(t) => {
      let total_ratio = t.to_int64().to_double() / unit.to_double()
      @rich.py_group_thousands(@rich.py_format_fixed(total_ratio, precision))
    }
    None => "?"
  }
  @rich.Text::new(
    text="\{completed_str}/\{total_str} \{suffix}",
    style="progress.download",
  )
}

///|
pub impl ProgressColumn for DownloadColumn with fn render(self, task) {
  DownloadColumn::render(self, task)
}

///|
pub impl ProgressColumn for DownloadColumn with fn column_state(self) {
  self.state
}

///|
/// Renders human readable transfer speed.
pub(all) struct TransferSpeedColumn {
  /// Column state.
  state : ColumnState
}

///|
pub fn TransferSpeedColumn::new(
  table_column? : @rich.Column,
) -> TransferSpeedColumn {
  { state: ColumnState::new(table_column?), }
}

///|
/// Show data transfer speed.
pub fn TransferSpeedColumn::render(
  _self : TransferSpeedColumn,
  task : Task,
) -> @rich.Text {
  let speed = match task.finished_speed {
    Some(s) if s != 0.0 => Some(s)
    _ => task.speed()
  }
  match speed {
    None => @rich.Text::new(text="?", style="progress.data.speed")
    Some(speed) => {
      let data_speed = @rich.filesize_decimal(speed.to_int64())
      @rich.Text::new(text="\{data_speed}/s", style="progress.data.speed")
    }
  }
}

///|
pub impl ProgressColumn for TransferSpeedColumn with fn render(self, task) {
  TransferSpeedColumn::render(self, task)
}

///|
pub impl ProgressColumn for TransferSpeedColumn with fn column_state(self) {
  self.state
}
