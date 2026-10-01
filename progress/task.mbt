// Port of the `Task` and `ProgressSample` classes of rich/progress.py.

///|
/// Sample of progress for a given time.
pub(all) struct ProgressSample {
  /// Timestamp of sample.
  timestamp : Double
  /// Number of steps completed.
  completed : Double
} derive(Eq, Debug)

///|
/// Maximum number of progress samples kept per task (upstream
/// `deque(maxlen=1000)`).
let max_samples : Int = 1000

///|
/// Information regarding a progress task.
///
/// This object should be considered read-only outside of `Progress`.
pub(all) struct Task {
  /// Task ID associated with this task (used in `Progress` methods).
  id : Int
  /// Description of the task.
  mut description : String
  /// Total number of steps in this task, or `None` if unknown.
  mut total : Double?
  /// Number of steps completed.
  mut completed : Double
  priv get_time_ : () -> Double
  /// Time the task was finished (elapsed time when it finished).
  mut finished_time : Double?
  /// Indicates if this task is visible in the progress display.
  mut visible : Bool
  /// Arbitrary fields passed in via `Progress::update` (available in
  /// format strings as `{task.fields[name]}`).
  mut fields : Map[String, Json]
  /// Time this task was started, or `None` if not started.
  mut start_time : Double?
  /// Time this task was stopped, or `None` if not stopped.
  mut stop_time : Double?
  /// The last speed for a finished task.
  mut finished_speed : Double?
  priv samples : @deque.Deque[ProgressSample]
}

///|
/// Create a task (normally done by `Progress::add_task`).
pub fn Task::new(
  id : Int,
  description : String,
  total : Double?,
  completed : Double,
  get_time~ : () -> Double,
  finished_time? : Double,
  visible? : Bool = true,
  fields? : Map[String, Json] = {},
) -> Task {
  {
    id,
    description,
    total,
    completed,
    get_time_: get_time,
    finished_time,
    visible,
    fields,
    start_time: None,
    stop_time: None,
    finished_speed: None,
    samples: @deque.Deque([]),
  }
}

///|
/// Get the current time, in seconds.
pub fn Task::get_time(self : Task) -> Double {
  (self.get_time_)()
}

///|
/// Check if the task has started.
pub fn Task::started(self : Task) -> Bool {
  self.start_time is Some(_)
}

///|
/// Number of steps remaining, if a total was set.
pub fn Task::remaining(self : Task) -> Double? {
  match self.total {
    None => None
    Some(total) => Some(total - self.completed)
  }
}

///|
/// Time elapsed since the task was started, or `None` if it hasn't
/// started.
pub fn Task::elapsed(self : Task) -> Double? {
  match self.start_time {
    None => None
    Some(start_time) =>
      match self.stop_time {
        Some(stop_time) => Some(stop_time - start_time)
        None => Some(self.get_time() - start_time)
      }
  }
}

///|
/// Check if the task has finished.
pub fn Task::finished(self : Task) -> Bool {
  self.finished_time is Some(_)
}

///|
/// Progress of the task as a percentage (0 if the total is unknown or 0).
pub fn Task::percentage(self : Task) -> Double {
  match self.total {
    None => 0.0
    Some(total) if total == 0.0 => 0.0
    Some(total) => {
      let completed = self.completed / total * 100.0
      @cmp.minimum(100.0, @cmp.maximum(0.0, completed))
    }
  }
}

///|
/// The estimated speed in steps per second.
pub fn Task::speed(self : Task) -> Double? {
  if self.start_time is None {
    return None
  }
  let progress = self.samples
  guard progress.front() is Some(first) && progress.back() is Some(last) else {
    return None
  }
  let total_time = last.timestamp - first.timestamp
  if total_time == 0.0 {
    return None
  }
  let mut total_completed = 0.0
  for i, sample in progress {
    if i > 0 {
      total_completed += sample.completed
    }
  }
  Some(total_completed / total_time)
}

///|
/// Estimated time to completion (whole seconds, rounded up), or `None` if
/// there is no data.
pub fn Task::time_remaining(self : Task) -> Double? {
  if self.finished() {
    return Some(0.0)
  }
  let speed = match self.speed() {
    Some(s) if s != 0.0 => s
    _ => return None
  }
  match self.remaining() {
    None => None
    Some(remaining) => Some((remaining / speed).ceil())
  }
}

///|
/// The progress samples used to estimate the speed (oldest first).
pub fn Task::samples(self : Task) -> Array[ProgressSample] {
  self.samples.iter().collect()
}

///|
/// Record a progress sample (keeps at most 1000 samples).
fn Task::add_sample(self : Task, sample : ProgressSample) -> Unit {
  if self.samples.length() >= max_samples {
    ignore(self.samples.pop_front())
  }
  self.samples.push_back(sample)
}

///|
/// Drop samples older than `old_sample_time`.
fn Task::drop_samples_before(self : Task, old_sample_time : Double) -> Unit {
  while self.samples.front() is Some(s) && s.timestamp < old_sample_time {
    ignore(self.samples.pop_front())
  }
}

///|
/// Reset progress.
fn Task::reset(self : Task) -> Unit {
  self.samples.clear()
  self.finished_time = None
  self.finished_speed = None
}
