///|
test "single-cell ranges are one cell wide in every table" {
  // `cell_size_in` answers 1 for these code points without a table lookup
  for version in unicode_versions() {
    let table = load(unicode_version=version)
    for range in single_cell_ranges {
      for cp in range.0..<=range.1 {
        assert_eq(table_lookup(table, cp), 1)
      }
    }
  }
}
