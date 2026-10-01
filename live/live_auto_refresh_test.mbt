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
test "auto refresh is throttled by refresh_per_second" {
  let time = Ref(0.0)
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    file~,
    width=20,
    height=10,
    force_terminal=true,
    legacy_windows=false,
    color_system=None,
    get_time=() => time.val,
    environ={},
  )
  let live = @live.Live::new(console~, refresh_per_second=4.0)
  live.start()
  // start without refresh: nothing rendered yet
  assert_eq(file.getvalue(), "\u{1b}[?25l")
  live.update("a")
  // not due yet (0s since start)
  assert_eq(file.getvalue(), "\u{1b}[?25l")
  time.val = 0.2
  live.update("b")
  assert_eq(file.getvalue(), "\u{1b}[?25l")
  time.val = 0.25
  live.update("c")
  assert_eq(file.getvalue(), "\u{1b}[?25lc")
  time.val = 0.4
  live.tick()
  assert_eq(file.getvalue(), "\u{1b}[?25lc")
  time.val = 0.5
  live.tick()
  assert_eq(file.getvalue(), "\u{1b}[?25lc\r\u{1b}[2Kc")
  live.stop()
  assert_eq(
    file.getvalue(),
    "\u{1b}[?25lc\r\u{1b}[2Kc\r\u{1b}[2Kc\n\u{1b}[?25h",
  )
}

///|
test "no auto refresh when disabled" {
  let time = Ref(0.0)
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    file~,
    width=20,
    force_terminal=true,
    legacy_windows=false,
    color_system=None,
    get_time=() => time.val,
    environ={},
  )
  let live = @live.Live::new(console~, auto_refresh=false)
  live.run(() => {
    for i in 0..<10 {
      time.val += 1.0
      live.update("step \{i}")
      live.tick()
    }
  })
  assert_eq(count(file.getvalue(), "step"), 1)
  assert_eq(file.getvalue(), "\u{1b}[?25lstep 9\n\u{1b}[?25h")
}

///|
test "nested live tick refreshes the top live" {
  let time = Ref(0.0)
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    file~,
    width=20,
    force_terminal=true,
    legacy_windows=false,
    color_system=None,
    get_time=() => time.val,
    environ={},
  )
  let outer = @live.Live::new(renderable="outer", console~)
  let inner = @live.Live::new(renderable="inner", console~)
  outer.run(() => {
    inner.run(() => {
      time.val = 1.0
      inner.update("inner2")
    })
  })
  // same output as upstream with `inner.update("inner2", refresh=True)`
  assert_eq(
    file.getvalue(),
    "\u{1b}[?25louter\r\u{1b}[2Kouter\ninner2\r\u{1b}[2K\u{1b}[1A\u{1b}[2Kinner2\nouter\ninner2\r\u{1b}[2K\u{1b}[1A\u{1b}[2Kouter\n\u{1b}[?25h",
  )
}
