// The command line interface of rich-cli (`rich_cli/__main__.py`): its
// click parameters, in declaration order.

///|
/// The rich-cli version this port follows (as printed by `--version`).
pub const VERSION : String = "1.8.0"

///|
/// Panel boxes accepted by `--panel` (`BOXES`).
let boxes : Array[String] = [
  "none", "ascii", "ascii2", "square", "rounded", "heavy", "double",
]

///|
/// The click type of a parameter.
priv enum ParamType {
  Flag
  Str
  Integer
  /// `click.IntRange(min=...)`.
  IntRange(Int)
  Choice(Array[String])
}

///|
/// A click option.
priv struct Param {
  /// Destination name.
  name : String
  /// Option strings, as declared (long first).
  opts : Array[String]
  type_ : ParamType
  metavar : String?
  /// Help text (console markup).
  help : String
}

///|
fn Param::takes_value(self : Param) -> Bool {
  !(self.type_ is Flag)
}

///|
/// The help text with click's extra information (`get_help_record`).
fn Param::help_record(self : Param) -> String {
  match self.type_ {
    IntRange(min) => "\{self.help}  [x>=\{min}]"
    _ => self.help
  }
}

///|
fn flag(name : String, opts : Array[String], help : String) -> Param {
  { name, opts, type_: Flag, metavar: None, help, }
}

///|
fn option(
  name : String,
  opts : Array[String],
  metavar : String,
  help : String,
  type_? : ParamType = Str,
) -> Param {
  { name, opts, type_, metavar: Some(metavar), help, }
}

///|
let box_text : String = {
  let sorted = boxes.copy()
  sorted.sort_by(py_compare)
  sorted.join(", ")
}

///|
/// All options, in declaration order (the help screen lists them so).
let params : Array[Param] = [
  flag(
    "print",
    ["--print", "-p"],
    "Print [u]console markup[/u]. [dim]See https://rich.readthedocs.io/en/latest/markup.html",
  ),
  flag("rule", ["--rule", "-u"], "Display a horizontal [u]rule[/u]."),
  flag("json", ["--json", "-J"], "Display as [u]JSON[/u]."),
  flag("markdown", ["--markdown", "-m"], "Display as [u]markdown[/u]."),
  flag("rst", ["--rst"], "Display [u]restructured text[/u]."),
  flag("csv", ["--csv"], "Display [u]CSV[/u] as a table."),
  flag("ipynb", ["--ipynb"], "Display [u]Jupyter notebook[/u]."),
  flag("syntax", ["--syntax"], "[u]Syntax[/u] highlighting."),
  flag("inspect", ["--inspect"], "[u]Inspect[/u] a python object."),
  option(
    "head",
    ["--head", "-h"],
    "LINES",
    "Display first [b]LINES[/] of the file (requires --syntax or --csv).",
    type_=IntRange(1),
  ),
  option(
    "tail",
    ["--tail", "-t"],
    "LINES",
    "Display last [b]LINES[/] of the file (requires --syntax or --csv).",
    type_=IntRange(1),
  ),
  flag("emoji", ["--emoji", "-j"], "Enable emoji code. [dim]e.g. :sparkle:"),
  flag("left", ["--left", "-l"], "Align to left."),
  flag("right", ["--right", "-r"], "Align to right."),
  flag("center", ["--center", "-c"], "Align to center."),
  flag("text_left", ["--text-left", "-L"], "Justify text to left."),
  flag("text_right", ["--text-right", "-R"], "Justify text to right."),
  flag("text_center", ["--text-center", "-C"], "Justify text to center."),
  flag(
    "text_full",
    ["--text-full", "-F"],
    "Justify text to both left and right edges.",
  ),
  flag("soft", ["--soft"], "Enable soft wrapping of text (requires --print)."),
  flag("expand", ["--expand", "-e"], "Expand to full width (requires --panel)."),
  option(
    "width",
    ["--width", "-w"],
    "SIZE",
    "Fit output to [b]SIZE[/] characters.",
    type_=Integer,
  ),
  option(
    "max_width",
    ["--max-width", "-W"],
    "SIZE",
    "Set maximum width to [b]SIZE[/] characters.",
    type_=Integer,
  ),
  option("style", ["--style", "-s"], "STYLE", "Set text style to [b]STYLE[/b]."),
  option(
    "rule_style",
    ["--rule-style"],
    "STYLE",
    "Set rule style to [b]STYLE[/b].",
  ),
  option(
    "rule_char",
    ["--rule-char"],
    "CHARACTER",
    "Use [b]CHARACTER[/b] to generate a line with --rule.",
  ),
  option(
    "padding",
    ["--padding", "-d"],
    "TOP,RIGHT,BOTTOM,LEFT",
    "Padding around output. [dim]1, 2 or 4 comma separated integers, e.g. 2,4",
  ),
  option(
    "panel",
    ["--panel", "-a"],
    "BOX",
    "Set panel type to [b]BOX[/b]. [dim]\{box_text}",
    type_=Choice(boxes),
  ),
  option(
    "panel_style",
    ["--panel-style", "-S"],
    "STYLE",
    "Set the panel style to [b]STYLE[/b] (requires --panel).",
  ),
  option(
    "theme",
    ["--theme"],
    "THEME",
    "Set syntax theme to [b]THEME[/b]. [dim]See https://pygments.org/styles/",
  ),
  flag(
    "line_numbers",
    ["--line-numbers", "-n"],
    "Enable line number in syntax.",
  ),
  flag(
    "guides",
    ["--guides", "-g"],
    "Enable indentation guides in syntax highlighting",
  ),
  option(
    "lexer",
    ["--lexer", "-x"],
    "LEXER",
    "Use [b]LEXER[/b] for syntax highlighting. [dim]See https://pygments.org/docs/lexers/",
  ),
  flag("hyperlinks", ["--hyperlinks", "-y"], "Render hyperlinks in markdown."),
  flag("no_wrap", ["--no-wrap"], "Don't word wrap syntax highlighted files."),
  option("title", ["--title"], "TEXT", "Set panel title to [b]TEXT[/]."),
  option("caption", ["--caption"], "TEXT", "Set panel caption to [b]TEXT[/]."),
  flag(
    "force_terminal",
    ["--force-terminal"],
    "Force terminal output when not writing to a terminal.",
  ),
  option(
    "export_html",
    ["--export-html", "-o"],
    "PATH",
    "Write HTML to [b]PATH[/b].",
  ),
  option("export_svg", ["--export-svg"], "PATH", "Write SVG to [b]PATH[/b]."),
  flag("pager", ["--pager"], "Display in an interactive pager."),
  flag("version", ["--version", "-v"], "Print version and exit."),
  flag("help", ["--help"], "Show this message and exit."),
]

