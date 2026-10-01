// Port of rich/syntax.py: the Syntax renderable.

///|
/// Padding between the line numbers and the code.
const NUMBERS_COLUMN_DEFAULT_PADDING : Int = 2

///|
/// A lexer given by name (looked up in `bobzhang/pygments/lexers`) or a
/// lexer instance (upstream `Union[Lexer, str]`).
pub(all) enum LexerSpec {
  Name(String)
  Lexer(@lexer.Lexer)
}

///|
/// Types accepted where upstream takes `Union[Lexer, str]`.
pub(open) trait IntoLexer {
  fn into_lexer_spec(Self) -> LexerSpec
}

///|
pub impl IntoLexer for String with fn into_lexer_spec(self) {
  Name(self)
}

///|
pub impl IntoLexer for @lexer.Lexer with fn into_lexer_spec(self) {
  Lexer(self)
}

///|
pub impl IntoLexer for LexerSpec with fn into_lexer_spec(self) {
  self
}

///|
/// A position in the code: (line number starting from 1, column index
/// starting from 0). Columns are UTF-16 offsets.
pub type SyntaxPosition = (Int, Int)

///|
/// A range to highlight in a Syntax object (upstream `_SyntaxHighlightRange`).
pub(all) struct SyntaxHighlightRange {
  style : @rich.StyleType
  start : SyntaxPosition
  end : SyntaxPosition
  style_before : Bool
}

///|
/// Construct a Syntax object to render syntax highlighted code.
pub(all) struct Syntax {
  /// Code to highlight.
  mut code : String
  /// Lexer to use (upstream `_lexer`).
  mut lexer_spec : LexerSpec
  /// Enable stripping of initial whitespace.
  mut dedent : Bool
  /// Enable rendering of line numbers.
  mut line_numbers : Bool
  /// Starting number for line numbers.
  mut start_line : Int
  /// Start and end line to render (1-based, `None` for open ends).
  mut line_range : (Int?, Int?)?
  /// Line numbers to highlight.
  mut highlight_lines : Array[Int]
  /// Width of code to render (not including line numbers).
  mut code_width : Int?
  /// Size of tabs.
  mut tab_size : Int
  /// Enable word wrapping.
  mut word_wrap : Bool
  /// Background color override.
  mut background_color : String?
  /// Style derived from `background_color`.
  mut background_style : @rich.Style
  /// Show indent guides.
  mut indent_guides : Bool
  /// Padding (top, right, bottom, left).
  mut padding : (Int, Int, Int, Int)
  /// The theme (upstream `_theme`).
  mut theme : &SyntaxTheme
  /// Ranges added with `stylize_range`.
  stylized_ranges : Array[SyntaxHighlightRange]
  priv mut lexer_cache : (String, Int, @lexer.Lexer?)?
}

///|
fn background_style_for(background_color : String?) -> @rich.Style raise {
  match background_color {
    Some(c) if c != "" => @rich.Style::new(bgcolor=@color.Color::parse(c))
    _ => @rich.Style::new()
  }
}

///|
/// Create a Syntax object.
///
/// * `lexer`: lexer name (see `bobzhang/pygments/lexers`) or instance.
/// * `theme`: theme name (Pygments style or `"ansi_light"`/`"ansi_dark"`)
///   or instance. Defaults to `"monokai"`.
/// * `line_range`: start and end line to render (`None` = open).
/// * `padding`: CSS-style padding, 1, 2 or 4 values.
///
/// Raises if `background_color` is not a valid color or `padding` has an
/// invalid length.
pub fn Syntax::new(
  code : String,
  lexer : &IntoLexer,
  theme? : &IntoSyntaxTheme = DEFAULT_THEME,
  dedent? : Bool = false,
  line_numbers? : Bool = false,
  start_line? : Int = 1,
  line_range? : (Int?, Int?),
  highlight_lines? : ArrayView[Int] = [],
  code_width? : Int,
  tab_size? : Int = 4,
  word_wrap? : Bool = false,
  background_color? : String,
  indent_guides? : Bool = false,
  padding? : ArrayView[Int] = [0],
) -> Syntax raise {
  {
    code,
    lexer_spec: lexer.into_lexer_spec(),
    dedent,
    line_numbers,
    start_line,
    line_range,
    highlight_lines: highlight_lines.to_owned(),
    code_width,
    tab_size,
    word_wrap,
    background_color,
    background_style: background_style_for(background_color),
    indent_guides,
    padding: @rich.unpack_padding(padding),
    theme: theme.into_syntax_theme(),
    stylized_ranges: [],
    lexer_cache: None,
  }
}

