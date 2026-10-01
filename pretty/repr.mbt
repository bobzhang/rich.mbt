// Port of rich/repr.py and of the `__rich_repr__` / dataclass / namedtuple
// branches of `rich.pretty.traverse`: helpers that build constructor-call
// style reprs such as `Foo('hello', bar=3, egg=1)`.

///|
/// One item of a rich repr (upstream's `__rich_repr__` yields).
pub(all) enum ReprArg {
  /// A positional value: `yield value` / `yield (value,)` /
  /// `yield None, value`.
  Positional(&PrettyRepr)
  /// A keyword value: `yield "name", value`.
  Keyword(String, &PrettyRepr)
  /// Nothing (a value equal to its default).
  Skip
}

///|
/// A positional argument.
pub fn[T : PrettyRepr] arg(value : T) -> ReprArg {
  Positional(value)
}

///|
/// A positional argument that is omitted when equal to `default`
/// (upstream `yield None, value, default`).
pub fn[T : PrettyRepr + Eq] arg_default(value : T, default : T) -> ReprArg {
  if value == default {
    Skip
  } else {
    Positional(value)
  }
}

///|
/// A keyword argument (upstream `yield name, value`).
pub fn[T : PrettyRepr] kwarg(name : String, value : T) -> ReprArg {
  Keyword(name, value)
}

///|
/// A keyword argument that is omitted when equal to `default` (upstream
/// `yield name, value, default`).
pub fn[T : PrettyRepr + Eq] kwarg_default(
  name : String,
  value : T,
  default : T,
) -> ReprArg {
  if value == default {
    Skip
  } else {
    Keyword(name, value)
  }
}

///|
/// A constructor-call style repr, as upstream renders objects with a
/// `__rich_repr__` method (and attrs classes): `Foo('a', bar=1)`, or
/// `<Foo 'a' bar=1>` when `angular`.
///
/// Pass `id` for objects that may be part of a reference cycle.
///
/// ```mbt check
/// test {
///   let ctx = @pretty.PrettyContext::new()
///   let node = ctx.rich_repr("Point", [
///     @pretty.arg(1),
///     @pretty.arg(2),
///     @pretty.kwarg_default("label", "origin", ""),
///   ])
///   inspect(node, content="Point(1, 2, label='origin')")
/// }
/// ```
pub fn PrettyContext::rich_repr(
  self : PrettyContext,
  class_name : String,
  args : ArrayView[ReprArg],
  angular? : Bool = false,
  id? : PrettyId,
) -> Node {
  self.guard_opt(id, () => {
    let args = args.iter().filter(a => !(a is Skip)).collect()
    if args.length() > 0 {
      if self.reached_max_depth() {
        if angular {
          Node::new(value_repr="<\{class_name}...>")
        } else {
          Node::new(value_repr="\{class_name}(...)")
        }
      } else {
        let children = []
        let node = if angular {
          Node::new(
            open_brace="<\{class_name} ",
            close_brace=">",
            children~,
            last=self.root,
            separator=" ",
          )
        } else {
          Node::new(
            open_brace="\{class_name}(",
            close_brace=")",
            children~,
            last=self.root,
          )
        }
        for i, arg in args {
          let last = i == args.length() - 1
          match arg {
            Keyword(key, value) => {
              let child_node = self.child(value)
              child_node.last = last
              child_node.key_repr = key
              child_node.key_separator = "="
              children.push(child_node)
            }
            Positional(value) => {
              let child_node = self.child(value)
              child_node.last = last
              children.push(child_node)
            }
            Skip => ()
          }
        }
        node
      }
    } else {
      Node::new(
        value_repr=if angular { "<\{class_name}>" } else { "\{class_name}()" },
        children=[],
        last=self.root,
      )
    }
  })
}

///|
/// A dataclass repr: `Name(field=value, ...)` (upstream's dataclass
/// branch; omit fields declared with `repr=False`).
pub fn PrettyContext::dataclass(
  self : PrettyContext,
  class_name : String,
  fields : ArrayView[(String, &PrettyRepr)],
  id? : PrettyId,
) -> Node {
  self.guard_opt(id, () => {
    if self.reached_max_depth() {
      Node::new(value_repr="\{class_name}(...)")
    } else {
      let children = []
      for i, field in fields {
        let (name, value) = field
        let child_node = self.child(value)
        child_node.key_repr = name
        child_node.last = i == fields.length() - 1
        child_node.key_separator = "="
        children.push(child_node)
      }
      Node::new(
        open_brace="\{class_name}(",
        close_brace=")",
        children~,
        last=self.root,
        empty="\{class_name}()",
      )
    }
  })
}

///|
/// A namedtuple repr: `Name(field=value, ...)` (upstream's namedtuple
/// branch).
pub fn PrettyContext::namedtuple(
  self : PrettyContext,
  class_name : String,
  fields : ArrayView[(String, &PrettyRepr)],
  id? : PrettyId,
) -> Node {
  let node = self.guard_opt(id, () => {
    if self.reached_max_depth() {
      Node::new(value_repr="\{class_name}(...)")
    } else {
      let children = []
      for i, field in fields {
        let (name, value) = field
        let child_node = self.child(value)
        child_node.key_repr = name
        child_node.last = i == fields.length() - 1
        child_node.key_separator = "="
        children.push(child_node)
      }
      Node::new(
        open_brace="\{class_name}(",
        close_brace=")",
        children~,
        empty="\{class_name}()",
      )
    }
  })
  node.is_namedtuple = true
  node
}

///|
/// The plain `repr` string that `rich.repr.auto` generates from
/// `__rich_repr__`: `Foo('hello', egg=1)` or `<Foo 'hello' egg=1>`.
pub fn repr_string(
  class_name : String,
  args : ArrayView[ReprArg],
  angular? : Bool = false,
) -> String {
  let parts = []
  for arg in args {
    match arg {
      Positional(value) => parts.push(traverse(value).to_string())
      Keyword(key, value) => parts.push("\{key}=\{traverse(value).to_string()}")
      Skip => ()
    }
  }
  if angular {
    "<\{class_name} \{parts.join(" ")}>"
  } else {
    "\{class_name}(\{parts.join(", ")})"
  }
}
