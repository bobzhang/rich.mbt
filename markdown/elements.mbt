// Port of the MarkdownElement classes of rich/markdown.py.

///|
priv enum Kind {
  Unknown
  Paragraph
  Heading(String)
  CodeBlock(
    String,
    String,
    ((String, String, String) -> &@rich.Renderable raise)?
  )
  BlockQuote
  HorizontalRule
  TableElement
  TableHeader
  TableBody
  TableRow
  TableData
  ListElement(String, Int)
  ListItem
  Link(String)
  ImageItem(String, Bool)
}

///|
/// One element of the upstream class hierarchy. Fields not used by a kind
/// keep their initial values.
priv struct Element {
  kind : Kind
  /// `TextElement.style` (set when entered).
  mut style : @rich.Style
  /// `TextElement.text`.
  mut text : @rich.Text
  /// Paragraph / table cell justification.
  justify : @rich.JustifyMethod
  /// Children of block quotes and list items (`Renderables`).
  elements : Array[&@rich.Renderable]
  /// Table header / body.
  mut header : Element?
  mut body : Element?
  /// Header row, body rows, row cells, list items.
  mut row : Element?
  rows : Array[Element]
  cells : Array[Element]
  items : Array[Element]
  /// Table cell content.
  content : @rich.Text
  /// Image link from the enclosing style.
  mut link : String?
}

///|
fn Element::new(
  kind : Kind,
  text? : @rich.Text = @rich.Text::new(),
  justify? : @rich.JustifyMethod = Default,
) -> Element {
  {
    kind,
    style: @rich.Style::null(),
    text,
    justify,
    elements: [],
    header: None,
    body: None,
    row: None,
    rows: [],
    cells: [],
    items: [],
    content: @rich.Text::new(justify~),
    link: None,
  }
}

///|
/// `MarkdownElement.new_line`.
fn Element::new_line(self : Element) -> Bool {
  !(self.kind is (HorizontalRule | ImageItem(_)))
}

///|
/// Subclasses of `TextElement`.
fn Element::is_text_element(self : Element) -> Bool {
  self.kind
  is (Paragraph
  | Heading(_)
  | CodeBlock(_)
  | BlockQuote
  | ListItem
  | Link(_)
  | ImageItem(_))
}

///|
fn Element::style_name(self : Element) -> String {
  match self.kind {
    Paragraph => "markdown.paragraph"
    Heading(tag) => "markdown.\{tag}"
    CodeBlock(_) => "markdown.code_block"
    BlockQuote => "markdown.block_quote"
    ListItem => "markdown.item"
    _ => "none"
  }
}

///|
/// `MarkdownElement.create`.
fn Element::create(markdown : Markdown, token : Token) -> Element {
  match token.type_ {
    "paragraph_open" =>
      Element::new(Paragraph, justify=markdown.justify.unwrap_or(Left))
    "heading_open" => Element::new(Heading(token.tag))
    "fence" | "code_block" => {
      let info = token.info
      let lexer_name = match info.find(" ") {
        Some(i) => substr(info, 0, end=i)
        None => info
      }
      Element::new(
        CodeBlock(
          if lexer_name == "" && !markdown.code_renderers.contains(token.type_) {
            "text"
          } else {
            lexer_name
          },
          markdown.code_theme,
          markdown.code_renderers.get(token.type_),
        ),
      )
    }
    "blockquote_open" => Element::new(BlockQuote)
    "hr" => Element::new(HorizontalRule)
    "bullet_list_open" | "ordered_list_open" => {
      let start = match token.attrs.get("start") {
        Some(s) => @string.parse_int(s) catch { _ => 1 }
        None => 1
      }
      Element::new(ListElement(token.type_, start))
    }
    "list_item_open" => Element::new(ListItem)
    "image" =>
      Element::new(
        ImageItem(token.attrs.get("src").unwrap_or(""), markdown.hyperlinks),
      )
    "table_open" => Element::new(TableElement)
    "tbody_open" => Element::new(TableBody)
    "thead_open" => Element::new(TableHeader)
    "tr_open" => Element::new(TableRow)
    "td_open" | "th_open" => {
      let style = token.attrs.get("style").unwrap_or("None")
      let justify : @rich.JustifyMethod = if style.contains("text-align:right") {
        Right
      } else if style.contains("text-align:center") {
        Center
      } else if style.contains("text-align:left") {
        Left
      } else {
        Default
      }
      Element::new(TableData, justify~)
    }
    _ => Element::new(Unknown)
  }
}

