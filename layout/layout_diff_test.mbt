// Differential cases generated with upstream Rich
// (`Console(width=..., height=..., color_system="truecolor" or None,
// force_terminal=True, legacy_windows=False, _environ={})`).

///|
fn render(
  renderable : &@rich.Renderable,
  width~ : Int,
  height? : Int,
  color? : Bool = true,
) -> String raise {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    width~,
    height?,
    file~,
    color_system=if color { Some("truecolor") } else { None },
    force_terminal=true,
    legacy_windows=false,
    environ={},
  )
  console.print(renderable)
  file.getvalue()
}

///|
fn demo() -> @layout.Layout raise {
  let layout = @layout.Layout::new()
  layout.split_column([
    @layout.Layout::new(name="header", size=3),
    @layout.Layout::new(ratio=1, name="main"),
    @layout.Layout::new(size=4, name="footer"),
  ])
  layout["main"].split_row([
    @layout.Layout::new(name="side"),
    @layout.Layout::new(name="body", ratio=2),
  ])
  layout["body"].split_row([
    @layout.Layout::new(name="content", ratio=2),
    @layout.Layout::new(name="s2"),
  ])
  layout["s2"].split_column([
    @layout.Layout::new(name="top"),
    @layout.Layout::new(name="middle"),
    @layout.Layout::new(name="bottom"),
  ])
  layout["side"].split_column([
    @layout.Layout::new(renderable=layout.tree(), name="left1"),
    @layout.Layout::new(name="left2"),
  ])
  layout["content"].update("foo")
  layout
}

///|
fn sized() -> @layout.Layout {
  let layout = @layout.Layout::new(name="root")
  let a = @layout.Layout::new(
    renderable=@rich.Text::new(text="left text", style="red"),
    name="a",
    minimum_size=5,
    ratio=3,
  )
  let b = @layout.Layout::new(
    renderable=@panel.Panel::new("middle"),
    name="b",
    size=12,
  )
  let c = @layout.Layout::new(name="c")
  let hidden = @layout.Layout::new(
    renderable="hidden!",
    name="hidden",
    visible=false,
  )
  layout.split_row([a, b, hidden, c])
  layout
}

