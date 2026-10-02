// Rendering benchmark; counterpart of `scripts/bench.py` (upstream Rich).
//
//   moon run --target native --release cmd/bench [workload ...]
//
// Every workload renders to an in-memory console (truecolor, width 100). It
// is warmed up for `warmup_seconds` (JIT tiering on wasm), then timed in
// `rounds` rounds of at least `round_seconds` each; the fastest round is
// reported as `name  iterations  ms/iter  output-length`.

///|
let warmup_seconds : Double = 0.3

///|
let round_seconds : Double = 0.3

///|
let rounds : Int = 3

///|
let words : Array[String] = [
  "lorem", "ipsum", "dolor", "sit", "amet", "consectetur", "adipiscing", "elit",
  "sed", "do", "eiusmod", "tempor", "incididunt", "ut", "labore", "et", "dolore",
  "magna", "aliqua",
]

///|
let span_styles : Array[String] = [
  "bold", "italic red", "underline #ff8800", "on blue", "dim cyan",
]

///|
fn new_console(file : @rich.StringIO) -> @rich.Console raise {
  @rich.Console::new(
    file~,
    width=100,
    color_system=Some("truecolor"),
    force_terminal=true,
    legacy_windows=false,
    environ={},
  )
}

///|
fn lorem(n_words : Int) -> String {
  let sb = StringBuilder()
  for i in 0..<n_words {
    if i > 0 {
      sb.write_string(if i % 150 == 0 { "\n\n" } else { " " })
    }
    sb.write_string(words[i * 7 % words.length()])
  }
  sb.to_string()
}

///|
fn pad2(n : Int) -> String {
  if n < 10 {
    "0\{n}"
  } else {
    n.to_string()
  }
}

///|
fn json_doc(n : Int) -> String {
  let items = []
  for i in 0..<n {
    let active = if i % 2 == 0 { "true" } else { "false" }
    items.push(
      "{\"id\": \{i}, \"name\": \"item \{i}\", \"active\": \{active}, " +
      "\"score\": \{i}.5, \"tags\": [\"alpha\", \"beta\", \"gamma\"], " +
      "\"meta\": {\"created\": \"2024-01-\{pad2(i % 28 + 1)}\", " +
      "\"owner\": null, \"ratio\": 0.\{i % 10}5}}",
    )
  }
  "[" + items.join(", ") + "]"
}

///|
fn setup_card(console : @rich.Console) -> (() -> Unit raise) raise {
  let card = @card.make_test_card()
  () => console.print(card)
}

///|
fn setup_table(console : @rich.Console) -> (() -> Unit raise) raise {
  () => {
    let table = @rich.Table::new(title="Big table", row_styles=["", "dim"])
    table.add_column(header="ID", justify=Right, style="cyan")
    table.add_column(header="Name", style="magenta")
    table.add_column(header="Status")
    table.add_column(header="Score", justify=Right)
    table.add_column(header="Description")
    table.add_column(header="Tags", style="green")
    for i in 0..<1000 {
      let desc = [
        for k in 0..<(i % 12 + 1) => words[(i + k) % words.length()]
      ].join(" ")
      table.add_row([
        i.to_string(),
        "[bold]User \{i}[/bold]",
        if i % 3 != 0 {
          "[green]ok[/]"
        } else {
          "[red]fail[/]"
        },
        "\{i * 3}.\{pad2(i % 100)}",
        desc,
        "[i]tag\{i % 7}[/i], [u]x\{i % 5}[/u]",
      ])
    }
    console.print(table)
  }
}

///|
fn setup_text(console : @rich.Console) -> (() -> Unit raise) raise {
  let plain = lorem(33000) // ~200 KB
  () => {
    let text = @rich.Text::new(text=plain)
    let len = plain.length()
    for pos = 0, k = 0; pos < len; {
      let end = @cmp.minimum(pos + 17 + k % 23, len)
      text.stylize(span_styles[k % span_styles.length()], start=pos, end~)
      continue end + 40 + k % 31, k + 1
    }
    console.print(text, justify=Full)
  }
}

///|
fn setup_markup(console : @rich.Console) -> (() -> Unit raise) raise {
  let lines = [
    for i in 0..<2000 => {
      "[bold red]Error[/] in [link]file_\{i}.py[/link]:\{i} - [i]value[/i]=" +
      "[cyan]\{i * 7}[/] {'a': \{i}, 'b': [1, 2, 3]} True None 3.14 " +
      "/usr/lib/x.so 0x\{i.to_string(radix=16)} https://example.com/\{i} [on #223344]done[/]"
    }
  ]
  () => {
    for line in lines {
      console.print(line)
    }
  }
}

