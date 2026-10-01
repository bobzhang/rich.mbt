"""Differential tests for the console/layout layer.

Each case is described as data; this script renders it with upstream Rich
and emits the equivalent MoonBit code plus the expected output into
`layout_oracle_test.mbt`.

    /Users/dii/git/rich.mbt/.venv/bin/python scripts/layout_oracle.py
"""
import io
import itertools
import re
import json as pyjson
from pathlib import Path

from rich import box as rbox
from rich.align import Align
from rich.console import Console
from rich.json import JSON
from rich.padding import Padding
from rich.rule import Rule
from rich.table import Table
from rich.text import Text

OUT = Path(__file__).resolve().parent.parent / "layout_oracle_test.mbt"


def mbt_str(s: str) -> str:
    out = ['"']
    for ch in s:
        o = ord(ch)
        if ch == '"':
            out.append('\\"')
        elif ch == "\\":
            out.append("\\\\")
        elif ch == "\n":
            out.append("\\n")
        elif ch == "\t":
            out.append("\\t")
        elif ch == "\r":
            out.append("\\r")
        elif o < 0x20 or o == 0x7F:
            out.append("\\u{%x}" % o)
        else:
            out.append(ch)
    out.append('"')
    return "".join(out)


def make_console(width, color_system="truecolor", height=None, **kwargs):
    file = io.StringIO()
    console = Console(
        file=file,
        width=width,
        height=height,
        color_system=color_system,
        force_terminal=True,
        legacy_windows=False,
        _environ={},
        **kwargs,
    )
    return console, file


def mbt_console(width, color_system="truecolor", height=None, **kwargs):
    cs = "None" if color_system is None else f"Some({mbt_str(color_system)})"
    args = [
        "file~",
        f"width={width}",
        f"color_system={cs}",
        "force_terminal=true",
        "legacy_windows=false",
        "environ={}",
    ]
    if height is not None:
        args.append(f"height={height}")
    for k, v in kwargs.items():
        args.append(f"{k}={mbt_value(v)}")
    return (
        "  let file = @rich.StringIO::new()\n"
        f"  let console = @rich.Console::new({', '.join(args)})\n"
    )


ENUMS = {"left": "Left", "center": "Center", "right": "Right", "full": "Full",
         "default": "Default", "top": "Top", "middle": "Middle",
         "bottom": "Bottom", "fold": "Fold", "crop": "Crop",
         "ellipsis": "Ellipsis", "ignore": "Ignore"}


def mbt_value(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, str):
        return mbt_str(v)
    raise TypeError(v)


def mbt_enum(v):
    return ENUMS[v]


# ---------------------------------------------------------------- cells


def py_cell(cell):
    if cell is None:
        return None
    if isinstance(cell, str):
        return cell
    kind = cell["kind"]
    if kind == "text":
        return Text(cell["text"], style=cell.get("style", ""),
                    justify=cell.get("justify"), overflow=cell.get("overflow"))
    if kind == "rule":
        return Rule(cell.get("title", ""), characters=cell.get("characters", "─"))
    if kind == "align":
        return Align(cell["text"], cell["align"], vertical=cell.get("vertical"))
    raise ValueError(kind)


def mbt_cell(cell):
    if cell is None:
        return '""'
    if isinstance(cell, str):
        return mbt_str(cell)
    kind = cell["kind"]
    if kind == "text":
        args = [f"text={mbt_str(cell['text'])}"]
        if cell.get("style"):
            args.append(f"style={mbt_str(cell['style'])}")
        if cell.get("justify"):
            args.append(f"justify={mbt_enum(cell['justify'])}")
        if cell.get("overflow"):
            args.append(f"overflow={mbt_enum(cell['overflow'])}")
        return f"@rich.Text::new({', '.join(args)})"
    if kind == "rule":
        args = [f"title={mbt_str(cell.get('title', ''))}"]
        if "characters" in cell:
            args.append(f"characters={mbt_str(cell['characters'])}")
        return f"@rich.Rule::new({', '.join(args)})"
    if kind == "align":
        args = [mbt_str(cell["text"]), mbt_enum(cell["align"])]
        if cell.get("vertical"):
            args.append(f"vertical={mbt_enum(cell['vertical'])}")
        return f"@rich.Align::new({', '.join(args)})"
    raise ValueError(kind)


# ---------------------------------------------------------------- tables

