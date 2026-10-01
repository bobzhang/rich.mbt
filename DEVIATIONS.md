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

## columns

* `Columns::new(renderables, ...)` takes the renderables as a required
  positional array (upstream: optional iterable, default empty); pass `[]`
  for an empty `Columns`.
* An explicit `width` larger than the available width (zero columns)
  raises `@rich.ValueError` at render time (upstream: `ValueError` from
  `range()`).

## tree

* `Tree::add(highlight=None)` inherits the parent's `highlight` (upstream
  `highlight: Optional[bool] = False`); the parameter is `highlight? : Bool?`.
* `ASCII_GUIDES` / `TREE_GUIDES` are the package values `ascii_guides` /
  `tree_guides` (not class attributes, so they cannot be overridden per
  subclass).

## bar

* `size`, `begin` and `end` are `Double`s. `Bar::repr` prints integral
  values without a fractional part (`Bar(100, 11, 62)`), so
  `Bar(100.0, ...)` reprs as `Bar(100, ...)` where Python would print
  `100.0`.
* `color` / `bgcolor` accept a `String` or a `@color.Color` (trait
  `IntoColor`).

## layout

* `Layout::split`, `split_row`, `split_column` and `add_split` take an
  array of `&IntoLayout` (implemented for `Layout`, `String`, `Text`,
  `TextType` and `Panel`); wrap any other renderable with
  `Layout::new(renderable=...)`.
* `Layout::split(splitter=...)` takes `&IntoSplitter` (a splitter name
  `String`, `RowSplitter` or `ColumnSplitter`); a custom `Splitter` must
  also implement `IntoSplitter`. `Layout.splitters` is the function
  `splitter_by_name`.
* `layout[name]` raises `LayoutError::KeyError` (upstream `KeyError`);
  `NoSplitter` is a constructor of `LayoutError` rather than a subclass.
* Without threads there is no lock: `update`/`refresh_screen` are plain
  methods.
* `Layout::renderable` returns an internal placeholder when no renderable
  was given (or it was an empty string / empty `Text`), like upstream; a
  `None` content cannot be set with `update`.
* The tree view and placeholder use a built-in pretty repr of `Layout`
  (`Layout::pretty_repr`, same output as `rich.pretty.pretty_repr` for a
  layout) instead of the generic `Pretty` renderable.
* `refresh_screen` on a layout that has not been rendered raises
  `LayoutError::KeyError` (upstream `KeyError` from the render map).
* A layout whose children are all invisible recurses forever, as upstream
  (which raises `RecursionError`).
