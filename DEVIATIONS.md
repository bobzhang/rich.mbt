# Deviations from upstream Rich

Intentional differences between rich.mbt and Rich 15.0.0, by module.

## General

* Offsets into strings (spans, `Text.length()`, `divide`, regex matches) are
  UTF-16 code units, not code points. Identical for text without astral
  characters (most emoji are astral).
* `__rich__` is not supported: implement `Renderable` instead. Arbitrary
  non-renderable values cannot be printed; wrap them (`@pretty.Pretty`) or
  format them as strings.
* `Console.print(*objects)` → `print(object)` and `print_many(objects)`.
* No Jupyter, no legacy Windows console API (`legacy_windows` only affects
  layout), no `file_proxy` redirection, no `inspect`.

## style

* Upstream caches the ANSI codes of a style for the first color system it
  is rendered with, so a style shared between consoles with different color
  systems renders with the wrong codes (upstream bug). rich.mbt caches per
  color system.
* Meta data is a `Map[String, Json]` (upstream pickles arbitrary values).
* Link ids are generated from a counter seeded with the clock.

## markup

* Emoji variants (`emoji_variant`) are also applied to emoji inside markup
  (upstream only applies them when the text contains no markup).
* `[@handler(...)]` parameters are parsed by a subset of Python's
  `literal_eval` (numbers, strings, tuples, lists, dicts, True/False/None)
  and stored as JSON.

## console

* `log` reports the MoonBit source location (`SourceLoc`) of the call;
  `log_locals` is not supported.
* `status`, `print_exception` and `pager` are functions of the `status` /
  `traceback` packages or take closures (`console.pager(fn() { ... })`).
* Contexts (`capture`, `use_theme`, `screen`, `pager`) take closures.
  `console.screen(f)` passes the `ScreenContext` to `f` (`screen.update(...)`);
  `console.screen_context()` returns it for manual `enter()` / `exit()`.
* `input` reads from stdin via the native runtime (not available on wasm/js).
* `out(*objects, sep=...)` → `out(text)` and `out_many(texts, sep=...)`.
* A callable `log_time_format` is passed as `log_time_formatter`.
* `get_datetime` returns seconds since the epoch; `log` formats it in local
  time with C `strftime` (UTC `%H %M %S %X %Y %m %d` only on js/wasm).
* The link of the path in `log` output is `file://` + the path reported by
  `SourceLoc` (package relative), not an absolute path.
* `reconfigure` takes a `Console` (upstream takes `Console` arguments and
  updates the global console in place).
* Export templates (`code_format`) are filled by `py_format`, which supports
  `{name}`, `{name!r}` and string format specs (fill, alignment, width,
  precision); all fields are pre-formatted strings, so numeric specs such
  as `{char_width:.1f}` are not supported.
* Tests not ported from tests/test_console.py: `test_size_can_fall_back_to_std_descriptors`
  (mocks `os.get_terminal_size`), `test_console_null_file` (no
  `sys.stdout` to replace), `test_input` / `test_input_password` (stdin),
  `test_print_json_error`, `test_render_error`,
  `test_render_broken_renderable` (statically typed), `test_unicode_error`
  (files are always UTF-8), `test_is_terminal_broken_file` (`isatty` cannot
  raise), `test_brokenpipeerror` (runs `python -m rich`). The parametrized
  `test_force_color` is shadowed by a second definition upstream and never
  runs, so only the second one is ported.
* Pending: `test_status` needs the `status` package.

## log

* Not ported from tests/test_log.py: `log_locals=True` (not supported) and
  `test_log_caller_frame_info` (Python frames); `render_log` without the
  locals panel is in log_oracle_test.mbt.

## table, box, align, rule, measure, padding, control

* Invalid enum arguments (`align="foo"`, `level="FOO"`, `vertical=...`) are
  type errors, so the upstream `ValueError` tests (`test_bad_align_legal`,
  `test_rule_error`, the invalid `get_row` level) are not ported; neither
  are `test_not_renderable` (tables) and `test_no_renderable` (measure).
* `Table::add_row` takes renderables; upstream's `None` cell is `""`.
* Boxes compare structurally (`derive(Eq)`); upstream compares identity.
* `test_control_move` is not ported: any use of `Control::move` triggers
  the `reserved_keyword` warning.

## protocol

* Not ported from tests/test_protocol.py: `test_rich_cast_fake` (repr of an
  arbitrary object), `test_abc` (isinstance checks), `test_cast_recursive`
  (an infinite `__rich__` chain). `__rich__` is replaced by implementing
  `Renderable` (and `rich_measure`) by delegation.

## json

* `JSON::from_data` takes a MoonBit `Json`; numbers without a textual
  representation are printed as integers when integral. There is no
  `default` callable (tests/test_json.py is ported with the converted
  value), nor `skip_keys` / `check_circular` / `allow_nan`.
