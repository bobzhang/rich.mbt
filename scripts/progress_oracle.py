"""Generate the *_oracle_test.mbt differential tests of spinner/, progress_bar/,
live/, status/ and progress/ (expected output computed with upstream Rich).

Run from the repository root with the Python oracle:
    .venv/bin/python scripts/progress_oracle.py && moon fmt
"""
import io

from rich.console import Console
from rich.live import Live
from rich.progress import (
    BarColumn,
    DownloadColumn,
    FileSizeColumn,
    MofNCompleteColumn,
    Progress,
    SpinnerColumn,
    Task,
    TaskProgressColumn,
    TextColumn,
    TimeElapsedColumn,
    TimeRemainingColumn,
    TotalFileSizeColumn,
    TransferSpeedColumn,
)
from rich.progress_bar import ProgressBar
from rich.rule import Rule
from rich.spinner import Spinner
from rich.status import Status
from rich.table import Column
from rich.text import Text

def lit(s):
    r = []
    for c in s:
        o = ord(c)
        if c == '"':
            r.append('\\"')
        elif c == '\\':
            r.append('\\\\')
        elif c == '\n':
            r.append('\\n')
        elif c == '\r':
            r.append('\\r')
        elif c == '\t':
            r.append('\\t')
        elif o < 0x20 or o == 0x7f:
            r.append("\\u{%x}" % o)
        else:
            r.append(c)
    return '"' + "".join(r) + '"'


# Upstream caches the ANSI codes of a style for the first color system it is
# rendered with (see DEVIATIONS.md, style); rich.mbt does not, so disable the
# cache to compare consoles with different color systems.
from rich.style import Style

_style_render = Style.render


def _uncached_render(self, *args, **kwargs):
    self._ansi = None
    return _style_render(self, *args, **kwargs)


Style.render = _uncached_render

HEADER = "// Differential tests: expected output computed with upstream Rich 15.0.0\n// (scripts/progress_oracle.py).\n"


def console(width=80, color_system="truecolor", **kw):
    kw.setdefault("force_terminal", True)
    return Console(
        file=io.StringIO(),
        width=width,
        color_system=color_system,
        legacy_windows=kw.pop("legacy_windows", False),
        _environ={},
        **kw,
    )


def mbt_console(width=80, color_system="truecolor", extra=""):
    cs = "None" if color_system is None else f'Some("{color_system}")'
    return (
        f"@rich.Console::new(file=@rich.StringIO::new(), width={width}, "
        f"color_system={cs}, legacy_windows=false, environ={{}}{extra})"
    )


# ---------------------------------------------------------------- spinner
def gen_spinner():
    out = [HEADER]
    names = ["dots", "line", "earth", "arc", "aesthetic", "bouncingBall", "toggle13", "material"]
    cases = []
    for name in names:
        for speed in (1.0, 2.5):
            frames = []
            spinner = Spinner(name, speed=speed, style="red")
            for t in (0.0, 0.05, 0.13, 0.5, 1.37, 10.0):
                frames.append(str(spinner.render(t)))
            cases.append((name, speed, frames))
    out.append("///|\ntest \"oracle spinner frames\" {")
    for name, speed, frames in cases:
        out.append(f"  let spinner = @spinner.Spinner::new({lit(name)}, speed={speed!r}, style=\"red\")")
        out.append("  let frames = [0.0, 0.05, 0.13, 0.5, 1.37, 10.0].map(t => {")
        out.append("    guard spinner.render(t).text_kind() is Text(t) else { abort(\"text\") }")
        out.append("    t.plain()")
        out.append("  })")
        out.append(f"  assert_eq(frames, [{', '.join(lit(f) for f in frames)}])")
    out.append("}\n")

    # spinner with text, renderable text, speed update; rendered through console
    t = [0.0]
    c = console(width=30, get_time=lambda: t[0])
    s = Spinner("dots2", text=Text("working", style="bold"), style="green")
    r = Spinner("line", text=Rule("x"))
    for step in range(5):
        c.print(s)
        c.print(r)
        if step == 2:
            s.update(text="[blue]phase 2", speed=3.0, style="magenta")
        t[0] += 0.09
    out.append(f'''///|
test "oracle spinner console" {{
  let t = Ref(0.0)
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(file~, width=30, color_system=Some("truecolor"), force_terminal=true, legacy_windows=false, get_time=() => t.val, environ={{}})
  let s = @spinner.Spinner::new("dots2", text=@rich.Text::new(text="working", style="bold"), style="green")
  let r = @spinner.Spinner::new("line", text=@rich.Rule::new(title="x"))
  for step in 0..<5 {{
    console.print(s)
    console.print(r)
    if step == 2 {{
      s.update(text="[blue]phase 2", speed=3.0, style="magenta")
    }}
    t.val += 0.09
  }}
  assert_eq(file.getvalue(), {lit(c.file.getvalue())})
}}
''')
    open("spinner/spinner_oracle_test.mbt", "w").write("\n".join(out))


