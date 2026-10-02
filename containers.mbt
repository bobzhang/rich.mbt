// Port of rich/containers.py and rich/_wrap.py.

///|
/// A list of renderables that renders its contents in order.
pub struct Renderables {
  renderables : Array[&Renderable]
}

///|
pub fn Renderables::new(renderables? : Array[&Renderable] = []) -> Renderables {
  { renderables: renderables.copy(), }
}

///|
/// Iterate over the renderables.
pub fn Renderables::iter(self : Renderables) -> Iter[&Renderable] {
  self.renderables.iter()
}

///|
pub fn Renderables::append(
  self : Renderables,
  renderable : &Renderable,
) -> Unit {
  self.renderables.push(renderable)
}

///|
pub impl Renderable for Renderables with fn rich_console(
  self,
  _console,
  _options,
) {
  self.renderables.map(r => Child(r))
}

///|
pub impl Renderable for Renderables with fn rich_measure(self, console, options) {
  if self.renderables.is_empty() {
    return Some({ minimum: 1, maximum: 1, })
  }
  let mut min = 0
  let mut max = 0
  for i, r in self.renderables {
    let d = Measurement::get(console, options, r)
    if i == 0 {
      min = d.minimum
      max = d.maximum
    } else {
      min = @cmp.maximum(min, d.minimum)
      max = @cmp.maximum(max, d.maximum)
    }
  }
  Some({ minimum: min, maximum: max, })
}

///|
/// A list of `Text` lines which renders each line.
pub struct Lines {
  lines : Array[Text]
}

///|
pub fn Lines::new(lines : ArrayView[Text]) -> Lines {
  { lines: lines.to_owned(), }
}

///|
pub fn Lines::length(self : Lines) -> Int {
  self.lines.length()
}

///|
/// The line at `index` (negative indices count from the end, as in
/// Python). Aborts if out of range.
pub fn Lines::get(self : Lines, index : Int) -> Text {
  self.lines[if index < 0 { self.lines.length() + index } else { index }]
}

///|
/// Replace the line at `index` (negative indices count from the end).
pub fn Lines::set(self : Lines, index : Int, value : Text) -> Unit {
  self.lines[if index < 0 { self.lines.length() + index } else { index }] = value
}

///|
/// Lines `start..end` with Python slice semantics (upstream `lines[a:b]`).
pub fn Lines::slice(self : Lines, start? : Int, end? : Int) -> Array[Text] {
  let n = self.lines.length()
  fn clamp(i : Int?, default : Int) -> Int {
    match i {
      None => default
      Some(i) => if i < 0 { @cmp.maximum(0, n + i) } else { @cmp.minimum(i, n) }
    }
  }

  let a = clamp(start, 0)
  let b = clamp(end, n)
  if a >= b {
    []
  } else {
    self.lines[a:b].to_owned()
  }
}

///|
pub fn Lines::append(self : Lines, line : Text) -> Unit {
  self.lines.push(line)
}

///|
pub fn Lines::extend_(self : Lines, lines : ArrayView[Text]) -> Unit {
  for line in lines {
    self.lines.push(line)
  }
}

///|
/// Remove and return the line at `index` (default: the last line;
/// negative indices count from the end). `None` if out of range.
pub fn Lines::pop(self : Lines, index? : Int = -1) -> Text? {
  let n = self.lines.length()
  let i = if index < 0 { n + index } else { index }
  if i < 0 || i >= n {
    None
  } else {
    Some(self.lines.remove(i))
  }
}

///|
pub fn Lines::iter(self : Lines) -> Iter[Text] {
  self.lines.iter()
}

///|
/// Upstream `repr(lines)`.
pub fn Lines::repr(self : Lines) -> String {
  "Lines([" + self.lines.map(l => l.repr()).join(", ") + "])"
}

///|
pub impl Renderable for Lines with fn rich_console(self, _console, _options) {
  self.lines.map(l => Child(l))
}

