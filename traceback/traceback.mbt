// Port of rich/traceback.py: the Traceback renderable, rendered from a
// `Trace` (see model.mbt).

///|
/// Default maximum length of containers in locals.
pub const LOCALS_MAX_LENGTH : Int = 10

///|
/// Default maximum length of strings in locals.
pub const LOCALS_MAX_STRING : Int = 80

///|
/// Yield (line, column1, column2) per line between two positions; `-1` as
/// `column2` means "to the end of the line".
fn iter_syntax_lines(
  start : (Int, Int),
  end : (Int, Int),
) -> Array[(Int, Int, Int)] {
  let (line1, column1) = start
  let (line2, column2) = end
  if line1 == line2 {
    return [(line1, column1, column2)]
  }
  let out = []
  for line_no in line1..<=line2 {
    if line_no == line1 {
      out.push((line_no, column1, -1))
    } else if line_no == line2 {
      out.push((line_no, 0, column2))
    } else {
      out.push((line_no, 0, -1))
    }
  }
  out
}

///|
/// A Console renderable that renders a traceback.
pub(all) struct Traceback {
  /// The trace to render.
  mut trace : Trace
  /// Number of characters used to render the traceback (`None` = all).
  mut width : Int?
  /// Number of code characters used to render code (`None` = all).
  mut code_width : Int?
  /// Additional lines of code to render around the error line.
  mut extra_lines : Int
  /// The syntax theme.
  mut theme : &@syntax.SyntaxTheme
  /// Enable word wrapping of long lines.
  mut word_wrap : Bool
  /// Enable display of local variables.
  mut show_locals : Bool
  /// Enable indent guides in code and locals.
  mut indent_guides : Bool
  /// Maximum length of containers in locals.
  mut locals_max_length : Int
  /// Maximum length of strings in locals.
  mut locals_max_string : Int
  /// Maximum depth of locals.
  mut locals_max_depth : Int?
  /// Hide locals prefixed with double underscore.
  mut locals_hide_dunder : Bool
  /// Hide locals prefixed with single underscore.
  mut locals_hide_sunder : Bool
  /// How to handle overflowing locals.
  mut locals_overflow : @rich.OverflowMethod?
  /// Normalized paths whose frames do not show source code.
  mut suppress : Array[String]
  /// Maximum number of frames per stack (0 for no maximum).
  mut max_frames : Int
  /// Reads the source of a file (upstream `linecache.getlines`).
  mut source_reader : (String) -> String?
  /// Whether a file exists (upstream `os.path.exists`).
  mut path_exists : (String) -> Bool
}

///|
/// Python `os.path.normpath` (POSIX).
fn normpath(path : String) -> String {
  if path == "" {
    return "."
  }
  let initial_slashes = if path.has_prefix("//") && !path.has_prefix("///") {
    2
  } else if path.has_prefix("/") {
    1
  } else {
    0
  }
  let comps : Array[String] = []
  for comp in path.split("/") {
    let comp = comp.to_owned()
    if comp == "" || comp == "." {
      continue
    }
    if comp != ".." ||
      (initial_slashes == 0 && comps.length() == 0) ||
      (comps.length() > 0 && comps[comps.length() - 1] == "..") {
      comps.push(comp)
    } else if comps.length() > 0 {
      comps.pop() |> ignore
    }
  }
  let result = "/".repeat(initial_slashes) + comps.join("/")
  if result == "" {
    "."
  } else {
    result
  }
}

///|
/// Python `os.path.normpath(os.path.abspath(path))`; relative paths are
/// resolved against the current directory when it is known.
fn normalize_path(path : String) -> String {
  if path.has_prefix("/") {
    return normpath(path)
  }
  match @env.current_dir() {
    Some(cwd) => normpath(cwd + "/" + path)
    None => normpath(path)
  }
}

