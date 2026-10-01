"""Differential cases for Traceback: traceback/oracle_test.mbt.

Raises real exceptions in a scenario module, extracts them with upstream
`Traceback.extract`, renames the files to fixed fake paths, dumps the Trace
as JSON (locals as `pretty.Node` dicts) and renders it with upstream
Rich. `os.path.exists` and `linecache.getlines` are redirected to the fake
sources, which is what the MoonBit `source_reader` does.

    /Users/dii/git/rich.mbt/.venv/bin/python scripts/traceback_oracle.py
"""
import dataclasses
import importlib.util
import io
import json
import os
import subprocess
import sys
import tempfile
import types
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from mbt_literal import mbt_lines, mbt_str  # noqa: E402

import rich.traceback as rt  # noqa: E402
from rich.console import Console  # noqa: E402
from rich.theme import Theme  # noqa: E402
from rich.traceback import Traceback  # noqa: E402

OUT = Path(__file__).parent.parent / "traceback" / "oracle_test.mbt"

HELPERS_SRC = '''\
"""Helpers living in another file (used to test `suppress`)."""


def call(function, *args):
    result = function(*args)
    return result


def check_positive(value):
    if value <= 0:
        raise ValueError(f"expected a positive value, got {value!r}")
    return value
'''

APP_SRC = '''\
import sys

import helpers


def capture(name):
    try:
        globals()[name]()
    except BaseException:
        return sys.exc_info()


def divide(a, b):
    return a / b


def level2(x):
    total = x * 2
    return divide(total, 0)


def level1():
    data = {"key": [1, 2, 3], "name": "value"}
    flag = True
    return level2(21)


def zero_division():
    level1()


def no_message():
    raise RuntimeError


def nested():
    try:
        level1()
    except ZeroDivisionError:
        raise ValueError("ValueError because of ZeroDivisionError")


def caused():
    try:
        level1()
    except ZeroDivisionError as e:
        raise ValueError("ValueError caused by ZeroDivisionError") from e


def recursive(n):
    if n > 12:
        raise RecursionError("maximum recursion depth exceeded")
    return recursive2(n + 1)


def recursive2(n):
    return recursive(n)


def recursion():
    recursive(0)


def syntax_error():
    eval("(2+2")


def file_syntax_error():
    compile("x = = 1\\n", "/project/bad.py", "exec")


def string_code():
    exec(compile("1/0", filename="<string>", mode="exec"))


def not_a_file():
    exec(compile("1/0", filename="string", mode="exec"))


def with_notes():
    try:
        1 / 0
    except Exception as error:
        error.add_note("Hello")
        error.add_note("World 'quoted' 123")
        raise


def group():
    errors = []
    for exc in (ValueError("bad value"), TypeError("bad type")):
        try:
            raise exc
        except Exception as e:
            errors.append(e)
    raise ExceptionGroup("many errors", errors)


def multiline():
    return divide(
        1,
        0,
    )


def long_line():
    message = "a very long line of code that will certainly not fit into the code width"; return message + 1  # noqa


def asian():
    # 这是对亚洲语言支持的测试。面对模棱两可的想法，拒绝猜测的诱惑
    value = {"键": "值"}
    return value["缺失"]


def key_error():
    {}["missing"]


def via_helpers():
    helpers.call(helpers.check_positive, -5)


def dunder_locals():
    __secret = 42
    _private = "x"
    visible = [None, False, 1.5]
    numbers = list(range(40))
    long_text = "lorem ipsum " * 12
    nested = {"alpha": [1, 2, {"beta": (3, 4)}], "gamma": {"delta": "epsilon", "zeta": [None] * 3}}
    return divide(visible[2], 0)


def tabs():
\tvalue = 1
\treturn value / 0
'''

FAKE_APP = "/project/app.py"
FAKE_HELPERS = "/project/lib/helpers.py"
SOURCES = {FAKE_APP: APP_SRC, FAKE_HELPERS: HELPERS_SRC}

tmp = tempfile.mkdtemp()
Path(tmp, "app.py").write_text(APP_SRC)
Path(tmp, "helpers.py").write_text(HELPERS_SRC)
sys.path.insert(0, tmp)
spec = importlib.util.spec_from_file_location("app", Path(tmp, "app.py"))
app = importlib.util.module_from_spec(spec)
sys.modules["app"] = app
spec.loader.exec_module(app)
REMAP = {
    os.path.realpath(Path(tmp, "app.py")): FAKE_APP,
    str(Path(tmp, "app.py")): FAKE_APP,
    os.path.realpath(Path(tmp, "helpers.py")): FAKE_HELPERS,
    str(Path(tmp, "helpers.py")): FAKE_HELPERS,
}


def remap(filename):
    return REMAP.get(filename, filename)


