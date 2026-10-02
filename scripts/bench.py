"""Rendering benchmark for upstream Rich; counterpart of `cmd/bench`.

Usage: .venv/bin/python scripts/bench.py [workload ...]

Every workload renders to an in-memory console (truecolor, width 100). It is
warmed up for WARMUP_SECONDS, then timed in ROUNDS rounds of at least
ROUND_SECONDS each; the fastest round is reported as
`name  iterations  ms/iter  output-length`.
"""

import io
import json
import sys
import time
from pathlib import Path

from rich.__main__ import make_test_card
from rich.console import Console
from rich.json import JSON
from rich.markdown import Markdown
from rich.pretty import Pretty
from rich.progress import Progress
from rich.syntax import Syntax
from rich.table import Table
from rich.text import Text

WARMUP_SECONDS = 0.3
ROUND_SECONDS = 0.3
ROUNDS = 3
RICH = Path("/Users/dii/git/rich.mbt/.repos/rich")

WORDS = (
    "lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod "
    "tempor incididunt ut labore et dolore magna aliqua"
).split()
SPAN_STYLES = ["bold", "italic red", "underline #ff8800", "on blue", "dim cyan"]


def new_console() -> Console:
    return Console(
        file=io.StringIO(),
        width=100,
        color_system="truecolor",
        force_terminal=True,
        legacy_windows=False,
        _environ={},
    )


def lorem(n_words: int) -> str:
    out = []
    for i in range(n_words):
        if i > 0:
            out.append("\n\n" if i % 150 == 0 else " ")
        out.append(WORDS[(i * 7) % len(WORDS)])
    return "".join(out)


def json_doc(n: int) -> str:
    items = []
    for i in range(n):
        active = "true" if i % 2 == 0 else "false"
        items.append(
            f'{{"id": {i}, "name": "item {i}", "active": {active}, '
            f'"score": {i}.5, "tags": ["alpha", "beta", "gamma"], '
            f'"meta": {{"created": "2024-01-{i % 28 + 1:02d}", '
            f'"owner": null, "ratio": 0.{i % 10}5}}}}'
        )
    return "[" + ", ".join(items) + "]"


def python_source() -> str:
    lines = (RICH / "rich" / "console.py").read_text().splitlines(keepends=True)
    return "".join(lines[:2000])


def readme() -> str:
    return (RICH / "README.md").read_text()


# ---------------------------------------------------------------- workloads


def setup_card(console):
    card = make_test_card()
    return lambda: console.print(card)


def setup_table(console):
    def run():
        table = Table(title="Big table", row_styles=["", "dim"])
        table.add_column("ID", justify="right", style="cyan")
        table.add_column("Name", style="magenta")
        table.add_column("Status")
        table.add_column("Score", justify="right")
        table.add_column("Description")
        table.add_column("Tags", style="green")
        for i in range(1000):
            table.add_row(
                str(i),
                f"[bold]User {i}[/bold]",
                "[green]ok[/]" if i % 3 else "[red]fail[/]",
                f"{i * 3}.{i % 100:02d}",
                " ".join(WORDS[(i + k) % len(WORDS)] for k in range(i % 12 + 1)),
                f"[i]tag{i % 7}[/i], [u]x{i % 5}[/u]",
            )
        console.print(table)

    return run


def setup_text(console):
    plain = lorem(33000)  # ~200 KB

    def run():
        text = Text(plain)
        pos = 0
        k = 0
        while pos < len(plain):
            end = min(pos + 17 + k % 23, len(plain))
            text.stylize(SPAN_STYLES[k % len(SPAN_STYLES)], pos, end)
            pos = end + 40 + k % 31
            k += 1
        console.print(text, justify="full")

    return run


def setup_markup(console):
    lines = [
        f"[bold red]Error[/] in [link]file_{i}.py[/link]:{i} - [i]value[/i]="
        f"[cyan]{i * 7}[/] {{'a': {i}, 'b': [1, 2, 3]}} True None 3.14 "
        f"/usr/lib/x.so 0x{i:x} https://example.com/{i} [on #223344]done[/]"
        for i in range(2000)
    ]

    def run():
        for line in lines:
            console.print(line)

    return run


def setup_pretty(console):
    data = json.loads(json_doc(300))
    return lambda: console.print(Pretty(data))


def setup_syntax(console):
    code = python_source()
    return lambda: console.print(
        Syntax(code, "python", theme="monokai", line_numbers=True)
    )


def setup_markdown(console):
    text = readme()
    return lambda: console.print(Markdown(text))


def setup_progress(console):
    clock = [0.0]
    progress = Progress(console=console, auto_refresh=False, get_time=lambda: clock[0])
    ids = [
        progress.add_task(f"task {i}", total=1000.0) for i in range(100)
    ]
    state = [0]

    def run():
        state[0] += 1
        clock[0] += 0.25
        for n, task_id in enumerate(ids):
            progress.update(task_id, completed=float((n * 37 + state[0] * 3) % 1000))
        console.print(progress.get_renderable())

    return run


def setup_json(console):
    doc = json_doc(300)
    return lambda: console.print(JSON(doc))


WORKLOADS = {
    "card": setup_card,
    "table": setup_table,
    "text": setup_text,
    "markup": setup_markup,
    "pretty": setup_pretty,
    "syntax": setup_syntax,
    "markdown": setup_markdown,
    "progress": setup_progress,
    "json": setup_json,
}


def bench(name: str) -> None:
    console = new_console()
    run = WORKLOADS[name](console)
    run()
    length = len(console.file.getvalue())

    def timed(seconds):
        iterations = 0
        start = time.perf_counter()
        while True:
            console.file = io.StringIO()
            run()
            iterations += 1
            elapsed = time.perf_counter() - start
            if elapsed >= seconds:
                return iterations, elapsed * 1000 / iterations

    timed(WARMUP_SECONDS)
    iterations, ms = min((timed(ROUND_SECONDS) for _ in range(ROUNDS)), key=lambda r: r[1])
    print(f"{name:<10} {iterations:>6} {ms:>10.3f} ms {length:>9}")
    sys.stdout.flush()


def main() -> None:
    names = sys.argv[1:] or list(WORKLOADS)
    for name in names:
        bench(name)


if __name__ == "__main__":
    main()
