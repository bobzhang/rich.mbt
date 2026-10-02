// `rich`: port of Textualize's rich-cli. The rendering lives in
// `bobzhang/rich/cli`; this executable does the IO (arguments, files,
// standard input/output) with `moonbitlang/async`, on native and wasm.

///|
async fn main {
  let code = run(@env.args()[1:].to_owned()) catch {
    e => {
      @stdio.stderr.write("rich: \{e}\n")
      1
    }
  }
  @sys.exit(code)
}

///|
/// Python's `str(OSError)` for `open(path)`, e.g. `[Errno 2] No such file or
/// directory: 'x.py'`.
fn os_error_message(e : Error, path : String) -> String {
  match e {
    @os_error.OSError(errno, ..) as err => {
      let code = if err.is_ENOENT() {
        2
      } else if err.is_EACCES() {
        13
      } else {
        errno
      }
      "[Errno \{code}] \{strerror(err)}: \{@richlib.py_repr(path)}"
    }
    _ => e.to_string()
  }
}

///|
/// The system message of an `OSError` ("No such file or directory"): its
/// `to_string` renders `OSError("context: message")`.
fn strerror(e : @os_error.OSError) -> String {
  let s = e.to_string()
  let msg = match s.rev_find(": ") {
    Some(i) => s.view(start_offset=i + 2).to_owned()
    None => s
  }
  if msg.has_suffix("\")") {
    msg.view(end_offset=msg.length() - 2).to_owned()
  } else {
    msg
  }
}

///|
/// Read a file as UTF-8, replacing invalid bytes (like `open(path,
/// encoding="utf8", errors="replace")`).
async fn read_text(path : String) -> Result[String, String] {
  let data = @fs.read_file(path) catch {
    e => return Err(os_error_message(e, path))
  }
  Ok(@utf8.decode_lossy(data.binary()))
}

///|
async fn run(args : Array[String]) -> Int {
  let stdout_isatty = @term.isatty(1)
  let stderr_isatty = @term.isatty(2)
  let command = @cli.parse_args(args)
  let input = match command {
    Run(options) =>
      match options.input() {
        NoInput => None
        Stdin => Some(Ok(@utf8.decode_lossy(@stdio.stdin.read_all().binary())))
        File(path) => Some(read_text(path))
      }
    _ => None
  }
  let output = @cli.execute(command, input?, stdout_isatty~, stderr_isatty~)
  if output.stdout != "" {
    @stdio.stdout.write(output.stdout)
  }
  if output.stderr != "" {
    @stdio.stderr.write(output.stderr)
  }
  if output.pager is Some(text) {
    @richlib.SystemPager::new().show(text)
  }
  for exported in output.exports {
    @fs.write_file(
      exported.path,
      exported.contents,
      create_mode=CreateOrTruncate,
    ) catch {
      e => {
        @stdio.stderr.write(
          @cli.error_text(
            "failed to save \{exported.format}",
            error=os_error_message(e, exported.path),
            isatty=stderr_isatty,
          ),
        )
        return 255
      }
    }
  }
  output.exit_code
}
