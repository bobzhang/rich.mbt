// The console protocol (rich/abc.py, rich/protocol.py, parts of
// rich/console.py) and small shared types.

///|
/// Something that may be rendered by a `Console`: upstream's
/// `__rich_console__` (required) and `__rich_measure__` (optional).
///
/// `String` and `Text` implement it; any other type can implement
/// `rich_console`, returning segments and/or nested renderables.
pub(open) trait Renderable {
  /// Render to segments and/or nested renderables.
  fn rich_console(Self, Console, ConsoleOptions) -> Array[RenderItem] raise
  /// Measure the minimum and maximum width. `None` means "not measurable",
  /// which upstream treats as `Measurement(0, options.max_width)`.
  fn rich_measure(Self, Console, ConsoleOptions) -> Measurement? raise = _
  /// Whether this is a plain string or a `Text` (upstream `isinstance`
  /// checks). Only `String` and `Text` should override this.
  fn text_kind(Self) -> TextKind = _
  /// Vertical alignment requested by the renderable (upstream reads a
  /// `vertical` attribute from table cells, e.g. on `Align`).
  fn vertical_align(Self) -> VerticalAlignMethod? = _
}

///|
impl Renderable with fn vertical_align(_self) {
  None
}

///|
impl Renderable with fn rich_measure(_self, _console, _options) {
  None
}

///|
impl Renderable with fn text_kind(_self) {
  NotText
}

///|
/// Result of `Renderable::text_kind`.
pub(all) enum TextKind {
  NotText
  Str(String)
  Text(Text)
}

///|
/// An item produced by `Renderable::rich_console`: a segment, or another
/// renderable to be rendered in turn.
pub(all) enum RenderItem {
  Seg(Segment)
  Child(&Renderable)
}

///|
/// Wrap segments as render items.
pub fn segments_to_items(segments : Array[Segment]) -> Array[RenderItem] {
  segments.map(s => Seg(s))
}

///|
pub impl Renderable for String with fn rich_console(self, console, options) {
  let text = console.render_str(
    self,
    highlight=options.highlight,
    markup=options.markup,
  )
  text.rich_console(console, options)
}

///|
pub impl Renderable for String with fn rich_measure(self, console, options) {
  let text = console.render_str(
    self,
    markup=options.markup,
    highlight=Some(false),
  )
  text.rich_measure(console, options)
}

///|
pub impl Renderable for String with fn text_kind(self) {
  Str(self)
}

///|
/// Justify methods.
pub(all) enum JustifyMethod {
  Default
  Left
  Center
  Right
  Full
} derive(Eq, Hash, Debug)

///|
pub fn JustifyMethod::to_string(self : JustifyMethod) -> String {
  match self {
    Default => "default"
    Left => "left"
    Center => "center"
    Right => "right"
    Full => "full"
  }
}

///|
/// Parse a justify method name (`"default"`, `"left"`, ...).
pub fn JustifyMethod::parse(s : String) -> JustifyMethod? {
  match s {
    "default" => Some(Default)
    "left" => Some(Left)
    "center" => Some(Center)
    "right" => Some(Right)
    "full" => Some(Full)
    _ => None
  }
}

///|
/// Overflow methods.
pub(all) enum OverflowMethod {
  Fold
  Crop
  Ellipsis
  Ignore
} derive(Eq, Hash, Debug)

///|
pub fn OverflowMethod::to_string(self : OverflowMethod) -> String {
  match self {
    Fold => "fold"
    Crop => "crop"
    Ellipsis => "ellipsis"
    Ignore => "ignore"
  }
}

///|
/// Parse an overflow method name.
pub fn OverflowMethod::parse(s : String) -> OverflowMethod? {
  match s {
    "fold" => Some(Fold)
    "crop" => Some(Crop)
    "ellipsis" => Some(Ellipsis)
    "ignore" => Some(Ignore)
    _ => None
  }
}

///|
/// Horizontal alignment.
pub(all) enum AlignMethod {
  Left
  Center
  Right
} derive(Eq, Hash, Debug)

