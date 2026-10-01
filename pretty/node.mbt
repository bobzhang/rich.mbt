// Port of `Node` and `_Line` from rich/pretty.py: the repr tree and the
// line-expansion algorithm that fits it into a given width.

///|
/// A node in a repr tree. May be atomic (`value_repr`) or a container
/// (`children` with `open_brace` / `close_brace`, or `empty` when there are
/// no children).
pub(all) struct Node {
  mut key_repr : String
  mut value_repr : String
  mut open_brace : String
  mut close_brace : String
  mut empty : String
  mut last : Bool
  mut is_tuple : Bool
  mut is_namedtuple : Bool
  mut children : Array[Node]?
  mut key_separator : String
  mut separator : String
}

///|
/// Create a node. Defaults follow upstream's `Node` dataclass.
///
/// ```mbt check
/// test {
///   let node = @pretty.Node::new(open_brace="[", close_brace="]", children=[
///     @pretty.Node::new(value_repr="1"),
///     @pretty.Node::new(value_repr="2", last=true),
///   ])
///   inspect(node, content="[1, 2]")
///   inspect(node.render(max_width=4), content="[\n    1,\n    2\n]")
/// }
/// ```
pub fn Node::new(
  key_repr? : String = "",
  value_repr? : String = "",
  open_brace? : String = "",
  close_brace? : String = "",
  empty? : String = "",
  last? : Bool = false,
  is_tuple? : Bool = false,
  is_namedtuple? : Bool = false,
  children? : Array[Node],
  key_separator? : String = ": ",
  separator? : String = ", ",
) -> Node {
  {
    key_repr,
    value_repr,
    open_brace,
    close_brace,
    empty,
    last,
    is_tuple,
    is_namedtuple,
    children,
    key_separator,
    separator,
  }
}

///|
/// A shallow copy of the node (children are shared).
pub fn Node::copy(self : Node) -> Node {
  { ..self, }
}

///|
/// Generate tokens for this node.
pub fn Node::iter_tokens(self : Node) -> Iter[String] {
  let tokens = []
  self.collect_tokens(tokens)
  tokens.iter()
}

///|
fn Node::collect_tokens(self : Node, tokens : Array[String]) -> Unit {
  if self.key_repr != "" {
    tokens.push(self.key_repr)
    tokens.push(self.key_separator)
  }
  if self.value_repr != "" {
    tokens.push(self.value_repr)
  } else if self.children is Some(children) {
    if children.length() > 0 {
      tokens.push(self.open_brace)
      if self.is_tuple && !self.is_namedtuple && children.length() == 1 {
        children[0].collect_tokens(tokens)
        tokens.push(",")
      } else {
        for child in children {
          child.collect_tokens(tokens)
          if !child.last {
            tokens.push(self.separator)
          }
        }
      }
      tokens.push(self.close_brace)
    } else {
      tokens.push(self.empty)
    }
  }
}

///|
/// Check the length fits within a limit.
///
/// `start_length` is the starting length of the line (indent, prefix,
/// suffix); returns `true` if the node can be rendered within
/// `max_length` cells.
pub fn Node::check_length(
  self : Node,
  start_length : Int,
  max_length : Int,
) -> Bool {
  // Walk the tokens lazily, stopping at the first one that overflows (as
  // upstream's generator does), so long containers are not tokenized in
  // full.
  let total = Ref(start_length)
  self.tokens_fit(total, max_length)
}