BOXES = {
    "ASCII": "box_ascii", "ASCII2": "box_ascii2",
    "ASCII_DOUBLE_HEAD": "box_ascii_double_head", "SQUARE": "box_square",
    "SQUARE_DOUBLE_HEAD": "box_square_double_head", "MINIMAL": "box_minimal",
    "MINIMAL_HEAVY_HEAD": "box_minimal_heavy_head",
    "MINIMAL_DOUBLE_HEAD": "box_minimal_double_head", "SIMPLE": "box_simple",
    "SIMPLE_HEAD": "box_simple_head", "SIMPLE_HEAVY": "box_simple_heavy",
    "HORIZONTALS": "box_horizontals", "ROUNDED": "box_rounded",
    "HEAVY": "box_heavy", "HEAVY_EDGE": "box_heavy_edge",
    "HEAVY_HEAD": "box_heavy_head", "DOUBLE": "box_double",
    "DOUBLE_EDGE": "box_double_edge", "MARKDOWN": "box_markdown",
}

TABLE_STYLE_KEYS = ["style", "header_style", "footer_style", "border_style",
                    "title_style", "caption_style"]
TABLE_BOOL_KEYS = ["expand", "show_header", "show_footer", "show_edge",
                   "show_lines", "collapse_padding", "pad_edge", "highlight"]
TABLE_INT_KEYS = ["width", "min_width", "leading"]
COLUMN_INT_KEYS = ["width", "min_width", "max_width", "ratio"]
COLUMN_STYLE_KEYS = ["style", "header_style", "footer_style"]


def py_table(spec):
    kwargs = {}
    if "box" in spec:
        kwargs["box"] = getattr(rbox, spec["box"]) if spec["box"] else None
    for k in TABLE_STYLE_KEYS + TABLE_BOOL_KEYS + TABLE_INT_KEYS:
        if k in spec:
            kwargs[k] = spec[k]
    for k in ["title", "caption"]:
        if k in spec:
            kwargs[k] = py_cell(spec[k])
    for k in ["title_justify", "caption_justify"]:
        if k in spec:
            kwargs[k] = spec[k]
    if "padding" in spec:
        kwargs["padding"] = tuple(spec["padding"])
    if "row_styles" in spec:
        kwargs["row_styles"] = spec["row_styles"]
    if "grid" in spec:
        table = Table.grid(padding=tuple(spec.get("padding", (0,))),
                           expand=spec.get("expand", False))
    else:
        table = Table(**kwargs)
    for col in spec.get("columns", []):
        ckw = dict(col)
        header = ckw.pop("header", "")
        footer = ckw.pop("footer", "")
        table.add_column(py_cell(header), py_cell(footer), **ckw)
    for row in spec.get("rows", []):
        cells, rkw = row if isinstance(row, tuple) else (row, {})
        table.add_row(*[py_cell(c) for c in cells], **rkw)
    return table


def mbt_table(spec):
    lines = []
    if "grid" in spec:
        pad = ", ".join(str(p) for p in spec.get("padding", (0,)))
        lines.append(
            f"  let table = @rich.Table::grid(padding=[{pad}], "
            f"expand={mbt_value(spec.get('expand', False))})"
        )
    else:
        args = []
        if "box" in spec:
            if spec["box"]:
                args.append(f"box_=@rich.{BOXES[spec['box']]}")
            else:
                args.append("no_box=true")
        for k in TABLE_STYLE_KEYS + TABLE_BOOL_KEYS + TABLE_INT_KEYS:
            if k in spec:
                args.append(f"{k}={mbt_value(spec[k])}")
        for k in ["title", "caption"]:
            if k in spec:
                args.append(f"{k}={mbt_cell(spec[k])}")
        for k in ["title_justify", "caption_justify"]:
            if k in spec:
                args.append(f"{k}={mbt_enum(spec[k])}")
        if "padding" in spec:
            args.append(f"padding=[{', '.join(str(p) for p in spec['padding'])}]")
        if "row_styles" in spec:
            styles = ", ".join(mbt_str(s) for s in spec["row_styles"])
            args.append(f"row_styles=[{styles}]")
        lines.append(f"  let table = @rich.Table::new({', '.join(args)})")
    for col in spec.get("columns", []):
        args = []
        if "header" in col:
            args.append(f"header={mbt_cell(col['header'])}")
        if "footer" in col:
            args.append(f"footer={mbt_cell(col['footer'])}")
        for k in COLUMN_STYLE_KEYS:
            if k in col:
                args.append(f"{k}={mbt_str(col[k])}")
        for k in COLUMN_INT_KEYS:
            if k in col:
                args.append(f"{k}={col[k]}")
        for k in ["justify", "vertical", "overflow"]:
            if k in col:
                args.append(f"{k}={mbt_enum(col[k])}")
        for k in ["no_wrap", "highlight"]:
            if k in col:
                args.append(f"{k}={mbt_value(col[k])}")
        lines.append(f"  table.add_column({', '.join(args)})")
    for row in spec.get("rows", []):
        cells, rkw = row if isinstance(row, tuple) else (row, {})
        args = ["[" + ", ".join(mbt_cell(c) for c in cells) + "]"]
        if "style" in rkw:
            args.append(f"style={mbt_str(rkw['style'])}")
        if "end_section" in rkw:
            args.append(f"end_section={mbt_value(rkw['end_section'])}")
        lines.append(f"  table.add_row({', '.join(args)})")
    return "\n".join(lines) + "\n"