///|
test "demo layout" {
  assert_eq(
    render(demo(), width=80, height=30),
    "\u{1b}[34m╭─\u{1b}[0m\u{1b}[34m────────────────────────────\u{1b}[0m\u{1b}[34m \u{1b}[0m\u{1b}[32m'header'\u{1b}[0m\u{1b}[34m \u{1b}[0m\u{1b}[1;34m(\u{1b}[0m\u{1b}[1;36m80\u{1b}[0m\u{1b}[34m x \u{1b}[0m\u{1b}[1;36m3\u{1b}[0m\u{1b}[1;34m)\u{1b}[0m\u{1b}[34m \u{1b}[0m\u{1b}[34m─────────────────────────────\u{1b}[0m\u{1b}[34m─╮\u{1b}[0m\n\u{1b}[34m│\u{1b}[0m                        \u{1b}[1;35mLayout\u{1b}[0m\u{1b}[1m(\u{1b}[0m\u{1b}[33mname\u{1b}[0m=\u{1b}[32m'header'\u{1b}[0m, \u{1b}[33msize\u{1b}[0m=\u{1b}[1;36m3\u{1b}[0m\u{1b}[1m)\u{1b}[0m                         \u{1b}[34m│\u{1b}[0m\n\u{1b}[34m╰──────────────────────────────────────────────────────────────────────────────╯\u{1b}[0m\n\u{1b}[34m⬍\u{1b}[0m \u{1b}[1;35mLayout\u{1b}[0m\u{1b}[1m(\u{1b}[0m\u{1b}[1m)\u{1b}[0m                foo                                 \u{1b}[34m╭─\u{1b}[0m\u{1b}[34m \u{1b}[0m\u{1b}[32m'top'\u{1b}[0m\u{1b}[34m \u{1b}[0m\u{1b}[1;34m(\u{1b}[0m\u{1b}[1;36m18\u{1b}[0m\u{1b}[34m x \u{1b}[0m\u{1b}[1;36m7\u{1b}[0m\u{1b}[34m─╮\u{1b}[0m\n\u{1b}[34m├── \u{1b}[0m\u{1b}[34m⬍\u{1b}[0m \u{1b}[1;35mLayout\u{1b}[0m\u{1b}[1m(\u{1b}[0m                                                 \u{1b}[34m│\u{1b}[0m                \u{1b}[34m│\u{1b}[0m\n\u{1b}[34m│   \u{1b}[0m      \u{1b}[33mname\u{1b}[0m=\u{1b}[32m'header'\u{1b}[0m,                                      \u{1b}[34m│\u{1b}[0m \u{1b}[1;35mLayout\u{1b}[0m\u{1b}[1m(\u{1b}[0m        \u{1b}[34m│\u{1b}[0m\n\u{1b}[34m│   \u{1b}[0m      \u{1b}[33msize\u{1b}[0m=\u{1b}[1;36m3\u{1b}[0m                                              \u{1b}[34m│\u{1b}[0m     \u{1b}[33mname\u{1b}[0m=\u{1b}[32m'top'\u{1b}[0m \u{1b}[34m│\u{1b}[0m\n\u{1b}[34m│   \u{1b}[0m  \u{1b}[1m)\u{1b}[0m                                                       \u{1b}[34m│\u{1b}[0m \u{1b}[1m)\u{1b}[0m              \u{1b}[34m│\u{1b}[0m\n\u{1b}[34m├── \u{1b}[0m\u{1b}[31m⬌\u{1b}[0m \u{1b}[1;35mLayout\u{1b}[0m\u{1b}[1m(\u{1b}[0m\u{1b}[33mname\u{1b}[0m=\u{1b}[32m'main'\u{1b}[0m\u{1b}[1m)\u{1b}[0m                                     \u{1b}[34m│\u{1b}[0m                \u{1b}[34m│\u{1b}[0m\n\u{1b}[34m│   \u{1b}[0m\u{1b}[31m├── \u{1b}[0m\u{1b}[34m⬍\u{1b}[0m \u{1b}[1;35mLayout\u{1b}[0m\u{1b}[1m(\u{1b}[0m                                             \u{1b}[34m╰────────────────╯\u{1b}[0m\n\u{1b}[34m│   \u{1b}[0m\u{1b}[31m│   \u{1b}[0m      \u{1b}[33mname\u{1b}[0m=\u{1b}[32m'side'\u{1b}[0m                                     \u{1b}[34m╭─\u{1b}[0m\u{1b}[34m \u{1b}[0m\u{1b}[32m'middle'\u{1b}[0m\u{1b}[34m \u{1b}[0m\u{1b}[1;34m(\u{1b}[0m\u{1b}[1;36m18\u{1b}[0m\u{1b}[34m \u{1b}[0m\u{1b}[34m─╮\u{1b}[0m\n\u{1b}[34m│   \u{1b}[0m\u{1b}[31m│   \u{1b}[0m  \u{1b}[1m)\u{1b}[0m                                                   \u{1b}[34m│\u{1b}[0m                \u{1b}[34m│\u{1b}[0m\n\u{1b}[34m│   \u{1b}[0m\u{1b}[31m└── \u{1b}[0m\u{1b}[31m⬌\u{1b}[0m \u{1b}[1;35mLayout\u{1b}[0m\u{1b}[1m(\u{1b}[0m                                             \u{1b}[34m│\u{1b}[0m \u{1b}[1;35mLayout\u{1b}[0m\u{1b}[1m(\u{1b}[0m        \u{1b}[34m│\u{1b}[0m\n\u{1b}[34m│   \u{1b}[0m\u{1b}[31m    \u{1b}[0m      \u{1b}[33mname\u{1b}[0m=\u{1b}[32m'body'\u{1b}[0m,                                    \u{1b}[34m│\u{1b}[0m     \u{1b}[33mname\u{1b}[0m=\u{1b}[32m'midd\u{1b}[0m \u{1b}[34m│\u{1b}[0m\n\u{1b}[34m╭─\u{1b}[0m\u{1b}[34m─\u{1b}[0m\u{1b}[34m \u{1b}[0m\u{1b}[32m'left2'\u{1b}[0m\u{1b}[34m \u{1b}[0m\u{1b}[1;34m(\u{1b}[0m\u{1b}[1;36m26\u{1b}[0m\u{1b}[34m x \u{1b}[0m\u{1b}[1;36m12\u{1b}[0m\u{1b}[1;34m)\u{1b}[0m\u{1b}[34m \u{1b}[0m\u{1b}[34m──\u{1b}[0m\u{1b}[34m─╮\u{1b}[0m                                    \u{1b}[34m│\u{1b}[0m \u{1b}[32mle'\u{1b}[0m            \u{1b}[34m│\u{1b}[0m\n\u{1b}[34m│\u{1b}[0m                        \u{1b}[34m│\u{1b}[0m                                    \u{1b}[34m│\u{1b}[0m \u{1b}[1m)\u{1b}[0m              \u{1b}[34m│\u{1b}[0m\n\u{1b}[34m│\u{1b}[0m                        \u{1b}[34m│\u{1b}[0m                                    \u{1b}[34m│\u{1b}[0m                \u{1b}[34m│\u{1b}[0m\n\u{1b}[34m│\u{1b}[0m                        \u{1b}[34m│\u{1b}[0m                                    \u{1b}[34m╰────────────────╯\u{1b}[0m\n\u{1b}[34m│\u{1b}[0m                        \u{1b}[34m│\u{1b}[0m                                    \u{1b}[34m╭─\u{1b}[0m\u{1b}[34m \u{1b}[0m\u{1b}[32m'bottom'\u{1b}[0m\u{1b}[34m \u{1b}[0m\u{1b}[1;34m(\u{1b}[0m\u{1b}[1;36m18\u{1b}[0m\u{1b}[34m \u{1b}[0m\u{1b}[34m─╮\u{1b}[0m\n\u{1b}[34m│\u{1b}[0m  \u{1b}[1;35mLayout\u{1b}[0m\u{1b}[1m(\u{1b}[0m\u{1b}[33mname\u{1b}[0m=\u{1b}[32m'left2'\u{1b}[0m\u{1b}[1m)\u{1b}[0m  \u{1b}[34m│\u{1b}[0m                                    \u{1b}[34m│\u{1b}[0m                \u{1b}[34m│\u{1b}[0m\n\u{1b}[34m│\u{1b}[0m                        \u{1b}[34m│\u{1b}[0m                                    \u{1b}[34m│\u{1b}[0m \u{1b}[1;35mLayout\u{1b}[0m\u{1b}[1m(\u{1b}[0m        \u{1b}[34m│\u{1b}[0m\n\u{1b}[34m│\u{1b}[0m                        \u{1b}[34m│\u{1b}[0m                                    \u{1b}[34m│\u{1b}[0m     \u{1b}[33mname\u{1b}[0m=\u{1b}[32m'bott\u{1b}[0m \u{1b}[34m│\u{1b}[0m\n\u{1b}[34m│\u{1b}[0m                        \u{1b}[34m│\u{1b}[0m                                    \u{1b}[34m│\u{1b}[0m \u{1b}[32mom'\u{1b}[0m            \u{1b}[34m│\u{1b}[0m\n\u{1b}[34m│\u{1b}[0m                        \u{1b}[34m│\u{1b}[0m                                    \u{1b}[34m│\u{1b}[0m \u{1b}[1m)\u{1b}[0m              \u{1b}[34m│\u{1b}[0m\n\u{1b}[34m│\u{1b}[0m                        \u{1b}[34m│\u{1b}[0m                                    \u{1b}[34m│\u{1b}[0m                \u{1b}[34m│\u{1b}[0m\n\u{1b}[34m╰────────────────────────╯\u{1b}[0m                                    \u{1b}[34m╰────────────────╯\u{1b}[0m\n\u{1b}[34m╭─\u{1b}[0m\u{1b}[34m────────────────────────────\u{1b}[0m\u{1b}[34m \u{1b}[0m\u{1b}[32m'footer'\u{1b}[0m\u{1b}[34m \u{1b}[0m\u{1b}[1;34m(\u{1b}[0m\u{1b}[1;36m80\u{1b}[0m\u{1b}[34m x \u{1b}[0m\u{1b}[1;36m4\u{1b}[0m\u{1b}[1;34m)\u{1b}[0m\u{1b}[34m \u{1b}[0m\u{1b}[34m─────────────────────────────\u{1b}[0m\u{1b}[34m─╮\u{1b}[0m\n\u{1b}[34m│\u{1b}[0m                        \u{1b}[1;35mLayout\u{1b}[0m\u{1b}[1m(\u{1b}[0m\u{1b}[33mname\u{1b}[0m=\u{1b}[32m'footer'\u{1b}[0m, \u{1b}[33msize\u{1b}[0m=\u{1b}[1;36m4\u{1b}[0m\u{1b}[1m)\u{1b}[0m                         \u{1b}[34m│\u{1b}[0m\n\u{1b}[34m│\u{1b}[0m                                                                              \u{1b}[34m│\u{1b}[0m\n\u{1b}[34m╰──────────────────────────────────────────────────────────────────────────────╯\u{1b}[0m\n",
  )
  assert_eq(
    render(demo(), width=100, height=24, color=false),
    "╭─────────────────────────────────────── 'header' (100 x 3) ───────────────────────────────────────╮\n│                                  Layout(name='header', size=3)                                   │\n╰──────────────────────────────────────────────────────────────────────────────────────────────────╯\n⬍ Layout()                       foo                                         ╭── 'top' (23 x 5) ───╮\n├── ⬍ Layout(                                                                │                     │\n│         name='header',                                                     │ Layout(name='top')  │\n│         size=3                                                             │                     │\n│     )                                                                      ╰─────────────────────╯\n├── ⬌ Layout(name='main')                                                    ╭─ 'middle' (23 x 6) ─╮\n│   ├── ⬍ Layout(name='side')                                                │  Layout(            │\n│   └── ⬌ Layout(                                                            │      name='middle'  │\n╭────── 'left2' (33 x 9) ───────╮                                            │  )                  │\n│                               │                                            │                     │\n│                               │                                            ╰─────────────────────╯\n│                               │                                            ╭─ 'bottom' (23 x 6) ─╮\n│     Layout(name='left2')      │                                            │  Layout(            │\n│                               │                                            │      name='bottom'  │\n│                               │                                            │  )                  │\n│                               │                                            │                     │\n╰───────────────────────────────╯                                            ╰─────────────────────╯\n╭─────────────────────────────────────── 'footer' (100 x 4) ───────────────────────────────────────╮\n│                                  Layout(name='footer', size=4)                                   │\n│                                                                                                  │\n╰──────────────────────────────────────────────────────────────────────────────────────────────────╯\n",
  )
  assert_eq(
    render(demo().tree(), width=60),
    "\u{1b}[34m⬍\u{1b}[0m \u{1b}[1;35mLayout\u{1b}[0m\u{1b}[1m(\u{1b}[0m\u{1b}[1m)\u{1b}[0m\n\u{1b}[34m├── \u{1b}[0m\u{1b}[34m⬍\u{1b}[0m \u{1b}[1;35mLayout\u{1b}[0m\u{1b}[1m(\u{1b}[0m\u{1b}[33mname\u{1b}[0m=\u{1b}[32m'header'\u{1b}[0m, \u{1b}[33msize\u{1b}[0m=\u{1b}[1;36m3\u{1b}[0m\u{1b}[1m)\u{1b}[0m\n\u{1b}[34m├── \u{1b}[0m\u{1b}[31m⬌\u{1b}[0m \u{1b}[1;35mLayout\u{1b}[0m\u{1b}[1m(\u{1b}[0m\u{1b}[33mname\u{1b}[0m=\u{1b}[32m'main'\u{1b}[0m\u{1b}[1m)\u{1b}[0m\n\u{1b}[34m│   \u{1b}[0m\u{1b}[31m├── \u{1b}[0m\u{1b}[34m⬍\u{1b}[0m \u{1b}[1;35mLayout\u{1b}[0m\u{1b}[1m(\u{1b}[0m\u{1b}[33mname\u{1b}[0m=\u{1b}[32m'side'\u{1b}[0m\u{1b}[1m)\u{1b}[0m\n\u{1b}[34m│   \u{1b}[0m\u{1b}[31m│   \u{1b}[0m\u{1b}[34m├── \u{1b}[0m\u{1b}[34m⬍\u{1b}[0m \u{1b}[1;35mLayout\u{1b}[0m\u{1b}[1m(\u{1b}[0m\u{1b}[33mname\u{1b}[0m=\u{1b}[32m'left1'\u{1b}[0m\u{1b}[1m)\u{1b}[0m\n\u{1b}[34m│   \u{1b}[0m\u{1b}[31m│   \u{1b}[0m\u{1b}[34m└── \u{1b}[0m\u{1b}[34m⬍\u{1b}[0m \u{1b}[1;35mLayout\u{1b}[0m\u{1b}[1m(\u{1b}[0m\u{1b}[33mname\u{1b}[0m=\u{1b}[32m'left2'\u{1b}[0m\u{1b}[1m)\u{1b}[0m\n\u{1b}[34m│   \u{1b}[0m\u{1b}[31m└── \u{1b}[0m\u{1b}[31m⬌\u{1b}[0m \u{1b}[1;35mLayout\u{1b}[0m\u{1b}[1m(\u{1b}[0m\u{1b}[33mname\u{1b}[0m=\u{1b}[32m'body'\u{1b}[0m, \u{1b}[33mratio\u{1b}[0m=\u{1b}[1;36m2\u{1b}[0m\u{1b}[1m)\u{1b}[0m\n\u{1b}[34m│   \u{1b}[0m\u{1b}[31m    \u{1b}[0m\u{1b}[31m├── \u{1b}[0m\u{1b}[34m⬍\u{1b}[0m \u{1b}[1;35mLayout\u{1b}[0m\u{1b}[1m(\u{1b}[0m\u{1b}[33mname\u{1b}[0m=\u{1b}[32m'content'\u{1b}[0m, \u{1b}[33mratio\u{1b}[0m=\u{1b}[1;36m2\u{1b}[0m\u{1b}[1m)\u{1b}[0m\n\u{1b}[34m│   \u{1b}[0m\u{1b}[31m    \u{1b}[0m\u{1b}[31m└── \u{1b}[0m\u{1b}[34m⬍\u{1b}[0m \u{1b}[1;35mLayout\u{1b}[0m\u{1b}[1m(\u{1b}[0m\u{1b}[33mname\u{1b}[0m=\u{1b}[32m's2'\u{1b}[0m\u{1b}[1m)\u{1b}[0m\n\u{1b}[34m│   \u{1b}[0m\u{1b}[31m    \u{1b}[0m\u{1b}[31m    \u{1b}[0m\u{1b}[34m├── \u{1b}[0m\u{1b}[34m⬍\u{1b}[0m \u{1b}[1;35mLayout\u{1b}[0m\u{1b}[1m(\u{1b}[0m\u{1b}[33mname\u{1b}[0m=\u{1b}[32m'top'\u{1b}[0m\u{1b}[1m)\u{1b}[0m\n\u{1b}[34m│   \u{1b}[0m\u{1b}[31m    \u{1b}[0m\u{1b}[31m    \u{1b}[0m\u{1b}[34m├── \u{1b}[0m\u{1b}[34m⬍\u{1b}[0m \u{1b}[1;35mLayout\u{1b}[0m\u{1b}[1m(\u{1b}[0m\u{1b}[33mname\u{1b}[0m=\u{1b}[32m'middle'\u{1b}[0m\u{1b}[1m)\u{1b}[0m\n\u{1b}[34m│   \u{1b}[0m\u{1b}[31m    \u{1b}[0m\u{1b}[31m    \u{1b}[0m\u{1b}[34m└── \u{1b}[0m\u{1b}[34m⬍\u{1b}[0m \u{1b}[1;35mLayout\u{1b}[0m\u{1b}[1m(\u{1b}[0m\u{1b}[33mname\u{1b}[0m=\u{1b}[32m'bottom'\u{1b}[0m\u{1b}[1m)\u{1b}[0m\n\u{1b}[34m└── \u{1b}[0m\u{1b}[34m⬍\u{1b}[0m \u{1b}[1;35mLayout\u{1b}[0m\u{1b}[1m(\u{1b}[0m\u{1b}[33mname\u{1b}[0m=\u{1b}[32m'footer'\u{1b}[0m, \u{1b}[33msize\u{1b}[0m=\u{1b}[1;36m4\u{1b}[0m\u{1b}[1m)\u{1b}[0m\n",
  )
}

