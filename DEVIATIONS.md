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
## prompt

* `PromptBase[PromptType]` is a generic struct `PromptBase[T]`; the upstream
  subclasses are namespaces whose `new` returns `PromptBase[String]`
  (`Prompt`), `PromptBase[Int]` (`IntPrompt`), `PromptBase[Double]`
  (`FloatPrompt`) and `PromptBase[Bool]` (`Confirm`), and whose `ask` is the
  upstream classmethod. Class attributes (`response_type`,
  `validate_error_message`, `illegal_choice_message`, `prompt_suffix`,
  `choices`) are fields; overridable methods are optional function fields
  (`render_default_fn`, `process_response_fn`, `pre_prompt_fn`,
  `get_input`). `convert_response` is the base `process_response`, so an
  override can call it (upstream `super().process_response`).
* `__call__` is `call(default?, stream?)`. `default` must have the response
  type (upstream accepts any value and only displays it when it is a `str`
  or of the response type; `...` is "no default" → `None`).
* The prompt text is a positional argument without a default (pass `""`).
* Input is injectable: `get_input?` (an `InputFn`, i.e.
  `(Console, Text, password, InputStream?) -> String raise`, defaulting to
  `@prompt.get_input`, which calls `Console::input`). `stream` is an
  `InputStream` (a readable string, like `io.StringIO`): lines keep their
  newline and the end of the stream reads as `""`, as with
  `TextIO.readline`. With `password=true` and a stream, the line is read from
  the stream with the newline removed (upstream passes the stream to
  `getpass`, which uses it for output and reads from the terminal).
* `IntPrompt` parses with Python `int()` rules (sign, whitespace, `_`
  separators, base 10) but rejects values that do not fit an `Int`.
  `FloatPrompt` uses `@string.parse_double` (Python `float()` syntax incl.
  `inf`/`nan`/`_`). The default of a `FloatPrompt` is displayed with Python
  float repr (`(1.0)`).
* `PromptError` (the base class of `InvalidResponse`) is not ported.

## logging

* There is no Python `logging` module: `RichHandler` renders `LogRecord`
  structs (name, level, already-interpolated `msg`, `pathname`, `lineno`,
  `func_name`, `created`, optional `exc_text` / `stack_info`). Upstream
  `extra={"markup": ..., "highlighter": ...}` are the record fields `markup`
  and `highlighter` (`highlighter: None` → pass a `@rich.NullHighlighter`);
  other extra attributes are strings in `extra`.
* A small `Formatter` replaces `logging.Formatter` (`%`-style only:
  `%(attr)[flags][width][.precision]conv` with conversions `s r d i f e g`,
  `%%`; `asctime` uses `datefmt` or `%Y-%m-%d %H:%M:%S,mmm` in local time).
  Unknown attributes raise `ValueError` at format time (Python `KeyError`).
  Attributes about threads/processes/`relativeCreated` are not available.
* A minimal `Logger` (level, handlers, `debug`/`info`/`warning`/`error`/
  `critical`/`exception`/`log`) creates records with the caller's MoonBit
  source location as `pathname`/`lineno`; no logger hierarchy, propagation,
  filters or `basicConfig`. `RichHandler::handle` checks the handler level
  (Python checks it in `Logger.callHandlers`).
* Rich tracebacks: MoonBit has no exception objects with frames, so the
  record carries an optional `traceback` renderable (e.g. a
  `@traceback.Traceback` built by the caller); with `rich_tracebacks=true` it
  is rendered below the message instead of the formatted `exc_text`. The
  `tracebacks_*` and `locals_*` options are therefore not handler
  options (configure the traceback renderable instead).
* `log_time_format` is a `strftime` string; a callable is passed as
  `log_time_formatter` (receives seconds since the epoch, not a
  `datetime`).
* `emit` raises render errors instead of calling `handleError`; the
  `NullFile` (pythonw) special case is not ported.
* Skipped upstream test: `test_stderr_and_stdout_are_none` (pythonw /
  `NullFile`). `test_exception*` use a stand-in traceback renderable.
## pretty (and repr)

* No object introspection. A value is pretty printed through the
  `PrettyRepr` trait, whose `pretty_node(ctx)` builds the upstream `Node`
  tree with the `PrettyContext` builders: `leaf` / `str_leaf`, `sequence`,
  `tuple`, `mapping` (upstream's container branch), `rich_repr`
  (`__rich_repr__` and attrs objects), `dataclass`, `namedtuple`. The
  `Node` layout algorithm (`Node::render`, `_Line` expansion) is ported
  exactly.
* Builtin values are formatted as the corresponding Python value: integers,
  `Double`/`Float` via `py_float_repr`, `Bool` → `True`/`False`, `Unit` →
  `None`, `Char`/`String` → `repr(str)`, `Bytes` → `repr(bytes)`,
  `Option` → `None` or the value, `Array`/`FixedArray`/`ArrayView`/
  `ReadOnlyArray` → list, `Map`/`HashMap` → dict, `Set`/`HashSet` → set
  (in iteration order), `Deque` → `deque([...])`, MoonBit tuples → tuple,
  `Json`/`JsonValue` → what `json.loads` returns. `Result` has no Python
  counterpart and renders as `Ok(...)` / `Err(...)`; `Error` uses its
  `Show` output. `@pretty.Tuple` (1-tuples, empty tuples, heterogeneous
  tuples) and `@pretty.Dict` (keys of different types) model Python values
  MoonBit has no literal for.
* Values known only through `Show`/`Debug` are opaque leaves
  (`@pretty.shown`, `@pretty.debugged`, `@pretty.Leaf`); `@debug.Repr`
  cannot be traversed. Python-specific containers (`defaultdict`,
  `Counter`, `array`, `deque(maxlen=)`, `frozenset`, `UserDict`, ...) are
  not built in but can be modelled with `sequence`/`mapping` and custom
  braces.
* Reference cycles: upstream uses `id(obj)`. MoonBit has no identity for
  arbitrary values, so detection is opt-in: objects that may be part of a
  cycle carry a `PrettyId` and pass it to the builders (`id=`) or use
  `PrettyContext::visit`. A cycle through containers without an id
  recurses without bound.
* Broken `__repr__` (`<repr-error ...>`), broken/lying `__getattr__`,
  custom `__repr__` overrides of containers and namedtuples, and attrs
  `repr=callable` fields are Python-only (the latter is a `Leaf`).
* A `Node` passed where a child is expected renders as itself (upstream
  would traverse the `Node` dataclass).
* `Pretty` with an empty repr shows `__repr__ returned empty string`
  (upstream prefixes the Python type).
* `install` (REPL display hook) and the IPython hook are not ported.
* `rich.repr.auto` cannot derive `__rich_repr__` from an `__init__`
  signature: list the arguments with `arg`/`kwarg`/`arg_default`/
  `kwarg_default`; `repr_string` builds the `__repr__` text (`ReprError`
  is therefore not needed).
* Skipped upstream tests: `test_install*`, `test_ipy_display_hook*`,
  `test_broken_repr`, `test_broken_getattr`, `test_lying_attribute`,
  `test_attrs_broken*`, `test_pretty_namedtuple_custom_repr`,
  `test_pretty_namedtuple_fields_invalid_type`, the `D2` (custom `__repr__`)
  half of `test_user_dict`, `test_broken_egg`. `test_deque` covers only
  `deque` without `maxlen`.

## scope

* `render_scope` takes a `Map[String, &PrettyRepr]` (insertion order is
  kept when `sort_keys=false`).
