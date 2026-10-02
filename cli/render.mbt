// Port of rich-cli's `main` (rich_cli/__main__.py) as a pure function from
// the command line, the input text and the terminal to the output.

///|
/// What the command reads (rich-cli's `read_resource` / `sys.stdin.read()`).
pub(all) enum Input {
  /// Nothing to read.
  NoInput
  /// Standard input (`-`).
  Stdin
  /// A file.
  File(String)
} derive(Debug, Eq)

///|
/// The result of running the command.
pub(all) struct Output {
  /// Text written to standard output.
  stdout : String
  /// Text written to standard error.
  stderr : String
  /// The exit status (rich-cli exits with -1, i.e. 255, on errors and 2 on
  /// usage errors).
  exit_code : Int
  /// Files to write (`--export-html`, `--export-svg`), in order. Write them
  /// after printing `stdout`.
  exports : Array[Export]
  /// With `--pager`: the rendered lines to show in a pager (`stdout` is
  /// then empty).
  pager : String?
} derive(Debug)

///|
/// An exported file.
pub(all) struct Export {
  /// The path given on the command line.
  path : String
  /// The HTML or SVG document.
  contents : String
  /// `"HTML"` or `"SVG"` (for the error message if saving fails: `failed to
  /// save HTML`).
  format : String
} derive(Debug, Eq)

///|
/// The resource format (`AUTO`, `SYNTAX`, ...).
priv enum Format {
  Syntax
  Print
  Markdown
  Rst
  Json
  Rule
  Inspect
  Csv
  Ipynb
}

///|
/// Python's `os.path.splitext(path)[1]`.
fn splitext_ext(path : String) -> String {
  let base = match path.rev_find("/") {
    Some(i) => path.view(start_offset=i + 1).to_owned()
    None => path
  }
  // leading dots of the base name do not start an extension
  let mut start = 0
  while start < base.length() && base[start] == '.' {
    start += 1
  }
  match base.rev_find(".") {
    Some(i) if i >= start => base.view(start_offset=i).to_owned()
    _ => ""
  }
}

///|
fn is_url(path : String) -> Bool {
  path.has_prefix("http://") || path.has_prefix("https://")
}

///|
/// The path part of a URL (`urlparse(url).path`).
fn url_path(url : String) -> String {
  let rest = match url.find("://") {
    Some(i) => url.view(start_offset=i + 3).to_owned()
    None => url
  }
  let path = match rest.find("/") {
    Some(i) => rest.view(start_offset=i).to_owned()
    None => ""
  }
  let mut end = path.length()
  for sep in ["?", "#"] {
    if path.find(sep) is Some(i) && i < end {
      end = i
    }
  }
  path.view(end_offset=end).to_owned()
}

///|
fn Options::format(self : Options) -> Format {
  let format = if self.print {
    Some(Print)
  } else if self.syntax {
    Some(Syntax)
  } else if self.json {
    Some(Json)
  } else if self.markdown {
    Some(Markdown)
  } else if self.rule {
    Some(Rule)
  } else if self.inspect {
    Some(Inspect)
  } else if self.csv {
    Some(Csv)
  } else if self.rst {
    Some(Rst)
  } else if self.ipynb {
    Some(Ipynb)
  } else {
    None
  }
  match format {
    Some(f) => f
    None if self.resource.contains(".") => {
      let path = if is_url(self.resource) {
        url_path(self.resource)
      } else {
        self.resource
      }
      let ext = splitext_ext(path).to_lower()
      match ext {
        ".md" => Markdown
        ".json" => Json
        ".csv" | ".tsv" => Csv
        ".rst" => Rst
        ".ipynb" => Ipynb
        _ => Syntax
      }
    }
    None => Syntax
  }
}

///|
/// What has to be read before rendering with these options.
pub fn Options::input(self : Options) -> Input {
  if self.version {
    return NoInput
  }
  let resource = self.resource
  match self.format() {
    Print | Rule => if resource == "-" { Stdin } else { NoInput }
    Inspect => NoInput
    _ =>
      if resource == "" || is_url(resource) {
        NoInput
      } else if resource == "-" {
        Stdin
      } else {
        File(resource)
      }
  }
}

///|
/// `sys.exit(code)`.
priv suberror Exit {
  Exit(Int)
}

///|
/// The consoles and outputs of one run.
priv struct Context {
  options : Options
  out : @rich.StringIO
  environ : Map[String, String]?
  error_console : @rich.Console
  exports : Array[Export]
  mut pager : String?
}