PRINT_ENUM_KEYS = ["justify", "overflow"]
PRINT_BOOL_KEYS = ["no_wrap", "soft_wrap", "crop", "new_line_start", "emoji",
                   "markup", "highlight"]
PRINT_INT_KEYS = ["width", "height"]


def mbt_print_args(kw):
    args = []
    for k in PRINT_ENUM_KEYS:
        if k in kw:
            args.append(f"{k}={mbt_enum(kw[k])}")
    for k in PRINT_BOOL_KEYS:
        if k in kw:
            args.append(f"{k}={mbt_value(kw[k])}")
    for k in PRINT_INT_KEYS:
        if k in kw:
            args.append(f"{k}={kw[k]}")
    for k in ["style", "end", "sep"]:
        if k in kw:
            args.append(f"{k}={mbt_str(kw[k])}")
    return args


cases = []  # (name, mbt_body, expected)


def add_table_case(name, spec, width=60, color_system="truecolor", print_kw=None):
    print_kw = print_kw or {}
    console, file = make_console(width, color_system)
    console.print(py_table(spec), **print_kw)
    body = mbt_console(width, color_system) + mbt_table(spec)
    args = ["table"] + mbt_print_args(print_kw)
    body += f"  console.print({', '.join(args)})\n"
    cases.append((name, body, file.getvalue()))


# --- table cases ----------------------------------------------------------

BASE_COLUMNS = [
    {"header": "Released", "footer": "Total", "justify": "left"},
    {"header": "Title", "footer": "", "justify": "center"},
    {"header": "Box Office", "footer": "$4,429,254,000", "justify": "right"},
]
BASE_ROWS = [
    ["Dec 20, 2019", "Star Wars: The Rise of Skywalker", "$952,110,690"],
    ["May 25, 2018", "Solo: A Star Wars Story", "$393,151,347"],
    ["Dec 15, 2017", "Star Wars Ep. V111: The Last Jedi", "$1,332,539,889"],
    ["Dec 16, 2016", "Rogue One: A Star Wars Story", "$1,332,439,889"],
]

for box_name in BOXES:
    add_table_case(
        f"table box {box_name}",
        {"box": box_name, "columns": BASE_COLUMNS, "rows": BASE_ROWS[:2],
         "show_footer": True},
        width=70,
    )
add_table_case("table no box", {"box": None, "columns": BASE_COLUMNS, "rows": BASE_ROWS})

for width in [20, 30, 45, 60, 80]:
    for expand in [False, True]:
        add_table_case(
            f"table width {width} expand {expand}",
            {"columns": BASE_COLUMNS, "rows": BASE_ROWS, "expand": expand,
             "title": "Star Wars Movies", "caption": "Rich example table"},
            width=width,
        )

for padding in [(0,), (1,), (0, 2), (1, 2, 0, 3)]:
    for pad_edge in [True, False]:
        for collapse in [False, True]:
            add_table_case(
                f"table padding {padding} pad_edge {pad_edge} collapse {collapse}",
                {"columns": BASE_COLUMNS[:2], "rows": BASE_ROWS[:2],
                 "padding": padding, "pad_edge": pad_edge,
                 "collapse_padding": collapse},
                width=70,
            )

