// Port of rich/live.py.
//
// MoonBit has no threads, so there is no background refresh thread (see
// DESIGN.md §7). With `auto_refresh=true` the display is refreshed by
// `update` (and `tick`) when at least `1 / refresh_per_second` seconds
// (measured with `console.get_time`) have passed since the last refresh.
// `start(refresh=true)`, `refresh()`, `update(refresh=true)` and `stop()`
// refresh unconditionally, exactly as upstream.

///|
/// Live displays that are started, by id (the console only keeps ids on
/// its live stack).
let live_registry : Map[Int, Live] = Map([])

///|
let next_live_id : Ref[Int] = Ref(0)

///|
/// Renders an auto-updating live display of any given renderable.
pub(all) struct Live {
  priv id : Int
  priv mut renderable_ : &@rich.Renderable?
  /// The console the display is written to.
  console : @rich.Console
  priv screen : Bool
  priv mut alt_screen : Bool
  /// Refresh automatically (throttled by `refresh_per_second`) when the
  /// display is updated. When disabled, call `refresh()` or
  /// `update(refresh=true)`.
  mut auto_refresh : Bool
  priv mut started : Bool
  /// Clear the renderable on exit.
  mut transient : Bool
  /// Maximum number of automatic refreshes per second.
  mut refresh_per_second : Double
  /// How to handle a renderable taller than the console.
  mut vertical_overflow : VerticalOverflowMethod
  priv get_renderable_ : (() -> &@rich.Renderable raise)?
  priv live_render : LiveRender
  priv mut nested : Bool
  priv mut last_refresh : Double?
}

///|
/// Create a live display.
///
/// * `renderable`: the renderable to display (default: nothing).
/// * `console`: defaults to the global console.
/// * `screen`: enable alternate screen mode.
/// * `auto_refresh`: refresh when updated, at most `refresh_per_second`
///   times per second.
/// * `transient`: clear the display on exit (implied by `screen`).
/// * `redirect_stdout` / `redirect_stderr`: accepted for compatibility;
///   MoonBit cannot redirect the process streams (print through the
///   console instead).
/// * `vertical_overflow`: how to handle a renderable taller than the
///   console.
/// * `get_renderable`: called to get the renderable on every refresh.
pub fn Live::new(
  renderable? : &@rich.Renderable,
  console? : @rich.Console,
  screen? : Bool = false,
  auto_refresh? : Bool = true,
  refresh_per_second? : Double = 4.0,
  transient? : Bool = false,
  redirect_stdout? : Bool = true,
  redirect_stderr? : Bool = true,
  vertical_overflow? : VerticalOverflowMethod = Ellipsis,
  get_renderable? : () -> &@rich.Renderable raise,
) -> Live {
  ignore(redirect_stdout)
  ignore(redirect_stderr)
  guard refresh_per_second > 0.0 else {
    abort("refresh_per_second must be > 0")
  }
  let id = next_live_id.val
  next_live_id.val += 1
  let live : Live = {
    id,
    renderable_: renderable,
    console: match console {
      Some(c) => c
      None => @rich.get_console()
    },
    screen,
    alt_screen: false,
    auto_refresh,
    started: false,
    transient: if screen {
      true
    } else {
      transient
    },
    refresh_per_second,
    vertical_overflow,
    get_renderable_: get_renderable,
    live_render: LiveRender::new("", vertical_overflow~),
    nested: false,
    last_refresh: None,
  }
  live.live_render.set_renderable(live.get_renderable() catch { _ => "" })
  live
}

///|
/// Check if the live display has been started.
pub fn Live::is_started(self : Live) -> Bool {
  self.started
}

///|
/// Whether this display was started inside another live display on the
/// same console (it is then rendered by the outermost display, which also
/// owns refreshing).
pub fn Live::is_nested(self : Live) -> Bool {
  self.nested
}

///|
/// Seconds until an automatic refresh is due (0 if due now), shared by
/// update-driven refresh (`tick`) and timer-driven refresh (`@aio`).
pub fn Live::time_until_refresh(self : Live) -> Double {
  match self.last_refresh {
    None => 0.0
    Some(last) => {
      let wait = 1.0 / self.refresh_per_second - (self.now() - last)
      if wait > 0.0 {
        wait
      } else {
        0.0
      }
    }
  }
}

///|
/// The renderable to display (from `get_renderable` if given), or `""`.
pub fn Live::get_renderable(self : Live) -> &@rich.Renderable raise {
  let renderable = match self.get_renderable_ {
    Some(f) => Some(f())
    None => self.renderable_
  }
  match renderable {
    None => "" as &@rich.Renderable
    Some(r) =>
      match r.text_kind() {
        Str("") => "" as &@rich.Renderable
        Text(t) if t.length() == 0 => ""
        _ => r
      }
  }
}

///|
/// The `LiveRender` used to display the renderable.
pub fn Live::live_render(self : Live) -> LiveRender {
  self.live_render
}

///|
fn Live::now(self : Live) -> Double {
  (self.console.get_time)()
}

///|
/// Start live rendering display. With `refresh=true`, also refresh.
pub fn Live::start(self : Live, refresh? : Bool = false) -> Unit raise {
  if self.started {
    return
  }
  self.started = true
  live_registry[self.id] = self
  if !self.console.set_live(self.id) {
    self.nested = true
    return
  }
  if self.screen {
    self.alt_screen = self.console.set_alt_screen(enable=true)
  }
  ignore(self.console.show_cursor(show=false))
  self.console.push_render_hook(self)
  if refresh {
    // If refresh fails, stop the display so the error can be shown.
    errdefer self.stop()
    self.refresh()
  }
  if self.auto_refresh {
    self.last_refresh = Some(self.now())
  }
}

