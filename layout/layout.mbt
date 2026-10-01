// Port of rich/layout.py.

///|
/// Layout related errors (upstream `LayoutError`, `NoSplitter`, and the
/// `KeyError` raised by `layout[name]`).
pub(all) suberror LayoutError {
  /// Layout related error.
  LayoutError(String)
  /// Requested splitter does not exist.
  NoSplitter(String)
  /// No layout with the requested name.
  KeyError(String)
} derive(Debug)

///|
pub impl Show for LayoutError with fn output(self, logger) {
  match self {
    LayoutError(msg) => logger.write_string("LayoutError: \{msg}")
    NoSplitter(msg) => logger.write_string("NoSplitter: \{msg}")
    KeyError(msg) => logger.write_string("KeyError: \{msg}")
  }
}

///|
/// An individual layout render.
pub(all) struct LayoutRender {
  region : @rich.Region
  render : Array[Array[@rich.Segment]]
}

///|
/// Base trait for a splitter.
pub(open) trait Splitter {
  /// Name of the splitter (`"row"`, `"column"`).
  fn name(Self) -> String
  /// Get the icon (emoji) used in `Layout::tree`.
  fn get_tree_icon(Self) -> String
  /// Divide a region amongst several child layouts.
  fn divide(Self, Array[Layout], @rich.Region) -> Array[(Layout, @rich.Region)]
}

///|
/// Split a layout region in to rows.
pub struct RowSplitter {}

///|
pub fn RowSplitter::new() -> RowSplitter {
  RowSplitter::{ }
}

///|
pub impl Splitter for RowSplitter with fn name(_self) {
  "row"
}

///|
pub impl Splitter for RowSplitter with fn get_tree_icon(_self) {
  "[layout.tree.row]⬌"
}

///|
pub impl Splitter for RowSplitter with fn divide(_self, children, region) {
  let { x, y, width, height, } = region
  let render_widths = @rich.ratio_resolve(width, children.map(c => c.edge()))
  let mut offset = 0
  let out = []
  for i, child in children {
    let child_width = render_widths[i]
    out.push(
      (child, @rich.Region::{ x: x + offset, y, width: child_width, height, }),
    )
    offset += child_width
  }
  out
}

///|
/// Split a layout region in to columns.
pub struct ColumnSplitter {}

///|
pub fn ColumnSplitter::new() -> ColumnSplitter {
  ColumnSplitter::{ }
}

///|
pub impl Splitter for ColumnSplitter with fn name(_self) {
  "column"
}

///|
pub impl Splitter for ColumnSplitter with fn get_tree_icon(_self) {
  "[layout.tree.column]⬍"
}

///|
pub impl Splitter for ColumnSplitter with fn divide(_self, children, region) {
  let { x, y, width, height, } = region
  let render_heights = @rich.ratio_resolve(height, children.map(c => c.edge()))
  let mut offset = 0
  let out = []
  for i, child in children {
    let child_height = render_heights[i]
    out.push(
      (child, @rich.Region::{ x, y: y + offset, width, height: child_height, }),
    )
    offset += child_height
  }
  out
}

///|
/// A splitter instance or the name of a splitter (upstream
/// `Union[Splitter, str]`).
pub(open) trait IntoSplitter {
  fn into_splitter(Self) -> &Splitter raise LayoutError
}

///|
/// Look up a splitter by name (upstream `Layout.splitters`).
pub fn splitter_by_name(name : String) -> &Splitter raise LayoutError {
  match name {
    "row" => (RowSplitter::new() : &Splitter)
    "column" => ColumnSplitter::new()
    _ => raise NoSplitter("No splitter called \{@rich.py_repr(name)}")
  }
}

///|
pub impl IntoSplitter for String with fn into_splitter(self) {
  splitter_by_name(self)
}

///|
pub impl IntoSplitter for RowSplitter with fn into_splitter(self) {
  self
}

///|
pub impl IntoSplitter for ColumnSplitter with fn into_splitter(self) {
  self
}

///|
let layout_counter : Ref[Int] = { val: 0, }

