///|
/// A renderable that counts how often it is rendered.
struct Counter {
  mut renders : Int
}

///|
impl @rich.Renderable for Counter with fn rich_console(self, _console, _options) {
  self.renders += 1
  [Child("render \{self.renders}")]
}

///|
fn terminal_console() -> (@rich.Console, @rich.StringIO) raise {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    file~,
    width=40,
    color_system=Some("truecolor"),
    force_terminal=true,
    legacy_windows=false,
    environ={},
  )
  (console, file)
}

///|
async test "run_live refreshes from a timer while the body sleeps" {
  let (console, file) = terminal_console()
  let counter = Counter::{ renders: 0, }
  let live = @live.Live::new(
    renderable=counter,
    console~,
    refresh_per_second=20.0,
  )
  let result : Int = @aio.run_live(live, () => {
    @async.sleep(300)
    42
  })
  assert_eq(result, 42)
  // initial + about 6 timer refreshes + final; allow for scheduling jitter
  assert_true(counter.renders >= 4, msg="renders: \{counter.renders}")
  assert_true(!live.is_started())
  // each timer refresh redraws the line (carriage return + erase line)
  let redraws = file.getvalue().split("\r\u{1b}[2K").count() - 1
  assert_true(redraws >= 3, msg="redraws: \{redraws}")
}

///|
async test "run_live stops the display when the body raises" {
  let (console, _) = terminal_console()
  let live = @live.Live::new(renderable="x", console~)
  let body : async () -> Unit = () => {
    @async.sleep(10)
    fail("boom")
  }
  try @aio.run_live(live, body) catch {
    _ => ()
  } noraise {
    _ => fail("expected run_live to raise")
  }
  assert_true(!live.is_started())
}

///|
async test "status spinner animates while the body sleeps" {
  let (console, file) = terminal_console()
  let status = @status.Status::new("Working", console~, refresh_per_second=20.0)
  @aio.run_status(status, () => @async.sleep(300))
  // several distinct spinner frames were written
  let frames = [
    "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏",
  ]
  let seen = frames.filter(f => file.getvalue().contains(f))
  assert_true(seen.length() >= 3, msg="frames: \{seen.length()}")
}

///|
async test "async track advances a progress bar" {
  let (console, file) = terminal_console()
  let progress = @progress.Progress::new(console~, refresh_per_second=50.0)
  let seen = []
  @aio.track(
    [1, 2, 3],
    item => {
      @async.sleep(20)
      seen.push(item)
    },
    description="Items",
    progress~,
  )
  assert_eq(seen, [1, 2, 3])
  assert_true(file.getvalue().contains("100%"))
}

///|
async test "nested displays do not start their own timer" {
  let (console, file) = terminal_console()
  let outer = @live.Live::new(renderable="outer", console~, auto_refresh=false)
  outer.start(refresh=true)
  let status = @status.Status::new("inner", console~, refresh_per_second=20.0)
  @aio.run_status(status, () => @async.sleep(200))
  outer.stop()
  // no timer redraws: only the start/stop refreshes of the displays
  let redraws = file.getvalue().split("\r\u{1b}[2K").count() - 1
  assert_true(redraws <= 2, msg="redraws: \{redraws}")
}

///|
async test "timer shares the refresh throttle with update" {
  let (console, _) = terminal_console()
  let counter = Counter::{ renders: 0, }
  let live = @live.Live::new(
    renderable=counter,
    console~,
    refresh_per_second=5.0,
  )
  @aio.run_live(live, () => {
    // updates at 5 Hz plus a 5 Hz timer must not double the refresh rate
    for _ in 0..<5 {
      @async.sleep(100)
      live.update(counter)
    }
  })
  // 500 ms at 5 Hz: start + ~3 automatic refreshes + stop
  assert_true(counter.renders <= 6, msg="renders: \{counter.renders}")
}

///|
async test "async track refreshes after each item without auto refresh" {
  let (console, file) = terminal_console()
  let progress = @progress.Progress::new(console~, auto_refresh=false)
  @aio.track([1, 2, 3, 4], _ => @async.sleep(1), description="Items", progress~)
  let out = file.getvalue()
  assert_true(out.contains(" 25%"), msg=out.escape())
  assert_true(out.contains(" 50%"))
  assert_true(out.contains(" 75%"))
}