///|
/// `Link.create`.
fn Element::link(token : Token) -> Element {
  let href = token.attrs.get("href").unwrap_or("#")
  Element::new(Link(href), text=@rich.Text::new(text=token.content))
}

///|
/// `MarkdownElement.on_enter`.
fn Element::on_enter(self : Element, context : Context) -> Unit raise {
  match self.kind {
    Heading(_) => {
      self.text = @rich.Text::new()
      context.enter_style(self.style_name()) |> ignore
    }
    ImageItem(_) => {
      self.link = context.current_style().link()
      self.text = @rich.Text::new(justify=Left)
      self.style = context.enter_style(self.style_name())
      self.text = @rich.Text::new(justify=Left)
    }
    _ if self.is_text_element() => {
      self.style = context.enter_style(self.style_name())
      self.text = @rich.Text::new(justify=Left)
    }
    _ => ()
  }
}

///|
/// `MarkdownElement.on_text`.
fn Element::on_text(
  self : Element,
  context : Context,
  text : @rich.TextType,
) -> Unit {
  match self.kind {
    TableData =>
      match text {
        Str(s) =>
          self.content.append_str(s, style=context.current_style()) |> ignore
        Text(t) => self.content.append_text(t) |> ignore
      }
    _ if self.is_text_element() =>
      match text {
        Str(s) =>
          self.text.append_str(s, style=context.current_style()) |> ignore
        Text(t) => self.text.append_text(t) |> ignore
      }
    _ => ()
  }
}

///|
/// `MarkdownElement.on_leave`.
fn Element::on_leave(self : Element, context : Context) -> Unit raise {
  if self.is_text_element() {
    context.leave_style() |> ignore
  }
}

///|
/// `MarkdownElement.on_child_close`: whether the child should be rendered
/// directly (`false` when the parent takes it over).
fn Element::on_child_close(
  self : Element,
  _context : Context,
  child : Element,
) -> Bool raise {
  match self.kind {
    BlockQuote | ListItem => {
      self.elements.push(child)
      false
    }
    TableElement =>
      match child.kind {
        TableHeader => {
          self.header = Some(child)
          false
        }
        TableBody => {
          self.body = Some(child)
          false
        }
        _ => raise @rich.ValueError("Couldn't process markdown table.")
      }
    TableHeader => {
      self.row = Some(child)
      false
    }
    TableBody => {
      self.rows.push(child)
      false
    }
    TableRow => {
      self.cells.push(child)
      false
    }
    ListElement(_) => {
      self.items.push(child)
      false
    }
    _ => true
  }
}

///|
/// Python `str.rstrip()`.
fn py_rstrip(s : String) -> String {
  s.trim_end(chars=py_whitespace).to_owned()
}

