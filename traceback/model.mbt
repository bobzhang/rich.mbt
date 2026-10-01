// The traceback data model (rich/traceback.py dataclasses Frame,
// _SyntaxError, Stack, Trace). MoonBit has no runtime frames, so callers
// build these values themselves (or load them from Python-like data with
// `Trace::from_json`).

///|
/// A stack frame.
pub(all) struct Frame {
  /// File name of the source.
  filename : String
  /// Line number (1-based).
  lineno : Int
  /// Function name.
  name : String
  /// Source line.
  line : String
  /// Local variables (pretty printer nodes, e.g. from `@pretty.traverse`),
  /// or `None` when locals were not captured.
  locals : Map[String, @pretty.Node]?
  /// Position of the last instruction: ((start line, start column),
  /// (end line, end column)); columns are UTF-16 offsets.
  last_instruction : ((Int, Int), (Int, Int))?
}

///|
pub fn Frame::new(
  filename : String,
  lineno : Int,
  name : String,
  line? : String = "",
  locals? : Map[String, @pretty.Node],
  last_instruction? : ((Int, Int), (Int, Int)),
) -> Frame {
  { filename, lineno, name, line, locals, last_instruction, }
}

///|
/// Information about a syntax error (upstream `_SyntaxError`).
pub(all) struct SyntaxErrorInfo {
  offset : Int
  filename : String
  line : String
  lineno : Int
  msg : String
  notes : Array[String]
}

///|
pub fn SyntaxErrorInfo::new(
  offset~ : Int,
  filename~ : String,
  line~ : String,
  lineno~ : Int,
  msg~ : String,
  notes? : Array[String] = [],
) -> SyntaxErrorInfo {
  { offset, filename, line, lineno, msg, notes, }
}

///|
/// One exception and its frames.
pub(all) struct Stack {
  /// Exception type name.
  exc_type : String
  /// Exception message (`str(exception)`).
  exc_value : String
  syntax_error : SyntaxErrorInfo?
  /// Whether this exception was the direct cause of the next one.
  is_cause : Bool
  frames : Array[Frame]
  notes : Array[String]
  /// Whether this is an exception group.
  is_group : Bool
  /// Sub-exceptions of a group.
  exceptions : Array[Trace]
}

///|
pub fn Stack::new(
  exc_type : String,
  exc_value : String,
  syntax_error? : SyntaxErrorInfo,
  is_cause? : Bool = false,
  frames? : Array[Frame] = [],
  notes? : Array[String] = [],
  is_group? : Bool = false,
  exceptions? : Array[Trace] = [],
) -> Stack {
  {
    exc_type,
    exc_value,
    syntax_error,
    is_cause,
    frames,
    notes,
    is_group,
    exceptions,
  }
}

///|
/// A chain of exceptions, the first one being the last raised (as
/// upstream's `Traceback.extract` produces them).
pub(all) struct Trace {
  stacks : Array[Stack]
}

///|
pub fn Trace::new(stacks : Array[Stack]) -> Trace {
  { stacks, }
}

///|
/// A trace for a MoonBit error value: one stack without frames whose type is
/// `exc_type` (default `"Error"`) and whose message is the error's `Show`
/// output.
pub fn Trace::from_error(
  error : Error,
  exc_type? : String = "Error",
  frames? : Array[Frame] = [],
) -> Trace {
  { stacks: [Stack::new(exc_type, "\{error}", frames~)], }
}

// ---------------------------------------------------------------------------
// Loading from Python-like data

///|
fn bad(what : String) -> @rich.RichError {
  @rich.ValueError("invalid trace data: \{what}")
}

///|
fn json_field(obj : Map[String, Json], key : String) -> Json {
  obj.get(key).unwrap_or(Json::null())
}

///|
fn json_string(j : Json, what : String) -> String raise @rich.RichError {
  match j {
    String(s) => s
    _ => raise bad("\{what} should be a string")
  }
}

///|
fn json_int(j : Json, what : String) -> Int raise @rich.RichError {
  match j {
    Number(n, ..) => n.to_int()
    Null => 0
    _ => raise bad("\{what} should be a number")
  }
}

