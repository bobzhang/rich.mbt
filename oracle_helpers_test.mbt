// Helpers for the differential tests.

///|
/// Replace each `(from, to)` pair in `s` (times rendered in UTC by the
/// oracle and in local time here).
fn replace_times(s : String, pairs : Array[(String, String)]) -> String {
  let mut s = s
  for pair in pairs {
    s = s.replace_all(old=pair.0, new=pair.1)
  }
  s
}

///|
/// Replace the (random) ids of OSC 8 hyperlinks, `id=<digits>;`, by `id=0;`.
fn normalize_link_ids(s : String) -> String {
  let buf = StringBuilder()
  let n = s.length()
  let mut i = 0
  while i < n {
    if s.view(start_offset=i).has_prefix("id=") {
      let mut j = i + 3
      while j < n && s[j] >= '0' && s[j] <= '9' {
        j += 1
      }
      if j > i + 3 && j < n && s[j] == ';' {
        buf.write_string("id=0;")
        i = j + 1
        continue
      }
    }
    buf.write_char(s[i].to_int().unsafe_to_char())
    i += 1
  }
  buf.to_string()
}
