// A subset of Python's `ast.literal_eval`, used by markup for the
// parameters of `[@handler=...]` tags.

///|
/// A Python literal value (as parsed by `ast.literal_eval`).
pub(all) enum PyValue {
  PyNone
  PyBool(Bool)
  PyInt(Int64)
  PyFloat(Double)
  PyStr(String)
  PyBytes(String)
  PyTuple(Array[PyValue])
  PyList(Array[PyValue])
  PySet(Array[PyValue])
  PyDict(Array[(PyValue, PyValue)])
} derive(Eq, Debug)

///|
/// Convert to JSON: tuples, lists and sets become arrays, dicts objects
/// (non-string keys are stringified), bytes strings.
pub impl ToJson for PyValue with fn to_json(self) {
  match self {
    PyNone => Json::null()
    PyBool(b) => Json::boolean(b)
    PyInt(n) => Json::number(n.to_double())
    PyFloat(f) => Json::number(f)
    PyStr(s) | PyBytes(s) => Json::string(s)
    PyTuple(items) | PyList(items) | PySet(items) =>
      Json::array(items.map(v => v.to_json()))
    PyDict(items) => {
      let m : Map[String, Json] = Map([])
      for kv in items {
        let key = match kv.0 {
          PyStr(s) => s
          k => k.to_json().stringify()
        }
        m[key] = kv.1.to_json()
      }
      Json::object(m)
    }
  }
}

///|
/// Python `repr()` of the value.
pub fn PyValue::repr(self : PyValue) -> String {
  match self {
    PyNone => "None"
    PyBool(b) => py_bool(b)
    PyInt(n) => n.to_string()
    PyFloat(f) => py_float_repr(f)
    PyStr(s) => py_repr(s)
    PyBytes(s) => "b" + py_repr(s)
    PyTuple([item]) => "(" + item.repr() + ",)"
    PyTuple(items) => "(" + items.map(PyValue::repr).join(", ") + ")"
    PyList(items) => "[" + items.map(PyValue::repr).join(", ") + "]"
    PySet([]) => "set()"
    PySet(items) => "{" + items.map(PyValue::repr).join(", ") + "}"
    PyDict(items) =>
      "{" + items.map(kv => kv.0.repr() + ": " + kv.1.repr()).join(", ") + "}"
  }
}

///|
/// `SyntaxError` (with its `msg`) or `ValueError` from `literal_eval`.
priv suberror LitError {
  LitSyntax(String)
  LitValue(String)
}

///|
priv enum LitTok {
  TName(String)
  TNum(String)
  /// value, `kind` ("u" or none), is bytes
  TStr(String, String?, Bool)
  TOp(String)
  TEnd
}

///|
fn is_name_start(c : Char) -> Bool {
  c is ('a'..='z' | 'A'..='Z' | '_') || c.to_int() > 0x7f
}

///|
fn is_name_char(c : Char) -> Bool {
  is_name_start(c) || c is ('0'..='9')
}

///|
fn bracket_close(open : Char) -> Char {
  match open {
    '(' => ')'
    '[' => ']'
    _ => '}'
  }
}

