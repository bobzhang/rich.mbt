// Differential cases computed with upstream Rich
// (`Console(width=..., color_system="truecolor", force_terminal=True,
// legacy_windows=False, _environ={})`).

///|
fn render(
  renderable : &@rich.Renderable,
  width? : Int = 40,
  justify? : @rich.JustifyMethod,
) -> String raise {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    width~,
    file~,
    color_system=Some("truecolor"),
    force_terminal=true,
    legacy_windows=false,
    environ={},
  )
  console.print(renderable, justify?)
  file.getvalue()
}

///|
fn case1() -> @tree.Tree {
  let root = @tree.Tree::new("[b green]Rich Tree", highlight=true)
  let a = root.add("node [red]A[/red] 123", guide_style="red")
  let a1 = a.add("[bold yellow]Atomic", guide_style="uu green")
  ignore(a1.add("leaf one which is rather long and will need to wrap around"))
  ignore(a1.add("leaf 2"))
  let b = a.add("Containers", guide_style="bold magenta")
  ignore(b.add(@panel.Panel::fit("Just a panel", border_style="red")))
  ignore(b.add("multi\nline\nlabel"))
  ignore(root.add("collapsed", expanded=false).add("hidden"))
  ignore(root.add("last 'str' 42", highlight=None))
  root
}

///|
fn case2() -> @tree.Tree {
  let root = @tree.Tree::new("root", hide_root=true, guide_style="bold")
  let x = root.add("x")
  ignore(x.add("x1"))
  ignore(x.add("x2").add("x21"))
  ignore(root.add("y", style="italic").add("y1", style="on red"))
  root
}

///|
test "nested tree" {
  assert_eq(
    render(case1()),
    "\u{1b}[1;32mRich Tree\u{1b}[0m\n├── node \u{1b}[31mA\u{1b}[0m \u{1b}[1;36m123\u{1b}[0m\n│   \u{1b}[31m├── \u{1b}[0m\u{1b}[1;33mAtomic\u{1b}[0m\n│   \u{1b}[31m│   \u{1b}[0m\u{1b}[32m╠══ \u{1b}[0mleaf one which is rather \n│   \u{1b}[31m│   \u{1b}[0m\u{1b}[32m║   \u{1b}[0mlong and will need to wrap \n│   \u{1b}[31m│   \u{1b}[0m\u{1b}[32m║   \u{1b}[0maround\n│   \u{1b}[31m│   \u{1b}[0m\u{1b}[32m╚══ \u{1b}[0mleaf \u{1b}[1;36m2\u{1b}[0m\n│   \u{1b}[31m└── \u{1b}[0mContainers\n│   \u{1b}[31m    \u{1b}[0m\u{1b}[35m┣━━ \u{1b}[0m\u{1b}[31m╭──────────────╮\u{1b}[0m\n│   \u{1b}[31m    \u{1b}[0m\u{1b}[35m┃   \u{1b}[0m\u{1b}[31m│\u{1b}[0m Just a panel \u{1b}[31m│\u{1b}[0m\n│   \u{1b}[31m    \u{1b}[0m\u{1b}[35m┃   \u{1b}[0m\u{1b}[31m╰──────────────╯\u{1b}[0m\n│   \u{1b}[31m    \u{1b}[0m\u{1b}[35m┗━━ \u{1b}[0mmulti\n│   \u{1b}[31m    \u{1b}[0m\u{1b}[35m    \u{1b}[0mline\n│   \u{1b}[31m    \u{1b}[0m\u{1b}[35m    \u{1b}[0mlabel\n├── collapsed\n└── last \u{1b}[32m'str'\u{1b}[0m \u{1b}[1;36m42\u{1b}[0m\n",
  )
  assert_eq(
    render(case1(), width=30),
    "\u{1b}[1;32mRich Tree\u{1b}[0m\n├── node \u{1b}[31mA\u{1b}[0m \u{1b}[1;36m123\u{1b}[0m\n│   \u{1b}[31m├── \u{1b}[0m\u{1b}[1;33mAtomic\u{1b}[0m\n│   \u{1b}[31m│   \u{1b}[0m\u{1b}[32m╠══ \u{1b}[0mleaf one which is \n│   \u{1b}[31m│   \u{1b}[0m\u{1b}[32m║   \u{1b}[0mrather long and \n│   \u{1b}[31m│   \u{1b}[0m\u{1b}[32m║   \u{1b}[0mwill need to wrap \n│   \u{1b}[31m│   \u{1b}[0m\u{1b}[32m║   \u{1b}[0maround\n│   \u{1b}[31m│   \u{1b}[0m\u{1b}[32m╚══ \u{1b}[0mleaf \u{1b}[1;36m2\u{1b}[0m\n│   \u{1b}[31m└── \u{1b}[0mContainers\n│   \u{1b}[31m    \u{1b}[0m\u{1b}[35m┣━━ \u{1b}[0m\u{1b}[31m╭──────────────╮\u{1b}[0m\n│   \u{1b}[31m    \u{1b}[0m\u{1b}[35m┃   \u{1b}[0m\u{1b}[31m│\u{1b}[0m Just a panel \u{1b}[31m│\u{1b}[0m\n│   \u{1b}[31m    \u{1b}[0m\u{1b}[35m┃   \u{1b}[0m\u{1b}[31m╰──────────────╯\u{1b}[0m\n│   \u{1b}[31m    \u{1b}[0m\u{1b}[35m┗━━ \u{1b}[0mmulti\n│   \u{1b}[31m    \u{1b}[0m\u{1b}[35m    \u{1b}[0mline\n│   \u{1b}[31m    \u{1b}[0m\u{1b}[35m    \u{1b}[0mlabel\n├── collapsed\n└── last \u{1b}[32m'str'\u{1b}[0m \u{1b}[1;36m42\u{1b}[0m\n",
  )
}

