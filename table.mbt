// Port of rich/table.py.

///|
/// Defines a column within a `Table`.
pub(all) struct Column {
  /// Renderable for the header (typically a string).
  mut header : &Renderable
  /// Renderable for the footer (typically a string).
  mut footer : &Renderable
  /// The style of the header.
  mut header_style : StyleType
  /// The style of the footer.
  mut footer_style : StyleType
  /// The style of the column.
  mut style : StyleType
  /// How to justify text within the column.
  mut justify : JustifyMethod
  /// How to vertically align content.
  mut vertical : VerticalAlignMethod
  /// Overflow method.
  mut overflow : OverflowMethod
  /// Width of the column, or `None` to auto calculate width.
  mut width : Int?
  /// Minimum width of column.
  mut min_width : Int?
  /// Maximum width of column.
  mut max_width : Int?
  /// Ratio to use when calculating column width.
  mut ratio : Int?
  /// Prevent wrapping of text within the column.
  mut no_wrap : Bool
  /// Apply highlighter to column.
  mut highlight : Bool
  priv mut index : Int
  priv cells_ : Array[&Renderable]
}

///|
pub fn Column::new(
  header? : &Renderable = "",
  footer? : &Renderable = "",
  header_style? : &IntoStyle,
  footer_style? : &IntoStyle,
  style? : &IntoStyle,
  justify? : JustifyMethod = Left,
  vertical? : VerticalAlignMethod = Top,
  overflow? : OverflowMethod = Ellipsis,
  width? : Int,
  min_width? : Int,
  max_width? : Int,
  ratio? : Int,
  no_wrap? : Bool = false,
  highlight? : Bool = false,
) -> Column {
  {
    header,
    footer,
    header_style: style_or_empty(header_style),
    footer_style: style_or_empty(footer_style),
    style: style_or_empty(style),
    justify,
    vertical,
    overflow,
    width,
    min_width,
    max_width,
    ratio,
    no_wrap,
    highlight,
    index: 0,
    cells_: [],
  }
}

///|
/// A copy of the column without its cells.
pub fn Column::copy(self : Column) -> Column {
  { ..self, cells_: [], }
}

///|
/// The cells in the column.
pub fn Column::cells(self : Column) -> Array[&Renderable] {
  self.cells_.copy()
}

///|
/// Check if this column is flexible.
pub fn Column::flexible(self : Column) -> Bool {
  self.ratio is Some(_)
}

///|
/// Things accepted as table headers: strings and columns.
pub(open) trait IntoColumn {
  fn into_column(Self) -> Column
  /// Convert to a column of a table whose `highlight` setting is given.
  /// Upstream adds string headers with `add_column(header=...)`, so they
  /// inherit the table's `highlight`; `Column`s are used as they are.
  fn into_table_column(Self, highlight~ : Bool) -> Column = _
}

///|
impl IntoColumn with fn into_table_column(self, highlight~) {
  ignore(highlight)
  self.into_column()
}

///|
pub impl IntoColumn for String with fn into_column(self) {
  Column::new(header=self)
}

///|
pub impl IntoColumn for String with fn into_table_column(self, highlight~) {
  Column::new(header=self, highlight~)
}

///|
pub impl IntoColumn for Column with fn into_column(self) {
  self
}

///|
/// Information regarding a row.
pub(all) struct Row {
  /// Style to apply to row.
  mut style : StyleType?
  /// Indicated end of section, which will force a line beneath the row.
  mut end_section : Bool
}

///|
priv struct Cell {
  style : Style
  renderable : &Renderable
  vertical : VerticalAlignMethod
}

