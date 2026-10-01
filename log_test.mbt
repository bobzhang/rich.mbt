// Port of tests/test_log.py.
//
// `render_log` / `test_log` are ported (without `log_locals`, which is not
// supported) in log_oracle_test.mbt ("log oracle render_log"), because the
// expected output contains the source path and line numbers of the calls.
// `test_log_caller_frame_info` tests a Python frame helper.

///|
test "test_justify" {
  let console = @rich.Console::new(
    width=20,
    log_path=false,
    log_time=false,
    color_system=None,
    environ={},
  )
  console.begin_capture()
  console.log("foo", justify=Right)
  let result = console.end_capture()
  assert_eq(result, "                 foo\n")
}
