// Port of tests/test_progress.py.
//
// Skipped (no threads / file IO in MoonBit): test_track_thread, test_open,
// test_open_text_mode, test_wrap_file, test_wrap_file_task_total.

///|
/// A clock that is manually advanced (upstream `MockClock`).
struct MockClock {
  mut time : Double
  auto : Bool
}

///|
fn MockClock::new(time? : Double = 0.0, auto? : Bool = true) -> MockClock {
  { time, auto, }
}

///|
fn MockClock::get_time(self : MockClock) -> () -> Double {
  () => {
    let t = self.time
    if self.auto {
      self.time += 1.0
    }
    t
  }
}

///|
fn make_console(
  width? : Int = 80,
  force_terminal? : Bool = true,
  force_interactive? : Bool,
) -> @rich.Console raise {
  @rich.Console::new(
    file=@rich.StringIO::new(),
    force_terminal~,
    force_interactive?,
    color_system=Some("truecolor"),
    width~,
    legacy_windows=false,
    environ={},
  )
}

///|
fn plain(r : &@rich.Renderable) -> String {
  match r.text_kind() {
    Str(s) => s
    Text(t) => t.plain()
    NotText => abort("not text")
  }
}

///|
test "bar_columns" {
  let bar_column = @progress.BarColumn::new(bar_width=Some(100))
  assert_eq(bar_column.bar_width, Some(100))
  let task = @progress.Task::new(1, "test", Some(100.0), 20.0, get_time=() => {
    1.0
  })
  let bar = bar_column.render(task)
  assert_eq(bar.completed, 20.0)
  assert_eq(bar.total, Some(100.0))
}

///|
test "text_column" {
  let text_column = @progress.TextColumn::new(
    "[b]foo",
    highlighter=@rich.NullHighlighter::new(),
  )
  let task = @progress.Task::new(1, "test", Some(100.0), 20.0, get_time=() => {
    1.0
  })
  let text = text_column.render(task)
  assert_eq(text.plain(), "foo")
  let text_column = @progress.TextColumn::new("[b]bar", markup=false)
  let task = @progress.Task::new(1, "test", Some(100.0), 20.0, get_time=() => {
    1.0
  })
  let text = text_column.render(task)
  assert_true(text == @rich.Text::new(text="[b]bar"))
}

///|
test "time_elapsed_column" {
  let column = @progress.TimeElapsedColumn::new()
  let task = @progress.Task::new(1, "test", Some(100.0), 20.0, get_time=() => {
    1.0
  })
  let text = column.render(task)
  assert_eq(text.plain(), "-:--:--")
}

///|
/// A task whose estimated time remaining is `task_time` (upstream fakes
/// the `time_remaining` property): one step per second has been done.
fn task_with_time_remaining(task_time : Int?) -> @progress.Task raise {
  let clock = MockClock::new(auto=false)
  let progress = @progress.Progress::new(
    console=make_console(),
    get_time=clock.get_time(),
    auto_refresh=false,
  )
  let total = match task_time {
    Some(t) => t.to_double() + 1.0
    None => 100.0
  }
  let task_id = progress.add_task("test", total=Some(total))
  if task_time is Some(_) {
    progress.advance(task_id, advance=0.0)
    clock.time += 1.0
    progress.advance(task_id, advance=1.0)
  }
  progress.get_task(task_id)
}

///|
test "time_remaining_column" {
  let column = @progress.TimeRemainingColumn::new()
  let task = @progress.Task::new(1, "test", Some(100.0), 20.0, get_time=() => {
    1.0
  })
  let text = column.call(task)
  assert_eq(plain(text), "-:--:--")
  // time_remaining = 60
  let clock = MockClock::new(auto=false)
  let progress = @progress.Progress::new(
    console=make_console(),
    get_time=clock.get_time(),
    auto_refresh=false,
  )
  let task_id = progress.add_task("test", total=Some(140.0))
  progress.advance(task_id, advance=0.0)
  clock.time += 10.0
  progress.advance(task_id, advance=20.0)
  let task = progress.get_task(task_id)
  assert_eq(task.time_remaining(), Some(60.0))
  let text = column.call(task)
  assert_eq(plain(text), "0:01:00")
}

