# rich.mbt — design notes

Port of [Rich](https://github.com/Textualize/rich) 15.0.0 (upstream `9d8f9a37`,
cloned at `.repos/rich`) to MoonBit. Module `bobzhang/rich`.

## Facts gathered from the upstream code

* 26.6 k lines in 70 modules; 3.6 k of them are emoji data, 1.1 k unicode
  width tables (21 Unicode versions, ~250–400 ranges each), 0.5 k spinners,
  0.3 k palettes, 0.5 k box drawing.
* Everything revolves around `Console`, which imports (directly or lazily)
  `Text`, `Style`, `Segment`, markup, highlighters, themes, `Align`,
  `Styled`, `Table` (via `LogRender` for `Console.log`), `Rule`, `JSON`,
  `Pager`, `Status`/`Live`, `Traceback`, `Pretty`, jupyter, win32.
* Protocol: a renderable is `str`, or has `__rich_console__(console, options)`
  yielding `Segment`s or further renderables, optionally `__rich_measure__`,
  or `__rich__` returning a renderable. `isinstance` checks on `str`/`Text`
  are used by `Console._collect_renderables`, `Measurement.get`, `Columns`,
  `Table`, `Panel` titles, `Tree` labels, `Text.assemble`, ...
* `re` is used by markup (`RE_TAGS`), highlighters (big named-group regexes),
  `Text.highlight_regex`, `_wrap`, `ansi.AnsiDecoder`, `Style.parse` helpers,
  `color.py` (`RE_COLOR`), `pretty`, `traceback`, `markdown`.
* Python-runtime specific modules: `pretty` (introspects arbitrary objects:
  dataclasses, attrs, namedtuples, `__rich_repr__`), `inspect`, `traceback`
  (frames/exception objects), `logging` (stdlib `logging.Handler`), `jupyter`,
  `_win32_console`/`_windows_renderer` (legacy Windows API), `file_proxy`
  (stdout redirection), `scope`, `_inspect`.
* `Live`/`Progress`/`Status` auto-refresh from a background thread.
* `Syntax` uses Pygments (lexers + style classes); `Markdown` uses
  `markdown-it-py` (token stream with nesting/tag/info/attrs).
* Test suite: 63 pytest files (11.2 k lines) with exact expected output strings
  (ANSI escapes included), mostly via `Console(file=io.StringIO(), width=..,
  force_terminal=.., color_system=.., legacy_windows=False, _environ={})`.

## MoonBit facilities used

* Trait objects coerce implicitly, including inside array literals:
  `fn f(xs : Array[&Renderable])` accepts `f(["str", my_table])`.
* `bobzhang/pygments/regex`: a Python-`re`-compatible backtracking engine
  (named groups, lookaround, Unicode `\w\d\s`), offsets in UTF-16 units.
* `bobzhang/pygments/lexers` + `styles` for `Syntax`.
* `moonbitlang/core/env` for environment variables and wall clock time.
* Native C stubs for `write(2)`, `isatty`, `ioctl(TIOCGWINSZ)`, monotonic
  clock, `localtime/strftime`, reading a line from stdin.

## Decisions

1. **Strings and offsets.** Text is a MoonBit `String` (UTF-16). Span offsets,
   `Text.length()`, `divide` offsets, regex match offsets are UTF-16 offsets
   (same choice as pygments.mbt). Cell-width functions iterate code points
   and report UTF-16 offsets. For BMP text this is identical to Python;
   astral characters (most emoji) count as 2 in `length()`. Documented
   deviation.

2. **Renderable protocol** (trait object, open):

   ```mbt nocheck
   pub(open) trait Renderable {
     rich_console(Self, Console, ConsoleOptions) -> Array[RenderItem] raise
     rich_measure(Self, Console, ConsoleOptions) -> Measurement? raise = _   // None: no __rich_measure__
     as_str(Self) -> String? = _      // isinstance(x, str)
     as_text(Self) -> Text? = _       // isinstance(x, Text)
   }
   pub(all) enum RenderItem { Seg(Segment); Child(&Renderable) }
   ```

   `String` and `Text` implement it (`as_str`/`as_text` give the
   `isinstance` checks). `__rich__` is not ported (implement `Renderable`
   instead). Arbitrary non-renderable objects are not accepted by `print`
   (wrap them: `@pretty.Pretty::new(...)`, or interpolate a string).

3. **Union parameters.** `StyleType = str | Style` and `TextType = str | Text`
   become small open traits with implementations for `String` and the
   class, so call sites pass either directly (`style="bold red"` or
   `style=Style::new(bold=true)`); values are stored as enums
   (`StyleSpec { Name(String) | Style(Style) }`, same for text).

4. **Errors.** One `suberror RichError` with the upstream exception classes as
   constructors (`StyleSyntaxError`, `MissingStyle`, `StyleStackError`,
   `NotRenderableError`, `MarkupError`, `LiveError`, `NoAltScreen`).
   Rendering may raise (markup errors surface at render time as in Python),
   so `rich_console`, `Console::print`, `render`, `render_lines`... are
   `raise`. Python `ValueError`/`TypeError` on bad arguments → same suberror
   or `abort` for programming errors that Python asserts on.

