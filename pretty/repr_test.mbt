// Port of tests/test_repr.py. `@rich.repr.auto` classes become types whose
// `PrettyRepr` implementation lists the `__rich_repr__` items, and whose
// plain repr comes from `@pretty.repr_string`.

///|
/// `Foo.__rich_repr__`: `yield self.foo; yield None, self.foo;
/// yield "bar", self.bar, None; yield "egg", self.egg`.
struct ReprFoo {
  foo : String
  bar : Int?
  egg : Int
}

///|
fn ReprFoo::new(foo : String, bar? : Int, egg? : Int = 1) -> ReprFoo {
  { foo, bar, egg, }
}

///|
fn ReprFoo::args(self : ReprFoo) -> Array[@pretty.ReprArg] {
  [
    @pretty.arg(self.foo),
    @pretty.arg(self.foo),
    @pretty.kwarg_default("bar", self.bar, None),
    @pretty.kwarg("egg", self.egg),
  ]
}

///|
fn ReprFoo::repr(self : ReprFoo) -> String {
  @pretty.repr_string("Foo", self.args())
}

///|
impl @pretty.PrettyRepr for ReprFoo with fn pretty_node(self, ctx) {
  ctx.rich_repr("Foo", self.args())
}

///|
/// `Bar(Foo)` with an angular `__rich_repr__`.
struct ReprBar {
  foo : ReprFoo
}

///|
fn ReprBar::repr(self : ReprBar) -> String {
  @pretty.repr_string("Bar", self.foo.args(), angular=true)
}

///|
impl @pretty.PrettyRepr for ReprBar with fn pretty_node(self, ctx) {
  ctx.rich_repr("Bar", self.foo.args(), angular=true)
}

///|
test "rich_repr" {
  assert_eq(ReprFoo::new("hello").repr(), "Foo('hello', 'hello', egg=1)")
  assert_eq(
    ReprFoo::new("hello", bar=3).repr(),
    "Foo('hello', 'hello', bar=3, egg=1)",
  )
}

///|
test "rich_repr_positional_only" {
  assert_eq(@pretty.repr_string("PosOnly", [@pretty.arg(1)]), "PosOnly(1)")
}

///|
test "rich_angular" {
  assert_eq(
    ReprBar::{ foo: ReprFoo::new("hello"), }.repr(),
    "<Bar 'hello' 'hello' egg=1>",
  )
  assert_eq(
    ReprBar::{ foo: ReprFoo::new("hello", bar=3), }.repr(),
    "<Bar 'hello' 'hello' bar=3 egg=1>",
  )
}

///|
test "rich_repr_auto" {
  // `Egg(foo, bar=None, egg=1)` as `rich.repr.auto` derives it from the
  // signature of `__init__`.
  let egg = @pretty.repr_string("Egg", [
    @pretty.arg("hello"),
    @pretty.kwarg_default("bar", (None : Int?), None),
    @pretty.kwarg_default("egg", 2, 1),
  ])
  assert_eq(egg, "Egg('hello', egg=2)")
  let bird = @pretty.repr_string("Bird", [
    @pretty.arg("penguin"),
    @pretty.arg(["fish"]),
    @pretty.kwarg_default("fly", true, true),
    @pretty.kwarg("another", @pretty.Leaf::new("<StupidClass>")),
  ])
  assert_eq(bird, "Bird('penguin', ['fish'], another=<StupidClass>)")
}

///|
test "rich_repr_auto_angular" {
  assert_eq(
    @pretty.repr_string(
      "AngularEgg",
      [
        @pretty.arg("hello"),
        @pretty.kwarg_default("bar", (None : Int?), None),
        @pretty.kwarg_default("egg", 2, 1),
      ],
      angular=true,
    ),
    "<AngularEgg 'hello' egg=2>",
  )
}

///|
fn capture_print(value : &@rich.Renderable) -> String raise {
  let console = @rich.Console::new(
    file=@rich.StringIO::new(),
    width=80,
    color_system=None,
    environ={},
  )
  console.capture(() => console.print(value))
}

///|
test "rich_pretty" {
  assert_eq(
    capture_print(@pretty.Pretty::new(ReprFoo::new("hello", bar=3))),
    "Foo('hello', 'hello', bar=3, egg=1)\n",
  )
}

///|
test "rich_pretty_angular" {
  assert_eq(
    capture_print(
      @pretty.Pretty::new(ReprBar::{ foo: ReprFoo::new("hello", bar=3), }),
    ),
    "<Bar 'hello' 'hello' bar=3 egg=1>\n",
  )
}

///|
test "repr __main__ demo" {
  // The `__main__` demo of rich/repr.py, rendered by the Python oracle.
  let args = [
    @pretty.arg("foo"),
    @pretty.kwarg("bar", { "shopping": ["eggs", "ham", "pineapple"] }),
    @pretty.kwarg("buy", "hand sanitizer"),
  ]
  let ctx = @pretty.PrettyContext::new()
  let node = ctx.rich_repr("Foo", args)
  assert_eq(
    node.render(max_width=80),
    "Foo('foo', bar={'shopping': ['eggs', 'ham', 'pineapple']}, buy='hand sanitizer')",
  )
  assert_eq(
    node.render(max_width=60),
    "Foo(\n    'foo',\n    bar={'shopping': ['eggs', 'ham', 'pineapple']},\n    buy='hand sanitizer'\n)",
  )
  assert_eq(
    node.render(max_width=30),
    "Foo(\n    'foo',\n    bar={\n        'shopping': [\n            'eggs',\n            'ham',\n            'pineapple'\n        ]\n    },\n    buy='hand sanitizer'\n)",
  )
  let node = ctx.rich_repr("Foo", args, angular=true)
  assert_eq(
    node.render(max_width=80),
    "<Foo 'foo' bar={'shopping': ['eggs', 'ham', 'pineapple']} buy='hand sanitizer'>",
  )
  assert_eq(
    node.render(max_width=60),
    "<Foo \n    'foo'\n    bar={'shopping': ['eggs', 'ham', 'pineapple']}\n    buy='hand sanitizer'\n>",
  )
}
