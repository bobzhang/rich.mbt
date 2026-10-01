"""Generate differential Segment tests from the Python oracle.

    /path/to/.venv/bin/python scripts/gen_segment_tests.py

Writes `segment_oracle_test.mbt`.
"""
import os
import random

from rich.segment import Segment
from rich.style import Style

from gen_markup_tests import HEADER, mbt_str

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HEADER = HEADER.replace("gen_markup_tests", "gen_segment_tests")

PIECES = ["a", "bc", "def", " ", "あ", "い", "😀", "👩‍🔧", "x́", "\t", "１", "é"]
STYLES = ["bold", "red", "italic on blue", None]


def random_segments(rng):
    segments = []
    for _ in range(rng.randint(1, 4)):
        text = "".join(rng.choice(PIECES) for _ in range(rng.randint(1, 5)))
        segments.append((text, rng.choice(STYLES)))
    return segments


def seg_repr(seg):
    return f"{seg.text!r}/{seg.style}" if seg.style is not None else repr(seg.text)


def main():
    rng = random.Random(1234)
    lines = [HEADER, "", "///|", 'test "segment divide / split_cells oracle cases" {']
    lines.append("  let cases : Array[(Array[(String, String?)], Array[Int], Int, Int, String, String, String)] = [")
    for _ in range(120):
        segs = random_segments(rng)
        segments = [Segment(t, Style.parse(s) if s else None) for t, s in segs]
        total = Segment.get_line_length(segments)
        cuts = sorted(set(rng.randint(0, total + 2) for _ in range(rng.randint(1, 3))))
        divided = list(Segment.divide(segments, cuts))
        div = " | ".join(",".join(seg_repr(s) for s in part) for part in divided)
        cut = rng.randint(0, total + 1)
        first = segments[0]
        left, right = first.split_cells(min(cut, first.cell_length))
        split = seg_repr(left) + " + " + seg_repr(right)
        width = rng.randint(0, total + 3)
        adjusted = ",".join(seg_repr(s) for s in Segment.adjust_line_length(segments, width, style=Style.parse("dim")))
        segs_mbt = ", ".join(
            f"({mbt_str(t)}, {'None' if s is None else 'Some(' + mbt_str(s) + ')'})" for t, s in segs
        )
        cuts_mbt = ", ".join(str(c) for c in cuts)
        lines.append(
            f"    ([{segs_mbt}], [{cuts_mbt}], {min(cut, first.cell_length)}, {width}, {mbt_str(div)}, {mbt_str(split)}, {mbt_str(adjusted)}),"
        )
    lines += [
        "  ]",
        "  for case in cases {",
        "    let (segs, cuts, cut, width, divided, split, adjusted) = case",
        "    assert_eq(segment_ops(segs, cuts, cut, width), (divided, split, adjusted))",
        "  }",
        "}",
    ]
    with open(os.path.join(ROOT, "segment_oracle_test.mbt"), "w") as f:
        f.write("\n".join(lines) + "\n")


main()
