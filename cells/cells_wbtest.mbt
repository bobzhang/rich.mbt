///|
/// Upstream `_SINGLE_CELL_UNICODE_RANGES` (rich/cells.py).
let single_cell_ranges : FixedArray[(Int, Int)] = [
  (0x20, 0x7E),
  (0xA0, 0xAC),
  (0xAE, 0x002FF),
  (0x00370, 0x00482),
  (0x02500, 0x025FC),
  (0x02800, 0x028FF),
]

///|
test "is_single_cell_char is the single-cell ranges" {
  for cp in 0..<0x3000 {
    let expected = single_cell_ranges.iter().any(r => cp >= r.0 && cp <= r.1)
    assert_eq(is_single_cell_char(cp), expected)
  }
}

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
