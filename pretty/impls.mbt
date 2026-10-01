// `PrettyRepr` implementations for builtin and core types, formatted as
// the Python value they correspond to would be.

///|
pub impl PrettyRepr for Int with fn pretty_node(self, ctx) {
  ctx.leaf(self.to_string())
}

///|
pub impl PrettyRepr for Int64 with fn pretty_node(self, ctx) {
  ctx.leaf(self.to_string())
}

///|
pub impl PrettyRepr for UInt with fn pretty_node(self, ctx) {
  ctx.leaf(self.to_string())
}

///|
pub impl PrettyRepr for UInt64 with fn pretty_node(self, ctx) {
  ctx.leaf(self.to_string())
}

///|
pub impl PrettyRepr for Int16 with fn pretty_node(self, ctx) {
  ctx.leaf(self.to_string())
}

///|
pub impl PrettyRepr for UInt16 with fn pretty_node(self, ctx) {
  ctx.leaf(self.to_string())
}

///|
/// A byte is shown as an integer (as an element of Python `bytes` is).
pub impl PrettyRepr for Byte with fn pretty_node(self, ctx) {
  ctx.leaf(self.to_int().to_string())
}

///|
pub impl PrettyRepr for BigInt with fn pretty_node(self, ctx) {
  ctx.leaf(self.to_string())
}

///|
/// Python `repr(float)`.
pub impl PrettyRepr for Double with fn pretty_node(self, ctx) {
  ctx.leaf(@rich.py_float_repr(self))
}

///|
/// Python `repr(float)` of the (exact) double value.
pub impl PrettyRepr for Float with fn pretty_node(self, ctx) {
  ctx.leaf(@rich.py_float_repr(self.to_double()))
}

///|
/// `True` / `False`.
pub impl PrettyRepr for Bool with fn pretty_node(self, ctx) {
  ctx.leaf(if self { "True" } else { "False" })
}

///|
/// `None`.
pub impl PrettyRepr for Unit with fn pretty_node(_self, ctx) {
  ctx.leaf("None")
}

///|
/// A one character Python string.
pub impl PrettyRepr for Char with fn pretty_node(self, ctx) {
  ctx.str_leaf(self.to_string())
}

///|
/// Python `repr(str)`, truncated to `max_string`.
pub impl PrettyRepr for String with fn pretty_node(self, ctx) {
  ctx.str_leaf(self)
}

///|
pub impl PrettyRepr for StringView with fn pretty_node(self, ctx) {
  ctx.str_leaf(self.to_owned())
}

///|
/// Python `repr(bytes)`, truncated to `max_string`.
pub impl PrettyRepr for Bytes with fn pretty_node(self, ctx) {
  match ctx.max_string {
    Some(max_string) if self.length() > max_string =>
      ctx.leaf(
        "\{py_bytes_repr(self[:max_string])}+\{self.length() - max_string}",
      )
    _ => ctx.leaf(py_bytes_repr(self[:]))
  }
}

///|
/// Python `repr(bytes)`.
pub fn py_bytes_repr(b : BytesView) -> String {
  let mut has_single = false
  let mut has_double = false
  for byte in b {
    if byte == b'\'' {
      has_single = true
    } else if byte == b'"' {
      has_double = true
    }
  }
  let quote = if has_single && !has_double { '"' } else { '\'' }
  let buf = StringBuilder()
  buf.write_char('b')
  buf.write_char(quote)
  let hex = "0123456789abcdef"
  for byte in b {
    let c = byte.to_int()
    if c == quote.to_int() || c == '\\'.to_int() {
      buf.write_char('\\')
      buf.write_char(c.unsafe_to_char())
    } else if c == '\t'.to_int() {
      buf.write_string("\\t")
    } else if c == '\n'.to_int() {
      buf.write_string("\\n")
    } else if c == '\r'.to_int() {
      buf.write_string("\\r")
    } else if c < 0x20 || c >= 0x7f {
      buf.write_string("\\x")
      buf.write_char(hex[c >> 4].to_int().unsafe_to_char())
      buf.write_char(hex[c & 15].to_int().unsafe_to_char())
    } else {
      buf.write_char(c.unsafe_to_char())
    }
  }
  buf.write_char(quote)
  buf.to_string()
}