# ---------------------------------------------------------------- progress bar
def gen_bar():
    out = [HEADER]
    out.append("///|\ntest \"oracle progress bar\" {")
    for color_system in ("truecolor", "256", "standard", None):
        for legacy in (False, True):
            for no_color in (False, True):
                c = Console(file=io.StringIO(), width=24, color_system=color_system,
                            legacy_windows=legacy, no_color=no_color, force_terminal=True, _environ={})
                for total, completed, width, pulse, anim in [
                    (100.0, 0.0, None, False, None),
                    (100.0, 33.0, 20, False, None),
                    (100.0, 34.0, 20, False, None),
                    (7.0, 7.0, 10, False, None),
                    (7.0, 9.0, None, False, None),
                    (0.0, 0.0, 12, False, None),
                    (100.0, -5.0, 8, False, None),
                    (None, 0.0, 15, False, 1.234),
                    (100.0, 50.0, 30, True, 0.5),
                ]:
                    bar = ProgressBar(total=total, completed=completed, width=width, pulse=pulse, animation_time=anim)
                    c.print(bar)
                    c.print("|")
                cs = "None" if color_system is None else f'Some("{color_system}")'
                out.append("  {")
                out.append(f"    let file = @rich.StringIO::new()")
                out.append(f"    let console = @rich.Console::new(file~, width=24, color_system={cs}, legacy_windows={str(legacy).lower()}, no_color={str(no_color).lower()}, force_terminal=true, environ={{}})")
                out.append("    let cases : Array[(Double?, Double, Int?, Bool, Double?)] = [")
                out.append("      (Some(100.0), 0.0, None, false, None),")
                out.append("      (Some(100.0), 33.0, Some(20), false, None),")
                out.append("      (Some(100.0), 34.0, Some(20), false, None),")
                out.append("      (Some(7.0), 7.0, Some(10), false, None),")
                out.append("      (Some(7.0), 9.0, None, false, None),")
                out.append("      (Some(0.0), 0.0, Some(12), false, None),")
                out.append("      (Some(100.0), -5.0, Some(8), false, None),")
                out.append("      (None, 0.0, Some(15), false, Some(1.234)),")
                out.append("      (Some(100.0), 50.0, Some(30), true, Some(0.5)),")
                out.append("    ]")
                out.append("    for case in cases {")
                out.append("      let (total, completed, width, pulse, animation_time) = case")
                out.append("      let bar = @progress_bar.ProgressBar::new(total~, completed~, width?, pulse~, animation_time?)")
                out.append("      console.print(bar)")
                out.append("      console.print(\"|\")")
                out.append("    }")
                out.append(f"    assert_eq(file.getvalue(), {lit(c.file.getvalue())})")
                out.append("  }")
    out.append("}\n")
    open("progress_bar/progress_bar_oracle_test.mbt", "w").write("\n".join(out))