///|
/// Tokenize a Python expression (eval mode).
fn lit_tokenize(src : String) -> Array[LitTok] raise LitError {
  let chars = src.to_array()
  let n = chars.length()
  let tokens = []
  let brackets : Array[Char] = []
  let mut i = 0
  while i < n {
    let c = chars[i]
    if c is (' ' | '\t' | '\n' | '\r' | '\u{0c}') {
      i += 1
      continue
    }
    // string literal (with an optional prefix)
    let mut j = i
    while j < n && j - i < 2 && chars[j] is ('r' | 'R' | 'u' | 'U' | 'b' | 'B') {
      j += 1
    }
    if j < n && chars[j] is ('\'' | '"') {
      let prefix = String::from_array(chars[i:j]).to_lower()
      if prefix is ("" | "r" | "u" | "b" | "rb" | "br") {
        let raw = prefix.contains("r")
        let quote = chars[j]
        let triple = j + 2 < n && chars[j + 1] == quote && chars[j + 2] == quote
        let mut k = j + (if triple { 3 } else { 1 })
        let buf = StringBuilder()
        while true {
          if k >= n || (!triple && chars[k] == '\n') {
            raise LitSyntax(
              if triple {
                "unterminated triple-quoted string literal (detected at line 1)"
              } else {
                "unterminated string literal (detected at line 1)"
              },
            )
          }
          let d = chars[k]
          if d == quote {
            if !triple {
              k += 1
              break
            }
            if k + 2 < n && chars[k + 1] == quote && chars[k + 2] == quote {
              k += 3
              break
            }
          }
          if d == '\\' && k + 1 < n {
            if raw {
              buf.write_char(d)
              buf.write_char(chars[k + 1])
              k += 2
            } else {
              k = lit_escape(chars, k + 1, buf, prefix.contains("b"))
            }
            continue
          }
          buf.write_char(d)
          k += 1
        }
        tokens.push(
          TStr(
            buf.to_string(),
            if prefix.contains("u") {
              Some("u")
            } else {
              None
            },
            prefix.contains("b"),
          ),
        )
        i = k
        continue
      }
    }
    if is_name_start(c) {
      let mut k = i
      while k < n && is_name_char(chars[k]) {
        k += 1
      }
      tokens.push(TName(String::from_array(chars[i:k])))
      i = k
      continue
    }
    if c is ('0'..='9') ||
      (c == '.' && i + 1 < n && chars[i + 1] is ('0'..='9')) {
      let mut k = i
      if c == '0' &&
        i + 1 < n &&
        chars[i + 1] is ('x' | 'X' | 'o' | 'O' | 'b' | 'B') {
        k = i + 2
        while k < n && chars[k] is ('0'..='9' | 'a'..='f' | 'A'..='F' | '_') {
          k += 1
        }
      } else {
        while k < n && chars[k] is ('0'..='9' | '_') {
          k += 1
        }
        if k < n && chars[k] == '.' {
          k += 1
          while k < n && chars[k] is ('0'..='9' | '_') {
            k += 1
          }
        }
        if k < n && chars[k] is ('e' | 'E') {
          let mut e = k + 1
          if e < n && chars[e] is ('+' | '-') {
            e += 1
          }
          if e < n && chars[e] is ('0'..='9') {
            k = e
            while k < n && chars[k] is ('0'..='9' | '_') {
              k += 1
            }
          }
        }
        if k < n && chars[k] is ('j' | 'J') {
          k += 1
        }
      }
      if k < n && is_name_char(chars[k]) {
        raise LitSyntax("invalid decimal literal")
      }
      tokens.push(TNum(String::from_array(chars[i:k])))
      i = k
      continue
    }
    match c {
      '(' | '[' | '{' => brackets.push(c)
      ')' | ']' | '}' =>
        match brackets.pop() {
          None => raise LitSyntax("unmatched '\{c}'")
          Some(open) =>
            if bracket_close(open) != c {
              raise LitSyntax(
                "closing parenthesis '\{c}' does not match opening parenthesis '\{open}'",
              )
            }
        }
      _ => ()
    }
    let two = if i + 1 < n { String::from_array(chars[i:i + 2]) } else { "" }
    if two is ("**" | "//") {
      tokens.push(TOp(two))
      i += 2
    } else {
      tokens.push(TOp(c.to_string()))
      i += 1
    }
  }
  if brackets.pop() is Some(open) {
    raise LitSyntax("'\{open}' was never closed")
  }
  tokens.push(TEnd)
  tokens
}