///|
/// Create a Traceback renderable for `trace`.
///
/// * `width`: characters used for the traceback (`None` for all).
/// * `code_width`: characters used for code (`None` for all).
/// * `extra_lines`: lines of code around the error line.
/// * `theme`: syntax theme (name or instance); defaults to `"ansi_dark"`.
/// * `suppress`: paths whose frames do not show source code.
/// * `max_frames`: maximum frames per stack, 0 for no maximum (values
///   below 4 are raised to 4).
/// * `source_reader`: reads source files (default: the file system on
///   native, nothing elsewhere).
/// * `path_exists`: whether a file exists (default: `source_reader`
///   returns `Some` if a reader was given, else the file system).
pub fn Traceback::new(
  trace : Trace,
  width? : Int? = Some(100),
  code_width? : Int? = Some(88),
  extra_lines? : Int = 3,
  theme? : &@syntax.IntoSyntaxTheme,
  word_wrap? : Bool = false,
  show_locals? : Bool = false,
  locals_max_length? : Int = LOCALS_MAX_LENGTH,
  locals_max_string? : Int = LOCALS_MAX_STRING,
  locals_max_depth? : Int,
  locals_hide_dunder? : Bool = true,
  locals_hide_sunder? : Bool = false,
  locals_overflow? : @rich.OverflowMethod,
  indent_guides? : Bool = true,
  suppress? : ArrayView[String] = [],
  max_frames? : Int = 100,
  source_reader? : (String) -> String?,
  path_exists? : (String) -> Bool,
) -> Traceback {
  let theme = match theme {
    Some(t) => t.into_syntax_theme()
    None => @syntax.get_theme("ansi_dark")
  }
  let (source_reader, path_exists) = match (source_reader, path_exists) {
    (Some(r), Some(e)) => (r, e)
    (Some(r), None) => (r, (f : String) => r(f) is Some(_))
    (None, Some(e)) => (@fs.read_file, e)
    (None, None) => (@fs.read_file, @fs.exists)
  }
  {
    trace,
    width,
    code_width,
    extra_lines,
    theme,
    word_wrap,
    show_locals,
    indent_guides,
    locals_max_length,
    locals_max_string,
    locals_max_depth,
    locals_hide_dunder,
    locals_hide_sunder,
    locals_overflow,
    suppress: suppress.iter().map(normalize_path).collect(),
    max_frames: if max_frames > 0 {
      @cmp.maximum(4, max_frames)
    } else {
      0
    },
    source_reader,
    path_exists,
  }
}

///|
/// Lexer names for some Python file extensions (upstream `LEXERS`).
let lexers_by_extension : Map[String, String] = {
  "": "text",
  ".py": "python",
  ".pxd": "cython",
  ".pyx": "cython",
  ".pxi": "pyrex",
}

///|
/// Guess the lexer name for a file. Raises (as upstream's `str.index`) if
/// the file has no extension and the code has no new line.
pub fn Traceback::guess_lexer(
  filename : String,
  code : String,
) -> String raise @rich.RichError {
  let (_, ext) = @syntax.splitext(filename)
  if ext == "" {
    // No extension, look at first line to see if it is a hashbang
    let first_line = match code.find("\n") {
      Some(i) => code.unsafe_substring(start=0, end=i)
      None => raise @rich.ValueError("substring not found")
    }
    if first_line.has_prefix("#!") && first_line.to_lower().contains("python") {
      return "python"
    }
  }
  match lexers_by_extension.get(ext) {
    Some(name) if name != "" => name
    _ =>
      @lexers.guess_lexer_for_filename(filename, code).name() catch {
        _ => "text"
      }
  }
}

///|
/// Python `str.lstrip()` / `str.rstrip()` whitespace test.
fn is_py_space(c : Char) -> Bool {
  match c {
    ' ' | '\t' | '\n' | '\r' | '\u{0b}' | '\u{0c}' => true
    '\u{1c}'..='\u{1f}' | '\u{85}' | '\u{a0}' | '\u{1680}' => true
    '\u{2000}'..='\u{200a}' | '\u{2028}' | '\u{2029}' | '\u{202f}' => true
    '\u{205f}' | '\u{3000}' => true
    _ => false
  }
}

///|
/// Python `str.rstrip()`.
fn py_rstrip(s : String) -> String {
  let mut end = s.length()
  while end > 0 && is_py_space(s[end - 1].unsafe_to_char()) {
    end -= 1
  }
  s.unsafe_substring(start=0, end~)
}

