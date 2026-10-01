// Port of tests/test_text.py.
//
// Offsets are UTF-16 offsets: spans over astral characters (emoji) are
// converted from upstream's code-point offsets.

///|
fn test_console(
  width? : Int = 80,
  record? : Bool = false,
  file? : @rich.StringIO,
  markup? : Bool = true,
  emoji? : Bool = true,
  color_system? : String? = None,
  force_terminal? : Bool,
) -> @rich.Console raise {
  @rich.Console::new(
    width~,
    record~,
    file=file.unwrap_or(@rich.StringIO::new()),
    markup~,
    emoji~,
    color_system~,
    force_terminal?,
    legacy_windows=false,
    environ={},
  )
}

///|
fn span(start : Int, end : Int, style : &@rich.IntoStyle) -> @rich.Span {
  @rich.Span::new(start, end, style)
}

///|
fn text(s : String, style? : &@rich.IntoStyle) -> @rich.Text {
  @rich.Text::new(text=s, style?)
}

///|
fn sorted_spans(spans : Array[@rich.Span]) -> Array[@rich.Span] {
  let spans = spans.copy()
  spans.sort_by((a, b) => {
    let c = a.start.compare(b.start)
    if c != 0 {
      c
    } else {
      a.end.compare(b.end)
    }
  })
  spans
}

///|
test "span" {
  let s = span(1, 10, "foo")
  inspect(s, content="Span(1, 10, 'foo')")
  assert_true(s.to_bool())
  assert_false(span(10, 10, "foo").to_bool())
}

///|
test "span_split" {
  assert_eq(span(5, 10, "foo").split(2), (span(5, 10, "foo"), None))
  assert_eq(span(5, 10, "foo").split(15), (span(5, 10, "foo"), None))
  assert_eq(
    span(0, 10, "foo").split(5),
    (span(0, 5, "foo"), Some(span(5, 10, "foo"))),
  )
}

///|
test "span_move" {
  assert_eq(span(5, 10, "foo").move_(2), span(7, 12, "foo"))
}

///|
test "span_right_crop" {
  assert_eq(span(5, 10, "foo").right_crop(15), span(5, 10, "foo"))
  assert_eq(span(5, 10, "foo").right_crop(7), span(5, 7, "foo"))
}

///|
test "len" {
  inspect(text("foo").length(), content="3")
}

///|
test "cell_len" {
  inspect(text("foo").cell_len(), content="3")
  inspect(text("😀").cell_len(), content="2")
}

///|
test "bool" {
  assert_true(text("foo").to_bool())
  assert_false(text("").to_bool())
}

///|
test "str" {
  inspect(text("foo"), content="foo")
}

///|
test "repr" {
  inspect(text("foo").repr(), content="<text 'foo' [] ''>")
  let t = text("foo bar", style="bold")
  t.stylize("red", start=0, end=3)
  inspect(t.repr(), content="<text 'foo bar' [Span(0, 3, 'red')] 'bold'>")
}

///|
test "add" {
  let t = text("foo") + text("bar")
  inspect(t, content="foobar")
  inspect(text("foo").concat("bar"), content="foobar")
}

///|
test "eq" {
  assert_eq(text("foo"), text("foo"))
  assert_not_eq(text("foo"), text("bar"))
}

///|
test "contain" {
  let t = text("foobar")
  assert_true(t.contains("foo"))
  assert_false(t.contains("foo "))
  assert_true(t.contains(text("bar")))
}

///|
test "plain_property" {
  let t = text("foo")
  t.append("bar") |> ignore
  t.append("baz") |> ignore
  inspect(t.plain(), content="foobarbaz")
}

///|
test "plain_property_setter" {
  let t = text("foo")
  t.set_plain("bar")
  inspect(t, content="bar")
  let t = text("")
  t.append("Hello, World", style="bold") |> ignore
  t.set_plain("Hello")
  inspect(t, content="Hello")
  assert_eq(t.spans(), [span(0, 5, "bold")])
}

///|
test "from_markup" {
  let t = @rich.Text::from_markup("Hello, [bold]World![/bold]")
  inspect(t, content="Hello, World!")
  assert_eq(t.spans(), [span(7, 13, "bold")])
}

///|
test "from_ansi" {
  let bold = @rich.Style::new(bold=true)
  let t = @rich.Text::from_ansi("Hello, \u{1b}[1mWorld!\u{1b}[0m")
  inspect(t, content="Hello, World!")
  assert_eq(t.spans(), [span(7, 13, bold)])
  let t = @rich.Text::from_ansi("Hello, \u{1b}[1m\nWorld!\u{1b}[0m")
  assert_eq(t.plain(), "Hello, \nWorld!")
  assert_eq(t.spans(), [span(8, 14, bold)])
  let t = @rich.Text::from_ansi("\u{1b}[1mBOLD\u{1b}[m not bold")
  inspect(t, content="BOLD not bold")
  assert_eq(t.spans(), [span(0, 4, bold)])
  let t = @rich.Text::from_ansi("\u{1b}[1m\u{1b}[Kfoo barmbaz")
  inspect(t, content="foo barmbaz")
  assert_eq(t.spans(), [span(0, 11, bold)])
}