///|
/// `on_error`: print a message (and the error) in bold red to standard
/// error and exit with -1.
fn[T] Context::on_error(
  self : Context,
  message : String,
  error? : String,
) -> T raise Exit {
  write_error(self.error_console, message, error)
  raise Exit(-1)
}

///|
fn write_error(
  console : @rich.Console,
  message : String,
  error : String?,
) -> Unit {
  let text = match error {
    Some(error) => {
      let text = @rich.Text::new(text=message)
      text.stylize("bold red")
      let detail = @rich.Text::new(text=error)
      @rich.ReprHighlighter::new().highlight(detail) catch {
        _ => ()
      }
      text.append_text(@rich.Text::new(text=": ")).append_text(detail)
    }
    None => @rich.Text::new(text=message, style="bold red")
  }
  console.print(text) catch {
    _ => ()
  }
}

///|
fn make_error_console(
  file : @rich.StringIO,
  environ : Map[String, String]?,
) -> @rich.Console {
  @rich.Console::new(stderr=true, file~, legacy_windows=false, environ?) catch {
    _ => abort("console")
  }
}

///|
/// Render the error message rich-cli prints for `message` (and the error
/// detail) as it would appear on standard error (e.g. when writing an
/// exported file fails).
pub fn error_text(
  message : String,
  error? : String,
  environ? : Map[String, String],
  isatty? : Bool = false,
) -> String {
  let file = @rich.StringIO::new(isatty~)
  write_error(make_error_console(file, environ), message, error)
  file.getvalue()
}

///|
/// Run a parsed command. `input` is the text read for `options.input()`:
/// `Ok(text)` or `Err(message)` when reading failed (e.g. `[Errno 2] No
/// such file or directory: 'x.py'`). `environ` replaces the process
/// environment (`COLUMNS`, `COLORTERM`, `NO_COLOR`, ...) for hermetic runs.
pub fn execute(
  command : Command,
  input? : Result[String, String],
  environ? : Map[String, String],
  stdout_isatty? : Bool = false,
  stderr_isatty? : Bool = false,
) -> Output {
  let out = @rich.StringIO::new(isatty=stdout_isatty)
  let err = @rich.StringIO::new(isatty=stderr_isatty)
  fn output(code : Int, exports : Array[Export], pager : String?) {
    {
      stdout: out.getvalue(),
      stderr: err.getvalue(),
      exit_code: code,
      exports,
      pager,
    }
  }

  match command {
    UsageError(message, usage~) => {
      if usage {
        err.write(
          "Usage: rich [OPTIONS] <PATH or TEXT or '-'>\nTry 'rich --help' for help.\n\n",
        ) catch {
          _ => ()
        }
      }
      err.write("Error: \{message}\n") catch {
        _ => ()
      }
      output(2, [], None)
    }
    Help => {
      render_help(out, environ) catch {
        e => err.write("\{e}\n") catch { _ => () }
      }
      output(0, [], None)
    }
    Run(options) => {
      let ctx : Context = {
        options,
        out,
        environ,
        error_console: make_error_console(err, environ),
        exports: [],
        pager: None,
      }
      let code = ctx.main(input.map(r => r.map(normalize_newlines))) catch {
        Exit(code) => (code % 256 + 256) % 256
      }
      output(code, ctx.exports, ctx.pager)
    }
  }
}

///|
/// Parse the arguments and run, reading files from `files` (path ->
/// contents) and standard input from `stdin`.
pub fn run(
  args : ArrayView[String],
  files? : Map[String, String] = Map([]),
  stdin? : String = "",
  environ? : Map[String, String],
  stdout_isatty? : Bool = false,
  stderr_isatty? : Bool = false,
) -> Output {
  let command = parse_args(args, environ?)
  let input = match command {
    Run(options) =>
      match options.input() {
        NoInput => None
        Stdin => Some(Ok(stdin))
        File(path) =>
          match files.get(path) {
            Some(text) => Some(Ok(text))
            None =>
              Some(
                Err(
                  "[Errno 2] No such file or directory: \{@rich.py_repr(path)}",
                ),
              )
          }
      }
    _ => None
  }
  execute(command, input?, environ?, stdout_isatty~, stderr_isatty~)
}

///|
/// Python's universal newlines: `\r\n` and `\r` become `\n`.
fn normalize_newlines(text : String) -> String {
  if !text.contains("\r") {
    return text
  }
  text.replace_all(old="\r\n", new="\n").replace_all(old="\r", new="\n")
}

