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

## syntax

* `lexer` is a lexer name or a `@lexer.Lexer` instance (`&IntoLexer`);
  `theme` is a theme name or a `SyntaxTheme` instance (`&IntoSyntaxTheme`).
  `SyntaxTheme` is an open trait. `PygmentsSyntaxTheme::new(name)` takes a
  style name; `PygmentsSyntaxTheme::from_style` takes a
  `@styles.Style` value (upstream takes a style class).
* Lexers and styles come from `bobzhang/pygments` (Pygments 2.21). Six
  upstream tests (`test_python_render*`, `test_option_no_wrap`,
  `test_syntax_highlight_ranges`) expect colors from an older Pygments
  monokai style and fail upstream with Pygments 2.21; their ports compare
  with the output of upstream Rich + Pygments 2.21 instead
  (`scripts/gen_syntax_expected.py`).
* Private helpers are public under names without the underscore:
  `style_cache`, `background_style` (themes), `get_line_numbers_color`,
  `get_number_styles`, `numbers_column_width()`; `_lexer` is
  `lexer_spec`, the `lexer` property is `lexer()`, the `padding` setter is
  `set_padding`.
* A lexer looked up by name is cached per (name, tab_size) instead of being
  re-created on every access.
* `highlight_lines` is an array (upstream: a set).
* `stylize_range` columns are UTF-16 offsets.
* `from_path` reads files on the native backend only (raises elsewhere) and
  only supports UTF-8 (no `encoding` parameter). `Syntax::new` raises for an
  invalid `background_color` or padding, like upstream's constructor.
* `dedent` follows Python 3.14's `textwrap.dedent`.
* The `python -m rich.syntax` command line is not ported.