///|
test "copy" {
  let t = text("")
  t.append("Hello", style="bold") |> ignore
  t.append(" ") |> ignore
  t.append("World", style="italic") |> ignore
  let test_copy = t.copy()
  assert_eq(t, test_copy)
  assert_false(physical_equal(t, test_copy))
}

///|
test "rstrip" {
  let t = text("Hello, World!    ")
  t.rstrip()
  inspect(t, content="Hello, World!")
}

///|
test "rstrip_end" {
  let t = text("Hello, World!    ")
  t.rstrip_end(14)
  assert_eq(t.plain(), "Hello, World! ")
}

///|
test "stylize" {
  let t = text("Hello, World!")
  t.stylize("bold", start=7, end=11)
  assert_eq(t.spans(), [span(7, 11, "bold")])
  t.stylize("bold", start=20, end=25)
  assert_eq(t.spans(), [span(7, 11, "bold")])
}

///|
test "stylize_before" {
  let t = text("Hello, World!")
  t.stylize("bold", start=0, end=5)
  t.stylize_before("italic", start=2, end=7)
  assert_eq(t.spans(), [span(2, 7, "italic"), span(0, 5, "bold")])
}

///|
test "stylize_negative_index" {
  let t = text("Hello, World!")
  t.stylize("bold", start=-6, end=-1)
  assert_eq(t.spans(), [span(7, 12, "bold")])
}

///|
test "highlight_regex" {
  // As a string
  let t = text("peek-a-boo")
  let count = t.highlight_pattern("NEVER_MATCH", style="red")
  inspect(count, content="0")
  inspect(t.spans().length(), content="0")
  let count = t.highlight_pattern("[a|e|o]+", style="red")
  inspect(count, content="3")
  assert_eq(sorted_spans(t.spans()), [
    span(1, 3, "red"),
    span(5, 6, "red"),
    span(8, 10, "red"),
  ])
  let t = text("Ada Lovelace, Alan Turing")
  let count = t.highlight_pattern(
    "(?P<yellow>[A-Za-z]+)[ ]+(?P<red>[A-Za-z]+)(?P<NEVER_MATCH>NEVER_MATCH)*",
  )
  inspect(count, content="2")
  assert_eq(sorted_spans(t.spans()), [
    span(0, 3, "yellow"),
    span(4, 12, "red"),
    span(14, 18, "yellow"),
    span(19, 25, "red"),
  ])
  // As a regular expression object
  let t = text("peek-a-boo")
  let count = t.highlight_regex(@rich.compile_regex("NEVER_MATCH"), style="red")
  inspect(count, content="0")
  inspect(t.spans().length(), content="0")
  let count = t.highlight_regex(@rich.compile_regex("[a|e|o]+"), style="red")
  inspect(count, content="3")
  assert_eq(sorted_spans(t.spans()), [
    span(1, 3, "red"),
    span(5, 6, "red"),
    span(8, 10, "red"),
  ])
  let t = text("Ada Lovelace, Alan Turing")
  let count = t.highlight_regex(
    @rich.compile_regex(
      "(?P<yellow>[A-Za-z]+)[ ]+(?P<red>[A-Za-z]+)(?P<NEVER_MATCH>NEVER_MATCH)*",
    ),
  )
  inspect(count, content="2")
  assert_eq(sorted_spans(t.spans()), [
    span(0, 3, "yellow"),
    span(4, 12, "red"),
    span(14, 18, "yellow"),
    span(19, 25, "red"),
  ])
}

///|
test "highlight_regex_callable" {
  let t = text("Vulnerability CVE-2018-6543 detected")
  fn get_style(s : String) -> @rich.StyleType? {
    Some(
      Style(
        @rich.Style::parse(
          "bold yellow link https://cve.mitre.org/cgi-bin/cvekey.cgi?keyword=\{s}",
        ) catch {
          _ => abort("bad style")
        },
      ),
    )
  }

  let count = t.highlight_regex(
    @rich.compile_regex("CVE-\\d{4}-\\d+"),
    style_fn=get_style,
  )
  inspect(count, content="1")
  inspect(t.spans().length(), content="1")
  inspect(t.spans()[0].start, content="14")
  inspect(t.spans()[0].end, content="27")
  guard t.spans()[0].style is Style(style) else { fail("expected a Style") }
  assert_eq(
    style.link(),
    Some("https://cve.mitre.org/cgi-bin/cvekey.cgi?keyword=CVE-2018-6543"),
  )
}

