// Port of rich/ansi.py.

///|
let re_ansi : @regex.Regex = @regex.compile(
  "\n(?:\u{1b}[0-?])|\n(?:\u{1b}\\](.*?)\u{1b}\\\\)|\n(?:\u{1b}([(@-Z\\\\-_]|\\[[0-?]*[ -/]*[@-~]))\n",
  flags=@regex.VERBOSE,
) catch {
  _ => abort("bad ansi regex")
}

///|
priv struct AnsiToken {
  plain : String
  sgr : String?
  osc : String?
}

///|
fn ansi_tokenize(ansi_text : String) -> Array[AnsiToken] {
  let out = []
  let mut position = 0
  let matches = re_ansi.find_all(ansi_text) catch { _ => [] }
  for m in matches {
    let start = m.start()
    let end = m.end()
    let osc = m.group(1)
    let sgr = m.group(2)
    if start > position {
      out.push({
        plain: py_slice(ansi_text, position, start),
        sgr: Some(""),
        osc: Some(""),
      })
    }
    match sgr {
      Some(s) if s != "" => {
        if s == "(" {
          position = end + 1
          continue
        }
        if s.has_suffix("m") {
          out.push({
            plain: "",
            sgr: Some(py_slice(s, 1, s.length() - 1)),
            osc,
          })
        }
      }
      _ => out.push({ plain: "", sgr, osc, })
    }
    position = end
  }
  if position < ansi_text.length() {
    out.push({
      plain: py_slice(ansi_text, position, ansi_text.length()),
      sgr: Some(""),
      osc: Some(""),
    })
  }
  out
}

///|
let sgr_style_map : Map[Int, String] = {
  1: "bold",
  2: "dim",
  3: "italic",
  4: "underline",
  5: "blink",
  6: "blink2",
  7: "reverse",
  8: "conceal",
  9: "strike",
  21: "underline2",
  22: "not dim not bold",
  23: "not italic",
  24: "not underline",
  25: "not blink",
  26: "not blink2",
  27: "not reverse",
  28: "not conceal",
  29: "not strike",
  30: "color(0)",
  31: "color(1)",
  32: "color(2)",
  33: "color(3)",
  34: "color(4)",
  35: "color(5)",
  36: "color(6)",
  37: "color(7)",
  39: "default",
  40: "on color(0)",
  41: "on color(1)",
  42: "on color(2)",
  43: "on color(3)",
  44: "on color(4)",
  45: "on color(5)",
  46: "on color(6)",
  47: "on color(7)",
  49: "on default",
  51: "frame",
  52: "encircle",
  53: "overline",
  54: "not frame not encircle",
  55: "not overline",
  90: "color(8)",
  91: "color(9)",
  92: "color(10)",
  93: "color(11)",
  94: "color(12)",
  95: "color(13)",
  96: "color(14)",
  97: "color(15)",
  100: "on color(8)",
  101: "on color(9)",
  102: "on color(10)",
  103: "on color(11)",
  104: "on color(12)",
  105: "on color(13)",
  106: "on color(14)",
  107: "on color(15)",
}

///|
/// Translate ANSI codes in to styled Text.
pub struct AnsiDecoder {
  priv mut style : Style
}

///|
pub fn AnsiDecoder::new() -> AnsiDecoder {
  { style: Style::null(), }
}

///|
/// Decode ANSI codes in terminal output, one Text per line.
pub fn AnsiDecoder::decode(
  self : AnsiDecoder,
  terminal_text : String,
) -> Array[Text] {
  // re.split(r"(?<=\n)", text)
  let lines = []
  let mut start = 0
  for i in 0..<terminal_text.length() {
    if terminal_text[i] == '\n' {
      lines.push(py_slice(terminal_text, start, i + 1))
      start = i + 1
    }
  }
  lines.push(py_slice(terminal_text, start, terminal_text.length()))
  lines.map(line => {
    let mut end = line.length()
    while end > 0 && line[end - 1] == '\n' {
      end -= 1
    }
    self.decode_line(py_slice(line, 0, end))
  })
}

///|
fn is_py_digit_str(s : String) -> Bool {
  s != "" && s.iter().all(c => c >= '0' && c <= '9')
}

///|
/// Decode a line containing ANSI codes.
pub fn AnsiDecoder::decode_line(self : AnsiDecoder, line : String) -> Text {
  let text = Text::new()
  let line = match line.rev_find("\r") {
    Some(i) => py_slice(line, i + 1, line.length())
    None => line
  }
  for token in ansi_tokenize(line) {
    if token.plain != "" {
      text.append_str(
        token.plain,
        style?=if self.style.to_bool() { Some(self.style) } else { None },
      )
      |> ignore
    } else if token.osc is Some(osc) {
      if osc.has_prefix("8;") {
        let (_, semicolon, link) = partition(
          py_slice(osc, 2, osc.length()),
          ";",
        )
        if semicolon {
          self.style = self.style.update_link(
            if link == "" {
              None
            } else {
              Some(link)
            },
          )
        }
      }
    } else if token.sgr is Some(sgr) {
      let codes = []
      for code in sgr.split(";") {
        let code = code.to_owned()
        if code == "" {
          codes.push(0)
        } else if is_py_digit_str(code) {
          codes.push(@cmp.minimum(255, parse_int_or(code, 255)))
        }
      }
      let mut i = 0
      fn next() -> Int? {
        if i < codes.length() {
          let c = codes[i]
          i += 1
          Some(c)
        } else {
          None
        }
      }

      while next() is Some(code) {
        if code == 0 {
          self.style = Style::null()
        } else if sgr_style_map.get(code) is Some(definition) {
          self.style = self.style +
            (Style::parse(definition) catch { _ => Style::null() })
        } else if code == 38 || code == 48 {
          let foreground = code == 38
          match next() {
            Some(5) =>
              if next() is Some(n) {
                let c = @color.Color::from_ansi(n)
                self.style = self.style +
                  (if foreground {
                    Style::from_color(color=c)
                  } else {
                    Style::from_color(bgcolor=c)
                  })
              }
            Some(2) =>
              match (next(), next(), next()) {
                (Some(r), Some(g), Some(b)) => {
                  let c = @color.Color::from_rgb(
                    r.to_double(),
                    g.to_double(),
                    b.to_double(),
                  )
                  self.style = self.style +
                    (if foreground {
                      Style::from_color(color=c)
                    } else {
                      Style::from_color(bgcolor=c)
                    })
                }
                _ => ()
              }
            _ => ()
          }
        }
      }
    }
  }
  text
}