# ---------------------------------------------------------------- live
def gen_live():
    out = [HEADER]
    # nested lives
    c = Console(file=io.StringIO(), width=30, height=10, force_terminal=True,
                legacy_windows=False, color_system=None, _environ={})
    a = Live("outer", console=c, auto_refresh=False)
    b = Live("inner", console=c, auto_refresh=False)
    a.start(refresh=True)
    b.start(refresh=True)
    b.update("inner2", refresh=True)
    c.print("hello")
    b.stop()
    a.update("outer2", refresh=True)
    a.stop()
    out.append(f'''///|
test "oracle nested live" {{
  let file = @rich.StringIO::new()
  let c = @rich.Console::new(file~, width=30, height=10, force_terminal=true, legacy_windows=false, color_system=None, environ={{}})
  let a = @live.Live::new(renderable="outer", console=c, auto_refresh=false)
  let b = @live.Live::new(renderable="inner", console=c, auto_refresh=false)
  a.start(refresh=true)
  b.start(refresh=true)
  b.update("inner2", refresh=true)
  c.print("hello")
  b.stop()
  a.update("outer2", refresh=true)
  a.stop()
  assert_eq(file.getvalue(), {lit(c.file.getvalue())})
}}
''')
    # non terminal, transient and not
    for transient in (False, True):
        c = Console(file=io.StringIO(), width=30, height=10, force_terminal=False,
                    legacy_windows=False, color_system=None, _environ={})
        with Live("[bold]x", console=c, auto_refresh=False, transient=transient) as live:
            live.update("[red]y[/red] z", refresh=True)
            c.print("between")
            live.update(Text("final"))
        out.append(f'''///|
test "oracle live file transient={transient}" {{
  let file = @rich.StringIO::new()
  let c = @rich.Console::new(file~, width=30, height=10, force_terminal=false, legacy_windows=false, color_system=None, environ={{}})
  let live = @live.Live::new(renderable="[bold]x", console=c, auto_refresh=false, transient={str(transient).lower()})
  live.run(() => {{
    live.update("[red]y[/red] z", refresh=true)
    c.print("between")
    live.update(@rich.Text::new(text="final"))
  }})
  assert_eq(file.getvalue(), {lit(c.file.getvalue())})
}}
''')
    # styled, overflow with color, alt screen with updates
    c = Console(file=io.StringIO(), width=12, height=4, force_terminal=True,
                legacy_windows=False, color_system="truecolor", _environ={})
    with Live(Text("start", style="green"), console=c, auto_refresh=False, screen=True) as live:
        live.update("[b]line1\nline2\nline3\nline4\nline5", refresh=True)
        live.update("bye", refresh=True)
    out.append(f'''///|
test "oracle live screen updates" {{
  let file = @rich.StringIO::new()
  let c = @rich.Console::new(file~, width=12, height=4, force_terminal=true, legacy_windows=false, color_system=Some("truecolor"), environ={{}})
  let live = @live.Live::new(renderable=@rich.Text::new(text="start", style="green"), console=c, auto_refresh=false, screen=true)
  live.run(() => {{
    live.update("[b]line1\\nline2\\nline3\\nline4\\nline5", refresh=true)
    live.update("bye", refresh=true)
  }})
  assert_eq(file.getvalue(), {lit(c.file.getvalue())})
}}
''')
    c = Console(file=io.StringIO(), width=12, height=4, force_terminal=True,
                legacy_windows=False, color_system="truecolor", _environ={})
    with Live(console=c, auto_refresh=False) as live:
        live.update("a\nb\nc\nd\ne\nf", refresh=True)
        c.log  # noqa
        c.print("[u]log line")
    out.append(f'''///|
test "oracle live ellipsis styled" {{
  let file = @rich.StringIO::new()
  let c = @rich.Console::new(file~, width=12, height=4, force_terminal=true, legacy_windows=false, color_system=Some("truecolor"), environ={{}})
  let live = @live.Live::new(console=c, auto_refresh=false)
  live.run(() => {{
    live.update("a\\nb\\nc\\nd\\ne\\nf", refresh=true)
    c.print("[u]log line")
  }})
  assert_eq(file.getvalue(), {lit(c.file.getvalue())})
}}
''')
    open("live/live_oracle_test.mbt", "w").write("\n".join(out))