///|
/// A console renderable to draw a table.
pub(all) struct Table {
  columns : Array[Column]
  rows : Array[Row]
  mut title : TextType?
  mut caption : TextType?
  mut width : Int?
  mut min_width : Int?
  mut box_ : Box?
  mut safe_box : Bool?
  priv mut padding_ : (Int, Int, Int, Int)
  mut pad_edge : Bool
  priv mut expand_ : Bool
  mut show_header : Bool
  mut show_footer : Bool
  mut show_edge : Bool
  mut show_lines : Bool
  mut leading : Int
  mut collapse_padding : Bool
  mut style : StyleType
  mut header_style : StyleType
  mut footer_style : StyleType
  mut border_style : StyleType?
  mut title_style : StyleType?
  mut caption_style : StyleType?
  mut title_justify : JustifyMethod
  mut caption_justify : JustifyMethod
  mut highlight : Bool
  mut row_styles : Array[StyleType]
}

///|
/// Create a table. `headers` are column headers (strings or `Column`s).
/// `box_` is the box style; pass `no_box=true` for no box.
pub fn Table::new(
  headers? : Array[&IntoColumn] = [],
  title? : &IntoText,
  caption? : &IntoText,
  width? : Int,
  min_width? : Int,
  box_? : Box = box_heavy_head,
  no_box? : Bool = false,
  safe_box? : Bool,
  padding? : ArrayView[Int] = [0, 1],
  collapse_padding? : Bool = false,
  pad_edge? : Bool = true,
  expand? : Bool = false,
  show_header? : Bool = true,
  show_footer? : Bool = false,
  show_edge? : Bool = true,
  show_lines? : Bool = false,
  leading? : Int = 0,
  style? : &IntoStyle,
  row_styles? : Array[&IntoStyle] = [],
  header_style? : &IntoStyle,
  footer_style? : &IntoStyle,
  border_style? : &IntoStyle,
  title_style? : &IntoStyle,
  caption_style? : &IntoStyle,
  title_justify? : JustifyMethod = Center,
  caption_justify? : JustifyMethod = Center,
  highlight? : Bool = false,
) -> Table raise RichError {
  let table : Table = {
    columns: [],
    rows: [],
    title: title.map(t => t.into_text_type()),
    caption: caption.map(t => t.into_text_type()),
    width,
    min_width,
    box_: if no_box {
      None
    } else {
      Some(box_)
    },
    safe_box,
    padding_: unpack_padding(padding),
    pad_edge,
    expand_: expand,
    show_header,
    show_footer,
    show_edge,
    show_lines,
    leading,
    collapse_padding,
    style: match style {
      Some(s) => s.into_style_type()
      None => Def("none")
    },
    header_style: match header_style {
      Some(s) => s.into_style_type()
      None => Def("table.header")
    },
    footer_style: match footer_style {
      Some(s) => s.into_style_type()
      None => Def("table.footer")
    },
    border_style: style_opt(border_style),
    title_style: style_opt(title_style),
    caption_style: style_opt(caption_style),
    title_justify,
    caption_justify,
    highlight,
    row_styles: row_styles.map(s => s.into_style_type()),
  }
  for header in headers {
    let column = header.into_table_column(highlight~)
    column.index = table.columns.length()
    table.columns.push(column)
  }
  table
}

///|
/// Get a table with no lines, headers, or footer.
pub fn Table::grid(
  headers? : Array[&IntoColumn] = [],
  padding? : ArrayView[Int] = [0],
  collapse_padding? : Bool = true,
  pad_edge? : Bool = false,
  expand? : Bool = false,
) -> Table raise RichError {
  Table::new(
    headers~,
    no_box=true,
    padding~,
    collapse_padding~,
    show_header=false,
    show_footer=false,
    show_edge=false,
    pad_edge~,
    expand~,
  )
}

///|
/// Whether the table expands to the available space.
pub fn Table::expand(self : Table) -> Bool {
  self.expand_ || self.width is Some(_)
}

///|
pub fn Table::set_expand(self : Table, expand : Bool) -> Unit {
  self.expand_ = expand
}

///|
/// Cell padding as `(top, right, bottom, left)`.
pub fn Table::padding(self : Table) -> (Int, Int, Int, Int) {
  self.padding_
}

