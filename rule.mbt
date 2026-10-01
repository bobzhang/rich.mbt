// Port of rich/rule.py.

///|
/// A console renderable to draw a horizontal rule (line).
pub struct Rule {
  title : TextType
  characters : String
  style : StyleType
  end : String
  align : AlignMethod
}

///|
pub fn Rule::new(
  title? : &IntoText,
  characters? : String = "─",
  style? : &IntoStyle,
  end? : String = "\n",
  align? : AlignMethod = Center,
) -> Rule raise RichError {
  if @cells.cell_len(characters) < 1 {
    raise ValueError(
      "'characters' argument must have a cell width of at least 1",
    )
  }
  {
    title: match title {
      Some(t) => t.into_text_type()
      None => Str("")
    },
    characters,
    style: match style {
      Some(s) => s.into_style_type()
      None => Def("rule.line")
    },
    end,
    align,
  }
}

///|
pub fn Rule::repr(self : Rule) -> String {
  let title = match self.title {
    Str(s) => py_repr(s)
    Text(t) => t.repr()
  }
  "Rule(\{title}, \{py_repr(self.characters)})"
}

///|
fn is_ascii(s : String) -> Bool {
  for i in 0..<s.length() {
    if s[i].to_int() > 127 {
      return false
    }
  }
  true
}

///|
fn Rule::rule_line(self : Rule, chars_len : Int, width : Int) -> Text {
  let rule_text = Text::new(
    text=self.characters.repeat(floor_div(width, chars_len) + 1),
    style=self.style,
  )
  rule_text.truncate(width)
  rule_text.set_plain(@cells.set_cell_size(rule_text.plain(), width))
  rule_text
}

///|
pub impl Renderable for Rule with fn rich_console(self, console, options) {
  let width = options.max_width
  let characters = if options.ascii_only() && !is_ascii(self.characters) {
    "-"
  } else {
    self.characters
  }
  let chars_len = @cells.cell_len(characters)
  if !self.title.to_bool() {
    return [Child(self.rule_line(chars_len, width))]
  }
  let title_text = match self.title {
    Text(t) => t
    Str(s) => console.render_str(s, style="rule.text")
  }
  title_text.set_plain(title_text.plain().replace_all(old="\n", new=" "))
  title_text.expand_tabs()
  let required_space = if self.align == Center { 4 } else { 2 }
  let truncate_width = @cmp.maximum(0, width - required_space)
  if truncate_width == 0 {
    return [Child(self.rule_line(chars_len, width))]
  }
  let rule_text = Text::new(end=self.end)
  match self.align {
    Center => {
      title_text.truncate(truncate_width, overflow=Ellipsis)
      let side_width = floor_div(width - @cells.cell_len(title_text.plain()), 2)
      let left = Text::new(
        text=characters.repeat(floor_div(side_width, chars_len) + 1),
      )
      left.truncate(side_width - 1)
      let right_length = width -
        @cells.cell_len(left.plain()) -
        @cells.cell_len(title_text.plain())
      let right = Text::new(
        text=characters.repeat(floor_div(side_width, chars_len) + 1),
      )
      right.truncate(right_length)
      rule_text.append_str(left.plain() + " ", style=self.style) |> ignore
      rule_text.append_text(title_text) |> ignore
      rule_text.append_str(" " + right.plain(), style=self.style) |> ignore
    }
    Left => {
      title_text.truncate(truncate_width, overflow=Ellipsis)
      rule_text.append_text(title_text) |> ignore
      rule_text.append_str(" ") |> ignore
      rule_text.append_str(
        characters.repeat(@cmp.maximum(0, width - rule_text.cell_len())),
        style=self.style,
      )
      |> ignore
    }
    Right => {
      title_text.truncate(truncate_width, overflow=Ellipsis)
      rule_text.append_str(
        characters.repeat(@cmp.maximum(0, width - title_text.cell_len() - 1)),
        style=self.style,
      )
      |> ignore
      rule_text.append_str(" ") |> ignore
      rule_text.append_text(title_text) |> ignore
    }
  }
  rule_text.set_plain(@cells.set_cell_size(rule_text.plain(), width))
  [Child(rule_text)]
}

///|
pub impl Renderable for Rule with fn rich_measure(_self, _console, _options) {
  Some({ minimum: 1, maximum: 1, })
}
