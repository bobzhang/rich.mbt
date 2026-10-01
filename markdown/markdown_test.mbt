// Port of tests/test_markdown.py.

///|
let markdown_source : String = "Heading\n=======\n\nSub-heading\n-----------\n\n### Heading\n\n#### H4 Heading\n\n##### H5 Heading\n\n###### H6 Heading\n\n\nParagraphs are separated\nby a blank line.\n\nTwo spaces at the end of a line\nproduces a line break.\n\nText attributes _italic_,\n**bold**, `monospace`.\n\nHorizontal rule:\n\n---\n\nBullet list:\n\n  * apples\n  * oranges\n  * pears\n\nNumbered list:\n\n  1. lather\n  2. rinse\n  3. repeat\n\nAn [example](http://example.com).\n\n> Markdown uses email-style > characters for blockquoting.\n>\n> Lorem ipsum\n\n![progress](https://github.com/textualize/rich/raw/master/imgs/progress.gif)\n\n\n```\na=1\n```\n\n```python\nimport this\n```\n\n```somelang\nfoobar\n```\n\n    import this\n\n\n1. List item\n\n       Code block\n"

///|
/// Link IDs have a random ID and system path which is a problem for
/// reproducible tests (upstream `replace_link_ids`).
fn replace_link_ids(render : String) -> String {
  let re = @regex.compile("id=[\\d\\.\\-]*?;.*?\u{1b}") catch {
    _ => return render
  }
  re.replace_all(render, _ => "id=0;foo\u{1b}") catch {
    _ => render
  }
}

///|
fn render(renderable : &@rich.Renderable) -> String raise {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    width=100,
    file~,
    color_system=Some("truecolor"),
    legacy_windows=false,
    environ={},
  )
  console.print(renderable)
  replace_link_ids(file.getvalue())
}

