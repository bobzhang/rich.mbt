// Port of `Console.export_svg` (rich/console.py) and the SVG template
// from rich/_export_format.py.

///|
/// The default SVG template.
pub let console_svg_format : String =
  #|<svg class="rich-terminal" viewBox="0 0 {width} {height}" xmlns="http://www.w3.org/2000/svg">
  #|    <!-- Generated with Rich https://www.textualize.io -->
  #|    <style>
  #|
  #|    @font-face {{
  #|        font-family: "Fira Code";
  #|        src: local("FiraCode-Regular"),
  #|                url("https://cdnjs.cloudflare.com/ajax/libs/firacode/6.2.0/woff2/FiraCode-Regular.woff2") format("woff2"),
  #|                url("https://cdnjs.cloudflare.com/ajax/libs/firacode/6.2.0/woff/FiraCode-Regular.woff") format("woff");
  #|        font-style: normal;
  #|        font-weight: 400;
  #|    }}
  #|    @font-face {{
  #|        font-family: "Fira Code";
  #|        src: local("FiraCode-Bold"),
  #|                url("https://cdnjs.cloudflare.com/ajax/libs/firacode/6.2.0/woff2/FiraCode-Bold.woff2") format("woff2"),
  #|                url("https://cdnjs.cloudflare.com/ajax/libs/firacode/6.2.0/woff/FiraCode-Bold.woff") format("woff");
  #|        font-style: bold;
  #|        font-weight: 700;
  #|    }}
  #|
  #|    .{unique_id}-matrix {{
  #|        font-family: Fira Code, monospace;
  #|        font-size: {char_height}px;
  #|        line-height: {line_height}px;
  #|        font-variant-east-asian: full-width;
  #|    }}
  #|
  #|    .{unique_id}-title {{
  #|        font-size: 18px;
  #|        font-weight: bold;
  #|        font-family: arial;
  #|    }}
  #|
  #|    {styles}
  #|    </style>
  #|
  #|    <defs>
  #|    <clipPath id="{unique_id}-clip-terminal">
  #|      <rect x="0" y="0" width="{terminal_width}" height="{terminal_height}" />
  #|    </clipPath>
  #|    {lines}
  #|    </defs>
  #|
  #|    {chrome}
  #|    <g transform="translate({terminal_x}, {terminal_y})" clip-path="url(#{unique_id}-clip-terminal)">
  #|    {backgrounds}
  #|    <g class="{unique_id}-matrix">
  #|    {matrix}
  #|    </g>
  #|    </g>
  #|</svg>
  #|

///|
/// zlib's Adler-32 checksum.
pub fn adler32(data : Bytes) -> UInt {
  let mod_adler = 65521U
  let mut a = 1U
  let mut b = 0U
  for byte in data {
    a = (a + byte.to_uint()) % mod_adler
    b = (b + a) % mod_adler
  }
  (b << 16) | a
}

///|
/// A value for an SVG attribute: ints are printed as is, floats with
/// Python's `format(value, "g")`.
priv enum SvgValue {
  I(Int)
  F(Double)
  S(String)
}

///|
fn SvgValue::stringify(self : SvgValue) -> String {
  match self {
    I(i) => i.to_string()
    F(f) => py_format_g(f)
    S(s) => s
  }
}

///|
fn make_tag(
  name : String,
  attribs : Array[(String, SvgValue)],
  content? : String,
) -> String {
  let tag_attribs = attribs
    .map(kv => {
      let mut k = kv.0
      while k.strip_prefix("_") is Some(rest) {
        k = rest.to_owned()
      }
      "\{k.replace_all(old="_", new="-")}=\"\{kv.1.stringify()}\""
    })
    .join(" ")
  match content {
    Some(c) if c != "" => "<\{name} \{tag_attribs}>\{c}</\{name}>"
    _ => "<\{name} \{tag_attribs}/>"
  }
}

///|
fn svg_escape_text(text : String) -> String {
  html_escape(text).replace_all(old=" ", new="&#160;")
}

