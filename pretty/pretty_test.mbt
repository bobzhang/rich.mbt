// Port of tests/test_pretty.py. Python objects are modelled with
// `PrettyRepr` implementations producing the same repr trees.

///|
fn plain_console(width? : Int = 80) -> @rich.Console raise {
  @rich.Console::new(
    file=@rich.StringIO::new(),
    width~,
    color_system=None,
    legacy_windows=false,
    environ={},
  )
}

///|
let none : Int? = None

///|
fn set_of(items : Array[Int]) -> @set.Set[Int] {
  @set.Set::from_array(items)
}

///|
test "pretty" {
  let test_value = @pretty.Dict::new([
    (
      "foo",
      (
        [
          1,
          2,
          3,
          @pretty.Tuple::new([4, 5, set_of([6]), 7, 8, set_of([9])]),
          @pretty.Dict::new([]),
        ] : Array[&@pretty.PrettyRepr]),
    ),
    (
      "bar",
      @pretty.Dict::new([
        ("egg", "baz"),
        ("words", Array::make(10, "Hello World")),
      ]),
    ),
    (false, "foo"),
    (true, ""),
    ("text", ("Hello World", "foo bar baz egg")),
  ])
  let result = @pretty.pretty_repr(test_value, max_width=80)
  let expected = "{\n    'foo': [1, 2, 3, (4, 5, {6}, 7, 8, {9}), {}],\n    'bar': {\n        'egg': 'baz',\n        'words': [\n            'Hello World',\n            'Hello World',\n            'Hello World',\n            'Hello World',\n            'Hello World',\n            'Hello World',\n            'Hello World',\n            'Hello World',\n            'Hello World',\n            'Hello World'\n        ]\n    },\n    False: 'foo',\n    True: '',\n    'text': ('Hello World', 'foo bar baz egg')\n}"
  assert_eq(result, expected)
}

///|
/// `@dataclass class ExampleDataclass` (with `ignore` and `last` declared
/// `repr=False`).
struct ExampleDataclass {
  foo : Int
  mut bar : &@pretty.PrettyRepr
  ignore : Int
  baz : Array[String]
  last : Int
  id : @pretty.PrettyId
}

///|
impl @pretty.PrettyRepr for ExampleDataclass with fn pretty_node(self, ctx) {
  ctx.dataclass(
    "ExampleDataclass",
    [("foo", self.foo), ("bar", self.bar), ("baz", self.baz)],
    id=self.id,
  )
}

///|
struct Empty {}

///|
impl @pretty.PrettyRepr for Empty with fn pretty_node(_self, ctx) {
  ctx.dataclass("Empty", [])
}

///|
test "pretty_dataclass" {
  let dc = ExampleDataclass::{
    foo: 1000,
    bar: "Hello, World",
    ignore: 999,
    baz: ["foo", "bar", "baz"],
    last: 1,
    id: @pretty.PrettyId::new(),
  }
  assert_eq(dc.ignore + dc.last, 1000)
  assert_eq(
    @pretty.pretty_repr(dc, max_width=80),
    "ExampleDataclass(foo=1000, bar='Hello, World', baz=['foo', 'bar', 'baz'])",
  )
  assert_eq(
    @pretty.pretty_repr(dc, max_width=16),
    "ExampleDataclass(\n    foo=1000,\n    bar='Hello, World',\n    baz=[\n        'foo',\n        'bar',\n        'baz'\n    ]\n)",
  )
  dc.bar = dc
  assert_eq(
    @pretty.pretty_repr(dc, max_width=80),
    "ExampleDataclass(foo=1000, bar=..., baz=['foo', 'bar', 'baz'])",
  )
}

///|
test "empty_dataclass" {
  assert_eq(@pretty.pretty_repr(Empty::{ }), "Empty()")
  assert_eq(@pretty.pretty_repr([Empty::{ }]), "[Empty()]")
}

///|
/// `class StockKeepingUnit(NamedTuple)`.
struct StockKeepingUnit {
  name : String
  description : String
  price : Double
  category : String
  reviews : Array[String]
}

///|
impl @pretty.PrettyRepr for StockKeepingUnit with fn pretty_node(self, ctx) {
  ctx.namedtuple("StockKeepingUnit", [
    ("name", self.name),
    ("description", self.description),
    ("price", self.price),
    ("category", self.category),
    ("reviews", self.reviews),
  ])
}

