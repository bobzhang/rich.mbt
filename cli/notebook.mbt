// `render_ipynb`: a Jupyter notebook as a group of renderables.

///|
/// The notebook does not have the expected structure.
priv suberror NotebookFormat

///|
fn json_get(value : @rich.JsonValue?, key : String) -> @rich.JsonValue? {
  match value {
    Some(JObject(fields)) => {
      // like a Python dict, a repeated key keeps the last value
      let mut found = None
      for field in fields {
        if field.0 == key {
          found = Some(field.1)
        }
      }
      found
    }
    _ => None
  }
}

///|
/// `sep.join(value)` for a string or a list of strings.
fn json_join(
  value : @rich.JsonValue?,
  sep : String,
) -> String raise NotebookFormat {
  match value {
    Some(JString(s)) => s.to_array().map(c => c.to_string()).join(sep)
    Some(JArray(items)) =>
      items
      .map(item => {
        match item {
          JString(s) => s
          _ => raise NotebookFormat
        }
      })
      .join(sep)
    _ => raise NotebookFormat
  }
}

///|
/// Python truthiness of a JSON value.
fn json_truthy(value : @rich.JsonValue?) -> Bool {
  match value {
    None | Some(JNull) | Some(JBool(false)) => false
    Some(JInt(s)) => s.to_array().any(c => c is ('1'..='9'))
    Some(JFloat(d)) => d != 0.0
    Some(JString(s)) => s != ""
    Some(JArray(a)) => a.length() > 0
    Some(JObject(o)) => o.length() > 0
    _ => true
  }
}

///|
/// `str(value)` for an execution count.
fn json_str(value : @rich.JsonValue) -> String {
  match value {
    JInt(s) => s
    JFloat(d) => @rich.py_float_repr(d)
    JString(s) => s
    JBool(b) => if b { "True" } else { "False" }
    JNull => "None"
    _ => "..."
  }
}

///|
/// Render the resource as a Jupyter notebook (`render_ipynb`).
fn Context::render_ipynb(
  self : Context,
  resource : String,
  input : Result[String, String]?,
) -> &@rich.Renderable raise Exit {
  let opts = self.options
  let (notebook_str, _) = self.read_resource(resource, None, input)
  let notebook = Some(
    @rich.JsonValue::parse(notebook_str) catch {
      e => {
        self.on_error(
          "unable to read notebook",
          error=json_error(e, notebook_str),
        )
        JNull
      }
    },
  )
  let lexer = match opts.lexer {
    Some(l) if l != "" => l
    _ =>
      match
        json_get(
          json_get(json_get(notebook, "metadata"), "kernelspec"),
          "language",
        ) {
        Some(JString(l)) => l
        _ => ""
      }
  }
  self.notebook_cells(notebook, lexer) catch {
    NotebookFormat => {
      self.on_error("unable to read notebook", error="invalid notebook format")
      ""
    }
    Exit(_) as e => raise e
    e => {
      self.on_error("unable to read notebook", error=e.to_string())
      ""
    }
  }
}

///|
fn Context::notebook_cells(
  self : Context,
  notebook : @rich.JsonValue?,
  lexer : String,
) -> &@rich.Renderable raise {
  let opts = self.options
  guard json_get(notebook, "cells") is Some(JArray(cell_list)) else {
    raise NotebookFormat
  }
  let mut new_line = true
  let cells : Array[&@rich.Renderable] = []
  for cell_value in cell_list {
    let cell = Some(cell_value)
    if new_line {
      cells.push("")
    }
    if json_get(cell, "execution_count") is Some(count) {
      let count = if json_truthy(Some(count)) { json_str(count) } else { " " }
      cells.push("[green]In [[#66ff00]\{count}[/#66ff00]]:[/green]")
    }
    let source = json_join(json_get(cell, "source"), "")
    let renderable : &@rich.Renderable = match json_get(cell, "cell_type") {
      Some(JString("code")) => {
        let line_range = self.line_range(count_lines(source))
        let syntax = @syntax.Syntax::new(
          source,
          lexer,
          theme=opts.theme,
          line_numbers=opts.line_numbers,
          indent_guides=opts.guides,
          word_wrap=!opts.no_wrap,
          line_range?,
        )
        (@panel.Panel::new(syntax, border_style="dim") : &@rich.Renderable)
      }
      Some(JString("markdown")) =>
        (make_markdown(source, opts.theme, opts.hyperlinks) : &@rich.Renderable)
      _ => (@rich.Text::new(text=source) : &@rich.Renderable)
    }
    new_line = true
    cells.push(renderable)
    let outputs = match json_get(cell, "outputs") {
      Some(JArray(outputs)) => outputs
      _ => []
    }
    for output_value in outputs {
      let output = Some(output_value)
      let renderable : &@rich.Renderable = match
        json_get(output, "output_type") {
        Some(JString("stream")) => {
          new_line = false
          @rich.Text::from_ansi(json_join(json_get(output, "text"), ""))
        }
        Some(JString("error")) => {
          new_line = true
          let traceback = json_join(json_get(output, "traceback"), "\n")
          @rich.Text::from_ansi(py_rstrip(traceback))
        }
        Some(JString("execute_result")) => {
          let count = match json_get(output, "execution_count") {
            Some(c) if json_truthy(Some(c)) => json_str(c)
            _ => " "
          }
          let text = @rich.Text::from_markup(
            "[red]Out[[#ee4b2b]\{count}[/#ee4b2b]]:[/red]\n",
          )
          let data = match json_get(json_get(output, "data"), "text/plain") {
            Some(JArray(_)) as d => json_join(d, "")
            Some(JString(s)) => s
            None => ""
            _ => raise NotebookFormat
          }
          new_line = true
          text.copy().append_text(@rich.Text::from_ansi(data))
        }
        _ => continue
      }
      cells.push(renderable)
    }
  }
  @rich.Group::new(cells)
}

///|
/// Python's `str.rstrip()`.
fn py_rstrip(s : String) -> String {
  let chars = s.to_array()
  let mut end = chars.length()
  while end > 0 && is_py_space(chars[end - 1]) {
    end -= 1
  }
  String::from_array(chars[:end])
}