///|
/// A renderable to divide a fixed height in to rows or columns.
pub(all) struct Layout {
  priv id : Int
  /// The content, or `None` for the placeholder.
  priv mut renderable_ : &@rich.Renderable?
  /// Optional fixed size of layout.
  mut size : Int?
  /// Minimum size of layout.
  mut minimum_size : Int
  /// Ratio for flexible layout.
  mut ratio : Int
  /// Optional identifier for the layout.
  mut name : String?
  /// Visibility of layout.
  mut visible : Bool
  /// The splitter used to divide the layout amongst its children.
  mut splitter : &Splitter
  priv children_ : Array[Layout]
  priv mut render_map : Map[Layout, LayoutRender]
}

///|
pub impl Eq for Layout with fn equal(self, other) {
  physical_equal(self, other)
}

///|
pub impl Hash for Layout with fn hash_combine(self, hasher) {
  hasher.combine_int(self.id)
}

///|
/// Upstream `bool(renderable)` for the renderables that define it.
fn is_truthy(renderable : &@rich.Renderable) -> Bool {
  match renderable.text_kind() {
    Str(s) => s != ""
    Text(t) => t.length() > 0
    NotText => true
  }
}

///|
/// Create a layout. Without a renderable (or with an empty string/text)
/// the layout shows a placeholder.
pub fn Layout::new(
  renderable? : &@rich.Renderable,
  name? : String,
  size? : Int,
  minimum_size? : Int = 1,
  ratio? : Int = 1,
  visible? : Bool = true,
) -> Layout {
  layout_counter.val += 1
  {
    id: layout_counter.val,
    renderable_: match renderable {
      Some(r) if is_truthy(r) => Some(r)
      _ => None
    },
    size,
    minimum_size,
    ratio,
    name,
    visible,
    splitter: ColumnSplitter::new(),
    children_: [],
    render_map: Map([]),
  }
}

///|
/// The edge used by `ratio_resolve`.
fn Layout::edge(self : Layout) -> @rich.Edge {
  { size: self.size, ratio: self.ratio, minimum_size: self.minimum_size, }
}

///|
/// Layout renderable: the layout itself if it has children, otherwise its
/// content (or a placeholder).
pub fn Layout::renderable(self : Layout) -> &@rich.Renderable {
  if self.children_.length() > 0 {
    (self : &@rich.Renderable)
  } else {
    match self.renderable_ {
      Some(r) => r
      None => Placeholder::{ layout: self, style: Def(""), }
    }
  }
}

///|
/// Gets (visible) layout children.
pub fn Layout::children(self : Layout) -> Array[Layout] {
  self.children_.filter(child => child.visible)
}

///|
/// Get a map of the last render.
pub fn Layout::map(self : Layout) -> Map[Layout, LayoutRender] {
  self.render_map
}

///|
/// Get a named layout, or `None` if it doesn't exist.
pub fn Layout::get(self : Layout, name : String) -> Layout? {
  if self.name is Some(n) && n == name {
    return Some(self)
  }
  for child in self.children_ {
    if child.get(name) is Some(named_layout) {
      return Some(named_layout)
    }
  }
  None
}

///|
/// Get a named layout (upstream `layout[name]`).
#alias("_[_]")
pub fn Layout::at(self : Layout, name : String) -> Layout raise LayoutError {
  match self.get(name) {
    Some(layout) => layout
    None => raise KeyError("No layout with name \{@rich.py_repr(name)}")
  }
}

///|
/// Things that may be used to split a layout: layouts, or renderables
/// which are wrapped in a new layout (upstream
/// `Union[Layout, RenderableType]`).
pub(open) trait IntoLayout {
  fn into_layout(Self) -> Layout
}

///|
pub impl IntoLayout for Layout with fn into_layout(self) {
  self
}

///|
pub impl IntoLayout for String with fn into_layout(self) {
  Layout::new(renderable=self)
}

///|
pub impl IntoLayout for @rich.Text with fn into_layout(self) {
  Layout::new(renderable=self)
}

///|
pub impl IntoLayout for @rich.TextType with fn into_layout(self) {
  Layout::new(renderable=self)
}

///|
pub impl IntoLayout for @panel.Panel with fn into_layout(self) {
  Layout::new(renderable=self)
}

