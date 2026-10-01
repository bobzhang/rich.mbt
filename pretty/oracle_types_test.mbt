// Values for oracle_test.mbt, mirroring the Python values in
// scripts/pretty_oracle.py.

///|
fn render_pretty(
  value : &@pretty.PrettyRepr,
  width~ : Int,
  indent_guides~ : Bool,
) -> String raise {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    file~,
    width~,
    color_system=Some("truecolor"),
    force_terminal=true,
    legacy_windows=false,
    environ={},
  )
  console.print(@pretty.Pretty::new(value, indent_guides~))
  file.getvalue()
}

///|
fn rpc_value() -> Map[String, &@pretty.PrettyRepr] {
  {
    "version": "1.1",
    "method": "confirmFruitPurchase",
    "params": (
      [["apple", "orange", "mangoes", "pomelo"], 1.123] :
      Array[&@pretty.PrettyRepr]),
    "id": "194521489",
  }
}

///|
struct Address {
  street : String
  city : String
  zip : String
}

///|
impl @pretty.PrettyRepr for Address with fn pretty_node(self, ctx) {
  // `zip` is declared with `repr=False`
  ignore(self.zip)
  ctx.dataclass("Address", [("street", self.street), ("city", self.city)])
}

///|
struct Person {
  name : String
  age : Int
  tags : Array[String]
  address : Address
  friends : Array[Person]
}

///|
impl @pretty.PrettyRepr for Person with fn pretty_node(self, ctx) {
  ctx.dataclass("Person", [
    ("name", self.name),
    ("age", self.age),
    ("tags", self.tags),
    ("address", self.address),
    ("friends", self.friends),
  ])
}

///|
fn person_value() -> Person {
  let alice = Person::{
    name: "Alice",
    age: 30,
    tags: ["admin", "user"],
    address: Address::{
      street: "1 Main Street",
      city: "Springfield",
      zip: "12345",
    },
    friends: [],
  }
  Person::{
    name: "Bob",
    age: 25,
    tags: [],
    address: Address::{ street: "2 Side Road", city: "Shelbyville", zip: "", },
    friends: [alice],
  }
}

///|
fn tuples_value() -> @pretty.Tuple {
  @pretty.Tuple::new([
    (1, 2),
    @pretty.Tuple::new([3]),
    @pretty.Tuple::new([]),
    ("a", ("b", @pretty.Tuple::new(["c"]))),
  ])
}

///|
fn bytes_value() -> Array[Bytes] {
  [b"hello", b"it's", b"\x00\xff\n", b"say \"hi\"", b"both '\"", b"\\"]
}

///|
fn mixed_keys_value() -> @pretty.Dict {
  @pretty.Dict::new([
    (1, "a"),
    (2, ["b", "c"]),
    ((1, 2), "tuple key"),
    ("long key ".repeat(3), { "nested": true }),
  ])
}

///|
fn deep_value() -> Array[&@pretty.PrettyRepr] {
  let a : Array[Array[Array[Int]]] = [[[1, 2], [3, 4]], [[5, 6], [7, 8]]]
  let b : Array[Array[Int]] = [[9]]
  [a, b]
}

///|
fn big_value() -> Map[String, Array[Int]] {
  let m = Map([])
  for i in 0..<12 {
    m["k\{i}"] = Array::makei(i, j => j)
  }
  m
}

///|
fn json_value() -> Json raise {
  @json.parse(
    "{\"a\": [1, 2.5, null, true, \"x\"], \"b\": {\"c\": \"d\", \"e\": []}, \"f\": {}, \"g\": 1e100}",
  )
}

///|
struct Widget {
  name : String
  children : Array[Widget]
  visible : Bool
}

///|
impl @pretty.PrettyRepr for Widget with fn pretty_node(self, ctx) {
  ctx.rich_repr(
    "Widget",
    [
      @pretty.arg(self.name),
      @pretty.kwarg("children", self.children),
      @pretty.kwarg_default("visible", self.visible, true),
    ],
    angular=true,
  )
}

///|
/// `Widget("other", [1, 2])`: children of a different type.
struct IntWidget {
  name : String
  children : Array[Int]
}

///|
impl @pretty.PrettyRepr for IntWidget with fn pretty_node(self, ctx) {
  ctx.rich_repr(
    "Widget",
    [@pretty.arg(self.name), @pretty.kwarg("children", self.children)],
    angular=true,
  )
}

///|
fn widget_value() -> &@pretty.PrettyRepr {
  ReprWidget::{
    name: "root",
    children: [
      Widget::{ name: "leaf", children: [], visible: false, },
      IntWidget::{ name: "other", children: [1, 2], },
    ],
  }
}

///|
struct ReprWidget {
  name : String
  children : Array[&@pretty.PrettyRepr]
}

///|
impl @pretty.PrettyRepr for ReprWidget with fn pretty_node(self, ctx) {
  ctx.rich_repr(
    "Widget",
    [@pretty.arg(self.name), @pretty.kwarg("children", self.children)],
    angular=true,
  )
}

///|
fn sets_deques_value() -> Array[&@pretty.PrettyRepr] {
  let empty_set : @set.Set[Int] = @set.Set([])
  let empty_deque : @deque.Deque[Int] = @deque.Deque([])
  [@set.Set([1, 2, 3]), @deque.Deque([1, 2]), empty_set, empty_deque]
}

///|
fn empties_value() -> Array[&@pretty.PrettyRepr] {
  let empty_list : Array[Int] = []
  let empty_map : Map[String, Int] = Map([])
  let empty_set : @set.Set[Int] = @set.Set([])
  let empty_bytes : Bytes = b""
  [empty_list, empty_map, @pretty.Tuple::new([]), empty_set, "", empty_bytes]
}

///|
fn wide_chars_value() -> Map[String, &@pretty.PrettyRepr] {
  {
    "名前": "山田太郎",
    "趣味": ["読書", "映画鑑賞", "プログラミング"],
  }
}

///|
fn render_renderable(value : &@rich.Renderable, width~ : Int) -> String raise {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    file~,
    width~,
    color_system=Some("truecolor"),
    force_terminal=true,
    legacy_windows=false,
    environ={},
  )
  console.print(value)
  file.getvalue()
}

///|
fn nested_value() -> Map[String, Map[String, Array[Int]]] {
  { "a": { "b": [1, 2] } }
}