///|
/// Justify and overflow text to a given width.
pub fn Lines::justify(
  self : Lines,
  console : Console,
  width : Int,
  justify? : JustifyMethod = Left,
  overflow? : OverflowMethod = Fold,
) -> Unit raise {
  match justify {
    Left =>
      for line in self.lines {
        line.truncate(width, overflow~, pad=true)
      }
    Center =>
      for line in self.lines {
        line.rstrip()
        line.truncate(width, overflow~)
        line.pad_left(floor_div(width - @cells.cell_len(line.plain()), 2))
        line.pad_right(width - @cells.cell_len(line.plain()))
      }
    Right =>
      for line in self.lines {
        line.rstrip()
        line.truncate(width, overflow~)
        line.pad_left(width - @cells.cell_len(line.plain()))
      }
    Full =>
      for line_index, line in self.lines {
        if line_index == self.lines.length() - 1 {
          break
        }
        let words = line.split(separator=" ").lines
        let mut words_size = 0
        for word in words {
          words_size += @cells.cell_len(word.plain())
        }
        let mut num_spaces = words.length() - 1
        let spaces = Array::make(@cmp.maximum(0, num_spaces), 1)
        let mut index = 0
        if !spaces.is_empty() {
          while words_size + num_spaces < width {
            spaces[spaces.length() - index - 1] += 1
            num_spaces += 1
            index = (index + 1) % spaces.length()
          }
        }
        let tokens : Array[Text] = []
        for index, word in words {
          tokens.push(word)
          if index < spaces.length() {
            let next_word = words[index + 1]
            let style = word.get_style_at_offset(console, -1)
            let next_style = next_word.get_style_at_offset(console, 0)
            let space_style = if style == next_style {
              StyleType::Style(style)
            } else {
              line.style
            }
            tokens.push(
              Text::new(text=" ".repeat(spaces[index]), style=space_style),
            )
          }
        }
        self.lines[line_index] = Text::new().join(tokens)
      }
    Default => ()
  }
}

///|
/// Match `\s*\S+\s*` at `position`; returns the end offset.
fn match_word(text : String, position : Int) -> Int? {
  let n = text.length()
  let mut i = position
  while i < n && is_py_whitespace(text[i].to_int().unsafe_to_char()) {
    i += 1
  }
  let start_word = i
  while i < n && !is_py_whitespace(text[i].to_int().unsafe_to_char()) {
    i += 1
  }
  if i == start_word {
    return None
  }
  while i < n && is_py_whitespace(text[i].to_int().unsafe_to_char()) {
    i += 1
  }
  Some(i)
}

///|
/// Words of `text` as `(start, end, word)` where a word includes the
/// whitespace around it.
pub fn words(text : String) -> Array[(Int, Int, String)] {
  let out = []
  let mut position = 0
  while match_word(text, position) is Some(end) {
    out.push(
      (
        position,
        end,
        text.view(start_offset=position, end_offset=end).to_owned(),
      ),
    )
    position = end
  }
  out
}

///|
/// Given a string of text and a width (in cells), return the offsets at
/// which the string should be split in order to fit within the width.
/// With `fold`, words longer than `width` are folded onto new lines.
pub fn divide_line(
  text : String,
  width : Int,
  fold? : Bool = true,
) -> Array[Int] {
  let break_positions = []
  let mut cell_offset = 0
  let mut position = 0
  // the words of `words(text)`, as views (no substring per word)
  while match_word(text, position) is Some(end) {
    let mut start = position
    let word = text.view(start_offset=position, end_offset=end)
    position = end
    let mut stripped_end = word.length()
    while stripped_end > 0 &&
          is_py_space_unit(word.unsafe_get(stripped_end - 1).to_int()) {
      stripped_end -= 1
    }
    let word_length = @cells.cell_len(word.view(end_offset=stripped_end))
    let remaining_space = width - cell_offset
    if remaining_space >= word_length {
      cell_offset += @cells.cell_len(word)
    } else if word_length > width {
      if fold {
        let folded_word = @cells.chop_cells(word, width)
        for i, line in folded_word {
          let last = i == folded_word.length() - 1
          if start != 0 {
            break_positions.push(start)
          }
          if last {
            cell_offset = @cells.cell_len(line)
          } else {
            start += line.length()
          }
        }
      } else {
        if start != 0 {
          break_positions.push(start)
        }
        cell_offset = @cells.cell_len(word)
      }
    } else if cell_offset != 0 && start != 0 {
      break_positions.push(start)
      cell_offset = @cells.cell_len(word)
    }
  }
  break_positions
}
