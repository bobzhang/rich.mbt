// Port of rich/__main__.py: the Rich feature "test card".

///|
fn hls_value(m1 : Double, m2 : Double, hue : Double) -> Double {
  let hue = hue - hue.floor()
  if hue < 1.0 / 6.0 {
    m1 + (m2 - m1) * hue * 6.0
  } else if hue < 0.5 {
    m2
  } else if hue < 2.0 / 3.0 {
    m1 + (m2 - m1) * (2.0 / 3.0 - hue) * 6.0
  } else {
    m1
  }
}

///|
/// Python's `colorsys.hls_to_rgb`.
pub fn hls_to_rgb(
  h : Double,
  l : Double,
  s : Double,
) -> (Double, Double, Double) {
  if s == 0.0 {
    return (l, l, l)
  }
  let m2 = if l <= 0.5 { l * (1.0 + s) } else { l + s - l * s }
  let m1 = 2.0 * l - m2
  (
    hls_value(m1, m2, h + 1.0 / 3.0),
    hls_value(m1, m2, h),
    hls_value(m1, m2, h - 1.0 / 3.0),
  )
}

///|
/// A renderable that shows a band of colors.
pub struct ColorBox {}

///|
pub impl @rich.Renderable for ColorBox with fn rich_console(
  _self,
  _console,
  options,
) {
  let out = []
  let width = options.max_width
  for y in 0..<5 {
    for x in 0..<width {
      let h = x.to_double() / width.to_double()
      let l = 0.1 + y.to_double() / 5.0 * 0.7
      let (r1, g1, b1) = hls_to_rgb(h, l, 1.0)
      let (r2, g2, b2) = hls_to_rgb(h, l + 0.7 / 10.0, 1.0)
      let bgcolor = @color.Color::from_rgb(r1 * 255.0, g1 * 255.0, b1 * 255.0)
      let color = @color.Color::from_rgb(r2 * 255.0, g2 * 255.0, b2 * 255.0)
      out.push(
        @rich.RenderItem::Seg(
          @rich.Segment::new("▄", style=@rich.Style::new(color~, bgcolor~)),
        ),
      )
    }
    out.push(Seg(@rich.Segment::line()))
  }
  out
}

///|
pub impl @rich.Renderable for ColorBox with fn rich_measure(
  _self,
  _console,
  options,
) {
  Some(@rich.Measurement::new(1, options.max_width))
}

///|
fn comparison(
  renderable1 : &@rich.Renderable,
  renderable2 : &@rich.Renderable,
) -> @rich.Table raise {
  let table = @rich.Table::new(
    show_header=false,
    pad_edge=false,
    no_box=true,
    expand=true,
  )
  table.add_column(header="1", ratio=1)
  table.add_column(header="2", ratio=1)
  table.add_row([renderable1, renderable2])
  table
}

///|
let code : String =
  #|def iter_last(values: Iterable[T]) -> Iterable[Tuple[bool, T]]:
  #|    """Iterate and generate a tuple with a flag for last value."""
  #|    iter_values = iter(values)
  #|    try:
  #|        previous_value = next(iter_values)
  #|    except StopIteration:
  #|        return
  #|    for value in iter_values:
  #|        yield False, previous_value
  #|        previous_value = value
  #|    yield True, previous_value

///|
let markdown_example : String = "# Markdown\n\nSupports much of the *markdown* __syntax__!\n\n- Headers\n- Basic formatting: **bold**, *italic*, `code`\n- Block quotes\n- Lists, and more...\n    "