///|
test "highlight_words" {
  let t = text("Do NOT! touch anything!")
  let count = t.highlight_words(["NOT", "!"], "red")
  inspect(count, content="3")
  assert_eq(sorted_spans(t.spans()), [
    span(3, 6, "red"),
    span(6, 7, "red"),
    span(22, 23, "red"),
  ])
  // regex escape test
  let t = text("[o|u]aeiou")
  let count = t.highlight_words(["[a|e|i]", "[o|u]"], "red")
  inspect(count, content="1")
  assert_eq(t.spans(), [span(0, 5, "red")])
  // case sensitive
  let t = text("AB Ab aB ab")
  let count = t.highlight_words(["AB"], "red")
  inspect(count, content="1")
  assert_eq(t.spans(), [span(0, 2, "red")])
  let t = text("AB Ab aB ab")
  let count = t.highlight_words(["AB"], "red", case_sensitive=false)
  inspect(count, content="4")
}

///|
test "set_length" {
  let t = text("Hello")
  t.set_length(5)
  assert_eq(t, text("Hello"))
  let t = text("Hello")
  t.set_length(10)
  assert_eq(t, text("Hello     "))
  let t = text("Hello World")
  t.stylize("bold", start=0, end=5)
  t.stylize("italic", start=7, end=9)
  t.set_length(3)
  let expected = text("")
  expected.append("Hel", style="bold") |> ignore
  assert_eq(t, expected)
}

///|
test "console_width" {
  let console = test_console()
  let options = console.options()
  let t = text("Hello World!\nfoobarbaz")
  assert_eq(
    t.rich_measure(console, options),
    Some(@rich.Measurement::new(9, 12)),
  )
  assert_eq(
    text(" ".repeat(4)).rich_measure(console, options),
    Some(@rich.Measurement::new(4, 4)),
  )
  assert_eq(
    text(" \n  \n   ").rich_measure(console, options),
    Some(@rich.Measurement::new(3, 3)),
  )
}

///|
test "join" {
  let t = text("bar").join([text("foo", style="red"), text("baz", style="blue")])
  inspect(t, content="foobarbaz")
  assert_eq(t.spans(), [span(0, 3, "red"), span(6, 9, "blue")])
}

///|
test "trim_spans" {
  let t = text("Hello")
  t.spans().append([span(0, 3, "red"), span(3, 6, "green"), span(6, 9, "blue")])
  // `_trim_spans` is private: `set_plain` to a shorter text trims spans
  t.set_plain("Hello!")
  t.set_plain("Hello")
  assert_eq(t.spans(), [span(0, 3, "red"), span(3, 5, "green")])
}

///|
test "pad_left" {
  let t = text("foo")
  t.pad_left(3, character='X')
  inspect(t, content="XXXfoo")
}

///|
test "pad_right" {
  let t = text("foo")
  t.pad_right(3, character='X')
  inspect(t, content="fooXXX")
}

///|
test "append" {
  let t = text("foo")
  t.append("bar") |> ignore
  inspect(t, content="foobar")
  t.append(text("baz", style="bold")) |> ignore
  inspect(t, content="foobarbaz")
  assert_eq(t.spans(), [span(6, 9, "bold")])
  try t.append(text("foo"), style="bar") catch {
    ValueError(msg) =>
      inspect(msg, content="style must not be set when appending Text instance")
    e => fail("unexpected \{e}")
  } noraise {
    _ => fail("expected ValueError")
  }
}

///|
test "append_text" {
  let t = text("foo")
  t.append_text(text("bar", style="bold")) |> ignore
  inspect(t, content="foobar")
  assert_eq(t.spans(), [span(3, 6, "bold")])
}

///|
test "end" {
  let file = @rich.StringIO::new()
  let console = test_console(width=20, file~)
  let t = @rich.Group::new([
    @rich.Text::from_markup("foo", end=" "),
    @rich.Text::from_markup("bar"),
  ])
  console.print(t)
  assert_eq(file.getvalue(), "foo bar\n")
}

///|
test "split" {
  let t = text("")
  t.append("foo", style="red") |> ignore
  t.append("\n") |> ignore
  t.append("bar", style="green") |> ignore
  t.append("\n") |> ignore
  let line1 = text("")
  line1.append("foo", style="red") |> ignore
  let line2 = text("")
  line2.append("bar", style="green") |> ignore
  let split = t.split(separator="\n")
  inspect(split.length(), content="2")
  assert_eq(split.get(0), line1)
  assert_eq(split.get(1), line2)
  assert_eq(text("foo").split(separator="\n").lines, [text("foo")])
}

///|
test "split_spans" {
  let t = @rich.Text::from_markup("[red]Hello\n[b]World")
  let lines = t.split(separator="\n")
  assert_eq(lines.get(0).plain(), "Hello")
  assert_eq(lines.get(1).plain(), "World")
  assert_eq(lines.get(0).spans(), [span(0, 5, "red")])
  assert_eq(lines.get(1).spans(), [span(0, 5, "red"), span(0, 5, "bold")])
}