def trace_json(trace):
    def frame(f):
        return {
            "filename": remap(f.filename),
            "lineno": f.lineno,
            "name": f.name,
            "line": f.line,
            "locals": None if f.locals is None else {
                k: dataclasses.asdict(v) for k, v in f.locals.items()
            },
            "last_instruction": None if f.last_instruction is None else [
                list(f.last_instruction[0]), list(f.last_instruction[1])
            ],
        }

    def stack(s):
        return {
            "exc_type": s.exc_type,
            "exc_value": s.exc_value,
            "syntax_error": None if s.syntax_error is None else {
                **dataclasses.asdict(s.syntax_error),
                "filename": remap(s.syntax_error.filename),
            },
            "is_cause": s.is_cause,
            "frames": [frame(f) for f in s.frames],
            "notes": list(s.notes),
            "is_group": s.is_group,
            "exceptions": [trace_json(t) for t in s.exceptions],
        }

    return {"stacks": [stack(s) for s in trace.stacks]}


def remap_trace(trace):
    for s in trace.stacks:
        for f in s.frames:
            f.filename = remap(f.filename)
        if s.syntax_error is not None:
            s.syntax_error.filename = remap(s.syntax_error.filename)
        for t in s.exceptions:
            remap_trace(t)
    return trace


# Redirect file access in rich.traceback to the fake sources.
rt.linecache = types.SimpleNamespace(
    getlines=lambda f: SOURCES[f].splitlines(True) if f in SOURCES else [])
_real_exists = os.path.exists
os.path.exists = lambda p: p in SOURCES

SCENARIOS = ["zero_division", "no_message", "nested", "caused", "recursion",
             "syntax_error", "file_syntax_error", "string_code", "not_a_file",
             "with_notes", "group", "multiline", "long_line", "asian",
             "key_error", "via_helpers", "dunder_locals", "tabs"]

# (scenario, extract kwargs, Traceback kwargs, console kwargs)
CASES = []
for name in SCENARIOS:
    CASES.append((name, {}, {}, {"width": 100, "color_system": "truecolor"}))
CASES += [
    ("zero_division", {"show_locals": True}, {"show_locals": True},
     {"width": 100, "color_system": "truecolor"}),
    ("zero_division", {"show_locals": True}, {"show_locals": True, "code_width": 50},
     {"width": 140, "color_system": "256"}),
    ("dunder_locals", {"show_locals": True, "locals_hide_dunder": False,
                       "locals_hide_sunder": False},
     {"show_locals": True, "indent_guides": False}, {"width": 100, "color_system": "standard"}),
    ("dunder_locals", {"show_locals": True, "locals_hide_sunder": True},
     {"show_locals": True, "width": None}, {"width": 120, "color_system": "truecolor"}),
    ("recursion", {}, {"max_frames": 6}, {"width": 100, "color_system": "truecolor"}),
    ("recursion", {}, {"max_frames": 0}, {"width": 80, "color_system": None}),
    ("nested", {}, {"theme": "monokai"}, {"width": 100, "color_system": "truecolor"}),
    ("caused", {}, {"theme": "ansi_light", "extra_lines": 1},
     {"width": 80, "color_system": "256"}),
    ("long_line", {}, {"word_wrap": True, "code_width": 40},
     {"width": 70, "color_system": "truecolor"}),
    ("long_line", {}, {"code_width": None, "width": None},
     {"width": 70, "color_system": "standard"}),
    ("via_helpers", {}, {"suppress": ["/project/lib"]},
     {"width": 100, "color_system": "truecolor"}),
    ("multiline", {}, {"extra_lines": 0, "indent_guides": False},
     {"width": 60, "color_system": "truecolor"}),
    ("group", {}, {"theme": "dracula"}, {"width": 90, "color_system": "truecolor"}),
    ("syntax_error", {}, {"width": 50}, {"width": 100, "color_system": "standard"}),
    ("file_syntax_error", {}, {"theme": "monokai"},
     {"width": 80, "color_system": "truecolor"}),
    ("asian", {}, {"word_wrap": True}, {"width": 60, "color_system": "truecolor"}),
    ("tabs", {}, {"theme": "github-dark"}, {"width": 100, "color_system": "256"}),
    ("zero_division", {}, {}, {"width": 40, "color_system": "truecolor"}),
]


def render(trace, tb_kwargs, console_kwargs):
    f = io.StringIO()
    console = Console(file=f, force_terminal=True, legacy_windows=False,
                      _environ={}, **console_kwargs)
    console.print(Traceback(trace, **tb_kwargs))
    return f.getvalue()


