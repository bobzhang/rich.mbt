// Port of rich/logging.py.

///|
/// The words highlighted by default (upstream `RichHandler.KEYWORDS`).
pub let default_keywords : Array[String] = [
  "GET", "POST", "HEAD", "PUT", "DELETE", "OPTIONS", "TRACE", "PATCH",
]

///|
/// A logging handler that renders output with Rich. The time / level /
/// message and file are displayed in columns. The level is color coded, and
/// the message is syntax highlighted.
///
/// Be careful when enabling console markup in log messages if you log
/// messages you do not control: square brackets may not produce the intended
/// output.
pub(all) struct RichHandler {
  /// Records below this level are ignored by `handle`.
  mut level : Int
  mut console : @rich.Console
  mut highlighter : &@rich.Highlighter
  priv log_render : @rich.LogRender
  mut enable_link_path : Bool
  mut markup : Bool
  mut rich_tracebacks : Bool
  /// Words to highlight, or `None` for `default_keywords`.
  mut keywords : Array[String]?
  /// Optional formatter (upstream `Handler.setFormatter`).
  mut formatter : Formatter?
}

///|
/// Create a handler.
///
/// * `console`: the console to write logs to; defaults to the global console.
/// * `show_time`, `omit_repeated_times`, `show_level`, `show_path`: columns.
/// * `enable_link_path`: link the path column to the file.
/// * `highlighter`: highlights messages; defaults to `ReprHighlighter`.
/// * `markup`: enable console markup in log messages.
/// * `rich_tracebacks`: render the `traceback` renderable of records (see
///   `LogRecord`) below the message instead of the formatted `exc_text`.
/// * `log_time_format`: `strftime` format of the time column;
///   `log_time_formatter` formats the time (seconds since the epoch)
///   instead (upstream accepts a callable as `log_time_format`).
/// * `keywords`: words to highlight instead of `default_keywords`.
pub fn RichHandler::new(
  level? : Int = NOTSET,
  console? : @rich.Console,
  show_time? : Bool = true,
  omit_repeated_times? : Bool = true,
  show_level? : Bool = true,
  show_path? : Bool = true,
  enable_link_path? : Bool = true,
  highlighter? : &@rich.Highlighter,
  markup? : Bool = false,
  rich_tracebacks? : Bool = false,
  log_time_format? : String = "[%x %X]",
  log_time_formatter? : (Double) -> @rich.Text,
  keywords? : Array[String],
  formatter? : Formatter,
) -> RichHandler {
  let console = match console {
    Some(c) => c
    None => @rich.get_console()
  }
  let highlighter : &@rich.Highlighter = match highlighter {
    Some(h) => h
    None => @rich.ReprHighlighter::new()
  }
  {
    level,
    console,
    highlighter,
    log_render: @rich.LogRender::new(
      show_time~,
      show_level~,
      show_path~,
      time_format=log_time_format,
      time_formatter?=log_time_formatter,
      omit_repeated_times~,
      level_width=None,
    ),
    enable_link_path,
    markup,
    rich_tracebacks,
    keywords,
    formatter,
  }
}

///|
/// Set the formatter (upstream `Handler.setFormatter`).
pub fn RichHandler::set_formatter(
  self : RichHandler,
  formatter : Formatter?,
) -> Unit {
  self.formatter = formatter
}

///|
/// Get the level name from the record, padded to 8 characters and styled
/// with `logging.level.<name>`.
pub fn RichHandler::get_level_text(
  self : RichHandler,
  record : LogRecord,
) -> @rich.Text {
  ignore(self)
  let level_name = record.levelname
  let len = level_name.char_length()
  let padded = if len < 8 {
    level_name + " ".repeat(8 - len)
  } else {
    level_name
  }
  @rich.Text::styled(padded, style="logging.level.\{@pystr.lower(level_name)}")
}

///|
/// Format the record with the handler's formatter, or with
/// `Formatter::new()` when it has none (upstream `Handler.format`).
pub fn RichHandler::format(
  self : RichHandler,
  record : LogRecord,
) -> String raise @rich.RichError {
  match self.formatter {
    Some(f) => f.format(record)
    None => Formatter::new().format(record)
  }
}

///|
/// Handle a record: emit it if its level is at least the handler's level.
pub fn RichHandler::handle(
  self : RichHandler,
  record : LogRecord,
) -> Unit raise {
  if record.levelno >= self.level {
    self.emit(record)
  }
}

///|
/// Render the record and print it to the console.
pub fn RichHandler::emit(self : RichHandler, record : LogRecord) -> Unit raise {
  let mut message = self.format(record)
  let mut traceback : &@rich.Renderable? = None
  if self.rich_tracebacks && record.traceback is Some(tb) {
    traceback = Some(tb)
    message = record.get_message()
    if self.formatter is Some(formatter) {
      message = formatter.format_message(record)
    }
  }
  let message_renderable = self.render_message(record, message)
  let log_renderable = self.render(record~, traceback?, message_renderable~)
  self.console.print(log_renderable)
}

///|
/// Render message text in to Text: markup (if enabled for the handler or
/// the record), highlighting and keywords.
pub fn RichHandler::render_message(
  self : RichHandler,
  record : LogRecord,
  message : String,
) -> @rich.Text raise {
  let use_markup = record.markup.unwrap_or(self.markup)
  let mut message_text = if use_markup {
    @rich.Text::from_markup(message)
  } else {
    @rich.Text::new(text=message)
  }
  let highlighter = match record.highlighter {
    Some(h) => h
    None => self.highlighter
  }
  message_text = highlighter.apply(message_text)
  if self.keywords is None {
    self.keywords = Some(default_keywords)
  }
  if self.keywords is Some(keywords) && keywords.length() > 0 {
    message_text.highlight_words(keywords, "logging.keyword") |> ignore
  }
  message_text
}

///|
/// Render log for display: a grid with the time, level, message (and
/// traceback) and path columns.
pub fn RichHandler::render(
  self : RichHandler,
  record~ : LogRecord,
  traceback? : &@rich.Renderable,
  message_renderable~ : &@rich.Renderable,
) -> @rich.Table raise {
  let path = record.filename()
  let level = self.get_level_text(record)
  let time_format = match self.formatter {
    Some({ datefmt: Some(d), .. }) if d != "" => Some(d)
    _ => None
  }
  let renderables : Array[&@rich.Renderable] = match traceback {
    Some(tb) => [message_renderable, tb]
    None => [message_renderable]
  }
  self.log_render.render(
    self.console,
    renderables,
    log_time=record.created,
    time_format?,
    level~,
    path~,
    line_no=record.lineno,
    link_path?=if self.enable_link_path { Some(record.pathname) } else { None },
  )
}