///|
/// Set cell padding (1, 2 or 4 values).
pub fn Table::set_padding(
  self : Table,
  padding : ArrayView[Int],
) -> Unit raise RichError {
  self.padding_ = unpack_padding(padding)
}

///|
fn Table::extra_width(self : Table) -> Int {
  let mut width = 0
  if self.box_ is Some(_) && self.show_edge {
    width += 2
  }
  if self.box_ is Some(_) {
    width += self.columns.length() - 1
  }
  width
}

///|
/// The number of rows in the table.
pub fn Table::row_count(self : Table) -> Int {
  self.rows.length()
}

///|
/// Get the current row style.
pub fn Table::get_row_style(
  self : Table,
  console : Console,
  index : Int,
) -> Style raise {
  let mut style = Style::null()
  if !self.row_styles.is_empty() {
    style = style +
      console.get_style(
        self.row_styles[py_mod(index, self.row_styles.length())],
      )
  }
  if self.rows[index].style is Some(row_style) {
    style = style + console.get_style(row_style)
  }
  style
}

///|
pub impl Renderable for Table with fn rich_measure(self, console, options) {
  let mut max_width = options.max_width
  if self.width is Some(w) {
    max_width = w
  }
  if max_width < 0 {
    return Some({ minimum: 0, maximum: 0, })
  }
  let extra_width = self.extra_width()
  let mut max_width_sum = 0
  for
    w in self.calculate_column_widths(
      console,
      options.update_width(max_width - extra_width),
    ) {
    max_width_sum += w
  }
  let max_width = max_width_sum
  let mut minimum_width = 0
  let mut maximum_width = 0
  for column in self.columns {
    let m = self.measure_column(
      console,
      options.update_width(max_width),
      column,
    )
    minimum_width += m.minimum
    maximum_width += m.maximum
  }
  let measurement = {
    minimum: minimum_width + extra_width,
    maximum: match self.width {
      None => maximum_width + extra_width
      Some(w) => w
    },
  }
  Some(measurement.clamp(min_width?=self.min_width))
}

///|
/// Add a column to the table.
pub fn Table::add_column(
  self : Table,
  header? : &Renderable = "",
  footer? : &Renderable = "",
  header_style? : &IntoStyle,
  highlight? : Bool,
  footer_style? : &IntoStyle,
  style? : &IntoStyle,
  justify? : JustifyMethod = Left,
  vertical? : VerticalAlignMethod = Top,
  overflow? : OverflowMethod = Ellipsis,
  width? : Int,
  min_width? : Int,
  max_width? : Int,
  ratio? : Int,
  no_wrap? : Bool = false,
) -> Unit {
  let column = Column::new(
    header~,
    footer~,
    header_style?,
    highlight=highlight.unwrap_or(self.highlight),
    footer_style?,
    style?,
    justify~,
    vertical~,
    overflow~,
    width?,
    min_width?,
    max_width?,
    ratio?,
    no_wrap~,
  )
  column.index = self.columns.length()
  self.columns.push(column)
}

///|
/// Add a row of renderables.
pub fn Table::add_row(
  self : Table,
  renderables : ArrayView[&Renderable],
  style? : &IntoStyle,
  end_section? : Bool = false,
) -> Unit {
  let cells : Array[&Renderable] = renderables.to_owned()
  while cells.length() < self.columns.length() {
    cells.push("")
  }
  for index, renderable in cells {
    let column = if index == self.columns.length() {
      let column = Column::new(highlight=self.highlight)
      column.index = index
      for _ in self.rows {
        column.cells_.push(Text::new())
      }
      self.columns.push(column)
      column
    } else {
      self.columns[index]
    }
    column.cells_.push(renderable)
  }
  self.rows.push({ style: style_opt(style), end_section, })
}

///|
/// Add a new section (draw a line after current row).
pub fn Table::add_section(self : Table) -> Unit {
  if !self.rows.is_empty() {
    self.rows[self.rows.length() - 1].end_section = true
  }
}

