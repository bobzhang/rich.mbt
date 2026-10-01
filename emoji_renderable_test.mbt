// Port of tests/test_emoji.py.

///|
/// Upstream tests/render.py `render`.
fn render_for_test(
  renderable : &@rich.Renderable,
  no_wrap? : Bool = false,
) -> String raise {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    width=100,
    file~,
    color_system=Some("truecolor"),
    legacy_windows=false,
    environ={},
  )
  console.print(renderable, no_wrap~)
  file.getvalue()
}

///|
test "no_emoji" {
  try @rich.Emoji::new("ambivalent_bunny") catch {
    NoEmoji(msg) => inspect(msg, content="No emoji called 'ambivalent_bunny'")
    e => fail("unexpected \{e}")
  } noraise {
    _ => fail("expected NoEmoji")
  }
}

///|
test "str_repr" {
  inspect(@rich.Emoji::new("pile_of_poo"), content="💩")
  inspect(
    @rich.Emoji::new("pile_of_poo").repr(),
    content="<emoji 'pile_of_poo'>",
  )
}

///|
test "replace" {
  inspect(
    @rich.Emoji::replace("my code is :pile_of_poo:"),
    content="my code is 💩",
  )
}

///|
test "render" {
  let render_result = render_for_test(@rich.Emoji::new("pile_of_poo"))
  // `end` is only added after strings and Text, so there is no new line
  assert_eq(render_result, "💩")
}

///|
test "variant" {
  assert_eq(@rich.Emoji::replace(":warning:"), "⚠")
  assert_eq(@rich.Emoji::replace(":warning-text:"), "⚠" + "\u{FE0E}")
  assert_eq(@rich.Emoji::replace(":warning-emoji:"), "⚠" + "\u{FE0F}")
  assert_eq(@rich.Emoji::replace(":warning-foo:"), ":warning-foo:")
}

///|
test "variant_non_default" {
  let render_result = render_for_test(
    @rich.Emoji::new("warning", variant=Emoji),
  )
  assert_eq(render_result, "⚠" + "\u{FE0F}")
}