///|
/// `None`, or the repr of the value (Python's `Optional`).
pub impl[T : PrettyRepr] PrettyRepr for T? with fn pretty_node(self, ctx) {
  match self {
    None => ctx.leaf("None")
    Some(value) => value.pretty_node(ctx)
  }
}

///|
/// `Ok(value)` / `Err(error)`.
pub impl[T : PrettyRepr, E : PrettyRepr] PrettyRepr for Result[T, E] with fn pretty_node(
  self,
  ctx,
) {
  match self {
    Ok(value) => ctx.rich_repr("Ok", [arg(value)])
    Err(error) => ctx.rich_repr("Err", [arg(error)])
  }
}

///|
/// An error value, shown with its `Show` output.
pub impl PrettyRepr for Error with fn pretty_node(self, ctx) {
  ctx.leaf(self.to_string())
}

///|
/// A Python list.
pub impl[T : PrettyRepr] PrettyRepr for Array[T] with fn pretty_node(self, ctx) {
  ctx.sequence(self[:])
}

///|
/// A Python list.
pub impl[T : PrettyRepr] PrettyRepr for ArrayView[T] with fn pretty_node(
  self,
  ctx,
) {
  ctx.sequence(self)
}

///|
/// A Python list.
pub impl[T : PrettyRepr] PrettyRepr for FixedArray[T] with fn pretty_node(
  self,
  ctx,
) {
  ctx.sequence(self[:])
}

///|
/// A Python list.
pub impl[T : PrettyRepr] PrettyRepr for ReadOnlyArray[T] with fn pretty_node(
  self,
  ctx,
) {
  ctx.sequence(self[:])
}

///|
/// A Python `deque`.
pub impl[T : PrettyRepr] PrettyRepr for @deque.Deque[T] with fn pretty_node(
  self,
  ctx,
) {
  ctx.sequence(
    self.to_array(),
    open_brace="deque([",
    close_brace="])",
    empty="deque()",
  )
}

///|
/// A Python `set` (in iteration order).
pub impl[T : PrettyRepr] PrettyRepr for @set.Set[T] with fn pretty_node(
  self,
  ctx,
) {
  ctx.sequence(self.to_array(), open_brace="{", close_brace="}", empty="set()")
}

///|
/// A Python `set` (in iteration order).
pub impl[T : PrettyRepr] PrettyRepr for @hashset.HashSet[T] with fn pretty_node(
  self,
  ctx,
) {
  ctx.sequence(
    self.iter().collect(),
    open_brace="{",
    close_brace="}",
    empty="set()",
  )
}

///|
/// A Python dict (in insertion order).
pub impl[K : PrettyRepr, V : PrettyRepr] PrettyRepr for Map[K, V] with fn pretty_node(
  self,
  ctx,
) {
  ctx.mapping(self.to_array())
}

///|
/// A Python dict (in iteration order).
pub impl[K : PrettyRepr, V : PrettyRepr] PrettyRepr for @hashmap.HashMap[K, V] with fn pretty_node(
  self,
  ctx,
) {
  ctx.mapping(self.iter().collect())
}

///|
/// A Python tuple.
pub impl[A : PrettyRepr, B : PrettyRepr] PrettyRepr for (A, B) with fn pretty_node(
  self,
  ctx,
) {
  ctx.tuple([self.0, self.1])
}

///|
/// A Python tuple.
pub impl[A : PrettyRepr, B : PrettyRepr, C : PrettyRepr] PrettyRepr for (
  A,
  B,
  C,
) with fn pretty_node(self, ctx) {
  ctx.tuple([self.0, self.1, self.2])
}