///|
/// Length of the leading whitespace of `s` (`len(s) - len(s.lstrip())`).
fn leading_space(s : String) -> Int {
  let mut i = 0
  while i < s.length() && is_py_space(s[i].unsafe_to_char()) {
    i += 1
  }
  i
}

///|
/// The source of a file as `linecache` provides it: universal new lines,
/// and a final new line.
fn Traceback::read_lines(self : Traceback, filename : String) -> Array[String] {
  let code = match (self.source_reader)(filename) {
    Some(code) => code
    None => return []
  }
  if code == "" {
    return []
  }
  let code = code
    .replace_all(old="\r\n", new="\n")
    .replace_all(old="\r", new="\n")
  let lines = []
  let mut start = 0
  for i in 0..<code.length() {
    if code[i] == '\n' {
      lines.push(code.unsafe_substring(start~, end=i + 1))
      start = i + 1
    }
  }
  if start < code.length() {
    lines.push(code.unsafe_substring(start~, end=code.length()) + "\n")
  }
  lines
}

///|
let path_highlighter_instance : @rich.RegexHighlighter = try! @rich.RegexHighlighter::new([
    "(?P<dim>.*/)(?P<bold>.+)",
  ],
)

///|
/// Highlights the directory part of a path dim and the file name bold
/// (upstream `rich.traceback.PathHighlighter`).
pub struct PathHighlighter {
  priv inner : @rich.RegexHighlighter
}

///|
pub fn PathHighlighter::new() -> PathHighlighter {
  { inner: path_highlighter_instance, }
}

///|
pub impl @rich.Highlighter for PathHighlighter with fn highlight(self, text) {
  self.inner.highlight(text)
}

///|
let path_highlighter : &@rich.Highlighter = PathHighlighter::new()

///|
let repr_highlighter : &@rich.Highlighter = @rich.ReprHighlighter::new()

///|
fn Traceback::render_locals(
  self : Traceback,
  frame : Frame,
) -> Array[&@rich.Renderable] {
  match frame.locals {
    Some(locals) if locals.length() > 0 => {
      let scope : Map[String, &@pretty.PrettyRepr] = Map([])
      for key, value in locals {
        scope[key] = value
      }
      [
        @scope.render_scope(
          scope,
          title="locals",
          indent_guides=self.indent_guides,
          max_length=self.locals_max_length,
          max_string=self.locals_max_string,
          max_depth?=self.locals_max_depth,
          overflow?=self.locals_overflow,
        ),
      ]
    }
    _ => []
  }
}

///|
/// Python list indexing (negative indexes count from the end).
fn[T] py_index(xs : Array[T], i : Int) -> T? {
  let i = if i < 0 { i + xs.length() } else { i }
  if i >= 0 && i < xs.length() {
    Some(xs[i])
  } else {
    None
  }
}

