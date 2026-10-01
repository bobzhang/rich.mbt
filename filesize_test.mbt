// Port of tests/test_filesize.py.

///|
test "test_traditional" {
  assert_eq(@rich.filesize_decimal(0), "0 bytes")
  assert_eq(@rich.filesize_decimal(1), "1 byte")
  assert_eq(@rich.filesize_decimal(2), "2 bytes")
  assert_eq(@rich.filesize_decimal(1000), "1.0 kB")
  assert_eq(@rich.filesize_decimal(1500000), "1.5 MB")
  assert_eq(@rich.filesize_decimal(0, precision=2), "0 bytes")
  assert_eq(@rich.filesize_decimal(1111, precision=0), "1 kB")
  assert_eq(@rich.filesize_decimal(1111, precision=1), "1.1 kB")
  assert_eq(@rich.filesize_decimal(1111, precision=2), "1.11 kB")
  assert_eq(@rich.filesize_decimal(1111, separator=""), "1.1kB")
}

///|
test "test_pick_unit_and_suffix" {
  let units = ["bytes", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"]
  assert_eq(@rich.pick_unit_and_suffix(50, units, 1024), (1, "bytes"))
  assert_eq(@rich.pick_unit_and_suffix(2048, units, 1024), (1024, "KB"))
}

///|
test "filesize differential" {
  // computed with upstream rich.filesize.decimal
  assert_eq(@rich.filesize_decimal(999), "999 bytes")
  assert_eq(@rich.filesize_decimal(1234567), "1.2 MB")
  assert_eq(@rich.filesize_decimal(1234567890123), "1.2 TB")
  assert_eq(@rich.filesize_decimal(999999), "1,000.0 kB")
}
