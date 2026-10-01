// Port of rich/__init__.py: the global console and `print`.

///|
let global_console : Ref[Console?] = Ref(None)

///|
/// Get the global console object (created on first use).
pub fn get_console() -> Console {
  match global_console.val {
    Some(c) => c
    None => {
      let c = Console::new() catch { _ => abort("unable to create console") }
      global_console.val = Some(c)
      c
    }
  }
}

///|
/// Replace the global console (upstream `reconfigure(**kwargs)`; create the
/// console with `Console::new(...)` and pass it here).
pub fn reconfigure(console : Console) -> Unit {
  global_console.val = Some(console)
}

///|
/// Print an object with the global console (markup and highlighting
/// enabled). With `file`, a new console writing to it is used.
pub fn print(
  object : &Renderable,
  end? : String = "\n",
  file? : &ConsoleFile,
) -> Unit raise {
  let console = match file {
    Some(f) => Console::new(file=f)
    None => get_console()
  }
  console.print(object, end~)
}

///|
/// Print several objects separated by `sep` with the global console.
pub fn print_many(
  objects : ArrayView[&Renderable],
  sep? : String = " ",
  end? : String = "\n",
  file? : &ConsoleFile,
) -> Unit raise {
  let console = match file {
    Some(f) => Console::new(file=f)
    None => get_console()
  }
  console.print_many(objects, sep~, end~)
}

///|
/// Pretty print JSON with the global console.
pub fn print_json(
  json? : String,
  data? : Json,
  indent? : Int? = Some(2),
  highlight? : Bool = true,
  ensure_ascii? : Bool = false,
  sort_keys? : Bool = false,
) -> Unit raise {
  get_console().print_json(
    json?,
    data?,
    indent~,
    highlight~,
    ensure_ascii~,
    sort_keys~,
  )
}