///|
test "test_markdown_render" {
  let markdown = @markdown.Markdown::new(markdown_source)
  let rendered_markdown = render(markdown)
  let expected = "                                              \u{1b}[1;4mHeading\u{1b}[0m                                               \n\n\u{1b}[4;35mSub-heading\u{1b}[0m                                                                                         \n\n\u{1b}[1;35mHeading\u{1b}[0m                                                                                             \n\n\u{1b}[3;35mH4 Heading\u{1b}[0m                                                                                          \n\n\u{1b}[3mH5 Heading\u{1b}[0m                                                                                          \n\n\u{1b}[2mH6 Heading\u{1b}[0m                                                                                          \n\nParagraphs are separated by a blank line.                                                           \n\nTwo spaces at the end of a line produces a line break.                                              \n\nText attributes \u{1b}[3mitalic\u{1b}[0m, \u{1b}[1mbold\u{1b}[0m, \u{1b}[1;36;40mmonospace\u{1b}[0m.                                                            \n\nHorizontal rule:                                                                                    \n\n\u{1b}[2m----------------------------------------------------------------------------------------------------\u{1b}[0m\n\nBullet list:                                                                                        \n\n\u{1b}[1m • \u{1b}[0mapples                                                                                           \n\u{1b}[1m • \u{1b}[0moranges                                                                                          \n\u{1b}[1m • \u{1b}[0mpears                                                                                            \n\nNumbered list:                                                                                      \n\n\u{1b}[36m 1 \u{1b}[0mlather                                                                                           \n\u{1b}[36m 2 \u{1b}[0mrinse                                                                                            \n\u{1b}[36m 3 \u{1b}[0mrepeat                                                                                           \n\nAn \u{1b}]8;id=0;foo\u{1b}\\\u{1b}[4;34mexample\u{1b}[0m\u{1b}]8;;\u{1b}\\.                                                                                         \n\n\u{1b}[35m▌ \u{1b}[0m\u{1b}[35mMarkdown uses email-style > characters for blockquoting.\u{1b}[0m\u{1b}[35m                                        \u{1b}[0m\n\u{1b}[35m▌ \u{1b}[0m\u{1b}[35mLorem ipsum\u{1b}[0m\u{1b}[35m                                                                                     \u{1b}[0m\n\n🌆 \u{1b}]8;id=0;foo\u{1b}\\progress\u{1b}]8;;\u{1b}\\                                                                                         \n\n\u{1b}[48;2;39;40;34m                                                                                                    \u{1b}[0m\n\u{1b}[48;2;39;40;34m \u{1b}[0m\u{1b}[38;2;248;248;242;48;2;39;40;34ma=1\u{1b}[0m\u{1b}[48;2;39;40;34m                                                                                               \u{1b}[0m\u{1b}[48;2;39;40;34m \u{1b}[0m\n\u{1b}[48;2;39;40;34m                                                                                                    \u{1b}[0m\n\n\u{1b}[48;2;39;40;34m                                                                                                    \u{1b}[0m\n\u{1b}[48;2;39;40;34m \u{1b}[0m\u{1b}[38;2;255;70;137;48;2;39;40;34mimport\u{1b}[0m\u{1b}[38;2;248;248;242;48;2;39;40;34m \u{1b}[0m\u{1b}[38;2;248;248;242;48;2;39;40;34mthis\u{1b}[0m\u{1b}[48;2;39;40;34m                                                                                       \u{1b}[0m\u{1b}[48;2;39;40;34m \u{1b}[0m\n\u{1b}[48;2;39;40;34m                                                                                                    \u{1b}[0m\n\n\u{1b}[48;2;39;40;34m                                                                                                    \u{1b}[0m\n\u{1b}[48;2;39;40;34m \u{1b}[0m\u{1b}[38;2;248;248;242;48;2;39;40;34mfoobar\u{1b}[0m\u{1b}[48;2;39;40;34m                                                                                            \u{1b}[0m\u{1b}[48;2;39;40;34m \u{1b}[0m\n\u{1b}[48;2;39;40;34m                                                                                                    \u{1b}[0m\n\n\u{1b}[48;2;39;40;34m                                                                                                    \u{1b}[0m\n\u{1b}[48;2;39;40;34m \u{1b}[0m\u{1b}[38;2;248;248;242;48;2;39;40;34mimport this\u{1b}[0m\u{1b}[48;2;39;40;34m                                                                                       \u{1b}[0m\u{1b}[48;2;39;40;34m \u{1b}[0m\n\u{1b}[48;2;39;40;34m                                                                                                    \u{1b}[0m\n\n\u{1b}[36m 1 \u{1b}[0mList item                                                                                        \n\u{1b}[36m   \u{1b}[0m\u{1b}[48;2;39;40;34m                                                                                                 \u{1b}[0m\n\u{1b}[36m   \u{1b}[0m\u{1b}[48;2;39;40;34m \u{1b}[0m\u{1b}[38;2;248;248;242;48;2;39;40;34mCode block\u{1b}[0m\u{1b}[48;2;39;40;34m                                                                                     \u{1b}[0m\u{1b}[48;2;39;40;34m \u{1b}[0m\n\u{1b}[36m   \u{1b}[0m\u{1b}[48;2;39;40;34m                                                                                                 \u{1b}[0m\n"
  assert_eq(rendered_markdown, expected)
}

///|
test "test_inline_code" {
  let markdown = @markdown.Markdown::new(
    "inline `import this` code",
    inline_code_lexer="python",
    inline_code_theme="emacs",
  )
  let result = render(markdown)
  let expected = "inline \u{1b}[1;38;2;170;34;255;48;2;248;248;248mimport\u{1b}[0m\u{1b}[38;2;187;187;187;48;2;248;248;248m \u{1b}[0m\u{1b}[1;38;2;0;0;255;48;2;248;248;248mthis\u{1b}[0m code                                                                             \n"
  assert_eq(result, expected)
}

