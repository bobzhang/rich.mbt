// Syntax themes (rich/syntax.py: SyntaxTheme, PygmentsSyntaxTheme,
// ANSISyntaxTheme, ANSI_LIGHT, ANSI_DARK).

///|
/// The default theme (a Pygments style name).
pub const DEFAULT_THEME : String = "monokai"

///|
/// Base trait for a syntax theme (upstream abstract class `SyntaxTheme`).
pub(open) trait SyntaxTheme {
  /// Get a style for a given Pygments token type.
  fn get_style_for_token(Self, @token.TokenType) -> @rich.Style
  /// Get the background style.
  fn get_background_style(Self) -> @rich.Style
}

///|
/// Types accepted where upstream takes `Union[str, SyntaxTheme]`: a theme
/// name (`"monokai"`, `"ansi_dark"`, ...) or a theme instance.
pub(open) trait IntoSyntaxTheme {
  fn into_syntax_theme(Self) -> &SyntaxTheme
}

///|
pub impl IntoSyntaxTheme for String with fn into_syntax_theme(self) {
  get_theme(self)
}

///|
pub impl IntoSyntaxTheme for PygmentsSyntaxTheme with fn into_syntax_theme(self) {
  self
}

///|
pub impl IntoSyntaxTheme for ANSISyntaxTheme with fn into_syntax_theme(self) {
  self
}

///|
pub impl IntoSyntaxTheme for &SyntaxTheme with fn into_syntax_theme(self) {
  self
}

///|
/// Get a syntax theme instance by name (upstream `Syntax.get_theme`):
/// `"ansi_light"` / `"ansi_dark"` give an `ANSISyntaxTheme`, anything else a
/// `PygmentsSyntaxTheme` (unknown names fall back to Pygments' `default`).
pub fn get_theme(name : String) -> &SyntaxTheme {
  match name {
    "ansi_light" => ANSISyntaxTheme::new(ansi_light()) as &SyntaxTheme
    "ansi_dark" => ANSISyntaxTheme::new(ansi_dark())
    _ => PygmentsSyntaxTheme::new(name)
  }
}

///|
fn parse_color(s : String) -> @color.Color? {
  try @color.Color::parse(s) catch {
    _ => None
  } noraise {
    c => Some(c)
  }
}

///|
/// Syntax theme that delegates to a Pygments style.
pub(all) struct PygmentsSyntaxTheme {
  /// Cache of computed styles (upstream `_style_cache`).
  mut style_cache : Map[@token.TokenType, @rich.Style]
  /// The Pygments style (upstream `_pygments_style_class`).
  pygments_style : @styles.Style
  /// The style's background color (upstream `_background_color`).
  mut background_color : String?
  /// Upstream `_background_style`.
  mut background_style : @rich.Style
}

///|
/// A theme for the Pygments style called `theme`, or Pygments' `default`
/// style if there is no such style.
pub fn PygmentsSyntaxTheme::new(theme : String) -> PygmentsSyntaxTheme {
  let style = @styles.get_style_by_name(theme) catch {
    _ => @styles.default_style()
  }
  PygmentsSyntaxTheme::from_style(style)
}

///|
/// A theme for a Pygments style instance (upstream passes a style class).
pub fn PygmentsSyntaxTheme::from_style(
  style : @styles.Style,
) -> PygmentsSyntaxTheme {
  let background_color = style.background_color
  let background_style = match background_color.map(parse_color) {
    Some(Some(c)) => @rich.Style::new(bgcolor=c)
    _ => @rich.Style::new()
  }
  {
    style_cache: {},
    pygments_style: style,
    background_color,
    background_style,
  }
}

///|
pub impl SyntaxTheme for PygmentsSyntaxTheme with fn get_style_for_token(
  self,
  token_type,
) {
  match self.style_cache.get(token_type) {
    Some(style) => style
    None => {
      let style = try self.pygments_style.style_for_token(token_type) catch {
        _ => @rich.Style::null()
      } noraise {
        ts => {
          let color = match ts.color {
            Some(c) if c != "" => parse_color("#" + c)
            _ => parse_color("#000000")
          }
          let bgcolor = match ts.bgcolor {
            Some(c) if c != "" => parse_color("#" + c)
            _ =>
              match self.background_color {
                Some(c) => parse_color(c)
                None => None
              }
          }
          @rich.Style::new(
            color?,
            bgcolor?,
            bold=ts.bold,
            italic=ts.italic,
            underline=ts.underline,
          )
        }
      }
      self.style_cache[token_type] = style
      style
    }
  }
}

