"""Generate highlighter tests.

    /path/to/.venv/bin/python scripts/gen_highlighter_tests.py /path/to/.repos/rich

* `highlighter_upstream_test.mbt`: the data tables of upstream
  tests/test_highlighter.py (`highlight_tests`, `iso8601_highlight_tests`).
* `highlighter_oracle_test.mbt`: ReprHighlighter / JSONHighlighter /
  ISO8601Highlighter spans computed by the Python oracle for more inputs.

Span offsets are converted to UTF-16 offsets.
"""
import datetime
import decimal
import fractions
import json
import os
import sys
import uuid
from collections import OrderedDict, defaultdict, deque, namedtuple

from rich.highlighter import ISO8601Highlighter, JSONHighlighter, ReprHighlighter
from rich.text import Text

from gen_markup_tests import HEADER, mbt_str, u16

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, sys.argv[1])
from tests.test_highlighter import highlight_tests, iso8601_highlight_tests  # noqa: E402

HEADER = HEADER.replace("gen_markup_tests", "gen_highlighter_tests")


def spans_mbt(plain, spans):
    items = [
        f"({u16(plain, s.start)}, {u16(plain, s.end)}, {mbt_str(s.style)})" for s in spans
    ]
    return "[" + ", ".join(items) + "]"


def table(name, kind, rows):
    lines = ["///|", f'test "{name}" {{']
    lines.append("  let cases : Array[(String, Array[(Int, Int, String)])] = [")
    for text, spans in rows:
        lines.append(f"    ({mbt_str(text)}, {spans_mbt(text, spans)}),")
    lines += [
        "  ]",
        "  for case in cases {",
        f"    assert_eq(highlight_spans({kind}, case.0), case.1)",
        "  }",
        "}",
        "",
    ]
    return lines


def computed(highlighter, inputs):
    rows = []
    for s in inputs:
        t = Text(s)
        highlighter.highlight(t)
        rows.append((s, t.spans))
    return rows


Point = namedtuple("Point", "x y")


class Foo:
    def __repr__(self):
        return "<Foo bar=1 baz='qux'>"


REPR_INPUTS = [
    repr(x)
    for x in [
        1, -1, 1.5, -2.5e-10, 1e100, float("inf"), 3 + 4j, -1j, 0xFF, "hello", "it's", 'say "hi"',
        b"bytes", b"\x00\xff", [1, 2, 3], (1,), (), {"a": 1, "b": [True, False, None]},
        {1, 2}, frozenset(), set(), Point(1, 2), OrderedDict(a=1), defaultdict(list),
        deque([1, 2]), datetime.date(2020, 1, 2), datetime.datetime(2020, 1, 2, 3, 4, 5),
        datetime.timedelta(seconds=5), decimal.Decimal("1.10"), fractions.Fraction(1, 3),
        uuid.UUID("12345678-1234-5678-1234-567812345678"), Foo(), ..., None, True, object,
        int, len, range(10), slice(1, 2), "a\nb", "tab\there", "unicode ünïcödé 😀",
    ]
] + [
    "<function foo at 0x7f8b8c0b8d30>",
    "<class 'int'>",
    "/usr/local/lib/python3.12/site-packages/rich/text.py",
    "C:\\Users\\foo\\file.txt",
    "~/projects/rich.mbt/README.md",
    "file:///home/user/doc.txt and ws://localhost:8080/socket",
    "wss://example.com/path?q=1&r=2#frag",
    "Visit https://github.com/Textualize/rich/issues/2273.",
    "IPv6 ::1 and fe80::1ff:fe23:4567:890a and 2001:db8::8a2e:370:7334",
    "MAC 00:1B:44:11:3A:B7 and 00-1B-44-11-3A-B7",
    "192.168.0.1:8080",
    "999.999.999.999",
    "1.2.3",
    "version 3.12.1",
    "x=1, y=2.5, z='three'",
    "foo(bar=baz(1), qux=[1, 2])",
    "a.b.c(d)",
    "f()",
    "...",
    "1..2",
    "-0x1F 0b101 0o17",
    "1_000_000",
    "1e-5 1E5 1e+5",
    "abc123 123abc",
    "True_ False1 Nonesuch",
    "'unterminated",
    "\"double\" 'single' '''triple'''",
    "b'bytes' b\"bytes\"",
    "r'raw' f'fmt'",
    "escaped \\'quote\\'",
    "<html><body class=\"x\">text</body></html>",
    "<a href=\"https://example.org\">link</a>",
    "<>",
    "< spaced >",
    "Error: [Errno 2] No such file or directory: '/tmp/x'",
    "Traceback (most recent call last):",
    "{'key': \"value\", 'n': -3.14}",
    "[[1, [2, [3]]]]",
    "😀 = 1",
    "数字 = 42",
    "name='名前'",
    "x = 0x",
    "uuid 12345678-1234-5678-1234-567812345678!",
    "2023-01-01T00:00:00",
    "-",
    "+1",
    "1 + 2j",
    "(1-2j)",
    "",
    " ",
]

JSON_INPUTS = [
    json.dumps({"name": "apple", "count": 1}, indent=2),
    json.dumps([1, 2.5, -3e10, True, False, None, "s"]),
    json.dumps({"nested": {"a": [1, {"b": "c"}]}}, indent=4),
    json.dumps({"key with spaces": "value: colon", "k2": "\"quoted\""}),
    '{"a" : 1, "b"\n:\t2}',
    '"just a string"',
    "123",
    "null",
    '{"emoji": "😀", "unicode": "ünï"}',
    '["a", "b": "c"]',
    '{"escaped \\" quote": 1}',
]

ISO_INPUTS = [
    "2008", "2008-08", "200808", "2008-08-30", "20080830", "2008-243", "2008243",
    "2008-W35", "2008W35", "2008-W35-6", "2008W356", "17:18", "1718", "171819",
    "Z", "+01:00", "-0100", "+01", "171819Z", "2008-08-30 17:18:19", "20080830 171819",
    "2008-08-30T17:18:19", "2008-08-30T17:18:19.123", "2008-08-30T17:18:19+01:00",
    "2008-08-30T17:18:19Z", "-12008-08-30", "17:18:19.5", "17:18:19.5Z", "25:00",
    "2008-13-01", "not a date", "2008-08-30T25:18:19", "12008-08-30T17:18:19-05:30",
]


def main():
    lines = [HEADER, "", "// Data tables of upstream tests/test_highlighter.py.", ""]
    lines += table("highlight_regex", "Repr", highlight_tests)
    lines += table("highlight_iso8601_regex", "ISO8601", iso8601_highlight_tests)
    with open(os.path.join(ROOT, "highlighter_upstream_test.mbt"), "w") as f:
        f.write("\n".join(lines))
    lines = [HEADER, ""]
    lines += table("repr highlighter oracle", "Repr", computed(ReprHighlighter(), REPR_INPUTS))
    lines += table("json highlighter oracle", "JSON", computed(JSONHighlighter(), JSON_INPUTS))
    lines += table("iso8601 highlighter oracle", "ISO8601", computed(ISO8601Highlighter(), ISO_INPUTS))
    with open(os.path.join(ROOT, "highlighter_oracle_test.mbt"), "w") as f:
        f.write("\n".join(lines))


main()