///|
pub fn AlignMethod::to_string(self : AlignMethod) -> String {
  match self {
    Left => "left"
    Center => "center"
    Right => "right"
  }
}

///|
/// Vertical alignment.
pub(all) enum VerticalAlignMethod {
  Top
  Middle
  Bottom
} derive(Eq, Hash, Debug)

///|
pub fn VerticalAlignMethod::to_string(self : VerticalAlignMethod) -> String {
  match self {
    Top => "top"
    Middle => "middle"
    Bottom => "bottom"
  }
}

///|
/// A style definition (looked up in the theme, then parsed, at render
/// time) or a `Style` (upstream `StyleType = Union[str, Style]`).
pub(all) enum StyleType {
  Def(String)
  Style(Style)
} derive(Eq, Hash)

///|
/// Upstream `bool(style)`: a non-empty definition or a non-null style.
pub fn StyleType::to_bool(self : StyleType) -> Bool {
  match self {
    Def(s) => s != ""
    Style(s) => s.to_bool()
  }
}

///|
/// Upstream `repr(style)` for a str or Style.
pub fn StyleType::repr(self : StyleType) -> String {
  match self {
    Def(s) => py_repr(s)
    Style(s) => s.repr()
  }
}

///|
/// Upstream `str(style)`.
pub impl Show for StyleType with fn output(self, logger) {
  match self {
    Def(s) => logger.write_string(s)
    Style(s) => logger.write_string(s.to_definition())
  }
}

///|
pub impl Debug for StyleType with fn to_repr(self) {
  @debug.Repr(self.repr())
}

///|
/// Types accepted where upstream takes `Union[str, Style]`.
pub(open) trait IntoStyle {
  fn into_style_type(Self) -> StyleType
}

///|
pub impl IntoStyle for String with fn into_style_type(self) {
  Def(self)
}

///|
pub impl IntoStyle for Style with fn into_style_type(self) {
  StyleType::Style(self)
}

///|
pub impl IntoStyle for StyleType with fn into_style_type(self) {
  self
}

///|
fn style_or_empty(style : &IntoStyle?) -> StyleType {
  match style {
    Some(s) => s.into_style_type()
    None => Def("")
  }
}

///|
fn style_opt(style : &IntoStyle?) -> StyleType? {
  match style {
    Some(s) => Some(s.into_style_type())
    None => None
  }
}

///|
/// A plain string or a `Text` instance (upstream `TextType`).
pub(all) enum TextType {
  Str(String)
  Text(Text)
}

///|
/// Types accepted where upstream takes `Union[str, Text]`.
pub(open) trait IntoText {
  fn into_text_type(Self) -> TextType
}

///|
pub impl IntoText for String with fn into_text_type(self) {
  Str(self)
}

///|
pub impl IntoText for Text with fn into_text_type(self) {
  TextType::Text(self)
}

///|
pub impl IntoText for TextType with fn into_text_type(self) {
  self
}

///|
/// Upstream `bool(text)`.
pub fn TextType::to_bool(self : TextType) -> Bool {
  match self {
    Str(s) => s != ""
    Text(t) => t.length() > 0
  }
}

///|
/// Upstream `str(text)`.
pub fn TextType::plain(self : TextType) -> String {
  match self {
    Str(s) => s
    Text(t) => t.plain()
  }
}

///|
pub impl Renderable for TextType with fn rich_console(self, console, options) {
  match self {
    Str(s) => Renderable::rich_console(s, console, options)
    Text(t) => Renderable::rich_console(t, console, options)
  }
}

///|
pub impl Renderable for TextType with fn rich_measure(self, console, options) {
  match self {
    Str(s) => Renderable::rich_measure(s, console, options)
    Text(t) => Renderable::rich_measure(t, console, options)
  }
}

///|
pub impl Renderable for TextType with fn text_kind(self) {
  match self {
    Str(s) => Str(s)
    Text(t) => Text(t)
  }
}

///|
/// Stores the minimum and maximum widths (in cells) required to render an
/// object.
pub(all) struct Measurement {
  minimum : Int
  maximum : Int
} derive(Eq, Debug)

///|
pub fn Measurement::new(minimum : Int, maximum : Int) -> Measurement {
  { minimum, maximum, }
}