///|
test "test_markdown_table" {
  let markdown = @markdown.Markdown::new(
    "| Year |                      Title                       | Director          |  Box Office (USD) |\n|------|:------------------------------------------------:|:------------------|------------------:|\n| 1982 |            *E.T. the Extra-Terrestrial*          | Steven Spielberg  |    $792.9 million |\n| 1980 |  Star Wars: Episode V – The Empire Strikes Back  | Irvin Kershner    |    $538.4 million |\n| 1983 |    Star Wars: Episode VI – Return of the Jedi    | Richard Marquand  |    $475.1 million |\n| 1981 |             Raiders of the Lost Ark              | Steven Spielberg  |    $389.9 million |\n| 1984 |       Indiana Jones and the Temple of Doom       | Steven Spielberg  |    $333.1 million |\n",
  )
  let result = render(markdown)
  let expected = "\n\u{1b}[36m                                                                                          \u{1b}[0m\n\u{1b}[36m \u{1b}[0m\u{1b}[36mYear\u{1b}[0m\u{1b}[1m \u{1b}[0m\u{1b}[36m \u{1b}[0m\u{1b}[1m                    \u{1b}[0m\u{1b}[36mTitle\u{1b}[0m\u{1b}[1m                     \u{1b}[0m\u{1b}[1m \u{1b}[0m\u{1b}[36m \u{1b}[0m\u{1b}[36mDirector\u{1b}[0m\u{1b}[1m        \u{1b}[0m\u{1b}[1m \u{1b}[0m\u{1b}[36m \u{1b}[0m\u{1b}[36mBox Office (USD)\u{1b}[0m\u{1b}[36m \u{1b}[0m\n\u{1b}[36m ──────────────────────────────────────────────────────────────────────────────────────── \u{1b}[0m\n\u{1b}[36m \u{1b}[0m1982 \u{1b}[36m \u{1b}[0m          \u{1b}[3mE.T. the Extra-Terrestrial\u{1b}[0m           \u{1b}[36m \u{1b}[0mSteven Spielberg \u{1b}[36m \u{1b}[0m  $792.9 million\u{1b}[36m \u{1b}[0m\n\u{1b}[36m \u{1b}[0m1980 \u{1b}[36m \u{1b}[0mStar Wars: Episode V – The Empire Strikes Back \u{1b}[36m \u{1b}[0mIrvin Kershner   \u{1b}[36m \u{1b}[0m  $538.4 million\u{1b}[36m \u{1b}[0m\n\u{1b}[36m \u{1b}[0m1983 \u{1b}[36m \u{1b}[0m  Star Wars: Episode VI – Return of the Jedi   \u{1b}[36m \u{1b}[0mRichard Marquand \u{1b}[36m \u{1b}[0m  $475.1 million\u{1b}[36m \u{1b}[0m\n\u{1b}[36m \u{1b}[0m1981 \u{1b}[36m \u{1b}[0m           Raiders of the Lost Ark             \u{1b}[36m \u{1b}[0mSteven Spielberg \u{1b}[36m \u{1b}[0m  $389.9 million\u{1b}[36m \u{1b}[0m\n\u{1b}[36m \u{1b}[0m1984 \u{1b}[36m \u{1b}[0m     Indiana Jones and the Temple of Doom      \u{1b}[36m \u{1b}[0mSteven Spielberg \u{1b}[36m \u{1b}[0m  $333.1 million\u{1b}[36m \u{1b}[0m\n\u{1b}[36m                                                                                          \u{1b}[0m\n"
  assert_eq(result, expected)
}

