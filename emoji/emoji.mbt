// Port of rich/_emoji_replace.py and the data of rich/_emoji_codes.py.

///|
/// Look up an emoji by name (e.g. `"smiley"`).
pub fn get(name : String) -> String? {
  emoji_codes.get(name)
}

///|
/// All emoji names, in upstream order.
pub fn names() -> Array[String] {
  emoji_codes.keys().collect()
}

///|
/// The variation selector for `"text"` or `"emoji"`.
pub fn variant_code(variant : String) -> String? {
  match variant {
    "text" => Some("\u{fe0e}")
    "emoji" => Some("\u{fe0f}")
    _ => None
  }
}

///|
let emoji_re : @regex.Regex = @regex.compile(
  "(:(\\S*?)(?:(?:\\-)(emoji|text))?:)",
) catch {
  _ => abort("bad emoji regex")
}

///|
/// Replace emoji codes such as `:smiley:` in text. `default_variant` is
/// `"text"` or `"emoji"`.
pub fn replace(text : String, default_variant? : String) -> String {
  if !text.contains(":") {
    return text
  }
  let default_variant_code = match default_variant {
    Some(v) => variant_code(v).unwrap_or("")
    None => ""
  }
  emoji_re.replace_all(text, m => {
    let emoji_code = m.group(1).unwrap_or("")
    let emoji_name = m.group(2).unwrap_or("")
    match emoji_codes.get(@pystr.lower(emoji_name)) {
      Some(e) => {
        let variant = match m.group(3) {
          Some(v) => variant_code(v).unwrap_or(default_variant_code)
          None => default_variant_code
        }
        e + variant
      }
      None => emoji_code
    }
  }) catch {
    _ => text
  }
}
