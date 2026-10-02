// rich-cli's help screen (`RichCommand.format_help`).

///|
/// `highlighter(text)`: a highlighted copy.
fn highlighted(
  highlighter : &@rich.Highlighter,
  text : @rich.Text,
) -> @rich.Text raise {
  let copy = text.copy()
  highlighter.highlight(copy)
  copy
}

///|
/// `blend_text`: color each character, blending from `color1` to `color2`.
fn blend_text(
  message : String,
  color1 : (Int, Int, Int),
  color2 : (Int, Int, Int),
) -> @rich.Text {
  let text = @rich.Text::new(text=message)
  let (r1, g1, b1) = color1
  let (r2, g2, b2) = color2
  let size = text.length()
  fn hex(start : Int, delta : Int, blend : Double) -> String {
    let v = (start.to_double() + delta.to_double() * blend).to_int()
    let digits = "0123456789ABCDEF"
    "\{digits[v / 16:v / 16 + 1]}\{digits[v % 16:v % 16 + 1]}"
  }

  for index in 0..<size {
    let blend = index.to_double() / size.to_double()
    let color = "#\{hex(r1, r2 - r1, blend)}\{hex(g1, g2 - g1, blend)}\{hex(b1, b2 - b1, blend)}"
    text.stylize(color, start=index, end=index + 1)
  }
  text
}

///|
/// Print the help screen to `file`.
fn render_help(
  file : @rich.StringIO,
  environ : Map[String, String]?,
) -> Unit raise {
  let highlighter = @rich.RegexHighlighter::new([
    "(?P<switch>\\-\\w)", "(?P<option>\\-\\-[\\w\\-]+)",
  ])
  let console = @rich.Console::new(
    file~,
    theme=@rich.Theme::new(styles={
      "option": "bold cyan",
      "switch": "bold green",
    }),
    highlighter~,
    legacy_windows=false,
    environ?,
  )
  console.print(
    "[b]Rich CLI[/b] [magenta]v\{VERSION}[/] 🤑\n\n[dim]Rich text and formatting in the terminal\n",
    justify=Center,
  )
  console.print(
    "Usage: [b]rich[/b] [b][OPTIONS][/] [b cyan]<PATH,TEXT,URL, or '-'>\n",
  )
  let options_table = @rich.Table::new(
    highlight=true,
    no_box=true,
    show_header=false,
  )
  for param in params {
    let (opt1, opt2) = if param.opts.length() == 2 {
      (
        highlighted(highlighter, @rich.Text::new(text=param.opts[1])),
        highlighted(highlighter, @rich.Text::new(text=param.opts[0])),
      )
    } else {
      (
        @rich.Text::new(text=""),
        highlighted(highlighter, @rich.Text::new(text=param.opts[0])),
      )
    }
    let opt2 = match param.metavar {
      Some(metavar) =>
        opt2
        .copy()
        .append_text(@rich.Text::new(text=" \{metavar}", style="bold yellow"))
      None => opt2
    }
    let help = @rich.Text::from_markup(param.help_record(), emoji=false)
    options_table.add_row([opt1, opt2, highlighted(highlighter, help)])
  }
  console.print(
    @panel.Panel::new(
      options_table,
      border_style="dim",
      title="Options",
      title_align=Left,
    ),
  )
  console.print(
    blend_text(
      "♥ https://www.textualize.io",
      (0xb1, 0x69, 0xdd),
      (0x54, 0x2c, 0x91),
    ),
    justify=Left,
    style="bold",
  )
  // click echoes the (empty) formatter output
  file.write("\n")
}
