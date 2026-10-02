///|
/// Reference `markup._parse` driven by upstream's `RE_TAGS` regex: the
/// hand-written tag scanner of `parse_markup` must agree with it.
fn regex_parse_markup(markup : String) -> Array[@rich.MarkupItem] {
  let re = @regex.compile("((\\\\*)\\[([a-z#/@][^[]*?)])") catch {
    _ => abort("bad regex")
  }
  let out = []
  let mut position = 0
  for m in (try! re.find_all(markup)) {
    let full_text = m.group(1).unwrap_or("")
    let escapes = m.group(2).unwrap_or("")
    let tag_text = m.group(3).unwrap_or("")
    let mut start = m.start()
    let end = m.end()
    if start > position {
      out.push(
        @rich.MarkupItem::PlainText(
          start,
          markup.view(start_offset=position, end_offset=start).to_owned(),
        ),
      )
    }
    if escapes != "" {
      let backslashes = escapes.length() / 2
      if backslashes != 0 {
        out.push(PlainText(start, "\\".repeat(backslashes)))
        start += backslashes * 2
      }
      if escapes.length() % 2 != 0 {
        out.push(
          PlainText(
            start,
            full_text.view(start_offset=escapes.length()).to_owned(),
          ),
        )
        position = end
        continue
      }
    }
    let tag : @rich.Tag = match tag_text.find("=") {
      Some(i) =>
        {
          name: tag_text.view(end_offset=i).to_owned(),
          parameters: Some(tag_text.view(start_offset=i + 1).to_owned()),
        }
      None => { name: tag_text, parameters: None, }
    }
    out.push(TagAt(start, tag))
    position = end
  }
  if position < markup.length() {
    out.push(PlainText(position, markup.view(start_offset=position).to_owned()))
  }
  out
}

///|
test "parse_markup agrees with the RE_TAGS regex" {
  let alphabet = [
    "\\", "\\", "[", "[", "]", "]", "a", "z", "/", "#", "@", "=", " ", "B", "1",
    "é", "😀", "\n",
  ]
  let mut seed = 12345
  for _ in 0..<4000 {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff
    let length = seed % 16
    let sb = StringBuilder()
    for _ in 0..<length {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff
      sb.write_string(alphabet[(seed >> 8) % alphabet.length()])
    }
    let s = sb.to_string()
    assert_eq(@rich.parse_markup(s), regex_parse_markup(s))
  }
  for
    s in [
      "[bold]x[/bold]", "\\[bold]", "\\\\[bold]x[/]", "\\\\\\[b]", "[a[b]c]", "[a=b=c]",
      "[link=https://x.org/?a=[1]]", "[#ff0000 on blue]x", "\\", "[", "]", "[/]",
    ] {
    assert_eq(@rich.parse_markup(s), regex_parse_markup(s))
  }
}
