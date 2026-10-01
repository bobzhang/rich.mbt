// Differential tests: expected output computed with upstream Rich 15.0.0
// (scripts/progress_oracle.py).

///|
test "oracle format_task" {
  let task = @progress.Task::new(
    3,
    "Downloading",
    Some(1234.0),
    567.5,
    get_time=() => 5.0,
    fields={
      "name": "x y",
      "n": 42,
      "x": 3.14159,
      "big": 1234567,
      "flag": true,
    },
  )
  task.start_time = Some(1.5)
  assert_eq(@progress.format_task("{task.description}", task), "Downloading")
  assert_eq(@progress.format_task("{task.percentage:>3.0f}%", task), " 46%")
  assert_eq(@progress.format_task("{task.completed}", task), "567.5")
  assert_eq(@progress.format_task("{task.total}", task), "1234.0")
  assert_eq(
    @progress.format_task("{task.completed:.2f}/{task.total:,.1f}", task),
    "567.50/1,234.0",
  )
  assert_eq(@progress.format_task("{task.percentage:05.1f}", task), "046.0")
  assert_eq(
    @progress.format_task("{task.description:^15}|", task),
    "  Downloading  |",
  )
  assert_eq(
    @progress.format_task("{task.description:*<14}", task),
    "Downloading***",
  )
  assert_eq(
    @progress.format_task("{task.description!r}", task),
    "'Downloading'",
  )
  assert_eq(@progress.format_task("{task.id:03d}", task), "003")
  assert_eq(@progress.format_task("{task.id:>+4}", task), "  +3")
  assert_eq(@progress.format_task("{task.fields[name]}", task), "x y")
  assert_eq(@progress.format_task("{task.fields[n]:>5}", task), "   42")
  assert_eq(@progress.format_task("{task.fields[n]:<5}|", task), "42   |")
  assert_eq(@progress.format_task("{task.fields[x]:.3f}", task), "3.142")
  assert_eq(@progress.format_task("{task.fields[x]}", task), "3.14159")
  assert_eq(@progress.format_task("{task.fields[big]:,d}", task), "1,234,567")
  assert_eq(@progress.format_task("{task.fields[big]:_}", task), "1_234_567")
  assert_eq(
    @progress.format_task(
      "{task.fields[n]:x} {task.fields[n]:X} {task.fields[n]:o} {task.fields[n]:b}",
      task,
    ),
    "2a 2A 52 101010",
  )
  assert_eq(@progress.format_task("{task.fields[flag]}", task), "True")
  assert_eq(@progress.format_task("{task.remaining}", task), "666.5")
  assert_eq(
    @progress.format_task("{task.started} {task.finished} {task.visible}", task),
    "True False True",
  )
  assert_eq(@progress.format_task("{{literal}} {task.id}", task), "{literal} 3")
  assert_eq(
    @progress.format_task("{task.completed:+.1f} {task.completed: .1f}", task),
    "+567.5  567.5",
  )
  assert_eq(@progress.format_task("{task.completed:,}", task), "567.5")
  assert_eq(
    @progress.format_task("{task.total:e} {task.completed:10.3E}", task),
    "1.234000e+03  5.675E+02",
  )
  assert_eq(@progress.format_task("{task.description:.4}", task), "Down")
  assert_eq(
    @progress.format_task("{task.percentage:=+10.2f}", task),
    "+    45.99",
  )
  assert_eq(@progress.format_task("{task.completed:%}", task), "56750.000000%")
  assert_eq(@progress.format_task("{task.completed:.0%}", task), "56750%")
  assert_eq(@progress.format_task("{task.elapsed}", task), "3.5")
  assert_eq(@progress.format_task("{task.speed}", task), "None")
  assert_eq(
    @progress.format_task("{task.completed:12,.3f}", task),
    "     567.500",
  )
  let task2 = @progress.Task::new(0, "Unknown", None, 0.0, get_time=() => 5.0)
  assert_eq(@progress.format_task("{task.total}", task2), "None")
  assert_eq(@progress.format_task("{task.percentage:>3.0f}%", task2), "  0%")
  assert_eq(@progress.format_task("{task.remaining}", task2), "None")
  assert_eq(@progress.format_task("{task.elapsed}", task2), "None")
  assert_eq(@progress.format_task("{task.time_remaining}", task2), "None")
}

