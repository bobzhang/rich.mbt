// Differential cases computed with upstream Rich
// (`Console(width=..., color_system="truecolor", force_terminal=True,
// legacy_windows=False, _environ={})`).

///|
let words : Array[String] = [
  "alpha", "beta", "gamma", "delta", "epsilon", "zeta", "eta", "theta", "iota", "kappa",
  "lambda", "mu", "nu", "xi", "omicron", "pi", "rho",
]

///|
fn word_items(n? : Int = 17) -> Array[&@rich.Renderable] {
  words[:n].iter().map(s => (s : &@rich.Renderable)).to_array()
}

///|
fn render(renderable : &@rich.Renderable, width : Int) -> String raise {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    width~,
    file~,
    color_system=Some("truecolor"),
    force_terminal=true,
    legacy_windows=false,
    environ={},
  )
  console.print(renderable)
  file.getvalue()
}

///|
test "differential layouts" {
  let cases : Array[(@columns.Columns, Int, String)] = [
    (
      @columns.Columns::new(word_items()),
      40,
      "alpha beta  gamma   delta epsilon zeta\neta   theta iota    kappa lambda  mu  \nnu    xi    omicron pi    rho         \n",
    ),
    (
      @columns.Columns::new(word_items()),
      17,
      "alpha   beta \ngamma   delta\nepsilon zeta \neta     theta\niota    kappa\nlambda  mu   \nnu      xi   \nomicron pi   \nrho          \n",
    ),
    (
      @columns.Columns::new(word_items(), padding=[0, 3]),
      40,
      "alpha    beta   gamma   delta   epsilon\nzeta     eta    theta   iota    kappa  \nlambda   mu     nu      xi      omicron\npi       rho                           \n",
    ),
    (
      @columns.Columns::new(word_items(n=7), padding=[1, 2]),
      30,
      "alpha    beta  gamma  delta\n                           \nepsilon  zeta  eta         \n",
    ),
    (
      @columns.Columns::new(word_items(), column_first=true),
      30,
      "alpha   zeta  kappa  xi     \nbeta    eta   lambda omicron\ngamma   theta mu     pi     \ndelta   iota  nu     rho    \nepsilon                     \n",
    ),
    (
      @columns.Columns::new(word_items(), right_to_left=true),
      30,
      "delta gamma   beta  alpha  \ntheta eta     zeta  epsilon\nmu    lambda  kappa iota   \npi    omicron xi    nu     \n                    rho    \n",
    ),
    (
      @columns.Columns::new(word_items(), equal=true, expand=true),
      50,
      "alpha   beta    gamma      delta   epsilon   zeta \neta     theta   iota       kappa   lambda    mu   \nnu      xi      omicron    pi      rho            \n",
    ),
    (
      @columns.Columns::new(word_items(), equal=true, align=Center),
      50,
      "alpha beta   gamma  delta epsilon zeta\n eta  theta  iota   kappa lambda   mu \n nu    xi   omicron  pi     rho       \n",
    ),
    (
      @columns.Columns::new(word_items(n=6), title="My Title"),
      30,
      "\u{1b}[3m           My Title           \u{1b}[0m\nalpha beta gamma delta epsilon\nzeta                          \n",
    ),
    (
      @columns.Columns::new([
        "[bold red]hot[/]",
        "[green]go[/] 123",
        "xxxxxxxxxxxx",
        @rich.Text::new(text="text obj", style="blue"),
      ]),
      30,
      "\u{1b}[1;31mhot\u{1b}[0m      \u{1b}[32mgo\u{1b}[0m \u{1b}[1;36m123\u{1b}[0m xxxxxxxxxxxx\n\u{1b}[34mtext obj\u{1b}[0m                    \n",
    ),
    (
      @columns.Columns::new(word_items(n=9), width=8),
      40,
      "alpha    beta     gamma    delta   \nepsilon  zeta     eta      theta   \niota                               \n",
    ),
    (
      @columns.Columns::new(
        word_items(n=9),
        width=8,
        column_first=true,
        right_to_left=true,
      ),
      40,
      "theta    zeta     delta    alpha   \niota     eta      epsilon  beta    \n                           gamma   \n",
    ),
    (@columns.Columns::new(["only one"]), 20, "only one\n"),
    (
      @columns.Columns::new(
        words[:5]
        .iter()
        .map(w => (@panel.Panel::new(w, expand=false) : &@rich.Renderable))
        .to_array(),
        expand=true,
        align=Right,
      ),
      50,
      "╭───────╮ ╭──────╮ ╭───────╮ ╭───────╮ ╭─────────╮\n│ alpha │ │ beta │ │ gamma │ │ delta │ │ epsilon │\n╰───────╯ ╰──────╯ ╰───────╯ ╰───────╯ ╰─────────╯\n",
    ),
    (
      @columns.Columns::new(["a very long word list item", "short"]),
      10,
      "a very    \nlong word \nlist item \nshort     \n",
    ),
  ]
  for case in cases {
    let (columns, width, expected) = case
    assert_eq(render(columns, width), expected)
  }
}
