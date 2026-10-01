// The layout placeholder (upstream `_Placeholder`) and the pretty repr of
// a layout (upstream `Pretty(layout)`).

///|
/// Upstream `Pretty(layout)`: the pretty repr of a layout, highlighted with
/// `ReprHighlighter`.
priv struct LayoutPretty {
  layout : Layout
}

///|
impl @rich.Renderable for LayoutPretty with fn rich_console(
  self,
  _console,
  options,
) {
  let pretty_str = self.layout.pretty_repr(max_width=options.max_width)
  let pretty_text = @rich.Text::from_ansi(
    pretty_str,
    justify?=options.justify,
    overflow?=options.overflow,
    no_wrap=@rich.pick_bool([Some(false), options.no_wrap]),
    style="pretty",
  )
  let highlighter : &@rich.Highlighter = @rich.ReprHighlighter::new()
  highlighter.highlight(pretty_text)
  [Child(pretty_text)]
}

///|
impl @rich.Renderable for LayoutPretty with fn rich_measure(
  self,
  _console,
  options,
) {
  let pretty_str = self.layout.pretty_repr(max_width=options.max_width)
  let mut text_width = 0
  for line in pretty_str.split("\n") {
    text_width = @cmp.maximum(text_width, @cells.cell_len(line.to_owned()))
  }
  Some(@rich.Measurement::new(text_width, text_width))
}

///|
/// An internal renderable used as a layout placeholder.
priv struct Placeholder {
  layout : Layout
  style : @rich.StyleType
}

///|
impl @rich.Renderable for Placeholder with fn rich_console(
  self,
  _console,
  options,
) {
  let width = options.max_width
  let height = height_or(options.height, options.size.height)
  let layout = self.layout
  let title = match layout.name {
    Some(name) if name != "" => "\{@rich.py_repr(name)} (\{width} x \{height})"
    _ => "(\{width} x \{height})"
  }
  let highlighter : &@rich.Highlighter = @rich.ReprHighlighter::new()
  [
    Child(
      @panel.Panel::new(
        @rich.Align::center(LayoutPretty::{ layout, }, vertical=Middle),
        style=self.style,
        title=highlighter.apply(title),
        border_style="blue",
        height~,
      ),
    ),
  ]
}