///|
/// Read the resource (`read_resource`): the text and the lexer name.
fn Context::read_resource(
  self : Context,
  path : String,
  lexer : String?,
  input : Result[String, String]?,
) -> (String, String?) raise Exit {
  if path == "" {
    self.on_error("missing path or URL")
  }
  if is_url(path) {
    self.on_error(
      "unable to read \{@rich.escape(path)}",
      error="fetching URLs is not supported",
    )
  }
  let text = match input {
    Some(Ok(text)) => text
    Some(Err(message)) => {
      self.on_error("unable to read \{@rich.escape(path)}", error=message)
      ""
    }
    None => ""
  }
  if path == "-" {
    return (text, None)
  }
  let mut lexer = match lexer {
    Some(l) if l != "" => Some(l)
    _ => None
  }
  if lexer is None {
    let ext = match path.rev_find(".") {
      Some(i) => path.view(start_offset=i + 1).to_owned().to_lower()
      None => ""
    }
    lexer = match ext {
      "html" => Some("html")
      "py" => Some("python")
      "md" => Some("markdown")
      "js" => Some("javascript")
      "xml" => Some("xml")
      "json" => Some("json")
      "toml" => Some("toml")
      _ => None
    }
  }
  if lexer is None {
    lexer = Some(@lexers.guess_lexer_for_filename(path, text).info.name) catch {
      _ => return (text, Some("text"))
    }
  }
  (text, lexer)
}

///|
/// Force a renderable to a given width (`ForceWidth`).
priv struct ForceWidth {
  renderable : &@rich.Renderable
  width : Int
}

///|
impl @rich.Renderable for ForceWidth with fn rich_console(
  self,
  console,
  options,
) {
  let child_options = options.update_width(self.width)
  console.render(self.renderable, options=child_options).map(s => Seg(s))
}

///|
impl @rich.Renderable for ForceWidth with fn rich_measure(
  self,
  _console,
  _options,
) {
  Some(@rich.Measurement::new(self.width, self.width))
}

///|
/// `_line_range`.
fn Context::line_range(
  self : Context,
  num_lines : Int,
) -> (Int?, Int?)? raise Exit {
  let { head, tail, .. } = self.options
  if head is Some(_) && tail is Some(_) {
    self.on_error("cannot specify both head and tail")
  }
  match (head, tail) {
    (Some(head), _) => Some((Some(1), Some(head)))
    (_, Some(tail)) => Some((Some(num_lines - tail + 2), Some(num_lines + 1)))
    _ => None
  }
}

///|
/// Python's `len(text.splitlines())`.
fn count_lines(text : String) -> Int {
  let mut n = 0
  let mut at_line_start = true
  let len = text.length()
  let mut i = 0
  while i < len {
    let c = text[i]
    at_line_start = false
    if c
      is ('\n'
      | '\r'
      | '\u{0b}'
      | '\u{0c}'
      | '\u{1c}'
      | '\u{1d}'
      | '\u{1e}'
      | '\u{85}'
      | '\u{2028}'
      | '\u{2029}') {
      if c == '\r' && i + 1 < len && text[i + 1] == '\n' {
        i += 1
      }
      n += 1
      at_line_start = true
    }
    i += 1
  }
  if !at_line_start {
    n += 1
  }
  n
}

///|
/// rich-cli's `CodeBlock` (`rich_cli.markdown`): syntax highlighting with
/// word wrap, indented by four cells.
fn code_block(
  code : String,
  lexer_name : String,
  theme : String,
) -> &@rich.Renderable raise {
  let lexer_name = if lexer_name == "" { "default" } else { lexer_name }
  let syntax = @syntax.Syntax::new(code, lexer_name, theme~, word_wrap=true)
  @rich.Padding::new(syntax, pad=[0, 4])
}

///|
/// A markdown renderer with rich-cli's code blocks. rich-cli replaces
/// `Markdown.elements["code_block"]` only, which with Rich 15's markdown-it
/// tokens applies to indented code blocks; fenced code keeps Rich's element.
fn make_markdown(
  markup : String,
  theme : String,
  hyperlinks : Bool,
) -> @markdown.Markdown {
  @markdown.Markdown::new(markup, code_theme=theme, hyperlinks~, code_renderers={
    "code_block": code_block,
  })
}