for show_header, show_footer, show_edge, show_lines in itertools.product(
    [True, False], repeat=4
):
    add_table_case(
        f"table flags h{show_header} f{show_footer} e{show_edge} l{show_lines}",
        {"columns": BASE_COLUMNS, "rows": BASE_ROWS[:3],
         "show_header": show_header, "show_footer": show_footer,
         "show_edge": show_edge, "show_lines": show_lines},
        width=70,
    )

for leading in [1, 2]:
    add_table_case(
        f"table leading {leading}",
        {"columns": BASE_COLUMNS, "rows": BASE_ROWS[:3], "leading": leading,
         "box": "ROUNDED"},
        width=70,
    )

add_table_case(
    "table row styles",
    {"columns": BASE_COLUMNS, "rows": BASE_ROWS,
     "row_styles": ["on blue", "dim", "bold on red"], "box": "SIMPLE"},
    width=70,
)
add_table_case(
    "table row style and end_section",
    {"columns": BASE_COLUMNS,
     "rows": [(BASE_ROWS[0], {"style": "on green"}),
              (BASE_ROWS[1], {"end_section": True}),
              (BASE_ROWS[2], {"style": "italic"}), BASE_ROWS[3]]},
    width=70,
)
add_table_case(
    "table styles",
    {"columns": [dict(c, style="magenta", header_style="bold cyan")
                 for c in BASE_COLUMNS],
     "rows": BASE_ROWS[:2], "style": "on grey11", "header_style": "underline",
     "footer_style": "italic", "border_style": "red", "show_footer": True,
     "title": "Title", "caption": "Caption", "title_style": "bold yellow",
     "caption_style": "dim"},
    width=70,
)
for tj, cj in [("left", "right"), ("right", "left"), ("center", "full")]:
    add_table_case(
        f"table title {tj} caption {cj}",
        {"columns": BASE_COLUMNS[:2], "rows": BASE_ROWS[:1],
         "title": "A long title for the table", "caption": "caption text",
         "title_justify": tj, "caption_justify": cj},
        width=60,
    )
add_table_case(
    "table title Text",
    {"columns": BASE_COLUMNS[:2], "rows": BASE_ROWS[:1],
     "title": {"kind": "text", "text": "Styled title", "style": "bold red"},
     "caption": {"kind": "text", "text": "right caption", "justify": "right"}},
    width=60,
)

for ratios in [(1, 1, 1), (1, 2, 3), (2, None, 1), (None, 1, None)]:
    cols = []
    for c, r in zip(BASE_COLUMNS, ratios):
        c = dict(c)
        if r is not None:
            c["ratio"] = r
        cols.append(c)
    for expand in [True, False]:
        add_table_case(
            f"table ratios {ratios} expand {expand}",
            {"columns": cols, "rows": BASE_ROWS[:2], "expand": expand},
            width=80,
        )
add_table_case(
    "table ratio with width",
    {"columns": [dict(BASE_COLUMNS[0], ratio=1, width=20),
                 dict(BASE_COLUMNS[1], ratio=2), BASE_COLUMNS[2]],
     "rows": BASE_ROWS[:2], "expand": True},
    width=80,
)

for col_kw in [
    {"min_width": 20}, {"max_width": 8}, {"width": 5}, {"width": 30},
    {"min_width": 10, "max_width": 12}, {"no_wrap": True},
    {"no_wrap": True, "overflow": "crop"}, {"overflow": "fold"},
    {"overflow": "ellipsis", "max_width": 10},
]:
    cols = [dict(BASE_COLUMNS[0]), dict(BASE_COLUMNS[1], **col_kw),
            dict(BASE_COLUMNS[2])]
    for width in [40, 80]:
        add_table_case(
            f"table column {col_kw} width {width}",
            {"columns": cols, "rows": BASE_ROWS},
            width=width,
        )

add_table_case(
    "table width and min_width",
    {"columns": BASE_COLUMNS, "rows": BASE_ROWS[:2], "width": 50},
    width=80,
)
add_table_case(
    "table min_width",
    {"columns": BASE_COLUMNS[:1], "rows": [["a"], ["b"]], "min_width": 25},
    width=80,
)

for vertical in ["top", "middle", "bottom"]:
    add_table_case(
        f"table vertical {vertical}",
        {"columns": [{"header": "A", "vertical": vertical},
                     {"header": "B"}, {"header": "C", "vertical": "bottom"}],
         "rows": [["x", "one\ntwo\nthree\nfour", "y"],
                  [{"kind": "align", "text": "mid", "align": "center",
                    "vertical": "middle"}, "1\n2\n3", "z"]]},
        width=40,
    )

