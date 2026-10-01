"""Generate differential Style tests from the Python oracle.

    /path/to/.venv/bin/python scripts/gen_style_tests.py

Writes `style_oracle_test.mbt`.
"""
import os
import re

from rich.color import ColorSystem
from rich.errors import StyleSyntaxError
from rich.style import Style

from gen_markup_tests import HEADER, mbt_str

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HEADER = HEADER.replace("gen_markup_tests", "gen_style_tests")

DEFINITIONS = [
    "", "none", " none ", "bold", "b", "BOLD", "Bold Italic", "dim i u", "not bold", "not b",
    "bold not bold", "not bold bold", "blink blink2 reverse conceal strike", "r c s uu o",
    "underline2 frame encircle overline", "red", "RED", "on red", "red on blue", "on red blue",
    "#ff0000", "#FF00ff on #000000", "color(1)", "color(16)", "color(255)", "rgb(10,20,30)",
    "rgb(255, 0, 128) on rgb(0,0,0)", "default", "on default", "default on default",
    "bright_red", "grey50", "gray50", "dark_orange3", "link https://example.org",
    "bold link https://example.org red", "italic   red\ton\nwhite", "not italic not bold",
    "bold on color(17)", "on", "on nothing", "not", "not foo", "link", "foo", "color(256)",
    "rgb(1,2)", "#12345", "red green", "on red on blue", "i not i", "reverse red on white",
    "dim red", "dim on blue", "reverse dim red on yellow", "bold italic underline strike overline red",
]

SYSTEMS = [ColorSystem.TRUECOLOR, ColorSystem.EIGHT_BIT, ColorSystem.STANDARD, ColorSystem.WINDOWS]


def describe(d):
    try:
        s = Style.parse(d)
    except StyleSyntaxError as e:
        return ["error: " + str(e)]
    out = [str(s), repr(s), str(bool(s))]
    for system in SYSTEMS:
        # upstream caches the codes of the first color system (see
        # DEVIATIONS.md): reset the cache for each system
        s._ansi = None
        out.append(re.sub(r"id=[\d.\-]*?;", "id=0;", s.render("x", color_system=system)))
    s._ansi = None
    out.append(s.get_html_style())
    return out


def main():
    lines = [HEADER, "", "///|", 'test "style parse oracle cases" {']
    lines.append("  let cases : Array[(String, Array[String])] = [")
    for d in DEFINITIONS:
        out = ", ".join(mbt_str(o) for o in describe(d))
        lines.append(f"    ({mbt_str(d)}, [{out}]),")
    lines += [
        "  ]",
        "  for case in cases {",
        "    let actual = describe_style(case.0)",
        "    if actual != case.1 {",
        "      fail(\"\\{case.0}:\\n\\{actual.join(\"\\n\")}\\n\\{case.1.join(\"\\n\")}\")",
        "    }",
        "  }",
        "}",
        "",
    ]
    lines += ["///|", 'test "style add oracle cases" {']
    lines.append("  let cases : Array[(String, String, String)] = [")
    valid = [d for d in DEFINITIONS if not describe(d)[0].startswith("error")]
    for a in valid[::3]:
        for b in valid[1::4]:
            lines.append(f"    ({mbt_str(a)}, {mbt_str(b)}, {mbt_str(str(Style.parse(a) + Style.parse(b)))}),")
    lines += [
        "  ]",
        "  for case in cases {",
        "    let (a, b, expected) = case",
        "    assert_eq(",
        "      (@rich.Style::parse(a) + @rich.Style::parse(b)).to_string(),",
        "      expected,",
        "      msg=\"\\{a} + \\{b}\",",
        "    )",
        "  }",
        "}",
    ]
    with open(os.path.join(ROOT, "style_oracle_test.mbt"), "w") as f:
        f.write("\n".join(lines) + "\n")


main()
