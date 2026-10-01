// Port of tests/test_live.py.

///|
fn create_capture_console(
  width? : Int = 60,
  height? : Int = 80,
  force_terminal? : Bool = true,
) -> @rich.Console raise {
  @rich.Console::new(
    width~,
    height~,
    force_terminal~,
    legacy_windows=false,
    color_system=None,
    file=@rich.StringIO::new(),
    environ={},
  )
}

///|
test "live_state" {
  let console = create_capture_console()
  let live = @live.Live::new(renderable="", console~)
  live.run(() => {
    assert_true(live.is_started())
    live.start()
    let r = live.get_renderable()
    assert_true(r.text_kind() is Str(""))
    assert_true(live.is_started())
    live.stop()
    assert_true(!live.is_started())
  })
  assert_true(!live.is_started())
}

///|
test "growing_display" {
  let console = create_capture_console(height=80, force_terminal=true)
  console.begin_capture()
  let live = @live.Live::new(console~, auto_refresh=false)
  live.run(() => {
    let display = StringBuilder()
    for step in 0..<10 {
      display.write_string("Step \{step}\n")
      live.update(display.to_string(), refresh=true)
    }
  })
  let output = console.end_capture()
  assert_eq(
    output, "\u{1b}[?25lStep 0\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\nStep 4\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\nStep 4\nStep 5\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\nStep 4\nStep 5\nStep 6\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\nStep 4\nStep 5\nStep 6\nStep 7\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\nStep 4\nStep 5\nStep 6\nStep 7\nStep 8\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\nStep 4\nStep 5\nStep 6\nStep 7\nStep 8\nStep 9\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\nStep 4\nStep 5\nStep 6\nStep 7\nStep 8\nStep 9\n\n\u{1b}[?25h",
  )
}

///|
test "growing_display_transient" {
  let console = create_capture_console(height=80, force_terminal=true)
  console.begin_capture()
  let live = @live.Live::new(console~, auto_refresh=false, transient=true)
  live.run(() => {
    let display = StringBuilder()
    for step in 0..<10 {
      display.write_string("Step \{step}\n")
      live.update(display.to_string(), refresh=true)
    }
  })
  let output = console.end_capture()
  assert_eq(
    output, "\u{1b}[?25lStep 0\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\nStep 4\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\nStep 4\nStep 5\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\nStep 4\nStep 5\nStep 6\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\nStep 4\nStep 5\nStep 6\nStep 7\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\nStep 4\nStep 5\nStep 6\nStep 7\nStep 8\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\nStep 4\nStep 5\nStep 6\nStep 7\nStep 8\nStep 9\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\nStep 4\nStep 5\nStep 6\nStep 7\nStep 8\nStep 9\n\n\u{1b}[?25h\r\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K",
  )
}

///|
test "growing_display_overflow_ellipsis" {
  let console = create_capture_console(height=5, force_terminal=true)
  console.begin_capture()
  let live = @live.Live::new(
    console~,
    auto_refresh=false,
    vertical_overflow=Ellipsis,
  )
  live.run(() => {
    let display = StringBuilder()
    for step in 0..<10 {
      display.write_string("Step \{step}\n")
      live.update(display.to_string(), refresh=true)
    }
  })
  let output = console.end_capture()
  assert_eq(
    output, "\u{1b}[?25lStep 0\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\n                            ...                             \r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\n                            ...                             \r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\n                            ...                             \r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\n                            ...                             \r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\n                            ...                             \r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\n                            ...                             \r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\nStep 4\nStep 5\nStep 6\nStep 7\nStep 8\nStep 9\n\n\u{1b}[?25h",
  )
}

///|
test "growing_display_overflow_crop" {
  let console = create_capture_console(height=5, force_terminal=true)
  console.begin_capture()
  let live = @live.Live::new(
    console~,
    auto_refresh=false,
    vertical_overflow=Crop,
  )
  live.run(() => {
    let display = StringBuilder()
    for step in 0..<10 {
      display.write_string("Step \{step}\n")
      live.update(display.to_string(), refresh=true)
    }
  })
  let output = console.end_capture()
  assert_eq(
    output, "\u{1b}[?25lStep 0\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\nStep 4\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\nStep 4\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\nStep 4\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\nStep 4\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\nStep 4\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\nStep 4\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\nStep 4\nStep 5\nStep 6\nStep 7\nStep 8\nStep 9\n\n\u{1b}[?25h",
  )
}

///|
test "growing_display_overflow_visible" {
  let console = create_capture_console(height=5, force_terminal=true)
  console.begin_capture()
  let live = @live.Live::new(
    console~,
    auto_refresh=false,
    vertical_overflow=Visible,
  )
  live.run(() => {
    let display = StringBuilder()
    for step in 0..<10 {
      display.write_string("Step \{step}\n")
      live.update(display.to_string(), refresh=true)
    }
  })
  let output = console.end_capture()
  assert_eq(
    output, "\u{1b}[?25lStep 0\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\nStep 4\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\nStep 4\nStep 5\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\nStep 4\nStep 5\nStep 6\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\nStep 4\nStep 5\nStep 6\nStep 7\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\nStep 4\nStep 5\nStep 6\nStep 7\nStep 8\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\nStep 4\nStep 5\nStep 6\nStep 7\nStep 8\nStep 9\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\nStep 4\nStep 5\nStep 6\nStep 7\nStep 8\nStep 9\n\n\u{1b}[?25h",
  )
}