# ---------------------------------------------------------------- status
def gen_status():
    out = [HEADER]
    t = [0.0]
    c = Console(file=io.StringIO(), width=40, color_system="truecolor", force_terminal=True,
                legacy_windows=False, get_time=lambda: t[0], _environ={})
    status = Status("[bold]Working", console=c, spinner="arc")
    for i in range(4):
        c.print(status)
        t[0] += 0.1
        if i == 1:
            status.update(status="Still [i]working", spinner_style="yellow")
        if i == 2:
            status.update(spinner="dots", speed=2.0)
    out.append(f'''///|
test "oracle status render" {{
  let t = Ref(0.0)
  let file = @rich.StringIO::new()
  let c = @rich.Console::new(file~, width=40, color_system=Some("truecolor"), force_terminal=true, legacy_windows=false, get_time=() => t.val, environ={{}})
  let status = @status.Status::new("[bold]Working", console=c, spinner="arc")
  for i in 0..<4 {{
    c.print(status)
    t.val += 0.1
    if i == 1 {{
      status.update(status="Still [i]working", spinner_style="yellow")
    }}
    if i == 2 {{
      status.update(spinner="dots", speed=2.0)
    }}
  }}
  assert_eq(file.getvalue(), {lit(c.file.getvalue())})
}}
''')
    open("status/status_oracle_test.mbt", "w").write("\n".join(out))


# ---------------------------------------------------------------- progress
FORMATS = [
    "{task.description}",
    "{task.percentage:>3.0f}%",
    "{task.completed}",
    "{task.total}",
    "{task.completed:.2f}/{task.total:,.1f}",
    "{task.percentage:05.1f}",
    "{task.description:^15}|",
    "{task.description:*<14}",
    "{task.description!r}",
    "{task.id:03d}",
    "{task.id:>+4}",
    "{task.fields[name]}",
    "{task.fields[n]:>5}",
    "{task.fields[n]:<5}|",
    "{task.fields[x]:.3f}",
    "{task.fields[x]}",
    "{task.fields[big]:,d}",
    "{task.fields[big]:_}",
    "{task.fields[n]:x} {task.fields[n]:X} {task.fields[n]:o} {task.fields[n]:b}",
    "{task.fields[flag]}",
    "{task.remaining}",
    "{task.started} {task.finished} {task.visible}",
    "{{literal}} {task.id}",
    "{task.completed:+.1f} {task.completed: .1f}",
    "{task.completed:,}",
    "{task.total:e} {task.completed:10.3E}",
    "{task.description:.4}",
    "{task.percentage:=+10.2f}",
    "{task.completed:%}",
    "{task.completed:.0%}",
    "{task.elapsed}",
    "{task.speed}",
    "{task.completed:12,.3f}",
]