///|
pub impl Show for Measurement with fn output(self, logger) {
  logger.write_string(
    "Measurement(minimum=\{self.minimum}, maximum=\{self.maximum})",
  )
}

///|
/// Difference between maximum and minimum.
pub fn Measurement::span(self : Measurement) -> Int {
  self.maximum - self.minimum
}

///|
/// Ensure that minimum <= maximum and minimum >= 0.
pub fn Measurement::normalize(self : Measurement) -> Measurement {
  let { minimum, maximum, } = self
  let minimum = @cmp.minimum(@cmp.maximum(0, minimum), maximum)
  {
    minimum: @cmp.maximum(0, minimum),
    maximum: @cmp.maximum(0, @cmp.maximum(minimum, maximum)),
  }
}

///|
/// Get a measurement where the widths are <= width.
pub fn Measurement::with_maximum(
  self : Measurement,
  width : Int,
) -> Measurement {
  {
    minimum: @cmp.minimum(self.minimum, width),
    maximum: @cmp.minimum(self.maximum, width),
  }
}

///|
/// Get a measurement where the widths are >= width.
pub fn Measurement::with_minimum(
  self : Measurement,
  width : Int,
) -> Measurement {
  let width = @cmp.maximum(0, width)
  {
    minimum: @cmp.maximum(self.minimum, width),
    maximum: @cmp.maximum(self.maximum, width),
  }
}

///|
/// Clamp a measurement within the specified range.
pub fn Measurement::clamp(
  self : Measurement,
  min_width? : Int,
  max_width? : Int,
) -> Measurement {
  let mut m = self
  if min_width is Some(w) {
    m = m.with_minimum(w)
  }
  if max_width is Some(w) {
    m = m.with_maximum(w)
  }
  m
}

///|
/// Get a measurement for a renderable.
pub fn Measurement::get(
  console : Console,
  options : ConsoleOptions,
  renderable : &Renderable,
) -> Measurement raise {
  let max_width = options.max_width
  if max_width < 1 {
    return { minimum: 0, maximum: 0, }
  }
  match renderable.rich_measure(console, options) {
    Some(m) => {
      let render_width = m.normalize().with_maximum(max_width)
      if render_width.maximum < 1 {
        return { minimum: 0, maximum: 0, }
      }
      render_width.normalize()
    }
    None => { minimum: 0, maximum: max_width, }
  }
}

///|
/// Get a measurement that would fit a number of renderables.
pub fn measure_renderables(
  console : Console,
  options : ConsoleOptions,
  renderables : ArrayView[&Renderable],
) -> Measurement raise {
  if renderables.length() == 0 {
    return { minimum: 0, maximum: 0, }
  }
  let measurements = []
  for r in renderables {
    measurements.push(Measurement::get(console, options, r))
  }
  // max() with a key returns the first maximal item
  let mut min_m = measurements[0]
  let mut max_m = measurements[0]
  for m in measurements {
    if m.minimum > min_m.minimum {
      min_m = m
    }
    if m.maximum > max_m.maximum {
      max_m = m
    }
  }
  { minimum: min_m.minimum, maximum: max_m.maximum, }
}

///|
/// Size of the terminal.
pub(all) struct ConsoleDimensions {
  width : Int
  height : Int
} derive(Eq, Debug)

///|
/// Options for `Renderable::rich_console`.
pub(all) struct ConsoleOptions {
  /// Size of console.
  mut size : ConsoleDimensions
  /// Flag for legacy windows.
  mut legacy_windows : Bool
  /// Minimum width of renderable.
  mut min_width : Int
  /// Maximum width of renderable.
  mut max_width : Int
  /// True if the target is a terminal.
  mut is_terminal : Bool
  /// Encoding of terminal.
  mut encoding : String
  /// Height of container (starts as terminal).
  mut max_height : Int
  /// Justify value override for renderable.
  mut justify : JustifyMethod?
  /// Overflow value override for renderable.
  mut overflow : OverflowMethod?
  /// Disable wrapping for text.
  mut no_wrap : Bool?
  /// Highlight override for render_str.
  mut highlight : Bool?
  /// Enable markup when rendering strings.
  mut markup : Bool?
  /// Height available, if fixed.
  mut height : Int?
}

