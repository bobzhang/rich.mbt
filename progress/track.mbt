// Port of `track` and `Progress.track` from rich/progress.py.
//
// Upstream returns a generator; MoonBit has no generators, so the loop
// body is passed as a closure: `@progress.track(items.iter(), item => ...)`.

///|
/// Track progress of `f` applied to each value of `sequence`.
///
/// * `total`: total number of steps; defaults to the size hint of
///   `sequence` (`None` if unknown or 0).
/// * `completed`: number of steps completed so far.
/// * `task_id`: task to track; default is a new task.
/// * `description`: description of the new task.
/// * `update_period`: with auto refresh, minimum time (seconds, measured
///   with `console.get_time`) between task updates (upstream's track
///   thread period).
pub fn[T] Progress::track(
  self : Progress,
  sequence : Iter[T],
  f : (T) -> Unit raise,
  total? : Double,
  completed? : Double = 0.0,
  task_id? : Int,
  description? : String = "Working...",
  update_period? : Double = 0.1,
) -> Unit raise {
  let total = match total {
    Some(t) => Some(t)
    None =>
      match sequence.size_hint() {
        Some(n) if n != 0 => Some(n.to_double())
        _ => None
      }
  }
  let task_id = match task_id {
    None => self.add_task(description, total~, completed~)
    Some(task_id) => {
      self.update(task_id, total?, completed~)
      task_id
    }
  }
  if self.live.auto_refresh {
    // Replaces upstream's `_TrackThread`: count iterations and advance the
    // task at most every `update_period` seconds.
    let get_time = self.console().get_time
    let mut track_completed = 0
    let mut last_completed = 0
    let mut last_update = get_time()
    {
      errdefer self.update(
        task_id,
        completed=track_completed.to_double(),
        refresh=true,
      )
      for value in sequence {
        f(value)
        track_completed += 1
        let now = get_time()
        if now - last_update >= update_period && self.live.is_started() {
          last_update = now
          if last_completed != track_completed {
            self.advance(
              task_id,
              advance=(track_completed - last_completed).to_double(),
            )
            last_completed = track_completed
          }
        }
      }
    }
    self.update(task_id, completed=track_completed.to_double(), refresh=true)
  } else {
    for value in sequence {
      f(value)
      self.advance(task_id, advance=1.0)
      self.refresh()
    }
  }
}

///|
/// Track progress by iterating over a sequence: displays a progress bar
/// while `f` is applied to each value.
///
/// * `description`: description of the task shown next to the bar.
/// * `total`: total number of steps; defaults to the size hint of
///   `sequence`.
/// * `completed`: number of steps completed so far.
/// * `auto_refresh`: refresh automatically; disable to refresh after each
///   iteration.
/// * `console`: console to write to (default: the global console).
/// * `transient`: clear the progress on exit.
/// * `get_time`: the clock (default: `console.get_time`).
/// * `refresh_per_second`: maximum number of refreshes per second.
/// * `style`, `complete_style`, `finished_style`, `pulse_style`: bar styles.
/// * `update_period`: minimum time (seconds) between task updates.
/// * `disable`: disable display of progress.
/// * `show_speed`: show speed if the total isn't known.
pub fn[T] track(
  sequence : Iter[T],
  f : (T) -> Unit raise,
  description? : String = "Working...",
  total? : Double,
  completed? : Double = 0.0,
  auto_refresh? : Bool = true,
  console? : @rich.Console,
  transient? : Bool = false,
  get_time? : () -> Double,
  refresh_per_second? : Double = 10.0,
  style? : &@rich.IntoStyle = "bar.back",
  complete_style? : &@rich.IntoStyle = "bar.complete",
  finished_style? : &@rich.IntoStyle = "bar.finished",
  pulse_style? : &@rich.IntoStyle = "bar.pulse",
  update_period? : Double = 0.1,
  disable? : Bool = false,
  show_speed? : Bool = true,
) -> Unit raise {
  let columns : Array[&ProgressColumn] = if description != "" {
    [TextColumn::new("[progress.description]{task.description}")]
  } else {
    []
  }
  columns.push(
    BarColumn::new(style~, complete_style~, finished_style~, pulse_style~),
  )
  columns.push(TaskProgressColumn::new(show_speed~))
  columns.push(TimeRemainingColumn::new(elapsed_when_finished=true))
  let progress = Progress::new(
    columns~,
    auto_refresh~,
    console?,
    transient~,
    get_time?,
    refresh_per_second=if refresh_per_second == 0.0 {
      10.0
    } else {
      refresh_per_second
    },
    disable~,
  )
  progress.run(() => {
    progress.track(
      sequence,
      f,
      total?,
      completed~,
      description~,
      update_period~,
    )
  })
}