///|
impl @rich.Renderable for Element with fn rich_console(self, console, options) {
  match self.kind {
    Paragraph => {
      self.text.justify = Some(self.justify)
      [Child(self.text)]
    }
    Heading(tag) => {
      let text = self.text.copy()
      text.justify = Some(if tag == "h1" { Center } else { Left })
      [Child(text)]
    }
    CodeBlock(lexer_name, theme, renderer) => {
      let code = py_rstrip(self.text.plain())
      if renderer is Some(render) {
        return [Child(render(code, lexer_name, theme))]
      }
      let syntax = @syntax.Syntax::new(
        code,
        lexer_name,
        theme~,
        word_wrap=true,
        padding=[1],
      )
      [Child(syntax)]
    }
    BlockQuote => {
      let render_options = options.update(width=options.max_width - 4)
      let lines = console.render_lines(
        @rich.Renderables::new(renderables=self.elements),
        options=render_options,
        style=self.style,
      )
      let new_line = @rich.Segment::new("\n")
      let padding = @rich.Segment::new("▌ ", style=self.style)
      let out : Array[@rich.RenderItem] = []
      for line in lines {
        out.push(Seg(padding))
        for s in line {
          out.push(Seg(s))
        }
        out.push(Seg(new_line))
      }
      out
    }
    HorizontalRule => {
      let style = console.get_style("markdown.hr", default=Def("none"))
      [Child(@rich.Rule::new(style~, characters="-")), Child(@rich.Text::new())]
    }
    TableElement => {
      let table = @rich.Table::new(
        box_=@rich.box_simple,
        pad_edge=false,
        style="markdown.table.border",
        show_edge=true,
        collapse_padding=true,
      )
      if self.header is Some(header) && header.row is Some(row) {
        for column in row.cells {
          let heading = column.content.copy()
          heading.stylize("markdown.table.header")
          table.add_column(header=heading)
        }
      }
      if self.body is Some(body) {
        for row in body.rows {
          let row_content : Array[&@rich.Renderable] = row.cells.map(element => {
            (element.content : &@rich.Renderable)
          })
          table.add_row(row_content)
        }
      }
      [Child(table)]
    }
    ListElement(list_type, list_start) => {
      let out : Array[@rich.RenderItem] = []
      if list_type == "bullet_list_open" {
        for item in self.items {
          out.append(item.render_bullet(console, options))
        }
      } else {
        let number = list_start
        let last_number = number + self.items.length()
        for index, item in self.items {
          out.append(
            item.render_number(console, options, number + index, last_number),
          )
        }
      }
      out
    }
    ImageItem(destination, hyperlinks) => {
      let link = match self.link {
        Some(l) if l != "" => Some(l)
        _ => if destination != "" { Some(destination) } else { None }
      }
      let link_style = match link {
        Some(l) => @rich.Style::new(link=l)
        None => @rich.Style::new()
      }
      let title = if self.text.to_bool() {
        self.text
      } else {
        let stripped = destination.trim(chars="/").to_owned()
        let name = match stripped.rev_find("/") {
          Some(i) => substr(stripped, i + 1)
          None => stripped
        }
        @rich.Text::new(text=name)
      }
      if hyperlinks {
        title.stylize(link_style)
      }
      [Child(@rich.Text::assemble(["🌆 ", title, " "], end=""))]
    }
    _ => []
  }
}

///|
/// `ListItem.render_bullet`.
fn Element::render_bullet(
  self : Element,
  console : @rich.Console,
  options : @rich.ConsoleOptions,
) -> Array[@rich.RenderItem] raise {
  let render_options = options.update(width=options.max_width - 3)
  let lines = console.render_lines(
    @rich.Renderables::new(renderables=self.elements),
    options=render_options,
    style=self.style,
  )
  let bullet_style = console.get_style(
    "markdown.item.bullet",
    default=Def("none"),
  )
  let bullet = @rich.Segment::new(" • ", style=bullet_style)
  let padding = @rich.Segment::new("   ", style=bullet_style)
  let new_line = @rich.Segment::new("\n")
  let out : Array[@rich.RenderItem] = []
  for i, line in lines {
    out.push(Seg(if i == 0 { bullet } else { padding }))
    for s in line {
      out.push(Seg(s))
    }
    out.push(Seg(new_line))
  }
  out
}

///|
/// `ListItem.render_number`.
fn Element::render_number(
  self : Element,
  console : @rich.Console,
  options : @rich.ConsoleOptions,
  number : Int,
  last_number : Int,
) -> Array[@rich.RenderItem] raise {
  let number_width = last_number.to_string().length() + 2
  let render_options = options.update(width=options.max_width - number_width)
  let lines = console.render_lines(
    @rich.Renderables::new(renderables=self.elements),
    options=render_options,
    style=self.style,
  )
  let number_style = console.get_style(
    "markdown.item.number",
    default=Def("none"),
  )
  let new_line = @rich.Segment::new("\n")
  let padding = @rich.Segment::new(" ".repeat(number_width), style=number_style)
  let label = number.to_string()
  let numeral = @rich.Segment::new(
    " ".repeat(number_width - 1 - label.length()) + label + " ",
    style=number_style,
  )
  let out : Array[@rich.RenderItem] = []
  for i, line in lines {
    out.push(Seg(if i == 0 { numeral } else { padding }))
    for s in line {
      out.push(Seg(s))
    }
    out.push(Seg(new_line))
  }
  out
}