///|
/// Construct a Syntax object from a file (native backend only; elsewhere
/// the file cannot be read and this raises). If `lexer` is omitted, it is
/// guessed from the path and contents. Only UTF-8 is supported.
pub fn Syntax::from_path(
  path : String,
  lexer? : &IntoLexer,
  theme? : &IntoSyntaxTheme = DEFAULT_THEME,
  dedent? : Bool = false,
  line_numbers? : Bool = false,
  line_range? : (Int?, Int?),
  start_line? : Int = 1,
  highlight_lines? : ArrayView[Int] = [],
  code_width? : Int,
  tab_size? : Int = 4,
  word_wrap? : Bool = false,
  background_color? : String,
  indent_guides? : Bool = false,
  padding? : ArrayView[Int] = [0],
) -> Syntax raise {
  let code = match @fs.read_file(path) {
    Some(code) => code
    None => raise @rich.ValueError("unable to read file \{path}")
  }
  let lexer : &IntoLexer = match lexer {
    Some(l) =>
      match l.into_lexer_spec() {
        Name("") => Name(Syntax::guess_lexer(path, code~))
        spec => spec
      }
    None => Name(Syntax::guess_lexer(path, code~))
  }
  Syntax::new(
    code,
    lexer,
    theme~,
    dedent~,
    line_numbers~,
    line_range?,
    start_line~,
    highlight_lines~,
    code_width?,
    tab_size~,
    word_wrap~,
    background_color?,
    indent_guides~,
    padding~,
  )
}

///|
/// Guess the alias of the Pygments lexer to use based on a path and an
/// optional string of code. With code, the contents help choose between
/// lexers matching the file name; otherwise the file extension is used.
/// Returns `"default"` if nothing matches.
pub fn Syntax::guess_lexer(path : String, code? : String) -> String {
  let mut lexer : @lexer.Lexer? = None
  if code is Some(code) && code != "" {
    lexer = Some(@lexers.guess_lexer_for_filename(path, code)) catch {
      _ => None
    }
  }
  if lexer is None {
    let (_, ext) = splitext(path)
    if ext != "" {
      let extension = ext.trim_start(chars=".").to_owned().to_lower()
      lexer = Some(@lexers.get_lexer_by_name(extension)) catch { _ => None }
    }
  }
  match lexer {
    Some(l) =>
      if l.info.aliases.length() > 0 {
        l.info.aliases[0]
      } else {
        l.info.name
      }
    None => "default"
  }
}

///|
/// Set the padding (1, 2 or 4 values, CSS style).
pub fn Syntax::set_padding(
  self : Syntax,
  padding : ArrayView[Int],
) -> Unit raise {
  self.padding = @rich.unpack_padding(padding)
}

///|
fn lexer_options(tab_size : Int) -> Map[String, String] {
  { "stripnl": "False", "ensurenl": "True", "tabsize": tab_size.to_string() }
}

///|
/// The lexer for this syntax, or `None` if no lexer was found (looked up by
/// name if a name was given).
pub fn Syntax::lexer(self : Syntax) -> @lexer.Lexer? {
  match self.lexer_spec {
    Lexer(l) => Some(l)
    Name(name) =>
      match self.lexer_cache {
        Some((n, t, l)) if n == name && t == self.tab_size => l
        _ => {
          let l = Some(
            @lexers.get_lexer_by_name(
              name,
              options=lexer_options(self.tab_size),
            ),
          ) catch {
            _ => None
          }
          self.lexer_cache = Some((name, self.tab_size, l))
          l
        }
      }
  }
}