///|
test "compact_time_remaining_column" {
  let cases : Array[(Int?, String)] = [
    (None, "--:--"),
    (Some(0), "00:00"),
    (Some(59), "00:59"),
    (Some(71), "01:11"),
    (Some(4210), "1:10:10"),
  ]
  for case in cases {
    let (task_time, formatted) = case
    let task = task_with_time_remaining(task_time)
    let column = @progress.TimeRemainingColumn::new(compact=true)
    assert_eq(column.render(task).plain(), formatted)
  }
}

///|
test "time_remaining_column_elapsed_when_finished" {
  let task = @progress.Task::new(1, "test", Some(100.0), 20.0, get_time=() => {
    1.0
  })
  task.finished_time = Some(71.0)
  let column = @progress.TimeRemainingColumn::new(elapsed_when_finished=true)
  assert_eq(column.render(task).plain(), "0:01:11")
}

///|
test "renderable_column" {
  let column = @progress.RenderableColumn::new(renderable="foo")
  let task = @progress.Task::new(1, "test", Some(100.0), 20.0, get_time=() => {
    1.0
  })
  assert_true(
    @progress.ProgressColumn::render(column, task).text_kind() is Str("foo"),
  )
}

///|
test "spinner_column" {
  let time = Ref(1.0)
  let column = @progress.SpinnerColumn::new()
  column.set_spinner("dots2")
  let task = @progress.Task::new(1, "test", Some(100.0), 20.0, get_time=() => {
    time.val
  })
  let result = @progress.ProgressColumn::render(column, task)
  assert_eq(plain(result), "⣾")
  time.val += 1.0
  column.spinner.update(speed=0.5)
  let result = @progress.ProgressColumn::render(column, task)
  assert_eq(plain(result), "⡿")
}

///|
test "download_progress_uses_decimal_units" {
  let column = @progress.DownloadColumn::new()
  let test_task = @progress.Task::new(1, "test", Some(1000.0), 500.0, get_time=() => {
    1.0
  })
  assert_eq(column.render(test_task).plain(), "0.5/1.0 kB")
}

///|
test "download_progress_uses_binary_units" {
  let column = @progress.DownloadColumn::new(binary_units=true)
  let test_task = @progress.Task::new(1, "test", Some(1024.0), 512.0, get_time=() => {
    1.0
  })
  assert_eq(column.render(test_task).plain(), "0.5/1.0 KiB")
}

///|
test "task_ids" {
  let (progress, _) = make_progress()
  assert_eq(progress.task_ids(), [0, 1, 2, 4])
}

///|
test "finished" {
  let (progress, _) = make_progress()
  assert_true(!progress.finished())
}

///|
fn make_progress() -> (@progress.Progress, @rich.StringIO) raise {
  let clock = MockClock::new()
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    file~,
    force_terminal=true,
    color_system=Some("truecolor"),
    width=80,
    legacy_windows=false,
    environ={},
  )
  let progress = @progress.Progress::new(
    console~,
    get_time=clock.get_time(),
    auto_refresh=false,
  )
  let _task1 = progress.add_task("foo")
  let task2 = progress.add_task("bar", total=Some(30.0))
  progress.advance(task2, advance=16.0)
  let _task3 = progress.add_task("baz", visible=false)
  let task4 = progress.add_task("egg")
  progress.remove_task(task4)
  let task4 = progress.add_task("foo2", completed=50.0, start=false)
  progress.stop_task(task4)
  progress.start_task(task4)
  progress.update(
    task4,
    total=200.0,
    advance=50.0,
    completed=200.0,
    visible=true,
    refresh=true,
  )
  progress.stop_task(task4)
  (progress, file)
}

///|
fn render_progress() -> String raise {
  let (progress, file) = make_progress()
  progress.start() // superfluous noop
  progress.run(() => ())
  progress.stop() // superfluous noop
  file.getvalue()
}