///|
/// Process the escape sequence after a backslash at `k`; returns the index
/// after it.
fn lit_escape(
  chars : Array[Char],
  k : Int,
  buf : StringBuilder,
  bytes : Bool,
) -> Int raise LitError {
  let n = chars.length()
  let e = chars[k]
  fn hex(start : Int, count : Int) -> Int raise LitError {
    if start + count > n {
      raise LitSyntax("truncated escape")
    }
    let mut v = 0
    for idx in start..<(start + count) {
      let d = match chars[idx] {
        '0'..='9' as d => d.to_int() - '0'.to_int()
        'a'..='f' as d => d.to_int() - 'a'.to_int() + 10
        'A'..='F' as d => d.to_int() - 'A'.to_int() + 10
        _ => raise LitSyntax("truncated escape")
      }
      v = v * 16 + d
    }
    v
  }

  match e {
    '\n' => k + 1
    '\\' | '\'' | '"' => {
      buf.write_char(e)
      k + 1
    }
    'n' => {
      buf.write_char('\n')
      k + 1
    }
    't' => {
      buf.write_char('\t')
      k + 1
    }
    'r' => {
      buf.write_char('\r')
      k + 1
    }
    'a' => {
      buf.write_char('\u{07}')
      k + 1
    }
    'b' => {
      buf.write_char('\u{08}')
      k + 1
    }
    'f' => {
      buf.write_char('\u{0c}')
      k + 1
    }
    'v' => {
      buf.write_char('\u{0b}')
      k + 1
    }
    '0'..='7' => {
      let mut v = 0
      let mut idx = k
      while idx < n && idx < k + 3 && chars[idx] is ('0'..='7') {
        v = v * 8 + (chars[idx].to_int() - '0'.to_int())
        idx += 1
      }
      buf.write_char(v.unsafe_to_char())
      idx
    }
    'x' => {
      buf.write_char(hex(k + 1, 2).unsafe_to_char())
      k + 3
    }
    'u' if !bytes => {
      buf.write_char(hex(k + 1, 4).unsafe_to_char())
      k + 5
    }
    'U' if !bytes => {
      buf.write_char(hex(k + 1, 8).unsafe_to_char())
      k + 9
    }
    _ => {
      buf.write_char('\\')
      buf.write_char(e)
      k + 1
    }
  }
}

///|
/// A node of the (Python) expression AST.
priv enum LitNode {
  Const(PyValue, String?)
  Name(String)
  Attr(LitNode, String)
  Call(LitNode, Array[LitNode])
  BinOp(LitNode, String, LitNode)
  Unary(String, LitNode)
  TupleN(Array[LitNode])
  ListN(Array[LitNode])
  SetN(Array[LitNode])
  DictN(Array[LitNode], Array[LitNode])
}

///|
/// Python `repr()` of the AST node (as in the `malformed node` message).
fn LitNode::repr(self : LitNode) -> String {
  fn list(nodes : Array[LitNode]) -> String {
    "[" + nodes.map(LitNode::repr).join(", ") + "]"
  }

  match self {
    Const(v, kind) => {
      let kind = match kind {
        Some(k) => py_repr(k)
        None => "None"
      }
      "Constant(value=\{v.repr()}, kind=\{kind})"
    }
    Name(id) => "Name(id=\{py_repr(id)}, ctx=Load())"
    Attr(value, attr) =>
      "Attribute(value=\{value.repr()}, attr=\{py_repr(attr)}, ctx=Load())"
    Call(func, args) =>
      "Call(func=\{func.repr()}, args=\{list(args)}, keywords=[])"
    BinOp(left, op, right) =>
      "BinOp(left=\{left.repr()}, op=\{op}(), right=\{right.repr()})"
    Unary(op, operand) => "UnaryOp(op=\{op}(), operand=\{operand.repr()})"
    TupleN(elts) => "Tuple(elts=\{list(elts)}, ctx=Load())"
    ListN(elts) => "List(elts=\{list(elts)}, ctx=Load())"
    SetN(elts) => "Set(elts=\{list(elts)})"
    DictN(keys, values) => "Dict(keys=\{list(keys)}, values=\{list(values)})"
  }
}

///|
priv struct LitParser {
  tokens : Array[LitTok]
  mut pos : Int
}

///|
fn LitParser::peek(self : LitParser) -> LitTok {
  self.tokens[self.pos]
}

///|
fn LitParser::is_op(self : LitParser, op : String) -> Bool {
  self.tokens[self.pos] is TOp(o) && o == op
}

///|
fn LitParser::expect_op(self : LitParser, op : String) -> Unit raise LitError {
  if self.is_op(op) {
    self.pos += 1
  } else {
    raise LitSyntax("invalid syntax")
  }
}

///|
/// `expr (',' expr)* [',']` up to (not including) a token for which
/// `at_end` is true; a tuple if there is a comma.
fn LitParser::parse_exprlist(
  self : LitParser,
  at_end : (LitTok) -> Bool,
) -> LitNode raise LitError {
  let first = self.parse_expr()
  if !self.is_op(",") {
    return first
  }
  let items = [first]
  while self.is_op(",") {
    self.pos += 1
    if at_end(self.peek()) {
      break
    }
    items.push(self.parse_expr())
  }
  TupleN(items)
}

