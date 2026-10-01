// Port of tests/test_box.py.

///|
test "test_str" {
  assert_eq(
    @rich.box_ascii.to_string(),
    "+--+\n| ||\n|-+|\n| ||\n|-+|\n|-+|\n| ||\n+--+\n",
  )
}

///|
test "test_repr" {
  assert_eq(@rich.box_ascii.repr(), "Box(...)")
}

///|
test "test_get_top" {
  let top = @rich.box_heavy.get_top([1, 2])
  assert_eq(top, "┏━┳━━┓")
}

///|
test "test_get_row" {
  let head_row = @rich.box_double.get_row([3, 2, 1], level=Head)
  assert_eq(head_row, "╠═══╬══╬═╣")
  let row = @rich.box_ascii.get_row([1, 2, 3], level=Row)
  assert_eq(row, "|-+--+---|")
  let foot_row = @rich.box_rounded.get_row([2, 1, 3], level=Foot)
  assert_eq(foot_row, "├──┼─┼───┤")
  // upstream also checks that an invalid level raises ValueError; levels
  // are an enum here.
}

///|
test "test_get_bottom" {
  let bottom = @rich.box_heavy.get_bottom([1, 2, 3])
  assert_eq(bottom, "┗━┻━━┻━━━┛")
}

///|
fn box_options(
  legacy_windows~ : Bool,
  encoding~ : String,
) -> @rich.ConsoleOptions {
  {
    size: { width: 80, height: 25, },
    legacy_windows,
    min_width: 1,
    max_width: 100,
    is_terminal: true,
    encoding,
    max_height: 25,
    justify: None,
    overflow: None,
    no_wrap: Some(false),
    highlight: None,
    markup: None,
    height: None,
  }
}

///|
test "test_box_substitute_for_same_box" {
  let options = box_options(legacy_windows=false, encoding="utf-8")
  assert_eq(@rich.box_rounded.substitute(options), @rich.box_rounded)
  assert_eq(
    @rich.box_minimal_heavy_head.substitute(options),
    @rich.box_minimal_heavy_head,
  )
  assert_eq(@rich.box_simple_heavy.substitute(options), @rich.box_simple_heavy)
  assert_eq(@rich.box_heavy.substitute(options), @rich.box_heavy)
  assert_eq(@rich.box_heavy_edge.substitute(options), @rich.box_heavy_edge)
  assert_eq(@rich.box_heavy_head.substitute(options), @rich.box_heavy_head)
}

///|
test "test_box_substitute_for_different_box_legacy_windows" {
  let options = box_options(legacy_windows=true, encoding="utf-8")
  assert_eq(@rich.box_rounded.substitute(options), @rich.box_square)
  assert_eq(@rich.box_minimal_heavy_head.substitute(options), @rich.box_minimal)
  assert_eq(@rich.box_simple_heavy.substitute(options), @rich.box_simple)
  assert_eq(@rich.box_heavy.substitute(options), @rich.box_square)
  assert_eq(@rich.box_heavy_edge.substitute(options), @rich.box_square)
  assert_eq(@rich.box_heavy_head.substitute(options), @rich.box_square)
}

///|
test "test_box_substitute_for_different_box_ascii_encoding" {
  let options = box_options(legacy_windows=true, encoding="ascii")
  assert_eq(@rich.box_rounded.substitute(options), @rich.box_ascii)
  assert_eq(@rich.box_minimal_heavy_head.substitute(options), @rich.box_ascii)
  assert_eq(@rich.box_simple_heavy.substitute(options), @rich.box_ascii)
  assert_eq(@rich.box_heavy.substitute(options), @rich.box_ascii)
  assert_eq(@rich.box_heavy_edge.substitute(options), @rich.box_ascii)
  assert_eq(@rich.box_heavy_head.substitute(options), @rich.box_ascii)
}
