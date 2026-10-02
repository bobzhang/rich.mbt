"""Differential data for the `cli` package (port of rich-cli): cli/oracle_data_test.mbt.

rich-cli pins `rich<13`, so it is not installed into the oracle venv (that
would replace Rich 15). Instead its source (`.repos/rich-cli/src`) is run
against Rich 15 with `click` put on the path separately:

    pip install --target /tmp/pylib --no-deps click
    PYTHONPATH=/tmp/pylib:/Users/dii/git/rich.mbt/.repos/rich-cli/src \\
      /Users/dii/git/rich.mbt/.venv/bin/python scripts/cli_oracle.py

Each case runs `rich_cli.__main__.main` with the fixtures of cli/testdata in
the current directory, a hermetic environment (`COLUMNS`, `COLORTERM`) and
captured stdin/stdout/stderr, and records stdout, stderr, the exit code and
the exported files.
"""

from __future__ import annotations

import functools
import io
import os
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from mbt_literal import mbt_str  # noqa: E402

import rich.console  # noqa: E402
import rich_cli.__main__ as cli  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
FIXTURES = ROOT / "cli/testdata"
OUT = ROOT / "cli/oracle_data_test.mbt"

LONG = (
    "I must not fear. Fear is the mind-killer. Fear is the little-death "
    "that brings total obliteration."
)