///|
test "divide" {
  let lines = text("foo").divide([])
  inspect(lines.length(), content="1")
  assert_eq(lines.get(0), text("foo"))
  let t = text("")
  t.append("foo", style="bold") |> ignore
  let lines = t.divide([1, 2])
  inspect(lines.length(), content="3")
  inspect(lines.get(0), content="f")
  inspect(lines.get(1), content="o")
  inspect(lines.get(2), content="o")
  assert_eq(lines.get(0).spans(), [span(0, 1, "bold")])
  assert_eq(lines.get(1).spans(), [span(0, 1, "bold")])
  assert_eq(lines.get(2).spans(), [span(0, 1, "bold")])
  let t = text("")
  t.append("foo", style="red") |> ignore
  t.append("bar", style="green") |> ignore
  t.append("baz", style="blue") |> ignore
  let lines = t.divide([8])
  inspect(lines.length(), content="2")
  inspect(lines.get(0), content="foobarba")
  inspect(lines.get(1), content="z")
  assert_eq(lines.get(0).spans(), [
    span(0, 3, "red"),
    span(3, 6, "green"),
    span(6, 8, "blue"),
  ])
  assert_eq(lines.get(1).spans(), [span(0, 1, "blue")])
  let lines = t.divide([1])
  inspect(lines.length(), content="2")
  inspect(lines.get(0), content="f")
  inspect(lines.get(1), content="oobarbaz")
  assert_eq(lines.get(0).spans(), [span(0, 1, "red")])
  assert_eq(lines.get(1).spans(), [
    span(0, 2, "red"),
    span(2, 5, "green"),
    span(5, 8, "blue"),
  ])
}

///|
test "right_crop" {
  let t = text("")
  t.append("foobar", style="red") |> ignore
  t.right_crop(amount=3)
  inspect(t, content="foo")
  assert_eq(t.spans(), [span(0, 3, "red")])
}

///|
test "wrap_3" {
  let lines = text("foo bar baz").wrap(test_console(), 3)
  inspect(lines.length(), content="3")
  assert_eq(lines.lines, [text("foo"), text("bar"), text("baz")])
}

///|
test "wrap_4" {
  let t = @rich.Text::new(text="foo bar baz", justify=Left)
  let lines = t.wrap(test_console(), 4)
  inspect(lines.length(), content="3")
  assert_eq(lines.lines, [text("foo "), text("bar "), text("baz ")])
}

///|
test "wrap_wrapped_word_length_greater_than_available_width" {
  let lines = text("1234 12345678").wrap(test_console(), 7)
  assert_eq(lines.lines, [text("1234 "), text("1234567"), text("8")])
}

///|
test "wrap_cjk" {
  let lines = text("わさび").wrap(test_console(), 4)
  assert_eq(lines.lines, [text("わさ"), text("び")])
}

///|
test "wrap_cjk_width_mid_character" {
  let lines = text("わさび").wrap(test_console(), 3)
  assert_eq(lines.lines, [text("わ"), text("さ"), text("び")])
}

///|
test "wrap_cjk_mixed" {
  let t = text("123ありがとうございました")
  let console = test_console(width=20)
  let wrapped_lines = t.wrap(console, 8)
  let output = console.capture(() => console.print(wrapped_lines))
  assert_eq(output, "123あり\nがとうご\nざいまし\nた\n")
}

///|
test "wrap_long" {
  let t = @rich.Text::new(text="abracadabra", justify=Left)
  let lines = t.wrap(test_console(), 4)
  inspect(lines.length(), content="3")
  assert_eq(lines.lines, [text("abra"), text("cada"), text("bra ")])
}

///|
test "wrap_long_multi_codepoint" {
  let female_mechanic = "👩\u{200d}🔧"
  let t = @rich.Text::new(text=female_mechanic.repeat(5), justify=Left)
  let lines = t.wrap(test_console(), 4)
  inspect(lines.length(), content="3")
  assert_eq(lines.lines, [
    text(female_mechanic.repeat(2)),
    text(female_mechanic.repeat(2)),
    text(female_mechanic + "  "),
  ])
}

///|
test "wrap_overflow" {
  let lines = text("Some more words").wrap(test_console(), 4, overflow=Ellipsis)
  inspect(lines.length(), content="3")
  assert_eq(lines.lines, [text("Some"), text("more"), text("wor…")])
}

///|
test "wrap_overflow_long" {
  let lines = text("bigword".repeat(10)).wrap(
    test_console(),
    4,
    overflow=Ellipsis,
  )
  inspect(lines.length(), content="1")
  assert_eq(lines.get(0), text("big…"))
}