///|
/// Stop live rendering display (a final refresh renders the whole
/// renderable, even if it overflows).
pub fn Live::stop(self : Live) -> Unit raise {
  if !self.started {
    return
  }
  self.started = false
  self.console.clear_live()
  live_registry.remove(self.id)
  if self.nested {
    if !self.transient {
      self.console.print(self.renderable())
    }
    return
  }
  self.last_refresh = None
  // allow it to fully render on the last even if overflow
  self.vertical_overflow = Visible
  let console = self.console
  console.enter_buffer()
  let mut error : Error? = None
  if !self.alt_screen && !console.is_jupyter {
    self.refresh() catch {
      e => error = Some(e)
    }
  }
  try {
    console.pop_render_hook()
    if !self.alt_screen &&
      console.is_terminal() &&
      self.live_render.last_render_height() != 0 {
      console.line()
    }
    ignore(console.show_cursor(show=true))
    if self.alt_screen {
      ignore(console.set_alt_screen(enable=false))
    }
    if self.transient && !self.alt_screen {
      console.control([self.live_render.restore_cursor()])
    }
  } catch {
    e => if error is None { error = Some(e) }
  }
  console.exit_buffer()
  if error is Some(e) {
    raise e
  }
}

///|
/// Start the display (refreshing if a renderable was given), as upstream
/// `with live:` does on entry.
pub fn Live::enter(self : Live) -> Unit raise {
  self.start(refresh=self.renderable_ is Some(_))
}

///|
/// Run `f` with the live display started (upstream `with Live(...):`).
/// The display is stopped when `f` returns or raises.
pub fn Live::run(self : Live, f : () -> Unit raise) -> Unit raise {
  self.enter()
  {
    errdefer self.stop()
    f()
  }
  self.stop()
}

///|
/// The renderable being displayed. The first live display on the console
/// renders every live display on the console's live stack.
pub fn Live::renderable(self : Live) -> &@rich.Renderable raise {
  let live_stack = self.console.live_stack()
  let renderable : &@rich.Renderable = if live_stack.length() > 0 &&
    live_stack[0] == self.id {
    let renderables : Array[&@rich.Renderable] = []
    for id in live_stack {
      if live_registry.get(id) is Some(live) {
        renderables.push(live.get_renderable())
      }
    }
    @rich.Group::new(renderables) as &@rich.Renderable
  } else {
    self.get_renderable()
  }
  if self.alt_screen {
    @rich.Screen::new([renderable]) as &@rich.Renderable
  } else {
    renderable
  }
}

///|
/// Update the renderable being displayed. A string is rendered with
/// `console.render_str` (markup). With `refresh=true` the display is
/// refreshed now; otherwise it is refreshed if auto refresh is due.
pub fn Live::update(
  self : Live,
  renderable : &@rich.Renderable,
  refresh? : Bool = false,
) -> Unit raise {
  let renderable : &@rich.Renderable = match renderable.text_kind() {
    Str(s) => self.console.render_str(s) as &@rich.Renderable
    _ => renderable
  }
  self.renderable_ = Some(renderable)
  if refresh {
    self.refresh()
  } else {
    self.tick()
  }
}

///|
/// Refresh the display if auto refresh is enabled and at least
/// `1 / refresh_per_second` seconds passed since the last refresh. This
/// replaces upstream's refresh thread: call it from long running loops.
pub fn Live::tick(self : Live) -> Unit raise {
  if !self.started || !self.auto_refresh {
    return
  }
  if self.nested {
    let live_stack = self.console.live_stack()
    if live_stack.length() > 0 && live_registry.get(live_stack[0]) is Some(top) {
      top.tick()
    }
    return
  }
  let now = self.now()
  match self.last_refresh {
    Some(last) if now - last < 1.0 / self.refresh_per_second => ()
    _ => self.refresh()
  }
}

///|
/// Update the display of the live render.
pub fn Live::refresh(self : Live) -> Unit raise {
  self.live_render.set_renderable(self.renderable())
  if self.nested {
    let live_stack = self.console.live_stack()
    if live_stack.length() > 0 && live_registry.get(live_stack[0]) is Some(top) {
      top.refresh()
    }
    return
  }
  let console = self.console
  if console.is_terminal() && !console.is_dumb_terminal() {
    console.buffered(() => console.print(@rich.Control::new([])))
  } else if !self.started && !self.transient {
    // if it is finished allow files or dumb-terminals to see final result
    console.buffered(() => console.print(@rich.Control::new([])))
  }
  if self.auto_refresh && self.started {
    self.last_refresh = Some(self.now())
  }
}

///|
/// Process renderables to restore cursor and display the live render.
pub impl @rich.RenderHook for Live with fn process_renderables(
  self,
  renderables,
) {
  self.live_render.vertical_overflow = self.vertical_overflow
  if self.console.is_interactive {
    let reset = if self.alt_screen {
      @rich.Control::home()
    } else {
      self.live_render.position_cursor()
    }
    [reset, ..renderables, self.live_render]
  } else if !self.started && !self.transient {
    // if it is finished render the final output for files or dumb_terminals
    [..renderables, self.live_render]
  } else {
    renderables
  }
}