///|
/// A Python tuple.
pub impl[A : PrettyRepr, B : PrettyRepr, C : PrettyRepr, D : PrettyRepr] PrettyRepr for (
  A,
  B,
  C,
  D,
) with fn pretty_node(self, ctx) {
  ctx.tuple([self.0, self.1, self.2, self.3])
}

///|
/// A Python tuple.
pub impl[
  A : PrettyRepr,
  B : PrettyRepr,
  C : PrettyRepr,
  D : PrettyRepr,
  E : PrettyRepr,
] PrettyRepr for (A, B, C, D, E) with fn pretty_node(self, ctx) {
  ctx.tuple([self.0, self.1, self.2, self.3, self.4])
}

///|
/// A Python tuple.
pub impl[
  A : PrettyRepr,
  B : PrettyRepr,
  C : PrettyRepr,
  D : PrettyRepr,
  E : PrettyRepr,
  F : PrettyRepr,
] PrettyRepr for (A, B, C, D, E, F) with fn pretty_node(self, ctx) {
  ctx.tuple([self.0, self.1, self.2, self.3, self.4, self.5])
}

///|
/// JSON data as Python's `json.loads` returns it: `None`, `True`/`False`,
/// int or float, str, list, dict.
pub impl PrettyRepr for Json with fn pretty_node(self, ctx) {
  PrettyRepr::pretty_node(@rich.JsonValue::from_json(self), ctx)
}

///|
pub impl PrettyRepr for @rich.JsonValue with fn pretty_node(self, ctx) {
  match self {
    JNull => ctx.leaf("None")
    JBool(b) => PrettyRepr::pretty_node(b, ctx)
    JInt(digits) => ctx.leaf(digits)
    JFloat(d) => PrettyRepr::pretty_node(d, ctx)
    JString(s) => ctx.str_leaf(s)
    JArray(items) => ctx.sequence(items)
    JObject(items) => ctx.mapping(items)
  }
}

///|
/// A node renders as itself (upstream `pretty_repr(node)`).
pub impl PrettyRepr for Node with fn pretty_node(self, _ctx) {
  self.copy()
}

///|
/// An explicit Python tuple, including the 1-tuple `(1,)` and the empty
/// tuple `()`.
pub struct Tuple {
  items : Array[&PrettyRepr]
}

///|
pub fn Tuple::new(items : Array[&PrettyRepr]) -> Tuple {
  { items, }
}

///|
pub impl PrettyRepr for Tuple with fn pretty_node(self, ctx) {
  ctx.tuple(self.items)
}

///|
/// An opaque value with a fixed repr string. Use it for values known only
/// through `Show` or `Debug` (see `shown` and `debugged`), or for a
/// custom repr.
pub struct Leaf {
  repr : String
}

///|
/// A leaf with the given repr (shown verbatim; `max_string` does not
/// apply).
pub fn Leaf::new(repr : String) -> Leaf {
  { repr, }
}

///|
/// An opaque leaf showing `value` with its `Show` implementation.
pub fn[T : Show] shown(value : T) -> Leaf {
  { repr: value.to_string(), }
}

///|
/// An opaque leaf showing `value` with its `Debug` implementation.
pub fn[T : @debug.Debug] debugged(value : T) -> Leaf {
  { repr: @debug.to_string(value), }
}

///|
pub impl PrettyRepr for Leaf with fn pretty_node(self, ctx) {
  ctx.leaf(self.repr)
}

///|
/// A Python dict with keys and values of any (possibly different) types,
/// in the given order.
pub struct Dict {
  items : Array[(&PrettyRepr, &PrettyRepr)]
}

///|
pub fn Dict::new(items : Array[(&PrettyRepr, &PrettyRepr)]) -> Dict {
  { items, }
}

///|
pub impl PrettyRepr for Dict with fn pretty_node(self, ctx) {
  ctx.mapping(self.items)
}
