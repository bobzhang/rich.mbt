// Port of rich/theme.py, rich/themes.py and rich/default_styles.py.

///|
/// The default styles, by name.
pub fn default_styles() -> Map[String, Style] {
  let m : Map[String, Style] = Map([])
  for item in default_style_definitions {
    m[item.0] = Style::parse(item.1) catch { _ => abort("bad default style") }
  }
  m
}

///|
let default_styles_map : Map[String, Style] = default_styles()

///|
/// A container for style information, used by `Console`.
pub struct Theme {
  styles : Map[String, Style]
}

///|
/// Create a theme. With `inherit`, the default styles are included.
/// Style definitions are parsed (raising on syntax errors).
pub fn Theme::new(
  styles? : Map[String, &IntoStyle],
  inherit_styles? : Bool = true,
) -> Theme raise RichError {
  let m : Map[String, Style] = if inherit_styles {
    default_styles_map.copy()
  } else {
    Map([])
  }
  if styles is Some(styles) {
    for name, style in styles {
      m[name] = match style.into_style_type() {
        Style(s) => s
        Def(d) => Style::parse(d)
      }
    }
  }
  { styles: m, }
}

///|
/// Contents of a config file for this theme.
pub fn Theme::config(self : Theme) -> String {
  let items = self.styles.to_array()
  items.sort_by((a, b) => a.0.compare(b.0))
  "[styles]\n" + items.map(kv => "\{kv.0} = \{kv.1}").join("\n")
}

///|
/// Load a theme from the contents of an INI-style config file with a
/// `[styles]` section (upstream `Theme.from_file`, which reads the file
/// with Python's `configparser`: keys are lower-cased, `[DEFAULT]` values
/// are inherited, values may continue on indented lines and `%%` /
/// `%(name)s` are interpolated). Configparser errors are `ValueError`s
/// with the upstream message.
pub fn Theme::from_config(
  config : String,
  inherit_styles? : Bool = true,
) -> Theme raise RichError {
  let parsed : Map[String, &IntoStyle] = Map([])
  for item in config_items(config, "styles") {
    parsed[item.0] = Style::parse(item.1)
  }
  Theme::new(styles=parsed, inherit_styles~)
}

///|
/// The `(name, value)` items of a section of an INI file, as Python's
/// `ConfigParser().read_string(config); config.items(section)`.
fn config_items(
  config : String,
  section_name : String,
) -> Array[(String, String)] raise RichError {
  // section name -> ordered option names and their value lines
  let sections : Map[String, Map[String, Array[String]]] = Map([])
  let defaults : Map[String, Array[String]] = Map([])
  let errors = []
  let mut cursect : Map[String, Array[String]]? = None
  let mut sectname = ""
  let mut optname : String? = None
  let mut indent_level = 0
  let lines = config.split("\n").map(l => l.to_owned()).to_array()
  // `split` gives a trailing empty line for a final "\n"
  if lines.length() > 0 && lines[lines.length() - 1] == "" {
    lines.pop() |> ignore
  }
  for index, line in lines {
    let lineno = index + 1
    let value = py_strip(line)
    if value == "" || value.has_prefix("#") || value.has_prefix(";") {
      if value == "" && cursect is Some(sect) && optname is Some(name) {
        // empty lines are kept in multi-line values
        if sect.get(name) is Some(v) {
          v.push("")
        }
      } else {
        indent_level = 0x7fffffff
      }
      continue
    }
    let stripped_left = line.trim_start(chars=" \t").to_string()
    let cur_indent_level = line.length() - stripped_left.length()
    if cursect is Some(sect) &&
      optname is Some(name) &&
      cur_indent_level > indent_level {
      if sect.get(name) is Some(v) {
        v.push(value)
      }
      continue
    }
    indent_level = cur_indent_level
    // SECTCRE = r"\[(?P<header>.+)\]" (matched at the start)
    if value.has_prefix("[") && value.rev_find("]") is Some(close) && close > 1 {
      let name = py_slice(value, 1, close)
      if name == "DEFAULT" {
        cursect = Some(defaults)
      } else {
        if sections.contains(name) {
          raise ValueError(
            "While reading from '<???>' [line \{pad2(lineno)}]: section \{py_repr(name)} already exists",
          )
        }
        let sect = Map([])
        sections[name] = sect
        cursect = Some(sect)
      }
      sectname = name
      optname = None
      continue
    }
    guard cursect is Some(sect) else {
      raise ValueError(
        "File contains no section headers.\nfile: '<???>', line: \{lineno}\n\{py_repr(line + "\n")}",
      )
    }
    // OPTCRE = r"(?P<option>.*?)\s*(?P<vi>=|:)\s*(?P<value>.*)$"
    let sep = match (value.find("="), value.find(":")) {
      (Some(a), Some(b)) => Some(@cmp.minimum(a, b))
      (Some(a), None) => Some(a)
      (None, Some(b)) => Some(b)
      (None, None) => None
    }
    match sep {
      Some(i) if py_strip(py_slice(value, 0, i)) != "" => {
        let name = @pystr.lower(py_strip(py_slice(value, 0, i)))
        if sect.contains(name) {
          raise ValueError(
            "While reading from '<???>' [line \{pad2(lineno)}]: option \{py_repr(name)} in section \{py_repr(sectname)} already exists",
          )
        }
        sect[name] = [py_strip(py_slice(value, i + 1, value.length()))]
        optname = Some(name)
      }
      _ => {
        errors.push("\n\t[line \{pad2(lineno)}]: \{py_repr(line + "\n")}")
        optname = None
      }
    }
  }
  if errors.length() > 0 {
    raise ValueError(
      "Source contains parsing errors: '<???>'" + errors.join(""),
    )
  }
  guard sections.get(section_name) is Some(section) else {
    raise ValueError("No section: \{py_repr(section_name)}")
  }
  let merged : Map[String, String] = Map([])
  for name, value in defaults {
    merged[name] = py_rstrip(value.join("\n"))
  }
  for name, value in section {
    merged[name] = py_rstrip(value.join("\n"))
  }
  let items = []
  for name, value in merged {
    items.push((name, interpolate(merged, section_name, name, value, 1)))
  }
  items
}

