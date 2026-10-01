// The `traverse` half of rich/pretty.py. Upstream introspects arbitrary
// Python objects; here a value describes itself by implementing
// `PrettyRepr`, using the `PrettyContext` helpers that encode upstream's
// rules for containers, mappings, strings and limits.

///|
/// A value that can be pretty printed: build the repr tree (`Node`) for
/// `self`.
///
/// Implementations normally call one of the `PrettyContext` builders:
/// `leaf` (an atomic repr), `str_leaf` (a string subject to `max_string`),
/// `sequence` / `mapping` / `tuple` (containers subject to `max_length` and
/// `max_depth`), or `rich_repr` / `dataclass` / `namedtuple` (a
/// constructor-call style repr such as `Foo(a=1, b=[1, 2])`). Children are
/// traversed with `PrettyContext::child`.
///
/// ```mbt check
/// test {
///   let ctx_demo : Array[Int] = [1, 2, 3]
///   inspect(@pretty.pretty_repr(ctx_demo), content="[1, 2, 3]")
/// }
/// ```
pub(open) trait PrettyRepr {
  fn pretty_node(Self, PrettyContext) -> Node
}

///|
/// The traversal state handed to `PrettyRepr::pretty_node`: the limits
/// requested by the caller and the current depth.
pub struct PrettyContext {
  /// Maximum length of containers before abbreviating.
  max_length : Int?
  /// Maximum length of strings before truncating.
  max_string : Int?
  /// Maximum depth of nested data structures.
  max_depth : Int?
  /// Depth of the value being traversed (0 for the root).
  depth : Int
  /// Whether the value being traversed is the root of the tree.
  root : Bool
  priv visited : Array[Int]
  // Key reprs use the full `repr` of the key, truncating only a top-level
  // string (upstream `to_repr(key)`).
  priv key_mode : Bool
}

///|
/// A fresh context for the root of a traversal.
pub fn PrettyContext::new(
  max_length? : Int,
  max_string? : Int,
  max_depth? : Int,
) -> PrettyContext {
  {
    max_length,
    max_string,
    max_depth,
    depth: 0,
    root: true,
    visited: [],
    key_mode: false,
  }
}

///|
/// Traverse a child value (one level deeper).
pub fn[T : PrettyRepr] PrettyContext::child(
  self : PrettyContext,
  value : T,
) -> Node {
  value.pretty_node({
    ..self,
    depth: self.depth + 1,
    root: false,
    max_string: if self.key_mode {
      None
    } else {
      self.max_string
    },
  })
}

///|
/// Whether the maximum depth has been reached (containers are abbreviated,
/// e.g. `[...]`).
pub fn PrettyContext::reached_max_depth(self : PrettyContext) -> Bool {
  match self.max_depth {
    Some(max_depth) => self.depth >= max_depth
    None => false
  }
}

///|
/// An atomic node with the given repr.
pub fn PrettyContext::leaf(self : PrettyContext, value_repr : String) -> Node {
  Node::new(value_repr~, last=self.root)
}

///|
/// The repr of a string, truncated to `max_string` characters (upstream
/// shows `'abc'+N` where N is the number of characters removed).
pub fn PrettyContext::str_repr(self : PrettyContext, s : String) -> String {
  match self.max_string {
    Some(max_string) if @pystr.py_len(s) > max_string => {
      let truncated = @pystr.py_len(s) - max_string
      "\{@rich.py_repr(@pystr.slice(s, 0, end=max_string))}+\{truncated}"
    }
    _ => @rich.py_repr(s)
  }
}

///|
/// An atomic node for a string, truncated to `max_string`.
pub fn PrettyContext::str_leaf(self : PrettyContext, s : String) -> Node {
  self.leaf(self.str_repr(s))
}

///|
/// The repr of a mapping key: the full single-line repr of `key` (only a
/// top-level string key is truncated to `max_string`).
pub fn[K : PrettyRepr] PrettyContext::key_repr(
  self : PrettyContext,
  key : K,
) -> String {
  let ctx = {
    max_length: None,
    max_string: self.max_string,
    max_depth: None,
    depth: 0,
    root: true,
    visited: [],
    key_mode: true,
  }
  key.pretty_node(ctx).to_string()
}