///|
test "expand_bar" {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    file~,
    force_terminal=true,
    width=10,
    color_system=Some("truecolor"),
    legacy_windows=false,
    environ={},
  )
  let progress = @progress.Progress::new(
    columns=[@progress.BarColumn::new(bar_width=None)],
    console~,
    get_time=() => 1.0,
    auto_refresh=false,
  )
  ignore(progress.add_task("foo"))
  progress.run(() => ())
  assert_eq(
    file.getvalue(),
    "\u{1b}[?25l\u{1b}[38;5;237m━━━━━━━━━━\u{1b}[0m\r\u{1b}[2K\u{1b}[38;5;237m━━━━━━━━━━\u{1b}[0m\n\u{1b}[?25h",
  )
}

///|
test "progress_with_none_total_renders_a_pulsing_bar" {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    file~,
    force_terminal=true,
    width=10,
    color_system=Some("truecolor"),
    legacy_windows=false,
    environ={},
  )
  let progress = @progress.Progress::new(
    columns=[@progress.BarColumn::new(bar_width=None)],
    console~,
    get_time=() => 1.0,
    auto_refresh=false,
  )
  ignore(progress.add_task("foo", total=None))
  progress.run(() => ())
  assert_eq(
    file.getvalue(),
    "\u{1b}[?25l\u{1b}[38;2;153;48;86m━\u{1b}[0m\u{1b}[38;2;183;44;94m━\u{1b}[0m\u{1b}[38;2;209;42;102m━\u{1b}[0m\u{1b}[38;2;230;39;108m━\u{1b}[0m\u{1b}[38;2;244;38;112m━\u{1b}[0m\u{1b}[38;2;249;38;114m━\u{1b}[0m\u{1b}[38;2;244;38;112m━\u{1b}[0m\u{1b}[38;2;230;39;108m━\u{1b}[0m\u{1b}[38;2;209;42;102m━\u{1b}[0m\u{1b}[38;2;183;44;94m━\u{1b}[0m\r\u{1b}[2K\u{1b}[38;2;153;48;86m━\u{1b}[0m\u{1b}[38;2;183;44;94m━\u{1b}[0m\u{1b}[38;2;209;42;102m━\u{1b}[0m\u{1b}[38;2;230;39;108m━\u{1b}[0m\u{1b}[38;2;244;38;112m━\u{1b}[0m\u{1b}[38;2;249;38;114m━\u{1b}[0m\u{1b}[38;2;244;38;112m━\u{1b}[0m\u{1b}[38;2;230;39;108m━\u{1b}[0m\u{1b}[38;2;209;42;102m━\u{1b}[0m\u{1b}[38;2;183;44;94m━\u{1b}[0m\n\u{1b}[?25h",
  )
}

///|
test "render" {
  assert_eq(
    render_progress(),
    "\u{1b}[?25lfoo  \u{1b}[38;5;237m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\u{1b}[0m \u{1b}[35m  0%\u{1b}[0m \u{1b}[36m-:--:--\u{1b}[0m\nbar  \u{1b}[38;2;249;38;114m━━━━━━━━━━━━━━━━━━━━━\u{1b}[0m\u{1b}[38;5;237m╺\u{1b}[0m\u{1b}[38;5;237m━━━━━━━━━━━━━━━━━━\u{1b}[0m \u{1b}[35m 53%\u{1b}[0m \u{1b}[36m-:--:--\u{1b}[0m\nfoo2 \u{1b}[38;2;114;156;31m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\u{1b}[0m \u{1b}[35m100%\u{1b}[0m \u{1b}[36m0:00:00\u{1b}[0m\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2Kfoo  \u{1b}[38;5;237m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\u{1b}[0m \u{1b}[35m  0%\u{1b}[0m \u{1b}[36m-:--:--\u{1b}[0m\nbar  \u{1b}[38;2;249;38;114m━━━━━━━━━━━━━━━━━━━━━\u{1b}[0m\u{1b}[38;5;237m╺\u{1b}[0m\u{1b}[38;5;237m━━━━━━━━━━━━━━━━━━\u{1b}[0m \u{1b}[35m 53%\u{1b}[0m \u{1b}[36m-:--:--\u{1b}[0m\nfoo2 \u{1b}[38;2;114;156;31m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\u{1b}[0m \u{1b}[35m100%\u{1b}[0m \u{1b}[36m0:00:00\u{1b}[0m\n\u{1b}[?25h",
  )
}

