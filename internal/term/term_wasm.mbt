///|
let pending : StringBuilder = StringBuilder()

///|
/// Write a string to stdout/stderr. Only whole lines can be printed on this
/// target; incomplete lines are buffered until a newline or `flush_fd`.
pub fn write_fd(_fd : Int, text : String) -> Bool {
  pending.write_string(text)
  let s = pending.to_string()
  match s.rev_find("\n") {
    Some(i) => {
      println(s.view(end_offset=i).to_owned())
      pending.reset()
      pending.write_string(s.view(start_offset=i + 1).to_owned())
    }
    None => ()
  }
  true
}

///|
pub fn flush_fd(_fd : Int) -> Unit {
  let s = pending.to_string()
  if s != "" {
    println(s)
    pending.reset()
  }
}

///|
pub fn isatty(_fd : Int) -> Bool {
  false
}

///|
pub fn terminal_size(_fd : Int) -> (Int, Int)? {
  None
}

///|
pub fn monotonic() -> Double {
  @env.now().to_double() / 1000.0
}

///|
pub fn time() -> Double {
  @env.now().to_double() / 1000.0
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