for justify in ["left", "center", "right", "full"]:
    add_table_case(
        f"table column justify {justify}",
        {"columns": [{"header": "Text", "justify": justify, "width": 24}],
         "rows": [["The quick brown fox jumps over the lazy dog"]]},
        width=40,
    )

add_table_case(
    "table cjk and emoji",
    {"columns": [{"header": "名前"}, {"header": "Emoji :smile:"}],
     "rows": [["日本語のテキスト", ":thumbs_up: ok"], ["中文", "💩💩💩"]]},
    width=30,
)
add_table_case(
    "table markup and highlight",
    {"columns": [{"header": "[bold]Key"}, {"header": "Value", "highlight": True}],
     "rows": [["[red]alpha", "123 'str' None"], ["beta", "[1, 2.5, True]"]]},
    width=50,
)
add_table_case(
    "table rule cell",
    {"columns": [{"header": "A"}, {"header": "B"}],
     "rows": [["x", {"kind": "rule", "title": "mid"}], ["y", "z"]],
     "expand": True},
    width=40,
)
add_table_case(
    "table extra cells and empty",
    {"columns": [{"header": "A"}],
     "rows": [["1"], ["2", "3"], ["4", "5", "6"], [None]]},
    width=40,
)
add_table_case(
    "table no columns rows only",
    {"rows": [["a", "b"], ["c"]], "show_header": False},
    width=40,
)
add_table_case(
    "table grid",
    {"grid": True, "padding": (0, 1), "columns": [{}, {"justify": "right"}],
     "rows": [["left", "right"], ["a longer left cell", "r"]]},
    width=40,
)
add_table_case(
    "table grid expand",
    {"grid": True, "expand": True, "columns": [{"ratio": 1}, {"justify": "right"}],
     "rows": [["left", "right"]]},
    width=40,
)
for justify in ["left", "center", "right"]:
    add_table_case(
        f"table print justify {justify}",
        {"columns": BASE_COLUMNS[:2], "rows": BASE_ROWS[:1]},
        width=80,
        print_kw={"justify": justify},
    )
add_table_case(
    "table no color",
    {"columns": BASE_COLUMNS, "rows": BASE_ROWS[:2], "row_styles": ["on blue"]},
    width=70, color_system=None,
)
add_table_case(
    "table 256 colors",
    {"columns": BASE_COLUMNS, "rows": BASE_ROWS[:2], "border_style": "#ff8800",
     "row_styles": ["on #102030"]},
    width=70, color_system="256",
)

# --- console.print cases --------------------------------------------------

LOREM = ("Lorem ipsum dolor sit amet, [bold]consectetur[/bold] adipiscing elit, "
         "sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.")
LONG_WORD = "Supercalifragilisticexpialidocious-and-even-longer-words"


def add_print_case(name, objects, width=40, color_system="truecolor",
                   console_kw=None, **kw):
    console_kw = console_kw or {}
    console, file = make_console(width, color_system, **console_kw)
    if isinstance(objects, list):
        console.print(*objects, **kw)
        objs = "[" + ", ".join(mbt_str(o) for o in objects) + "]"
        call = f"  console.print_many({', '.join([objs] + mbt_print_args(kw))})\n"
    else:
        console.print(objects, **kw)
        call = f"  console.print({', '.join([mbt_str(objects)] + mbt_print_args(kw))})\n"
    body = mbt_console(width, color_system, **console_kw) + call
    cases.append((name, body, file.getvalue()))


for justify in ["default", "left", "center", "right", "full"]:
    for overflow in ["fold", "crop", "ellipsis", "ignore"]:
        add_print_case(f"print justify {justify} overflow {overflow}",
                       LOREM + " " + LONG_WORD, justify=justify,
                       overflow=overflow)
for no_wrap in [True, False]:
    for overflow in ["fold", "crop", "ellipsis"]:
        add_print_case(f"print no_wrap {no_wrap} overflow {overflow}",
                       LOREM, no_wrap=no_wrap, overflow=overflow)
for crop in [True, False]:
    add_print_case(f"print crop {crop}", LONG_WORD + " x", crop=crop,
                   overflow="ignore", no_wrap=True)
add_print_case("print soft_wrap", LOREM, soft_wrap=True)
add_print_case("print soft_wrap console", LOREM, console_kw={"soft_wrap": True})
add_print_case("print soft_wrap false override", LOREM,
               console_kw={"soft_wrap": True}, soft_wrap=False)
