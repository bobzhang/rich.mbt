///|
extern "js" fn js_write(fd : Int, text : String) -> Bool =
  #|(fd, text) => {
  #|  try {
  #|    if (typeof process !== "undefined" && process.stdout) {
  #|      (fd === 2 ? process.stderr : process.stdout).write(text);
  #|      return true;
  #|    }
  #|  } catch (e) {}
  #|  console.log(text);
  #|  return true;
  #|}

///|
extern "js" fn js_isatty(fd : Int) -> Bool =
  #|(fd) => {
  #|  try {
  #|    const s = fd === 2 ? process.stderr : process.stdout;
  #|    return !!(s && s.isTTY);
  #|  } catch (e) { return false; }
  #|}

///|
extern "js" fn js_columns(fd : Int) -> Int =
  #|(fd) => {
  #|  try {
  #|    const s = fd === 2 ? process.stderr : process.stdout;
  #|    return s && s.columns ? s.columns : -1;
  #|  } catch (e) { return -1; }
  #|}

///|
extern "js" fn js_rows(fd : Int) -> Int =
  #|(fd) => {
  #|  try {
  #|    const s = fd === 2 ? process.stderr : process.stdout;
  #|    return s && s.rows ? s.rows : -1;
  #|  } catch (e) { return -1; }
  #|}

///|
extern "js" fn js_monotonic() -> Double =
  #|() => (typeof performance !== "undefined" ? performance.now() : Date.now()) / 1000

///|
extern "js" fn js_time() -> Double =
  #|() => Date.now() / 1000

///|
pub fn write_fd(fd : Int, text : String) -> Bool {
  js_write(fd, text)
}

///|
pub fn flush_fd(_fd : Int) -> Unit {
  ()
}

///|
pub fn isatty(fd : Int) -> Bool {
  js_isatty(fd)
}

///|
pub fn terminal_size(fd : Int) -> (Int, Int)? {
  let c = js_columns(fd)
  let r = js_rows(fd)
  if c < 0 || r < 0 {
    None
  } else {
    Some((c, r))
  }
}

///|
pub fn monotonic() -> Double {
  js_monotonic()
}

///|
pub fn time() -> Double {
  js_time()
}

///|
pub fn sleep(_seconds : Double) -> Unit {
  ()
}

///|
pub fn strftime(format : String, epoch : Double) -> String {
  utc_strftime(format, epoch)
}

///|
pub fn read_line(echo? : Bool = true) -> String? {
  ignore(echo)
  None
}

///|
pub fn write_file(_path : String, _text : String) -> Bool {
  false
}

///|
pub fn pipe_to(_command : String, _text : String) -> Bool {
  false
}