///|
/// Python `"%2d" % n`.
fn pad2(n : Int) -> String {
  if n < 10 {
    " \{n}"
  } else {
    n.to_string()
  }
}

///|
/// configparser `BasicInterpolation`: `%%` is a literal `%` and
/// `%(name)s` the value of another option.
fn interpolate(
  options : Map[String, String],
  section : String,
  option : String,
  value : String,
  depth : Int,
) -> String raise RichError {
  if depth > 10 {
    raise ValueError(
      "Recursion limit exceeded in value substitution: option \{py_repr(option)} in section \{py_repr(section)} contains an interpolation key which cannot be substituted in 10 steps. Raw value: \{py_repr(value)}",
    )
  }
  let buf = StringBuilder()
  let mut rest = value
  while rest.find("%") is Some(p) {
    buf.write_string(py_slice(rest, 0, p))
    rest = py_slice(rest, p, rest.length())
    if rest.has_prefix("%%") {
      buf.write_char('%')
      rest = py_slice(rest, 2, rest.length())
    } else if rest.has_prefix("%(") && rest.find(")s") is Some(close) {
      let name = @pystr.lower(py_slice(rest, 2, close))
      rest = py_slice(rest, close + 2, rest.length())
      match options.get(name) {
        Some(v) =>
          buf.write_string(
            if v.contains("%") {
              interpolate(options, section, option, v, depth + 1)
            } else {
              v
            },
          )
        None =>
          raise ValueError(
            "Bad value substitution: option \{py_repr(option)} in section \{py_repr(section)} contains an interpolation key \{py_repr(name)} which is not a valid option name. Raw value: \{py_repr(value)}",
          )
      }
    } else {
      raise ValueError(
        "'%' must be followed by '%' or '(', found: \{py_repr(rest)}",
      )
    }
  }
  buf.write_string(rest)
  buf.to_string()
}

///|
/// The default theme.
pub let default_theme : Theme = { styles: default_styles_map, }

///|
/// A stack of themes.
pub struct ThemeStack {
  priv entries : Array[Map[String, Style]]
}

///|
pub fn ThemeStack::new(theme : Theme) -> ThemeStack {
  { entries: [theme.styles], }
}

///|
/// Get a style by name from the top-most theme.
pub fn ThemeStack::get(self : ThemeStack, name : String) -> Style? {
  self.entries[self.entries.length() - 1].get(name)
}

///|
/// Push a theme on the top of the stack.
pub fn ThemeStack::push_theme(
  self : ThemeStack,
  theme : Theme,
  inherit_styles? : Bool = true,
) -> Unit {
  let styles = if inherit_styles {
    let m = self.entries[self.entries.length() - 1].copy()
    for k, v in theme.styles {
      m[k] = v
    }
    m
  } else {
    theme.styles.copy()
  }
  self.entries.push(styles)
}

///|
/// Pop (and discard) the top-most theme.
pub fn ThemeStack::pop_theme(self : ThemeStack) -> Unit raise RichError {
  if self.entries.length() == 1 {
    raise StyleStackError("Unable to pop base theme")
  }
  ignore(self.entries.pop())
}
