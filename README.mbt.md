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

## Packages

| Package | Upstream module(s) |
|---|---|
| `bobzhang/rich` | console, text, style, segment, markup, table, rule, padding, align, json, ansi, highlighter, theme, ... |
| `bobzhang/rich/cells` | cells, `_unicode_data` |
| `bobzhang/rich/color` | color, color_triplet, palette, terminal_theme |
| `bobzhang/rich/emoji` | emoji codes |
| `bobzhang/rich/panel` | panel |

See [DESIGN.md](DESIGN.md) for the architecture and
[DEVIATIONS.md](DEVIATIONS.md) for the differences from upstream.

## License

MIT, like upstream Rich (Copyright (c) 2020 Will McGugan).