5. **Packages** (acyclic; Python module → MoonBit package):

   | Package | Upstream modules |
   |---|---|
   | `cells` | `cells.py`, `_unicode_data/*` (generated tables, all versions) |
   | `color` | `color.py`, `color_triplet.py`, `palette.py`, `_palettes.py`, `terminal_theme.py` |
   | `emoji` | `_emoji_codes.py` (generated), `_emoji_replace.py` |
   | `internal/term` | platform layer: stdout/stderr writes, isatty, terminal size, clock, stdin line (native C stubs; js/wasm fallbacks) |
   | root `bobzhang/rich` | everything `Console` needs: `style`, `segment`, `text`, `markup`, `console`, `measure`, `containers`, `control`, `theme`, `themes`, `default_styles`, `highlighter`, `padding`, `align`, `constrain`, `styled`, `box`, `table`, `_ratio`, `_wrap`, `_pick`, `_loop`, `_log_render`, `region`, `screen`, `errors`, `json`, `ansi`, `rule`, `emoji` (renderable), `filesize`, `pager`, `abc`/`protocol`, `__init__` (`@rich.print`, `get_console`, `reconfigure`, `print_json`) |
   | `panel`, `columns`, `tree`, `layout`, `bar`, `progress_bar`, `spinner`, `live` (+`live_render`), `status`, `progress`, `prompt`, `pretty`, `markdown`, `syntax`, `traceback`, `logging` | one package per upstream module |
   | `cmd/demo` | `__main__.py` (the Rich demo card) |

   Root keeps `Table`, `Rule`, `Padding`, `Align` because `Console` uses them
   (`log`, `rule`, `print(justify=)`). `syntax`/`markdown`/`traceback` are
   kept out of the root so users who only print do not compile all Pygments
   lexers.

6. **Console output.** `Console(file?=...)` takes an open trait
   `ConsoleFile { write(String); flush(); isatty() -> Bool }`; defaults are
   stdout/stderr from `internal/term`; `StringIO` (a `StringBuilder`-backed
   file) is provided for tests and capture. Environment is read through an
   injectable map (Python's `_environ`) so tests are hermetic.

7. **Live / Progress / Status without threads.** MoonBit has no threads. The
   synchronous API keeps upstream semantics except the refresh thread:
   `Live::update`/`Progress::advance`/`Status::update` refresh when the
   refresh interval has elapsed (throttled by `refresh_per_second`), plus
   `refresh()` and `start()/stop()`; spinner frames are computed from the
   clock at render time as upstream. A native-only async helper
   (`moonbitlang/async`) can drive periodic refresh for long blocking work:
   implemented as the `aio` package (`@aio.run_live` and friends).

8. **Python-runtime modules.**
   * `pretty`: an open trait `PrettyRepr` producing the upstream `Node` tree;
     impls for builtins, `Array`, `Map`, `Option`, `Json`, tuples; fallback for
     any `Show`. `@debug.Repr` is opaque so arbitrary `Debug` values cannot be
     traversed (would need core to expose `Repr`'s constructors).
     `rich.repr` becomes builders (`rich_repr`, `dataclass`, `namedtuple`
     with `arg`/`kwarg` items); `scope.render_scope` takes a
     `Map[String, &PrettyRepr]` (package `scope`).
   * `traceback`: renderer ported over a plain data model (`Trace`, `Stack`,
     `Frame`, `SyntaxErrorInfo`) the caller builds; no automatic capture
     (MoonBit has no runtime frames).
   * `logging`: `RichHandler` ported as a renderer for a `LogRecord` struct.
   * `inspect`, `jupyter`, `_win32_console`, `_windows_renderer`,
     `file_proxy` — not
     ported / reduced; listed as blocked.

9. **Markdown.** `moonbit-community/cmark` parses in strict CommonMark
   mode; an adapter converts the AST into markdown-it's (flattened) token
   stream so `rich/markdown.py`'s token loop and element classes port
   literally. Since cmark 0.4.10 agrees with markdown-it on CommonMark,
   the adapter only emulates markdown-it's own rules: GFM tables
   (markdown-it's table rule on paragraph lines, tried before other block
   rules), a link reference definition being a block of its own,
   `~~strikethrough~~` (its delimiter algorithm on the token stream),
   `normalizeLink`/`validateLink`, its stricter raw HTML comment pattern,
   and Python's `str.strip()` of the inline source. Inline content is
   converted from the AST, or re-parsed from its source lines (a
   one-paragraph snippet) for table cells and where the last two rules
   apply. `scripts/markdown_oracle.py` records markdown-it tokens and Rich
   output for the CommonMark spec examples and a corpus
   (`markdown/corpus_data_test.mbt`); `scripts/markdown_fuzz.py` compares
   token streams on random documents.

10. **Conformance.** `.venv` with upstream Rich (+pygments, markdown-it).
    Upstream pytest files are ported test-by-test to MoonBit black-box tests
    with the same expected strings; additional differential cases are
    generated by `scripts/*_oracle.py` into `.oracle/*.jsonl` and replayed.
