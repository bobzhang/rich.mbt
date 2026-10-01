///|
/// Read a whole file as UTF-8 text (not available on this backend).
pub fn read_file(_path : String) -> String? {
  None
}

///|
/// Whether a path exists (always `false` on this backend).
pub fn exists(_path : String) -> Bool {
  false
}

///|
/// Write a file (not available on this backend).
pub fn write_file(_path : String, _text : String) -> Bool {
  false
}

///|
/// Remove a file (not available on this backend).
pub fn remove_file(_path : String) -> Bool {
  false
}