///|
/// Render the frames of a stack (upstream `_render_stack`).
fn Traceback::render_frames(
  self : Traceback,
  stack : Stack,
) -> @rich.Group raise {
  let out : Array[&@rich.Renderable] = []
  let frames = stack.frames
  let exclude_frames = if self.max_frames != 0 {
    Some((self.max_frames / 2, frames.length() - self.max_frames / 2))
  } else {
    None
  }
  let mut excluded = false
  for frame_index, frame in frames {
    if exclude_frames is Some((start, stop)) &&
      stop > start &&
      frame_index >= start &&
      frame_index < stop {
      excluded = true
      continue
    }
    if excluded && exclude_frames is Some((start, stop)) {
      out.push(
        @rich.Text::new(
          text="\n... \{stop - start} frames hidden ...",
          justify=Center,
          style="traceback.error",
        ),
      )
      excluded = false
    }
    let first = frame_index == 0
    let frame_filename = frame.filename
    let suppressed = self.suppress
      .iter()
      .any(path => frame_filename.has_prefix(path))
    let text = if (self.path_exists)(frame.filename) {
      @rich.Text::assemble(
        [
          path_highlighter.apply(
            @rich.Text::new(text=frame.filename, style="pygments.string"),
          ),
          (":", "pygments.text"),
          (frame.lineno.to_string(), "pygments.number"),
          " in ",
          (frame.name, "pygments.function"),
        ],
        style="pygments.text",
      )
    } else {
      @rich.Text::assemble(
        [
          "in ",
          (frame.name, "pygments.function"),
          (":", "pygments.text"),
          (frame.lineno.to_string(), "pygments.number"),
        ],
        style="pygments.text",
      )
    }
    if !frame.filename.has_prefix("<") && !first {
      out.push("")
    }
    out.push(text)
    if frame.filename.has_prefix("<") {
      out.append(self.render_locals(frame))
      continue
    }
    if suppressed {
      continue
    }
    let code_lines = self.read_lines(frame.filename)
    let code = code_lines.join("")
    if code == "" {
      // code may be an empty string if the file doesn't exist, OR
      // if the traceback filename is generated dynamically
      continue
    }
    let lexer_name = Traceback::guess_lexer(frame.filename, code) catch {
      error => {
        out.push(@rich.Text::assemble([("\n\{error}", "traceback.error")]))
        continue
      }
    }
    let syntax = @syntax.Syntax::new(
      code,
      lexer_name,
      theme=self.theme,
      line_numbers=true,
      line_range=(
        Some(frame.lineno - self.extra_lines),
        Some(frame.lineno + self.extra_lines),
      ),
      highlight_lines=[frame.lineno],
      word_wrap=self.word_wrap,
      code_width?=self.code_width,
      indent_guides=self.indent_guides,
      dedent=false,
    )
    out.push("")
    if frame.last_instruction is Some((start, end)) {
      // Stylize a line at a time, so that indentation isn't underlined
      for item in iter_syntax_lines(start, end) {
        let (line1, column1, column2) = item
        let mut column1 = column1
        let mut column2 = column2
        if column1 == 0 {
          match py_index(code_lines, line1 - 1) {
            Some(line) => column1 = leading_space(line)
            None => continue
          }
        }
        if column2 == -1 {
          match py_index(code_lines, line1 - 1) {
            Some(line) => column2 = line.length()
            None => continue
          }
        }
        syntax.stylize_range(
          "traceback.error_range",
          (line1, column1),
          (line1, column2),
        )
      }
    }
    match frame.locals {
      Some(locals) if locals.length() > 0 => {
        let renderables : Array[&@rich.Renderable] = [syntax]
        renderables.append(self.render_locals(frame))
        out.push(@columns.Columns::new(renderables, padding=[1]))
      }
      _ => out.push(syntax)
    }
  }
  @rich.Group::new(out)
}

///|
/// Render a syntax error (upstream `_render_syntax_error`).
fn Traceback::render_syntax_error(
  self : Traceback,
  syntax_error : SyntaxErrorInfo,
) -> @rich.Group raise {
  let out : Array[&@rich.Renderable] = []
  if syntax_error.filename != "<stdin>" &&
    (self.path_exists)(syntax_error.filename) {
    let text = @rich.Text::assemble(
      [
        (" \{syntax_error.filename}", "pygments.string"),
        (":", "pygments.text"),
        (syntax_error.lineno.to_string(), "pygments.number"),
      ],
      style="pygments.text",
    )
    out.push(path_highlighter.apply(text))
  }
  let syntax_error_text = repr_highlighter.apply(py_rstrip(syntax_error.line))
  syntax_error_text.no_wrap = Some(true)
  let offset = @cmp.minimum(syntax_error.offset - 1, syntax_error_text.length())
  syntax_error_text.stylize("bold underline", start=offset, end=offset)
  let marker = @rich.Text::from_markup(
    "\n" + " ".repeat(@cmp.maximum(0, offset)) + "[traceback.offset]▲[/]",
    style="pygments.text",
  )
  out.push(syntax_error_text.concat(marker))
  @rich.Group::new(out)
}

