# rich.mbt

A port of [Rich](https://github.com/Textualize/rich) 15.0 — rich text and
beautiful formatting in the terminal — to MoonBit.

Rendering is byte-for-byte compatible with Python Rich: the upstream test
suite is ported test by test, and extra cases are compared against the
Python implementation.

## Usage

```mbt check
///|
test "print markup and a table" {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(file~, width=30, color_system=None)
  console.print("Hello, [bold magenta]World[/]!")
  let table = @rich.Table::new(headers=["Name", "Value"])
  table.add_row(["foo", "1"])
  table.add_row(["bar", "2"])
  console.print(table)
  inspect(
    file.getvalue(),
    content=(
      #|Hello, World!
      #|┏━━━━━━┳━━━━━━━┓
      #|┃ Name ┃ Value ┃
      #|┡━━━━━━╇━━━━━━━┩
      #|│ foo  │ 1     │
      #|│ bar  │ 2     │
      #|└──────┴───────┘
      #|
    ),
  )
}
```

`@rich.print` writes to standard output with the global console:

```mbt nocheck
///|
fn main {
  @rich.print("[bold red]alert![/] Something happened") catch { _ => () }
}
```

More renderables live in their own packages, as in upstream
(`rich.panel.Panel` → `@panel.Panel`):

```mbt nocheck
///|
fn main raise {
  let console = @rich.Console::new()
  console.print(@panel.Panel::new("Hello, [red]World!", title="Greeting"))
  let tree = @tree.Tree::new("Rich Tree")
  tree.add("foo").add("bar") |> ignore
  console.print(tree)
  console.print(@syntax.Syntax::new("def f(x):\n    return x + 1", "python", line_numbers=true))
  console.print(@markdown.Markdown::new("# Title\n\n* one\n* **two**"))
  console.print(@pretty.Pretty::new({ "numbers": [1, 2, 3], "ok": true }))
  let progress = @progress.Progress::new()
  progress.start()
  let task = progress.add_task("Working...", total=Some(10.0))
  for _ in 0..<10 {
    progress.advance(task) // refreshes when the refresh interval has passed
  }
  progress.stop()
}
```

Run the feature demo (`python -m rich`):

```bash
moon run cmd/demo
```

## Packages

| Package | Upstream module(s) |
|---|---|
| `bobzhang/rich` | console, text, style, segment, markup, table, rule, padding, align, constrain, styled, box, measure, containers, control, json, ansi, highlighter, theme, emoji, filesize, `_log_render`, `_ratio`, `_wrap`, export (text/HTML/SVG) |
| `bobzhang/rich/cells` | cells, `_unicode_data` (all Unicode versions) |
| `bobzhang/rich/color` | color, color_triplet, palette, terminal_theme |
| `bobzhang/rich/emoji` | `_emoji_codes`, `_emoji_replace` |
| `bobzhang/rich/panel` | panel |
| `bobzhang/rich/columns` | columns |
| `bobzhang/rich/tree` | tree |
| `bobzhang/rich/bar` | bar |
| `bobzhang/rich/layout` | layout |
| `bobzhang/rich/spinner` | spinner, `_spinners` |
| `bobzhang/rich/progress_bar` | progress_bar |
| `bobzhang/rich/live` | live, live_render |
| `bobzhang/rich/status` | status |
| `bobzhang/rich/progress` | progress |
| `bobzhang/rich/pretty` | pretty, repr |
| `bobzhang/rich/scope` | scope |
| `bobzhang/rich/syntax` | syntax (via [pygments.mbt](https://github.com/bobzhang/pygments.mbt)) |
| `bobzhang/rich/traceback` | traceback (renders caller-built traces) |
| `bobzhang/rich/markdown` | markdown (via `moonbit-community/cmark`) |
| `bobzhang/rich/prompt` | prompt |
| `bobzhang/rich/logging` | logging (`RichHandler` over a `LogRecord`) |
| `bobzhang/rich/demo`, `cmd/demo` | `__main__` (the feature card) |

## Compatibility

* The upstream test suite is ported test by test; around 1,500 tests run on
  native, js and wasm-gc, including thousands of differential cases generated
  with Python Rich (`scripts/*_oracle.py`), the full feature card at width
  100, all 652 CommonMark spec examples for Markdown and 36 languages × 13
  themes for Syntax.
* MoonBit has no threads and no runtime introspection: `Live`/`Progress`
  refresh on updates (or `tick()`) instead of from a timer thread; `pretty`
  works through the `PrettyRepr` trait; tracebacks are rendered from data you
  provide; `inspect` and Jupyter support are not ported.

See [DESIGN.md](DESIGN.md) for the architecture and
[DEVIATIONS.md](DEVIATIONS.md) for every difference from upstream.

## License

MIT, like upstream Rich (Copyright (c) 2020 Will McGugan).
