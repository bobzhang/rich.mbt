///|
fn pad2(n : Int) -> String {
  if n < 10 {
    "0\{n}"
  } else {
    n.to_string()
  }
}

///|
/// A portable `strftime` (UTC) supporting `%H %M %S %X %Y %m %d %%`.
fn utc_strftime(format : String, epoch : Double) -> String {
  let secs = epoch.floor().to_int64()
  let days = (secs / 86400L).to_int()
  let rem = (secs % 86400L).to_int()
  let hour = rem / 3600
  let minute = rem % 3600 / 60
  let second = rem % 60
  // civil from days (Howard Hinnant)
  let z = days + 719468
  let era = (if z >= 0 { z } else { z - 146096 }) / 146097
  let doe = z - era * 146097
  let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
  let y = yoe + era * 400
  let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
  let mp = (5 * doy + 2) / 153
  let d = doy - (153 * mp + 2) / 5 + 1
  let m = if mp < 10 { mp + 3 } else { mp - 9 }
  let year = if m <= 2 { y + 1 } else { y }
  let buf = StringBuilder()
  let mut i = 0
  while i < format.length() {
    let c = format[i]
    if c == '%' && i + 1 < format.length() {
      match format[i + 1] {
        'H' => buf.write_string(pad2(hour))
        'M' => buf.write_string(pad2(minute))
        'S' => buf.write_string(pad2(second))
        'X' => buf.write_string("\{pad2(hour)}:\{pad2(minute)}:\{pad2(second)}")
        'Y' => buf.write_string(year.to_string())
        'm' => buf.write_string(pad2(m))
        'd' => buf.write_string(pad2(d))
        '%' => buf.write_char('%')
        other => {
          buf.write_char('%')
          buf.write_char(other.to_int().unsafe_to_char())
        }
      }
      i += 2
    } else {
      buf.write_char(c.to_int().unsafe_to_char())
      i += 1
    }
  }
  buf.to_string()
}