///|
test "oracle progress default columns" {
  let clock = Ref(0.0)
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    file~,
    width=80,
    color_system=Some("truecolor"),
    force_terminal=true,
    legacy_windows=false,
    environ={},
  )
  let get_time = () => clock.val
  let p = @progress.Progress::new(console~, get_time~, auto_refresh=false)
  let t1 = p.add_task("[red]Download", total=Some(1000.0))
  let t2 = p.add_task("Unknown", total=None)
  let t3 = p.add_task("Done", total=Some(10.0))
  let _t4 = p.add_task("Later", start=false)
  for _ in 0..<5 {
    clock.val += 0.7
    p.advance(t1, advance=37.0)
    p.update(t3, advance=3.0)
  }
  p.update(t2, description="Unknown [b]still")
  let progress = p
  console.print(progress)
  assert_eq(
    file.getvalue(),
    "\u{1b}[31mDownload\u{1b}[0m      \u{1b}[38;2;249;38;114m━━━━━━━\u{1b}[0m\u{1b}[38;5;237m╺\u{1b}[0m\u{1b}[38;5;237m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\u{1b}[0m \u{1b}[35m 18%\u{1b}[0m \u{1b}[36m0:00:16\u{1b}[0m\nUnknown \u{1b}[1mstill\u{1b}[0m \u{1b}[38;2;230;39;108m━\u{1b}[0m\u{1b}[38;2;244;38;112m━\u{1b}[0m\u{1b}[38;2;249;38;114m━\u{1b}[0m\u{1b}[38;2;244;38;112m━\u{1b}[0m\u{1b}[38;2;230;39;108m━\u{1b}[0m\u{1b}[38;2;209;42;102m━\u{1b}[0m\u{1b}[38;2;183;44;94m━\u{1b}[0m\u{1b}[38;2;153;48;86m━\u{1b}[0m\u{1b}[38;2;123;51;77m━\u{1b}[0m\u{1b}[38;2;97;53;69m━\u{1b}[0m\u{1b}[38;2;76;56;63m━\u{1b}[0m\u{1b}[38;2;62;57;59m━\u{1b}[0m\u{1b}[38;2;58;58;58m━\u{1b}[0m\u{1b}[38;2;62;57;59m━\u{1b}[0m\u{1b}[38;2;76;56;63m━\u{1b}[0m\u{1b}[38;2;97;53;69m━\u{1b}[0m\u{1b}[38;2;123;51;77m━\u{1b}[0m\u{1b}[38;2;153;48;86m━\u{1b}[0m\u{1b}[38;2;183;44;94m━\u{1b}[0m\u{1b}[38;2;209;42;102m━\u{1b}[0m\u{1b}[38;2;230;39;108m━\u{1b}[0m\u{1b}[38;2;244;38;112m━\u{1b}[0m\u{1b}[38;2;249;38;114m━\u{1b}[0m\u{1b}[38;2;244;38;112m━\u{1b}[0m\u{1b}[38;2;230;39;108m━\u{1b}[0m\u{1b}[38;2;209;42;102m━\u{1b}[0m\u{1b}[38;2;183;44;94m━\u{1b}[0m\u{1b}[38;2;153;48;86m━\u{1b}[0m\u{1b}[38;2;123;51;77m━\u{1b}[0m\u{1b}[38;2;97;53;69m━\u{1b}[0m\u{1b}[38;2;76;56;63m━\u{1b}[0m\u{1b}[38;2;62;57;59m━\u{1b}[0m\u{1b}[38;2;58;58;58m━\u{1b}[0m\u{1b}[38;2;62;57;59m━\u{1b}[0m\u{1b}[38;2;76;56;63m━\u{1b}[0m\u{1b}[38;2;97;53;69m━\u{1b}[0m\u{1b}[38;2;123;51;77m━\u{1b}[0m\u{1b}[38;2;153;48;86m━\u{1b}[0m\u{1b}[38;2;183;44;94m━\u{1b}[0m\u{1b}[38;2;209;42;102m━\u{1b}[0m      \u{1b}[36m       \u{1b}[0m\nDone          \u{1b}[38;2;114;156;31m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\u{1b}[0m \u{1b}[35m100%\u{1b}[0m \u{1b}[36m0:00:00\u{1b}[0m\nLater         \u{1b}[38;2;230;39;108m━\u{1b}[0m\u{1b}[38;2;244;38;112m━\u{1b}[0m\u{1b}[38;2;249;38;114m━\u{1b}[0m\u{1b}[38;2;244;38;112m━\u{1b}[0m\u{1b}[38;2;230;39;108m━\u{1b}[0m\u{1b}[38;2;209;42;102m━\u{1b}[0m\u{1b}[38;2;183;44;94m━\u{1b}[0m\u{1b}[38;2;153;48;86m━\u{1b}[0m\u{1b}[38;2;123;51;77m━\u{1b}[0m\u{1b}[38;2;97;53;69m━\u{1b}[0m\u{1b}[38;2;76;56;63m━\u{1b}[0m\u{1b}[38;2;62;57;59m━\u{1b}[0m\u{1b}[38;2;58;58;58m━\u{1b}[0m\u{1b}[38;2;62;57;59m━\u{1b}[0m\u{1b}[38;2;76;56;63m━\u{1b}[0m\u{1b}[38;2;97;53;69m━\u{1b}[0m\u{1b}[38;2;123;51;77m━\u{1b}[0m\u{1b}[38;2;153;48;86m━\u{1b}[0m\u{1b}[38;2;183;44;94m━\u{1b}[0m\u{1b}[38;2;209;42;102m━\u{1b}[0m\u{1b}[38;2;230;39;108m━\u{1b}[0m\u{1b}[38;2;244;38;112m━\u{1b}[0m\u{1b}[38;2;249;38;114m━\u{1b}[0m\u{1b}[38;2;244;38;112m━\u{1b}[0m\u{1b}[38;2;230;39;108m━\u{1b}[0m\u{1b}[38;2;209;42;102m━\u{1b}[0m\u{1b}[38;2;183;44;94m━\u{1b}[0m\u{1b}[38;2;153;48;86m━\u{1b}[0m\u{1b}[38;2;123;51;77m━\u{1b}[0m\u{1b}[38;2;97;53;69m━\u{1b}[0m\u{1b}[38;2;76;56;63m━\u{1b}[0m\u{1b}[38;2;62;57;59m━\u{1b}[0m\u{1b}[38;2;58;58;58m━\u{1b}[0m\u{1b}[38;2;62;57;59m━\u{1b}[0m\u{1b}[38;2;76;56;63m━\u{1b}[0m\u{1b}[38;2;97;53;69m━\u{1b}[0m\u{1b}[38;2;123;51;77m━\u{1b}[0m\u{1b}[38;2;153;48;86m━\u{1b}[0m\u{1b}[38;2;183;44;94m━\u{1b}[0m\u{1b}[38;2;209;42;102m━\u{1b}[0m \u{1b}[35m  0%\u{1b}[0m \u{1b}[36m-:--:--\u{1b}[0m\n",
  )
}

