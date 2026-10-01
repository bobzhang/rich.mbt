// Port of tests/test_theme.py.

///|
fn warning_theme(style : String) -> @rich.Theme raise {
  @rich.Theme::new(styles={ "warning": style })
}

///|
test "inherit" {
  let theme = warning_theme("red")
  assert_true(theme.styles["warning"] == @rich.Style::new(color=color("red")))
  assert_true(theme.styles["dim"] == @rich.Style::new(dim=true))
  let theme = @rich.Theme::new(
    styles={ "warning": "red" },
    inherit_styles=false,
  )
  inspect(theme.styles.length(), content="1")
}

///|
test "config" {
  let theme = warning_theme("red")
  let config = theme.config()
  assert_true(config.contains("warning = red\n"))
  assert_true(config.has_prefix("[styles]\n"))
}

///|
test "from_file" {
  // upstream reads from an open file; `from_config` takes its contents
  let theme = warning_theme("red")
  let load_theme = @rich.Theme::from_config(theme.config())
  assert_eq(theme.styles.length(), load_theme.styles.length())
  for name, style in theme.styles {
    assert_true(load_theme.styles[name] == style)
  }
}

///|
test "from_config configparser syntax" {
  let theme = @rich.Theme::from_config(
    (
      #|# a comment
      #|[other]
      #|warning = blue
      #|[styles]
      #|; another comment
      #|Warning = bold red
      #|info: italic
      #|multi = bold
      #|  underline
    ),
    inherit_styles=false,
  )
  assert_eq(theme.styles.length(), 3)
  assert_true(theme.styles["warning"] == @rich.Style::parse("bold red"))
  assert_true(theme.styles["info"] == @rich.Style::parse("italic"))
  assert_true(theme.styles["multi"] == @rich.Style::parse("bold underline"))
}

///|
test "from_config oracle cases" {
  fn load(config : String) -> String {
    try @rich.Theme::from_config(config, inherit_styles=false) catch {
      e => "error: \{e}"
    } noraise {
      theme => {
        let items = []
        for name, style in theme.styles {
          items.push("\{name}=\{style}")
        }
        items.join(", ")
      }
    }
  }

  inspect(
    load("warning = red\n"),
    content=(
      #|error: File contains no section headers.
      #|file: '<???>', line: 1
      #|'warning = red\n'
    ),
  )
  inspect(
    load("[styles]\nwarning = red\nwarning = blue\n"),
    content="error: While reading from '<???>' [line  3]: option 'warning' in section 'styles' already exists",
  )
  inspect(
    load("[styles]\nwarning = red\n[styles]\ninfo = blue\n"),
    content="error: While reading from '<???>' [line  3]: section 'styles' already exists",
  )
  inspect(load("[other]\nx = 1\n"), content="error: No section: 'styles'")
  inspect(
    load("[styles]\nfoo\n"),
    content=(
      #|error: Source contains parsing errors: '<???>'
      #|	[line  2]: 'foo\n'
    ),
  )
  inspect(
    load("[styles]\nlink = link https://x.com/%%20\n"),
    content="link=link https://x.com/%20",
  )
  inspect(
    load("[styles]\nlink = 50%\n"),
    content="error: '%' must be followed by '%' or '(', found: '%'",
  )
  inspect(
    load("[styles]\nbase = bold\nderived = %(base)s red\n"),
    content="base=bold, derived=bold red",
  )
  inspect(
    load("[DEFAULT]\nshared = italic\n[styles]\nwarning = red\n"),
    content="shared=italic, warning=red",
  )
  inspect(load("[styles] trailing\nwarning = red\n"), content="warning=red")
  inspect(load("[styles]\n  indented = red\n"), content="indented=red")
  inspect(load("[styles]\nmulti = bold\n\n  red\n"), content="multi=bold red")
  inspect(
    load("[styles]\nk=v=w\n"),
    content="error: unable to parse 'v=w' as color; 'v=w' is not a valid color",
  )
}

///|
test "theme_stack" {
  let theme = warning_theme("red")
  let stack = @rich.ThemeStack::new(theme)
  assert_true(stack.get("warning") == Some(@rich.Style::parse("red")))
  let new_theme = warning_theme("bold yellow")
  stack.push_theme(new_theme)
  assert_true(stack.get("warning") == Some(@rich.Style::parse("bold yellow")))
  stack.pop_theme()
  assert_true(stack.get("warning") == Some(@rich.Style::parse("red")))
  try stack.pop_theme() catch {
    StyleStackError(msg) => inspect(msg, content="Unable to pop base theme")
    e => fail("unexpected \{e}")
  } noraise {
    _ => fail("expected ThemeStackError")
  }
}