///|
fn setup_pretty(console : @rich.Console) -> (() -> Unit raise) raise {
  let data = @json.parse(json_doc(300))
  () => console.print(@pretty.Pretty::new(data))
}

///|
fn setup_syntax(console : @rich.Console) -> (() -> Unit raise) raise {
  () => {
    console.print(
      @syntax.Syntax::new(
        python_source,
        "python",
        theme="monokai",
        line_numbers=true,
      ),
    )
  }
}

///|
fn setup_markdown(console : @rich.Console) -> (() -> Unit raise) raise {
  () => console.print(@markdown.Markdown::new(readme))
}

///|
fn setup_progress(console : @rich.Console) -> (() -> Unit raise) raise {
  let clock = Ref(0.0)
  let progress = @progress.Progress::new(console~, auto_refresh=false, get_time=() => {
    clock.val
  })
  let ids = [
    for i in 0..<100 => progress.add_task("task \{i}", total=Some(1000.0))
  ]
  let state = Ref(0)
  () => {
    state.val += 1
    clock.val += 0.25
    for n, task_id in ids {
      progress.update(
        task_id,
        completed=((n * 37 + state.val * 3) % 1000).to_double(),
      )
    }
    console.print(progress.get_renderable())
  }
}

///|
fn setup_json(console : @rich.Console) -> (() -> Unit raise) raise {
  let doc = json_doc(300)
  () => console.print(@rich.JSON::new(doc))
}

///|
let workloads : Array[(String, (@rich.Console) -> (() -> Unit raise) raise)] = [
  ("card", setup_card),
  ("table", setup_table),
  ("text", setup_text),
  ("markup", setup_markup),
  ("pretty", setup_pretty),
  ("syntax", setup_syntax),
  ("markdown", setup_markdown),
  ("progress", setup_progress),
  ("json", setup_json),
]

///|
fn pad_left(s : String, width : Int) -> String {
  " ".repeat(@cmp.maximum(0, width - s.length())) + s
}

///|
fn pad_right(s : String, width : Int) -> String {
  s + " ".repeat(@cmp.maximum(0, width - s.length()))
}

///|
fn bench(
  name : String,
  setup : (@rich.Console) -> (() -> Unit raise) raise,
) -> Unit raise {
  let file = @rich.StringIO::new()
  let console = new_console(file)
  let run = setup(console)
  run()
  let length = file.getvalue().length()
  // Repeat `run` until `seconds` have elapsed; returns ms per iteration.
  fn timed(seconds : Double) raise {
    let start = @term.monotonic()
    for iterations = 1 {
      file.reset()
      run()
      let elapsed = @term.monotonic() - start
      if elapsed >= seconds {
        break (iterations, elapsed * 1000.0 / iterations.to_double())
      }
      continue iterations + 1
    }
  }
  ignore(timed(warmup_seconds))
  let mut best = (0, @double.infinity)
  for _ in 0..<rounds {
    let r = timed(round_seconds)
    if r.1 < best.1 {
      best = r
    }
  }
  let ms = @rich.py_format_fixed(best.1, 3)
  println(
    "\{pad_right(name, 10)} \{pad_left(best.0.to_string(), 6)} \{pad_left(ms, 10)} ms \{pad_left(length.to_string(), 9)}",
  )
}

///|
/// `--dump`: print the output of the first iteration instead of timing.
fn dump(
  name : String,
  setup : (@rich.Console) -> (() -> Unit raise) raise,
) -> Unit raise {
  let file = @rich.StringIO::new()
  let console = new_console(file)
  let run = setup(console)
  run()
  println("=== \{name}")
  println(file.getvalue())
}

///|
fn main {
  let args = @env.args()[1:].to_owned()
  let selected = args.filter(a => workloads.iter().any(w => w.0 == a))
  let dumping = args.contains("--dump")
  for w in workloads {
    if selected.is_empty() || selected.contains(w.0) {
      try {
        if dumping {
          dump(w.0, w.1)
        } else {
          bench(w.0, w.1)
        }
      } catch {
        e => println("\{w.0}: error: \{e}")
      }
    }
  }
}