///|
test "sizes, ratios and visibility" {
  assert_eq(
    render(sized(), width=40, height=6),
    "\u{1b}[31mleft text\u{1b}[0m            ╭──────────╮\u{1b}[34m╭─\u{1b}[0m\u{1b}[34m \u{1b}[0m\u{1b}[32m'c\u{1b}[0m\u{1b}[34m─╮\u{1b}[0m\n                     │ middle   │\u{1b}[34m│\u{1b}[0m \u{1b}[1;35mLay\u{1b}[0m \u{1b}[34m│\u{1b}[0m\n                     │          │\u{1b}[34m│\u{1b}[0m \u{1b}[1;35mout\u{1b}[0m \u{1b}[34m│\u{1b}[0m\n                     │          │\u{1b}[34m│\u{1b}[0m \u{1b}[1m(\u{1b}[0m   \u{1b}[34m│\u{1b}[0m\n                     │          │\u{1b}[34m│\u{1b}[0m     \u{1b}[34m│\u{1b}[0m\n                     ╰──────────╯\u{1b}[34m╰─────╯\u{1b}[0m\n",
  )
  assert_eq(
    render(sized(), width=20, height=4),
    "\u{1b}[31mleft \u{1b}[0m ╭──────────╮\u{1b}[34m╭╮\u{1b}[0m\n\u{1b}[31mtext\u{1b}[0m  │ middle   │\u{1b}[34m│\u{1b}[0m\u{1b}[34m│\u{1b}[0m\n      │          │\u{1b}[34m│\u{1b}[0m\u{1b}[34m│\u{1b}[0m\n      ╰──────────╯\u{1b}[34m╰╯\u{1b}[0m\n",
  )
  assert_eq(
    render(sized().tree(), width=60),
    "\u{1b}[31m⬌\u{1b}[0m \u{1b}[1;35mLayout\u{1b}[0m\u{1b}[1m(\u{1b}[0m\u{1b}[33mname\u{1b}[0m=\u{1b}[32m'root'\u{1b}[0m\u{1b}[1m)\u{1b}[0m\n\u{1b}[31m├── \u{1b}[0m\u{1b}[34m⬍\u{1b}[0m \u{1b}[1;35mLayout\u{1b}[0m\u{1b}[1m(\u{1b}[0m\u{1b}[33mname\u{1b}[0m=\u{1b}[32m'a'\u{1b}[0m, \u{1b}[33mminimum_size\u{1b}[0m=\u{1b}[1;36m5\u{1b}[0m, \u{1b}[33mratio\u{1b}[0m=\u{1b}[1;36m3\u{1b}[0m\u{1b}[1m)\u{1b}[0m\n\u{1b}[31m├── \u{1b}[0m\u{1b}[34m⬍\u{1b}[0m \u{1b}[1;35mLayout\u{1b}[0m\u{1b}[1m(\u{1b}[0m\u{1b}[33mname\u{1b}[0m=\u{1b}[32m'b'\u{1b}[0m, \u{1b}[33msize\u{1b}[0m=\u{1b}[1;36m12\u{1b}[0m\u{1b}[1m)\u{1b}[0m\n\u{1b}[31m├── \u{1b}[0m\u{1b}[34m⬍\u{1b}[0m \u{1b}[1;2;35mLayout\u{1b}[0m\u{1b}[1;2m(\u{1b}[0m\u{1b}[2;33mname\u{1b}[0m\u{1b}[2m=\u{1b}[0m\u{1b}[2;32m'hidden'\u{1b}[0m\u{1b}[1;2m)\u{1b}[0m\n\u{1b}[31m└── \u{1b}[0m\u{1b}[34m⬍\u{1b}[0m \u{1b}[1;35mLayout\u{1b}[0m\u{1b}[1m(\u{1b}[0m\u{1b}[33mname\u{1b}[0m=\u{1b}[32m'c'\u{1b}[0m\u{1b}[1m)\u{1b}[0m\n",
  )
}