///|
test "wrap_long_words" {
  let lines = text("XX 12345678912").wrap(test_console(), 4)
  assert_eq(lines.lines, [text("XX "), text("1234"), text("5678"), text("912")])
}

///|
test "wrap_long_words_2" {
  let lines = text("Hello, World...123").wrap(test_console(), 10)
  assert_eq(lines.lines, [text("Hello, "), text("World...12"), text("3")])
}

///|
test "wrap_long_words_followed_by_other_words" {
  let lines = text("123 12345678 123 123").wrap(test_console(), 6)
  assert_eq(lines.lines, [
    text("123 "),
    text("123456"),
    text("78 123"),
    text("123"),
  ])
}

///|
test "wrap_long_word_preceeded_by_word_of_full_line_length" {
  let lines = text("123456 12345678 123 123").wrap(test_console(), 6)
  assert_eq(lines.lines, [
    text("123456"),
    text("123456"),
    text("78 123"),
    text("123"),
  ])
}

///|
test "wrap_multiple_consecutive_spaces" {
  let lines = text("123456    12345678 123 123").wrap(test_console(), 6)
  assert_eq(lines.lines, [
    text("123456"),
    text("123456"),
    text("78 123"),
    text("123"),
  ])
}

///|
test "wrap_multi_codepoint" {
  let female_mechanic = "👩\u{200d}🔧"
  let t = text(female_mechanic.repeat(6) + " " + female_mechanic.repeat(4))
  let lines = t.wrap(test_console(), 12)
  assert_eq(lines.lines, [
    text(female_mechanic.repeat(6)),
    text(female_mechanic.repeat(4)),
  ])
}

///|
test "wrap_long_words_justify_left" {
  let t = @rich.Text::new(text="X 123456789", justify=Left)
  let lines = t.wrap(test_console(), 4)
  inspect(lines.length(), content="4")
  assert_eq(lines.lines, [
    text("X   "),
    text("1234"),
    text("5678"),
    text("9   "),
  ])
}

///|
test "wrap_leading_and_trailing_whitespace" {
  let lines = text("   123  456 789   ").wrap(test_console(), 4)
  assert_eq(lines.lines, [
    text("   1"),
    text("23  "),
    text("456 "),
    text("789 "),
  ])
}

///|
test "no_wrap_no_crop" {
  let t = text("Hello World!".repeat(3))
  let file = @rich.StringIO::new()
  let console = test_console(width=20, file~)
  console.print(t, no_wrap=true)
  console.print(t, no_wrap=true, crop=false, overflow=Ignore)
  assert_eq(
    file.getvalue(),
    "Hello World!Hello Wo\nHello World!Hello World!Hello World!\n",
  )
}

///|
test "fit" {
  let lines = text("Hello\nWorld").fit(3)
  inspect(lines.get(0), content="Hel")
  inspect(lines.get(1), content="Wor")
}

///|
test "wrap_tabs" {
  let t = @rich.Text::new(text="foo\tbar", justify=Left)
  let lines = t.wrap(test_console(), 4)
  inspect(lines.length(), content="2")
  assert_eq(lines.get(0).plain(), "foo ")
  assert_eq(lines.get(1).plain(), "bar ")
}

///|
test "render" {
  let console = test_console(width=15, record=true)
  let t = @rich.Text::from_markup(
    "[u][b]Where[/b] there is a [i]Will[/i], there is a Way.[/u]",
  )
  console.print(t)
  let output = console.export_text(styles=true)
  assert_eq(
    output, "\u{1b}[1;4mWhere\u{1b}[0m\u{1b}[4m there is \u{1b}[0m\n\u{1b}[4ma \u{1b}[0m\u{1b}[3;4mWill\u{1b}[0m\u{1b}[4m, there \u{1b}[0m\n\u{1b}[4mis a Way.\u{1b}[0m\n",
  )
}

///|
test "render_simple" {
  let console = test_console(width=80)
  console.begin_capture()
  console.print(text("foo"))
  let result = console.end_capture()
  assert_eq(result, "foo\n")
}

///|
test "print" {
  let cases : Array[(Array[&@rich.Renderable], String)] = [
    (["."], ".\n"),
    ([".", "."], ". .\n"),
    (["Hello", "World", "!"], "Hello World !\n"),
  ]
  for case in cases {
    let (print_text, result) = case
    let console = test_console(record=true)
    console.print_many(print_text)
    assert_eq(console.export_text(styles=false), result)
  }
}

///|
test "print_sep_end" {
  let cases : Array[(Array[&@rich.Renderable], String)] = [
    (["."], ".X"),
    ([".", "."], "..X"),
    (["Hello", "World", "!"], "HelloWorld!X"),
  ]
  for case in cases {
    let (print_text, result) = case
    let file = @rich.StringIO::new()
    let console = test_console(record=true, file~)
    console.print_many(print_text, sep="", end="X")
    assert_eq(file.getvalue(), result)
  }
}