///|
test "pretty_namedtuple" {
  let example_namedtuple = StockKeepingUnit::{
    name: "Sparkling British Spring Water",
    description: "Carbonated spring water",
    price: 0.9,
    category: "water",
    reviews: ["its amazing!", "its terrible!"],
  }
  assert_eq(
    @pretty.pretty_repr(example_namedtuple),
    (
      #|StockKeepingUnit(
      #|    name='Sparkling British Spring Water',
      #|    description='Carbonated spring water',
      #|    price=0.9,
      #|    category='water',
      #|    reviews=['its amazing!', 'its terrible!']
      #|)
    ),
  )
}

///|
struct Thing {
  name : String
}

///|
impl @pretty.PrettyRepr for Thing with fn pretty_node(self, ctx) {
  ctx.namedtuple("Thing", [("name", self.name)])
}

///|
test "pretty_namedtuple_length_one_no_trailing_comma" {
  assert_eq(@pretty.pretty_repr(Thing::{ name: "Bob", }), "Thing(name='Bob')")
}

///|
test "pretty_namedtuple_empty" {
  let ctx = @pretty.PrettyContext::new()
  assert_eq(ctx.namedtuple("Thing", []).render(), "Thing()")
}

///|
test "pretty_namedtuple_max_depth" {
  let instance = {
    "unit": StockKeepingUnit::{
      name: "a",
      description: "b",
      price: 1.0,
      category: "c",
      reviews: ["d", "e"],
    },
  }
  assert_eq(
    @pretty.pretty_repr(instance, max_depth=1),
    "{'unit': StockKeepingUnit(...)}",
  )
}

///|
test "small_width" {
  let test_value = ["Hello world! 12345"]
  assert_eq(
    @pretty.pretty_repr(test_value, max_width=10),
    "[\n    'Hello world! 12345'\n]",
  )
}

///|
test "ansi_in_pretty_repr" {
  let pretty = @pretty.Pretty::new(
    @pretty.Leaf::new("Hello \u{1b}[38;5;239mWorld!"),
  )
  let console = @rich.Console::new(
    file=@rich.StringIO::new(),
    record=true,
    width=80,
    environ={},
  )
  console.print(pretty)
  assert_eq(console.export_text(), "Hello World!\n")
}

///|
/// A list that may contain itself (Python lists have an identity).
struct PyList {
  items : Array[&@pretty.PrettyRepr]
  id : @pretty.PrettyId
}

///|
fn PyList::new(items : Array[&@pretty.PrettyRepr]) -> PyList {
  { items, id: @pretty.PrettyId::new(), }
}

///|
impl @pretty.PrettyRepr for PyList with fn pretty_node(self, ctx) {
  ctx.sequence(self.items, id=self.id)
}

///|
test "reference_cycle_container" {
  let test_value = PyList::new([])
  test_value.items.push(test_value)
  assert_eq(@pretty.pretty_repr(test_value), "[...]")
  let inner = PyList::new([])
  let test_value = PyList::new([1, inner])
  inner.items.push(test_value)
  assert_eq(@pretty.pretty_repr(test_value), "[1, [...]]")
  // Not a cyclic reference, just a repeated reference
  let a = PyList::new([2])
  let test_value = PyList::new([1, PyList::new([a, a])])
  assert_eq(@pretty.pretty_repr(test_value), "[1, [[2], [2]]]")
}

///|
struct Example {
  x : Int
  mut y : &@pretty.PrettyRepr
  id : @pretty.PrettyId
}

///|
fn Example::new(x : Int, y : &@pretty.PrettyRepr) -> Example {
  { x, y, id: @pretty.PrettyId::new(), }
}

///|
/// The same object as a namedtuple, dataclass, attrs class or
/// `__rich_repr__` class.
struct ExampleAs {
  kind : String
  example : Example
}

///|
impl @pretty.PrettyRepr for ExampleAs with fn pretty_node(self, ctx) {
  let e = self.example
  let y = e.y
  match self.kind {
    "namedtuple" => ctx.namedtuple("Example", [("x", e.x), ("y", y)], id=e.id)
    "dataclass" => ctx.dataclass("Example", [("x", e.x), ("y", y)], id=e.id)
    _ =>
      ctx.rich_repr(
        "Example",
        [@pretty.kwarg("x", e.x), @pretty.kwarg("y", y)],
        id=e.id,
      )
  }
}