///|
pub impl Renderable for Table with fn rich_console(self, console, options) {
  if self.columns.is_empty() {
    return [Seg(Segment::new("\n"))]
  }
  let mut max_width = options.max_width
  if self.width is Some(w) {
    max_width = w
  }
  let extra_width = self.extra_width()
  let widths = self.calculate_column_widths(
    console,
    options.update_width(max_width - extra_width),
  )
  let mut table_width = extra_width
  for w in widths {
    table_width += w
  }
  let render_options = options.update(
    width=table_width,
    highlight=Some(self.highlight),
    height=None,
  )
  let out = []
  fn render_annotation(
    text : TextType,
    style : StyleType,
    justify : JustifyMethod,
  ) -> Unit raise {
    let render_text = match text {
      Str(s) => console.render_str(s, style~, highlight=Some(false))
      Text(t) => t
    }
    for
      s in console.render(
        render_text,
        options=render_options.update(justify=Some(justify)),
      ) {
      out.push(Seg(s))
    }
  }

  if self.title is Some(title) && title.to_bool() {
    render_annotation(
      title,
      self.title_style.unwrap_or(Def("table.title")),
      self.title_justify,
    )
  }
  for s in self.render_table(console, render_options, widths) {
    out.push(Seg(s))
  }
  if self.caption is Some(caption) && caption.to_bool() {
    render_annotation(
      caption,
      self.caption_style.unwrap_or(Def("table.caption")),
      self.caption_justify,
    )
  }
  out
}

///|
fn sum(xs : ArrayView[Int]) -> Int {
  let mut total = 0
  for x in xs {
    total += x
  }
  total
}

///|
/// Calculate the widths of each column, including padding, not including
/// borders.
fn Table::calculate_column_widths(
  self : Table,
  console : Console,
  options : ConsoleOptions,
) -> Array[Int] raise {
  let max_width = options.max_width
  let columns = self.columns
  let width_ranges = columns.map(c => self.measure_column(console, options, c))
  let mut widths = width_ranges.map(r => {
    if r.maximum == 0 {
      1
    } else {
      r.maximum
    }
  })
  let extra_width = self.extra_width()
  if self.expand() {
    let ratios = []
    for col in columns {
      if col.flexible() {
        ratios.push(col.ratio.unwrap_or(0))
      }
    }
    if ratios.iter().any(r => r != 0) {
      let fixed_widths = columns.mapi((i, column) => {
        if column.flexible() {
          0
        } else {
          width_ranges[i].maximum
        }
      })
      let flex_minimum = []
      for column in columns {
        if column.flexible() {
          flex_minimum.push(
            (match column.width {
              Some(w) if w != 0 => w
              _ => 1
            }) +
            self.get_padding_width(column.index),
          )
        }
      }
      let flexible_width = max_width - sum(fixed_widths)
      let flex_widths = ratio_distribute(
        flexible_width,
        ratios,
        minimums=flex_minimum,
      )
      let mut flex_index = 0
      for index, column in columns {
        if column.flexible() {
          widths[index] = fixed_widths[index] + flex_widths[flex_index]
          flex_index += 1
        }
      }
    }
  }
  let mut table_width = sum(widths)
  if table_width > max_width {
    widths = Table::collapse_widths(
      widths,
      columns.map(column => column.width is None && !column.no_wrap),
      max_width,
    )
    table_width = sum(widths)
    if table_width > max_width {
      let excess_width = table_width - max_width
      widths = ratio_reduce(
        excess_width,
        Array::make(widths.length(), 1),
        widths,
        widths,
      )
      table_width = sum(widths)
    }
    let width_ranges = []
    for i, column in columns {
      width_ranges.push(
        self.measure_column(console, options.update_width(widths[i]), column),
      )
    }
    widths = width_ranges.map(r => r.maximum)
  }
  if (table_width < max_width && self.expand()) ||
    (self.min_width is Some(mw) && table_width < mw - extra_width) {
    let max_width = match self.min_width {
      None => max_width
      Some(mw) => @cmp.minimum(mw - extra_width, max_width)
    }
    let pad_widths = ratio_distribute(max_width - table_width, widths)
    widths = widths.mapi((i, w) => w + pad_widths[i])
  }
  widths
}