///|
/// The lexer used if none is specified or the name is invalid.
pub fn Syntax::default_lexer(self : Syntax) -> @lexer.Lexer {
  try! @lexers.get_lexer_by_name("text", options=lexer_options(self.tab_size))
}

///|
/// Get the base style.
fn Syntax::get_base_style(self : Syntax) -> @rich.Style {
  self.theme.get_background_style() + self.background_style
}

///|
/// Get a color (if any) for the given token.
fn Syntax::get_token_color(
  self : Syntax,
  token_type : @token.TokenType,
) -> @color.Color? {
  self.theme.get_style_for_token(token_type).color()
}

///|
/// Highlight code and return a Text instance. With `line_range`, only the
/// given lines are styled.
pub fn Syntax::highlight(
  self : Syntax,
  code : String,
  line_range? : (Int?, Int?),
) -> @rich.Text raise {
  let base_style = self.get_base_style()
  let justify : @rich.JustifyMethod = if base_style.transparent_background() {
    Default
  } else {
    Left
  }
  let text = @rich.Text::new(
    style=base_style,
    justify~,
    tab_size=self.tab_size,
    no_wrap=!self.word_wrap,
  )
  let theme = self.theme
  let lexer = match self.lexer() {
    Some(l) => l
    None => self.default_lexer()
  }
  let tokens = lexer.get_tokens(code)
  match line_range {
    Some((line_start, line_end)) => {
      // Split tokens to one per line.
      let line_tokens = []
      for item in tokens {
        let (token_type, token) = item
        let mut rest = token
        while rest != "" {
          match rest.find("\n") {
            Some(i) => {
              line_tokens.push(
                (token_type, rest.unsafe_substring(start=0, end=i + 1)),
              )
              rest = rest.unsafe_substring(start=i + 1, end=rest.length())
            }
            None => {
              line_tokens.push((token_type, rest))
              rest = ""
            }
          }
        }
      }
      let spans : Array[(String, @rich.StyleType?)] = []
      let mut line_no = 0
      let line_start_index = match line_start {
        Some(s) if s != 0 => s - 1
        _ => 0
      }
      let mut index = 0
      // Skip over tokens until line start
      while line_no < line_start_index && index < line_tokens.length() {
        let (_, token) = line_tokens[index]
        index += 1
        spans.push((token, None))
        if token.has_suffix("\n") {
          line_no += 1
        }
      }
      // Generate spans until line end
      while index < line_tokens.length() {
        let (token_type, token) = line_tokens[index]
        index += 1
        spans.push((token, Some(Style(theme.get_style_for_token(token_type)))))
        if token.has_suffix("\n") {
          line_no += 1
          if line_end is Some(e) && e != 0 && line_no >= e {
            break
          }
        }
      }
      text.append_tokens(spans) |> ignore
    }
    None =>
      text.append_tokens(
        tokens.map(item => {
          let (token_type, token) = item
          (token, Some(Style(theme.get_style_for_token(token_type))))
        }),
      )
      |> ignore
  }
  if self.background_color is Some(bg) {
    text.stylize("on \{bg}")
  }
  if self.stylized_ranges.length() > 0 {
    self.apply_stylized_ranges(text)
  }
  text
}

///|
/// Add a custom style on a part of the code, applied when rendered. Line
/// numbers are 1-based, column indexes 0-based. With `style_before`, the
/// style is applied before existing styles.
pub fn Syntax::stylize_range(
  self : Syntax,
  style : &@rich.IntoStyle,
  start : SyntaxPosition,
  end : SyntaxPosition,
  style_before? : Bool = false,
) -> Unit {
  self.stylized_ranges.push({
    style: style.into_style_type(),
    start,
    end,
    style_before,
  })
}