///|
test "render map" {
  let layout = sized()
  ignore(render(layout, width=40, height=6))
  let regions = []
  for layout, render in layout.map() {
    let { x, y, width, height, } = render.region
    regions.push(
      (layout.name.unwrap_or(""), (x, y, width, height), render.render.length()),
    )
  }
  assert_eq(regions, [
    ("a", (0, 0, 21, 6), 6),
    ("b", (21, 0, 12, 6), 6),
    ("c", (33, 0, 7, 6), 6),
  ])
}

///|
test "add split and unsplit" {
  let layout = @layout.Layout::new()
  layout.split(
    [
      @layout.Layout::new(renderable="one"),
      @layout.Layout::new(renderable="two"),
    ],
    splitter="row",
  )
  layout.add_split(["three"])
  assert_eq(
    render(layout, width=30, height=3),
    "one       two       three     \n                              \n                              \n",
  )
  layout.unsplit()
  assert_eq(
    render(layout, width=30, height=5),
    "\u{1b}[34m╭─\u{1b}[0m\u{1b}[34m────────\u{1b}[0m\u{1b}[34m \u{1b}[0m\u{1b}[1;34m(\u{1b}[0m\u{1b}[1;36m30\u{1b}[0m\u{1b}[34m x \u{1b}[0m\u{1b}[1;36m5\u{1b}[0m\u{1b}[1;34m)\u{1b}[0m\u{1b}[34m \u{1b}[0m\u{1b}[34m────────\u{1b}[0m\u{1b}[34m─╮\u{1b}[0m\n\u{1b}[34m│\u{1b}[0m                            \u{1b}[34m│\u{1b}[0m\n\u{1b}[34m│\u{1b}[0m          \u{1b}[1;35mLayout\u{1b}[0m\u{1b}[1m(\u{1b}[0m\u{1b}[1m)\u{1b}[0m          \u{1b}[34m│\u{1b}[0m\n\u{1b}[34m│\u{1b}[0m                            \u{1b}[34m│\u{1b}[0m\n\u{1b}[34m╰────────────────────────────╯\u{1b}[0m\n",
  )
}