///|
fn json_bool(j : Json, what : String) -> Bool raise @rich.RichError {
  match j {
    True => true
    False | Null => false
    _ => raise bad("\{what} should be a boolean")
  }
}

///|
fn json_array(j : Json, what : String) -> Array[Json] raise @rich.RichError {
  match j {
    Array(a) => a
    Null => []
    _ => raise bad("\{what} should be an array")
  }
}

///|
fn json_strings(j : Json, what : String) -> Array[String] raise @rich.RichError {
  json_array(j, what).map(s => json_string(s, what))
}

///|
fn json_object(
  j : Json,
  what : String,
) -> Map[String, Json] raise @rich.RichError {
  match j {
    Object(o) => o
    _ => raise bad("\{what} should be an object")
  }
}

///|
fn json_position(j : Json) -> (Int, Int) raise @rich.RichError {
  match json_array(j, "position") {
    [a, b] => (json_int(a, "line"), json_int(b, "column"))
    _ => raise bad("position should be [line, column]")
  }
}

///|
/// A `pretty.Node` from JSON: the dataclass fields of upstream's `Node`, or
/// a plain string (a leaf node showing that repr).
fn node_from_json(j : Json) -> @pretty.Node raise @rich.RichError {
  match j {
    String(s) => @pretty.Node::new(value_repr=s)
    Object(o) => {
      let str_field = (key : String, default : String) => {
        match o.get(key) {
          Some(String(s)) => s
          _ => default
        }
      }
      let bool_field = (key : String) => o.get(key) is Some(True)
      let children = match o.get("children") {
        Some(Array(a)) => Some(a.map(node_from_json))
        _ => None
      }
      @pretty.Node::new(
        key_repr=str_field("key_repr", ""),
        value_repr=str_field("value_repr", ""),
        open_brace=str_field("open_brace", ""),
        close_brace=str_field("close_brace", ""),
        empty=str_field("empty", ""),
        last=bool_field("last"),
        is_tuple=bool_field("is_tuple"),
        is_namedtuple=bool_field("is_namedtuple"),
        children?,
        key_separator=str_field("key_separator", ": "),
        separator=str_field("separator", ", "),
      )
    }
    _ => raise bad("a local should be a node object or a repr string")
  }
}

///|
fn node_to_json(node : @pretty.Node) -> Json {
  {
    "key_repr": node.key_repr.to_json(),
    "value_repr": node.value_repr.to_json(),
    "open_brace": node.open_brace.to_json(),
    "close_brace": node.close_brace.to_json(),
    "empty": node.empty.to_json(),
    "last": node.last.to_json(),
    "is_tuple": node.is_tuple.to_json(),
    "is_namedtuple": node.is_namedtuple.to_json(),
    "children": match node.children {
      None => Json::null()
      Some(c) => Json::array(c.map(node_to_json))
    },
    "key_separator": node.key_separator.to_json(),
    "separator": node.separator.to_json(),
  }
}

///|
fn frame_from_json(j : Json) -> Frame raise @rich.RichError {
  let o = json_object(j, "frame")
  let locals = match json_field(o, "locals") {
    Null => None
    Object(m) => {
      let locals : Map[String, @pretty.Node] = Map([])
      for k, v in m {
        locals[k] = node_from_json(v)
      }
      Some(locals)
    }
    _ => raise bad("locals should be an object")
  }
  let last_instruction = match json_field(o, "last_instruction") {
    Null => None
    j =>
      match json_array(j, "last_instruction") {
        [start, end] => Some((json_position(start), json_position(end)))
        _ => raise bad("last_instruction should be [start, end]")
      }
  }
  {
    filename: json_string(json_field(o, "filename"), "filename"),
    lineno: json_int(json_field(o, "lineno"), "lineno"),
    name: json_string(json_field(o, "name"), "name"),
    line: match json_field(o, "line") {
      Null => ""
      j => json_string(j, "line")
    },
    locals,
    last_instruction,
  }
}