///|
test "justified tree" {
  assert_eq(
    render(case1(), justify=Center),
    "               \u{1b}[1;32mRich Tree\u{1b}[0m                \n├──              node \u{1b}[31mA\u{1b}[0m \u{1b}[1;36m123\u{1b}[0m             \n│   \u{1b}[31m├── \u{1b}[0m             \u{1b}[1;33mAtomic\u{1b}[0m             \n│   \u{1b}[31m│   \u{1b}[0m\u{1b}[32m╠══ \u{1b}[0m  leaf one which is rather  \n│   \u{1b}[31m│   \u{1b}[0m\u{1b}[32m║   \u{1b}[0m long and will need to wrap \n│   \u{1b}[31m│   \u{1b}[0m\u{1b}[32m║   \u{1b}[0m           around           \n│   \u{1b}[31m│   \u{1b}[0m\u{1b}[32m╚══ \u{1b}[0m           leaf \u{1b}[1;36m2\u{1b}[0m           \n│   \u{1b}[31m└── \u{1b}[0m           Containers           \n│   \u{1b}[31m    \u{1b}[0m\u{1b}[35m┣━━ \u{1b}[0m\u{1b}[31m╭──────────────╮\u{1b}[0m            \n│   \u{1b}[31m    \u{1b}[0m\u{1b}[35m┃   \u{1b}[0m\u{1b}[31m│\u{1b}[0m Just a panel \u{1b}[31m│\u{1b}[0m            \n│   \u{1b}[31m    \u{1b}[0m\u{1b}[35m┃   \u{1b}[0m\u{1b}[31m╰──────────────╯\u{1b}[0m            \n│   \u{1b}[31m    \u{1b}[0m\u{1b}[35m┗━━ \u{1b}[0m           multi            \n│   \u{1b}[31m    \u{1b}[0m\u{1b}[35m    \u{1b}[0m            line            \n│   \u{1b}[31m    \u{1b}[0m\u{1b}[35m    \u{1b}[0m           label            \n├──              collapsed              \n└──            last \u{1b}[32m'str'\u{1b}[0m \u{1b}[1;36m42\u{1b}[0m            \n",
  )
}

///|
test "hide root with bold guides" {
  assert_eq(
    render(case2()),
    "x\n┣━━ x1\n┗━━ x2\n    ┗━━ x21\n\u{1b}[3my\u{1b}[0m\n\u{1b}[41m┗━━ \u{1b}[0m\u{1b}[3;41my1\u{1b}[0m\n",
  )
}

///|
test "text label" {
  assert_eq(
    render(
      @tree.Tree::new(@rich.Text::new(text="text label", style="blue")),
      width=20,
    ),
    "\u{1b}[34mtext label\u{1b}[0m\n",
  )
}

///|
test "measure nested" {
  let console = @rich.Console::new(width=80, environ={})
  assert_eq(
    @rich.Measurement::get(console, console.options(), case1()),
    @rich.Measurement::new(28, 70),
  )
  assert_eq(
    @rich.Measurement::get(console, console.options(), case2()),
    @rich.Measurement::new(15, 15),
  )
}