///|
/// Color of the line numbers (`blend` towards the text color).
pub fn Syntax::get_line_numbers_color(
  self : Syntax,
  blend? : Double = 0.3,
) -> @color.Color {
  let background_style = self.theme.get_background_style() +
    self.background_style
  let background_color = match background_style.bgcolor() {
    Some(c) if !c.is_system_defined() => c
    _ => return @color.Color::default()
  }
  let foreground_color = match self.get_token_color(@token.text) {
    None => return @color.Color::default()
    Some(c) if c.is_system_defined() => return c
    Some(c) => c
  }
  let new_color = @color.blend_rgb(
    background_color.get_truecolor(),
    foreground_color.get_truecolor(),
    cross_fade=blend,
  )
  @color.Color::from_triplet(new_color)
}

///|
/// The number of characters used to render the numbers column.
pub fn Syntax::numbers_column_width(self : Syntax) -> Int {
  if self.line_numbers {
    let newlines = self.code.iter().filter(c => c == '\n').count()
    (self.start_line + newlines).to_string().length() +
    NUMBERS_COLUMN_DEFAULT_PADDING
  } else {
    0
  }
}

///|
/// Background, number, and highlighted number styles for line numbers.
pub fn Syntax::get_number_styles(
  self : Syntax,
  console : @rich.Console,
) -> (@rich.Style, @rich.Style, @rich.Style) {
  let background_style = self.get_base_style()
  if background_style.transparent_background() {
    return (
      @rich.Style::null(),
      @rich.Style::new(dim=true),
      @rich.Style::null(),
    )
  }
  match console.color_system() {
    Some("256") | Some("truecolor") => {
      let number_style = @rich.Style::chain([
        background_style,
        self.theme.get_style_for_token(@token.text),
        @rich.Style::new(color=self.get_line_numbers_color()),
        self.background_style,
      ])
      let highlight_number_style = @rich.Style::chain([
        background_style,
        self.theme.get_style_for_token(@token.text),
        @rich.Style::new(
          bold=true,
          color=self.get_line_numbers_color(blend=0.9),
        ),
        self.background_style,
      ])
      (background_style, number_style, highlight_number_style)
    }
    _ =>
      (
        background_style,
        background_style + @rich.Style::new(dim=true),
        background_style + @rich.Style::new(dim=false),
      )
  }
}

///|
pub impl @rich.Renderable for Syntax with fn rich_measure(
  self,
  _console,
  _options,
) {
  let (_, right, _, left) = self.padding
  let padding = left + right
  let numbers_column_width = self.numbers_column_width()
  if self.code_width is Some(code_width) {
    let width = code_width + numbers_column_width + padding + 1
    return Some(@rich.Measurement::new(numbers_column_width, width))
  }
  let lines = @lexers.splitlines(self.code)
  let mut max_len = 0
  for line in lines {
    max_len = @cmp.maximum(max_len, @cells.cell_len(line))
  }
  let mut width = numbers_column_width + padding + max_len
  if self.line_numbers {
    width += 1
  }
  Some(@rich.Measurement::new(numbers_column_width, width))
}

///|
/// Pre-rendered segments (upstream `Segments`).
priv struct Segments {
  segments : Array[@rich.Segment]
}

///|
impl @rich.Renderable for Segments with fn rich_console(
  self,
  _console,
  _options,
) {
  @rich.segments_to_items(self.segments)
}

///|
pub impl @rich.Renderable for Syntax with fn rich_console(
  self,
  console,
  options,
) {
  let segments = Segments::{ segments: self.get_syntax(console, options), }
  let (top, right, bottom, left) = self.padding
  if top != 0 || right != 0 || bottom != 0 || left != 0 {
    [
      Child(
        @rich.Padding::new(segments, style=self.get_base_style(), pad=[
          top, right, bottom, left,
        ]),
      ),
    ]
  } else {
    [Child(segments)]
  }
}

