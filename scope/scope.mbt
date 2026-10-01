// Port of rich/scope.py.

///|
/// Compare strings by code point, as Python does.
fn compare_code_points(a : String, b : String) -> Int {
  let ai = a.iter()
  let bi = b.iter()
  for ;; {
    match (ai.next(), bi.next()) {
      (None, None) => return 0
      (None, Some(_)) => return -1
      (Some(_), None) => return 1
      (Some(x), Some(y)) => if x != y { return x.compare(y) }
    }
  }
}

///|
/// Render variables in a given scope: a table of `name = value` rows (the
/// values pretty printed) in a panel.
///
/// * `title`: optional panel title.
/// * `sort_keys`: sort special (`__dunder`) variables first, then
///   alphabetically (case-insensitive); otherwise keep the map's order.
/// * `indent_guides`: enable indentation guides.
/// * `max_length` / `max_string` / `max_depth`: abbreviate containers,
///   strings and deep structures.
/// * `overflow`: how to handle overflowing values.
///
/// ```mbt check
/// test {
///   let scope : Map[String, &@pretty.PrettyRepr] = { "foo": 1, "bar": "baz" }
///   let console = @rich.Console::new(
///     file=@rich.StringIO::new(),
///     width=40,
///     color_system=None,
///     environ={},
///   )
///   let output = console.capture(() => console.print(@scope.render_scope(scope)))
///   inspect(
///     output,
///     content=(
///       #|╭─────────────╮
///       #|│ bar = 'baz' │
///       #|│ foo = 1     │
///       #|╰─────────────╯
///       #|
///     ),
///   )
/// }
/// ```
pub fn render_scope(
  scope : Map[String, &@pretty.PrettyRepr],
  title? : &@rich.IntoText,
  sort_keys? : Bool = true,
  indent_guides? : Bool = false,
  max_length? : Int,
  max_string? : Int,
  max_depth? : Int,
  overflow? : @rich.OverflowMethod,
) -> @panel.Panel {
  let highlighter = @rich.ReprHighlighter::new()
  // the padding is valid, so constructing the grid cannot fail
  let items_table = try! @rich.Table::grid(padding=[0, 1], expand=false)
  items_table.add_column(justify=Right)
  let items = scope.to_array()
  if sort_keys {
    // Sort special variables first, then alphabetically (a stable sort:
    // ties keep the map's order).
    let indexed = items.mapi((i, item) => (i, item))
    indexed.sort_by((a, b) => {
      let (ai, (akey, _)) = a
      let (bi, (bkey, _)) = b
      let a_special = akey.has_prefix("__")
      let b_special = bkey.has_prefix("__")
      if a_special != b_special {
        if a_special {
          -1
        } else {
          1
        }
      } else {
        match compare_code_points(@pystr.lower(akey), @pystr.lower(bkey)) {
          0 => ai.compare(bi)
          c => c
        }
      }
    })
    for i, item in indexed {
      items[i] = item.1
    }
  }
  for item in items {
    let (key, value) = item
    let key_text = @rich.Text::assemble([
      (
        key,
        if key.has_prefix("__") {
          "scope.key.special"
        } else {
          "scope.key"
        },
      ),
      (" =", "scope.equals"),
    ])
    items_table.add_row([
      key_text,
      @pretty.Pretty::new(
        value,
        highlighter~,
        indent_guides~,
        max_length?,
        max_string?,
        max_depth?,
        overflow?,
      ),
    ])
  }
  @panel.Panel::fit(items_table, title?, border_style="scope.border", padding=[
    0, 1,
  ])
}