///|
test "track" {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    file~,
    force_terminal=true,
    width=60,
    color_system=Some("truecolor"),
    legacy_windows=false,
    environ={},
  )
  let test_values = ["foo", "bar", "baz"]
  let seen = []
  @progress.track(
    test_values.iter(),
    value => seen.push(value),
    description="test",
    console~,
    auto_refresh=false,
    get_time=MockClock::new(auto=true).get_time(),
  )
  assert_eq(seen, test_values)
  assert_eq(
    file.getvalue(),
    "\u{1b}[?25l\r\u{1b}[2Ktest \u{1b}[38;5;237m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\u{1b}[0m \u{1b}[35m  0%\u{1b}[0m \u{1b}[36m-:--:--\u{1b}[0m\r\u{1b}[2Ktest \u{1b}[38;2;249;38;114m━━━━━━━━━━━━━\u{1b}[0m\u{1b}[38;5;237m╺\u{1b}[0m\u{1b}[38;5;237m━━━━━━━━━━━━━━━━━━━━━━━━━━\u{1b}[0m \u{1b}[35m 33%\u{1b}[0m \u{1b}[36m-:--:--\u{1b}[0m\r\u{1b}[2Ktest \u{1b}[38;2;249;38;114m━━━━━━━━━━━━━━━━━━━━━━━━━━\u{1b}[0m\u{1b}[38;2;249;38;114m╸\u{1b}[0m\u{1b}[38;5;237m━━━━━━━━━━━━━\u{1b}[0m \u{1b}[35m 67%\u{1b}[0m \u{1b}[36m0:00:06\u{1b}[0m\r\u{1b}[2Ktest \u{1b}[38;2;114;156;31m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\u{1b}[0m \u{1b}[35m100%\u{1b}[0m \u{1b}[33m0:00:19\u{1b}[0m\r\u{1b}[2Ktest \u{1b}[38;2;114;156;31m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\u{1b}[0m \u{1b}[35m100%\u{1b}[0m \u{1b}[33m0:00:19\u{1b}[0m\n\u{1b}[?25h",
  )
}

///|
test "progress_track" {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    file~,
    force_terminal=true,
    width=60,
    color_system=Some("truecolor"),
    legacy_windows=false,
    environ={},
  )
  let progress = @progress.Progress::new(
    console~,
    auto_refresh=false,
    get_time=MockClock::new(auto=true).get_time(),
  )
  let test_values = ["foo", "bar", "baz"]
  let seen = []
  progress.run(() => {
    progress.track(
      test_values.iter(),
      value => seen.push(value),
      description="test",
    )
  })
  assert_eq(seen, test_values)
  assert_eq(
    file.getvalue(),
    "\u{1b}[?25l\r\u{1b}[2Ktest \u{1b}[38;5;237m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\u{1b}[0m \u{1b}[35m  0%\u{1b}[0m \u{1b}[36m-:--:--\u{1b}[0m\r\u{1b}[2Ktest \u{1b}[38;2;249;38;114m━━━━━━━━━━━━━\u{1b}[0m\u{1b}[38;5;237m╺\u{1b}[0m\u{1b}[38;5;237m━━━━━━━━━━━━━━━━━━━━━━━━━━\u{1b}[0m \u{1b}[35m 33%\u{1b}[0m \u{1b}[36m-:--:--\u{1b}[0m\r\u{1b}[2Ktest \u{1b}[38;2;249;38;114m━━━━━━━━━━━━━━━━━━━━━━━━━━\u{1b}[0m\u{1b}[38;2;249;38;114m╸\u{1b}[0m\u{1b}[38;5;237m━━━━━━━━━━━━━\u{1b}[0m \u{1b}[35m 67%\u{1b}[0m \u{1b}[36m0:00:06\u{1b}[0m\r\u{1b}[2Ktest \u{1b}[38;2;114;156;31m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\u{1b}[0m \u{1b}[35m100%\u{1b}[0m \u{1b}[36m0:00:00\u{1b}[0m\r\u{1b}[2Ktest \u{1b}[38;2;114;156;31m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\u{1b}[0m \u{1b}[35m100%\u{1b}[0m \u{1b}[36m0:00:00\u{1b}[0m\n\u{1b}[?25h",
  )
}

