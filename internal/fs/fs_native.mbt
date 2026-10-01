///|
#borrow(path, ok)
extern "c" fn c_read_file(path : Bytes, ok : Ref[Int]) -> Bytes = "rich_fs_read_file"

///|
#borrow(path)
extern "c" fn c_exists(path : Bytes) -> Int = "rich_fs_exists"

///|
/// Read a whole file as UTF-8 text. `None` if it cannot be read.
pub fn read_file(path : String) -> String? {
  let ok : Ref[Int] = { val: 0, }
  let data = c_read_file(@utf8.encode(path + "\u{0}"), ok)
  if ok.val == 0 {
    return None
  }
  Some(@utf8.decode_lossy(data))
}

///|
/// Whether a path exists (file or directory).
pub fn exists(path : String) -> Bool {
  c_exists(@utf8.encode(path + "\u{0}")) != 0
}

///|
#borrow(path, data)
extern "c" fn c_write_file(path : Bytes, data : Bytes) -> Int = "rich_fs_write_file"

///|
#borrow(path)
extern "c" fn c_remove(path : Bytes) -> Int = "rich_fs_remove"

///|
/// Write `text` (UTF-8) to a file. Returns `false` on failure.
pub fn write_file(path : String, text : String) -> Bool {
  c_write_file(@utf8.encode(path + "\u{0}"), @utf8.encode(text)) == 0
}

///|
/// Remove a file. Returns `false` on failure.
pub fn remove_file(path : String) -> Bool {
  c_remove(@utf8.encode(path + "\u{0}")) == 0
}