///|
/// Regression test for https://github.com/Textualize/rich/issues/3115
test "test_inline_styles_in_table" {
  let markdown = @markdown.Markdown::new(
    "| Year | This **column** displays _the_ movie _title_ ~~description~~ | Director          |  Box Office (USD) |\n|------|:----------------------------------------------------------:|:------------------|------------------:|\n| 1982 | *E.T. the Extra-Terrestrial* ([Wikipedia article](https://en.wikipedia.org/wiki/E.T._the_Extra-Terrestrial)) | Steven Spielberg  |    $792.9 million |\n| 1980 |  Star Wars: Episode V – The *Empire* **Strikes** ~~Back~~  | Irvin Kershner    |    $538.4 million |\n",
  )
  let result = render(markdown)
  let expected = "\n\u{1b}[36m                                                                                            \u{1b}[0m\n\u{1b}[36m \u{1b}[0m\u{1b}[36mYear\u{1b}[0m\u{1b}[1m \u{1b}[0m\u{1b}[36m \u{1b}[0m\u{1b}[36mThis \u{1b}[0m\u{1b}[36mcolumn\u{1b}[0m\u{1b}[36m displays \u{1b}[0m\u{1b}[3;36mthe\u{1b}[0m\u{1b}[36m movie \u{1b}[0m\u{1b}[3;36mtitle\u{1b}[0m\u{1b}[36m \u{1b}[0m\u{1b}[9;36mdescription\u{1b}[0m\u{1b}[1m \u{1b}[0m\u{1b}[36m \u{1b}[0m\u{1b}[36mDirector\u{1b}[0m\u{1b}[1m        \u{1b}[0m\u{1b}[1m \u{1b}[0m\u{1b}[36m \u{1b}[0m\u{1b}[36mBox Office (USD)\u{1b}[0m\u{1b}[36m \u{1b}[0m\n\u{1b}[36m ────────────────────────────────────────────────────────────────────────────────────────── \u{1b}[0m\n\u{1b}[36m \u{1b}[0m1982 \u{1b}[36m \u{1b}[0m \u{1b}[3mE.T. the Extra-Terrestrial\u{1b}[0m (\u{1b}]8;id=0;foo\u{1b}\\\u{1b}[4;34mWikipedia article\u{1b}[0m\u{1b}]8;;\u{1b}\\)  \u{1b}[36m \u{1b}[0mSteven Spielberg \u{1b}[36m \u{1b}[0m  $792.9 million\u{1b}[36m \u{1b}[0m\n\u{1b}[36m \u{1b}[0m1980 \u{1b}[36m \u{1b}[0m Star Wars: Episode V – The \u{1b}[3mEmpire\u{1b}[0m \u{1b}[1mStrikes\u{1b}[0m \u{1b}[9mBack\u{1b}[0m  \u{1b}[36m \u{1b}[0mIrvin Kershner   \u{1b}[36m \u{1b}[0m  $538.4 million\u{1b}[36m \u{1b}[0m\n\u{1b}[36m                                                                                            \u{1b}[0m\n"
  assert_eq(result, expected)
}

///|
/// Regression test for https://github.com/Textualize/rich/issues/3115
test "test_inline_styles_with_justification" {
  let markdown = @markdown.Markdown::new(
    "| left | center | right |\n| :- | :-: | -: |\n| This is a long row | because it contains | a fairly long sentence. |\n| a*b* _c_ ~~d~~ e | a*b* _c_ ~~d~~ e | a*b* _c_ ~~d~~ e |",
  )
  let result = render(markdown)
  let expected = "\n\u{1b}[36m                                                                  \u{1b}[0m\n\u{1b}[36m \u{1b}[0m\u{1b}[36mleft\u{1b}[0m\u{1b}[1m              \u{1b}[0m\u{1b}[1m \u{1b}[0m\u{1b}[36m \u{1b}[0m\u{1b}[1m      \u{1b}[0m\u{1b}[36mcenter\u{1b}[0m\u{1b}[1m       \u{1b}[0m\u{1b}[1m \u{1b}[0m\u{1b}[36m \u{1b}[0m\u{1b}[1m                  \u{1b}[0m\u{1b}[36mright\u{1b}[0m\u{1b}[36m \u{1b}[0m\n\u{1b}[36m ──────────────────────────────────────────────────────────────── \u{1b}[0m\n\u{1b}[36m \u{1b}[0mThis is a long row \u{1b}[36m \u{1b}[0mbecause it contains \u{1b}[36m \u{1b}[0ma fairly long sentence.\u{1b}[36m \u{1b}[0m\n\u{1b}[36m \u{1b}[0ma\u{1b}[3mb\u{1b}[0m \u{1b}[3mc\u{1b}[0m \u{1b}[9md\u{1b}[0m e           \u{1b}[36m \u{1b}[0m     a\u{1b}[3mb\u{1b}[0m \u{1b}[3mc\u{1b}[0m \u{1b}[9md\u{1b}[0m e       \u{1b}[36m \u{1b}[0m               a\u{1b}[3mb\u{1b}[0m \u{1b}[3mc\u{1b}[0m \u{1b}[9md\u{1b}[0m e\u{1b}[36m \u{1b}[0m\n\u{1b}[36m                                                                  \u{1b}[0m\n"
  assert_eq(result, expected)
}