///|
test "columns" {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    file~,
    force_terminal=true,
    width=80,
    log_time_format="[TIME]",
    color_system=Some("truecolor"),
    legacy_windows=false,
    log_path=false,
    environ={},
  )
  let progress = @progress.Progress::new(
    columns=[
      "test",
      @progress.TextColumn::new("{task.description}"),
      @progress.BarColumn::new(bar_width=None),
      @progress.TimeRemainingColumn::new(),
      @progress.TimeElapsedColumn::new(),
      @progress.FileSizeColumn::new(),
      @progress.TotalFileSizeColumn::new(),
      @progress.DownloadColumn::new(),
      @progress.TransferSpeedColumn::new(),
      @progress.MofNCompleteColumn::new(),
      @progress.MofNCompleteColumn::new(separator=" of "),
    ],
    transient=true,
    console~,
    auto_refresh=false,
    get_time=MockClock::new().get_time(),
  )
  let task1 = progress.add_task("foo", total=Some(10.0))
  let task2 = progress.add_task("bar", total=Some(7.0))
  progress.run(() => {
    for _ in 0..<4 {
      progress.advance(task1, advance=3.0)
      progress.advance(task2, advance=4.0)
    }
    // upstream: print("foo") through the stdout redirection
    console.print("foo")
    console.log("hello")
    console.print("world")
    progress.refresh()
  })
  assert_eq(
    file.getvalue(),
    "\u{1b}[?25ltest foo \u{1b}[38;5;237m━━━━━━━━━━\u{1b}[0m \u{1b}[36m-:--:--\u{1b}[0m \u{1b}[33m0:00:07\u{1b}[0m \u{1b}[32m0 bytes\u{1b}[0m \u{1b}[32m10 bytes\u{1b}[0m \u{1b}[32m0/10 bytes\u{1b}[0m \u{1b}[31m?\u{1b}[0m \u{1b}[32m 0/10\u{1b}[0m \u{1b}[32m 0 of 10\u{1b}[0m\ntest bar \u{1b}[38;5;237m━━━━━━━━━━\u{1b}[0m \u{1b}[36m-:--:--\u{1b}[0m \u{1b}[33m0:00:18\u{1b}[0m \u{1b}[32m0 bytes\u{1b}[0m \u{1b}[32m7 bytes \u{1b}[0m \u{1b}[32m0/7 bytes \u{1b}[0m \u{1b}[31m?\u{1b}[0m \u{1b}[32m0/7  \u{1b}[0m \u{1b}[32m0 of 7  \u{1b}[0m\r\u{1b}[2K\u{1b}[1A\u{1b}[2Kfoo\ntest foo \u{1b}[38;5;237m━━━━━━━━━━\u{1b}[0m \u{1b}[36m-:--:--\u{1b}[0m \u{1b}[33m0:00:07\u{1b}[0m \u{1b}[32m0 bytes\u{1b}[0m \u{1b}[32m10 bytes\u{1b}[0m \u{1b}[32m0/10 bytes\u{1b}[0m \u{1b}[31m?\u{1b}[0m \u{1b}[32m 0/10\u{1b}[0m \u{1b}[32m 0 of 10\u{1b}[0m\ntest bar \u{1b}[38;5;237m━━━━━━━━━━\u{1b}[0m \u{1b}[36m-:--:--\u{1b}[0m \u{1b}[33m0:00:18\u{1b}[0m \u{1b}[32m0 bytes\u{1b}[0m \u{1b}[32m7 bytes \u{1b}[0m \u{1b}[32m0/7 bytes \u{1b}[0m \u{1b}[31m?\u{1b}[0m \u{1b}[32m0/7  \u{1b}[0m \u{1b}[32m0 of 7  \u{1b}[0m\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[2;36m[TIME]\u{1b}[0m\u{1b}[2;36m \u{1b}[0mhello                                                                    \ntest foo \u{1b}[38;5;237m━━━━━━━━━━\u{1b}[0m \u{1b}[36m-:--:--\u{1b}[0m \u{1b}[33m0:00:07\u{1b}[0m \u{1b}[32m0 bytes\u{1b}[0m \u{1b}[32m10 bytes\u{1b}[0m \u{1b}[32m0/10 bytes\u{1b}[0m \u{1b}[31m?\u{1b}[0m \u{1b}[32m 0/10\u{1b}[0m \u{1b}[32m 0 of 10\u{1b}[0m\ntest bar \u{1b}[38;5;237m━━━━━━━━━━\u{1b}[0m \u{1b}[36m-:--:--\u{1b}[0m \u{1b}[33m0:00:18\u{1b}[0m \u{1b}[32m0 bytes\u{1b}[0m \u{1b}[32m7 bytes \u{1b}[0m \u{1b}[32m0/7 bytes \u{1b}[0m \u{1b}[31m?\u{1b}[0m \u{1b}[32m0/7  \u{1b}[0m \u{1b}[32m0 of 7  \u{1b}[0m\r\u{1b}[2K\u{1b}[1A\u{1b}[2Kworld\ntest foo \u{1b}[38;5;237m━━━━━━━━━━\u{1b}[0m \u{1b}[36m-:--:--\u{1b}[0m \u{1b}[33m0:00:07\u{1b}[0m \u{1b}[32m0 bytes\u{1b}[0m \u{1b}[32m10 bytes\u{1b}[0m \u{1b}[32m0/10 bytes\u{1b}[0m \u{1b}[31m?\u{1b}[0m \u{1b}[32m 0/10\u{1b}[0m \u{1b}[32m 0 of 10\u{1b}[0m\ntest bar \u{1b}[38;5;237m━━━━━━━━━━\u{1b}[0m \u{1b}[36m-:--:--\u{1b}[0m \u{1b}[33m0:00:18\u{1b}[0m \u{1b}[32m0 bytes\u{1b}[0m \u{1b}[32m7 bytes \u{1b}[0m \u{1b}[32m0/7 bytes \u{1b}[0m \u{1b}[31m?\u{1b}[0m \u{1b}[32m0/7  \u{1b}[0m \u{1b}[32m0 of 7  \u{1b}[0m\r\u{1b}[2K\u{1b}[1A\u{1b}[2Ktest foo \u{1b}[38;2;114;156;31m━━━━━━━\u{1b}[0m \u{1b}[36m0:00:00\u{1b}[0m \u{1b}[33m0:00:34\u{1b}[0m \u{1b}[32m12     \u{1b}[0m \u{1b}[32m10     \u{1b}[0m \u{1b}[32m12/10   \u{1b}[0m \u{1b}[31m1      \u{1b}[0m \u{1b}[32m12/10\u{1b}[0m \u{1b}[32m12 of 10\u{1b}[0m\n                                 \u{1b}[32mbytes  \u{1b}[0m \u{1b}[32mbytes  \u{1b}[0m \u{1b}[32mbytes   \u{1b}[0m \u{1b}[31mbyte/s \u{1b}[0m               \ntest bar \u{1b}[38;2;114;156;31m━━━━━━━\u{1b}[0m \u{1b}[36m0:00:00\u{1b}[0m \u{1b}[33m0:00:29\u{1b}[0m \u{1b}[32m16     \u{1b}[0m \u{1b}[32m7 bytes\u{1b}[0m \u{1b}[32m16/7    \u{1b}[0m \u{1b}[31m2      \u{1b}[0m \u{1b}[32m16/7 \u{1b}[0m \u{1b}[32m16 of 7 \u{1b}[0m\n                                 \u{1b}[32mbytes  \u{1b}[0m         \u{1b}[32mbytes   \u{1b}[0m \u{1b}[31mbytes/s\u{1b}[0m               \r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2Ktest foo \u{1b}[38;2;114;156;31m━━━━━━━\u{1b}[0m \u{1b}[36m0:00:00\u{1b}[0m \u{1b}[33m0:00:34\u{1b}[0m \u{1b}[32m12     \u{1b}[0m \u{1b}[32m10     \u{1b}[0m \u{1b}[32m12/10   \u{1b}[0m \u{1b}[31m1      \u{1b}[0m \u{1b}[32m12/10\u{1b}[0m \u{1b}[32m12 of 10\u{1b}[0m\n                                 \u{1b}[32mbytes  \u{1b}[0m \u{1b}[32mbytes  \u{1b}[0m \u{1b}[32mbytes   \u{1b}[0m \u{1b}[31mbyte/s \u{1b}[0m               \ntest bar \u{1b}[38;2;114;156;31m━━━━━━━\u{1b}[0m \u{1b}[36m0:00:00\u{1b}[0m \u{1b}[33m0:00:29\u{1b}[0m \u{1b}[32m16     \u{1b}[0m \u{1b}[32m7 bytes\u{1b}[0m \u{1b}[32m16/7    \u{1b}[0m \u{1b}[31m2      \u{1b}[0m \u{1b}[32m16/7 \u{1b}[0m \u{1b}[32m16 of 7 \u{1b}[0m\n                                 \u{1b}[32mbytes  \u{1b}[0m         \u{1b}[32mbytes   \u{1b}[0m \u{1b}[31mbytes/s\u{1b}[0m               \n\u{1b}[?25h\r\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K",
  )
}