///|
/// Split the layout in to multiple sub-layouts. `splitter` is a splitter
/// instance or the name of a splitter (`"column"` by default).
pub fn Layout::split(
  self : Layout,
  layouts : ArrayView[&IntoLayout],
  splitter? : &IntoSplitter = "column",
) -> Unit raise LayoutError {
  let layouts = layouts.map(l => l.into_layout())
  self.splitter = splitter.into_splitter()
  self.children_.clear()
  self.children_.append(layouts)
}

///|
/// Add new layout(s) to the existing split.
pub fn Layout::add_split(
  self : Layout,
  layouts : ArrayView[&IntoLayout],
) -> Unit {
  for layout in layouts {
    self.children_.push(layout.into_layout())
  }
}

///|
/// Split the layout in to a row (layouts side by side).
pub fn Layout::split_row(
  self : Layout,
  layouts : ArrayView[&IntoLayout],
) -> Unit {
  self.split(layouts, splitter=RowSplitter::new()) catch {
    _ => panic()
  }
}

///|
/// Split the layout in to a column (layouts stacked on top of each other).
pub fn Layout::split_column(
  self : Layout,
  layouts : ArrayView[&IntoLayout],
) -> Unit {
  self.split(layouts, splitter=ColumnSplitter::new()) catch {
    _ => panic()
  }
}

///|
/// Reset splits to initial state.
pub fn Layout::unsplit(self : Layout) -> Unit {
  self.children_.clear()
}

///|
/// Update renderable.
pub fn Layout::update(self : Layout, renderable : &@rich.Renderable) -> Unit {
  self.renderable_ = Some(renderable)
}

///|
/// Refresh a sub-layout in place (the console must be in alt screen mode
/// and the layout must have been rendered before).
pub fn Layout::refresh_screen(
  self : Layout,
  console : @rich.Console,
  layout_name : String,
) -> Unit raise {
  let layout = self.at(layout_name)
  let region = match self.render_map.get(layout) {
    Some(r) => r.region
    None => raise KeyError(layout.repr())
  }
  let { x, y, width, height, } = region
  let lines = console.render_lines(
    layout,
    options=console.options().update_dimensions(width, height),
  )
  self.render_map[layout] = { region, render: lines, }
  console.update_screen_lines(lines, x~, y~)
}

///|
fn compare_region(a : @rich.Region, b : @rich.Region) -> Int {
  let c = a.x.compare(b.x)
  if c != 0 {
    return c
  }
  let c = a.y.compare(b.y)
  if c != 0 {
    return c
  }
  let c = a.width.compare(b.width)
  if c != 0 {
    return c
  }
  a.height.compare(b.height)
}

///|
/// Create a map of layouts on to regions, ordered by region.
fn Layout::make_region_map(
  self : Layout,
  width : Int,
  height : Int,
) -> Map[Layout, @rich.Region] {
  let stack : Array[(Layout, @rich.Region)] = [
    (self, { x: 0, y: 0, width, height, }),
  ]
  let layout_regions : Array[(Layout, @rich.Region)] = []
  while stack.pop() is Some(item) {
    layout_regions.push(item)
    let (layout, region) = item
    let children = layout.children()
    if children.length() > 0 {
      for child_and_region in layout.splitter.divide(children, region) {
        stack.push(child_and_region)
      }
    }
  }
  // Stable sort by region.
  let indexed = layout_regions.mapi((i, item) => (i, item))
  indexed.sort_by((a, b) => {
    let c = compare_region(a.1.1, b.1.1)
    if c != 0 {
      c
    } else {
      a.0.compare(b.0)
    }
  })
  let region_map : Map[Layout, @rich.Region] = Map([])
  for item in indexed {
    let (_, (layout, region)) = item
    region_map[layout] = region
  }
  region_map
}

///|
fn height_or(height : Int?, default : Int) -> Int {
  match height {
    Some(h) if h != 0 => h
    _ => default
  }
}

///|
/// Render the sub-layouts: a map of each leaf layout on to its region and
/// rendered lines.
pub fn Layout::render(
  self : Layout,
  console : @rich.Console,
  options : @rich.ConsoleOptions,
) -> Map[Layout, LayoutRender] raise {
  let render_width = options.max_width
  let render_height = height_or(options.height, console.height())
  let region_map = self.make_region_map(render_width, render_height)
  let render_map : Map[Layout, LayoutRender] = Map([])
  for layout, region in region_map {
    if layout.children().length() > 0 {
      continue
    }
    let lines = console.render_lines(
      layout.renderable(),
      options=options.update_dimensions(region.width, region.height),
    )
    render_map[layout] = { region, render: lines, }
  }
  render_map
}