///|
test "tabs_to_spaces" {
  let t = @rich.Text::new(text="\tHello\tWorld", tab_size=8)
  t.expand_tabs()
  assert_eq(t.plain(), "        Hello   World")
  let t = @rich.Text::new(text="\tHello\tWorld", tab_size=4)
  t.expand_tabs()
  assert_eq(t.plain(), "    Hello   World")
  let t = @rich.Text::new(text=".\t..\t...\t....\t", tab_size=4)
  t.expand_tabs()
  assert_eq(t.plain(), ".   ..  ... ....    ")
  let t = text("No Tabs")
  t.expand_tabs()
  assert_eq(t.plain(), "No Tabs")
  let t = text("No Tabs", style="bold")
  t.expand_tabs()
  assert_eq(t.plain(), "No Tabs")
  assert_eq(t.style, Def("bold"))
}

///|
test "tabs_to_spaces_spans" {
  let cases : Array[(String, Int, String, Array[@rich.Span])] = [
    ("", 4, "", []),
    ("\t", 4, "    ", []),
    ("\tbar", 4, "    bar", []),
    ("foo\tbar", 4, "foo bar", []),
    ("foo\nbar\nbaz", 4, "foo\nbar\nbaz", []),
    ("[bold]foo\tbar", 4, "foo bar", [span(0, 4, "bold"), span(4, 7, "bold")]),
    ("[bold]\tbar", 4, "    bar", [span(0, 4, "bold"), span(4, 7, "bold")]),
    ("\t[bold]bar", 4, "    bar", [span(4, 7, "bold")]),
    (
      "[red]foo\tbar\n[green]egg\tbaz",
      8,
      "foo     bar\negg     baz",
      [
        span(0, 8, "red"),
        span(8, 12, "red"),
        span(12, 20, "red"),
        span(12, 20, "green"),
        span(20, 23, "red"),
        span(20, 23, "green"),
      ],
    ),
    ("[bold]X\tY", 8, "X       Y", [span(0, 8, "bold"), span(8, 9, "bold")]),
    // upstream (code points): Span(0, 7), Span(7, 8)
    (
      "[bold]💩\t💩",
      8,
      "💩      💩",
      [span(0, 8, "bold"), span(8, 10, "bold")],
    ),
    // upstream (code points): Span(0, 12), Span(12, 13)
    (
      "[bold]💩💩💩💩\t💩",
      8,
      "💩💩💩💩        💩",
      [span(0, 16, "bold"), span(16, 18, "bold")],
    ),
  ]
  for case in cases {
    let (markup, tab_size, expected_text, expected_spans) = case
    let t = @rich.Text::from_markup(markup)
    t.expand_tabs(tab_size~)
    assert_eq(t.plain(), expected_text)
    assert_eq(t.spans(), expected_spans)
  }
}

///|
test "markup_switch" {
  let file = @rich.StringIO::new()
  let console = test_console(file~, markup=false)
  console.print("[bold]foo[/bold]")
  assert_eq(file.getvalue(), "[bold]foo[/bold]\n")
}

///|
test "emoji" {
  let file = @rich.StringIO::new()
  let console = test_console(file~)
  console.print(":+1:")
  assert_eq(file.getvalue(), "👍\n")
}

///|
test "emoji_switch" {
  let file = @rich.StringIO::new()
  let console = test_console(file~, emoji=false)
  console.print(":+1:")
  assert_eq(file.getvalue(), ":+1:\n")
}

///|
test "assemble" {
  let t = @rich.Text::assemble(["foo", ("bar", "bold")])
  inspect(t, content="foobar")
  assert_eq(t.spans(), [span(3, 6, "bold")])
}

///|
test "assemble_meta" {
  let t = @rich.Text::assemble(["foo", ("bar", "bold")], meta={ "foo": "bar" })
  inspect(t, content="foobar")
  assert_eq(t.spans(), [
    span(3, 6, "bold"),
    span(0, 6, @rich.Style::new(meta={ "foo": "bar" })),
  ])
  let console = test_console()
  assert_eq(t.get_style_at_offset(console, 0).meta(), { "foo": "bar" })
}

///|
test "styled" {
  let t = @rich.Text::styled("foo", style="bold red")
  assert_eq(t.style, Def(""))
  inspect(t, content="foo")
  assert_eq(t.spans(), [span(0, 3, "bold red")])
}

///|
test "strip_control_codes" {
  let t = text("foo\rbar")
  inspect(t, content="foobar")
  t.append("\u{08}") |> ignore
  inspect(t, content="foobar")
}

///|
test "get_style_at_offset" {
  let console = test_console()
  let t = @rich.Text::from_markup("Hello [b]World[/b]")
  assert_true(t.get_style_at_offset(console, 0) == @rich.Style::new())
  assert_true(t.get_style_at_offset(console, 6) == @rich.Style::new(bold=true))
}

