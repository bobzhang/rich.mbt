// Helpers for style_oracle_test.mbt (see scripts/gen_style_tests.py).

///|
/// Replace link ids (`id=<digits>;`) with `id=0;` (link ids are random).
fn replace_link_ids(s : String) -> String {
  let buf = StringBuilder()
  let mut rest = s
  while rest.find("id=") is Some(i) {
    buf.write_string(rest.view(end_offset=i).to_owned())
    let after = rest.view(start_offset=i + 3).to_owned()
    match after.find(";") {
      Some(j) if after
        .view(end_offset=j)
        .iter()
        .all(c => c is ('0'..='9' | '.' | '-')) => {
        buf.write_string("id=0;")
        rest = after.view(start_offset=j + 1).to_owned()
      }
      _ => {
        buf.write_string("id=")
        rest = after
      }
    }
  }
  buf.write_string(rest)
  buf.to_string()
}

///|
fn describe_style(definition : String) -> Array[String] {
  let style = @rich.Style::parse(definition) catch {
    e => return ["error: \{e}"]
  }
  let out = [
    style.to_string(),
    style.repr(),
    if style.to_bool() {
      "True"
    } else {
      "False"
    },
  ]
  let systems : Array[@color.ColorSystem] = [
    Truecolor,
    EightBit,
    Standard,
    Windows,
  ]
  for system in systems {
    out.push(
      replace_link_ids(style.render(text="x", color_system=Some(system))),
    )
  }
  out.push(style.get_html_style())
  out
}
