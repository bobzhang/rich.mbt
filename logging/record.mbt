// A replacement for Python's `logging.LogRecord` and the level table of the
// `logging` module.

///|
pub const CRITICAL : Int = 50

///|
pub const FATAL : Int = 50

///|
pub const ERROR : Int = 40

///|
pub const WARNING : Int = 30

///|
pub const WARN : Int = 30

///|
pub const INFO : Int = 20

///|
pub const DEBUG : Int = 10

///|
pub const NOTSET : Int = 0

///|
/// The name of a level (Python `logging.getLevelName`): `"Level n"` for
/// levels without a name.
pub fn get_level_name(level : Int) -> String {
  match level {
    50 => "CRITICAL"
    40 => "ERROR"
    30 => "WARNING"
    20 => "INFO"
    10 => "DEBUG"
    0 => "NOTSET"
    n => "Level \{n}"
  }
}

///|
/// The level of a level name (`"INFO"`, `"WARN"`, ...), or `None`.
pub fn level_from_name(name : String) -> Int? {
  match name {
    "CRITICAL" | "FATAL" => Some(CRITICAL)
    "ERROR" => Some(ERROR)
    "WARNING" | "WARN" => Some(WARNING)
    "INFO" => Some(INFO)
    "DEBUG" => Some(DEBUG)
    "NOTSET" => Some(NOTSET)
    _ => None
  }
}

///|
/// A log event (Python `logging.LogRecord`).
///
/// * `msg` is the message with its arguments already interpolated (Python
///   `record.getMessage()`).
/// * `exc_text` is the formatted exception (appended to the message by
///   `Formatter::format`); `traceback` is a rich renderable of the exception
///   (typically a `@traceback.Traceback`) used instead when the handler has
///   `rich_tracebacks` enabled (upstream builds it from `exc_info`).
/// * `markup` and `highlighter` override the handler's settings for this
///   record (upstream `extra={"markup": ..., "highlighter": ...}`); pass a
///   `@rich.NullHighlighter` to disable highlighting (`"highlighter": None`).
/// * `extra` holds other attributes that formatters may reference.
pub(all) struct LogRecord {
  name : String
  msg : String
  levelno : Int
  levelname : String
  pathname : String
  lineno : Int
  func_name : String
  created : Double
  exc_text : String?
  stack_info : String?
  traceback : &@rich.Renderable?
  markup : Bool?
  highlighter : &@rich.Highlighter?
  extra : Map[String, String]
}

///|
/// Create a log record. `created` defaults to the current time (seconds
/// since the epoch); `levelname` is derived from `level`.
pub fn LogRecord::new(
  name? : String = "root",
  level : Int,
  msg : String,
  pathname? : String = "",
  lineno? : Int = 0,
  func_name? : String = "",
  created? : Double,
  exc_text? : String,
  stack_info? : String,
  traceback? : &@rich.Renderable,
  markup? : Bool,
  highlighter? : &@rich.Highlighter,
  extra? : Map[String, String] = {},
) -> LogRecord {
  {
    name,
    msg,
    levelno: level,
    levelname: get_level_name(level),
    pathname,
    lineno,
    func_name,
    created: match created {
      Some(t) => t
      None => @term.time()
    },
    exc_text,
    stack_info,
    traceback,
    markup,
    highlighter,
    extra,
  }
}

///|
/// The message of the record (Python `getMessage`).
pub fn LogRecord::get_message(self : LogRecord) -> String {
  self.msg
}

///|
/// The base name of `pathname` (Python `record.filename`).
pub fn LogRecord::filename(self : LogRecord) -> String {
  basename(self.pathname)
}

///|
/// The file name without its extension (Python `record.module`).
pub fn LogRecord::module_(self : LogRecord) -> String {
  let filename = self.filename()
  match filename.rev_find(".") {
    Some(i) => filename.view(end_offset=i).to_owned()
    None => filename
  }
}

///|
/// The millisecond part of the creation time (Python `record.msecs`).
pub fn LogRecord::msecs(self : LogRecord) -> Int {
  let frac = self.created - self.created.floor()
  (frac * 1000.0).floor().to_int()
}

///|
/// Python `os.path.basename`.
fn basename(path : String) -> String {
  match path.rev_find("/") {
    Some(i) => path.view(start_offset=i + 1).to_owned()
    None => path
  }
}