///|
test "truncate_ellipsis" {
  let cases = [
    ("Hello", 10, "Hello"),
    ("Hello", 5, "Hello"),
    ("Hello", 4, "Hel…"),
    ("Hello", 3, "He…"),
    ("Hello", 2, "H…"),
    ("Hello", 1, "…"),
  ]
  for case in cases {
    let (input, count, expected) = case
    let t = text(input)
    t.truncate(count, overflow=Ellipsis)
    assert_eq(t.plain(), expected)
  }
}

///|
test "truncate_ellipsis_pad" {
  let cases = [
    ("Hello", 5, "Hello"),
    ("Hello", 10, "Hello     "),
    ("Hello", 3, "He…"),
  ]
  for case in cases {
    let (input, count, expected) = case
    let t = text(input)
    t.truncate(count, overflow=Ellipsis, pad=true)
    assert_eq(t.plain(), expected)
  }
}

///|
test "pad" {
  let t = text("foo")
  t.pad(2)
  assert_eq(t.plain(), "  foo  ")
}

///|
test "align_left" {
  let t = text("foo")
  t.align(Left, 10)
  assert_eq(t.plain(), "foo       ")
}

///|
test "align_right" {
  let t = text("foo")
  t.align(Right, 10)
  assert_eq(t.plain(), "       foo")
}

///|
test "align_center" {
  let t = text("foo")
  t.align(Center, 10)
  assert_eq(t.plain(), "   foo    ")
}

///|
test "detect_indentation" {
  let t = "foo\n    bar\n    "
  inspect(text(t).detect_indentation(), content="4")
  let t = "foo\n    bar\n      baz\n    "
  inspect(text(t).detect_indentation(), content="2")
  inspect(text("").detect_indentation(), content="1")
  inspect(text(" ").detect_indentation(), content="1")
}

///|
test "indentation_guides" {
  let t = text(
    (
      #|for a in range(10):
      #|    print(a)
      #|
      #|foo = [
      #|    1,
      #|    {
      #|        2
      #|    }
      #|]
      #|
      #|
    ),
  )
  let result = t.with_indent_guides()
  assert_eq(
    result.plain(),
    "for a in range(10):\n│   print(a)\n\nfoo = [\n│   1,\n│   {\n│   │   2\n│   }\n]\n\n",
  )
}

///|
test "slice" {
  let t = @rich.Text::from_markup("[red]foo [bold]bar[/red] baz[/bold]")
  assert_eq(t.at(0), @rich.Text::new(text="f", spans=[span(0, 1, "red")]))
  assert_eq(
    t.at(4),
    @rich.Text::new(text="b", spans=[span(0, 1, "red"), span(0, 1, "bold")]),
  )
  assert_eq(
    t.slice(stop=3),
    @rich.Text::new(text="foo", spans=[span(0, 3, "red")]),
  )
  assert_eq(
    t.slice(stop=4),
    @rich.Text::new(text="foo ", spans=[span(0, 4, "red")]),
  )
  assert_eq(
    t.slice(stop=5),
    @rich.Text::new(text="foo b", spans=[span(0, 5, "red"), span(4, 5, "bold")]),
  )
  assert_eq(
    t.slice(start=4),
    @rich.Text::new(text="bar baz", spans=[
      span(0, 3, "red"),
      span(0, 7, "bold"),
    ]),
  )
}

///|
test "wrap_invalid_style" {
  // https://github.com/textualize/rich/issues/987
  let console = test_console(width=100, color_system=Some("truecolor"))
  let a = "[#######.................] " +
    "x".repeat(118) +
    " [#######.................]"
  console.print(a, justify=Full)
}

///|
test "apply_meta" {
  let t = text("foobar")
  t.apply_meta({ "foo": "bar" }, start=1, end=3)
  let console = test_console()
  assert_eq(t.get_style_at_offset(console, 0).meta(), {})
  assert_eq(t.get_style_at_offset(console, 1).meta(), { "foo": "bar" })
  assert_eq(t.get_style_at_offset(console, 2).meta(), { "foo": "bar" })
  assert_eq(t.get_style_at_offset(console, 3).meta(), {})
}

///|
test "on" {
  let console = test_console()
  let t = text("foo")
  t.on(meta={ "foo": "bar" }, handlers={ "click": "CLICK" }) |> ignore
  let expected : Map[String, Json] = { "foo": "bar", "@click": "CLICK" }
  assert_eq(t.get_style_at_offset(console, 0).meta(), expected)
  assert_eq(t.get_style_at_offset(console, 1).meta(), expected)
  assert_eq(t.get_style_at_offset(console, 2).meta(), expected)
}