///|
/// Reduce widths so that the total is under max_width.
fn Table::collapse_widths(
  widths : Array[Int],
  wrapable : Array[Bool],
  max_width : Int,
) -> Array[Int] {
  let mut widths = widths
  let mut total_width = sum(widths)
  let mut excess_width = total_width - max_width
  if wrapable.iter().any(w => w) {
    while total_width != 0 && excess_width > 0 {
      let mut max_column = 0
      let mut first = true
      for i, width in widths {
        if wrapable[i] && (first || width > max_column) {
          max_column = width
          first = false
        }
      }
      let mut second_max_column = 0
      for i, width in widths {
        let v = if wrapable[i] && width != max_column { width } else { 0 }
        second_max_column = @cmp.maximum(second_max_column, v)
      }
      let column_difference = max_column - second_max_column
      let ratios = widths.mapi((i, width) => {
        if width == max_column && wrapable[i] {
          1
        } else {
          0
        }
      })
      if !ratios.iter().any(r => r != 0) || column_difference == 0 {
        break
      }
      let max_reduce = Array::make(
        widths.length(),
        @cmp.minimum(excess_width, column_difference),
      )
      widths = ratio_reduce(excess_width, ratios, max_reduce, widths)
      total_width = sum(widths)
      excess_width = total_width - max_width
    }
  }
  widths
}

///|
fn Table::get_cells(
  self : Table,
  console : Console,
  column_index : Int,
  column : Column,
) -> Array[Cell] raise {
  let collapse_padding = self.collapse_padding
  let pad_edge = self.pad_edge
  let padding = self.padding_
  let any_padding = padding.0 != 0 ||
    padding.1 != 0 ||
    padding.2 != 0 ||
    padding.3 != 0
  let first_column = column_index == 0
  let last_column = column_index == self.columns.length() - 1
  fn get_padding(first_row : Bool, last_row : Bool) -> Array[Int] {
    let (t, r, b, l) = padding
    let mut top = t
    let mut right = r
    let mut bottom = b
    let mut left = l
    if collapse_padding {
      if !first_column {
        left = @cmp.maximum(0, left - right)
      }
      if !last_row {
        bottom = @cmp.maximum(0, top - bottom)
      }
    }
    if !pad_edge {
      if first_column {
        left = 0
      }
      if last_column {
        right = 0
      }
      if first_row {
        top = 0
      }
      if last_row {
        bottom = 0
      }
    }
    [top, right, bottom, left]
  }

  let raw_cells : Array[(Style, &Renderable)] = []
  if self.show_header {
    let header_style = console.get_style(self.header_style) +
      console.get_style(column.header_style)
    raw_cells.push((header_style, column.header))
  }
  let cell_style = console.get_style(column.style)
  for cell in column.cells_ {
    raw_cells.push((cell_style, cell))
  }
  if self.show_footer {
    let footer_style = console.get_style(self.footer_style) +
      console.get_style(column.footer_style)
    raw_cells.push((footer_style, column.footer))
  }
  let cells = []
  let n = raw_cells.length()
  for i, raw in raw_cells {
    let (style, renderable) = raw
    let vertical = renderable.vertical_align().unwrap_or(column.vertical)
    if any_padding {
      let p = get_padding(i == 0, i == n - 1)
      cells.push({
        style,
        renderable: Padding::new(renderable, pad=p),
        vertical,
      })
    } else {
      cells.push({ style, renderable, vertical, })
    }
  }
  cells
}