///|
test "test_partial_table" {
  let markdown = @markdown.Markdown::new(
    "| Simple | Table |\n| ------ | ----- ",
  )
  let result = render(markdown)
  let expected = "\n\u{1b}[36m               \u{1b}[0m\n\u{1b}[36m \u{1b}[0m\u{1b}[36mSimple\u{1b}[0m\u{1b}[1m \u{1b}[0m\u{1b}[36m \u{1b}[0m\u{1b}[36mTable\u{1b}[0m\u{1b}[36m \u{1b}[0m\n\u{1b}[36m ───────────── \u{1b}[0m\n\u{1b}[36m               \u{1b}[0m\n"
  assert_eq(result, expected)
}

///|
/// A table with empty cells is rendered without extra newlines above.
/// Regression test for #3027 https://github.com/Textualize/rich/issues/3027
test "test_table_with_empty_cells" {
  let complete_table = @markdown.Markdown::new(
    "| First Header  | Second Header |\n| ------------- | ------------- |\n| Content Cell  | Content Cell  |\n| Content Cell  | Content Cell  |\n",
  )
  let table_with_empty_cells = @markdown.Markdown::new(
    "| First Header  |               |\n| ------------- | ------------- |\n| Content Cell  | Content Cell  |\n|               | Content Cell  |\n",
  )
  let result = render(table_with_empty_cells).split("\n").count()
  let expected = render(complete_table).split("\n").count()
  assert_eq(result, expected)
}

///|
/// Inline code in table cells.
/// Regression test for https://github.com/Textualize/rich/issues/4038
///
/// The upstream expectation predates Pygments lexing `print` as a builtin
/// (`Name.Builtin`, green in monokai); upstream's own test fails with the
/// Pygments of the oracle environment, so `print` is green here.
test "test_inline_code_in_table_cells" {
  let markdown = @markdown.Markdown::new(
    "| Col |\n|---|\n| `print('hello');` |\n",
    inline_code_theme="monokai",
    inline_code_lexer="python",
  )
  let result = render(markdown)
  let expected = "\n\u{1b}[36m                 \u{1b}[0m\n\u{1b}[36m \u{1b}[0m\u{1b}[36mCol\u{1b}[0m\u{1b}[1m            \u{1b}[0m\u{1b}[36m \u{1b}[0m\n\u{1b}[36m ─────────────── \u{1b}[0m\n\u{1b}[36m \u{1b}[0m\u{1b}[38;2;166;226;46;48;2;39;40;34mprint\u{1b}[0m\u{1b}[38;2;248;248;242;48;2;39;40;34m(\u{1b}[0m\u{1b}[38;2;230;219;116;48;2;39;40;34m'\u{1b}[0m\u{1b}[38;2;230;219;116;48;2;39;40;34mhello\u{1b}[0m\u{1b}[38;2;230;219;116;48;2;39;40;34m'\u{1b}[0m\u{1b}[38;2;248;248;242;48;2;39;40;34m)\u{1b}[0m\u{1b}[38;2;248;248;242;48;2;39;40;34m;\u{1b}[0m\u{1b}[36m \u{1b}[0m\n\u{1b}[36m                 \u{1b}[0m\n"
  assert_eq(result, expected)
}