///|
fn cycle_cases(kind : String) -> Array[String] {
  fn wrap(e : Example) -> ExampleAs {
    { kind, example: e, }
  }

  let results = []
  // Example(1, [Example(2, [])]) with a cycle through the list
  let inner_list = PyList::new([])
  let test_value = Example::new(1, inner_list)
  inner_list.items.push(wrap(Example::new(2, PyList::new([wrap(test_value)]))))
  results.push(@pretty.pretty_repr(wrap(test_value)))
  // test.y = test
  let test_value = Example::new(1, none)
  test_value.y = wrap(test_value)
  results.push(@pretty.pretty_repr(wrap(test_value)))
  // test = Example(1, Example(2, None)); test.y.y = test
  let inner = Example::new(2, none)
  let test_value = Example::new(1, wrap(inner))
  inner.y = wrap(test_value)
  results.push(@pretty.pretty_repr(wrap(test_value)))
  // Not a cyclic reference, just a repeated reference
  let a = wrap(Example::new(2, none))
  let test_value = Example::new(1, PyList::new([a, a]))
  results.push(@pretty.pretty_repr(wrap(test_value)))
  results
}

///|
test "reference_cycle_namedtuple" {
  let results = cycle_cases("namedtuple")
  assert_eq(results[0], "Example(x=1, y=[Example(x=2, y=[...])])")
  assert_eq(
    results[3],
    "Example(x=1, y=[Example(x=2, y=None), Example(x=2, y=None)])",
  )
}

///|
test "reference_cycle_dataclass" {
  let results = cycle_cases("dataclass")
  assert_eq(results[1], "Example(x=1, y=...)")
  assert_eq(results[2], "Example(x=1, y=Example(x=2, y=...))")
  assert_eq(
    results[3],
    "Example(x=1, y=[Example(x=2, y=None), Example(x=2, y=None)])",
  )
}

///|
test "reference_cycle_attrs / custom_repr" {
  let results = cycle_cases("rich_repr")
  assert_eq(results[1], "Example(x=1, y=...)")
  assert_eq(results[2], "Example(x=1, y=Example(x=2, y=...))")
  assert_eq(
    results[3],
    "Example(x=1, y=[Example(x=2, y=None), Example(x=2, y=None)])",
  )
}

///|
test "max_depth" {
  let d : Map[String, &@pretty.PrettyRepr] = Map([])
  d["foo"] = {
    "fob": (
      {
        "a": [1, 2, 3],
        "b": (
          { "z": "x", "y": ["a", "b", "c"] } : Map[String, &@pretty.PrettyRepr]),
      } : Map[String, &@pretty.PrettyRepr]),
  }
  assert_eq(@pretty.pretty_repr(d, max_depth=0), "{...}")
  assert_eq(@pretty.pretty_repr(d, max_depth=1), "{'foo': {...}}")
  assert_eq(@pretty.pretty_repr(d, max_depth=2), "{'foo': {'fob': {...}}}")
  assert_eq(
    @pretty.pretty_repr(d, max_depth=3),
    "{'foo': {'fob': {'a': [...], 'b': {...}}}}",
  )
  assert_eq(
    @pretty.pretty_repr(d, max_width=100, max_depth=4),
    "{'foo': {'fob': {'a': [1, 2, 3], 'b': {'z': 'x', 'y': [...]}}}}",
  )
  assert_eq(
    @pretty.pretty_repr(d, max_width=100, max_depth=5),
    "{'foo': {'fob': {'a': [1, 2, 3], 'b': {'z': 'x', 'y': ['a', 'b', 'c']}}}}",
  )
  assert_eq(
    @pretty.pretty_repr(d, max_width=100),
    "{'foo': {'fob': {'a': [1, 2, 3], 'b': {'z': 'x', 'y': ['a', 'b', 'c']}}}}",
  )
}

///|
struct Foo {
  foo : &@pretty.PrettyRepr
}