///|
test "markup_property" {
  inspect(text("").markup(), content="")
  inspect(text("foo").markup(), content="foo")
  inspect(text("foo", style="bold").markup(), content="[bold]foo[/bold]")
  inspect(
    @rich.Text::from_markup("foo [red]bar[/red]").markup(),
    content="foo [red]bar[/red]",
  )
  inspect(
    @rich.Text::from_markup("foo [red]bar[/red]", style="bold").markup(),
    content="[bold]foo [red]bar[/red][/bold]",
  )
  inspect(
    @rich.Text::from_markup("[bold]foo [italic]bar[/bold] baz[/italic]").markup(),
    content="[bold]foo [italic]bar[/bold] baz[/italic]",
  )
  inspect(text("[bold]foo").markup(), content="\\[bold]foo")
}

///|
test "extend_style" {
  let t = @rich.Text::from_markup("[red]foo[/red] [bold]bar")
  t.extend_style(0)
  assert_eq(t.plain(), "foo bar")
  assert_eq(t.spans(), [span(0, 3, "red"), span(4, 7, "bold")])
  t.extend_style(-1)
  assert_eq(t.plain(), "foo bar")
  assert_eq(t.spans(), [span(0, 3, "red"), span(4, 7, "bold")])
  t.extend_style(2)
  assert_eq(t.plain(), "foo bar  ")
  assert_eq(t.spans(), [span(0, 3, "red"), span(4, 9, "bold")])
}

///|
test "append_tokens" {
  let console = test_console()
  let t = text("").append_tokens([
    (
      "long text that will be wrapped with a control code \r\n",
      Some(Def("red")),
    ),
  ])
  let output = console.capture(() => console.print(t, width=40))
  assert_eq(output, "long text that will be wrapped with a \ncontrol code \n\n")
}

///|
test "append_loop_regression" {
  let a = text("one", style="blue")
  a.append(a) |> ignore
  assert_eq(a.plain(), "oneone")
  let b = text("two", style="blue")
  b.append_text(b) |> ignore
  assert_eq(b.plain(), "twotwo")
}

///|
test "soft_wrap" {
  let console = test_console(
    color_system=Some("standard"),
    width=80,
    force_terminal=true,
  )
  let t = text(" Hello World ", style="white on blue")
  let output = console.capture(() => console.print(t, soft_wrap=true))
  assert_eq(output, "\u{1b}[37;44m Hello World \u{1b}[0m\n")
}

///|
test "soft_wrap_styled" {
  let console = test_console(
    color_system=Some("standard"),
    width=80,
    force_terminal=true,
  )
  let output = console.capture(() => {
    console.print("soft wrap is on", style="blue on white", soft_wrap=true)
    console.print("Next line")
  })
  assert_eq(output, "\u{1b}[34;47msoft wrap is on\u{1b}[0m\nNext line\n")
}

// Regression tests (expected values from the Python oracle).

///|
test "append empty text" {
  let t = text("a")
  t.append_text(text("", style="bold")) |> ignore
  assert_eq(t.spans(), [span(1, 1, "bold")])
  let t = text("a")
  // upstream only checks `style` when the appended Text is not empty
  t.append(text("", style="bold"), style="x") |> ignore
  assert_eq(t.spans(), [])
  assert_eq((text("a") + text("", style="bold")).spans(), [])
}

///|
test "align and pad with negative counts" {
  let t = @rich.Text::new(text="abc", overflow=Ignore)
  t.stylize("red", start=0, end=2)
  t.align(Right, 1)
  inspect(t.repr(), content="<text 'abc' [Span(-2, 0, 'red')] ''>")
  let t = text("abc")
  t.stylize("red", start=0, end=2)
  t.pad_left(-1)
  inspect(t.repr(), content="<text 'abc' [Span(-1, 1, 'red')] ''>")
}

///|
test "pad with astral character" {
  // upstream (code points): Span(2, 4, 'red')
  let t = text("abc")
  t.stylize("red", start=0, end=2)
  t.pad_left(2, character='😀')
  assert_eq(t.plain(), "😀😀abc")
  assert_eq(t.spans(), [span(4, 6, "red")])
  let t = text("abc")
  t.stylize("red", start=0, end=2)
  t.pad(2, character='😀')
  assert_eq(t.plain(), "😀😀abc😀😀")
  assert_eq(t.spans(), [span(4, 6, "red")])
}

///|
test "indent guides with other characters" {
  // upstream (code points): Span(0, 2, 'dim green')
  let t = text("  abc").with_indent_guides(indent_size=2, character="😀")
  assert_eq(t.plain(), "😀 abc")
  assert_eq(t.spans(), [span(0, 3, "dim green")])
  let t = text("    abc\n  x").with_indent_guides(indent_size=2, character="->")
  assert_eq(t.plain(), "-> -> c\n-> ")
  assert_eq(t.spans(), [span(0, 6, "dim green"), span(8, 11, "dim green")])
}
