// Port of the `Progress` class of rich/progress.py.
//
// There is no refresh thread (DESIGN.md §7): with `auto_refresh=true`,
// `update` and `advance` refresh the display when the live display's
// refresh interval (`1 / refresh_per_second`) has elapsed; `add_task`,
// `reset`, `update(refresh=true)`, `refresh()`, `start()` and `stop()`
// refresh as upstream.

///|
/// Renders auto-updating progress bar(s).
pub(all) struct Progress {
  /// The columns of the display.
  columns : Array[&ProgressColumn]
  /// Period (in seconds) used to calculate the speed estimate.
  mut speed_estimate_period : Double
  /// Disable the progress display.
  mut disable : Bool
  /// Expand the tasks table to fit the width.
  mut expand : Bool
  priv tasks_ : Map[Int, Task]
  priv mut task_index : Int
  /// The live display used to render the progress.
  live : @live.Live
  /// Get the current time (used for elapsed time and speed estimates).
  get_time : () -> Double
}

///|
/// The default columns used for a new `Progress`: a description
/// `TextColumn`, a `BarColumn`, a `TaskProgressColumn` and a
/// `TimeRemainingColumn`.
pub fn Progress::get_default_columns() -> Array[&ProgressColumn] {
  [
    TextColumn::new("[progress.description]{task.description}"),
    BarColumn::new(),
    TaskProgressColumn::new(),
    TimeRemainingColumn::new(),
  ]
}

///|
/// Create a progress display.
///
/// * `columns`: the columns (strings are format strings, see
///   `format_task`); empty means `get_default_columns()`.
/// * `console`: defaults to the global console.
/// * `auto_refresh`: refresh when tasks are updated, at most
///   `refresh_per_second` times per second. When disabled call `refresh()`.
/// * `speed_estimate_period`: period (seconds) used for speed estimates.
/// * `transient`: clear the progress on exit.
/// * `redirect_stdout` / `redirect_stderr`: accepted for compatibility (no
///   effect).
/// * `get_time`: the clock, defaults to `console.get_time`.
/// * `disable`: disable the progress display.
/// * `expand`: expand the tasks table to fit the width.
pub fn Progress::new(
  columns? : Array[&ProgressColumn] = [],
  console? : @rich.Console,
  auto_refresh? : Bool = true,
  refresh_per_second? : Double = 10.0,
  speed_estimate_period? : Double = 30.0,
  transient? : Bool = false,
  redirect_stdout? : Bool = true,
  redirect_stderr? : Bool = true,
  get_time? : () -> Double,
  disable? : Bool = false,
  expand? : Bool = false,
) -> Progress {
  guard refresh_per_second > 0.0 else {
    abort("refresh_per_second must be > 0")
  }
  let console = match console {
    Some(c) => c
    None => @rich.get_console()
  }
  let cell : Ref[Progress?] = Ref(None)
  let live = @live.Live::new(
    console~,
    auto_refresh~,
    refresh_per_second~,
    transient~,
    redirect_stdout~,
    redirect_stderr~,
    get_renderable=() => {
      match cell.val {
        Some(progress) => progress.get_renderable()
        None => @rich.Group::new([])
      }
    },
  )
  let progress : Progress = {
    columns: if columns.is_empty() {
      Progress::get_default_columns()
    } else {
      columns
    },
    speed_estimate_period,
    disable,
    expand,
    tasks_: {},
    task_index: 0,
    live,
    get_time: match get_time {
      Some(f) => f
      None => console.get_time
    },
  }
  cell.val = Some(progress)
  progress
}

///|
/// The console used by the progress display.
pub fn Progress::console(self : Progress) -> @rich.Console {
  self.live.console
}

///|
/// The tasks (in the order they were added).
pub fn Progress::tasks(self : Progress) -> Array[Task] {
  self.tasks_.values().collect()
}

///|
/// The task IDs.
pub fn Progress::task_ids(self : Progress) -> Array[Int] {
  self.tasks_.keys().collect()
}

///|
/// Get a task by ID.
pub fn Progress::get_task(
  self : Progress,
  task_id : Int,
) -> Task raise @rich.RichError {
  match self.tasks_.get(task_id) {
    Some(task) => task
    None => raise ValueError("KeyError: \{task_id}")
  }
}

///|
/// Check if all tasks have been completed.
pub fn Progress::finished(self : Progress) -> Bool {
  self.tasks_.values().all(task => task.finished())
}

///|
/// Start the progress display.
pub fn Progress::start(self : Progress) -> Unit raise {
  if !self.disable {
    self.live.start(refresh=true)
  }
}

///|
/// Stop the progress display.
pub fn Progress::stop(self : Progress) -> Unit raise {
  if !self.disable {
    self.live.stop()
    let console = self.console()
    if !console.is_interactive && !console.is_jupyter {
      console.print_many([])
    }
  }
}

///|
/// Run `f` with the progress display started (upstream `with progress:`).
pub fn Progress::run(self : Progress, f : () -> Unit raise) -> Unit raise {
  self.start()
  {
    errdefer self.stop()
    f()
  }
  self.stop()
}

///|
/// Start a task (used when calculating elapsed time). Needed if the task
/// was added with `start=false`.
pub fn Progress::start_task(self : Progress, task_id : Int) -> Unit raise {
  let task = self.get_task(task_id)
  if task.start_time is None {
    task.start_time = Some((self.get_time)())
  }
}

///|
/// Stop a task: freezes the elapsed time.
pub fn Progress::stop_task(self : Progress, task_id : Int) -> Unit raise {
  let task = self.get_task(task_id)
  let current_time = (self.get_time)()
  if task.start_time is None {
    task.start_time = Some(current_time)
  }
  task.stop_time = Some(current_time)
}

