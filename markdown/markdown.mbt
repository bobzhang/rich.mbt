// Port of rich/markdown.py: the Markdown renderable.

///|
/// A Markdown renderable.
///
/// Parses CommonMark with GFM tables and strikethrough (as upstream's
/// `MarkdownIt().enable("strikethrough").enable("table")`) and renders it
/// with the `markdown.*` theme styles.
pub struct Markdown {
  /// The markdown source.
  markup : String
  /// The markdown-it token stream (see `parse_tokens`).
  parsed : Array[Token]
  /// Pygments theme for code blocks.
  code_theme : String
  /// Justify value for paragraphs.
  justify : @rich.JustifyMethod?
  /// Style applied to the whole document.
  style : @rich.StyleType
  /// Whether links are rendered as terminal hyperlinks.
  hyperlinks : Bool
  /// Lexer for inline code highlighting (none: no highlighting).
  inline_code_lexer : String?
  /// Pygments theme for inline code highlighting.
  inline_code_theme : String
}

///|
/// Create a Markdown renderable.
///
/// * `code_theme`: Pygments theme for code blocks.
/// * `justify`: justify value for paragraphs.
/// * `style`: optional style to apply to the markdown.
/// * `hyperlinks`: enable hyperlinks.
/// * `inline_code_lexer`: lexer to use for inline code highlighting.
/// * `inline_code_theme`: Pygments theme for inline code highlighting
///   (defaults to `code_theme`).
pub fn Markdown::new(
  markup : String,
  code_theme? : String = "monokai",
  justify? : @rich.JustifyMethod,
  style? : &@rich.IntoStyle,
  hyperlinks? : Bool = true,
  inline_code_lexer? : String,
  inline_code_theme? : String,
) -> Markdown {
  {
    markup,
    parsed: parse_tokens(markup),
    code_theme,
    justify,
    style: match style {
      Some(s) => s.into_style_type()
      None => Def("none")
    },
    hyperlinks,
    inline_code_lexer,
    inline_code_theme: match inline_code_theme {
      Some(t) if t != "" => t
      _ => code_theme
    },
  }
}

///|
/// Manages the render state (upstream `MarkdownContext`).
priv struct Context {
  console : @rich.Console
  options : @rich.ConsoleOptions
  style_stack : @rich.StyleStack
  stack : Array[Element]
  syntax : @syntax.Syntax?
  /// Number of styles entered (and not left).
  mut depth : Int
}

///|
fn Context::new(
  console : @rich.Console,
  options : @rich.ConsoleOptions,
  style : @rich.Style,
  inline_code_lexer : String?,
  inline_code_theme : String,
) -> Context raise {
  let syntax = match inline_code_lexer {
    Some(lexer) => Some(@syntax.Syntax::new("", lexer, theme=inline_code_theme))
    None => None
  }
  {
    console,
    options,
    style_stack: @rich.StyleStack::new(style),
    stack: [],
    syntax,
    depth: 0,
  }
}

///|
/// Current style which is the product of all styles on the stack.
fn Context::current_style(self : Context) -> @rich.Style {
  self.style_stack.current()
}

///|
fn Context::top(self : Context) -> Element {
  self.stack[self.stack.length() - 1]
}

///|
/// Called when the parser visits text.
fn Context::on_text(
  self : Context,
  text : String,
  node_type : String,
) -> Unit raise {
  match self.syntax {
    Some(syntax) if node_type is ("fence" | "code_inline") => {
      let highlight_text = syntax.highlight(text)
      highlight_text.rstrip()
      self
      .top()
      .on_text(
        self,
        Text(
          @rich.Text::assemble(
            [highlight_text],
            style=self.style_stack.current(),
          ),
        ),
      )
    }
    _ => self.top().on_text(self, Str(text))
  }
}

///|
/// Enter a style context.
fn Context::enter_style(
  self : Context,
  style_name : &@rich.IntoStyle,
) -> @rich.Style raise {
  let style = self.console.get_style(style_name, default=Def("none"))
  self.style_stack.push(style)
  self.depth += 1
  self.current_style()
}

