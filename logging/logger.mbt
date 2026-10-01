// A minimal logger that creates `LogRecord`s and passes them to handlers
// (a small subset of Python's `logging.Logger`).

///|
/// A named logger with a level and a list of handlers.
pub(all) struct Logger {
  name : String
  /// Records below this level are discarded.
  mut level : Int
  handlers : Array[RichHandler]
  /// Clock for `LogRecord.created` (seconds since the epoch).
  mut get_time : () -> Double
}

///|
/// Create a logger. `get_time` defaults to the wall clock.
pub fn Logger::new(
  name? : String = "root",
  level? : Int = NOTSET,
  handlers? : Array[RichHandler] = [],
  get_time? : () -> Double = @term.time,
) -> Logger {
  { name, level, handlers, get_time, }
}

///|
/// Add a handler.
pub fn Logger::add_handler(self : Logger, handler : RichHandler) -> Unit {
  self.handlers.push(handler)
}

///|
/// Remove a handler (compared by identity).
pub fn Logger::remove_handler(self : Logger, handler : RichHandler) -> Unit {
  match self.handlers.search_by(h => physical_equal(h, handler)) {
    Some(i) => self.handlers.remove(i) |> ignore
    None => ()
  }
}

///|
/// Is this logger enabled for `level`?
pub fn Logger::is_enabled_for(self : Logger, level : Int) -> Bool {
  level >= self.level
}

///|
/// Pass a record to the handlers whose level allows it.
pub fn Logger::handle(self : Logger, record : LogRecord) -> Unit raise {
  for handler in self.handlers {
    handler.handle(record)
  }
}

///|
/// Split a `SourceLoc` (`path:line:col-line:col`) into `(path, line)`.
fn parse_source_loc(loc : SourceLoc) -> (String, Int) {
  let s = loc.to_string()
  let parts = s.split(":").map(p => p.to_owned()).collect()
  if parts.length() >= 4 {
    let path = parts[0:parts.length() - 3].to_owned().join(":")
    let line = @string.parse_int(parts[parts.length() - 3]) catch { _ => 0 }
    (path, line)
  } else {
    (s, 0)
  }
}

///|
/// Log `msg` with the given level. The path and line of the call are
/// recorded from the caller's source location.
#callsite(autofill(loc))
pub fn Logger::log(
  self : Logger,
  level : Int,
  msg : String,
  exc_text? : String,
  stack_info? : String,
  traceback? : &@rich.Renderable,
  markup? : Bool,
  highlighter? : &@rich.Highlighter,
  extra? : Map[String, String] = {},
  loc~ : SourceLoc,
) -> Unit raise {
  if !self.is_enabled_for(level) {
    return
  }
  let (pathname, lineno) = parse_source_loc(loc)
  let record = LogRecord::new(
    name=self.name,
    level,
    msg,
    pathname~,
    lineno~,
    created=(self.get_time)(),
    exc_text?,
    stack_info?,
    traceback?,
    markup?,
    highlighter?,
    extra~,
  )
  self.handle(record)
}

///|
/// Log a message with level `DEBUG`.
#callsite(autofill(loc))
pub fn Logger::debug(
  self : Logger,
  msg : String,
  markup? : Bool,
  highlighter? : &@rich.Highlighter,
  loc~ : SourceLoc,
) -> Unit raise {
  self.log(DEBUG, msg, markup?, highlighter?, loc~)
}

///|
/// Log a message with level `INFO`.
#callsite(autofill(loc))
pub fn Logger::info(
  self : Logger,
  msg : String,
  markup? : Bool,
  highlighter? : &@rich.Highlighter,
  loc~ : SourceLoc,
) -> Unit raise {
  self.log(INFO, msg, markup?, highlighter?, loc~)
}

///|
/// Log a message with level `WARNING`.
#callsite(autofill(loc))
pub fn Logger::warning(
  self : Logger,
  msg : String,
  markup? : Bool,
  highlighter? : &@rich.Highlighter,
  loc~ : SourceLoc,
) -> Unit raise {
  self.log(WARNING, msg, markup?, highlighter?, loc~)
}

///|
/// Log a message with level `ERROR`.
#callsite(autofill(loc))
pub fn Logger::error(
  self : Logger,
  msg : String,
  markup? : Bool,
  highlighter? : &@rich.Highlighter,
  loc~ : SourceLoc,
) -> Unit raise {
  self.log(ERROR, msg, markup?, highlighter?, loc~)
}

///|
/// Log a message with level `CRITICAL`.
#callsite(autofill(loc))
pub fn Logger::critical(
  self : Logger,
  msg : String,
  markup? : Bool,
  highlighter? : &@rich.Highlighter,
  loc~ : SourceLoc,
) -> Unit raise {
  self.log(CRITICAL, msg, markup?, highlighter?, loc~)
}

///|
/// Log a message with level `ERROR` and exception information: the
/// formatted exception text and/or a rich traceback renderable (upstream
/// `Logger.exception`, which takes them from `sys.exc_info()`).
#callsite(autofill(loc))
pub fn Logger::exception(
  self : Logger,
  msg : String,
  exc_text? : String,
  traceback? : &@rich.Renderable,
  markup? : Bool,
  highlighter? : &@rich.Highlighter,
  loc~ : SourceLoc,
) -> Unit raise {
  self.log(ERROR, msg, exc_text?, traceback?, markup?, highlighter?, loc~)
}