///|
/// Refresh the display after a change if auto refresh is due.
fn Progress::auto_refresh(self : Progress) -> Unit raise {
  if !self.disable && self.live.is_started() {
    self.live.tick()
  }
}

///|
/// Update information associated with a task. Omitted arguments are left
/// unchanged; `fields` are merged into `task.fields`.
pub fn Progress::update(
  self : Progress,
  task_id : Int,
  total? : Double,
  completed? : Double,
  advance? : Double,
  description? : String,
  visible? : Bool,
  refresh? : Bool = false,
  fields? : Map[String, Json] = {},
) -> Unit raise {
  let task = self.get_task(task_id)
  let completed_start = task.completed
  if total is Some(total) && task.total != Some(total) {
    task.total = Some(total)
    task.reset()
  }
  if advance is Some(advance) {
    task.completed += advance
  }
  if completed is Some(completed) {
    task.completed = completed
  }
  if description is Some(description) {
    task.description = description
  }
  if visible is Some(visible) {
    task.visible = visible
  }
  for key, value in fields {
    task.fields[key] = value
  }
  let update_completed = task.completed - completed_start
  let current_time = (self.get_time)()
  let old_sample_time = current_time - self.speed_estimate_period
  task.drop_samples_before(old_sample_time)
  if update_completed > 0.0 {
    task.add_sample({ timestamp: current_time, completed: update_completed, })
  }
  if task.total is Some(total) &&
    task.completed >= total &&
    task.finished_time is None {
    task.finished_time = task.elapsed()
  }
  if refresh {
    self.refresh()
  } else {
    self.auto_refresh()
  }
}

///|
/// Reset a task so completed is 0 and the clock is reset.
pub fn Progress::reset(
  self : Progress,
  task_id : Int,
  start? : Bool = true,
  total? : Double,
  completed? : Double = 0.0,
  visible? : Bool,
  description? : String,
  fields? : Map[String, Json] = {},
) -> Unit raise {
  let current_time = (self.get_time)()
  let task = self.get_task(task_id)
  task.reset()
  task.start_time = if start { Some(current_time) } else { None }
  if total is Some(_) {
    task.total = total
  }
  task.completed = completed
  if visible is Some(visible) {
    task.visible = visible
  }
  if !fields.is_empty() {
    task.fields = fields
  }
  if description is Some(description) {
    task.description = description
  }
  task.finished_time = None
  self.refresh()
}

///|
/// Advance a task by a number of steps.
pub fn Progress::advance(
  self : Progress,
  task_id : Int,
  advance? : Double = 1.0,
) -> Unit raise {
  let current_time = (self.get_time)()
  let task = self.get_task(task_id)
  let completed_start = task.completed
  task.completed += advance
  let update_completed = task.completed - completed_start
  let old_sample_time = current_time - self.speed_estimate_period
  task.drop_samples_before(old_sample_time)
  task.add_sample({ timestamp: current_time, completed: update_completed, })
  if task.total is Some(total) &&
    task.completed >= total &&
    task.finished_time is None {
    task.finished_time = task.elapsed()
    task.finished_speed = task.speed()
  }
  self.auto_refresh()
}

///|
/// Refresh (render) the progress information.
pub fn Progress::refresh(self : Progress) -> Unit raise {
  if !self.disable && self.live.is_started() {
    self.live.refresh()
  }
}

///|
/// Get a renderable for the progress display.
pub fn Progress::get_renderable(self : Progress) -> &@rich.Renderable raise {
  @rich.Group::new(self.get_renderables())
}

///|
/// Get the renderables for the progress display (the tasks table).
pub fn Progress::get_renderables(
  self : Progress,
) -> Array[&@rich.Renderable] raise {
  [self.make_tasks_table(self.tasks())]
}

///|
/// Get a table to render the progress display, one row per visible task.
pub fn Progress::make_tasks_table(
  self : Progress,
  tasks : Array[Task],
) -> @rich.Table raise {
  let table_columns : Array[&@rich.IntoColumn] = self.columns.map(column => {
    column.get_table_column().copy()
  })
  let table = @rich.Table::grid(
    headers=table_columns,
    padding=[0, 1],
    expand=self.expand,
  )
  for task in tasks {
    if task.visible {
      let row : Array[&@rich.Renderable] = []
      for column in self.columns {
        row.push(column.call(task))
      }
      table.add_row(row)
    }
  }
  table
}

///|
/// Add a new task to the progress display and return its ID.
///
/// * `start`: start the task immediately (to calculate elapsed time);
///   otherwise call `start_task`.
/// * `total`: number of total steps, or `None` for a pulsing animation.
/// * `completed`: number of steps completed so far.
/// * `visible`: enable display of the task.
/// * `fields`: additional data fields required for rendering.
pub fn Progress::add_task(
  self : Progress,
  description : String,
  start? : Bool = true,
  total? : Double? = Some(100.0),
  completed? : Double = 0.0,
  visible? : Bool = true,
  fields? : Map[String, Json] = {},
) -> Int raise {
  let task = Task::new(
    self.task_index,
    description,
    total,
    completed,
    visible~,
    fields~,
    get_time=self.get_time,
  )
  self.tasks_[self.task_index] = task
  if start {
    self.start_task(self.task_index)
  }
  let new_task_index = self.task_index
  self.task_index += 1
  self.refresh()
  new_task_index
}

///|
/// Delete a task if it exists.
pub fn Progress::remove_task(self : Progress, task_id : Int) -> Unit {
  self.tasks_.remove(task_id)
}

///|
/// The progress display is renderable (upstream `__rich__`).
pub impl @rich.Renderable for Progress with fn rich_console(
  self,
  _console,
  _options,
) {
  [Child(self.get_renderable())]
}
