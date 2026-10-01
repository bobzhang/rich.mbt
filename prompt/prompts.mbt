// Port of rich/prompt.py: Prompt, IntPrompt, FloatPrompt and Confirm.
//
// Upstream these are subclasses of `PromptBase`; here they are namespaces
// whose `new` builds a `PromptBase[T]` with the class attributes of the
// upstream subclass and whose `ask` is the upstream `ask` classmethod.

///|
/// A prompt that returns a `String`.
///
/// ```mbt nocheck
/// let name = @prompt.Prompt::ask("Enter your name")
/// ```
pub(all) struct Prompt {}

///|
/// Create a prompt that returns a `String` (see `PromptBase::new`).
pub fn Prompt::new(
  prompt : &@rich.IntoText,
  console? : @rich.Console,
  password? : Bool = false,
  choices? : Array[String],
  case_sensitive? : Bool = true,
  show_default? : Bool = true,
  show_choices? : Bool = true,
  get_input? : InputFn = get_input,
) -> PromptBase[String] raise {
  PromptBase::new(
    prompt,
    console?,
    password~,
    choices?,
    case_sensitive~,
    show_default~,
    show_choices~,
    response_type=s => Some(s),
    to_str=s => s,
    get_input~,
  )
}

///|
/// Shortcut to construct and run a prompt loop and return the result.
pub fn Prompt::ask(
  prompt : &@rich.IntoText,
  console? : @rich.Console,
  password? : Bool = false,
  choices? : Array[String],
  case_sensitive? : Bool = true,
  show_default? : Bool = true,
  show_choices? : Bool = true,
  default? : String,
  stream? : InputStream,
  get_input? : InputFn = get_input,
) -> String raise {
  Prompt::new(
    prompt,
    console?,
    password~,
    choices?,
    case_sensitive~,
    show_default~,
    show_choices~,
    get_input~,
  ).call(default?, stream?)
}

///|
/// A prompt that returns an integer.
pub(all) struct IntPrompt {}

///|
/// Create a prompt that returns an `Int` (see `PromptBase::new`).
pub fn IntPrompt::new(
  prompt : &@rich.IntoText,
  console? : @rich.Console,
  password? : Bool = false,
  choices? : Array[String],
  case_sensitive? : Bool = true,
  show_default? : Bool = true,
  show_choices? : Bool = true,
  get_input? : InputFn = get_input,
) -> PromptBase[Int] raise {
  PromptBase::new(
    prompt,
    console?,
    password~,
    choices?,
    case_sensitive~,
    show_default~,
    show_choices~,
    response_type=py_int,
    to_str=n => n.to_string(),
    validate_error_message="[prompt.invalid]Please enter a valid integer number",
    get_input~,
  )
}

///|
/// Shortcut to construct and run an integer prompt loop.
pub fn IntPrompt::ask(
  prompt : &@rich.IntoText,
  console? : @rich.Console,
  password? : Bool = false,
  choices? : Array[String],
  case_sensitive? : Bool = true,
  show_default? : Bool = true,
  show_choices? : Bool = true,
  default? : Int,
  stream? : InputStream,
  get_input? : InputFn = get_input,
) -> Int raise {
  IntPrompt::new(
    prompt,
    console?,
    password~,
    choices?,
    case_sensitive~,
    show_default~,
    show_choices~,
    get_input~,
  ).call(default?, stream?)
}

///|
/// A prompt that returns a float.
pub(all) struct FloatPrompt {}

///|
/// Create a prompt that returns a `Double` (see `PromptBase::new`).
pub fn FloatPrompt::new(
  prompt : &@rich.IntoText,
  console? : @rich.Console,
  password? : Bool = false,
  choices? : Array[String],
  case_sensitive? : Bool = true,
  show_default? : Bool = true,
  show_choices? : Bool = true,
  get_input? : InputFn = get_input,
) -> PromptBase[Double] raise {
  PromptBase::new(
    prompt,
    console?,
    password~,
    choices?,
    case_sensitive~,
    show_default~,
    show_choices~,
    response_type=py_float,
    to_str=@rich.py_float_repr,
    validate_error_message="[prompt.invalid]Please enter a number",
    get_input~,
  )
}

///|
/// Shortcut to construct and run a float prompt loop.
pub fn FloatPrompt::ask(
  prompt : &@rich.IntoText,
  console? : @rich.Console,
  password? : Bool = false,
  choices? : Array[String],
  case_sensitive? : Bool = true,
  show_default? : Bool = true,
  show_choices? : Bool = true,
  default? : Double,
  stream? : InputStream,
  get_input? : InputFn = get_input,
) -> Double raise {
  FloatPrompt::new(
    prompt,
    console?,
    password~,
    choices?,
    case_sensitive~,
    show_default~,
    show_choices~,
    get_input~,
  ).call(default?, stream?)
}

///|
/// A yes / no confirmation prompt.
///
/// ```mbt nocheck
/// if @prompt.Confirm::ask("Continue") {
///   run_job()
/// }
/// ```
pub(all) struct Confirm {}

///|
/// Render the default as `(y)` or `(n)` rather than True/False.
fn confirm_render_default(p : PromptBase[Bool], default : Bool) -> @rich.Text {
  let choices = p.choices.unwrap_or([])
  let yes = choices.get(0).unwrap_or("")
  let no = choices.get(1).unwrap_or("")
  @rich.Text::new(
    text=if default { "(\{yes})" } else { "(\{no})" },
    style="prompt.default",
  )
}

///|
/// Convert choices to a bool.
fn confirm_process_response(
  p : PromptBase[Bool],
  value : String,
) -> Bool raise InvalidResponse {
  let value = @pystr.lower(py_strip(value))
  let choices = p.choices.unwrap_or([])
  if !choices.contains(value) {
    raise InvalidResponse(Str(p.validate_error_message))
  }
  value == choices[0]
}

///|
/// Create a yes / no prompt (see `PromptBase::new`). `choices` are the
/// strings for yes and no.
pub fn Confirm::new(
  prompt : &@rich.IntoText,
  console? : @rich.Console,
  password? : Bool = false,
  choices? : Array[String] = ["y", "n"],
  case_sensitive? : Bool = true,
  show_default? : Bool = true,
  show_choices? : Bool = true,
  get_input? : InputFn = get_input,
) -> PromptBase[Bool] raise {
  PromptBase::new(
    prompt,
    console?,
    password~,
    choices~,
    case_sensitive~,
    show_default~,
    show_choices~,
    response_type=s => Some(s != ""),
    to_str=b => if b { "True" } else { "False" },
    validate_error_message="[prompt.invalid]Please enter Y or N",
    render_default=confirm_render_default,
    process_response=confirm_process_response,
    get_input~,
  )
}

///|
/// Shortcut to construct and run a yes / no prompt loop.
pub fn Confirm::ask(
  prompt : &@rich.IntoText,
  console? : @rich.Console,
  password? : Bool = false,
  choices? : Array[String] = ["y", "n"],
  case_sensitive? : Bool = true,
  show_default? : Bool = true,
  show_choices? : Bool = true,
  default? : Bool,
  stream? : InputStream,
  get_input? : InputFn = get_input,
) -> Bool raise {
  Confirm::new(
    prompt,
    console?,
    password~,
    choices~,
    case_sensitive~,
    show_default~,
    show_choices~,
    get_input~,
  ).call(default?, stream?)
}
