// Port of tests/test_tree.py.

///|
fn capture(
  tree : @tree.Tree,
  width? : Int = 20,
  color_system? : String?,
  force_terminal? : Bool,
  legacy_windows? : Bool = false,
  file? : &@rich.ConsoleFile,
) -> String raise {
  let console = @rich.Console::new(
    color_system?,
    force_terminal?,
    width~,
    legacy_windows~,
    file?,
    environ={},
  )
  console.begin_capture()
  console.print(tree)
  console.end_capture()
}

///|
test "render single node" {
  let tree = @tree.Tree::new("foo")
  assert_eq(capture(tree, color_system=None), "foo\n")
}

///|
test "render single branch" {
  let tree = @tree.Tree::new("foo")
  ignore(tree.add("bar"))
  assert_eq(capture(tree, color_system=None), "foo\n└── bar\n")
}

///|
test "render double branch" {
  let tree = @tree.Tree::new("foo")
  ignore(tree.add("bar"))
  ignore(tree.add("baz"))
  assert_eq(
    capture(tree, color_system=None),
    "foo\n├── bar\n└── baz\n",
  )
}

///|
/// A console file reporting an ASCII encoding (upstream subclasses
/// `Console` to override `encoding`).
struct AsciiFile {
  io : @rich.StringIO
}

///|
impl @rich.ConsoleFile for AsciiFile with fn write(self, s) {
  self.io.write(s)
}

///|
impl @rich.ConsoleFile for AsciiFile with fn encoding(_self) {
  "ascii"
}

///|
test "render ascii" {
  let tree = @tree.Tree::new("foo")
  ignore(tree.add("bar"))
  ignore(tree.add("baz"))
  let file : AsciiFile = { io: @rich.StringIO::new(), }
  assert_eq(capture(tree, color_system=None, file~), "foo\n+-- bar\n`-- baz\n")
}

///|
fn styled_tree(hide_root? : Bool = false) -> @tree.Tree {
  let tree = @tree.Tree::new("foo", hide_root~)
  ignore(tree.add("bar", style="italic"))
  let baz_tree = tree.add("baz", guide_style="bold red", style="on blue")
  ignore(baz_tree.add("1"))
  ignore(baz_tree.add("2"))
  ignore(tree.add("egg"))
  tree
}

///|
test "render tree non win32" {
  assert_eq(
    capture(styled_tree(), force_terminal=true, color_system=Some("standard")),
    "foo\n├── \u{1b}[3mbar\u{1b}[0m\n\u{1b}[44m├── \u{1b}[0m\u{1b}[44mbaz\u{1b}[0m\n\u{1b}[44m│   \u{1b}[0m\u{1b}[31;44m┣━━ \u{1b}[0m\u{1b}[44m1\u{1b}[0m\n\u{1b}[44m│   \u{1b}[0m\u{1b}[31;44m┗━━ \u{1b}[0m\u{1b}[44m2\u{1b}[0m\n└── egg\n",
  )
}

///|
test "render tree win32" {
  assert_eq(
    capture(
      styled_tree(),
      force_terminal=true,
      color_system=Some("standard"),
      legacy_windows=true,
    ),
    "foo\n├── \u{1b}[3mbar\u{1b}[0m\n\u{1b}[44m├── \u{1b}[0m\u{1b}[44mbaz\u{1b}[0m\n\u{1b}[44m│   \u{1b}[0m\u{1b}[31;44m├── \u{1b}[0m\u{1b}[44m1\u{1b}[0m\n\u{1b}[44m│   \u{1b}[0m\u{1b}[31;44m└── \u{1b}[0m\u{1b}[44m2\u{1b}[0m\n└── egg\n",
  )
}

///|
test "render tree hide root non win32" {
  assert_eq(
    capture(
      styled_tree(hide_root=true),
      force_terminal=true,
      color_system=Some("standard"),
    ),
    "\u{1b}[3mbar\u{1b}[0m\n\u{1b}[44mbaz\u{1b}[0m\n\u{1b}[31;44m┣━━ \u{1b}[0m\u{1b}[44m1\u{1b}[0m\n\u{1b}[31;44m┗━━ \u{1b}[0m\u{1b}[44m2\u{1b}[0m\negg\n",
  )
}

///|
test "render tree hide root win32" {
  assert_eq(
    capture(
      styled_tree(hide_root=true),
      force_terminal=true,
      color_system=Some("standard"),
      legacy_windows=true,
    ),
    "\u{1b}[3mbar\u{1b}[0m\n\u{1b}[44mbaz\u{1b}[0m\n\u{1b}[31;44m├── \u{1b}[0m\u{1b}[44m1\u{1b}[0m\n\u{1b}[31;44m└── \u{1b}[0m\u{1b}[44m2\u{1b}[0m\negg\n",
  )
}

///|
test "tree measure" {
  let tree = @tree.Tree::new("foo")
  ignore(tree.add("bar"))
  ignore(tree.add("mushroom risotto"))
  let console = @rich.Console::new(environ={})
  let measurement = @rich.Measurement::get(console, console.options(), tree)
  assert_eq(measurement, @rich.Measurement::new(12, 20))
}