///|
impl @pretty.PrettyRepr for Foo with fn pretty_node(self, ctx) {
  ctx.rich_repr("Foo", [@pretty.kwarg("foo", self.foo)])
}

///|
struct Bar {
  bar : &@pretty.PrettyRepr
}

///|
impl @pretty.PrettyRepr for Bar with fn pretty_node(self, ctx) {
  ctx.rich_repr("Bar", [@pretty.kwarg("bar", self.bar)])
}

///|
struct FooDC {
  foo : &@pretty.PrettyRepr
}

///|
impl @pretty.PrettyRepr for FooDC with fn pretty_node(self, ctx) {
  ctx.dataclass("Foo", [("foo", self.foo)])
}

///|
struct BarDC {
  bar : &@pretty.PrettyRepr
}

///|
impl @pretty.PrettyRepr for BarDC with fn pretty_node(self, ctx) {
  ctx.dataclass("Bar", [("bar", self.bar)])
}

///|
test "max_depth_rich_repr / attrs" {
  let empty : Array[Int] = []
  assert_eq(
    @pretty.pretty_repr(
      Foo::{ foo: Bar::{ bar: Foo::{ foo: empty, }, }, },
      max_depth=2,
    ),
    "Foo(foo=Bar(bar=Foo(...)))",
  )
}

///|
test "max_depth_dataclass" {
  let empty : Array[Int] = []
  assert_eq(
    @pretty.pretty_repr(
      FooDC::{ foo: BarDC::{ bar: FooDC::{ foo: empty, }, }, },
      max_depth=2,
    ),
    "Foo(foo=Bar(bar=Foo(...)))",
  )
}

///|
/// `defaultdict(int, ...)` modelled with the mapping helper.
struct DefaultDict {
  items : Array[(String, Int)]
}

///|
impl @pretty.PrettyRepr for DefaultDict with fn pretty_node(self, ctx) {
  ctx.mapping(
    self.items,
    open_brace="defaultdict(<class 'int'>, {",
    close_brace="})",
    empty="defaultdict(<class 'int'>, {})",
  )
}

///|
test "defaultdict" {
  assert_eq(
    @pretty.pretty_repr(DefaultDict::{ items: [("foo", 2)], }),
    "defaultdict(<class 'int'>, {'foo': 2})",
  )
}

///|
test "deque" {
  assert_eq(
    @pretty.pretty_repr(@deque.Deque::from_array([1, 2, 3])),
    "deque([1, 2, 3])",
  )
  let empty : @deque.Deque[Int] = @deque.Deque([])
  assert_eq(@pretty.pretty_repr(empty), "deque()")
}

///|
/// `array('I', ...)` modelled with the sequence helper.
struct UIntArray {
  items : Array[UInt]
}

///|
impl @pretty.PrettyRepr for UIntArray with fn pretty_node(self, ctx) {
  ctx.sequence(
    self.items,
    open_brace="array('I', [",
    close_brace="])",
    empty="array('I')",
  )
}

///|
test "array" {
  assert_eq(
    @pretty.pretty_repr(UIntArray::{ items: [1, 2, 3], }),
    "array('I', [1, 2, 3])",
  )
}

///|
test "tuple_of_one" {
  assert_eq(@pretty.pretty_repr(@pretty.Tuple::new([1])), "(1,)")
}

///|
test "node" {
  let node = @pretty.Node::new(key_repr="abc")
  assert_eq(@pretty.pretty_repr(node), "abc: ")
}

///|
test "indent_lines" {
  let console = plain_console(width=100)
  console.begin_capture()
  console.print(@pretty.Pretty::new([100, 200], indent_guides=true), width=8)
  assert_eq(
    console.end_capture(),
    (
      #|[
      #|│   100,
      #|│   200
      #|]
      #|
    ),
  )
}

///|
test "pprint" {
  let console = plain_console()
  console.begin_capture()
  @pretty.pprint(1, console~)
  assert_eq(console.end_capture(), "1\n")
}

///|
test "pprint_max_values" {
  let console = plain_console()
  console.begin_capture()
  @pretty.pprint([1, 2, 3, 4, 5, 6, 7, 8, 9, 0], console~, max_length=2)
  assert_eq(console.end_capture(), "[1, 2, ... +8]\n")
}

