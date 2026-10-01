# Porting guide

Upstream: Rich 15.0.0 at `/Users/dii/git/rich.mbt/.repos/rich` (Python source in
`rich/`, tests in `tests/`). Read DESIGN.md first.

## Python oracle

`/Users/dii/git/rich.mbt/.venv/bin/python` has upstream Rich (editable install
of `.repos/rich`), Pygments and markdown-it-py. Use it to compute expected
output whenever an upstream test does not already give it, e.g.

```bash
/Users/dii/git/rich.mbt/.venv/bin/python - <<'EOF'
import io
from rich.console import Console
from rich.panel import Panel
f = io.StringIO()
c = Console(file=f, width=40, color_system="truecolor", force_terminal=True,
            legacy_windows=False, _environ={})
c.print(Panel("hello"))
print(repr(f.getvalue()))
EOF
```

(`.repos/` and `.venv/` are not in git; use the absolute paths above from a
worktree.)

## Package layout

* `cells/`, `color/`, `emoji/` (data + replace), `internal/term/` (platform).
* root `bobzhang/rich`: Console, Style, Segment, Text, markup, Table, Rule,
  Padding, Align, Styled, Constrain, Box, JSON, AnsiDecoder, highlighters,
  themes, LogRender, export (text/html/svg), global `print`.
* One package per remaining upstream module: `panel/`, `columns/`, `tree/`,
  `layout/`, `bar/`, `progress_bar/`, `spinner/`, `live/`, `status/`,
  `progress/`, `prompt/`, `pretty/`, `markdown/`, `syntax/`, `traceback/`,
  `logging/`, `cmd/demo/`. They import the root package as `@rich`.

## Conventions

* **Renderable protocol**: implement `@rich.Renderable` (`rich_console`
  returning `Array[@rich.RenderItem]` = `Seg(segment)` / `Child(renderable)`;
  optional `rich_measure` returning `Measurement?`). Strings and `Text` are
  renderables; pass any renderable as `&@rich.Renderable` (implicit
  coercion works: `console.print("hi")`, `table.add_row(["a", panel])`).
  Upstream `isinstance(x, str)` / `isinstance(x, Text)` checks →
  `x.text_kind()` (`Str(s)` / `Text(t)` / `NotText`).
* **Union parameters**: `style: Union[str, Style]` → `style? : &@rich.IntoStyle`
  (stored as `@rich.StyleType` = `Def(String) | Style(Style)`, resolved with
  `console.get_style(...)` at render time, never at construction).
  `TextType` (str | Text) → `&@rich.IntoText` / `@rich.TextType`.
* **Errors**: `@rich.RichError` (`StyleSyntaxError`, `MissingStyle`,
  `MarkupError`, `NotRenderableError`, `LiveError`, `NoAltScreen`,
  `ValueError`, ...). Rendering functions are `raise`. Pure helpers are
  not.
* **Offsets** are UTF-16 offsets (`String.length()`); cell widths via
  `@cells`. Upstream tests that use code-point offsets with astral
  characters (emoji) need their offsets converted.
* **Python formatting helpers** (root): `py_repr` (repr of str),
  `py_float_repr`, `py_format_fixed(d, n)` (`f"{d:.nf}"`), `py_format_g`,
  `py_group_thousands`, `py_format` (`str.format` with named fields),
  `@color.py_round` (round half even), `floor_div`/`py_mod` (private, copy if
  needed), `filesize_decimal`.
* **Keyword arguments** become labelled optional arguments with the same
  names and defaults. `Optional[X] = None` → `x? : X`. Where upstream
  distinguishes "not given" from `None` use `x? : X?` (see
  `ConsoleOptions::update`).
* **Context managers** (`with x:`) become `start()`/`stop()` pairs plus a
  helper taking a closure (`console.capture(fn() { ... })`).
* Classes with public mutable attributes → `pub(all) struct` with `mut`
  fields (private internals marked `priv`); constructors are
  `Type::new(...)`.
* Keep upstream names (snake_case) so the port is easy to compare.
  Reserved words: `inherit` → `inherit_styles`, `type` → `type_`,
  `box` field → `box_`.
* No threads: see DESIGN.md §7. Time comes from injectable clocks
  (`console.get_time`), never read directly in tests.

## Tests

* Port the upstream pytest file(s) for your module to black-box
  `*_test.mbt` files in the package, test by test, with the same names and
  the same expected strings (escape sequences included). Use
  `assert_eq(actual, expected)` or `inspect(x, content=...)`.
* Upstream tests that rely on Python-only features (pickling, `repr` of
  arbitrary objects, threads, Jupyter, Windows APIs) are skipped; list them
  in the module's section of DEVIATIONS.md.
* Typical console in tests:
  `@rich.Console::new(file=@rich.StringIO::new(), width=80,
  color_system=Some("truecolor"), force_terminal=true, legacy_windows=false,
  environ={})`; read output with `file.getvalue()`; or
  `console.capture(fn() { ... })`.
* Add extra differential cases computed with the Python oracle where the
  upstream tests are thin.

## Workflow

* `moon check`, `moon test <pkg>`, `moon fmt`, `moon info` before each commit.
* Do not rewrite other packages. If a root (`@rich`) API is missing or buggy,
  make the smallest additive fix and mention it in your final report.
* Record every intentional difference from upstream in DEVIATIONS.md
  (append to your module's section).