///|
/// Check if renderables should use ascii only.
pub fn ConsoleOptions::ascii_only(self : ConsoleOptions) -> Bool {
  !self.encoding.has_prefix("utf")
}

///|
/// Return a copy of the options.
pub fn ConsoleOptions::copy(self : ConsoleOptions) -> ConsoleOptions {
  { ..self, }
}

///|
/// Update values, return a copy. Omitted arguments are left unchanged
/// (upstream `NO_CHANGE`); `Some(None)`-style values reset an option.
pub fn ConsoleOptions::update(
  self : ConsoleOptions,
  width? : Int,
  min_width? : Int,
  max_width? : Int,
  justify? : JustifyMethod?,
  overflow? : OverflowMethod?,
  no_wrap? : Bool?,
  highlight? : Bool?,
  markup? : Bool?,
  height? : Int?,
) -> ConsoleOptions {
  let options = self.copy()
  if width is Some(w) {
    options.min_width = @cmp.maximum(0, w)
    options.max_width = @cmp.maximum(0, w)
  }
  if min_width is Some(w) {
    options.min_width = w
  }
  if max_width is Some(w) {
    options.max_width = w
  }
  if justify is Some(j) {
    options.justify = j
  }
  if overflow is Some(o) {
    options.overflow = o
  }
  if no_wrap is Some(n) {
    options.no_wrap = n
  }
  if highlight is Some(h) {
    options.highlight = h
  }
  if markup is Some(m) {
    options.markup = m
  }
  if height is Some(h) {
    if h is Some(h) {
      options.max_height = h
    }
    options.height = match h {
      None => None
      Some(h) => Some(@cmp.maximum(0, h))
    }
  }
  options
}

///|
/// Update just the width (sets both min_width and max_width).
pub fn ConsoleOptions::update_width(
  self : ConsoleOptions,
  width : Int,
) -> ConsoleOptions {
  let options = self.copy()
  options.min_width = @cmp.maximum(0, width)
  options.max_width = @cmp.maximum(0, width)
  options
}

///|
/// Update the height.
pub fn ConsoleOptions::update_height(
  self : ConsoleOptions,
  height : Int,
) -> ConsoleOptions {
  let options = self.copy()
  options.max_height = height
  options.height = Some(height)
  options
}

///|
/// Return a copy of the options with height set to `None`.
pub fn ConsoleOptions::reset_height(self : ConsoleOptions) -> ConsoleOptions {
  let options = self.copy()
  options.height = None
  options
}

///|
/// Update the width and height.
pub fn ConsoleOptions::update_dimensions(
  self : ConsoleOptions,
  width : Int,
  height : Int,
) -> ConsoleOptions {
  let options = self.copy()
  options.min_width = @cmp.maximum(0, width)
  options.max_width = @cmp.maximum(0, width)
  options.height = Some(height)
  options.max_height = height
  options
}

///|
/// Upstream `_pick.pick_bool`: the first non-`None` value, or `false`.
pub fn pick_bool(values : Array[Bool?]) -> Bool {
  for v in values {
    if v is Some(b) {
      return b
    }
  }
  false
}

///|
/// Pair each item with a flag that is true for the last item
/// (upstream `_loop.loop_last`).
fn[T] loop_last(xs : ArrayView[T]) -> Array[(Bool, T)] {
  let n = xs.length()
  let out = []
  for i, x in xs {
    out.push((i == n - 1, x))
  }
  out
}

///|
/// Pair each item with a flag that is true for the first item.
fn[T] loop_first(xs : ArrayView[T]) -> Array[(Bool, T)] {
  let out = []
  for i, x in xs {
    out.push((i == 0, x))
  }
  out
}

///|
/// Pair each item with flags for first and last.
fn[T] loop_first_last(xs : ArrayView[T]) -> Array[(Bool, Bool, T)] {
  let n = xs.length()
  let out = []
  for i, x in xs {
    out.push((i == 0, i == n - 1, x))
  }
  out
}
