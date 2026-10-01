///|
test "smoke" {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    file~,
    width=40,
    color_system=Some("truecolor"),
    force_terminal=true,
    legacy_windows=false,
    environ={},
  )
  console.print("Hello, [bold magenta]World[/]!")
  let table = @rich.Table::new(headers=["Name", "Value"])
  table.add_row(["foo", "1"])
  table.add_row(["bar", "[red]2"])
  console.print(table)
  console.rule(title="Title")
  inspect(
    file.getvalue().escape(),
    content=(
      #|"Hello, \u{1b}[1;35mWorld\u{1b}[0m!\n┏━━━━━━┳━━━━━━━┓\n┃\u{1b}[1m \u{1b}[0m\u{1b}[1mName\u{1b}[0m\u{1b}[1m \u{1b}[0m┃\u{1b}[1m \u{1b}[0m\u{1b}[1mValue\u{1b}[0m\u{1b}[1m \u{1b}[0m┃\n┡━━━━━━╇━━━━━━━┩\n│ foo  │ 1     │\n│ bar  │ \u{1b}[31m2\u{1b}[0m     │\n└──────┴───────┘\n\u{1b}[92m──────────────── \u{1b}[0mTitle\u{1b}[92m ─────────────────\u{1b}[0m\n"
    ),
  )
}