///|
/// Python slice bounds for `xs[start:end]`.
fn[T] py_slice(xs : Array[T], start : Int, end : Int?) -> Array[T] {
  let n = xs.length()
  let norm = (i : Int) => {
    if i < 0 {
      @cmp.maximum(0, i + n)
    } else {
      @cmp.minimum(i, n)
    }
  }
  let s = norm(start)
  let e = match end {
    Some(e) => norm(e)
    None => n
  }
  if s >= e {
    []
  } else {
    xs[s:e].to_owned()
  }
}

///|
/// Get the segments for the Syntax object, excluding any vertical /
/// horizontal padding.
fn Syntax::get_syntax(
  self : Syntax,
  console : @rich.Console,
  options : @rich.ConsoleOptions,
) -> Array[@rich.Segment] raise {
  let out : Array[@rich.Segment] = []
  let transparent_background = self.get_base_style().transparent_background()
  let (_, pad_right, _, pad_left) = self.padding
  let horizontal_padding = pad_left + pad_right
  let code_width = match self.code_width {
    None =>
      (if self.line_numbers {
        options.max_width - self.numbers_column_width() - 1
      } else {
        options.max_width
      }) -
      horizontal_padding
    Some(w) => w
  }
  let code_width = @cmp.maximum(0, code_width)
  let (ends_on_nl, processed_code) = self.process_code(self.code)
  let text = self.highlight(processed_code, line_range?=self.line_range)
  if !self.line_numbers && !self.word_wrap && self.line_range is None {
    if !ends_on_nl {
      text.remove_suffix("\n")
    }
    // Simple case of just rendering text
    let style = self.get_base_style() +
      self.theme.get_style_for_token(@token.comment) +
      @rich.Style::new(dim=true) +
      self.background_style
    let text = if self.indent_guides && !options.ascii_only() {
      let t = text.with_indent_guides(indent_size=self.tab_size, style~)
      t.overflow = Some(Crop)
      t
    } else {
      text
    }
    if style.transparent_background() {
      out.append(console.render(text, options=options.update(width=code_width)))
    } else {
      let syntax_lines = console.render_lines(
        text,
        options=options.update(
          width=code_width,
          height=None,
          justify=Some(Left),
        ),
        style=self.background_style,
        pad=true,
        new_lines=true,
      )
      for syntax_line in syntax_lines {
        out.append(syntax_line)
      }
    }
    return out
  }
  let (start_line, end_line) = match self.line_range {
    Some(r) => r
    None => (None, None)
  }
  let line_offset = match start_line {
    Some(s) if s != 0 => @cmp.maximum(0, s - 1)
    _ => 0
  }
  let mut lines = text.split(separator="\n", allow_blank=ends_on_nl).lines
  if self.line_range is Some(_) {
    if line_offset > lines.length() {
      return out
    }
    lines = py_slice(lines, line_offset, end_line)
  }
  if self.indent_guides && !options.ascii_only() {
    let style = self.get_base_style() +
      self.theme.get_style_for_token(@token.comment) +
      @rich.Style::new(dim=true) +
      self.background_style
    lines = @rich.Text::new(text="\n")
      .join(lines)
      .with_indent_guides(
        indent_size=self.tab_size,
        style=style + @rich.Style::new(italic=false),
      )
      .split(separator="\n", allow_blank=true).lines
  }
  let numbers_column_width = self.numbers_column_width()
  let render_options = options.update(width=code_width)
  let new_line = @rich.Segment::new("\n")
  let line_pointer = if options.legacy_windows { "> " } else { "❱ " }
  let (background_style, number_style, highlight_number_style) = self.get_number_styles(
    console,
  )
  for i, line in lines {
    let line_no = self.start_line + line_offset + i
    let wrapped_lines = if self.word_wrap {
      console.render_lines(
        line,
        options=render_options.update(height=None, justify=Some(Left)),
        style=background_style,
        pad=!transparent_background,
      )
    } else {
      let segments = line.render(console, end="")
      if options.no_wrap is Some(true) {
        [segments]
      } else {
        [
          @rich.Segment::adjust_line_length(
            segments,
            render_options.max_width,
            style=background_style,
            pad=!transparent_background,
          ),
        ]
      }
    }
    if self.line_numbers {
      let wrapped_line_left_pad = @rich.Segment::new(
        " ".repeat(numbers_column_width) + " ",
        style=background_style,
      )
      for j, wrapped_line in wrapped_lines {
        if j == 0 {
          let line_column = rjust(line_no.to_string(), numbers_column_width - 2) +
            " "
          if self.highlight_lines.contains(line_no) {
            out.push(
              @rich.Segment::new(line_pointer, style=@rich.Style::parse("red")),
            )
            out.push(
              @rich.Segment::new(line_column, style=highlight_number_style),
            )
          } else {
            out.push(@rich.Segment::new("  ", style=highlight_number_style))
            out.push(@rich.Segment::new(line_column, style=number_style))
          }
        } else {
          out.push(wrapped_line_left_pad)
        }
        out.append(wrapped_line)
        out.push(new_line)
      }
    } else {
      for wrapped_line in wrapped_lines {
        out.append(wrapped_line)
        out.push(new_line)
      }
    }
  }
  out
}