///|
test "oracle progress file columns" {
  let clock = Ref(0.0)
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    file~,
    width=120,
    color_system=Some("truecolor"),
    force_terminal=true,
    legacy_windows=false,
    environ={},
  )
  let get_time = () => clock.val
  let p = @progress.Progress::new(
    columns=[
      @progress.SpinnerColumn::new(finished_text="[green]✓"),
      @progress.TextColumn::new("{task.description}", justify=Right),
      @progress.MofNCompleteColumn::new(),
      @progress.TimeElapsedColumn::new(),
      @progress.TransferSpeedColumn::new(),
      @progress.DownloadColumn::new(binary_units=true),
      @progress.FileSizeColumn::new(),
      @progress.TotalFileSizeColumn::new(),
    ],
    console~,
    get_time~,
    auto_refresh=false,
  )
  let a = p.add_task("big.iso", total=Some(4.7e9))
  let b = p.add_task("small", total=Some(2048.0))
  let d = p.add_task("stream", total=None)
  for _ in 0..<3 {
    clock.val += 1.5
    p.advance(a, advance=1.234e8)
    p.advance(b, advance=1000.0)
    p.advance(d, advance=12345.0)
  }
  clock.val += 90000.0
  p.advance(b, advance=1048.0)
  let progress = p
  console.print(progress)
  assert_eq(
    file.getvalue(),
    "\u{1b}[32m⠋\u{1b}[0m big.iso \u{1b}[32m 370200000/4700000000\u{1b}[0m \u{1b}[33m1 day, 1:00:04\u{1b}[0m \u{1b}[31m82.3 MB/s  \u{1b}[0m \u{1b}[32m0.3/4.4 GiB\u{1b}[0m \u{1b}[32m370.2 MB\u{1b}[0m \u{1b}[32m4.7 GB\u{1b}[0m\n\u{1b}[32m✓\u{1b}[0m   small \u{1b}[32m4048/2048            \u{1b}[0m \u{1b}[33m0:00:04       \u{1b}[0m \u{1b}[31m666 bytes/s\u{1b}[0m \u{1b}[32m4.0/2.0 KiB\u{1b}[0m \u{1b}[32m4.0 kB  \u{1b}[0m \u{1b}[32m2.0 kB\u{1b}[0m\n\u{1b}[32m⠋\u{1b}[0m  stream \u{1b}[32m37035/?              \u{1b}[0m \u{1b}[33m1 day, 1:00:04\u{1b}[0m \u{1b}[31m8.2 kB/s   \u{1b}[0m \u{1b}[32m36.2/? KiB \u{1b}[0m \u{1b}[32m37.0 kB \u{1b}[0m \u{1b}[32m      \u{1b}[0m\n",
  )
}

