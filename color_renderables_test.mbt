// Ports of the root-package parts of tests/test_color.py and
// tests/test_palette.py (`__rich__` of Color and Palette).

///|
fn render_to_string(obj : &@rich.Renderable, width? : Int = 60) -> String raise {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    file~,
    width~,
    color_system=Some("truecolor"),
    force_terminal=true,
    legacy_windows=false,
    environ={},
  )
  console.print(obj)
  file.getvalue()
}

///|
test "color rich" {
  let red = color("red")
  let as_text = @rich.color_to_text(red)
  assert_eq(
    as_text,
    @rich.Text::new(text="<color 'red' (standard)⬤ >", spans=[
      @rich.Span::new(23, 24, @rich.Style::new(color=red)),
    ]),
  )
  inspect(as_text.markup(), content="<color 'red' (standard)[red]⬤[/red] >")
}

///|
test "color renderable (oracle)" {
  assert_eq(
    render_to_string(color("red")),
    "<color 'red' (standard)\u{1b}[31m⬤\u{1b}[0m >\n",
  )
  assert_eq(
    render_to_string(color("#123456")),
    "<color '#123456' (truecolor)\u{1b}[38;2;18;52;86m⬤\u{1b}[0m >\n",
  )
  assert_eq(
    render_to_string(color("color(100)")),
    "<color 'color(100)' (eight_bit)\u{1b}[38;5;100m⬤\u{1b}[0m >\n",
  )
}

///|
test "palette rich_cast" {
  let table = @rich.palette_to_table(@color.standard_palette)
  inspect(table.row_count(), content="16")
}

///|
test "palette renderable (oracle)" {
  let palette = @color.Palette::new([(255, 0, 0), (0, 128, 255)])
  assert_eq(
    render_to_string(palette),
    "\u{1b}[3m                  Palette                   \u{1b}[0m\n┏━━━━━━━┳━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━┓\n┃\u{1b}[1m \u{1b}[0m\u{1b}[1mindex\u{1b}[0m\u{1b}[1m \u{1b}[0m┃\u{1b}[1m \u{1b}[0m\u{1b}[1mRGB          \u{1b}[0m\u{1b}[1m \u{1b}[0m┃\u{1b}[1m \u{1b}[0m\u{1b}[1mColor           \u{1b}[0m\u{1b}[1m \u{1b}[0m┃\n┡━━━━━━━╇━━━━━━━━━━━━━━━╇━━━━━━━━━━━━━━━━━━┩\n│ \u{1b}[1;36m0\u{1b}[0m     │ \u{1b}[1m(\u{1b}[0m\u{1b}[1;36m255\u{1b}[0m, \u{1b}[1;36m0\u{1b}[0m, \u{1b}[1;36m0\u{1b}[0m\u{1b}[1m)\u{1b}[0m   │ \u{1b}[48;2;255;0;0m                \u{1b}[0m │\n│ \u{1b}[1;36m1\u{1b}[0m     │ \u{1b}[1m(\u{1b}[0m\u{1b}[1;36m0\u{1b}[0m, \u{1b}[1;36m128\u{1b}[0m, \u{1b}[1;36m255\u{1b}[0m\u{1b}[1m)\u{1b}[0m │ \u{1b}[48;2;0;128;255m                \u{1b}[0m │\n└───────┴───────────────┴──────────────────┘\n\u{1b}[2;3m                                    2 colors\u{1b}[0m\n",
  )
}
