///|
#borrow(data)
extern "c" fn c_write(fd : Int, data : Bytes) -> Int = "rich_term_write"

///|
extern "c" fn c_isatty(fd : Int) -> Int = "rich_term_isatty"

///|
extern "c" fn c_size(fd : Int) -> Int = "rich_term_size"

///|
extern "c" fn c_monotonic() -> Double = "rich_term_monotonic"

///|
extern "c" fn c_time() -> Double = "rich_term_time"

///|
extern "c" fn c_sleep(seconds : Double) = "rich_term_sleep"

///|
#borrow(fmt)
extern "c" fn c_strftime(fmt : Bytes, epoch : Double) -> Bytes = "rich_term_strftime"

///|
#borrow(eof)
extern "c" fn c_read_line(echo : Int, eof : Ref[Int]) -> Bytes = "rich_term_read_line"

///|
/// Write a string (UTF-8 encoded) to a file descriptor (1 = stdout,
/// 2 = stderr). Returns `false` on failure.
pub fn write_fd(fd : Int, text : String) -> Bool {
  c_write(fd, @utf8.encode(text)) == 0
}

///|
/// Flush a file descriptor (writes are unbuffered on native).
pub fn flush_fd(_fd : Int) -> Unit {
  ()
}

///|
/// Whether the file descriptor is a terminal.
pub fn isatty(fd : Int) -> Bool {
  c_isatty(fd) != 0
}

///|
/// Size of the terminal attached to the file descriptor, as
/// `(columns, rows)`.
pub fn terminal_size(fd : Int) -> (Int, Int)? {
  let v = c_size(fd)
  if v < 0 {
    None
  } else {
    Some(((v >> 16) & 0xffff, v & 0xffff))
  }
}

///|
/// Monotonic clock in seconds.
pub fn monotonic() -> Double {
  c_monotonic()
}

///|
/// Wall clock time in seconds since the epoch.
pub fn time() -> Double {
  c_time()
}

///|
/// Sleep for a number of seconds.
pub fn sleep(seconds : Double) -> Unit {
  c_sleep(seconds)
}

///|
/// Format a time (seconds since the epoch) in local time with C
/// `strftime`.
pub fn strftime(format : String, epoch : Double) -> String {
  let fmt = @utf8.encode(format + "\u{0}")
  @utf8.decode_lossy(c_strftime(fmt, epoch))
}

///|
/// Read a line from stdin (including the trailing newline), or `None` at
/// end of input. With `echo=false` the terminal does not echo the input.
pub fn read_line(echo? : Bool = true) -> String? {
  let eof = Ref(0)
  let bytes = c_read_line(if echo { 1 } else { 0 }, eof)
  if eof.val != 0 {
    None
  } else {
    Some(@utf8.decode_lossy(bytes))
  }
}

///|
#borrow(path, data)
extern "c" fn c_write_file(path : Bytes, data : Bytes) -> Int = "rich_term_write_file"

///|
#borrow(command, data)
extern "c" fn c_pipe_to(command : Bytes, data : Bytes) -> Int = "rich_term_pipe_to"

///|
/// Write `text` (UTF-8) to the file at `path`. Returns `false` on failure.
pub fn write_file(path : String, text : String) -> Bool {
  c_write_file(@utf8.encode(path + "\u{0}"), @utf8.encode(text)) == 0
}

///|
#borrow(path, ok)
extern "c" fn c_read_file(path : Bytes, ok : Ref[Int]) -> Bytes = "rich_term_read_file"

///|
/// Read the file at `path` (decoded as UTF-8), or `None` on failure.
pub fn read_file(path : String) -> String? {
  let ok = Ref(0)
  let bytes = c_read_file(@utf8.encode(path + "\u{0}"), ok)
  if ok.val == 0 {
    None
  } else {
    Some(@utf8.decode_lossy(bytes))
  }
}

///|
/// Pipe `text` to a shell command (e.g. a pager). Returns `false` if the
/// command could not be started.
pub fn pipe_to(command : String, text : String) -> Bool {
  c_pipe_to(@utf8.encode(command + "\u{0}"), @utf8.encode(text)) >= 0
}