///|
test "using_default_columns" {
  // Upstream checks the column classes; check the count here.
  let progress = @progress.Progress::new(console=make_console())
  assert_eq(progress.columns.length(), 4)
  let columns : Array[&@progress.ProgressColumn] = [
    @progress.SpinnerColumn::new(),
    ..@progress.Progress::get_default_columns(),
    "Elapsed:",
    @progress.TimeElapsedColumn::new(),
  ]
  let progress = @progress.Progress::new(columns~, console=make_console())
  assert_eq(progress.columns.length(), 7)
}

///|
test "task_create" {
  let task = @progress.Task::new(1, "foo", Some(100.0), 0.0, get_time=() => 1.0)
  assert_eq(task.elapsed(), None)
  assert_true(!task.finished())
  assert_eq(task.percentage(), 0.0)
  assert_eq(task.speed(), None)
  assert_eq(task.time_remaining(), None)
}

///|
test "task_start" {
  let current_time = Ref(1.0)
  let get_time = () => current_time.val
  let task = @progress.Task::new(1, "foo", Some(100.0), 0.0, get_time~)
  task.start_time = Some(get_time())
  assert_true(task.started())
  assert_eq(task.elapsed(), Some(0.0))
  current_time.val += 1.0
  assert_eq(task.elapsed(), Some(1.0))
  current_time.val += 1.0
  task.stop_time = Some(get_time())
  current_time.val += 1.0
  assert_eq(task.elapsed(), Some(2.0))
}