///|
/// Get a renderable that demonstrates a number of features.
pub fn make_test_card() -> @rich.Table raise {
  let table = @rich.Table::grid(padding=[1], pad_edge=true)
  table.title = Some(Str("Rich features"))
  table.add_column(
    header="Feature",
    no_wrap=true,
    justify=Center,
    style="bold red",
  )
  table.add_column(header="Demonstration")
  let color_table = @rich.Table::new(
    no_box=true,
    expand=false,
    show_header=false,
    show_edge=false,
    pad_edge=false,
  )
  color_table.add_row([
    "✓ [bold green]4-bit color[/]\n✓ [bold blue]8-bit color[/]\n✓ [bold magenta]Truecolor (16.7 million)[/]\n✓ [bold yellow]Dumb terminals[/]\n✓ [bold cyan]Automatic color conversion",
    ColorBox::{ },
  ])
  table.add_row(["Colors", color_table])
  table.add_row([
    "Styles", "All ansi styles: [bold]bold[/], [dim]dim[/], [italic]italic[/italic], [underline]underline[/], [strike]strikethrough[/], [reverse]reverse[/], and even [blink]blink[/].",
  ])
  let lorem = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Quisque in metus sed sapien ultricies pretium a at justo. Maecenas luctus velit et auctor maximus."
  let lorem_table = @rich.Table::grid(padding=[1], collapse_padding=true)
  lorem_table.pad_edge = false
  lorem_table.add_row([
    @rich.Text::new(text=lorem, justify=Left, style="green"),
    @rich.Text::new(text=lorem, justify=Center, style="yellow"),
    @rich.Text::new(text=lorem, justify=Right, style="blue"),
    @rich.Text::new(text=lorem, justify=Full, style="red"),
  ])
  table.add_row([
    "Text",
    @rich.Group::new([
      @rich.Text::from_markup(
        "Word wrap text. Justify [green]left[/], [yellow]center[/], [blue]right[/] or [red]full[/].\n",
      ),
      lorem_table,
    ]),
  ])
  table.add_row([
    "Asian\nlanguage\nsupport", ":flag_for_china:  该库支持中文，日文和韩文文本！\n:flag_for_japan:  ライブラリは中国語、日本語、韓国語のテキストをサポートしています\n:flag_for_south_korea:  이 라이브러리는 중국어, 일본어 및 한국어 텍스트를 지원합니다",
  ])
  let markup_example = "[bold magenta]Rich[/] supports a simple [i]bbcode[/i]-like [b]markup[/b] for [yellow]color[/], [underline]style[/], and emoji! :+1: :apple: :ant: :bear: :baguette_bread: :bus: "
  table.add_row(["Markup", markup_example])
  let example_table = @rich.Table::new(
    show_edge=false,
    show_header=true,
    expand=false,
    row_styles=["none", "dim"],
    box_=@rich.box_simple,
  )
  example_table.add_column(header="[green]Date", style="green", no_wrap=true)
  example_table.add_column(header="[blue]Title", style="blue")
  example_table.add_column(
    header="[cyan]Production Budget",
    style="cyan",
    justify=Right,
    no_wrap=true,
  )
  example_table.add_column(
    header="[magenta]Box Office",
    style="magenta",
    justify=Right,
    no_wrap=true,
  )
  example_table.add_row([
    "Dec 20, 2019", "Star Wars: The Rise of Skywalker", "$275,000,000", "$375,126,118",
  ])
  example_table.add_row([
    "May 25, 2018", "[b]Solo[/]: A Star Wars Story", "$275,000,000", "$393,151,347",
  ])
  example_table.add_row([
    "Dec 15, 2017", "Star Wars Ep. VIII: The Last Jedi", "$262,000,000", "[bold]$1,332,539,889[/bold]",
  ])
  example_table.add_row([
    "May 19, 1999", "Star Wars Ep. [b]I[/b]: [i]The phantom Menace", "$115,000,000",
    "$1,027,044,677",
  ])
  table.add_row(["Tables", example_table])
  let pretty_data = @pretty.Dict::new([
    (
      "foo",
      [
        (3.1427 : &@pretty.PrettyRepr),
        @pretty.Tuple::new([
          "Paul Atreides", "Vladimir Harkonnen", "Thufir Hawat",
        ]),
      ],
    ),
    ("atomic", @pretty.Tuple::new([false, true, ()])),
  ])
  table.add_row([
    "Syntax\nhighlighting\n&\npretty\nprinting",
    comparison(
      @syntax.Syntax::new(
        code,
        "python3",
        line_numbers=true,
        indent_guides=true,
      ),
      @pretty.Pretty::new(pretty_data, indent_guides=true),
    ),
  ])
  table.add_row([
    "Markdown",
    comparison(
      "[cyan]" + markdown_example,
      @markdown.Markdown::new(markdown_example),
    ),
  ])
  table.add_row([
    "+more!", "Progress bars, columns, styled logging handler, tracebacks, etc...",
  ])
  table
}