///|
fn Table::get_padding_width(self : Table, column_index : Int) -> Int {
  let (_, pad_right, _, pad_left) = self.padding_
  let mut pad_left = pad_left
  let mut pad_right = pad_right
  if self.collapse_padding {
    pad_left = 0
    pad_right = (pad_left - pad_right).abs()
  }
  if !self.pad_edge {
    if column_index == 0 {
      pad_left = 0
    }
    if column_index == self.columns.length() - 1 {
      pad_right = 0
    }
  }
  pad_left + pad_right
}

///|
fn Table::measure_column(
  self : Table,
  console : Console,
  options : ConsoleOptions,
  column : Column,
) -> Measurement raise {
  let max_width = options.max_width
  if max_width < 1 {
    return { minimum: 0, maximum: 0, }
  }
  let padding_width = self.get_padding_width(column.index)
  if column.width is Some(w) {
    return { minimum: w + padding_width, maximum: w + padding_width, }.with_maximum(
      max_width,
    )
  }
  let min_widths = []
  let max_widths = []
  for cell in self.get_cells(console, column.index, column) {
    let m = Measurement::get(console, options, cell.renderable)
    min_widths.push(m.minimum)
    max_widths.push(m.maximum)
  }
  fn max_of(xs : Array[Int], default : Int) -> Int {
    if xs.is_empty() {
      return default
    }
    let mut m = xs[0]
    for x in xs {
      m = @cmp.maximum(m, x)
    }
    m
  }

  let measurement = {
    minimum: max_of(min_widths, 1),
    maximum: max_of(max_widths, max_width),
  }.with_maximum(max_width)
  measurement.clamp(
    min_width?=column.min_width.map(w => w + padding_width),
    max_width?=column.max_width.map(w => w + padding_width),
  )
}