///|
test "task_zero_total" {
  let task = @progress.Task::new(1, "foo", Some(0.0), 0.0, get_time=() => 1.0)
  assert_eq(task.percentage(), 0.0)
}

///|
test "progress_create" {
  let progress = @progress.Progress::new(console=make_console())
  assert_true(progress.finished())
  assert_eq(progress.tasks().length(), 0)
  assert_eq(progress.task_ids(), [])
}

///|
test "reset" {
  let progress = @progress.Progress::new(console=make_console())
  let task_id = progress.add_task("foo")
  progress.advance(task_id, advance=1.0)
  progress.advance(task_id, advance=1.0)
  progress.advance(task_id, advance=1.0)
  progress.advance(task_id, advance=7.0)
  let task = progress.tasks()[task_id]
  assert_eq(task.completed, 10.0)
  progress.reset(
    task_id,
    total=200.0,
    completed=20.0,
    visible=false,
    description="bar",
    fields={ "example": "egg" },
  )
  assert_eq(task.total, Some(200.0))
  assert_eq(task.completed, 20.0)
  assert_eq(task.visible, false)
  assert_eq(task.description, "bar")
  assert_eq(task.fields, { "example": "egg" })
  assert_eq(task.samples().length(), 0)
}

///|
test "progress_max_refresh" {
  let time = Ref(0.0)
  let get_time = () => {
    let t = time.val
    time.val = time.val + 1.0
    t
  }
  let console = @rich.Console::new(
    color_system=None,
    width=80,
    legacy_windows=false,
    force_terminal=true,
    file=@rich.StringIO::new(),
    environ={},
  )
  let column = @progress.TextColumn::new("{task.description}")
  column.state.max_refresh = Some(3.0)
  let progress = @progress.Progress::new(
    columns=[column],
    get_time~,
    auto_refresh=false,
    console~,
  )
  console.begin_capture()
  progress.run(() => {
    let task_id = progress.add_task("start")
    for tick in 0..<6 {
      progress.update(task_id, description="tick \{tick}")
      progress.refresh()
    }
  })
  let result = console.end_capture()
  assert_eq(
    result, "\u{1b}[?25l\r\u{1b}[2Kstart\r\u{1b}[2Kstart\r\u{1b}[2Ktick 1\r\u{1b}[2Ktick 1\r\u{1b}[2Ktick 3\r\u{1b}[2Ktick 3\r\u{1b}[2Ktick 5\r\u{1b}[2Ktick 5\n\u{1b}[?25h",
  )
}