///|
/// Leave a style context. Raises (where upstream raises `IndexError`) when
/// leaving more styles than were entered, e.g. on an unbalanced `</kbd>`.
fn Context::leave_style(self : Context) -> @rich.Style raise {
  if self.depth == 0 {
    raise @rich.StyleStackError("pop from empty style stack")
  }
  self.depth -= 1
  self.style_stack.pop()
}

///|
let inline_style_tags : Array[String] = ["em", "strong", "code", "s"]

///|
pub impl @rich.Renderable for Markdown with fn rich_console(
  self,
  console,
  options,
) {
  let style = console.get_style(self.style, default=Def("none"))
  let options = options.update(height=None)
  let context = Context::new(
    console,
    options,
    style,
    self.inline_code_lexer,
    self.inline_code_theme,
  )
  let out : Array[@rich.RenderItem] = []
  let mut new_line = false
  let new_line_segment = @rich.Segment::line()
  fn emit(element : Element) raise {
    for s in console.render(element, options=context.options) {
      out.push(Seg(s))
    }
  }

  for token in self.parsed {
    let node_type = token.type_
    let tag = token.tag
    let entering = token.nesting == 1
    let exiting = token.nesting == -1
    let self_closing = token.nesting == 0
    if node_type == "text" {
      context.on_text(token.content, node_type)
    } else if node_type == "hardbreak" {
      context.on_text("\n", node_type)
    } else if node_type == "softbreak" {
      context.on_text(" ", node_type)
    } else if node_type == "link_open" {
      let href = token.attrs.get("href").unwrap_or("")
      if self.hyperlinks {
        let link_style = console.get_style(
            "markdown.link_url",
            default=Def("none"),
          ) +
          @rich.Style::new(link=href)
        context.enter_style(link_style) |> ignore
      } else {
        context.stack.push(Element::link(token))
      }
    } else if node_type == "html_inline" {
      if token.content == "<kbd>" {
        let kbd_style = console.get_style("markdown.kbd", default=Def("bold"))
        context.enter_style(kbd_style) |> ignore
      } else if token.content == "</kbd>" {
        context.leave_style() |> ignore
      } else {
        continue
      }
    } else if node_type == "link_close" {
      if self.hyperlinks {
        context.leave_style() |> ignore
      } else {
        guard context.stack.pop() is Some(element) && element.kind is Link(href) else {
          raise @rich.ValueError("expected a link element")
        }
        let link_style = console.get_style("markdown.link", default=Def("none"))
        context.enter_style(link_style) |> ignore
        context.on_text(element.text.plain(), node_type)
        context.leave_style() |> ignore
        context.on_text(" (", node_type)
        let link_url_style = console.get_style(
          "markdown.link_url",
          default=Def("none"),
        )
        context.enter_style(link_url_style) |> ignore
        context.on_text(href, node_type)
        context.leave_style() |> ignore
        context.on_text(")", node_type)
      }
    } else if inline_style_tags.contains(tag) &&
      node_type != "fence" &&
      node_type != "code_block" {
      if entering {
        context.enter_style("markdown.\{tag}") |> ignore
      } else if exiting {
        context.leave_style() |> ignore
      } else {
        context.enter_style("markdown.\{tag}") |> ignore
        if token.content != "" {
          context.on_text(token.content, node_type)
        }
        context.leave_style() |> ignore
      }
    } else {
      let mut element = Element::create(self, token)
      if entering || self_closing {
        context.stack.push(element)
        element.on_enter(context)
      }
      if exiting {
        element = context.stack.pop().unwrap()
        let should_render = context.stack.is_empty() ||
          context.top().on_child_close(context, element)
        if should_render {
          if new_line {
            out.push(Seg(new_line_segment))
          }
          emit(element)
        }
      } else if self_closing {
        context.stack.pop() |> ignore
        element.on_text(context, Str(token.content))
        let should_render = context.stack.is_empty() ||
          context.top().on_child_close(context, element)
        if should_render {
          if new_line && node_type != "inline" {
            out.push(Seg(new_line_segment))
          }
          emit(element)
        }
      }
      if exiting || self_closing {
        element.on_leave(context)
        new_line = element.new_line()
      }
    }
  }
  out
}