///|
fn syntax_error_from_json(j : Json) -> SyntaxErrorInfo raise @rich.RichError {
  let o = json_object(j, "syntax_error")
  {
    offset: json_int(json_field(o, "offset"), "offset"),
    filename: json_string(json_field(o, "filename"), "filename"),
    line: json_string(json_field(o, "line"), "line"),
    lineno: json_int(json_field(o, "lineno"), "lineno"),
    msg: json_string(json_field(o, "msg"), "msg"),
    notes: json_strings(json_field(o, "notes"), "notes"),
  }
}

///|
fn stack_from_json(j : Json) -> Stack raise @rich.RichError {
  let o = json_object(j, "stack")
  {
    exc_type: json_string(json_field(o, "exc_type"), "exc_type"),
    exc_value: json_string(json_field(o, "exc_value"), "exc_value"),
    syntax_error: match json_field(o, "syntax_error") {
      Null => None
      j => Some(syntax_error_from_json(j))
    },
    is_cause: json_bool(json_field(o, "is_cause"), "is_cause"),
    frames: json_array(json_field(o, "frames"), "frames").map(frame_from_json),
    notes: json_strings(json_field(o, "notes"), "notes"),
    is_group: json_bool(json_field(o, "is_group"), "is_group"),
    exceptions: json_array(json_field(o, "exceptions"), "exceptions").map(
      Trace::from_json,
    ),
  }
}

///|
/// Load a trace from Python-like data: the JSON form of upstream's `Trace`
/// dataclass (`dataclasses.asdict`): each local variable is a `pretty.Node`
/// as a dict of its fields (or just a repr string, for a leaf), and
/// `last_instruction` is `[[line, column], [line, column]]`.
///
/// ```json
/// {"stacks": [{"exc_type": "ZeroDivisionError", "exc_value": "division by zero",
///   "syntax_error": null, "is_cause": false, "notes": [], "is_group": false,
///   "exceptions": [], "frames": [{"filename": "/app.py", "lineno": 3,
///   "name": "main", "line": "", "locals": {"x": {"value_repr": "1"}},
///   "last_instruction": [[3, 4], [3, 9]]}]}]}
/// ```
pub fn Trace::from_json(j : Json) -> Trace raise @rich.RichError {
  let o = json_object(j, "trace")
  {
    stacks: json_array(json_field(o, "stacks"), "stacks").map(stack_from_json),
  }
}

///|
pub impl ToJson for Frame with fn to_json(self) {
  let locals : Json = match self.locals {
    None => Json::null()
    Some(m) => {
      let o : Map[String, Json] = Map([])
      for k, v in m {
        o[k] = node_to_json(v)
      }
      Json::object(o)
    }
  }
  let last_instruction : Json = match self.last_instruction {
    None => Json::null()
    Some(((l1, c1), (l2, c2))) => [[l1, c1], [l2, c2]].to_json()
  }
  {
    "filename": self.filename.to_json(),
    "lineno": self.lineno.to_json(),
    "name": self.name.to_json(),
    "line": self.line.to_json(),
    "locals": locals,
    "last_instruction": last_instruction,
  }
}

///|
pub impl ToJson for SyntaxErrorInfo with fn to_json(self) {
  {
    "offset": self.offset.to_json(),
    "filename": self.filename.to_json(),
    "line": self.line.to_json(),
    "lineno": self.lineno.to_json(),
    "msg": self.msg.to_json(),
    "notes": self.notes.to_json(),
  }
}

///|
pub impl ToJson for Stack with fn to_json(self) {
  {
    "exc_type": self.exc_type.to_json(),
    "exc_value": self.exc_value.to_json(),
    "syntax_error": match self.syntax_error {
      None => Json::null()
      Some(s) => s.to_json()
    },
    "is_cause": self.is_cause.to_json(),
    "frames": self.frames.to_json(),
    "notes": self.notes.to_json(),
    "is_group": self.is_group.to_json(),
    "exceptions": self.exceptions.to_json(),
  }
}

///|
pub impl ToJson for Trace with fn to_json(self) {
  { "stacks": self.stacks.to_json() }
}