///|
fn LitParser::parse_expr(self : LitParser) -> LitNode raise LitError {
  let mut left = self.parse_term()
  while self.peek() is TOp("+" | "-" as op) {
    self.pos += 1
    let right = self.parse_term()
    left = BinOp(left, if op == "+" { "Add" } else { "Sub" }, right)
  }
  left
}

///|
fn LitParser::parse_term(self : LitParser) -> LitNode raise LitError {
  let mut left = self.parse_factor()
  while self.peek() is TOp("*" | "/" | "//" | "%" as op) {
    self.pos += 1
    let right = self.parse_factor()
    let name = match op {
      "*" => "Mult"
      "/" => "Div"
      "//" => "FloorDiv"
      _ => "Mod"
    }
    left = BinOp(left, name, right)
  }
  left
}

///|
fn LitParser::parse_factor(self : LitParser) -> LitNode raise LitError {
  match self.peek() {
    TOp("+" | "-" | "~" as op) => {
      self.pos += 1
      let operand = self.parse_factor()
      let name = match op {
        "+" => "UAdd"
        "-" => "USub"
        _ => "Invert"
      }
      Unary(name, operand)
    }
    _ => {
      let base = self.parse_primary()
      if self.is_op("**") {
        self.pos += 1
        BinOp(base, "Pow", self.parse_factor())
      } else {
        base
      }
    }
  }
}

///|
fn LitParser::parse_primary(self : LitParser) -> LitNode raise LitError {
  let mut node = self.parse_atom()
  while true {
    if self.is_op(".") {
      self.pos += 1
      match self.peek() {
        TName(attr) => {
          self.pos += 1
          node = Attr(node, attr)
        }
        _ => raise LitSyntax("invalid syntax")
      }
    } else if self.is_op("(") {
      self.pos += 1
      let args = []
      while !self.is_op(")") {
        args.push(self.parse_expr())
        if self.is_op(",") {
          self.pos += 1
        } else if !self.is_op(")") {
          raise LitSyntax("invalid syntax")
        }
      }
      self.pos += 1
      node = Call(node, args)
    } else {
      break
    }
  }
  node
}

///|
fn parse_number(s : String) -> PyValue raise LitError {
  let digits = s.replace_all(old="_", new="")
  let lower = digits.to_lower()
  if lower.has_suffix("j") {
    raise LitValue("complex numbers are not supported")
  }
  if lower.has_prefix("0x") || lower.has_prefix("0o") || lower.has_prefix("0b") {
    let base = match lower[1] {
      'x' => 16
      'o' => 8
      _ => 2
    }
    let mut v = 0L
    for c in lower.view(start_offset=2) {
      let d = match c {
        '0'..='9' => c.to_int() - '0'.to_int()
        'a'..='f' => c.to_int() - 'a'.to_int() + 10
        _ => base
      }
      if d >= base {
        raise LitSyntax("invalid syntax")
      }
      v = v * base.to_int64() + d.to_int64()
    }
    return PyInt(v)
  }
  if lower.contains(".") || lower.contains("e") {
    return PyFloat(@string.parse_double(digits)) catch {
      _ => raise LitSyntax("invalid syntax")
    }
  }
  if lower.length() > 1 &&
    lower.has_prefix("0") &&
    lower.iter().any(c => c != '0') {
    raise LitSyntax(
      "leading zeros in decimal integer literals are not permitted; use an 0o prefix for octal integers",
    )
  }
  PyInt(@string.parse_int64(digits)) catch {
    _ => raise LitValue("integer too large")
  }
}

