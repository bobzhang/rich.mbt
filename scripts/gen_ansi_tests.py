"""Generate differential AnsiDecoder tests from the Python oracle.

    /path/to/.venv/bin/python scripts/gen_ansi_tests.py

Writes `ansi_oracle_test.mbt`. Span offsets are UTF-16 offsets.
"""
import os

from rich.ansi import AnsiDecoder

from gen_markup_tests import HEADER, mbt_str, u16

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

CASES = [
    "plain",
    "\x1b[1mbold\x1b[22m normal",
    "\x1b[2;3;4mdim italic underline\x1b[0m",
    "\x1b[38;5;196mred256\x1b[39m default",
    "\x1b[48;5;21mbg\x1b[49m",
    "\x1b[38;2;10;20;30mrgb\x1b[48;2;1;2;3mboth\x1b[m",
    "\x1b[90mbright\x1b[107mon bright white\x1b[0m",
    "\x1b[31;1mred bold\x1b[0;32mgreen",
    "\x1b[1;;3mreset in middle",
    "\x1b[38;5mtruncated",
    "\x1b[38;2;1;2mtruncated rgb",
    "\x1b[999mbig code",
    "\x1b[5;6;7;8;9;21mattrs\x1b[25;26;27;28;29;24;23m off",
    "\x1b[51;52;53mframe\x1b[54;55m",
    "\x1b]8;id=1;https://example.org\x1b\\link\x1b]8;;\x1b\\ nolink",
    "\x1b]8;;http://a.b\x1b\\x\x1b]8;;\x1b\\",
    "\x1b]0;title\x1b\\after osc",
    "abc\rdef",
    "line1\nline2\r\nline3",
    "\x1b[1mmulti\nline\x1b[0m\nend",
    "\x1b[Kerase\x1b[2Jclear\x1b[?25lcursor",
    "\x1b7save\x1b8restore",
    "\x1b[31m😀 emoji\x1b[0m 你好",
    "\x1b[38;5;256mclamped",
    "\x1b[1;x;3mjunk codes",
    "\x1b[30;40mblack\x1b[37;47mwhite",
    "\x1b[4:3mcolon",
    "text\x1b",
    "\x1b[",
    "\x1b[1m\x1b[0m",
]


def text_repr(t):
    spans = ", ".join(
        f"Span({u16(t.plain, s.start)}, {u16(t.plain, s.end)}, {str(s.style)!r})"
        for s in t.spans
    )
    return f"{t.plain!r} [{spans}]"


lines = [HEADER.replace("gen_markup_tests", "gen_ansi_tests"), "", "///|", 'test "ansi decoder oracle cases" {']
lines.append("  let cases : Array[(String, Array[String])] = [")
for c in CASES:
    decoder = AnsiDecoder()
    out = [text_repr(t) for t in decoder.decode(c)]
    lines.append(f"    ({mbt_str(c)}, [{', '.join(mbt_str(o) for o in out)}]),")
lines += [
    "  ]",
    "  for case in cases {",
    "    let decoder = @rich.AnsiDecoder::new()",
    "    assert_eq(decoder.decode(case.0).map(ansi_text_repr), case.1)",
    "  }",
    "}",
]
with open(os.path.join(ROOT, "ansi_oracle_test.mbt"), "w") as f:
    f.write("\n".join(lines) + "\n")
