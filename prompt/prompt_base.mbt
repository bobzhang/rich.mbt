// Port of rich/prompt.py: PromptBase.

///|
/// Raise within `process_response` to indicate that a response was invalid;
/// the message is printed (with markup) and the user is prompted again
/// (upstream `InvalidResponse`, a subclass of `PromptError`).
pub(all) suberror InvalidResponse {
  InvalidResponse(@rich.TextType)
}

///|
/// The message of an `InvalidResponse` (upstream `InvalidResponse.message`).
pub fn InvalidResponse::message(self : InvalidResponse) -> @rich.TextType {
  match self {
    InvalidResponse(message) => message
  }
}

///|
/// Ask the user for input until a valid response is received (upstream
/// `PromptBase[PromptType]`).
///
/// The upstream subclasses `Prompt`, `IntPrompt`, `FloatPrompt` and
/// `Confirm` are constructors of `PromptBase[String]`, `PromptBase[Int]`,
/// `PromptBase[Double]` and `PromptBase[Bool]`. Upstream class attributes
/// and overridable methods are fields:
///
/// * `response_type` converts the (stripped) response, `None` where the
///   upstream `response_type(value)` raises `ValueError`;
/// * `to_str` is `str(default)`, used by the default `render_default`;
/// * `render_default_fn`, `process_response_fn`, `pre_prompt_fn` and
///   `get_input` override the corresponding upstream methods.
pub(all) struct PromptBase[T] {
  mut console : @rich.Console
  mut prompt : @rich.Text
  mut password : Bool
  mut choices : Array[String]?
  mut case_sensitive : Bool
  mut show_default : Bool
  mut show_choices : Bool
  mut validate_error_message : String
  mut illegal_choice_message : String
  mut prompt_suffix : String
  mut response_type : (String) -> T?
  mut to_str : (T) -> String
  mut render_default_fn : ((PromptBase[T], T) -> @rich.Text)?
  mut process_response_fn : ((PromptBase[T], String) -> T raise InvalidResponse)?
  mut pre_prompt_fn : ((PromptBase[T]) -> Unit raise)?
  mut get_input : InputFn
}

///|
/// Create a prompt. `prompt` strings are parsed as markup with the style
/// `"prompt"`; `console` defaults to the global console.
pub fn[T] PromptBase::new(
  prompt : &@rich.IntoText,
  console? : @rich.Console,
  password? : Bool = false,
  choices? : Array[String],
  case_sensitive? : Bool = true,
  show_default? : Bool = true,
  show_choices? : Bool = true,
  response_type~ : (String) -> T?,
  to_str~ : (T) -> String,
  validate_error_message? : String = "[prompt.invalid]Please enter a valid value",
  illegal_choice_message? : String = "[prompt.invalid.choice]Please select one of the available options",
  prompt_suffix? : String = ": ",
  render_default? : (PromptBase[T], T) -> @rich.Text,
  process_response? : (PromptBase[T], String) -> T raise InvalidResponse,
  pre_prompt? : (PromptBase[T]) -> Unit raise,
  get_input? : InputFn = get_input,
) -> PromptBase[T] raise {
  let console = match console {
    Some(c) => c
    None => @rich.get_console()
  }
  let prompt = match prompt.into_text_type() {
    Str(s) => @rich.Text::from_markup(s, style="prompt")
    Text(t) => t
  }
  {
    console,
    prompt,
    password,
    choices,
    case_sensitive,
    show_default,
    show_choices,
    validate_error_message,
    illegal_choice_message,
    prompt_suffix,
    response_type,
    to_str,
    render_default_fn: render_default,
    process_response_fn: process_response,
    pre_prompt_fn: pre_prompt,
    get_input,
  }
}

///|
/// Turn the supplied default in to a Text instance (`(default)` in the
/// style `"prompt.default"`).
pub fn[T] PromptBase::render_default(
  self : PromptBase[T],
  default : T,
) -> @rich.Text {
  match self.render_default_fn {
    Some(f) => f(self, default)
    None =>
      @rich.Text::new(
        text="(\{(self.to_str)(default)})",
        style="prompt.default",
      )
  }
}