///|
test "oracle progress speed expand" {
  let clock = Ref(0.0)
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    file~,
    width=100,
    color_system=Some("truecolor"),
    force_terminal=true,
    legacy_windows=false,
    environ={},
  )
  let get_time = () => clock.val
  let p = @progress.Progress::new(
    columns=[
      @progress.TextColumn::new("[progress.description]{task.description}"),
      @progress.BarColumn::new(bar_width=Some(20)),
      @progress.TaskProgressColumn::new(show_speed=true),
      @progress.TimeRemainingColumn::new(compact=true),
      @progress.TimeRemainingColumn::new(elapsed_when_finished=true),
      "{task.fields[status]}",
    ],
    console~,
    get_time~,
    auto_refresh=false,
    expand=true,
  )
  let a = p.add_task("items", total=None, fields={ "status": "ok" })
  let b = p.add_task("known", total=Some(50.0), fields={ "status": "[i]busy" })
  for _ in 0..<6 {
    clock.val += 0.25
    p.advance(a, advance=1500.0)
    p.advance(b, advance=9.0)
  }
  p.update(b, fields={ "status": "done" }, refresh=true)
  let progress = p
  console.print(progress)
  assert_eq(
    file.getvalue(),
    "items      \u{1b}[38;2;76;56;63m━\u{1b}[0m\u{1b}[38;2;62;57;59m━\u{1b}[0m\u{1b}[38;2;58;58;58m━\u{1b}[0m\u{1b}[38;2;62;57;59m━\u{1b}[0m\u{1b}[38;2;76;56;63m━\u{1b}[0m\u{1b}[38;2;97;53;69m━\u{1b}[0m\u{1b}[38;2;123;51;77m━\u{1b}[0m\u{1b}[38;2;153;48;86m━\u{1b}[0m\u{1b}[38;2;183;44;94m━\u{1b}[0m\u{1b}[38;2;209;42;102m━\u{1b}[0m\u{1b}[38;2;230;39;108m━\u{1b}[0m\u{1b}[38;2;244;38;112m━\u{1b}[0m\u{1b}[38;2;249;38;114m━\u{1b}[0m\u{1b}[38;2;244;38;112m━\u{1b}[0m\u{1b}[38;2;230;39;108m━\u{1b}[0m\u{1b}[38;2;209;42;102m━\u{1b}[0m\u{1b}[38;2;183;44;94m━\u{1b}[0m\u{1b}[38;2;153;48;86m━\u{1b}[0m\u{1b}[38;2;123;51;77m━\u{1b}[0m\u{1b}[38;2;97;53;69m━\u{1b}[0m                \u{1b}[35m6.0×10³ it/s          \u{1b}[0m \u{1b}[36m         \u{1b}[0m \u{1b}[36m             \u{1b}[0m ok    \nknown      \u{1b}[38;2;114;156;31m━━━━━━━━━━━━━━━━━━━━\u{1b}[0m                \u{1b}[35m100%\u{1b}[0m                   \u{1b}[36m00:00    \u{1b}[0m \u{1b}[33m0:00:01      \u{1b}[0m done  \n",
  )
}

