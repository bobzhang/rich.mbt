// `render_csv`: CSV / TSV as a table.

///|
/// `re.compile(r"\-?[0-9]*?\.?[0-9]*?").fullmatch`
fn is_number(value : String) -> Bool {
  let chars = value.to_array()
  let mut i = 0
  if i < chars.length() && chars[i] == '-' {
    i += 1
  }
  while i < chars.length() && chars[i] is ('0'..='9') {
    i += 1
  }
  if i < chars.length() && chars[i] == '.' {
    i += 1
  }
  while i < chars.length() && chars[i] is ('0'..='9') {
    i += 1
  }
  i == chars.length()
}

///|
/// Render the resource as a table (`render_csv`).
fn Context::render_csv(
  self : Context,
  resource : String,
  input : Result[String, String]?,
) -> &@rich.Renderable raise Exit {
  let opts = self.options
  let (csv_data, _) = self.read_resource(resource, Some("csv"), input)
  let (dialect, has_header) = sniff_csv(resource, csv_data) catch {
    CsvError(message) => {
      self.on_error(message)
      (excel, true)
    }
  }
  let rows = csv_read(csv_data, dialect) catch {
    CsvError(message) => {
      self.on_error("unable to read CSV", error=message)
      []
    }
  }
  let title : &@rich.IntoText? = if opts.title != "" {
    Some(opts.title)
  } else {
    None
  }
  let caption : &@rich.IntoText? = if opts.caption != "" {
    Some(opts.caption)
  } else {
    None
  }
  let table = @rich.Table::new(
    show_header=has_header,
    box_=if has_header { @rich.box_heavy_head } else { @rich.box_square },
    border_style="blue",
    title?,
    caption?,
    caption_justify=Right,
  ) catch {
    e => {
      self.on_error("unable to create table", error=e.to_string())
      return ""
    }
  }
  let mut body = rows[:]
  if has_header && rows.length() > 0 {
    for column in rows[0] {
      table.add_column(header=column)
    }
    body = rows[1:]
  }
  let mut table_rows = body.iter().filter(row => row.length() > 0).collect()
  match (opts.head, opts.tail) {
    (Some(head), _) =>
      table_rows = table_rows[:@cmp.minimum(head, table_rows.length())].to_owned()
    (None, Some(tail)) =>
      table_rows = table_rows[@cmp.maximum(0, table_rows.length() - tail):].to_owned()
    _ => ()
  }
  for row in table_rows {
    table.add_row(row.map(cell => (cell : &@rich.Renderable)))
  }
  for index, column in table.columns {
    let numeric = table_rows
      .iter()
      .all(row => {
        guard row.get(index) is Some(value) else { return false }
        value == "" || is_number(value)
      })
    if numeric {
      column.justify = Right
      column.style = Def("bold green")
      column.header_style = Def("bold green")
    }
  }
  table
}
