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
* `diagnose.report` (prints Python environment details) is not ported.
* Upstream refreshes `Live`/`Progress`/`Status` from a background thread.
  The synchronous API refreshes on updates (and `tick()`); the `aio`
  package (native, `moonbitlang/async`) adds timer-driven refresh:
  `@aio.run_live`, `run_progress`, `run_status` and an async `track`. The
  async runtime is cooperative, so the timer fires whenever the body
  suspends (sleep, IO, `@async.pause()`), not during CPU-bound work.
* No Jupyter, no legacy Windows console API (`legacy_windows` only affects
  layout), no `file_proxy` redirection, no `inspect`.

## style

* Upstream caches the ANSI codes of a style for the first color system it
  is rendered with, so a style shared between consoles with different color
  systems renders with the wrong codes (upstream bug). rich.mbt caches per
  color system.
* Meta data is a `Map[String, Json]` (upstream pickles arbitrary values).
  It is deep-copied on construction and compared by its canonical JSON text
  (key order and number spelling matter, as upstream's pickled bytes do).
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
* `test_status` (only an `isinstance` check) is covered by `status/` tests: `@status.Status::new(..., console=)` replaces `console.status(...)`.

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

* `indent` is `Int?` (spaces); use `indent_str` for a string indent such as
  `"\t"` (upstream accepts either in `indent`).

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
## Live, Progress and Status: refresh without threads

MoonBit has no threads, so the upstream refresh threads (`Live`'s
`_RefreshThread`, `Progress`'s `_TrackThread`) are replaced by synchronous,
time-throttled refreshes (DESIGN.md §7):

* Upstream refresh points are unchanged: `Live.start(refresh=True)`,
  `Live.refresh()`, `Live.update(refresh=True)`, `Live.stop()` (final full
  render, cursor/alt-screen/render-hook cleanup), `Progress.add_task`,
  `Progress.reset`, `Progress.update(refresh=True)`, `Progress.refresh()`,
  `Status.update(spinner=...)`.
* With `auto_refresh=True`, `Live::update` (without `refresh`),
  `Progress::update`/`advance`, `Status::update` and the new `tick()`
  methods (`Live::tick`, `Status::tick`) refresh when at least
  `1 / refresh_per_second` seconds have passed since the last refresh,
  measured with `console.get_time` (the console clock, so tests inject it).
  Long blocking work should call `tick()` to keep spinners animated.
* `Progress::track` with auto refresh advances the task at most every
  `update_period` seconds (console clock) and ends with
  `update(completed=<iterations>, refresh=True)`, like the track thread.
* Timer-driven refresh is provided by the `aio` package (native,
  `moonbitlang/async`): `@aio.run_live`/`run_progress`/`run_status` start a
  refresh task like upstream's refresh thread. As upstream, no timer runs
  for nested displays or without `auto_refresh`; the timer shares the
  throttle of update-driven refresh; a failing timer refresh stops the timer
  without interrupting the body. The runtime is cooperative: refreshes
  happen while the body suspends.

## spinner

* An unknown spinner name raises `RichError::ValueError` (upstream
  `KeyError`).
* Spinner data is generated by `scripts/gen_spinners.py`; frames given as a
  string upstream are split into code points (what indexing a Python `str`
  does). `spinner_names()` lists the names.
* `Spinner::render` returns `&Renderable` (a `Text`, or a grid `Table` when
  the text is another renderable).

## progress_bar

* With `animation_time=None` the pulse animation reads the console clock
  (`console.get_time`) instead of `time.monotonic()`.
* `_get_pulse_segments` is the public `get_pulse_segments` (not cached) and
  takes the color system name (`console.color_system()`). The upstream
  quirk that 256-color consoles get the un-blended pulse (the code tests
  for `"eight_bit"`, which is not a color system name) is kept.
* `total`/`completed` are `Double`, so `repr` prints floats
  (`<Bar 50.0 of 100.0>`).

## live

* `redirect_stdout`/`redirect_stderr` are accepted but have no effect: the
  process streams cannot be redirected (no `FileProxy`); print through the
  console (`live.console.print(...)`), which is rendered above the display.
* `with Live(...) as live:` → `live.run(fn)` (or `enter()`/`stop()`;
  `enter` refreshes when a renderable was given, like `__enter__`).
* The console's live stack holds live ids; the `live` package keeps a
  registry of started displays so the top-most display can render nested
  ones (upstream stores the `Live` objects on the console).
* `refresh_per_second <= 0` aborts (upstream `assert`).
* No Jupyter widget support.
* `LiveRender._shape` is the public field `shape`; `vertical_overflow` is
  the `VerticalOverflowMethod` enum.
* `get_renderable` is called once at construction (as upstream) but an
  error raised there is ignored (the initial renderable is `""`).

## status

* `console.status(...)` → `@status.Status::new(status, console=console,
  ...)`; `with status:` → `status.run(fn)` (or `start()`/`stop()`).
* `Status::update` without a new spinner refreshes the display if auto
  refresh is due (`live.tick()`); `Status::live()` gives the `Live`.

## progress

* `track` and `Progress::track` take the loop body as a closure
  (`@progress.track(items.iter(), item => ...)`) instead of returning a
  generator; the sequence is an `Iter[T]` and the default total is its
  `size_hint()` (upstream `length_hint`).
* `wrap_file`, `open`, `Progress.wrap_file`, `Progress.open` and the
  `_Reader` file wrapper are not ported (no file IO in `moonbitlang/core`);
  their tests (`test_open`, `test_open_text_mode`, `test_wrap_file`,
  `test_wrap_file_task_total`) and `test_track_thread` are skipped.
  `test_using_default_columns` only checks the number of columns.
* Columns: `ProgressColumn` is an open trait (`render` + `column_state`,
  default `get_table_column` and `call` = upstream `__call__`); each column
  stores a `ColumnState` (table column, `max_refresh`, render cache), so
  `column.max_refresh = 3` is `column.state.max_refresh = Some(3.0)`.
  Strings are columns (format strings). The concrete columns' inherent
  `render` methods return their concrete type (`Text`, `ProgressBar`). The
  upstream render cache condition (`not task.completed`, i.e. only tasks
  with 0 steps completed are cached) is kept.
* `Progress(*columns)` → `Progress::new(columns=[...])` (empty means
  `get_default_columns()`); `Progress.print`/`log` → use
  `progress.console()`. Overriding `get_renderables` by subclassing is not
  supported.
* Task IDs are `Int`; an unknown task ID raises `RichError::ValueError`
  (upstream `KeyError`), `remove_task` of an unknown ID does nothing.
  `Progress::get_task(id)` returns a task.
* `Task` numbers are `Double`. In format strings, integral `completed`,
  `total` and `remaining` values print as ints (`{task.completed}` → `0`),
  matching upstream for the usual int counts; an explicitly fractional-free
  float (upstream `total=100.0`) also prints as `100`. `fields` (upstream `**fields`)
  is a `Map[String, Json]`; integral JSON numbers format as ints.
  `Task._progress` is private (`Task::samples()` returns a copy).
* Format strings (`TextColumn`, `TaskProgressColumn`, string columns) use
  `format_task`, a subset of `str.format(task=task)`: fields
  `{task.<attribute>}` and `{task.fields[<name>]}`, `!s`/`!r`, and format
  specs `[[fill]align][sign][#][0][width][,|_][.precision][type]` with types
  `s d n x X o b f F % e E` (`g`/`G` and float precision without a type use
  Python's default `g` formatting). Unknown attributes raise
  `RichError::ValueError`.
* Upstream test `test_columns` writes `print("foo")` through the stdout
  redirection; the port prints `"foo"` with the console.

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

## traceback

* MoonBit has no runtime frames or exception objects, so there is no
  automatic capture: `Traceback.extract`, `Traceback.from_exception`,
  `Traceback()` without a trace and `install` (sys.excepthook / IPython)
  are not ported. Callers build a `Trace` (`Trace`, `Stack`, `Frame`,
  `SyntaxErrorInfo` = upstream `_SyntaxError`) or load one from
  Python-like data with `Trace::from_json` (the `dataclasses.asdict` shape;
  each local is a `pretty.Node` dict or a repr string;
  `last_instruction` is `[[line, column], [line, column]]`). What
  `extract` does while walking frames — `_rich_traceback_omit` /
  `_rich_traceback_guard`, hiding dunder/sunder locals, `pretty.traverse`
  with `locals_max_*` — is the caller's job (`@pretty.traverse` builds the
  nodes); the options are kept on `Traceback` for parity.
  `Trace::from_error` / `print_error` wrap a MoonBit `Error` value as a
  frame-less stack.
* Source lines come from an injectable `source_reader` (upstream
  `linecache.getlines`; default: the file system on native, nothing
  elsewhere) and file existence from `path_exists` (upstream
  `os.path.exists`; defaults to "the reader returns `Some`" when a reader is
  given, else the file system).
* `Console.print_exception` is `@traceback.print_exception(console, trace,
  ...)`.
* `suppress` takes paths only (no modules); they are normalized like
  `os.path.normpath(os.path.abspath(path))` using `@env.current_dir()`.
* The constructor argument `locals_overlow` (upstream typo) is
  `locals_overflow`; `_guess_lexer` is public as `Traceback::guess_lexer`
  and treats any lexer lookup error as "text".
* Upstream pushes a theme of `pygments.*` / `repr.*` / `scope.*` styles
  while building (not rendering) the output, which has no effect; it is not
  reproduced.
* `last_instruction` columns are UTF-16 offsets.
* Skipped upstream tests (exception capture only): `test_no_exception`,
  `test_rich_traceback_omit_optional_local_flag`,
  `test_traceback_finely_grained_missing`, `test_recursive_exception`. The
  other tests are ported with the Trace data the Python test produces; 37
  differential cases (`scripts/traceback_oracle.py`) compare full output.
  representation are printed as integers when integral. There is no
  `default` callable (tests/test_json.py is ported with the converted
  value), nor `skip_keys` / `check_circular` / `allow_nan`.
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

## markdown

* Parsing uses `moonbit-community/cmark` (strict CommonMark mode) instead
  of markdown-it-py. An adapter (`markdown/adapter_*.mbt`) converts its AST
  into the flattened markdown-it token stream Rich walks (`parse_tokens`,
  `Token`, exposed for inspection). cmark 0.4.10 agrees with markdown-it
  on CommonMark itself, so the adapter only emulates markdown-it's own
  rules: GFM tables (markdown-it's table rule applied to paragraph lines,
  including tables that start where cmark saw a list / heading / quote,
  setext headings holding a table, terminators), `~~strike~~` (the
  markdown-it delimiter algorithm on the token stream), link
  normalization (`normalizeLink`, `normalizeLinkText` with mdurl and
  punycode) and `validateLink` (also for autolinks, whose entities it
  does not resolve), markdown-it's raw HTML comment pattern (stricter than
  CommonMark 0.31's), a link reference definition being a block of its
  own, Python's `str.strip()` of the inline source (which also strips
  U+00A0 and other Unicode blanks), the indentation markdown-it keeps on
  continuation lines of code spans and raw HTML, raw fence info strings,
  empty text tokens around `strong`. The renderer itself is a literal
  port.
* All 652 CommonMark spec examples produce the same markdown-it token
  stream, and every rendered case of the differential corpus is
  byte-identical to upstream. On random documents
  (`scripts/markdown_fuzz.py`, 4 x 5,000 documents) about 99.2% of the
  token streams are identical.
* Other known differences (rare): strikethrough delimiters cannot pair
  across emphasis boundaries (`~~a *b~~ c*`), markdown-it pairs them on
  the flat token stream; for `~~` flanking only Unicode punctuation (not
  symbols such as `😀` or `€`) counts as punctuation, markdown-it-py 4
  counts both; a line indented by 4+ spaces starting with a list marker
  that lazily continues a block quote paragraph (markdown-it ends the
  quote); the table-before-other-blocks rule and the link-definition rule
  are not applied inside list items, nor to a lazy line after a link
  definition in a block quote (markdown-it ends the quote); a link
  definition line swallowed as a table row by markdown-it still defines
  its label, and one whose destination `validateLink` rejects is still a
  definition (a paragraph for markdown-it); markdown-it-py's `\s` in its HTML patterns matches Unicode
  blanks (`<b>\u00a0` starts an HTML block for it); a comment ending in
  `--->` that cmark closes earlier; tabs in the continuation lines of HTML
  blocks and in the indentation markdown-it keeps on lazy lines in quotes;
  a link or image whose destination `validateLink` rejects keeps its
  source after the text as plain text (markdown-it parses it as inlines).
* An unbalanced `</kbd>` raises `StyleStackError` (upstream: `IndexError`
  from the style stack).
* Elements are private: upstream's `Markdown.elements` class mapping
  (customization by subclassing) is not available, except for code blocks:
  `Markdown::new(code_renderers=...)` replaces the `"fence"` /
  `"code_block"` elements (used by `cli` for rich-cli's `CodeBlock`).
* `test_inline_code_in_table_cells`: the upstream expectation predates
  Pygments lexing `print` as `Name.Builtin`; upstream's own test fails with
  the oracle's Pygments, the port expects the current (green) colour.

## cli, cmd/rich (rich-cli)

Port of [rich-cli](https://github.com/Textualize/rich-cli) 1.8 (`rich`
command). Option names, defaults, help text, click's usage errors and the
rendering follow rich-cli's `__main__.py` run against Rich 15 (rich-cli pins
Rich 12; `scripts/cli_oracle.py` runs its source with Rich 15 as the oracle).

* Not supported: fetching `http://` / `https://` URLs (an error is shown),
  `--inspect` (evaluates Python objects; an error is shown) and `--rst`
  (rich-rst is not ported: reStructuredText is shown as syntax-highlighted
  source).
* `--pager` pipes the rendered lines (rendered as rich-cli does, one cell
  narrower than the width) to `$PAGER` or `less -r` instead of Textual's
  pager app; without a pager (wasm) they are printed.
* With Rich 15, rich-cli's `CodeBlock` (Padding (0, 4), no background
  padding) only replaces indented code blocks (`Markdown.elements
  ["code_block"]`); fenced code keeps Rich's element. The port does the
  same.
* Error messages of Python exceptions are reproduced where the port has the
  information (`[Errno 2] No such file or directory: 'x'`, JSON decode
  errors with line/column, style and markup errors, `csv.Error`); a broken
  notebook gives `unable to read notebook` (rich-cli: a Python traceback).
* Files are decoded as UTF-8 with replacement characters and universal
  newlines, as `open(path, encoding="utf8", errors="replace")`.
