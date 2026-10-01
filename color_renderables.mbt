// Upstream `__rich__` methods of the `color` package types (`Color` in
// rich/color.py and `Palette` in rich/palette.py). They live in the root
// package because they build `Text` / `Table`.

///|
/// A Text that displays the color (upstream `Color.__rich__`), e.g.
/// `<color 'red' (standard)⬤ >` where the dot is drawn in the color.
pub fn color_to_text(color : @color.Color) -> Text {
  Text::assemble([
    "<color \{py_repr(color.name)} (\{color.type_.name().to_lower()})",
    ("⬤", Style::new(color~)),
    " >",
  ])
}

///|
/// Renders as `color_to_text(color)`.
pub impl Renderable for @color.Color with fn rich_console(
  self,
  console,
  options,
) {
  color_to_text(self).rich_console(console, options)
}

///|
pub impl Renderable for @color.Color with fn rich_measure(
  self,
  console,
  options,
) {
  color_to_text(self).rich_measure(console, options)
}

///|
/// A Table that displays the colors of a palette (upstream
/// `Palette.__rich__`).
pub fn palette_to_table(palette : @color.Palette) -> Table {
  let colors = palette.colors()
  // fixed, valid arguments: construction cannot fail
  let table = try! Table::new(
    headers=["index", "RGB", "Color"],
    title="Palette",
    caption="\{colors.length()} colors",
    highlight=true,
    caption_justify=Right,
  )
  for index, color in colors {
    let (r, g, b) = color
    table.add_row([
      index.to_string(),
      "(\{r}, \{g}, \{b})",
      Text::new(
        text=" ".repeat(16),
        style=Style::new(
          bgcolor=@color.Color::from_rgb(
            r.to_double(),
            g.to_double(),
            b.to_double(),
          ),
        ),
      ),
    ])
  }
  table
}

///|
/// Renders as `palette_to_table(palette)`.
pub impl Renderable for @color.Palette with fn rich_console(
  self,
  _console,
  _options,
) {
  [Child(palette_to_table(self))]
}

///|
pub impl Renderable for @color.Palette with fn rich_measure(
  self,
  console,
  options,
) {
  palette_to_table(self).rich_measure(console, options)
}
