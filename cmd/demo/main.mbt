// Port of `python -m rich`: render the feature card.

///|
fn main {
  run() catch {
    e => println("error: \{e}")
  }
}

///|
fn round1(d : Double) -> String {
  @rich.py_format_fixed(d, 1)
}

///|
fn run() -> Unit raise {
  let test_card = @demo.make_test_card()
  // render once to a string to warm caches, then time a second render
  let console = @rich.Console::new(
    file=@rich.StringIO::new(),
    force_terminal=true,
  )
  let start = @term.monotonic()
  console.print(test_card)
  let pre_cache_taken = (@term.monotonic() - start) * 1000.0
  console.set_file(@rich.StringIO::new())
  let start = @term.monotonic()
  console.print(test_card)
  let taken = (@term.monotonic() - start) * 1000.0
  let console = @rich.Console::new()
  console.print(test_card)
  console.print(
    "[dim]rendered in [not dim]\{round1(pre_cache_taken)}ms[/] (cold cache)",
  )
  console.print("[dim]rendered in [not dim]\{round1(taken)}ms[/] (warm cache)")
  console.line()
  console.print(
    @panel.Panel::new(
      "[b magenta]Hope you enjoy using Rich![/]\n\nConsider sponsoring to ensure this project is maintained.\n\n[cyan]https://github.com/sponsors/willmcgugan[/cyan]",
      border_style="green",
      title="Help ensure Rich is maintained",
      padding=[1, 2],
    ),
  )
}