///|
/// Run `f` unless the object identified by `id` is already being traversed
/// (a reference cycle), in which case the result is `...`.
///
/// Upstream detects cycles with `id(obj)`; MoonBit has no object identity
/// for arbitrary values, so types that may form cycles carry a `PrettyId`.
pub fn PrettyContext::visit(
  self : PrettyContext,
  id : PrettyId,
  f : () -> Node,
) -> Node {
  if self.visited.contains(id.id) {
    return Node::new(value_repr="...")
  }
  self.visited.push(id.id)
  let node = f()
  self.visited.pop() |> ignore
  node
}

///|
fn PrettyContext::guard_opt(
  self : PrettyContext,
  id : PrettyId?,
  f : () -> Node,
) -> Node {
  match id {
    Some(id) => self.visit(id, f)
    None => f()
  }
}

///|
/// A unique identity for objects that may be part of a reference cycle.
/// Store one in such objects and pass it to the builders (`id=`).
pub struct PrettyId {
  priv id : Int
}

///|
let pretty_id_counter : Ref[Int] = { val: 0, }

///|
/// A new unique identity.
pub fn PrettyId::new() -> PrettyId {
  pretty_id_counter.val += 1
  { id: pretty_id_counter.val, }
}

///|
/// Shared container logic (upstream's `_CONTAINERS` branch).
fn PrettyContext::container(
  self : PrettyContext,
  count : Int,
  child : (Int) -> Node,
  open_brace~ : String,
  close_brace~ : String,
  empty~ : String,
  is_tuple~ : Bool,
  id~ : PrettyId?,
) -> Node {
  let node = self.guard_opt(id, () => {
    if self.reached_max_depth() {
      Node::new(value_repr="\{open_brace}...\{close_brace}")
    } else if count > 0 {
      let children = []
      let last_item_index = count - 1
      let limit = match self.max_length {
        Some(max_length) => @cmp.minimum(max_length, count)
        None => count
      }
      for index in 0..<limit {
        let child_node = child(index)
        child_node.last = index == last_item_index
        children.push(child_node)
      }
      if self.max_length is Some(max_length) && count > max_length {
        children.push(
          Node::new(value_repr="... +\{count - max_length}", last=true),
        )
      }
      Node::new(open_brace~, close_brace~, children~, last=self.root)
    } else {
      Node::new(empty~, children=[], last=self.root)
    }
  })
  node.is_tuple = is_tuple
  node
}

///|
/// A sequence container such as a list (`[1, 2]`), set (`{1, 2}`) or
/// deque (`deque([1, 2])`).
///
/// Honours `max_length` (`[1, 2, ... +8]`) and `max_depth` (`[...]`).
pub fn[T : PrettyRepr] PrettyContext::sequence(
  self : PrettyContext,
  items : ArrayView[T],
  open_brace? : String = "[",
  close_brace? : String = "]",
  empty? : String = "[]",
  is_tuple? : Bool = false,
  id? : PrettyId,
) -> Node {
  self.container(
    items.length(),
    i => self.child(items[i]),
    open_brace~,
    close_brace~,
    empty~,
    is_tuple~,
    id~,
  )
}

///|
/// A Python tuple: `(1, 2)`, `(1,)` or `()`.
pub fn PrettyContext::tuple(
  self : PrettyContext,
  items : ArrayView[&PrettyRepr],
) -> Node {
  self.sequence(
    items,
    open_brace="(",
    close_brace=")",
    empty="()",
    is_tuple=true,
  )
}

///|
/// A mapping container such as a dict (`{'a': 1}`).
///
/// Keys are shown with their full repr (`PrettyContext::key_repr`).
pub fn[K : PrettyRepr, V : PrettyRepr] PrettyContext::mapping(
  self : PrettyContext,
  items : ArrayView[(K, V)],
  open_brace? : String = "{",
  close_brace? : String = "}",
  empty? : String = "{}",
  id? : PrettyId,
) -> Node {
  self.container(
    items.length(),
    i => {
      let (key, value) = items[i]
      let child_node = self.child(value)
      child_node.key_repr = self.key_repr(key)
      child_node
    },
    open_brace~,
    close_brace~,
    empty~,
    is_tuple=false,
    id~,
  )
}

///|
/// Traverse a value and generate a repr tree.
pub fn[T : PrettyRepr] traverse(
  value : T,
  max_length? : Int,
  max_string? : Int,
  max_depth? : Int,
) -> Node {
  value.pretty_node(PrettyContext::new(max_length?, max_string?, max_depth?))
}