///|
/// Generate an SVG from the console contents (requires `record=true`).
pub fn Console::export_svg(
  self : Console,
  title? : String = "Rich",
  theme? : @color.TerminalTheme,
  clear? : Bool = true,
  code_format? : String = console_svg_format,
  font_aspect_ratio? : Double = 0.61,
  unique_id? : String,
) -> String {
  let theme = theme.unwrap_or(@color.svg_export_theme)
  let style_cache : Map[Style, String] = Map([])
  fn get_svg_style(style : Style) -> String {
    match style_cache.get(style) {
      Some(css) => return css
      None => ()
    }
    let css_rules = []
    let mut color = match style.color() {
      Some(c) if !c.is_default() => c.get_truecolor(theme~)
      _ => theme.foreground_color
    }
    let mut bgcolor = match style.bgcolor() {
      Some(c) if !c.is_default() => c.get_truecolor(theme~)
      _ => theme.background_color
    }
    if style.reverse() is Some(true) {
      let tmp = color
      color = bgcolor
      bgcolor = tmp
    }
    if style.dim() is Some(true) {
      color = @color.blend_rgb(color, bgcolor, cross_fade=0.4)
    }
    css_rules.push("fill: \{color.hex()}")
    if style.bold() is Some(true) {
      css_rules.push("font-weight: bold")
    }
    if style.italic() is Some(true) {
      css_rules.push("font-style: italic;")
    }
    if style.underline() is Some(true) {
      css_rules.push("text-decoration: underline;")
    }
    if style.strike() is Some(true) {
      css_rules.push("text-decoration: line-through;")
    }
    let css = css_rules.join(";")
    style_cache[style] = css
    css
  }

  let width = self.width()
  let char_height = 20
  let char_width = char_height.to_double() * font_aspect_ratio
  let line_height = char_height.to_double() * 1.22
  let margin_top = 1
  let margin_right = 1
  let margin_bottom = 1
  let margin_left = 1
  let padding_top = 40
  let padding_right = 8
  let padding_bottom = 8
  let padding_left = 8
  let padding_width = padding_left + padding_right
  let padding_height = padding_top + padding_bottom
  let margin_width = margin_left + margin_right
  let margin_height = margin_top + margin_bottom
  let text_backgrounds = []
  let text_group = []
  let classes : Map[String, Int] = Map([])
  let mut style_no = 1
  let segments = Segment::filter_control(self.record_buffer)
  if clear {
    self.record_buffer.clear()
  }
  let unique_id = match unique_id {
    Some(u) => u
    None => {
      let reprs = segments.map(s => s.repr()).join("")
      let data = @utf8.encode(reprs + title)
      "terminal-\{adler32(data)}"
    }
  }
  let mut y = 0
  for line_index, line in Segment::split_and_crop_lines(segments, width) {
    y = line_index
    let mut x = 0
    for segment in line {
      let style = match segment.style {
        Some(s) => s
        None => Style::new()
      }
      let text = segment.text
      let rules = get_svg_style(style)
      if classes.get(rules) is None {
        classes[rules] = style_no
        style_no += 1
      }
      let class_name = "r\{classes[rules]}"
      let (has_background, background) = if style.reverse() is Some(true) {
        (
          true,
          match style.color() {
            None => theme.foreground_color.hex()
            Some(c) => c.get_truecolor(theme~).hex()
          },
        )
      } else {
        let bgcolor = style.bgcolor()
        (
          bgcolor is Some(c) && !c.is_default(),
          match bgcolor {
            None => theme.background_color.hex()
            Some(c) => c.get_truecolor(theme~, foreground=false).hex()
          },
        )
      }
      let text_length = @cells.cell_len(text)
      if has_background {
        text_backgrounds.push(
          make_tag("rect", [
            ("fill", S(background)),
            ("x", F(x.to_double() * char_width)),
            ("y", F(y.to_double() * line_height + 1.5)),
            ("width", F(char_width * text_length.to_double())),
            ("height", F(line_height + 0.25)),
            ("shape_rendering", S("crispEdges")),
          ]),
        )
      }
      let code_points = text.char_length()
      if text != " ".repeat(code_points) {
        text_group.push(
          make_tag(
            "text",
            [
              ("_class", S("\{unique_id}-\{class_name}")),
              ("x", F(x.to_double() * char_width)),
              ("y", F(y.to_double() * line_height + char_height.to_double())),
              ("textLength", F(char_width * code_points.to_double())),
              ("clip_path", S("url(#\{unique_id}-line-\{y})")),
            ],
            content=svg_escape_text(text),
          ),
        )
      }
      x += @cells.cell_len(text)
    }
  }
  let lines = []
  for line_no in 0..<y {
    let offset = line_no.to_double() * line_height + 1.5
    let rect = make_tag("rect", [
      ("x", I(0)),
      ("y", F(offset)),
      ("width", F(char_width * width.to_double())),
      ("height", F(line_height + 0.25)),
    ])
    lines.push(
      "<clipPath id=\"\{unique_id}-line-\{line_no}\">\n    \{rect}\n            </clipPath>",
    )
  }
  let styles = []
  for css, rule_no in classes {
    styles.push(".\{unique_id}-r\{rule_no} { \{css} }")
  }
  let backgrounds = text_backgrounds.join("")
  let matrix = text_group.join("")
  let terminal_width = (width.to_double() * char_width +
    padding_width.to_double())
    .ceil()
    .to_int()
  let terminal_height = (y + 1).to_double() * line_height +
    padding_height.to_double()
  let mut chrome = make_tag("rect", [
    ("fill", S(theme.background_color.hex())),
    ("stroke", S("rgba(255,255,255,0.35)")),
    ("stroke_width", S("1")),
    ("x", I(margin_left)),
    ("y", I(margin_top)),
    ("width", I(terminal_width)),
    ("height", F(terminal_height)),
    ("rx", I(8)),
  ])
  let title_color = theme.foreground_color.hex()
  if title != "" {
    chrome = chrome +
      make_tag(
        "text",
        [
          ("_class", S("\{unique_id}-title")),
          ("fill", S(title_color)),
          ("text_anchor", S("middle")),
          ("x", I(terminal_width / 2)),
          ("y", I(margin_top + char_height + 6)),
        ],
        content=svg_escape_text(title),
      )
  }
  chrome = chrome +
    (
      #|
      #|            <g transform="translate(26,22)">
      #|            <circle cx="0" cy="0" r="7" fill="#ff5f57"/>
      #|            <circle cx="22" cy="0" r="7" fill="#febc2e"/>
      #|            <circle cx="44" cy="0" r="7" fill="#28c840"/>
      #|            </g>
      #|        
    )
  py_format(code_format, {
    "unique_id": unique_id,
    "char_width": py_float_repr(char_width),
    "char_height": char_height.to_string(),
    "line_height": py_float_repr(line_height),
    "terminal_width": py_float_repr(char_width * width.to_double() - 1.0),
    "terminal_height": py_float_repr((y + 1).to_double() * line_height - 1.0),
    "width": (terminal_width + margin_width).to_string(),
    "height": py_float_repr(terminal_height + margin_height.to_double()),
    "terminal_x": (margin_left + padding_left).to_string(),
    "terminal_y": (margin_top + padding_top).to_string(),
    "styles": styles.join("\n"),
    "chrome": chrome,
    "backgrounds": backgrounds,
    "matrix": matrix,
    "lines": lines.join("\n"),
  })
}

///|
/// Generate an SVG from the console contents and save it to a file.
pub fn Console::save_svg(
  self : Console,
  path : String,
  title? : String = "Rich",
  theme? : @color.TerminalTheme,
  clear? : Bool = true,
  code_format? : String = console_svg_format,
  font_aspect_ratio? : Double = 0.61,
  unique_id? : String,
) -> Unit raise {
  let svg = self.export_svg(
    title~,
    theme?,
    clear~,
    code_format~,
    font_aspect_ratio~,
    unique_id?,
  )
  if !@term.write_file(path, svg) {
    raise WriteError("unable to write \{path}")
  }
}