# (name, args, stdin, width, tty)
CASES: list[tuple[str, list[str], str, int, bool]] = [
    # syntax
    ("syntax", ["sample.py"], "", 60, True),
    ("syntax numbers guides", ["sample.py", "-n", "-g"], "", 60, True),
    ("syntax theme", ["sample.py", "--theme", "monokai", "-n"], "", 50, True),
    ("syntax head", ["sample.py", "--head", "3"], "", 60, True),
    ("syntax tail", ["sample.py", "-t", "2", "-n"], "", 60, True),
    ("syntax no-wrap", ["sample.py", "--no-wrap", "-w", "40"], "", 60, True),
    ("syntax lexer", ["sample.rs", "-x", "javascript"], "", 60, True),
    ("syntax guess", ["sample.rs", "--theme", "dracula"], "", 60, True),
    ("syntax forced on markdown", ["--syntax", "sample.md"], "", 60, True),
    ("syntax text file", ["notes.txt"], "", 60, True),
    ("syntax crlf", ["crlf.txt", "-n"], "", 40, True),
    ("syntax stdin", ["-"], "def f(x):\n    return x\n", 60, True),
    ("syntax stdin lexer", ["-", "-x", "python"], "def f(x):\n    return x\n", 60, True),
    ("syntax plain", ["sample.py"], "", 60, False),
    ("syntax force terminal", ["sample.py", "--force-terminal"], "", 60, False),
    ("syntax panel", ["sample.rs", "-a", "rounded", "--title", "sample.rs", "-e"], "", 60, True),
    # markdown
    ("markdown", ["sample.md"], "", 70, True),
    ("markdown narrow", ["sample.md", "--theme", "monokai"], "", 40, True),
    ("markdown hyperlinks", ["-m", "sample.md", "-y"], "", 70, True),
    ("markdown stdin", ["-", "--markdown"], "# Title\n\nSome `code` here.\n", 50, True),
    ("markdown plain", ["sample.md"], "", 70, False),
    # json
    ("json", ["sample.json"], "", 60, True),
    ("json stdin", ["-J", "-"], '[1, 2.5, "three", {"four": false}]', 60, True),
    ("json padding panel", ["sample.json", "-d", "1,2", "-a", "heavy", "-S", "red"], "", 60, True),
    # csv
    ("csv", ["airtravel.csv"], "", 60, True),
    ("csv head", ["deniro.csv", "--head", "5"], "", 70, True),
    ("csv tail title caption", ["deniro.csv", "--tail", "3", "--title", "De Niro", "--caption", "Rotten Tomatoes"], "", 70, True),
    ("csv tsv", ["sample.tsv"], "", 60, True),
    ("csv semicolon", ["semicolon.csv"], "", 60, True),
    ("csv no header", ["numbers.csv"], "", 60, True),
    ("csv stdin", ["--csv", "-"], "a,b\n1,x\n2,y\n", 60, True),
    ("csv plain", ["airtravel.csv"], "", 60, False),
    # notebook
    ("ipynb", ["notebook.ipynb"], "", 70, True),
    ("ipynb options", ["--ipynb", "notebook.ipynb", "-n", "--head", "1"], "", 60, True),
    # print
    ("print", ["Hello, [bold magenta]World[/]!", "--print"], "", 60, True),
    ("print width center right", [LONG, "-p", "-w", "40", "-c", "-R"], "", 60, True),
    ("print full", [LONG, "-p", "-w", "40", "-F"], "", 60, True),
    ("print text center", [LONG, "-p", "-C"], "", 50, True),
    ("print right", ["right [i]aligned[/i]", "-p", "-r"], "", 50, True),
    ("print left width", ["left", "-p", "-l", "-w", "20", "-a", "square"], "", 50, True),
    ("print soft", [LONG, "-p", "--soft"], "", 30, True),
    ("print emoji", [":sparkles: [b]shiny[/b] :thumbs_up:", "-p", "-j"], "", 40, True),
    ("print no emoji", [":sparkles: shiny", "-p"], "", 40, True),
    ("print style", ["Hello, [b]World[/b]!", "--print", "--style", "on blue"], "", 40, True),
    ("print panel", ["Hello", "-p", "-a", "double", "--title", "Title", "--caption", "Caption", "-e"], "", 40, True),
    ("print panel ascii", ["Hello", "-p", "--panel", "ascii2", "-S", "green"], "", 40, True),
    ("print padding", ["Padded", "-p", "-d", "1,2,1,4", "-a", "rounded"], "", 40, True),
    ("print padding expand", ["Padded", "-p", "-d", "1", "-e", "-a", "rounded"], "", 40, True),
    ("print max width", [LONG, "-p", "-W", "30"], "", 60, True),
    ("print stdin", ["-", "-p"], "from [red]stdin[/red]\n", 40, True),
    ("print highlight", ["numbers 123 and 'strings' and https://example.com", "-p"], "", 70, True),
    ("print plain", ["Hello, [bold]World[/]!", "-p"], "", 40, False),
    ("print no-wrap", [LONG, "-p", "--no-wrap"], "", 40, True),
    # rule
    ("rule", ["Hello [b]World[/b]!", "--rule"], "", 40, True),
    ("rule style char", ["Hello", "-u", "--rule-style", "red", "--rule-char", "="], "", 40, True),
    ("rule left", ["Left", "-u", "-L"], "", 40, True),
    ("rule right", ["Right", "-u", "-R"], "", 40, True),
    ("rule empty", ["", "-u"], "", 30, True),
    ("csv quoted", ["quoted.csv"], "", 60, True),
    ("csv pipe", ["--csv", "-"], "a|b|c\n1|2|3\n4|5|6\n", 60, True),
    ("csv tail beyond", ["airtravel.csv", "-t", "50"], "", 60, True),
    ("error csv delimiter", ["--csv", "-"], "justoneword\n", 60, True),
    ("syntax tail beyond", ["sample.py", "-t", "100", "-n"], "", 60, True),
    ("print wide chars", ["日本語のテキスト and more text here", "-p", "-w", "12"], "", 40, True),
    ("print max width panel", [LONG, "-p", "-W", "30", "-a", "heavy", "--title", "Dune"], "", 60, True),
    ("print full panel width", [LONG, "-p", "-F", "-a", "rounded", "-w", "30", "-c"], "", 60, True),
    ("markdown export html", ["sample.md", "-o", "out.html"], "", 50, True),
    ("error json", ["-J", "-"], '{"a": 1,\n "b": }', 60, True),
    ("error json plain", ["-J", "-"], "", 60, False),
    # misc
    ("help", ["--help"], "", 100, True),
    ("help narrow", ["--help"], "", 70, False),
    ("version", ["--version"], "", 60, True),
    ("version short", ["-v"], "", 60, True),
    ("usage", [], "", 60, True),
    ("print empty", ["-p"], "", 60, True),
    ("export html", ["Hello, [b red]World[/]!", "-p", "-o", "out.html"], "", 40, True),
    ("export svg", ["sample.rs", "--export-svg", "out.svg", "-n"], "", 50, True),
    # errors
    ("error unknown option", ["--foo"], "", 60, True),
    ("error close match", ["--pri", "x"], "", 60, True),
    ("error close match one", ["--marckdown", "x"], "", 60, True),
    ("error extra argument", ["a", "b"], "", 60, True),
    ("error missing value", ["x", "-w"], "", 60, True),
    ("error bad int", ["-w", "abc", "x"], "", 60, True),
    ("error bad choice", ["--panel", "foo", "x"], "", 60, True),
    ("error range", ["-h", "0", "sample.py"], "", 60, True),
    ("error padding", ["x", "-p", "-d", "1,2,3"], "", 60, True),
    ("error padding int", ["x", "-p", "-d", "a"], "", 60, True),
    ("error head and tail", ["sample.py", "-h", "1", "-t", "1"], "", 60, True),
    ("error missing path", ["--json"], "", 60, True),
    ("error missing file", ["missing.py"], "", 60, True),
    ("error rule style", ["x", "-u", "--rule-style", "bold nope"], "", 60, True),
    ("error panel style", ["x", "-p", "-a", "square", "-S", "on"], "", 60, True),
    ("error style", ["x", "-p", "-s", "#12"], "", 60, True),
    ("error markup", ["[/b]", "-p"], "", 60, True),
    # option syntax
    ("cluster flags", ["sample.py", "-ng"], "", 60, True),
    ("attached values", ["sample.py", "-w30", "--theme=monokai"], "", 60, True),
    ("double dash", ["-p", "--", "-x-"], "", 60, True),
]


