// Input sources for prompts (upstream `PromptBase.get_input` and the
// `stream` argument of `Console.input`).

///|
/// A readable text stream (upstream `stream: TextIO`, typically an
/// `io.StringIO` in tests). Lines are consumed by `readline`.
pub struct InputStream {
  priv text : String
  priv mut pos : Int
}

///|
/// Create a stream that reads from `text`.
pub fn InputStream::new(text : String) -> InputStream {
  { text, pos: 0, }
}

///|
/// Read the next line including its trailing newline (Python
/// `TextIO.readline`); returns `""` at the end of the stream.
pub fn InputStream::readline(self : InputStream) -> String {
  let len = self.text.length()
  if self.pos >= len {
    return ""
  }
  let start = self.pos
  let mut end = len
  for i in start..<len {
    if self.text[i] == '\n' {
      end = i + 1
      break
    }
  }
  self.pos = end
  self.text.view(start_offset=start, end_offset=end).to_owned()
}

///|
/// The signature of an input function: `(console, prompt, password,
/// stream)` returns the string typed by the user (upstream
/// `PromptBase.get_input`).
pub type InputFn = (@rich.Console, @rich.Text, Bool, InputStream?) -> String raise

///|
/// Get input from the user (upstream `PromptBase.get_input`, which calls
/// `console.input(prompt, password=password, stream=stream)`).
///
/// Without a stream this is `Console::input` (reads a line from stdin, the
/// newline is removed). With a stream the prompt is printed and a line is
/// read with `readline` semantics: the trailing newline is kept and the
/// result is `""` at the end of the stream, as upstream.
pub fn get_input(
  console : @rich.Console,
  prompt : @rich.Text,
  password : Bool,
  stream : InputStream?,
) -> String raise {
  match stream {
    None => console.input(prompt~, password~)
    Some(stream) => {
      if prompt.to_bool() {
        console.print(prompt, end="")
      }
      let line = stream.readline()
      match line.strip_suffix("\n") {
        // getpass does not return the newline
        Some(l) if password => l.to_owned()
        _ => line
      }
    }
  }
}