///|
pub impl SyntaxTheme for PygmentsSyntaxTheme with fn get_background_style(self) {
  self.background_style
}

///|
/// Syntax theme to use standard colors.
pub(all) struct ANSISyntaxTheme {
  style_map : Map[@token.TokenType, @rich.Style]
  priv style_cache : Map[@token.TokenType, @rich.Style]
}

///|
pub fn ANSISyntaxTheme::new(
  style_map : Map[@token.TokenType, @rich.Style],
) -> ANSISyntaxTheme {
  { style_map, style_cache: {}, }
}

///|
pub impl SyntaxTheme for ANSISyntaxTheme with fn get_style_for_token(
  self,
  token_type,
) {
  match self.style_cache.get(token_type) {
    Some(style) => style
    None => {
      // Styles form a hierarchy: go from most to least specific
      // (the root `Token` itself is never looked up, as upstream).
      let mut style = @rich.Style::null()
      let mut token = token_type
      while token.path().length() > 0 {
        if self.style_map.get(token) is Some(s) {
          style = s
          break
        }
        match token.parent() {
          Some(p) => token = p
          None => break
        }
      }
      self.style_cache[token_type] = style
      style
    }
  }
}

///|
pub impl SyntaxTheme for ANSISyntaxTheme with fn get_background_style(_self) {
  @rich.Style::null()
}

///|
fn style(definition : String) -> @rich.Style {
  try! @rich.Style::parse(definition)
}

///|
/// Upstream `ANSI_LIGHT`.
pub fn ansi_light() -> Map[@token.TokenType, @rich.Style] {
  Map::from_array([
    (@token.token, @rich.Style::new()),
    (@token.whitespace, style("white")),
    (@token.comment, style("dim")),
    (@token.comment_preproc, style("cyan")),
    (@token.keyword, style("blue")),
    (@token.keyword_type, style("cyan")),
    (@token.operator_word, style("magenta")),
    (@token.name_builtin, style("cyan")),
    (@token.name_function, style("green")),
    (@token.name_namespace, style("cyan underline")),
    (@token.name_class, style("green underline")),
    (@token.name_exception, style("cyan")),
    (@token.name_decorator, style("magenta bold")),
    (@token.name_variable, style("red")),
    (@token.name_constant, style("red")),
    (@token.name_attribute, style("cyan")),
    (@token.name_tag, style("bright_blue")),
    (@token.string, style("yellow")),
    (@token.number, style("blue")),
    (@token.generic_deleted, style("bright_red")),
    (@token.generic_inserted, style("green")),
    (@token.generic_heading, style("bold")),
    (@token.generic_subheading, style("magenta bold")),
    (@token.generic_prompt, style("bold")),
    (@token.generic_error, style("bright_red")),
    (@token.error, style("red underline")),
  ])
}

///|
/// Upstream `ANSI_DARK`.
pub fn ansi_dark() -> Map[@token.TokenType, @rich.Style] {
  Map::from_array([
    (@token.token, @rich.Style::new()),
    (@token.whitespace, style("bright_black")),
    (@token.comment, style("dim")),
    (@token.comment_preproc, style("bright_cyan")),
    (@token.keyword, style("bright_blue")),
    (@token.keyword_type, style("bright_cyan")),
    (@token.operator_word, style("bright_magenta")),
    (@token.name_builtin, style("bright_cyan")),
    (@token.name_function, style("bright_green")),
    (@token.name_namespace, style("bright_cyan underline")),
    (@token.name_class, style("bright_green underline")),
    (@token.name_exception, style("bright_cyan")),
    (@token.name_decorator, style("bright_magenta bold")),
    (@token.name_variable, style("bright_red")),
    (@token.name_constant, style("bright_red")),
    (@token.name_attribute, style("bright_cyan")),
    (@token.name_tag, style("bright_blue")),
    (@token.string, style("yellow")),
    (@token.number, style("bright_blue")),
    (@token.generic_deleted, style("bright_red")),
    (@token.generic_inserted, style("bright_green")),
    (@token.generic_heading, style("bold")),
    (@token.generic_subheading, style("bright_magenta bold")),
    (@token.generic_prompt, style("bold")),
    (@token.generic_error, style("bright_red")),
    (@token.error, style("red underline")),
  ])
}
