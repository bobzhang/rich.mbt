// Port of tests/test_columns.py and tests/test_columns_align.py.

///|
let column_data : Array[String] = [
  "Ursus americanus", "American buffalo", "Bison bison", "American crow", "Corvus brachyrhynchos",
  "American marten", "Martes americana", "American racer", "Coluber constrictor",
  "American woodcock", "Scolopax minor", "Anaconda (unidentified)", "Eunectes sp.",
  "Andean goose", "Chloephaga melanoptera", "Ant", "Anteater, australian spiny",
  "Tachyglossus aculeatus", "Anteater, giant",
]

///|
fn render_columns() -> String raise {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(file~, width=100, legacy_windows=false, environ={})
  console.rule(title="empty")
  let empty_columns = @columns.Columns::new([])
  console.print(empty_columns)
  let columns = @columns.Columns::new(
    column_data.map(s => (s : &@rich.Renderable)),
  )
  columns.add_renderable("Myrmecophaga tridactyla")
  console.rule(title="optimal")
  console.print(columns)
  console.rule(title="optimal, expand")
  columns.expand = true
  console.print(columns)
  console.rule(title="column first, optimal")
  columns.column_first = true
  columns.expand = false
  console.print(columns)
  console.rule(title="column first, right to left")
  columns.right_to_left = true
  console.print(columns)
  console.rule(title="equal columns, expand")
  columns.equal = true
  columns.expand = true
  console.print(columns)
  console.rule(title="fixed width")
  columns.width = Some(16)
  columns.expand = false
  console.print(columns)
  console.print("")
  file.getvalue()
}

///|
test "render" {
  let expected = "────────────────────────────────────────────── empty ───────────────────────────────────────────────\n───────────────────────────────────────────── optimal ──────────────────────────────────────────────\nUrsus americanus           American buffalo       Bison bison            American crow          \nCorvus brachyrhynchos      American marten        Martes americana       American racer         \nColuber constrictor        American woodcock      Scolopax minor         Anaconda (unidentified)\nEunectes sp.               Andean goose           Chloephaga melanoptera Ant                    \nAnteater, australian spiny Tachyglossus aculeatus Anteater, giant        Myrmecophaga tridactyla\n───────────────────────────────────────── optimal, expand ──────────────────────────────────────────\nUrsus americanus             American buffalo        Bison bison             American crow          \nCorvus brachyrhynchos        American marten         Martes americana        American racer         \nColuber constrictor          American woodcock       Scolopax minor          Anaconda (unidentified)\nEunectes sp.                 Andean goose            Chloephaga melanoptera  Ant                    \nAnteater, australian spiny   Tachyglossus aculeatus  Anteater, giant         Myrmecophaga tridactyla\n────────────────────────────────────── column first, optimal ───────────────────────────────────────\nUrsus americanus      American marten     Scolopax minor          Ant                       \nAmerican buffalo      Martes americana    Anaconda (unidentified) Anteater, australian spiny\nBison bison           American racer      Eunectes sp.            Tachyglossus aculeatus    \nAmerican crow         Coluber constrictor Andean goose            Anteater, giant           \nCorvus brachyrhynchos American woodcock   Chloephaga melanoptera  Myrmecophaga tridactyla   \n─────────────────────────────────── column first, right to left ────────────────────────────────────\nAnt                        Scolopax minor          American marten     Ursus americanus     \nAnteater, australian spiny Anaconda (unidentified) Martes americana    American buffalo     \nTachyglossus aculeatus     Eunectes sp.            American racer      Bison bison          \nAnteater, giant            Andean goose            Coluber constrictor American crow        \nMyrmecophaga tridactyla    Chloephaga melanoptera  American woodcock   Corvus brachyrhynchos\n────────────────────────────────────── equal columns, expand ───────────────────────────────────────\nChloephaga melanoptera                American racer                    Ursus americanus            \nAnt                                   Coluber constrictor               American buffalo            \nAnteater, australian spiny            American woodcock                 Bison bison                 \nTachyglossus aculeatus                Scolopax minor                    American crow               \nAnteater, giant                       Anaconda (unidentified)           Corvus brachyrhynchos       \nMyrmecophaga tridactyla               Eunectes sp.                      American marten             \n                                      Andean goose                      Martes americana            \n─────────────────────────────────────────── fixed width ────────────────────────────────────────────\nAnteater,        Eunectes sp.     Coluber          Corvus           Ursus americanus\naustralian spiny                  constrictor      brachyrhynchos                   \nTachyglossus     Andean goose     American         American marten  American buffalo\naculeatus                         woodcock                                          \nAnteater, giant  Chloephaga       Scolopax minor   Martes americana Bison bison     \n                 melanoptera                                                        \nMyrmecophaga     Ant              Anaconda         American racer   American crow   \ntridactyla                        (unidentified)                                    \n\n"
  assert_eq(render_columns(), expected)
}

///|
fn render_align() -> String raise {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(file~, width=100, legacy_windows=false, environ={})
  let panel = @panel.Panel::fit("foo", box_=@rich.box_square, padding=[0])
  let columns = @columns.Columns::new([panel, panel, panel, panel])
  columns.expand = true
  console.rule(title="no align")
  console.print(columns)
  columns.align = Some(Left)
  console.rule(title="left align")
  console.print(columns)
  columns.align = Some(Center)
  console.rule(title="center align")
  console.print(columns)
  columns.align = Some(Right)
  console.rule(title="right align")
  console.print(columns)
  file.getvalue()
}

///|
test "align" {
  let expected = "───────────────────────────────────────────── no align ─────────────────────────────────────────────\n┌───┐                      ┌───┐                     ┌───┐                     ┌───┐                \n│foo│                      │foo│                     │foo│                     │foo│                \n└───┘                      └───┘                     └───┘                     └───┘                \n──────────────────────────────────────────── left align ────────────────────────────────────────────\n┌───┐                      ┌───┐                     ┌───┐                     ┌───┐                \n│foo│                      │foo│                     │foo│                     │foo│                \n└───┘                      └───┘                     └───┘                     └───┘                \n─────────────────────────────────────────── center align ───────────────────────────────────────────\n          ┌───┐                      ┌───┐                     ┌───┐                   ┌───┐        \n          │foo│                      │foo│                     │foo│                   │foo│        \n          └───┘                      └───┘                     └───┘                   └───┘        \n─────────────────────────────────────────── right align ────────────────────────────────────────────\n                     ┌───┐                     ┌───┐                     ┌───┐                 ┌───┐\n                     │foo│                     │foo│                     │foo│                 │foo│\n                     └───┘                     └───┘                     └───┘                 └───┘\n"
  assert_eq(render_align(), expected)
}