///|
/// The body of rich-cli's `main` (after argument parsing); returns the exit
/// code.
fn Context::main(
  self : Context,
  input : Result[String, String]?,
) -> Int raise Exit {
  let opts = self.options
  if opts.version {
    self.out.write("\{VERSION}\n") catch {
      _ => ()
    }
    return 0
  }
  let console = @rich.Console::new(
    file=self.out,
    emoji=opts.emoji,
    record=opts.export_html != "" || opts.export_svg != "",
    force_terminal?=if opts.force_terminal { Some(true) } else { None },
    legacy_windows=false,
    environ?=self.environ,
  ) catch {
    e => self.on_error("failed to create console", error=e.to_string())
  }
  let mut expand = opts.expand
  if opts.width > 0 {
    expand = true
  }
  let print_padding : Array[Int] = []
  if opts.padding != "" {
    for pad in opts.padding.split(",") {
      match py_int(pad.to_owned()) {
        Some(n) => print_padding.push(n)
        None =>
          self.on_error(
            "padding should be 1, 2 or 4 integers separated by commas",
          )
      }
    }
    if !(print_padding.length() is (1 | 2 | 4)) {
      self.on_error("padding should be 1, 2 or 4 integers separated by commas")
    }
  }
  let resource = opts.resource
  let format = opts.format()
  let mut renderable : &@rich.Renderable = ""
  match format {
    Print | Rule => {
      let justify : @rich.JustifyMethod = if opts.text_left {
        Left
      } else if opts.text_right {
        Right
      } else if opts.text_center {
        Center
      } else if opts.text_full {
        Full
      } else {
        Default
      }
      let source = if resource == "-" {
        match input {
          Some(Ok(text)) => text
          _ => ""
        }
      } else {
        resource
      }
      let text = @rich.Text::from_markup(source, justify~, emoji=opts.emoji) catch {
        e =>
          self.on_error("unable to parse console markup", error=e.to_string())
      }
      text.no_wrap = Some(opts.no_wrap)
      renderable = text
      if opts.rule {
        let rule_style = @rich.Style::parse(opts.rule_style) catch {
          e => self.on_error("unable to parse rule style", error=e.to_string())
        }
        let align : @rich.AlignMethod = match justify {
          Left => Left
          Right => Right
          _ => Center
        }
        renderable = @rich.Rule::new(
          title=resource,
          style=rule_style,
          characters=if opts.rule_char == "" { "─" } else { opts.rule_char },
          align~,
        ) catch {
          e => self.on_error("unable to create rule", error=e.to_string())
        }
      }
    }
    Json => {
      let (data, _) = self.read_resource(resource, opts.lexer, input)
      renderable = @rich.JSON::new(data) catch {
        e => self.on_error("unable to read json", error=json_error(e, data))
      }
    }
    Markdown => {
      let (data, _) = self.read_resource(resource, opts.lexer, input)
      renderable = make_markdown(data, opts.theme, opts.hyperlinks)
    }
    Rst => {
      // rich-rst is not ported: show the reStructuredText source with
      // syntax highlighting instead
      let (data, _) = self.read_resource(resource, opts.lexer, input)
      renderable = self.make_syntax(data, Some("rst"))
    }
    Inspect =>
      self.on_error(
        "unable to eval \{@rich.py_repr(resource)}",
        error="--inspect (Python objects) is not supported",
      )
    Csv => renderable = self.render_csv(resource, input)
    Ipynb => renderable = self.render_ipynb(resource, input)
    Syntax => {
      if resource == "" {
        console.print(
          "Usage: [b]rich [OPTIONS][/b] [b cyan]<PATH,TEXT,URL, or '-'>[/]",
        ) catch {
          _ => ()
        }
        console.print("See [bold green]rich --help[/] for options") catch {
          _ => ()
        }
        console.line() catch {
          _ => ()
        }
        raise Exit(0)
      }
      let (code, lexer) = if resource == "-" {
        let code = match input {
          Some(Ok(text)) => text
          _ => ""
        }
        (code, opts.lexer)
      } else {
        self.read_resource(resource, opts.lexer, input)
      }
      renderable = self.make_syntax(code, lexer)
    }
  }
  if print_padding.length() > 0 {
    renderable = @rich.Padding::new(renderable, pad=print_padding, expand~) catch {
      e => self.on_error("unable to pad", error=e.to_string())
    }
  }
  if opts.panel != "none" {
    let border_style = @rich.Style::parse(opts.panel_style) catch {
      e => self.on_error("unable to parse panel style", error=e.to_string())
    }
    let box_ = match opts.panel {
      "ascii" => @rich.box_ascii
      "ascii2" => @rich.box_ascii2
      "square" => @rich.box_square
      "heavy" => @rich.box_heavy
      "double" => @rich.box_double
      _ => @rich.box_rounded
    }
    let title : &@rich.IntoText? = if opts.title != "" {
      Some(opts.title)
    } else {
      None
    }
    let subtitle : &@rich.IntoText? = if opts.caption != "" {
      Some(opts.caption)
    } else {
      None
    }
    renderable = @panel.Panel::new(
      renderable,
      box_~,
      expand~,
      title?,
      subtitle?,
      border_style~,
    )
  }
  if opts.style != "" {
    let text_style = @rich.Style::parse(opts.style) catch {
      e => self.on_error("unable to parse style", error=e.to_string())
    }
    renderable = @rich.Styled::new(renderable, text_style)
  }
  if opts.width > 0 && !opts.pager {
    renderable = ForceWidth::{ renderable, width: opts.width, }
  }
  let justify : @rich.JustifyMethod = if opts.left {
    Left
  } else if opts.right {
    Right
  } else if opts.center {
    Center
  } else {
    Default
  }
  if opts.pager {
    let align : @rich.AlignMethod? = match justify {
      Left => Some(Left)
      Right => Some(Right)
      Center => Some(Center)
      _ => None
    }
    if align is Some(align) {
      renderable = @rich.Align::new(renderable, align)
    }
    let width = if opts.width < 0 { console.width() } else { opts.width }
    let render_options = console.options().update(width=width - 1)
    let text = console.capture(() => {
      let lines = console.render_lines(
        renderable,
        options=render_options,
        new_lines=true,
      )
      console.print(PagerLines(lines), width~)
    }) catch {
      e => self.on_error("failed to print resource", error=e.to_string())
    }
    self.pager = Some(text)
  } else {
    let width = if opts.max_width <= 0 { None } else { Some(opts.max_width) }
    console.print(renderable, width?, soft_wrap=opts.soft, justify~) catch {
      e => self.on_error("failed to print resource", error=e.to_string())
    }
  }
  if opts.export_html != "" {
    self.exports.push({
      path: opts.export_html,
      contents: console.export_html(clear=false),
      format: "HTML",
    })
  }
  if opts.export_svg != "" {
    self.exports.push({
      path: opts.export_svg,
      contents: console.export_svg(clear=false),
      format: "SVG",
    })
  }
  0
}