///|
/// Make the prompt text: the prompt, the choices, the default and the
/// prompt suffix.
pub fn[T] PromptBase::make_prompt(
  self : PromptBase[T],
  default? : T,
) -> @rich.Text {
  let prompt = self.prompt.copy()
  prompt.end = ""
  if self.show_choices && self.choices is Some(choices) && choices.length() > 0 {
    let choices = "[\{choices.join("/")}]"
    prompt.append_str(" ") |> ignore
    prompt.append_str(choices, style="prompt.choices") |> ignore
  }
  if default is Some(default) && self.show_default {
    prompt.append_str(" ") |> ignore
    prompt.append_text(self.render_default(default)) |> ignore
  }
  prompt.append_str(self.prompt_suffix) |> ignore
  prompt
}

///|
/// Check value is in the list of valid choices.
///
/// Panics if the prompt has no choices (upstream asserts).
pub fn[T] PromptBase::check_choice(
  self : PromptBase[T],
  value : String,
) -> Bool {
  guard self.choices is Some(choices) else { abort("prompt has no choices") }
  let value = py_strip(value)
  if self.case_sensitive {
    choices.contains(value)
  } else {
    let value = @pystr.lower(value)
    choices.iter().any(choice => @pystr.lower(choice) == value)
  }
}

///|
/// Process the response from the user and convert it to the prompt type
/// (the upstream base implementation, ignoring `process_response_fn`).
pub fn[T] PromptBase::convert_response(
  self : PromptBase[T],
  value : String,
) -> T raise InvalidResponse {
  let value = py_strip(value)
  guard (self.response_type)(value) is Some(return_value) else {
    raise InvalidResponse(Str(self.validate_error_message))
  }
  guard self.choices is Some(choices) else { return_value }
  if !self.check_choice(value) {
    raise InvalidResponse(Str(self.illegal_choice_message))
  }
  if self.case_sensitive {
    return_value
  } else {
    // return the original choice, not the lower case version
    let lower = @pystr.lower(value)
    let index = choices
      .search_by(choice => @pystr.lower(choice) == lower)
      .unwrap_or(0)
    match (self.response_type)(choices[index]) {
      Some(v) => v
      None => return_value
    }
  }
}

///|
/// Process the response from the user, convert it to the prompt type.
/// Raises `InvalidResponse` if the value is invalid.
pub fn[T] PromptBase::process_response(
  self : PromptBase[T],
  value : String,
) -> T raise InvalidResponse {
  match self.process_response_fn {
    Some(f) => f(self, value)
    None => self.convert_response(value)
  }
}

///|
/// Called to handle a validation error: prints the error message (with
/// markup).
pub fn[T] PromptBase::on_validate_error(
  self : PromptBase[T],
  value : String,
  error : InvalidResponse,
) -> Unit raise {
  ignore(value)
  match error.message() {
    Str(s) => self.console.print(s, markup=true)
    Text(t) => self.console.print(t, markup=true)
  }
}

///|
/// Hook to display something before the prompt.
pub fn[T] PromptBase::pre_prompt(self : PromptBase[T]) -> Unit raise {
  if self.pre_prompt_fn is Some(f) {
    f(self)
  }
}

///|
/// Run the prompt loop (upstream `__call__`). An empty response returns
/// `default` when given. `stream` is an optional stream to read the
/// responses from instead of stdin.
pub fn[T] PromptBase::call(
  self : PromptBase[T],
  default? : T,
  stream? : InputStream,
) -> T raise {
  for ;; {
    self.pre_prompt()
    let prompt = self.make_prompt(default?)
    let value = (self.get_input)(self.console, prompt, self.password, stream)
    if value == "" && default is Some(default) {
      return default
    }
    let return_value = self.process_response(value) catch {
      error => {
        self.on_validate_error(value, error)
        continue
      }
    }
    return return_value
  }
}
