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
  `repr` shows it as a Python dict (integral numbers as ints, arrays as
  lists).
* Link ids are generated from a counter seeded with the clock.
* `Style::new(color=..., bgcolor=...)` takes `@color.Color` values, not
  color strings (use `Style::parse` or `@color.Color::parse`).
* `update_link` and `clear_meta_and_links` do not reuse the cached style
  definition (upstream copies `_style_definition`, so `str()` of the result
  can show a stale or missing link depending on whether `str()` was called
  on the source style before).
* `Style.test()` (writes to stdout) is not ported; skipped tests:
  `test_test`, `test_clear_meta_and_links_clears_hash` (Python hash caching),
  and the `NotImplemented` checks of `test_eq`.

## markup

* `[@handler(...)]` parameters are parsed by a subset of Python's
  `literal_eval` (numbers, strings, bytes, tuples, lists, sets, dicts,
  True/False/None, unary +/-) and stored as JSON, so tuples become arrays
  (`('close', ())` is `["close", []]`). Complex numbers, f-strings,
  keyword arguments and integers beyond 64 bits are not supported; error
  messages follow upstream (`SyntaxError` / `malformed node` with the AST
  dump) for the supported grammar.

## console

* `log` reports the MoonBit source location (`SourceLoc`) of the call;
  `log_locals` is not supported.
* `status`, `print_exception` and `pager` are functions of the `status` /
  `traceback` packages or take closures (`console.pager(fn() { ... })`).
* Contexts (`capture`, `use_theme`, `screen`, `pager`) take closures.
* `input` reads from stdin via the native runtime (not available on wasm/js).

## json

* `JSON::from_data` takes a MoonBit `Json`; numbers without a textual
  representation are printed as integers when integral.

## text

* Lengths and offsets are UTF-16 (see General). `Text::rstrip_end` (used by
  `wrap`) compares the length in code points with the cell width, as
  upstream does, so wrapping text with emoji matches upstream. `pad*` move
  spans by the UTF-16 length of the padding; `with_indent_guides` slices
  lines by the code point length of the new indent (as upstream).
* `text[i]` / `text[a:b]` are `Text::at(i)` / `Text::slice(start?, stop?)`;
  slices with a step are not supported (upstream raises `TypeError`).
* `text + other` is `Add` for `Text` and `Text::concat` for strings; the
  `NotImplemented` / `TypeError` checks of `test_add`, `test_eq`,
  `test_contain` and `test_append` have no MoonBit equivalent (the type
  system rejects such calls).
* `highlight_regex` takes a compiled regex (`compile_regex`) and the style
  callable is the separate `style_fn` argument; `highlight_pattern` takes a
  pattern string.
* `Text::on(meta?, handlers?)` / `Style::on`: handler keyword arguments are
  a map.

## segment

* `Segment::is_control` is upstream's `control is not None`; the helpers
  that test the truthiness of `control` (`cell_length`, `split_lines`,
  `simplify`, `divide`, ...) use `Segment::has_codes`.
* Segment styles must be `Style`s (upstream tests use arbitrary objects such
  as `"foo"`; the port substitutes real styles).

## color renderables

* Upstream `Color.__rich__` / `Palette.__rich__` are `color_to_text` /
  `palette_to_table`, and `@color.Color` / `@color.Palette` implement
  `Renderable` with them.
* `parse_rgb_hex` aborts on invalid hex digits (upstream `ValueError`);
  `chop_cells` with a zero width on single-cell text aborts (upstream
  `ValueError` from `range`).

## theme

* `Theme.from_file(file)` is `Theme::from_config(contents)` (a port of the
  configparser subset Rich needs: sections, `[DEFAULT]`, comments,
  continuation lines, `%%` / `%(name)s` interpolation, and the upstream
  error messages for duplicates, missing headers / sections and parse
  errors). `Theme.read(path)` (file system) is not ported (`test_read`
  skipped).

## emoji / highlighter

* `NoEmoji` is the `RichError::NoEmoji` constructor.
* `Highlighter.__call__` is `&Highlighter::apply`; `test_wrong_type`
  (TypeError for a non-text argument) has no equivalent.