def gen_progress():
    out = [HEADER]
    # format strings
    task = Task(3, "Downloading", 1234, 567.5, _get_time=lambda: 5.0,
                fields={"name": "x y", "n": 42, "x": 3.14159, "big": 1234567, "flag": True})
    task.start_time = 1.5
    out.append('''///|
test "oracle format_task" {
  let task = @progress.Task::new(3, "Downloading", Some(1234.0), 567.5, get_time=() => 5.0, fields={ "name": "x y", "n": 42, "x": 3.14159, "big": 1234567, "flag": true })
  task.start_time = Some(1.5)''')
    for f in FORMATS:
        out.append(f"  assert_eq(@progress.format_task({lit(f)}, task), {lit(f.format(task=task))})")
    task2 = Task(0, "Unknown", None, 0.0, _get_time=lambda: 5.0)
    out.append('  let task2 = @progress.Task::new(0, "Unknown", None, 0.0, get_time=() => 5.0)')
    for f in ["{task.total}", "{task.percentage:>3.0f}%", "{task.remaining}", "{task.elapsed}", "{task.time_remaining}"]:
        out.append(f"  assert_eq(@progress.format_task({lit(f)}, task2), {lit(f.format(task=task2))})")
    out.append("}\n")

    # rendering scenarios
    def scenario(name, py_build, mbt_build, width=80, color_system="truecolor"):
        clock = [0.0]
        c = console(width=width, color_system=color_system)
        progress = py_build(c, lambda: clock[0], clock)
        c.print(progress)
        out.append(f'''///|
test "oracle progress {name}" {{
  let clock = Ref(0.0)
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(file~, width={width}, color_system=Some("{color_system}"), force_terminal=true, legacy_windows=false, environ={{}})
  let get_time = () => clock.val
{mbt_build}
  console.print(progress)
  assert_eq(file.getvalue(), {lit(c.file.getvalue())})
}}
''')

    def build_default(c, get_time, clock):
        p = Progress(console=c, get_time=get_time, auto_refresh=False)
        t1 = p.add_task("[red]Download", total=1000)
        t2 = p.add_task("Unknown", total=None)
        t3 = p.add_task("Done", total=10)
        t4 = p.add_task("Later", start=False)
        for i in range(5):
            clock[0] += 0.7
            p.advance(t1, 37)
            p.update(t3, advance=3)
        p.update(t2, description="Unknown [b]still")
        return p

    scenario("default columns", build_default, '''  let p = @progress.Progress::new(console~, get_time~, auto_refresh=false)
  let t1 = p.add_task("[red]Download", total=Some(1000.0))
  let t2 = p.add_task("Unknown", total=None)
  let t3 = p.add_task("Done", total=Some(10.0))
  let _t4 = p.add_task("Later", start=false)
  for _ in 0..<5 {
    clock.val += 0.7
    p.advance(t1, advance=37.0)
    p.update(t3, advance=3.0)
  }
  p.update(t2, description="Unknown [b]still")
  let progress = p''')

    def build_files(c, get_time, clock):
        p = Progress(
            SpinnerColumn(finished_text="[green]✓"),
            TextColumn("{task.description}", justify="right"),
            MofNCompleteColumn(),
            TimeElapsedColumn(),
            TransferSpeedColumn(),
            DownloadColumn(binary_units=True),
            FileSizeColumn(),
            TotalFileSizeColumn(),
            console=c, get_time=get_time, auto_refresh=False,
        )
        a = p.add_task("big.iso", total=4.7e9)
        b = p.add_task("small", total=2048)
        d = p.add_task("stream", total=None)
        for i in range(3):
            clock[0] += 1.5
            p.advance(a, 1.234e8)
            p.advance(b, 1000)
            p.advance(d, 12345)
        clock[0] += 90000
        p.advance(b, 1048)
        return p

    scenario("file columns", build_files, '''  let p = @progress.Progress::new(
    columns=[
      @progress.SpinnerColumn::new(finished_text="[green]✓"),
      @progress.TextColumn::new("{task.description}", justify=Right),
      @progress.MofNCompleteColumn::new(),
      @progress.TimeElapsedColumn::new(),
      @progress.TransferSpeedColumn::new(),
      @progress.DownloadColumn::new(binary_units=true),
      @progress.FileSizeColumn::new(),
      @progress.TotalFileSizeColumn::new(),
    ],
    console~, get_time~, auto_refresh=false,
  )
  let a = p.add_task("big.iso", total=Some(4.7e9))
  let b = p.add_task("small", total=Some(2048.0))
  let d = p.add_task("stream", total=None)
  for _ in 0..<3 {
    clock.val += 1.5
    p.advance(a, advance=1.234e8)
    p.advance(b, advance=1000.0)
    p.advance(d, advance=12345.0)
  }
  clock.val += 90000.0
  p.advance(b, advance=1048.0)
  let progress = p''', width=120)

    def build_speed(c, get_time, clock):
        p = Progress(
            TextColumn("[progress.description]{task.description}"),
            BarColumn(bar_width=20),
            TaskProgressColumn(show_speed=True),
            TimeRemainingColumn(compact=True),
            TimeRemainingColumn(elapsed_when_finished=True),
            "{task.fields[status]}",
            console=c, get_time=get_time, auto_refresh=False, expand=True,
        )
        a = p.add_task("items", total=None, status="ok")
        b = p.add_task("known", total=50, status="[i]busy")
        for i in range(6):
            clock[0] += 0.25
            p.advance(a, 1500)
            p.advance(b, 9)
        p.update(b, status="done", refresh=True)
        return p

    scenario("speed expand", build_speed, '''  let p = @progress.Progress::new(
    columns=[
      @progress.TextColumn::new("[progress.description]{task.description}"),
      @progress.BarColumn::new(bar_width=Some(20)),
      @progress.TaskProgressColumn::new(show_speed=true),
      @progress.TimeRemainingColumn::new(compact=true),
      @progress.TimeRemainingColumn::new(elapsed_when_finished=true),
      "{task.fields[status]}",
    ],
    console~, get_time~, auto_refresh=false, expand=true,
  )
  let a = p.add_task("items", total=None, fields={ "status": "ok" })
  let b = p.add_task("known", total=Some(50.0), fields={ "status": "[i]busy" })
  for _ in 0..<6 {
    clock.val += 0.25
    p.advance(a, advance=1500.0)
    p.advance(b, advance=9.0)
  }
  p.update(b, fields={ "status": "done" }, refresh=true)
  let progress = p''', width=100)

    def build_reset(c, get_time, clock):
        p = Progress(console=c, get_time=get_time, auto_refresh=False, speed_estimate_period=2.0)
        a = p.add_task("a", total=100)
        for i in range(10):
            clock[0] += 0.5
            p.advance(a, 4)
        p.reset(a, total=40, completed=10, description="a again")
        clock[0] += 1
        p.update(a, advance=5)
        b = p.add_task("hidden", visible=False)
        p.update(b, completed=100)
        return p

    scenario("reset", build_reset, '''  let p = @progress.Progress::new(console~, get_time~, auto_refresh=false, speed_estimate_period=2.0)
  let a = p.add_task("a", total=Some(100.0))
  for _ in 0..<10 {
    clock.val += 0.5
    p.advance(a, advance=4.0)
  }
  p.reset(a, total=40.0, completed=10.0, description="a again")
  clock.val += 1.0
  p.update(a, advance=5.0)
  let b = p.add_task("hidden", visible=false)
  p.update(b, completed=100.0)
  let progress = p''', width=70, color_system="256")

    # live progress with refreshes, non-interactive console
    c = Console(file=io.StringIO(), width=60, color_system="standard", force_terminal=False,
                legacy_windows=False, _environ={})
    clock = [0.0]
    p = Progress(console=c, get_time=lambda: clock[0], auto_refresh=False)
    with p:
        t = p.add_task("job", total=3)
        for i in range(3):
            clock[0] += 1
            p.advance(t)
            p.refresh()
    out.append(f'''///|
test "oracle progress non interactive" {{
  let clock = Ref(0.0)
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(file~, width=60, color_system=Some("standard"), force_terminal=false, legacy_windows=false, environ={{}})
  let p = @progress.Progress::new(console~, get_time=() => clock.val, auto_refresh=false)
  p.run(() => {{
    let t = p.add_task("job", total=Some(3.0))
    for _ in 0..<3 {{
      clock.val += 1.0
      p.advance(t)
      p.refresh()
    }}
  }})
  assert_eq(file.getvalue(), {lit(c.file.getvalue())})
}}
''')

    # TimeElapsedColumn with days
    task = Task(0, "t", 10.0, 3.0, _get_time=lambda: 200000.0)
    task.start_time = 0.0
    e1 = str(TimeElapsedColumn().render(task))
    task.start_time = 199999.0 - 86400.0
    e2 = str(TimeElapsedColumn().render(task))
    out.append(f'''///|
test "oracle time elapsed days" {{
  let task = @progress.Task::new(0, "t", Some(10.0), 3.0, get_time=() => 200000.0)
  task.start_time = Some(0.0)
  assert_eq(@progress.TimeElapsedColumn::new().render(task).plain(), {lit(e1)})
  task.start_time = Some(199999.0 - 86400.0)
  assert_eq(@progress.TimeElapsedColumn::new().render(task).plain(), {lit(e2)})
}}
''')
    open("progress/progress_oracle_test.mbt", "w").write("\n".join(out))


gen_spinner()
gen_bar()
gen_live()
gen_status()
gen_progress()