///|
/// Render one stack (upstream's nested `render_stack`).
fn Traceback::render_stack(
  self : Traceback,
  stack : Stack,
  last : Bool,
) -> @rich.Group raise {
  // Upstream builds a theme mapping `pygments.*`, `repr.*` and `scope.*`
  // styles to the syntax theme and pushes it with `console.use_theme` while
  // the renderables are *created* (the `@group` decorator consumes the
  // generator eagerly); it is popped before anything is rendered, so it
  // has no effect on the output and is not reproduced here.
  let background_style = self.theme.get_background_style()
  let out : Array[&@rich.Renderable] = []
  if stack.frames.length() > 0 {
    let stack_renderable = @panel.Panel::new(
      self.render_frames(stack),
      title="[traceback.title]Traceback [dim](most recent call last)",
      style=background_style,
      border_style="traceback.border",
      expand=true,
      padding=[0, 1],
    )
    out.push(@rich.Constrain::new(stack_renderable, width=self.width))
  }
  match stack.syntax_error {
    Some(syntax_error) => {
      out.push(
        @rich.Constrain::new(
          @panel.Panel::new(
            self.render_syntax_error(syntax_error),
            style=background_style,
            border_style="traceback.border.syntax_error",
            expand=true,
            padding=[0, 1],
            width?=self.width,
          ),
          width=self.width,
        ),
      )
      out.push(
        @rich.Text::assemble([
          ("\{stack.exc_type}: ", "traceback.exc_type"),
          repr_highlighter.apply(syntax_error.msg),
        ]),
      )
    }
    None =>
      if stack.exc_value != "" {
        out.push(
          @rich.Text::assemble([
            ("\{stack.exc_type}: ", "traceback.exc_type"),
            repr_highlighter.apply(stack.exc_value),
          ]),
        )
      } else {
        out.push(@rich.Text::assemble([(stack.exc_type, "traceback.exc_type")]))
      }
  }
  for note in stack.notes {
    out.push(
      @rich.Text::assemble([
        ("[NOTE] ", "traceback.note"),
        repr_highlighter.apply(note),
      ]),
    )
  }
  if stack.is_group {
    for i, group_exception in stack.exceptions {
      let grouped_exceptions : Array[&@rich.Renderable] = []
      let n = group_exception.stacks.length()
      for j, group_stack in group_exception.stacks {
        grouped_exceptions.push(self.render_stack(group_stack, j == n - 1))
      }
      out.push("")
      out.push(
        @rich.Constrain::new(
          @panel.Panel::new(
            @rich.Group::new(grouped_exceptions),
            title="Sub-exception #\{i + 1}",
            border_style="traceback.group.border",
          ),
          width=self.width,
        ),
      )
    }
  }
  if !last {
    if stack.is_cause {
      out.push(
        @rich.Text::from_markup(
          "\n[i]The above exception was the direct cause of the following exception:\n",
        ),
      )
    } else {
      out.push(
        @rich.Text::from_markup(
          "\n[i]During handling of the above exception, another exception occurred:\n",
        ),
      )
    }
  }
  @rich.Group::new(out)
}

///|
pub impl @rich.Renderable for Traceback with fn rich_console(
  self,
  _console,
  _options,
) {
  let stacks = self.trace.stacks
  let n = stacks.length()
  let out : Array[@rich.RenderItem] = []
  for i in 0..<n {
    let stack = stacks[n - 1 - i]
    out.push(Child(self.render_stack(stack, i == n - 1)))
  }
  out
}

///|
/// Print a trace to a console (upstream `Console.print_exception`).
pub fn print_exception(
  console : @rich.Console,
  trace : Trace,
  width? : Int? = Some(100),
  extra_lines? : Int = 3,
  theme? : &@syntax.IntoSyntaxTheme,
  word_wrap? : Bool = false,
  show_locals? : Bool = false,
  suppress? : ArrayView[String] = [],
  max_frames? : Int = 100,
  source_reader? : (String) -> String?,
) -> Unit raise {
  let traceback = Traceback::new(
    trace,
    width~,
    extra_lines~,
    theme?,
    word_wrap~,
    show_locals~,
    suppress~,
    max_frames~,
    source_reader?,
  )
  console.print(traceback)
}

///|
/// Print a MoonBit error value as a traceback without frames: the error's
/// `Show` output preceded by `exc_type` (default `"Error"`).
pub fn print_error(
  console : @rich.Console,
  error : Error,
  exc_type? : String = "Error",
  width? : Int? = Some(100),
) -> Unit raise {
  print_exception(console, Trace::from_error(error, exc_type~), width~)
}
