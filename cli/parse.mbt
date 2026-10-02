// Command line parsing with the behaviour (and error messages) of click's
// `OptionParser`, which rich-cli uses.

///|
/// The result of parsing the command line.
pub(all) enum Command {
  /// Render with these options.
  Run(Options)
  /// `--help`: show the help screen.
  Help
  /// A usage error (exit code 2). With `usage`, the message is preceded by
  /// the usage line and a hint to use `--help` (click's `UsageError.show`).
  UsageError(String, usage~ : Bool)
} derive(Debug)

///|
priv suberror ParseError {
  ParseError(String, Bool)
}

///|
fn find_param(opt : String) -> Param? {
  for param in params {
    if param.opts.contains(opt) {
      return Some(param)
    }
  }
  None
}

///|
/// click's `_split_opt`-based classification: `-x` is short, anything
/// else long.
fn is_short_opt(opt : String) -> Bool {
  opt.length() == 2 && opt.has_prefix("-") && !opt.has_prefix("--")
}

///|
fn long_opts() -> Array[String] {
  let out = []
  for param in params {
    for opt in param.opts {
      if !is_short_opt(opt) {
        out.push(opt)
      }
    }
  }
  out
}

///|
fn no_such_option(opt : String, possibilities? : Array[String]) -> ParseError {
  let message = "No such option \{@rich.py_repr(opt)}."
  let matches = match possibilities {
    Some(p) => get_close_matches(opt, p)
    None => []
  }
  if matches.is_empty() {
    return ParseError(message, true)
  }
  matches.sort_by(py_compare)
  let shown = matches.map(@rich.py_repr).join(", ")
  if matches.length() == 1 {
    ParseError("\{message} Did you mean \{shown}?", true)
  } else {
    ParseError("\{message} (Did you mean one of: \{shown}?)", true)
  }
}

///|
/// Parse the command line arguments (without the program name).
pub fn parse_args(
  args : ArrayView[String],
  environ? : Map[String, String],
) -> Command {
  parse(args, environ) catch {
    ParseError(message, usage) => UsageError(message, usage~)
  }
}

///|
fn parse(
  args : ArrayView[String],
  environ : Map[String, String]?,
) -> Command raise ParseError {
  let rargs = args.to_owned()
  rargs.rev_in_place()
  let positional : Array[String] = []
  // (param, value) in invocation order; the last value of a param wins
  let values : Map[String, String?] = Map([])
  let order : Array[Param] = []
  fn record(param : Param, value : String?) {
    if !values.contains(param.name) {
      order.push(param)
    }
    values[param.name] = value
  }

  fn take_value(opt : String) -> String raise ParseError {
    match rargs.pop() {
      Some(v) => v
      None =>
        raise ParseError(
          "Option \{@rich.py_repr(opt)} requires an argument.",
          false,
        )
    }
  }

  fn match_short(arg : String) -> Unit raise ParseError {
    let chars = arg.to_array()
    for i in 1..<chars.length() {
      let opt = "-\{chars[i]}"
      guard find_param(opt) is Some(param) && is_short_opt(opt) else {
        raise no_such_option(opt)
      }
      if param.takes_value() {
        if i + 1 < chars.length() {
          rargs.push(String::from_array(chars[i + 1:]))
        }
        record(param, Some(take_value(opt)))
        return
      }
      record(param, None)
    }
  }

  while rargs.pop() is Some(arg) {
    if arg == "--" {
      while rargs.pop() is Some(rest) {
        positional.push(rest)
      }
      break
    }
    if !(arg.has_prefix("-") && arg.length() > 1) {
      positional.push(arg)
      continue
    }
    let (long_opt, explicit_value) = match arg.find("=") {
      Some(i) =>
        (
          arg.view(end_offset=i).to_owned(),
          Some(arg.view(start_offset=i + 1).to_owned()),
        )
      None => (arg, None)
    }
    match find_param(long_opt) {
      Some(param) if !is_short_opt(long_opt) =>
        if param.takes_value() {
          if explicit_value is Some(v) {
            rargs.push(v)
          }
          record(param, Some(take_value(long_opt)))
        } else if explicit_value is Some(_) {
          raise ParseError(
            "Option \{@rich.py_repr(long_opt)} does not take a value.",
            false,
          )
        } else {
          record(param, None)
        }
      _ =>
        if arg.has_prefix("--") {
          raise no_such_option(long_opt, possibilities=long_opts())
        } else {
          match_short(arg)
        }
    }
  }
  // eager parameters first
  if values.contains("help") {
    return Help
  }
  let theme = match environ {
    Some(env) => env.get("RICH_THEME")
    None => @env.get_env_var("RICH_THEME")
  }
  let options = match theme {
    Some(theme) => Options::default(theme~)
    None => Options::default()
  }
  for param in order {
    let value = values[param.name]
    let hint = param.opts.map(@rich.py_repr).join(" / ")
    fn invalid(message : String) -> ParseError {
      ParseError("Invalid value for \{hint}: \{message}", true)
    }

    match (param.type_, value) {
      (Flag, _) => options.set_flag(param.name)
      (Str, Some(v)) => options.set_string(param.name, v)
      (Integer, Some(v)) =>
        match py_int(v) {
          Some(n) => options.set_int(param.name, n)
          None => raise invalid("\{@rich.py_repr(v)} is not a valid integer.")
        }
      (IntRange(min), Some(v)) =>
        match py_int(v) {
          Some(n) if n >= min => options.set_int(param.name, n)
          Some(n) => raise invalid("\{n} is not in the range x>=\{min}.")
          None => raise invalid("\{@rich.py_repr(v)} is not a valid integer.")
        }
      (Choice(choices), Some(v)) =>
        if choices.contains(v) {
          options.set_string(param.name, v)
        } else {
          let shown = choices.map(@rich.py_repr).join(", ")
          raise invalid("\{@rich.py_repr(v)} is not one of \{shown}.")
        }
      (_, None) => ()
    }
  }
  if positional.length() > 0 {
    options.resource = positional[0]
  }
  if positional.length() > 1 {
    let extra = positional[1:].to_owned()
    let s = if extra.length() == 1 { "" } else { "s" }
    raise ParseError(
      "Got unexpected extra argument\{s} (\{extra.join(" ")})",
      true,
    )
  }
  Run(options)
}

///|
/// Python's `int(text)` for decimal text: surrounding whitespace, a sign
/// and single underscores between digits are allowed.
fn py_int(text : String) -> Int? {
  let s = text.trim(chars=" \t\n\r\u{0b}\u{0c}").to_owned()
  let chars = s.to_array()
  let mut i = 0
  let mut negative = false
  if chars.length() > 0 && (chars[0] == '+' || chars[0] == '-') {
    negative = chars[0] == '-'
    i = 1
  }
  if i >= chars.length() {
    return None
  }
  let mut value = 0L
  let mut prev_digit = false
  while i < chars.length() {
    let c = chars[i]
    if c >= '0' && c <= '9' {
      value = value * 10L + (c.to_int() - '0'.to_int()).to_int64()
      if value > 0x7fffffffL {
        return None
      }
      prev_digit = true
    } else if c == '_' && prev_digit && i + 1 < chars.length() {
      prev_digit = false
    } else {
      return None
    }
    i += 1
  }
  if !prev_digit {
    return None
  }
  Some(if negative { -value.to_int() } else { value.to_int() })
}
