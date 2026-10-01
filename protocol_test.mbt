// Port of tests/test_protocol.py.
//
// `__rich__` is not supported: a type becomes renderable by implementing
// `Renderable`, here by delegating to the renderable that upstream's
// `__rich__` would return. `test_rich_cast_fake` (repr of an arbitrary
// object), `test_abc` (isinstance checks) and `test_cast_recursive` (an
// infinite `__rich__` chain) have no MoonBit equivalent.

///|
struct Foo {}

///|
impl @rich.Renderable for Foo with fn rich_console(_self, _console, _options) {
  [Child(@rich.Text::new(text="Foo"))]
}

///|
impl @rich.Renderable for Foo with fn rich_measure(_self, console, options) {
  Some(@rich.Measurement::get(console, options, @rich.Text::new(text="Foo")))
}

///|
test "test_rich_cast" {
  let foo = Foo::{ }
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(file~, width=80, environ={})
  console.print(foo)
  assert_eq(file.getvalue(), "Foo\n")
}

///|
test "test_rich_cast_container" {
  let foo = Foo::{ }
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(file~, width=80, legacy_windows=false, environ={})
  console.print(@panel.Panel::fit(foo, padding=[0]))
  assert_eq(file.getvalue(), "╭───╮\n│Foo│\n╰───╯\n")
}

///|
struct B {}

///|
impl @rich.Renderable for B with fn rich_console(_self, _console, _options) {
  [Child(Foo::{ })]
}

///|
struct A {}

///|
impl @rich.Renderable for A with fn rich_console(_self, _console, _options) {
  [Child(B::{ })]
}

///|
test "test_cast_deep" {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(file~, width=80, environ={})
  console.print(A::{ })
  assert_eq(file.getvalue(), "Foo\n")
}
