// Port of rich/emoji.py (the renderable).

///|
/// A single emoji character.
pub struct Emoji {
  name : String
  style : StyleType
  variant : EmojiVariant?
  priv char : String
}

///|
/// Create an emoji by name, e.g. `"smiley"`. Raises `NoEmoji` if there is
/// no such emoji.
pub fn Emoji::new(
  name : String,
  style? : &IntoStyle,
  variant? : EmojiVariant,
) -> Emoji raise RichError {
  let char = match @emoji.get(name) {
    Some(c) => c
    None => raise NoEmoji("No emoji called \{py_repr(name)}")
  }
  let char = match variant {
    Some(v) => char + @emoji.variant_code(v.to_string()).unwrap_or("")
    None => char
  }
  {
    name,
    style: match style {
      Some(s) => s.into_style_type()
      None => Def("none")
    },
    variant,
    char,
  }
}

///|
/// Replace emoji markup with corresponding unicode characters.
pub fn Emoji::replace(text : String) -> String {
  @emoji.replace(text)
}

///|
/// Upstream `repr(emoji)`, e.g. `<emoji 'smiley'>`.
pub fn Emoji::repr(self : Emoji) -> String {
  "<emoji \{py_repr(self.name)}>"
}

///|
/// `Show` gives the emoji character, like upstream `str(emoji)`.
pub impl Show for Emoji with fn output(self, logger) {
  logger.write_string(self.char)
}

///|
pub impl Debug for Emoji with fn to_repr(self) {
  @debug.Repr(self.repr())
}

///|
pub impl Renderable for Emoji with fn rich_console(self, console, _options) {
  [Seg(Segment::new(self.char, style=console.get_style(self.style)))]
}