///|
/// Lines of segments (`PagerRenderable`).
priv struct PagerLines(Array[Array[@rich.Segment]])

///|
impl @rich.Renderable for PagerLines with fn rich_console(
  self,
  _console,
  _options,
) {
  let out : Array[@rich.RenderItem] = []
  for line in self.0 {
    for segment in line {
      out.push(Seg(segment))
    }
  }
  out
}

///|
/// The `Syntax` of the syntax branch.
fn Context::make_syntax(
  self : Context,
  code : String,
  lexer : String?,
) -> &@rich.Renderable raise Exit {
  let opts = self.options
  let line_range = self.line_range(count_lines(code))
  @syntax.Syntax::new(
    code,
    lexer.unwrap_or(""),
    theme=opts.theme,
    line_numbers=opts.line_numbers,
    indent_guides=opts.guides,
    word_wrap=!opts.no_wrap,
    line_range?,
  ) catch {
    e => self.on_error("unable to read file", error=e.to_string())
  }
}

///|
/// Python's `str(json.JSONDecodeError)` from the position in the message
/// of `@rich.JSON::new` ("Expecting value: char 3").
fn json_error(e : Error, data : String) -> String {
  let message = match e {
    @rich.RichError::ValueError(m) => m
    _ => return e.to_string()
  }
  guard message.rev_find(": char ") is Some(i) else { return message }
  let msg = message.view(end_offset=i).to_owned()
  guard py_int(message.view(start_offset=i + 7).to_owned()) is Some(pos) else {
    return message
  }
  // `pos` is a UTF-16 offset; Python counts code points
  let mut lineno = 1
  let mut last_newline = -1
  let mut chars = 0
  for j in 0..<@cmp.minimum(pos, data.length()) {
    let c = data[j]
    if c >= 0xDC00 && c <= 0xDFFF {
      continue
    }
    if c == '\n' {
      lineno += 1
      last_newline = chars
    }
    chars += 1
  }
  "\{msg}: line \{lineno} column \{chars - last_newline} (char \{chars})"
}
