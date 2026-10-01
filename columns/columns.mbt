// Port of rich/columns.py.

///|
/// Display renderables in neat columns.
pub(all) struct Columns {
  /// The renderables (strings are rendered with `Console::render_str`).
  renderables : Array[&@rich.Renderable]
  /// The desired width of the columns, or `None` to auto detect.
  mut width : Int?
  /// Padding around cells (1, 2 or 4 values).
  mut padding : Array[Int]
  /// Expand columns to full width.
  mut expand : Bool
  /// Arrange in to equal sized columns.
  mut equal : Bool
  /// Align items from top to bottom (rather than left to right).
  mut column_first : Bool
  /// Start column from right hand side.
  mut right_to_left : Bool
  /// Align value, or `None` for default.
  mut align : @rich.AlignMethod?
  /// Optional title for the columns.
  mut title : @rich.TextType?
}

///|
/// Create columns from any number of renderables (including strings).
pub fn Columns::new(
  renderables : ArrayView[&@rich.Renderable],
  padding? : ArrayView[Int] = [0, 1],
  width? : Int,
  expand? : Bool = false,
  equal? : Bool = false,
  column_first? : Bool = false,
  right_to_left? : Bool = false,
  align? : @rich.AlignMethod,
  title? : &@rich.IntoText,
) -> Columns {
  {
    renderables: renderables.to_owned(),
    width,
    padding: padding.to_owned(),
    expand,
    equal,
    column_first,
    right_to_left,
    align,
    title: title.map(t => t.into_text_type()),
  }
}

///|
/// Add a renderable to the columns.
pub fn Columns::add_renderable(
  self : Columns,
  renderable : &@rich.Renderable,
) -> Unit {
  self.renderables.push(renderable)
}

///|
pub impl @rich.Renderable for Columns with fn rich_console(
  self,
  console,
  options,
) {
  let renderables : Array[&@rich.Renderable] = []
  for renderable in self.renderables {
    match renderable.text_kind() {
      Str(s) => renderables.push(console.render_str(s))
      _ => renderables.push(renderable)
    }
  }
  if renderables.is_empty() {
    return []
  }
  let (_, right, _, left) = @rich.unpack_padding(self.padding)
  let width_padding = @cmp.maximum(left, right)
  let max_width = options.max_width
  let widths : Map[Int, Int] = Map([])
  let mut column_count = renderables.length()
  let renderable_widths = renderables.map(r => {
    @rich.Measurement::get(console, options, r).maximum
  })
  if self.equal {
    let mut widest = renderable_widths[0]
    for w in renderable_widths {
      widest = @cmp.maximum(widest, w)
    }
    renderable_widths.fill(widest)
  }
  fn iter_renderables(column_count : Int) -> Array[(Int, &@rich.Renderable?)] {
    let item_count = renderables.length()
    let out : Array[(Int, &@rich.Renderable?)] = []
    if self.column_first {
      let column_lengths = Array::make(column_count, item_count / column_count)
      for col_no in 0..<(item_count % column_count) {
        column_lengths[col_no] += 1
      }
      let row_count = (item_count + column_count - 1) / column_count
      let cells = Array::makei(row_count, _ => Array::make(column_count, -1))
      let mut row = 0
      let mut col = 0
      for index in 0..<item_count {
        cells[row][col] = index
        column_lengths[col] -= 1
        if column_lengths[col] != 0 {
          row += 1
        } else {
          col += 1
          row = 0
        }
      }
      for cell_row in cells {
        for index in cell_row {
          if index == -1 {
            break
          }
          out.push((renderable_widths[index], Some(renderables[index])))
        }
      }
    } else {
      for index, renderable in renderables {
        out.push((renderable_widths[index], Some(renderable)))
      }
    }
    // Pad odd elements with spaces
    if item_count % column_count != 0 {
      for _ in 0..<(column_count - item_count % column_count) {
        out.push((0, None))
      }
    }
    out
  }

  let table = @rich.Table::grid(
    padding=self.padding,
    collapse_padding=true,
    pad_edge=false,
  )
  table.set_expand(self.expand)
  table.title = self.title
  match self.width {
    Some(width) => {
      column_count = max_width / (width + width_padding)
      for _ in 0..<column_count {
        table.add_column(width~)
      }
    }
    None =>
      while column_count > 1 {
        widths.clear()
        let mut column_no = 0
        let mut broke = false
        for item in iter_renderables(column_count) {
          let (renderable_width, _) = item
          widths[column_no] = @cmp.maximum(
            widths.get(column_no).unwrap_or(0),
            renderable_width,
          )
          let mut total_width = 0
          for _, w in widths {
            total_width += w
          }
          total_width += width_padding * (widths.length() - 1)
          if total_width > max_width {
            column_count = widths.length() - 1
            broke = true
            break
          } else {
            column_no = (column_no + 1) % column_count
          }
        }
        if !broke {
          break
        }
      }
  }
  if column_count == 0 {
    raise @rich.ValueError("range() arg 3 must not be zero")
  }
  let mut cells : Array[&@rich.Renderable?] = iter_renderables(column_count).map(item => {
      item.1
    },
  )
  if self.equal {
    cells = cells.map(r => {
      r.map(r => {
        (
          @rich.Constrain::new(r, width=Some(renderable_widths[0])) :
          &@rich.Renderable)
      })
    })
  }
  if self.align is Some(align) {
    cells = cells.map(r => {
      r.map(r => (@rich.Align::new(r, align) : &@rich.Renderable))
    })
  }
  for start = 0; start < cells.length(); start = start + column_count {
    let end = @cmp.minimum(start + column_count, cells.length())
    let row : Array[&@rich.Renderable] = cells[start:end]
      .iter()
      .map(r => r.unwrap_or(("" : &@rich.Renderable)))
      .to_array()
    if self.right_to_left {
      row.rev_in_place()
    }
    table.add_row(row)
  }
  [Child(table)]
}