traces = []
for name, extract_kwargs, _, _ in CASES:
    exc_type, exc_value, tb = app.capture(name)
    trace = Traceback.extract(exc_type, exc_value, tb, **extract_kwargs)
    traces.append(remap_trace(trace))

if len(sys.argv) == 3 and sys.argv[1] == "--render":
    color_system = json.loads(sys.argv[2])
    results = {}
    for i, (case, trace) in enumerate(zip(CASES, traces)):
        if case[3]["color_system"] == color_system:
            results[i] = render(trace, case[2], case[3])
    json.dump(results, sys.stdout)
    sys.exit(0)

# Upstream caches ANSI codes per Style object: render each color system in a
# fresh interpreter.
outputs = {}
for cs in {case[3]["color_system"] for case in CASES}:
    proc = subprocess.run([sys.executable, __file__, "--render", json.dumps(cs)],
                          check=True, capture_output=True, text=True)
    outputs.update({int(k): v for k, v in json.loads(proc.stdout).items()})

# The test from upstream test_traceback_console_theme_applies.
theme_trace = traces[0]
f = io.StringIO()
console = Console(file=f, width=80, force_terminal=True, _environ={"COLORTERM": "truecolor"},
                  theme=Theme({"traceback.title": "rgb(123,234,123)"}))
console.print(Traceback(theme_trace))
theme_expected = f.getvalue()


def mbt_value(key, value):
    if isinstance(value, bool):
        return f"{key}={'true' if value else 'false'}"
    if value is None:
        return f"{key}=None"
    if key in ("width", "code_width"):
        return f"{key}=Some({value})"
    if isinstance(value, int):
        return f"{key}={value}"
    if isinstance(value, str):
        return f"{key}={mbt_str(value)}"
    if isinstance(value, list):
        return f"{key}=[{', '.join(mbt_str(v) for v in value)}]"
    raise TypeError(value)


out = ["// Generated by scripts/traceback_oracle.py. DO NOT EDIT.", ""]
out.append("///|")
out.append(mbt_lines("source_app", APP_SRC).rstrip())
out.append("")
out.append("///|")
out.append(mbt_lines("source_helpers", HELPERS_SRC).rstrip())
out.append("")
out.append(f"""///|
fn read_source(filename : String) -> String? {{
  match filename {{
    {mbt_str(FAKE_APP)} => Some(source_app)
    {mbt_str(FAKE_HELPERS)} => Some(source_helpers)
    _ => None
  }}
}}

///|
fn oracle_console(width~ : Int, color_system~ : String?) -> (@rich.Console, @rich.StringIO) raise {{
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    file~,
    width~,
    color_system~,
    force_terminal=true,
    legacy_windows=false,
    environ={{}},
  )
  (console, file)
}}
""")
for i, ((name, extract_kwargs, tb_kwargs, console_kwargs), trace) in enumerate(
        zip(CASES, traces)):
    data = json.dumps(trace_json(trace), ensure_ascii=False)
    cs = console_kwargs["color_system"]
    cs = "None" if cs is None else f"Some({mbt_str(cs)})"
    args = ["trace", "source_reader=read_source"]
    args += [mbt_value(k, v) for k, v in tb_kwargs.items()]
    out.append("///|")
    out.append(f"test {mbt_str(f'oracle {i}: {name} {extract_kwargs} {tb_kwargs} {console_kwargs}')} {{")
    out.append(mbt_lines("data", data, indent="  ").rstrip())
    out.append("  let trace = @traceback.Trace::from_json(@json.parse(data))")
    out.append(f"  let (console, file) = oracle_console(width={console_kwargs['width']}, color_system={cs})")
    out.append(f"  console.print(@traceback.Traceback::new({', '.join(args)}))")
    out.append(mbt_lines("expected", outputs[i], indent="  ").rstrip())
    out.append("  assert_eq(file.getvalue(), expected)")
    out.append("}")
    out.append("")

data = json.dumps(trace_json(theme_trace), ensure_ascii=False)
out.append("///|")
out.append('test "traceback_console_theme_applies (full output)" {')
out.append(mbt_lines("data", data, indent="  ").rstrip())
out.append("  let trace = @traceback.Trace::from_json(@json.parse(data))")
out.append("""  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    file~,
    width=80,
    force_terminal=true,
    environ={ "COLORTERM": "truecolor" },
    theme=@rich.Theme::new(styles={ "traceback.title": "rgb(123,234,123)" }),
  )
  console.print(@traceback.Traceback::new(trace, source_reader=read_source))""")
out.append(mbt_lines("expected", theme_expected, indent="  ").rstrip())
out.append("  assert_eq(file.getvalue(), expected)")
out.append("}")
out.append("")
OUT.write_text("\n".join(out))
os.path.exists = _real_exists
print(f"wrote {len(CASES) + 1} cases to {OUT}")