///|
fn LitParser::parse_atom(self : LitParser) -> LitNode raise LitError {
  let tok = self.peek()
  self.pos += 1
  match tok {
    TName("True") => Const(PyBool(true), None)
    TName("False") => Const(PyBool(false), None)
    TName("None") => Const(PyNone, None)
    TName(name) => Name(name)
    TNum(s) => Const(parse_number(s), None)
    TStr(s, kind, bytes) => {
      let buf = StringBuilder()
      buf.write_string(s)
      while self.peek() is TStr(more, _, more_bytes) {
        if more_bytes != bytes {
          raise LitSyntax("cannot mix bytes and nonbytes literals")
        }
        buf.write_string(more)
        self.pos += 1
      }
      Const(
        if bytes {
          PyBytes(buf.to_string())
        } else {
          PyStr(buf.to_string())
        },
        kind,
      )
    }
    TOp("(") => {
      if self.is_op(")") {
        self.pos += 1
        return TupleN([])
      }
      let node = self.parse_exprlist(t => t is TOp(")"))
      self.expect_op(")")
      node
    }
    TOp("[") => {
      let items = []
      while !self.is_op("]") {
        items.push(self.parse_expr())
        if self.is_op(",") {
          self.pos += 1
        } else if !self.is_op("]") {
          raise LitSyntax("invalid syntax")
        }
      }
      self.pos += 1
      ListN(items)
    }
    TOp("{") => {
      if self.is_op("}") {
        self.pos += 1
        return DictN([], [])
      }
      let first = self.parse_expr()
      if self.is_op(":") {
        let keys = []
        let values = []
        let mut key = first
        while true {
          self.expect_op(":")
          if self.is_op(",") || self.is_op("}") {
            raise LitSyntax("expression expected after dictionary key and ':'")
          }
          keys.push(key)
          values.push(self.parse_expr())
          if self.is_op(",") {
            self.pos += 1
          }
          if self.is_op("}") {
            self.pos += 1
            break
          }
          key = self.parse_expr()
        }
        DictN(keys, values)
      } else {
        let items = [first]
        while self.is_op(",") {
          self.pos += 1
          if self.is_op("}") {
            break
          }
          items.push(self.parse_expr())
        }
        self.expect_op("}")
        SetN(items)
      }
    }
    _ => raise LitSyntax("invalid syntax")
  }
}

///|
fn malformed(node : LitNode) -> LitError {
  LitValue("malformed node or string on line 1: \{node.repr()}")
}

///|
fn convert_num(node : LitNode) -> PyValue raise LitError {
  match node {
    Const(PyInt(_) as v, _) | Const(PyFloat(_) as v, _) => v
    _ => raise malformed(node)
  }
}

///|
fn convert_signed_num(node : LitNode) -> PyValue raise LitError {
  match node {
    Unary("UAdd" | "USub" as op, operand) => {
      let v = convert_num(operand)
      if op == "UAdd" {
        v
      } else {
        match v {
          PyInt(n) => PyInt(-n)
          PyFloat(f) => PyFloat(-f)
          _ => v
        }
      }
    }
    _ => convert_num(node)
  }
}

///|
fn convert_node(node : LitNode) -> PyValue raise LitError {
  match node {
    Const(v, _) => v
    TupleN(elts) => PyTuple(elts.map(convert_node))
    ListN(elts) => PyList(elts.map(convert_node))
    SetN(elts) => PySet(elts.map(convert_node))
    Call(Name("set"), []) => PySet([])
    DictN(keys, values) => {
      let items = []
      for i, k in keys {
        items.push((convert_node(k), convert_node(values[i])))
      }
      PyDict(items)
    }
    BinOp(left, "Add" | "Sub", right) => {
      ignore(convert_signed_num(left))
      ignore(convert_num(right))
      // only `real +/- complex` is accepted upstream
      convert_signed_num(node)
    }
    _ => convert_signed_num(node)
  }
}

///|
fn literal_eval_impl(source : String) -> PyValue raise LitError {
  let source = source.trim_start(chars=" \t").to_owned()
  let p = LitParser::{ tokens: lit_tokenize(source), pos: 0, }
  if p.peek() is TEnd {
    raise LitSyntax("invalid syntax")
  }
  let node = p.parse_exprlist(t => t is TEnd)
  if !(p.peek() is TEnd) {
    raise LitSyntax("invalid syntax")
  }
  convert_node(node)
}

///|
/// A subset of Python's `ast.literal_eval`: numbers (not complex),
/// strings and bytes, `True`, `False`, `None`, tuples, lists, sets and
/// dicts. Errors are `ValueError`s carrying the upstream message.
pub fn literal_eval(source : String) -> PyValue raise RichError {
  literal_eval_impl(source) catch {
    LitSyntax(msg) => raise ValueError(msg)
    LitValue(msg) => raise ValueError(msg)
  }
}
