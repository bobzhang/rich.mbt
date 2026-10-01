// Port of rich/_log_render.py.

///|
/// Renders the layout of `Console.log` (and `RichHandler`).
pub struct LogRender {
  show_time : Bool
  show_level : Bool
  show_path : Bool
  time_format : String
  time_formatter : ((Double) -> Text)?
  omit_repeated_times : Bool
  level_width : Int?
  priv mut last_time : Text?
}

///|
/// `time_format` is a C `strftime` format; `time_formatter` overrides it
/// with a function from the time (seconds since the epoch) to a Text.
pub fn LogRender::new(
  show_time? : Bool = true,
  show_level? : Bool = false,
  show_path? : Bool = true,
  time_format? : String = "[%x %X]",
  time_formatter? : (Double) -> Text,
  omit_repeated_times? : Bool = true,
  level_width? : Int? = Some(8),
) -> LogRender {
  {
    show_time,
    show_level,
    show_path,
    time_format,
    time_formatter,
    omit_repeated_times,
    level_width,
    last_time: None,
  }
}

///|
/// Build the log line as a grid table.
pub fn LogRender::render(
  self : LogRender,
  console : Console,
  renderables : Array[&Renderable],
  log_time? : Double,
  time_format? : String,
  level? : &IntoText,
  path? : String,
  line_no? : Int,
  link_path? : String,
) -> Table raise {
  let output = Table::grid(padding=[0, 1])
  output.set_expand(true)
  if self.show_time {
    output.add_column(style="log.time")
  }
  if self.show_level {
    output.add_column(style="log.level", width?=self.level_width)
  }
  output.add_column(ratio=1, style="log.message", overflow=Fold)
  let path = match path {
    Some(p) if p != "" => Some(p)
    _ => None
  }
  if self.show_path && path is Some(_) {
    output.add_column(style="log.path")
  }
  let row : Array[&Renderable] = []
  if self.show_time {
    let log_time = match log_time {
      Some(t) => t
      None => (console.get_datetime)()
    }
    let log_time_display = match self.time_formatter {
      Some(f) if time_format is None => f(log_time)
      _ =>
        Text::new(
          text=@term.strftime(time_format.unwrap_or(self.time_format), log_time),
        )
    }
    if self.last_time is Some(last) &&
      last == log_time_display &&
      self.omit_repeated_times {
      row.push(Text::new(text=" ".repeat(log_time_display.length())))
    } else {
      row.push(log_time_display)
      self.last_time = Some(log_time_display)
    }
  }
  if self.show_level {
    match level {
      Some(l) =>
        match l.into_text_type() {
          Str(s) => row.push(s)
          Text(t) => row.push(t)
        }
      None => row.push("")
    }
  }
  row.push(Renderables::new(renderables~))
  if self.show_path && path is Some(path) {
    let path_text = Text::new()
    path_text.append_str(
      path,
      style=match link_path {
        Some(lp) => "link file://\{lp}"
        None => ""
      },
    )
    |> ignore
    if line_no is Some(line_no) && line_no != 0 {
      path_text.append_str(":") |> ignore
      path_text.append_str(
        "\{line_no}",
        style=match link_path {
          Some(lp) => "link file://\{lp}#\{line_no}"
          None => ""
        },
      )
      |> ignore
    }
    row.push(path_text)
  }
  output.add_row(row)
  output
}