class TTYStringIO(io.StringIO):
    def __init__(self, tty: bool) -> None:
        super().__init__()
        self._tty = tty

    def isatty(self) -> bool:
        return self._tty


def run_case(args: list[str], stdin: str, width: int, tty: bool):
    environ = {"COLUMNS": str(width), "COLORTERM": "truecolor"}
    console_class = functools.partial(
        rich.console.Console, _environ=environ, legacy_windows=False
    )
    out = TTYStringIO(tty)
    err = TTYStringIO(tty)
    old = sys.stdin, sys.stdout, sys.stderr
    sys.stdin, sys.stdout, sys.stderr = io.StringIO(stdin), out, err
    cli.Console = console_class
    cli.error_console = console_class(stderr=True)
    code = 0
    try:
        cli.main.main(args, prog_name="rich", standalone_mode=True)
    except SystemExit as exit:
        code = exit.code if isinstance(exit.code, int) else 1
    finally:
        sys.stdin, sys.stdout, sys.stderr = old
    return out.getvalue(), err.getvalue(), code % 256


def main() -> None:
    fixtures = {
        p.name: p.read_bytes().decode("utf-8")
        for p in sorted(FIXTURES.iterdir())
        if p.is_file()
    }
    lines = [
        "// Generated by scripts/cli_oracle.py. DO NOT EDIT.",
        "",
        "///|",
        "/// The files of cli/testdata.",
        "let fixtures : Array[(String, String)] = [",
    ]
    for name, text in fixtures.items():
        lines.append(f"  ({mbt_str(name)}, {mbt_str(text)}),")
    lines += [
        "]",
        "",
        "///|",
        "/// (name, args, stdin, width, tty, stdout, stderr, exit code, exported files)",
        "let oracle_cases : Array[",
        "  (String, Array[String], String, Int, Bool, String, String, Int, Array[(String, String)]),",
        "] = [",
    ]
    cwd = os.getcwd()
    for name, args, stdin, width, tty in CASES:
        with tempfile.TemporaryDirectory() as tmp:
            for fname, text in fixtures.items():
                Path(tmp, fname).write_bytes(text.encode("utf-8"))
            os.chdir(tmp)
            try:
                out, err, code = run_case(args, stdin, width, tty)
            finally:
                os.chdir(cwd)
            exports = []
            for fname in sorted(os.listdir(tmp)):
                if fname not in fixtures:
                    exports.append((fname, Path(tmp, fname).read_text("utf-8")))
        args_s = ", ".join(mbt_str(a) for a in args)
        exports_s = ", ".join(f"({mbt_str(f)}, {mbt_str(t)})" for f, t in exports)
        lines.append(
            f"  ({mbt_str(name)}, [{args_s}], {mbt_str(stdin)}, {width}, "
            f"{'true' if tty else 'false'}, {mbt_str(out)}, {mbt_str(err)}, "
            f"{code}, [{exports_s}]),"
        )
    lines.append("]")
    OUT.write_text("\n".join(lines) + "\n", "utf-8")
    print(f"wrote {len(CASES)} cases to {OUT}")


if __name__ == "__main__":
    main()
