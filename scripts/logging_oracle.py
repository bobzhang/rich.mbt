"""Differential data for RichHandler: logging/logging_oracle_test.mbt.

Run with the venv that has upstream Rich installed:
    .venv/bin/python scripts/logging_oracle.py
Times are formatted with formats that do not depend on the time zone.
"""
import io
import json
import re
import logging
from pathlib import Path

from rich.console import Console
from rich.logging import RichHandler
from rich.text import Text

T0 = 1700000000.25  # 2023-11-14 (any time zone)
PATH = "/home/user/project/app.py"


def rec(level, msg, created=T0, pathname=PATH, lineno=10, name="rich",
        exc_text=None, markup=None, no_highlight=False, func="main"):
    return dict(level=level, msg=msg, created=created, pathname=pathname,
                lineno=lineno, name=name, exc_text=exc_text, markup=markup,
                no_highlight=no_highlight, func=func)


BASIC = [
    rec(20, "Server starting..."),
    rec(20, "Listening on http://127.0.0.1:8080"),
    rec(20, "GET /index.html 200 1298", created=T0 + 1),
    rec(30, "GET /favicon.ico 404 242", created=T0 + 1),
    rec(10, "JSONRPC request\n--> {'version': '1.1', 'params': [['apple', 'orange'], 1.123]}\n<-- {'result': True, 'error': None}", created=T0 + 2),
    rec(40, "Unable to find 'pomelo' in database!", created=T0 + 2),
    rec(50, "Out of memory!", created=T0 + 3, lineno=0),
    rec(25, "custom level 25", created=T0 + 3),
    rec(20, "[bold]EXITING...[/bold]", markup=True, created=T0 + 4),
]

LONG = [
    rec(20, "Loading configuration file /adasd/asdasd/qeqwe/qwrqwrqwr/sdgsdgsdg/werwerwer/dfgerert/ertertert/ertetert/werwerwer and more words to wrap"),
    rec(40, "with exception", exc_text="Traceback (most recent call last):\n  File \"app.py\", line 3, in <module>\nZeroDivisionError: division by zero"),
]

MARKUP = [
    rec(20, "foo 3.141 127.0.0.1 [red]alert[/red]"),
    rec(20, "foo 3.141 127.0.0.1 [red]alert[/red]", markup=False),
    rec(20, "foo 3.141 127.0.0.1 [red]alert[/red] POST", no_highlight=True),
]

# (case name, python handler kwargs, mbt handler args, python formatter, mbt formatter, width, records)
CASES = [
    ("basic", "enable_link_path=False", "enable_link_path=false",
     "logging.Formatter('%(message)s', datefmt='[DATE]')", "@logging.Formatter::new(datefmt=\"[DATE]\")", 80, BASIC),
    ("link_path", "", "", "logging.Formatter(datefmt='[%Y]')", "@logging.Formatter::new(datefmt=\"[%Y]\")", 80, BASIC[:3]),
    ("time_format_year", "log_time_format='[%Y]'", "log_time_format=\"[%Y]\"", None, None, 80, BASIC[:4]),
    ("time_formatter", "log_time_format=lambda dt: Text(str(int(dt.timestamp()) % 100), style='green')",
     "log_time_formatter=t => @rich.Text::new(text=\"\\{t.to_int() % 100}\", style=\"green\")", None, None, 80, BASIC),
    ("no_omit", "omit_repeated_times=False, log_time_format='%Y'", "omit_repeated_times=false, log_time_format=\"%Y\"", None, None, 60, BASIC[:4]),
    ("no_time_level_path", "show_time=False, show_level=False, show_path=False", "show_time=false, show_level=false, show_path=false", None, None, 50, BASIC),
    ("no_time", "show_time=False", "show_time=false", None, None, 60, BASIC[:6]),
    ("markup", "markup=True, enable_link_path=False", "markup=true, enable_link_path=false",
     "logging.Formatter('%(message)s', datefmt='[DATE]')", "@logging.Formatter::new(datefmt=\"[DATE]\")", 100, MARKUP),
    ("keywords", "keywords=['foo', 'alert'], enable_link_path=False", "keywords=[\"foo\", \"alert\"], enable_link_path=false",
     "logging.Formatter('%(message)s', datefmt='[DATE]')", "@logging.Formatter::new(datefmt=\"[DATE]\")", 100, MARKUP + BASIC[2:4]),
    ("no_keywords", "keywords=[], enable_link_path=False", "keywords=[], enable_link_path=false",
     "logging.Formatter('%(message)s', datefmt='[DATE]')", "@logging.Formatter::new(datefmt=\"[DATE]\")", 100, BASIC[2:4]),
    ("long", "enable_link_path=False", "enable_link_path=false",
     "logging.Formatter(datefmt='%Y')", "@logging.Formatter::new(datefmt=\"%Y\")", 60, LONG),
    ("formatter_fields", "enable_link_path=False", "enable_link_path=false",
     "logging.Formatter('%(levelname)s:%(name)s:%(message)s [%(asctime)s] %(lineno)d %(filename)s %(module)s %(funcName)s %(levelno)05d|%(name)-6s|%(name)6s|%(msg).3s|%%', datefmt='%Y')",
     "@logging.Formatter::new(fmt=\"%(levelname)s:%(name)s:%(message)s [%(asctime)s] %(lineno)d %(filename)s %(module)s %(funcName)s %(levelno)05d|%(name)-6s|%(name)6s|%(msg).3s|%%\", datefmt=\"%Y\")",
     120, BASIC[:2] + LONG[1:]),
]