for width in [10, 25, 100]:
    add_print_case(f"print width {width}", LOREM, width=width)
    add_print_case(f"print width {width} justify right", LOREM, width=width,
                   justify="right")
add_print_case("print style", "Hello [italic]World[/italic]", style="bold on blue")
add_print_case("print style multiline", "one\ntwo\n\nthree", style="reverse")
add_print_case("print style justify", "styled", style="red", justify="center")
add_print_case("print new_line_start single", "one line", new_line_start=True)
add_print_case("print new_line_start multi", "one\ntwo", new_line_start=True)
add_print_case("print end", "no newline", end="")
add_print_case("print end custom", "custom", end=" <END>\n")
add_print_case("print sep", ["a", "b", "c"], sep=", ")
add_print_case("print many justify", ["left", "[b]mid", "right"], justify="center")
add_print_case("print emoji", "Hello :wave: :smile:")
add_print_case("print emoji off", "Hello :wave:", emoji=False)
add_print_case("print markup off", "[bold]not bold[/bold]", markup=False)
add_print_case("print highlight", "numbers 1 2.5 0x10 'str' None True https://x.org")
add_print_case("print highlight off", "numbers 1 2.5 'str'", highlight=False)
add_print_case("print tabs", "a\tb\tc\n\tindented")
add_print_case("print cjk wrap", "日本語のテキストを折り返す必要があります。" * 2, width=20)
add_print_case("print cjk justify", "中文 文字 对齐", width=20, justify="right")
add_print_case("print height", "a\nb\nc\nd", height=2)
add_print_case("print no color", "[bold red]x[/] y", color_system=None)
add_print_case("print standard color", "[#ff0000]x[/] [on #00ff00]y", color_system="standard")
# upstream caches the rendered codes per Style, so each color system gets
# its own colors here (see DEVIATIONS.md, style)
add_print_case("print 256 color", "[#fe0000]x[/] [on #00fe00]y", color_system="256")
add_print_case("print link", "[link=https://example.com]click[/link] [link=https://x.org]x[/]")
add_print_case("print control codes", "bell\x07 and backspace\x08 ok")
add_print_case("print long word fold", LONG_WORD * 2, width=20)
add_print_case("print trailing spaces", "trailing   \nspaces  ", width=20, justify="full")

# --- JSON -----------------------------------------------------------------

JSON_TEXTS = [
    '{"name": "apple", "count": 1, "price": 1.5, "tags": ["a", "b"], "ok": true, "none": null}',
    '[1, -0, -0.0, 1e5, 1.0E-7, 123456789012345678901234567890, 2.5e-300]',
    '{"b": 1, "aa": 2, "B": 3, "\\u00e9": 4, "\\ud83d\\udca9": 5, "\\ue000": 6, "": 7}',
    '{"nested": {"empty": {}, "list": [], "deep": [[1, [2, [3]]]]}}',
    '"just a string with \\"quotes\\" and \\\\ backslash \\n newline \\t tab"',
    '{"unicode": "caf\\u00e9 \\u4e2d\\u6587 \\ud83d\\ude00", "ctrl": "\\u0001\\u001f\\u007f"}',
    '[NaN, Infinity, -Infinity, 3.141592653589793, 0.1, 1e22, 1e16, 12345678.9]',
    '{"dup": 1, "x": 2, "dup": 3}',
]


def add_json_case(name, text, **kw):
    console, file = make_console(60)
    console.print_json(text, **kw)
    args = [f"json={mbt_str(text)}"]
    for k, v in kw.items():
        if k == "indent":
            args.append("indent=None" if v is None else f"indent=Some({v})")
        else:
            args.append(f"{k}={mbt_value(v)}")
    body = mbt_console(60) + f"  console.print_json({', '.join(args)})\n"
    cases.append((name, body, file.getvalue()))


for i, text in enumerate(JSON_TEXTS):
    for indent in [2, 4, None, 0]:
        for sort_keys in [False, True]:
            for ensure_ascii in [False, True]:
                add_json_case(
                    f"json {i} indent {indent} sort {sort_keys} ascii {ensure_ascii}",
                    text, indent=indent, sort_keys=sort_keys,
                    ensure_ascii=ensure_ascii,
                )
    add_json_case(f"json {i} no highlight", text, highlight=False)

# --- Align / Padding / Rule -------------------------------------------------