///|
test "live_is_started_if_progress_is_enabled" {
  let progress = @progress.Progress::new(
    console=make_console(),
    auto_refresh=false,
    disable=false,
  )
  progress.run(() => assert_true(progress.live.is_started()))
}

///|
test "live_is_not_started_if_progress_is_disabled" {
  let progress = @progress.Progress::new(
    console=make_console(),
    auto_refresh=false,
    disable=true,
  )
  progress.run(() => assert_true(!progress.live.is_started()))
}

///|
test "no_output_if_progress_is_disabled" {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    file~,
    force_terminal=true,
    width=60,
    color_system=Some("truecolor"),
    legacy_windows=false,
    environ={},
  )
  let progress = @progress.Progress::new(console~, disable=true)
  let test_values = ["foo", "bar", "baz"]
  let seen = []
  progress.run(() => {
    progress.track(
      test_values.iter(),
      value => seen.push(value),
      description="test",
    )
  })
  assert_eq(seen, test_values)
  assert_eq(file.getvalue(), "")
}

///|
test "no_output_if_progress_is_disabled_non_interactive" {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    file~,
    force_interactive=false,
    width=60,
    color_system=Some("truecolor"),
    legacy_windows=false,
    environ={},
  )
  let progress = @progress.Progress::new(console~, disable=true)
  let test_values = ["foo", "bar", "baz"]
  let seen = []
  progress.run(() => {
    progress.track(
      test_values.iter(),
      value => seen.push(value),
      description="test",
    )
  })
  assert_eq(seen, test_values)
  assert_eq(file.getvalue(), "")
}

///|
test "task_progress_column_speed" {
  let speed_text = @progress.TaskProgressColumn::render_speed(None)
  assert_eq(speed_text.plain(), "")
  let speed_text = @progress.TaskProgressColumn::render_speed(Some(5.0))
  assert_eq(speed_text.plain(), "5.0 it/s")
  let speed_text = @progress.TaskProgressColumn::render_speed(Some(5000.0))
  assert_eq(speed_text.plain(), "5.0×10³ it/s")
  let speed_text = @progress.TaskProgressColumn::render_speed(Some(8888888.0))
  assert_eq(speed_text.plain(), "8.9×10⁶ it/s")
}