///|
/// Parsed command line options (the parameters of rich-cli's `main`).
pub(all) struct Options {
  /// `<PATH or TEXT or '-'>`: a path, console markup / rule title, or `-`
  /// for standard input.
  mut resource : String
  mut print : Bool
  mut rule : Bool
  mut json : Bool
  mut markdown : Bool
  mut rst : Bool
  mut csv : Bool
  mut ipynb : Bool
  mut syntax : Bool
  mut inspect : Bool
  mut head : Int?
  mut tail : Int?
  mut emoji : Bool
  mut left : Bool
  mut right : Bool
  mut center : Bool
  mut text_left : Bool
  mut text_right : Bool
  mut text_center : Bool
  mut text_full : Bool
  mut soft : Bool
  mut expand : Bool
  mut width : Int
  mut max_width : Int
  mut style : String
  mut rule_style : String
  mut rule_char : String
  mut padding : String
  mut panel : String
  mut panel_style : String
  mut theme : String
  mut line_numbers : Bool
  mut guides : Bool
  mut lexer : String?
  mut hyperlinks : Bool
  mut no_wrap : Bool
  mut title : String
  mut caption : String
  mut force_terminal : Bool
  mut export_html : String
  mut export_svg : String
  mut pager : Bool
  mut version : Bool
} derive(Debug)

///|
/// The defaults of every option. `theme` defaults to `$RICH_THEME`, else
/// `ansi_dark`.
pub fn Options::default(theme? : String = "ansi_dark") -> Options {
  {
    resource: "",
    print: false,
    rule: false,
    json: false,
    markdown: false,
    rst: false,
    csv: false,
    ipynb: false,
    syntax: false,
    inspect: false,
    head: None,
    tail: None,
    emoji: false,
    left: false,
    right: false,
    center: false,
    text_left: false,
    text_right: false,
    text_center: false,
    text_full: false,
    soft: false,
    expand: false,
    width: -1,
    max_width: -1,
    style: "",
    rule_style: "bright_green",
    rule_char: "─",
    padding: "",
    panel: "none",
    panel_style: "",
    theme,
    line_numbers: false,
    guides: false,
    lexer: None,
    hyperlinks: false,
    no_wrap: false,
    title: "",
    caption: "",
    force_terminal: false,
    export_html: "",
    export_svg: "",
    pager: false,
    version: false,
  }
}

///|
/// Set a flag by destination name.
fn Options::set_flag(self : Options, name : String) -> Unit {
  match name {
    "print" => self.print = true
    "rule" => self.rule = true
    "json" => self.json = true
    "markdown" => self.markdown = true
    "rst" => self.rst = true
    "csv" => self.csv = true
    "ipynb" => self.ipynb = true
    "syntax" => self.syntax = true
    "inspect" => self.inspect = true
    "emoji" => self.emoji = true
    "left" => self.left = true
    "right" => self.right = true
    "center" => self.center = true
    "text_left" => self.text_left = true
    "text_right" => self.text_right = true
    "text_center" => self.text_center = true
    "text_full" => self.text_full = true
    "soft" => self.soft = true
    "expand" => self.expand = true
    "line_numbers" => self.line_numbers = true
    "guides" => self.guides = true
    "hyperlinks" => self.hyperlinks = true
    "no_wrap" => self.no_wrap = true
    "force_terminal" => self.force_terminal = true
    "pager" => self.pager = true
    "version" => self.version = true
    _ => ()
  }
}

///|
/// Set a string option by destination name.
fn Options::set_string(self : Options, name : String, value : String) -> Unit {
  match name {
    "style" => self.style = value
    "rule_style" => self.rule_style = value
    "rule_char" => self.rule_char = value
    "padding" => self.padding = value
    "panel" => self.panel = value
    "panel_style" => self.panel_style = value
    "theme" => self.theme = value
    "lexer" => self.lexer = Some(value)
    "title" => self.title = value
    "caption" => self.caption = value
    "export_html" => self.export_html = value
    "export_svg" => self.export_svg = value
    _ => ()
  }
}

///|
/// Set an integer option by destination name.
fn Options::set_int(self : Options, name : String, value : Int) -> Unit {
  match name {
    "head" => self.head = Some(value)
    "tail" => self.tail = Some(value)
    "width" => self.width = value
    "max_width" => self.max_width = value
    _ => ()
  }
}