def add_render_case(name, py_obj, mbt_expr, width=30, height=None, print_kw=None):
    print_kw = print_kw or {}
    console, file = make_console(width, height=height)
    console.print(py_obj, **print_kw)
    body = mbt_console(width, height=height)
    args = [mbt_expr] + mbt_print_args(print_kw)
    body += f"  console.print({', '.join(args)})\n"
    cases.append((name, body, file.getvalue()))


for align in ["left", "center", "right"]:
    for vertical in [None, "top", "middle", "bottom"]:
        for height in [None, 7]:
            for style in [None, "on blue"]:
                kw = {}
                margs = [mbt_str("foo\nbarbaz"), mbt_enum(align)]
                if vertical:
                    kw["vertical"] = vertical
                    margs.append(f"vertical={mbt_enum(vertical)}")
                if style:
                    kw["style"] = style
                    margs.append(f"style={mbt_str(style)}")
                print_kw = {"height": height} if height else {}
                add_render_case(
                    f"align {align} {vertical} height {height} style {style}",
                    Align("foo\nbarbaz", align, **kw),
                    f"@rich.Align::new({', '.join(margs)})",
                    width=20, print_kw=print_kw,
                )
add_render_case("align width height", Align("hello", "center", width=10, height=3,
                vertical="middle", style="on red"),
                '@rich.Align::new("hello", Center, width=10, height=3, vertical=Middle, style="on red")',
                width=30)
add_render_case("align no pad", Align("hello", "center", pad=False, vertical="bottom",
                height=3), '@rich.Align::new("hello", Center, pad=false, vertical=Bottom, height=3)',
                width=30)
add_render_case("align table", Align(py_table({"columns": BASE_COLUMNS[:1], "rows": [["x"]]}), "right"),
                "{\n" + mbt_table({"columns": BASE_COLUMNS[:1], "rows": [["x"]]}).replace("\n", "\n  ") + "  @rich.Align::new(table, Right)\n  }",
                width=30)

for pad in [(0,), (1,), (1, 2), (0, 3, 1, 5), (2, 0)]:
    for expand in [True, False]:
        for style in [None, "on magenta"]:
            kw = {"expand": expand}
            margs = [mbt_str("Hello\nWorld!"), f"pad=[{', '.join(map(str, pad))}]",
                     f"expand={mbt_value(expand)}"]
            if style:
                kw["style"] = style
                margs.append(f"style={mbt_str(style)}")
            add_render_case(f"padding {pad} expand {expand} style {style}",
                            Padding("Hello\nWorld!", pad, **kw),
                            f"@rich.Padding::new({', '.join(margs)})", width=20)
add_render_case("padding height", Padding("x", (1, 1)), '@rich.Padding::new("x", pad=[1, 1])',
                width=10, print_kw={"height": 5})

for title in ["", "Title", "[b]Bold[/b] title", "A very long title that will not fit"]:
    for align in ["left", "center", "right"]:
        for characters in ["─", "=-", "🎉"]:
            add_render_case(
                f"rule {title!r} {align} {characters}",
                Rule(title, align=align, characters=characters),
                f"@rich.Rule::new(title={mbt_str(title)}, align={mbt_enum(align)}, characters={mbt_str(characters)})",
                width=25,
            )
add_render_case("rule style", Rule("x", style="bold red", end=""),
                '@rich.Rule::new(title="x", style="bold red", end="")', width=20)
add_render_case("rule odd width", Rule("ab"), '@rich.Rule::new(title="ab")', width=11)
add_render_case("rule cjk title", Rule("中文标题"), '@rich.Rule::new(title="中文标题")', width=15)

# --- output -----------------------------------------------------------------

out = [
    "// Generated by scripts/layout_oracle.py from upstream Rich. DO NOT EDIT.",
    "",
]
LINK_ID = re.compile(r"id=\d+;")
for name, body, expected in cases:
    out.append("///|")
    out.append(f"test {mbt_str('oracle ' + name)} {{")
    out.append(body.rstrip("\n"))
    if LINK_ID.search(expected):
        # link ids are random
        expected = LINK_ID.sub("id=0;", expected)
        out.append(f"  assert_eq(normalize_link_ids(file.getvalue()), {mbt_str(expected)})")
    else:
        out.append(f"  assert_eq(file.getvalue(), {mbt_str(expected)})")
    out.append("}")
    out.append("")
OUT.write_text("\n".join(out))
print(f"wrote {len(cases)} cases to {OUT}")