///|
test "pprint_max_items" {
  let console = plain_console()
  console.begin_capture()
  @pretty.pprint({ "foo": 1, "bar": 2, "egg": 3 }, console~, max_length=2)
  assert_eq(console.end_capture(), "{'foo': 1, 'bar': 2, ... +1}\n")
}

///|
test "pprint_max_string" {
  let console = plain_console()
  console.begin_capture()
  @pretty.pprint(["Hello".repeat(20)], console~, max_string=8)
  assert_eq(console.end_capture(), "['HelloHel'+92]\n")
}

///|
test "tuples" {
  let console = plain_console()
  console.begin_capture()
  @pretty.pprint(@pretty.Tuple::new([1]), console~)
  @pretty.pprint(@pretty.Tuple::new([1]), expand_all=true, console~)
  @pretty.pprint(
    @pretty.Tuple::new([@pretty.Tuple::new([1])]),
    expand_all=true,
    console~,
  )
  assert_eq(
    console.end_capture(),
    "(1,)\n(\n│   1,\n)\n(\n│   (\n│   │   1,\n│   ),\n)\n",
  )
}

///|
test "newline" {
  let console = plain_console()
  console.begin_capture()
  console.print(
    @pretty.Pretty::new(
      @pretty.Tuple::new([1]),
      insert_line=true,
      expand_all=true,
    ),
  )
  assert_eq(console.end_capture(), "\n(\n    1,\n)\n")
}

///|
test "empty_repr" {
  assert_eq(@pretty.pretty_repr(@pretty.Leaf::new("")), "")
}

///|
/// `@attr.define class Point` with `foo: str = attr.field(repr=str.upper)`.
struct Point {
  x : Int
  y : Int
  foo : String
  z : Int
}

///|
impl @pretty.PrettyRepr for Point with fn pretty_node(self, ctx) {
  ctx.rich_repr("Point", [
    @pretty.kwarg("x", self.x),
    @pretty.kwarg("y", self.y),
    @pretty.kwarg("foo", @pretty.Leaf::new(self.foo.to_upper())),
    @pretty.kwarg("z", self.z),
  ])
}

///|
test "attrs" {
  assert_eq(
    @pretty.pretty_repr(Point::{ x: 1, y: 2, foo: "bar", z: 0, }),
    "Point(x=1, y=2, foo=BAR, z=0)",
  )
}

///|
test "attrs_empty" {
  let ctx = @pretty.PrettyContext::new()
  assert_eq(ctx.rich_repr("Nada", []).render(), "Nada()")
}

///|
test "user_dict" {
  let d1 = { "foo": "bar" }
  assert_eq(@pretty.pretty_repr(d1, expand_all=true), "{\n    'foo': 'bar'\n}")
}

///|
test "measure_pretty" {
  let console = plain_console()
  let pretty = @pretty.Pretty::new(
    ["alpha", "beta", "delta", "gamma"],
    expand_all=true,
  )
  let measurement = console.measure(pretty)
  assert_eq(measurement.minimum, 12)
  assert_eq(measurement.maximum, 12)
}

///|
struct TupleRichRepr {
  default : Bool
}

///|
impl @pretty.PrettyRepr for TupleRichRepr with fn pretty_node(self, ctx) {
  if self.default {
    ctx.rich_repr("Foo", [@pretty.arg_default((1, 2), (1, 2))])
  } else {
    ctx.rich_repr("Foo", [@pretty.arg(@pretty.Tuple::new([1]))])
  }
}

///|
test "tuple_rich_repr" {
  assert_eq(
    @pretty.pretty_repr(TupleRichRepr::{ default: false, }),
    "Foo((1,))",
  )
}

///|
test "tuple_rich_repr_default" {
  assert_eq(@pretty.pretty_repr(TupleRichRepr::{ default: true, }), "Foo()")
}

///|
struct BadDataclass {}

///|
impl @pretty.PrettyRepr for BadDataclass with fn pretty_node(_self, ctx) {
  ctx.dataclass("BadDataclass", [])
}

///|
test "dataclass_no_attribute" {
  let console = plain_console()
  let result = console.capture(() => {
    console.print(@pretty.Pretty::new(BadDataclass::{ }))
  })
  assert_eq(result, "BadDataclass()\n")
}
