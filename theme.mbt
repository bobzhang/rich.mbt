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
/// `[styles]` section (keys are lower-cased like Python's configparser).
pub fn Theme::from_config(
  config : String,
  inherit_styles? : Bool = true,
) -> Theme raise RichError {
  let styles : Map[String, &IntoStyle] = Map([])
  let mut section = ""
  let mut last_key : String? = None
  for raw_line in config.split("\n") {
    let line = raw_line.to_owned()
    let stripped = py_strip(line)
    if stripped == "" || stripped.has_prefix("#") || stripped.has_prefix(";") {
      continue
    }
    // continuation line
    if (line.has_prefix(" ") || line.has_prefix("\t")) && last_key is Some(key) {
      if section == "styles" {
        let previous = match styles.get(key) {
          Some(s) => s.into_style_type().to_string()
          None => ""
        }
        styles[key] = previous + "\n" + stripped
      }
      continue
    }
    if stripped.has_prefix("[") && stripped.has_suffix("]") {
      section = py_slice(stripped, 1, stripped.length() - 1)
      last_key = None
      continue
    }
    let sep = match (stripped.find("="), stripped.find(":")) {
      (Some(a), Some(b)) => Some(@cmp.minimum(a, b))
      (Some(a), None) => Some(a)
      (None, Some(b)) => Some(b)
      (None, None) => None
    }
    match sep {
      None =>
        raise ValueError("Source contains parsing errors: \{py_repr(line)}")
      Some(i) => {
        let key = py_strip(py_slice(stripped, 0, i)).to_lower()
        let value = py_strip(py_slice(stripped, i + 1, stripped.length()))
        if section == "styles" {
          styles[key] = value
        }
        last_key = Some(key)
      }
    }
  }
  let parsed : Map[String, &IntoStyle] = Map([])
  for name, value in styles {
    parsed[name] = Style::parse(value.into_style_type().to_string())
  }
  Theme::new(styles=parsed, inherit_styles~)
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