///|
pub impl @rich.Renderable for Layout with fn rich_console(
  self,
  console,
  options,
) {
  let width = if options.max_width != 0 {
    options.max_width
  } else {
    console.width()
  }
  let height = height_or(options.height, console.height())
  let render_map = self.render(
    console,
    options.update_dimensions(width, height),
  )
  self.render_map = render_map
  let layout_lines : Array[Array[@rich.Segment]] = Array::makei(height, _ => [])
  for _, layout_render in render_map {
    let { region, render: lines, } = layout_render
    let { y, height: layout_height, .. } = region
    let end = @cmp.minimum(y + layout_height, height)
    for row in y..<end {
      let line_no = row - y
      if row < 0 || line_no >= lines.length() {
        continue
      }
      layout_lines[row].append(lines[line_no])
    }
  }
  let new_line = @rich.Segment::line()
  let out : Array[@rich.RenderItem] = []
  for layout_row in layout_lines {
    for s in layout_row {
      out.push(Seg(s))
    }
    out.push(Seg(new_line))
  }
  out
}

///|
/// The `__rich_repr__` fields of a layout (fields equal to their default
/// are omitted).
fn Layout::repr_fields(self : Layout) -> Array[(String, String)] {
  let fields = []
  if self.name is Some(name) {
    fields.push(("name", @rich.py_repr(name)))
  }
  if self.size is Some(size) {
    fields.push(("size", size.to_string()))
  }
  if self.minimum_size != 1 {
    fields.push(("minimum_size", self.minimum_size.to_string()))
  }
  if self.ratio != 1 {
    fields.push(("ratio", self.ratio.to_string()))
  }
  fields
}

///|
/// Upstream `repr(layout)`, e.g. `Layout(name='root', size=3)`.
pub fn Layout::repr(self : Layout) -> String {
  let fields = self.repr_fields().map(f => "\{f.0}=\{f.1}")
  "Layout(" + fields.join(", ") + ")"
}

///|
pub impl Show for Layout with fn output(self, logger) {
  logger.write_string(self.repr())
}

///|
/// Upstream `pretty_repr(layout, max_width=...)`: the repr on one line if
/// it fits, otherwise one field per line.
pub fn Layout::pretty_repr(
  self : Layout,
  max_width? : Int = 80,
  indent_size? : Int = 4,
) -> String {
  let one_line = self.repr()
  let fields = self.repr_fields()
  if fields.is_empty() || @cells.cell_len(one_line) <= max_width {
    return one_line
  }
  let indent = " ".repeat(indent_size)
  let lines = ["Layout("]
  for i, field in fields {
    let separator = if i == fields.length() - 1 { "" } else { "," }
    lines.push("\{indent}\{field.0}=\{field.1}\{separator}")
  }
  lines.push(")")
  lines.join("\n")
}

///|
/// Get a tree renderable to show layout structure.
pub fn Layout::tree(self : Layout) -> @tree.Tree raise {
  fn summary(layout : Layout) -> @rich.Table raise {
    let icon = layout.splitter.get_tree_icon()
    let table = @rich.Table::grid(padding=[0, 1, 0, 0])
    let text : &@rich.Renderable = if layout.visible {
      (LayoutPretty::{ layout, } : &@rich.Renderable)
    } else {
      @rich.Styled::new(LayoutPretty::{ layout, }, "dim")
    }
    table.add_row([icon, text])
    table
  }

  let tree = @tree.Tree::new(
    summary(self),
    guide_style="layout.tree.\{self.splitter.name()}",
    highlight=true,
  )
  fn recurse(tree : @tree.Tree, layout : Layout) -> Unit raise {
    for child in layout.children_ {
      recurse(
        tree.add(
          summary(child),
          guide_style="layout.tree.\{child.splitter.name()}",
        ),
        child,
      )
    }
  }

  recurse(tree, self)
  tree
}