///|
fn Table::render_table(
  self : Table,
  console : Console,
  options : ConsoleOptions,
  widths : Array[Int],
) -> Array[Segment] raise {
  let out = []
  let table_style = console.get_style(self.style)
  let border_style = table_style +
    console.get_style(self.border_style.unwrap_or(Def("")))
  let column_cells = []
  for column_index, column in self.columns {
    column_cells.push(self.get_cells(console, column_index, column))
  }
  // zip(*column_cells): truncated to the shortest column
  let mut row_count = column_cells[0].length()
  for cells in column_cells {
    row_count = @cmp.minimum(row_count, cells.length())
  }
  let row_cells = []
  for r in 0..<row_count {
    row_cells.push(column_cells.map(cells => cells[r]))
  }
  let box_ = match self.box_ {
    Some(b) => {
      let b = b.substitute(
        options,
        safe=pick_bool([self.safe_box, Some(console.safe_box)]),
      )
      if !self.show_header {
        Some(b.get_plain_headed_box())
      } else {
        Some(b)
      }
    }
    None => None
  }
  let new_line = Segment::line()
  let columns = self.columns
  let show_header = self.show_header
  let show_footer = self.show_footer
  let show_edge = self.show_edge
  let show_lines = self.show_lines
  let leading = self.leading
  let box_segments = match box_ {
    Some(b) => {
      if show_edge {
        out.push(Segment::new(b.get_top(widths), style=border_style))
        out.push(new_line)
      }
      [
        (
          Segment::new(b.head_left, style=border_style),
          Segment::new(b.head_right, style=border_style),
          Segment::new(b.head_vertical, style=border_style),
        ),
        (
          Segment::new(b.mid_left, style=border_style),
          Segment::new(b.mid_right, style=border_style),
          Segment::new(b.mid_vertical, style=border_style),
        ),
        (
          Segment::new(b.foot_left, style=border_style),
          Segment::new(b.foot_right, style=border_style),
          Segment::new(b.foot_vertical, style=border_style),
        ),
      ]
    }
    None => []
  }
  let header_offset = if show_header { 1 } else { 0 }
  for index, row_cell in row_cells {
    let first = index == 0
    let last = index == row_cells.length() - 1
    let header_row = first && show_header
    let footer_row = last && show_footer
    let row = if !header_row && !footer_row {
      Some(self.rows[index - header_offset])
    } else {
      None
    }
    let mut max_height = 1
    let cells : Array[Array[Array[Segment]]] = []
    let row_style = if header_row || footer_row {
      Style::null()
    } else {
      self.get_row_style(console, if show_header { index - 1 } else { index })
    }
    for i, cell in row_cell {
      let width = widths[i]
      let column = columns[i]
      let render_options = options.update(
        width~,
        justify=Some(column.justify),
        no_wrap=Some(column.no_wrap),
        overflow=Some(column.overflow),
        height=None,
        highlight=Some(column.highlight),
      )
      let lines = console.render_lines(
        cell.renderable,
        options=render_options,
        style=cell.style + row_style,
      )
      max_height = @cmp.maximum(max_height, lines.length())
      cells.push(lines)
    }
    let mut row_height = 0
    for cell in cells {
      row_height = @cmp.maximum(row_height, cell.length())
    }
    fn align_cell(
      cell : Array[Array[Segment]],
      vertical : VerticalAlignMethod,
      width : Int,
      style : Style,
    ) -> Array[Array[Segment]] {
      let vertical = if header_row {
        Bottom
      } else if footer_row {
        Top
      } else {
        vertical
      }
      match vertical {
        Top => Segment::align_top(cell, width, row_height, Some(style))
        Middle => Segment::align_middle(cell, width, row_height, Some(style))
        Bottom => Segment::align_bottom(cell, width, row_height, Some(style))
      }
    }

    let aligned = []
    for i, cell in cells {
      let width = widths[i]
      let c = row_cell[i]
      aligned.push(
        Segment::set_shape(
          align_cell(cell, c.vertical, width, c.style + row_style),
          width,
          height=max_height,
        ),
      )
    }
    match box_ {
      Some(b) => {
        if last && show_footer {
          out.push(
            Segment::new(
              b.get_row(widths, level=Foot, edge=show_edge),
              style=border_style,
            ),
          )
          out.push(new_line)
        }
        let (left, right, divider_) = box_segments[if first {
            0
          } else if last {
            2
          } else {
            1
          }]
        let divider = if py_strip(divider_.text) != "" {
          divider_
        } else {
          Segment::new(
            divider_.text,
            style=row_style.background_style().add_opt(divider_.style),
          )
        }
        for line_no in 0..<max_height {
          if show_edge {
            out.push(left)
          }
          for i, rendered_cell in aligned {
            out.append(rendered_cell[line_no])
            if i != aligned.length() - 1 {
              out.push(divider)
            }
          }
          if show_edge {
            out.push(right)
          }
          out.push(new_line)
        }
      }
      None =>
        for line_no in 0..<max_height {
          for rendered_cell in aligned {
            out.append(rendered_cell[line_no])
          }
          out.push(new_line)
        }
    }
    if box_ is Some(b) && first && show_header {
      out.push(
        Segment::new(
          b.get_row(widths, level=Head, edge=show_edge),
          style=border_style,
        ),
      )
      out.push(new_line)
    }
    let end_section = match row {
      Some(r) => r.end_section
      None => false
    }
    if box_ is Some(b) && (show_lines || leading != 0 || end_section) {
      if !last &&
        !(show_footer && index >= row_cells.length() - 2) &&
        !(show_header && header_row) {
        if leading != 0 {
          out.push(
            Segment::new(
              b.get_row(widths, level=Mid, edge=show_edge).repeat(leading),
              style=border_style,
            ),
          )
        } else {
          out.push(
            Segment::new(
              b.get_row(widths, level=Row, edge=show_edge),
              style=border_style,
            ),
          )
        }
        out.push(new_line)
      }
    }
  }
  if box_ is Some(b) && show_edge {
    out.push(Segment::new(b.get_bottom(widths), style=border_style))
    out.push(new_line)
  }
  out
}
