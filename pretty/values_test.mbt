// Tests for the MoonBit-specific `PrettyRepr` implementations and helpers.

///|
test "keys use the full repr" {
  // Expected values from the Python oracle.
  let d = @pretty.Dict::new([("abcdefgh", 1), (("abcdefgh", 1), ["abcdefgh"])])
  assert_eq(
    @pretty.pretty_repr(d, max_string=3),
    "{'abc'+5: 1, ('abcdefgh', 1): ['abc'+5]}",
  )
  let d = @pretty.Dict::new([((1, 2, 3, 4), [1, 2, 3, 4])])
  assert_eq(
    @pretty.pretty_repr(d, max_length=2),
    "{(1, 2, 3, 4): [1, 2, ... +2]}",
  )
  assert_eq(
    @pretty.pretty_repr({ "a": { "b": 1 } }, max_depth=1, max_width=4),
    "{\n    'a': {...}\n}",
  )
  let nested : Array[&@pretty.PrettyRepr] = [
    1,
    ([2, ([3, [4]] : Array[&@pretty.PrettyRepr])] : Array[&@pretty.PrettyRepr]),
  ]
  assert_eq(
    @pretty.pretty_repr(nested, max_depth=2, expand_all=true),
    "[\n    1,\n    [\n        2,\n        [...]\n    ]\n]",
  )
}

///|
test "scalars" {
  inspect(@pretty.pretty_repr(42), content="42")
  inspect(@pretty.pretty_repr(-7L), content="-7")
  inspect(@pretty.pretty_repr(7U), content="7")
  inspect(
    @pretty.pretty_repr(18446744073709551615UL),
    content="18446744073709551615",
  )
  inspect(
    @pretty.pretty_repr(12345678901234567890N),
    content="12345678901234567890",
  )
  inspect(@pretty.pretty_repr(b'A'), content="65")
  inspect(@pretty.pretty_repr(0.1), content="0.1")
  inspect(@pretty.pretty_repr(1.0e300), content="1e+300")
  inspect(@pretty.pretty_repr((0.5 : Float)), content="0.5")
  inspect(@pretty.pretty_repr(true), content="True")
  inspect(@pretty.pretty_repr(()), content="None")
  inspect(@pretty.pretty_repr('x'), content="'x'")
  inspect(@pretty.pretty_repr("it's"), content="\"it's\"")
  inspect(@pretty.pretty_repr("abc"[1:]), content="'bc'")
  inspect(@pretty.pretty_repr(b"\x01ab'"), content="b\"\\x01ab'\"")
  inspect(@pretty.pretty_repr(b"abcdef", max_string=2), content="b'ab'+4")
  inspect(@pretty.pretty_repr("😀😀😀", max_string=1), content="'😀'+2")
}

///|
test "option and result" {
  let some : Int? = Some(1)
  let none : Int? = None
  inspect(@pretty.pretty_repr([some, none]), content="[1, None]")
  let ok : Result[Array[Int], String] = Ok([1, 2])
  let err : Result[Array[Int], String] = Err("boom")
  inspect(@pretty.pretty_repr(ok), content="Ok([1, 2])")
  inspect(@pretty.pretty_repr(err), content="Err('boom')")
  inspect(
    @pretty.pretty_repr(ok, max_width=6),
    content=(
      #|Ok(
      #|    [
      #|        1,
      #|        2
      #|    ]
      #|)
    ),
  )
}

///|
test "arrays and maps" {
  let fixed : FixedArray[Int] = [1, 2]
  inspect(@pretty.pretty_repr(fixed), content="[1, 2]")
  let view : ArrayView[Int] = [1, 2, 3][1:]
  inspect(@pretty.pretty_repr(view), content="[2, 3]")
  let ro : ReadOnlyArray[String] = ["a"]
  inspect(@pretty.pretty_repr(ro), content="['a']")
  let hm : @hashmap.HashMap[String, Int] = @hashmap.HashMap::from_array([
    ("a", 1),
  ])
  inspect(@pretty.pretty_repr(hm), content="{'a': 1}")
  let hs : @hashset.HashSet[Int] = @hashset.HashSet::from_array([1])
  inspect(@pretty.pretty_repr(hs), content="{1}")
  let empty_hs : @hashset.HashSet[Int] = @hashset.HashSet::from_array([])
  inspect(@pretty.pretty_repr(empty_hs), content="set()")
  inspect(
    @pretty.pretty_repr((1, "a", 2.5, true, 'c', [1])),
    content="(1, 'a', 2.5, True, 'c', [1])",
  )
}

///|
test "json" {
  let j : Json = {
    "int": 1,
    "float": 1.5,
    "null": Json::null(),
    "list": [true, false],
  }
  inspect(
    @pretty.pretty_repr(j),
    content="{'int': 1, 'float': 1.5, 'null': None, 'list': [True, False]}",
  )
}

///|
#warnings("-unused_constructor")
enum Color {
  Red
  Rgb(Int, Int, Int)
} derive(Debug)

///|
impl Show for Color with fn output(self, logger) {
  match self {
    Red => logger.write_string("Red")
    Rgb(r, g, b) => logger.write_string("#\{r}\{g}\{b}")
  }
}

///|
test "opaque leaves" {
  let values : Array[&@pretty.PrettyRepr] = [
    @pretty.debugged(Rgb(1, 2, 3)),
    @pretty.shown(Red),
    @pretty.Leaf::new("<object at 0x1>"),
  ]
  inspect(
    @pretty.pretty_repr(values),
    content="[Rgb(1, 2, 3), Red, <object at 0x1>]",
  )
  // max_string does not apply to opaque leaves
  inspect(
    @pretty.pretty_repr(@pretty.Leaf::new("abcdef"), max_string=2),
    content="abcdef",
  )
}

///|
test "traverse and node" {
  let node = @pretty.traverse([1, 2, 3], max_length=1)
  inspect(node, content="[1, ... +2]")
  inspect(node.children.unwrap().length(), content="2")
  inspect(node.check_length(0, 11), content="true")
  inspect(node.check_length(1, 11), content="false")
  inspect(node.iter_tokens().collect().join("|"), content="[|1|, |... +2|]")
  inspect(
    node.render(max_width=5, indent_size=2),
    content="[\n  1,\n  ... +2\n]",
  )
}

///|
test "large values" {
  let big = Array::makei(20000, i => i)
  let lines = @pretty.pretty_repr(big).split("\n").collect()
  inspect(lines.length(), content="20002")
  inspect(lines[20000], content="    19999")
  let nested = Array::makei(2000, i => [i, i + 1])
  let lines = @pretty.pretty_repr(nested, expand_all=true).split("\n").collect()
  inspect(lines.length(), content="8002")
}

///|
test "pprint to the global console" {
  // Smoke test: pprint without a console uses @rich.get_console().
  let console = @rich.get_console()
  let output = console.capture(() => @pretty.pprint([1, 2]))
  inspect(output, content="[1, 2]\n")
}