def make_record(r):
    record = logging.LogRecord(r["name"], r["level"], r["pathname"], r["lineno"],
                               r["msg"], None, None, func=r["func"])
    record.created = r["created"]
    record.msecs = 250.0
    if r["exc_text"] is not None:
        record.exc_text = r["exc_text"]
    if r["markup"] is not None:
        record.markup = r["markup"]
    if r["no_highlight"]:
        record.highlighter = None
    return record


def mbt_str(s):
    return json.dumps(s, ensure_ascii=False).replace("\\u001b", "\\u{1b}")


def mbt_record(r):
    args = [f"name={mbt_str(r['name'])}", str(r["level"]), mbt_str(r["msg"]),
            f"pathname={mbt_str(r['pathname'])}", f"lineno={r['lineno']}",
            f"func_name={mbt_str(r['func'])}", f"created={r['created']!r}"]
    if r["exc_text"] is not None:
        args.append(f"exc_text={mbt_str(r['exc_text'])}")
    if r["markup"] is not None:
        args.append(f"markup={'true' if r['markup'] else 'false'}")
    if r["no_highlight"]:
        args.append("highlighter=@rich.NullHighlighter::new()")
    return "@logging.LogRecord::new(" + ", ".join(args) + ")"


out = ["// Generated by scripts/logging_oracle.py. DO NOT EDIT.", ""]
for name, py_kwargs, mbt_args, py_fmt, mbt_fmt, width, records in CASES:
    console = Console(file=io.StringIO(), force_terminal=True, width=width,
                      color_system="truecolor", legacy_windows=False, _environ={})
    handler = eval(f"RichHandler(console=console, {py_kwargs})")
    if py_fmt:
        handler.setFormatter(eval(py_fmt))
    for r in records:
        handler.handle(make_record(r))
    # link ids are random: normalize them
    expected = re.sub(r"\]8;id=\d+;", "]8;id=0;", console.file.getvalue())
    out.append("///|")
    out.append(f"test \"oracle {name}\" {{")
    out.append(f"  let (console, file) = term_console({width})")
    args = ", ".join(a for a in ["console~", mbt_args] if a)
    out.append(f"  let handler = @logging.RichHandler::new({args})")
    if mbt_fmt:
        out.append(f"  handler.set_formatter(Some({mbt_fmt}))")
    for r in records:
        out.append(f"  handler.handle({mbt_record(r)})")
    out.append(f"  assert_eq(normalize_links(file.getvalue()), {mbt_str(expected)})")
    out.append("}")
    out.append("")

Path(__file__).parent.parent.joinpath("logging/logging_oracle_test.mbt").write_text("\n".join(out))