///|
test "oracle progress reset" {
  let clock = Ref(0.0)
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    file~,
    width=70,
    color_system=Some("256"),
    force_terminal=true,
    legacy_windows=false,
    environ={},
  )
  let get_time = () => clock.val
  let p = @progress.Progress::new(
    console~,
    get_time~,
    auto_refresh=false,
    speed_estimate_period=2.0,
  )
  let a = p.add_task("a", total=Some(100.0))
  for _ in 0..<10 {
    clock.val += 0.5
    p.advance(a, advance=4.0)
  }
  p.reset(a, total=40.0, completed=10.0, description="a again")
  clock.val += 1.0
  p.update(a, advance=5.0)
  let b = p.add_task("hidden", visible=false)
  p.update(b, completed=100.0)
  let progress = p
  console.print(progress)
  assert_eq(
    file.getvalue(),
    "a again \u{1b}[38;5;197m━━━━━━━━━━━━━━━\u{1b}[0m\u{1b}[38;5;237m╺\u{1b}[0m\u{1b}[38;5;237m━━━━━━━━━━━━━━━━━━━━━━━━\u{1b}[0m \u{1b}[35m 38%\u{1b}[0m \u{1b}[36m-:--:--\u{1b}[0m\n",
  )
}

///|
test "oracle progress non interactive" {
  let clock = Ref(0.0)
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    file~,
    width=60,
    color_system=Some("standard"),
    force_terminal=false,
    legacy_windows=false,
    environ={},
  )
  let p = @progress.Progress::new(
    console~,
    get_time=() => clock.val,
    auto_refresh=false,
  )
  p.run(() => {
    let t = p.add_task("job", total=Some(3.0))
    for _ in 0..<3 {
      clock.val += 1.0
      p.advance(t)
      p.refresh()
    }
  })
  assert_eq(
    file.getvalue(),
    "job \u{1b}[90m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\u{1b}[0m \u{1b}[35m100%\u{1b}[0m \u{1b}[36m0:00:00\u{1b}[0m\n",
  )
}

///|
test "oracle time elapsed days" {
  let task = @progress.Task::new(0, "t", Some(10.0), 3.0, get_time=() => {
    200000.0
  })
  task.start_time = Some(0.0)
  assert_eq(
    @progress.TimeElapsedColumn::new().render(task).plain(),
    "2 days, 7:33:20",
  )
  task.start_time = Some(199999.0 - 86400.0)
  assert_eq(
    @progress.TimeElapsedColumn::new().render(task).plain(),
    "1 day, 0:00:01",
  )
}