///|
test "growing_display_autorefresh" {
  // Upstream uses a refresh thread; here updates refresh when due.
  let time = Ref(0.0)
  let console = @rich.Console::new(
    width=60,
    height=5,
    force_terminal=true,
    legacy_windows=false,
    color_system=None,
    file=@rich.StringIO::new(),
    get_time=() => time.val,
    environ={},
  )
  console.begin_capture()
  let live = @live.Live::new(
    console~,
    auto_refresh=true,
    vertical_overflow=Visible,
  )
  live.run(() => {
    let display = StringBuilder()
    for step in 0..<10 {
      display.write_string("Step \{step}\n")
      live.update(display.to_string())
      time.val += 0.2
    }
  })
  ignore(console.end_capture())
}

///|
test "growing_display_console_redirect" {
  let console = create_capture_console(height=80, force_terminal=true)
  console.begin_capture()
  let live = @live.Live::new(console~, auto_refresh=false)
  live.run(() => {
    let display = StringBuilder()
    for step in 0..<10 {
      console.print("Running step \{step}")
      display.write_string("Step \{step}\n")
      live.update(display.to_string(), refresh=true)
    }
  })
  let output = console.end_capture()
  assert_eq(
    output, "\u{1b}[?25lRunning step 0\n\r\u{1b}[2KStep 0\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2KRunning step 1\nStep 0\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KRunning step 2\nStep 0\nStep 1\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KRunning step 3\nStep 0\nStep 1\nStep 2\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KRunning step 4\nStep 0\nStep 1\nStep 2\nStep 3\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\nStep 4\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KRunning step 5\nStep 0\nStep 1\nStep 2\nStep 3\nStep 4\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\nStep 4\nStep 5\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KRunning step 6\nStep 0\nStep 1\nStep 2\nStep 3\nStep 4\nStep 5\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\nStep 4\nStep 5\nStep 6\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KRunning step 7\nStep 0\nStep 1\nStep 2\nStep 3\nStep 4\nStep 5\nStep 6\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\nStep 4\nStep 5\nStep 6\nStep 7\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KRunning step 8\nStep 0\nStep 1\nStep 2\nStep 3\nStep 4\nStep 5\nStep 6\nStep 7\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\nStep 4\nStep 5\nStep 6\nStep 7\nStep 8\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KRunning step 9\nStep 0\nStep 1\nStep 2\nStep 3\nStep 4\nStep 5\nStep 6\nStep 7\nStep 8\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\nStep 4\nStep 5\nStep 6\nStep 7\nStep 8\nStep 9\n\r\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2K\u{1b}[1A\u{1b}[2KStep 0\nStep 1\nStep 2\nStep 3\nStep 4\nStep 5\nStep 6\nStep 7\nStep 8\nStep 9\n\n\u{1b}[?25h",
  )
}

///|
test "growing_display_file_console" {
  let console = create_capture_console(height=80, force_terminal=false)
  console.begin_capture()
  let live = @live.Live::new(console~, auto_refresh=false)
  live.run(() => {
    let display = StringBuilder()
    for step in 0..<10 {
      display.write_string("Step \{step}\n")
      live.update(display.to_string(), refresh=true)
    }
  })
  let output = console.end_capture()
  assert_eq(
    output, "Step 0\nStep 1\nStep 2\nStep 3\nStep 4\nStep 5\nStep 6\nStep 7\nStep 8\nStep 9\n",
  )
}

///|
test "live_screen" {
  let console = create_capture_console(width=20, height=5)
  console.begin_capture()
  let live = @live.Live::new(
    renderable=@rich.Text::new(text="foo"),
    screen=true,
    console~,
    auto_refresh=false,
  )
  live.run(() => live.refresh())
  let result = console.end_capture()
  assert_eq(
    result, "\u{1b}[?1049h\u{1b}[H\u{1b}[?25l\u{1b}[Hfoo                 \n                    \n                    \n                    \n                    \u{1b}[Hfoo                 \n                    \n                    \n                    \n                    \u{1b}[?25h\u{1b}[?1049l",
  )
}

///|
test "live_empty" {
  // Regression test for https://github.com/Textualize/rich/issues/3796
  // No NL should be written if there was nothing rendered.
  let console = create_capture_console(width=20, height=5)
  console.begin_capture()
  let live = @live.Live::new(
    renderable=@rich.Group::new([]),
    console~,
    transient=true,
  )
  live.run(() => ())
  let result = console.end_capture()
  assert_true(!result.contains("\n"))
  assert_eq(result, "\u{1b}[?25l\r\u{1b}[2K\u{1b}[?25h\r")
}
