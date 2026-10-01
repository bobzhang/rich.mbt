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
