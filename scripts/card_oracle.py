"""Regenerate demo/card_test.mbt's expected output with the current Pygments.

Upstream's tests/_card_render.py was produced with an older Pygments and no
longer matches upstream Rich itself.
"""
import io
import re
import sys
from pathlib import Path

from rich.__main__ import make_test_card
from rich.console import Console

re_link_ids = re.compile(r"id=[\d\.\-]*?;.*?\x1b")
console = Console(width=100, file=io.StringIO(), color_system="truecolor", legacy_windows=False)
console.print(make_test_card())
expected = re_link_ids.sub("id=0;foo\x1b", console.file.getvalue())


def lit(s):
    out = []
    for c in s:
        o = ord(c)
        if c == '"':
            out.append('\\"')
        elif c == "\\":
            out.append("\\\\")
        elif c == "\n":
            out.append("\\n")
        elif o < 0x20 or o == 0x7F:
            out.append("\\u{%x}" % o)
        else:
            out.append(c)
    return '"' + "".join(out) + '"'


path = Path(__file__).parent.parent / "demo" / "card_test.mbt"
src = path.read_text()
start = src.index("let expected : String = ")
end = src.index("\n", start)
path.write_text(src[:start] + "let expected : String = " + lit(expected) + src[end:])
