// Port of `Pretty`, `pretty_repr` and `pprint` from rich/pretty.py.

///|
/// Prettify a repr by expanding on to new lines to fit within `max_width`.
///
/// ```mbt check
/// test {
///   let data : Map[String, Array[Int]] = { "foo": [1, 2, 3], "bar": [] }
///   inspect(@pretty.pretty_repr(data), content="{'foo': [1, 2, 3], 'bar': []}")
///   inspect(
///     @pretty.pretty_repr(data, max_width=16),
///     content=(
///       #|{
///       #|    'foo': [
///       #|        1,
///       #|        2,
///       #|        3
///       #|    ],
///       #|    'bar': []
///       #|}
///     ),
///   )
/// }
/// ```
pub fn[T : PrettyRepr] pretty_repr(
  value : T,
  max_width? : Int = 80,
  indent_size? : Int = 4,
  max_length? : Int,
  max_string? : Int,
  max_depth? : Int,
  expand_all? : Bool = false,
) -> String {
  traverse(value, max_length?, max_string?, max_depth?).render(
    max_width~,
    indent_size~,
    expand_all~,
  )
}

///|
/// A renderable that pretty prints a value.
pub(all) struct Pretty {
  mut value : &PrettyRepr
  mut highlighter : &@rich.Highlighter
  mut indent_size : Int
  mut justify : @rich.JustifyMethod?
  mut overflow : @rich.OverflowMethod?
  mut no_wrap : Bool?
  mut indent_guides : Bool
  mut max_length : Int?
  mut max_string : Int?
  mut max_depth : Int?
  mut expand_all : Bool
  mut margin : Int
  mut insert_line : Bool
}

///|
/// Create a pretty renderable.
///
/// * `highlighter`: defaults to `ReprHighlighter`.
/// * `indent_size`: number of spaces in an indent.
/// * `no_wrap`: `None` to use the console option.
/// * `indent_guides`: draw indentation guides.
/// * `max_length` / `max_string` / `max_depth`: abbreviate containers,
///   strings and deep structures.
/// * `expand_all`: expand all containers.
/// * `margin`: subtract a margin from the width to force containers to
///   expand earlier.
/// * `insert_line`: insert a blank line before a multi-line repr.
pub fn Pretty::new(
  value : &PrettyRepr,
  highlighter? : &@rich.Highlighter,
  indent_size? : Int = 4,
  justify? : @rich.JustifyMethod,
  overflow? : @rich.OverflowMethod,
  no_wrap? : Bool? = Some(false),
  indent_guides? : Bool = false,
  max_length? : Int,
  max_string? : Int,
  max_depth? : Int,
  expand_all? : Bool = false,
  margin? : Int = 0,
  insert_line? : Bool = false,
) -> Pretty {
  {
    value,
    highlighter: match highlighter {
      Some(h) => h
      None => @rich.ReprHighlighter::new()
    },
    indent_size,
    justify,
    overflow,
    no_wrap,
    indent_guides,
    max_length,
    max_string,
    max_depth,
    expand_all,
    margin,
    insert_line,
  }
}

///|
fn Pretty::repr(self : Pretty, max_width : Int) -> String {
  traverse(
    self.value,
    max_length?=self.max_length,
    max_string?=self.max_string,
    max_depth?=self.max_depth,
  ).render(max_width~, indent_size=self.indent_size, expand_all=self.expand_all)
}

///|
pub impl @rich.Renderable for Pretty with fn rich_console(
  self,
  _console,
  options,
) {
  let pretty_str = self.repr(options.max_width - self.margin)
  let pretty_text = @rich.Text::from_ansi(
    pretty_str,
    justify?=match self.justify {
      Some(j) => Some(j)
      None => options.justify
    },
    overflow?=match self.overflow {
      Some(o) => Some(o)
      None => options.overflow
    },
    no_wrap=@rich.pick_bool([self.no_wrap, options.no_wrap]),
    style="pretty",
  )
  let pretty_text = if pretty_text.to_bool() {
    self.highlighter.apply(pretty_text)
  } else {
    @rich.Text::new(text="__repr__ returned empty string", style="dim italic")
  }
  let pretty_text = if self.indent_guides && !options.ascii_only() {
    pretty_text.with_indent_guides(
      indent_size=self.indent_size,
      style="repr.indent",
    )
  } else {
    pretty_text
  }
  let result : Array[@rich.RenderItem] = []
  if self.insert_line && pretty_text.plain().contains("\n") {
    result.push(Child(""))
  }
  result.push(Child(pretty_text))
  result
}

///|
pub impl @rich.Renderable for Pretty with fn rich_measure(
  self,
  _console,
  options,
) {
  let pretty_str = self.repr(options.max_width)
  let mut text_width = 0
  if pretty_str != "" {
    for line in @pystr.splitlines(pretty_str) {
      let width = @cells.cell_len(line)
      if width > text_width {
        text_width = width
      }
    }
  }
  Some(@rich.Measurement::new(text_width, text_width))
}

///|
/// A convenience function for pretty printing (with indentation guides by
/// default) to `console`, or to the global console.
pub fn[T : PrettyRepr] pprint(
  value : T,
  console? : @rich.Console,
  indent_guides? : Bool = true,
  max_length? : Int,
  max_string? : Int,
  max_depth? : Int,
  expand_all? : Bool = false,
) -> Unit raise {
  let console = match console {
    Some(c) => c
    None => @rich.get_console()
  }
  console.print(
    Pretty::new(
      value,
      max_length?,
      max_string?,
      max_depth?,
      indent_guides~,
      expand_all~,
      overflow=Ignore,
    ),
    soft_wrap=true,
  )
}
