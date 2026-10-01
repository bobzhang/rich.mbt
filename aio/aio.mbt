// Timer-driven refresh for Live, Progress and Status on top of
// `moonbitlang/async`: the counterpart of upstream's refresh thread.
//
// `moonbitlang/async` is single threaded and cooperative: the refresher
// runs whenever the body suspends (sleeps, does async IO, or calls
// `@async.pause()`). A CPU-bound body that never suspends is only refreshed
// by the synchronous `update`/`advance`/`tick` path, as without this package.

///|
/// Refresh `live` from a timer while `body` runs (upstream
/// `_RefreshThread`). `live` must already be started.
///
/// * As upstream, no timer runs for a display that does not auto refresh or
///   that is nested in another live display (the outermost display owns
///   refreshing).
/// * The timer shares the throttle of update-driven refresh (`tick`): a
///   refresh is skipped if the display was refreshed less than
///   `1 / refresh_per_second` seconds ago.
/// * As upstream's refresh thread, a failing timer refresh stops the timer
///   but does not interrupt `body`.
async fn[X] with_refresher(live : @live.Live, body : async () -> X) -> X {
  @async.with_task_group(group => {
    if live.auto_refresh && !live.is_nested() {
      let interval_ms = @cmp.maximum(
        1,
        (1000.0 / live.refresh_per_second).to_int(),
      )
      group.spawn_bg(no_wait=true, allow_failure=true, () => {
        for ;; {
          let wait = live.time_until_refresh()
          if wait > 0.0 {
            // sleep until the shared throttle allows a refresh
            @async.sleep(@cmp.maximum(1, (wait * 1000.0).ceil().to_int()))
            continue
          }
          if !live.is_started() {
            break
          }
          live.refresh()
          @async.sleep(interval_ms)
        }
      })
    }
    body()
  })
}

///|
/// Run `body` with `live` started and refreshed from a timer (upstream
/// `with Live(...):`). The display is stopped when `body` returns or raises.
pub async fn[X] run_live(live : @live.Live, body : async () -> X) -> X {
  live.enter()
  let result = {
    errdefer live.stop()
    with_refresher(live, body)
  }
  live.stop()
  result
}

///|
/// Run `body` with the progress display started and refreshed from a timer
/// (upstream `with Progress(...):`).
pub async fn[X] run_progress(
  progress : @progress.Progress,
  body : async () -> X,
) -> X {
  progress.start()
  let result = {
    errdefer progress.stop()
    with_refresher(progress.live, body)
  }
  progress.stop()
  result
}

///|
/// Run `body` with the status spinner started and animated from a timer
/// (upstream `with console.status(...):`).
pub async fn[X] run_status(status : @status.Status, body : async () -> X) -> X {
  status.start()
  let result = {
    errdefer status.stop()
    with_refresher(status.live(), body)
  }
  status.stop()
  result
}

///|
/// Iterate over `items`, calling `body` for each, with a progress bar that
/// keeps refreshing while `body` suspends (an async `track`).
pub async fn[T] track(
  items : Array[T],
  body : async (T) -> Unit,
  description? : String = "Working...",
  progress? : @progress.Progress,
) -> Unit {
  let progress = match progress {
    Some(p) => p
    None => @progress.Progress::new()
  }
  run_progress(progress, () => {
    let task = progress.add_task(
      description,
      total=Some(items.length().to_double()),
    )
    for item in items {
      body(item)
      progress.advance(task)
      if !progress.live.auto_refresh {
        // upstream's non-threaded `track` refreshes after every item
        progress.refresh()
      }
    }
  })
}