///|
/// Python `str.rjust`.
fn rjust(s : String, width : Int) -> String {
  let n = s.length()
  if n >= width {
    s
  } else {
    " ".repeat(width - n) + s
  }
}

///|
/// Apply stylized ranges to a text instance.
fn Syntax::apply_stylized_ranges(self : Syntax, text : @rich.Text) -> Unit {
  let code = text.plain()
  let newlines_offsets = [0]
  for i in 0..<code.length() {
    if code[i] == '\n' {
      newlines_offsets.push(i + 1)
    }
  }
  newlines_offsets.push(code.length() + 1)
  for stylized_range in self.stylized_ranges {
    let start = get_code_index_for_syntax_position(
      newlines_offsets,
      stylized_range.start,
    )
    let end = get_code_index_for_syntax_position(
      newlines_offsets,
      stylized_range.end,
    )
    if start is Some(start) && end is Some(end) {
      if stylized_range.style_before {
        text.stylize_before(stylized_range.style, start~, end~)
      } else {
        text.stylize(stylized_range.style, start~, end~)
      }
    }
  }
}

///|
/// Normalise the code so it ends with a new line, dedent it if necessary,
/// and expand tabs. Returns whether the raw code ended with a new line,
/// and the processed code.
fn Syntax::process_code(self : Syntax, code : String) -> (Bool, String) {
  let ends_on_nl = code.has_suffix("\n")
  let processed_code = if ends_on_nl { code } else { code + "\n" }
  let processed_code = if self.dedent {
    dedent(processed_code)
  } else {
    processed_code
  }
  (ends_on_nl, expandtabs(processed_code, self.tab_size))
}

///|
/// The index in the code string for a position, or `None` if the line
/// number is out of range (columns out of range are clamped).
fn get_code_index_for_syntax_position(
  newlines_offsets : Array[Int],
  position : SyntaxPosition,
) -> Int? {
  let lines_count = newlines_offsets.length()
  let (line_number, column_index) = position
  if line_number > lines_count || newlines_offsets.length() < line_number + 1 {
    return None
  }
  // Python indexing (negative indexes count from the end)
  let at = (i : Int) => {
    if i < 0 {
      newlines_offsets[i + lines_count]
    } else {
      newlines_offsets[i]
    }
  }
  let line_index = line_number - 1
  let line_length = at(line_index + 1) - at(line_index) - 1
  let column_index = @cmp.minimum(line_length, column_index)
  Some(at(line_index) + column_index)
}