///|
/// Add the widths of this node's tokens to `total`; `false` as soon as it
/// exceeds `max_length`. Same token order as `collect_tokens`.
fn Node::tokens_fit(self : Node, total : Ref[Int], max_length : Int) -> Bool {
  fn add(token : String) -> Bool {
    total.val += @cells.cell_len(token)
    total.val <= max_length
  }

  if self.key_repr != "" {
    if !add(self.key_repr) || !add(self.key_separator) {
      return false
    }
  }
  if self.value_repr != "" {
    return add(self.value_repr)
  }
  guard self.children is Some(children) else { return true }
  if children.length() == 0 {
    return add(self.empty)
  }
  if !add(self.open_brace) {
    return false
  }
  if self.is_tuple && !self.is_namedtuple && children.length() == 1 {
    if !children[0].tokens_fit(total, max_length) || !add(",") {
      return false
    }
  } else {
    for child in children {
      if !child.tokens_fit(total, max_length) {
        return false
      }
      if !child.last && !add(self.separator) {
        return false
      }
    }
  }
  add(self.close_brace)
}

///|
/// The single-line repr (upstream `str(node)`).
pub impl Show for Node with fn output(self, logger) {
  for token in self.iter_tokens() {
    logger.write_string(token)
  }
}

///|
/// Render the node to a pretty repr, expanding containers on to new lines
/// until each line fits in `max_width` (or every container, with
/// `expand_all`).
pub fn Node::render(
  self : Node,
  max_width? : Int = 80,
  indent_size? : Int = 4,
  expand_all? : Bool = false,
) -> String {
  let mut lines : Array[Line] = [
    { node: Some(self), text: "", suffix: "", whitespace: "", last: false, },
  ]
  let mut line_no = 0
  while line_no < lines.length() {
    let line = lines[line_no]
    if line.expandable() {
      if expand_all || !line.check_length(max_width) {
        // lines[line_no : line_no + 1] = line.expand(indent_size)
        let expanded = line.expand(indent_size)
        let spliced = Array(capacity=lines.length() + expanded.length() - 1)
        spliced.append(lines[:line_no])
        spliced.append(expanded)
        spliced.append(lines[line_no + 1:])
        lines = spliced
      }
    }
    line_no += 1
  }
  lines.map(Line::to_string).join("\n")
}

///|
/// A line in repr output (upstream `_Line`).
priv struct Line {
  node : Node?
  text : String
  suffix : String
  whitespace : String
  last : Bool
}

///|
/// Check if the line may be expanded.
fn Line::expandable(self : Line) -> Bool {
  match self.node {
    Some({ children: Some(children), .. }) => children.length() > 0
    _ => false
  }
}

///|
/// Check this line fits within a given number of cells.
fn Line::check_length(self : Line, max_length : Int) -> Bool {
  let start_length = self.whitespace.length() +
    @cells.cell_len(self.text) +
    @cells.cell_len(self.suffix)
  self.node.unwrap().check_length(start_length, max_length)
}

///|
/// Expand this line by adding children on their own line.
fn Line::expand(self : Line, indent_size : Int) -> Array[Line] {
  let node = self.node.unwrap()
  let whitespace = self.whitespace
  let children = node.children.unwrap()
  let result = []
  let text = if node.key_repr != "" {
    "\{node.key_repr}\{node.key_separator}\{node.open_brace}"
  } else {
    node.open_brace
  }
  result.push({ node: None, text, suffix: "", whitespace, last: false, })
  let child_whitespace = whitespace + " ".repeat(indent_size)
  let tuple_of_one = node.is_tuple && children.length() == 1
  let separator = if tuple_of_one { "," } else { node.separator }
  for i, child in children {
    let last = i == children.length() - 1
    result.push({
      node: Some(child),
      text: "",
      suffix: separator,
      whitespace: child_whitespace,
      last: last && !tuple_of_one,
    })
  }
  result.push({
    node: None,
    text: node.close_brace,
    suffix: self.suffix,
    whitespace,
    last: self.last,
  })
  result
}

///|
fn Line::to_string(self : Line) -> String {
  let node = match self.node {
    Some(node) => node.to_string()
    None => ""
  }
  if self.last {
    "\{self.whitespace}\{self.text}\{node}"
  } else {
    "\{self.whitespace}\{self.text}\{node}\{self.suffix.trim_end()}"
  }
}

///|
extend Node with Show::{to_string}
