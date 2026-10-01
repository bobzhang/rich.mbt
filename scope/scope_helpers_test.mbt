// Helpers for scope_test.mbt (values mirror scripts/scope_oracle.py).

///|
fn render(
  scope : Map[String, &@pretty.PrettyRepr],
  width~ : Int,
  color~ : Bool,
  title? : String,
  sort_keys? : Bool = true,
  indent_guides? : Bool = false,
  max_length? : Int,
  max_string? : Int,
  max_depth? : Int,
  overflow? : @rich.OverflowMethod,
) -> String raise {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    file~,
    width~,
    color_system=if color { Some("truecolor") } else { None },
    force_terminal=color,
    legacy_windows=false,
    environ={},
  )
  console.print(
    @scope.render_scope(
      scope,
      title?=title.map(t => (t : &@rich.IntoText)),
      sort_keys~,
      indent_guides~,
      max_length?,
      max_string?,
      max_depth?,
      overflow?,
    ),
  )
  file.getvalue()
}

///|
let none : Int? = None

///|
fn demo_scope() -> Map[String, &@pretty.PrettyRepr] {
  {
    "foo": 20.3423,
    "bar": 3.1427,
    "list_of_things": (
      [1, 2, 3, none, 4, true, false, "Hello World"] :
      Array[&@pretty.PrettyRepr]),
    "dict_of_things": (
      {
        "version": "1.1",
        "method": "confirmFruitPurchase",
        "params": (
          [["apple", "orange", "mangoes", "pomelo"], 1.123] :
          Array[&@pretty.PrettyRepr]),
        "id": "194521489",
      } : Map[String, &@pretty.PrettyRepr]),
  }
}

///|
fn special_scope() -> Map[String, &@pretty.PrettyRepr] {
  {
    "zebra": 1,
    "Apple": "a",
    "__name__": "__main__",
    "apple": "b",
    "__doc__": none,
    "_private": [1, 2],
    "Zed": { "k": "v" },
  }
}

///|
fn long_scope() -> Map[String, &@pretty.PrettyRepr] {
  { "s": "x".repeat(60) }
}
