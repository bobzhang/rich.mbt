// Tests for the thread-less auto refresh (not upstream tests).

///|
fn count(haystack : String, needle : String) -> Int {
  let mut n = 0
  let mut rest = haystack[:]
  while rest.find(needle) is Some(i) {
    n += 1
    rest = rest[i + needle.length():]
  }
  n
}

///|
test "advance refreshes when the refresh interval elapsed" {
  let time = Ref(0.0)
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    file~,
    width=40,
    force_terminal=true,
    legacy_windows=false,
    color_system=None,
    get_time=() => time.val,
    environ={},
  )
  let progress = @progress.Progress::new(
    columns=["{task.description} {task.completed:.0f}"],
    console~,
    refresh_per_second=10.0,
  )
  progress.start()
  let task = progress.add_task("job", total=Some(100.0))
  let after_add = file.getvalue()
  assert_eq(after_add, "\u{1b}[?25l\r\u{1b}[2Kjob 0")
  // within 0.1s of the last refresh: no output
  time.val = 0.05
  progress.advance(task)
  assert_eq(file.getvalue(), after_add)
  time.val = 0.1
  progress.advance(task)
  assert_eq(file.getvalue(), after_add + "\r\u{1b}[2Kjob 2")
  time.val = 0.15
  progress.update(task, advance=5.0)
  assert_eq(file.getvalue(), after_add + "\r\u{1b}[2Kjob 2")
  time.val = 0.3
  progress.update(task, advance=5.0)
  assert_eq(file.getvalue(), after_add + "\r\u{1b}[2Kjob 2\r\u{1b}[2Kjob 12")
  progress.stop()
  assert_true(file.getvalue().has_suffix("\r\u{1b}[2Kjob 12\n\u{1b}[?25h"))
}

///|
test "track with auto refresh advances every update_period" {
  let time = Ref(0.0)
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    file~,
    width=40,
    force_terminal=true,
    legacy_windows=false,
    color_system=None,
    get_time=() => time.val,
    environ={},
  )
  let progress = @progress.Progress::new(
    columns=["{task.description} {task.completed:.0f}"],
    console~,
    refresh_per_second=4.0,
  )
  let completed = []
  progress.run(() => {
    progress.track(
      [1, 2, 3, 4, 5, 6, 7, 8, 9, 10].iter(),
      _ => {
        time.val += 0.25
        completed.push(progress.tasks()[0].completed)
      },
      description="items",
      update_period=0.75,
    )
  })
  // the task is advanced in batches, every 0.75 seconds
  assert_eq(completed, [0, 0, 0, 3, 3, 3, 6, 6, 6, 9])
  assert_eq(progress.tasks()[0].completed, 10.0)
  assert_true(file.getvalue().has_suffix("items 10\n\u{1b}[?25h"))
  assert_true(count(file.getvalue(), "items") < 10)
}

///|
test "module track with auto refresh" {
  let time = Ref(0.0)
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    file~,
    width=60,
    force_terminal=true,
    legacy_windows=false,
    color_system=None,
    get_time=() => time.val,
    environ={},
  )
  let mut sum = 0
  let items = Array::makei(99, i => i + 1)
  @progress.track(
    items.iter(),
    i => {
      time.val += 0.01
      sum += i
    },
    description="sum",
    console~,
  )
  assert_eq(sum, 4950)
  // 10 refreshes per second over ~1 second, plus start and stop
  assert_true(count(file.getvalue(), "sum") <= 13)
  assert_true(file.getvalue().has_suffix(" 100% 0:00:00\n\u{1b}[?25h"))
  // without a size hint the total is unknown: the speed is shown
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    file~,
    width=60,
    force_terminal=true,
    legacy_windows=false,
    color_system=None,
    get_time=() => time.val,
    environ={},
  )
  @progress.track(
    (1).until(100).iter(),
    _ => time.val += 0.01,
    description="sum",
    console~,
  )
  assert_true(file.getvalue().has_suffix(" 100.0 it/s  \n\u{1b}[?25h"))
}