///|
test "pretty repr" {
  assert_eq(@layout.Layout::new().pretty_repr(max_width=3), "Layout()")
  assert_eq(@layout.Layout::new().pretty_repr(max_width=12), "Layout()")
  assert_eq(@layout.Layout::new().pretty_repr(max_width=20), "Layout()")
  assert_eq(@layout.Layout::new().pretty_repr(max_width=80), "Layout()")
  assert_eq(
    @layout.Layout::new(name="foo").pretty_repr(max_width=3),
    "Layout(\n    name='foo'\n)",
  )
  assert_eq(
    @layout.Layout::new(name="foo").pretty_repr(max_width=12),
    "Layout(\n    name='foo'\n)",
  )
  assert_eq(
    @layout.Layout::new(name="foo").pretty_repr(max_width=20),
    "Layout(name='foo')",
  )
  assert_eq(
    @layout.Layout::new(name="foo").pretty_repr(max_width=80),
    "Layout(name='foo')",
  )
  assert_eq(
    @layout.Layout::new(name="foo", size=2, minimum_size=3, ratio=4).pretty_repr(
      max_width=3,
    ),
    "Layout(\n    name='foo',\n    size=2,\n    minimum_size=3,\n    ratio=4\n)",
  )
  assert_eq(
    @layout.Layout::new(name="foo", size=2, minimum_size=3, ratio=4).pretty_repr(
      max_width=12,
    ),
    "Layout(\n    name='foo',\n    size=2,\n    minimum_size=3,\n    ratio=4\n)",
  )
  assert_eq(
    @layout.Layout::new(name="foo", size=2, minimum_size=3, ratio=4).pretty_repr(
      max_width=20,
    ),
    "Layout(\n    name='foo',\n    size=2,\n    minimum_size=3,\n    ratio=4\n)",
  )
  assert_eq(
    @layout.Layout::new(name="foo", size=2, minimum_size=3, ratio=4).pretty_repr(
      max_width=80,
    ),
    "Layout(name='foo', size=2, minimum_size=3, ratio=4)",
  )
  assert_eq(
    @layout.Layout::new(name="it's \"q\"").pretty_repr(max_width=3),
    "Layout(\n    name='it\\'s \"q\"'\n)",
  )
  assert_eq(
    @layout.Layout::new(name="it's \"q\"").pretty_repr(max_width=12),
    "Layout(\n    name='it\\'s \"q\"'\n)",
  )
  assert_eq(
    @layout.Layout::new(name="it's \"q\"").pretty_repr(max_width=20),
    "Layout(\n    name='it\\'s \"q\"'\n)",
  )
  assert_eq(
    @layout.Layout::new(name="it's \"q\"").pretty_repr(max_width=80),
    "Layout(name='it\\'s \"q\"')",
  )
}
