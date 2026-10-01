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
* `input` reads from stdin via the native runtime (not available on wasm/js).

## json

* `JSON::from_data` takes a MoonBit `Json`; numbers without a textual
  representation are printed as integers when integral.
