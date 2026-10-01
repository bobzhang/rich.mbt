// Port of rich/filesize.py.

///|
fn filesize_to_str(
  size : Int64,
  suffixes : Array[String],
  base : Int64,
  precision : Int,
  separator : String,
) -> String {
  if size == 1L {
    return "1 byte"
  } else if size < base {
    return "\{py_group_thousands(size.to_string())} bytes"
  }
  let mut unit = base
  let mut suffix = suffixes[0]
  for i, s in suffixes {
    unit = 1L
    for _ in 0..<(i + 2) {
      unit = unit * base
    }
    suffix = s
    if size < unit {
      break
    }
  }
  let value = base.to_double() * size.to_double() / unit.to_double()
  py_group_thousands(py_format_fixed(value, precision)) + separator + suffix
}

///|
/// Pick a suffix and base for the given size.
pub fn pick_unit_and_suffix(
  size : Int64,
  suffixes : Array[String],
  base : Int64,
) -> (Int64, String) {
  let mut unit = 1L
  let mut suffix = suffixes[0]
  for i, s in suffixes {
    unit = 1L
    for _ in 0..<i {
      unit = unit * base
    }
    suffix = s
    if size < unit * base {
      break
    }
  }
  (unit, suffix)
}

///|
/// Convert a filesize in to a string (powers of 1000, SI prefixes), e.g.
/// `30.0 kB`.
pub fn filesize_decimal(
  size : Int64,
  precision? : Int = 1,
  separator? : String = " ",
) -> String {
  filesize_to_str(
    size,
    ["kB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"],
    1000L,
    precision,
    separator,
  )
}
