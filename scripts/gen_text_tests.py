"""Generate differential Text tests (wrap / justify / render ...) from the
Python oracle.

    /path/to/.venv/bin/python scripts/gen_text_tests.py

Writes `text_oracle_test.mbt`. Span offsets are UTF-16 offsets.
"""
import io
import os

from rich.console import Console
from rich.text import Text

from gen_markup_tests import HEADER, mbt_str, u16

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HEADER = HEADER.replace("gen_markup_tests", "gen_text_tests")


def text_repr(t: Text) -> str:
    spans = ", ".join(
        f"Span({u16(t.plain, s.start)}, {u16(t.plain, s.end)}, {s.style!r})"
        for s in t.spans
    )
    return f"<text {t.plain!r} [{spans}] {t.style!r}>"


def console(width=80, **kwargs):
    return Console(
        file=io.StringIO(),
        width=width,
        color_system="truecolor",
        force_terminal=True,
        legacy_windows=False,
        _environ={},
        **kwargs,
    )


MARKUPS = [
    "Hello, World!",
    "The quick brown fox jumps over the lazy dog.",
    "[bold]The quick[/bold] brown [red on white]fox jumps[/] over the [i]lazy dog[/i].",
    "  leading and trailing spaces  ",
    "multiple    spaces   between  words",
    "a verylongwordthatdoesnotfit at all",
    "Supercalifragilisticexpialidocious",
    "line one\nline two is longer\n\nline four",
    "trailing newline\n",
    "tabs\there\tand\tthere",
    "日本語のテキストを折り返します。漢字とかなが混在しています。",
    "mixed English と 日本語 text with スペース",
    "emoji 😀 in 👍 the 🎉 text 😀😀😀😀",
    "[u]under[/u]lined [b]bold [i]both[/i][/b] plain",
    "x",
    "",
    " ",
    "a b c d e f g h i j k l m n o p",
    "[on blue]background spans across words[/on blue]",
    "comma,separated,values,without,spaces,at,all",
    "hyphen-ated-words-are-not-split-on-hyphens",
]

WIDTHS = [1, 3, 5, 8, 12, 20, 40]
JUSTIFIES = [None, "left", "center", "right", "full"]
OVERFLOWS = [None, "crop", "ellipsis", "ignore"]


def wrap_cases():
    rows = []
    for m in MARKUPS:
        for width in WIDTHS:
            for justify in JUSTIFIES:
                for overflow in OVERFLOWS:
                    if overflow is not None and justify not in (None, "left"):
                        continue
                    text = Text.from_markup(m)
                    lines = text.wrap(console(), width, justify=justify, overflow=overflow)
                    rows.append((m, width, justify, overflow, [text_repr(l) for l in lines]))
    return rows


def opt(v):
    return "None" if v is None else f"Some({v.capitalize()})"


def print_cases():
    rows = []
    for m in MARKUPS:
        for width in [7, 16, 30]:
            for justify in JUSTIFIES:
                c = console(width)
                c.print(Text.from_markup(m, style="dim"), justify=justify)
                rows.append((m, width, justify, c.file.getvalue()))
    return rows


def misc_cases():
    """Single-method cases: (markup, method description, result)."""
    rows = []
    for m in MARKUPS:
        t = Text.from_markup(m)
        rows.append((m, "markup", t.markup))
        rows.append((m, "split_space", " | ".join(text_repr(l) for l in t.split(" "))))
        rows.append((m, "split_nl_sep", " | ".join(text_repr(l) for l in t.split("\n", include_separator=True))))
        rows.append((m, "split_nl_blank", " | ".join(text_repr(l) for l in t.split("\n", allow_blank=True))))
        n = len(t)
        offsets = [o for o in (1, 4, 7, 11) if o < n]
        rows.append((m, "divide", " | ".join(text_repr(l) for l in t.divide(offsets))))
        e = t.copy()
        e.expand_tabs(4)
        rows.append((m, "expand_tabs4", text_repr(e)))
        for width in (4, 10):
            for overflow in ("crop", "ellipsis", "fold"):
                tr = t.copy()
                tr.truncate(width, overflow=overflow, pad=True)
                rows.append((m, f"truncate{width}_{overflow}", text_repr(tr)))
        for align in ("left", "center", "right"):
            a = t.copy()
            a.align(align, 25)
            rows.append((m, f"align_{align}", text_repr(a)))
        meas = t.__rich_measure__(console(), console().options)
        rows.append((m, "measure", f"{meas.minimum},{meas.maximum}"))
        hw = t.copy()
        hw.highlight_words(["e", "o"], "red")
        rows.append((m, "highlight_words", text_repr(hw)))
        r = t.copy()
        r.rstrip()
        rows.append((m, "rstrip", text_repr(r)))
        fit = t.fit(6)
        rows.append((m, "fit6", " | ".join(text_repr(l) for l in fit)))
        rows.append((m, "cell_len", str(t.cell_len)))
    return rows


def main():
    lines = [HEADER, ""]
    lines += ["///|", 'test "wrap oracle cases" {']
    lines.append("  let cases : Array[(String, Int, JustifyMethod?, OverflowMethod?, Array[String])] = [")
    for m, width, justify, overflow, out in wrap_cases():
        outs = ", ".join(mbt_str(o) for o in out)
        lines.append(f"    ({mbt_str(m)}, {width}, {opt(justify)}, {opt(overflow)}, [{outs}]),")
    lines += [
        "  ]",
        "  for case in cases {",
        "    let (markup, width, justify, overflow, expected) = case",
        "    let text = @rich.Text::from_markup(markup)",
        "    let lines = text.wrap(oracle_console(), width, justify?, overflow?)",
        "    let actual = lines.lines.map(l => l.repr())",
        "    if actual != expected {",
        "      fail(",
        "        \"\\{markup} width=\\{width} \\{to_repr(justify)} \\{to_repr(overflow)}:\\n\\{to_repr(actual)}\\n\\{to_repr(expected)}\",",
        "      )",
        "    }",
        "  }",
        "}",
        "",
    ]
    lines += ["///|", 'test "print oracle cases" {']
    lines.append("  let cases : Array[(String, Int, JustifyMethod?, String)] = [")
    for m, width, justify, out in print_cases():
        lines.append(f"    ({mbt_str(m)}, {width}, {opt(justify)}, {mbt_str(out)}),")
    lines += [
        "  ]",
        "  for case in cases {",
        "    let (markup, width, justify, expected) = case",
        "    let file = @rich.StringIO::new()",
        "    let console = oracle_console(width~, file~)",
        "    console.print(@rich.Text::from_markup(markup, style=\"dim\"), justify?)",
        "    assert_eq(file.getvalue(), expected, msg=markup)",
        "  }",
        "}",
        "",
    ]
    lines += ["///|", 'test "text method oracle cases" {']
    lines.append("  let cases : Array[(String, String, String)] = [")
    for m, method, out in misc_cases():
        lines.append(f"    ({mbt_str(m)}, {mbt_str(method)}, {mbt_str(out)}),")
    lines += [
        "  ]",
        "  for case in cases {",
        "    let (markup, method, expected) = case",
        "    assert_eq(text_method(markup, method), expected, msg=\"\\{markup} \\{method}\")",
        "  }",
        "}",
    ]
    with open(os.path.join(ROOT, "text_oracle_test.mbt"), "w") as f:
        f.write("\n".join(lines) + "\n")


main()
