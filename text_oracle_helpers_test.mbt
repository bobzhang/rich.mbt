// Helpers for text_oracle_test.mbt (see scripts/gen_text_tests.py).

///|
fn oracle_console(width? : Int = 80, file? : @rich.StringIO) -> @rich.Console {
  @rich.Console::new(
    file=file.unwrap_or(@rich.StringIO::new()),
    width~,
    color_system=Some("truecolor"),
    force_terminal=true,
    legacy_windows=false,
    environ={},
  ) catch {
    _ => abort("console")
  }
}

///|
fn lines_repr_text(lines : @rich.Lines) -> String {
  lines.lines.map(l => l.repr()).join(" | ")
}

///|
/// Apply the method named by the generator to the Text of `markup`.
fn text_method(markup : String, op : String) -> String raise {
  let t = @rich.Text::from_markup(markup)
  match op {
    "markup" => t.markup()
    "split_space" => lines_repr_text(t.split(separator=" "))
    "split_nl_sep" =>
      lines_repr_text(t.split(separator="\n", include_separator=true))
    "split_nl_blank" =>
      lines_repr_text(t.split(separator="\n", allow_blank=true))
    "divide" => {
      // the generator uses code point offsets: convert to UTF-16
      let plain = t.plain()
      let n = plain.char_length()
      let offsets = [1, 4, 7, 11]
        .filter(o => o < n)
        .map(o => plain.offset_of_nth_char(o).unwrap_or(plain.length()))
      lines_repr_text(t.divide(offsets))
    }
    "expand_tabs4" => {
      let e = t.copy()
      e.expand_tabs(tab_size=4)
      e.repr()
    }
    "align_left" | "align_center" | "align_right" => {
      let a = t.copy()
      let align : @rich.AlignMethod = match op {
        "align_left" => Left
        "align_center" => Center
        _ => Right
      }
      a.align(align, 25)
      a.repr()
    }
    "measure" => {
      let console = oracle_console()
      guard t.rich_measure(console, console.options()) is Some(m) else {
        fail("no measurement")
      }
      "\{m.minimum},\{m.maximum}"
    }
    "highlight_words" => {
      let hw = t.copy()
      hw.highlight_words(["e", "o"], "red") |> ignore
      hw.repr()
    }
    "rstrip" => {
      let r = t.copy()
      r.rstrip()
      r.repr()
    }
    "fit6" => lines_repr_text(t.fit(6))
    "cell_len" => t.cell_len().to_string()
    _ if op.has_prefix("truncate") => {
      // truncate{width}_{overflow}
      let rest = op.view(start_offset=8).to_owned()
      guard rest.find("_") is Some(i) else { fail("bad method") }
      let width = @string.parse_int(rest.view(end_offset=i))
      let overflow = @rich.OverflowMethod::parse(
        rest.view(start_offset=i + 1).to_owned(),
      ).unwrap()
      let tr = t.copy()
      tr.truncate(width, overflow~, pad=true)
      tr.repr()
    }
    _ => fail("unknown method \{op}")
  }
}
