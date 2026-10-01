"""Differential cases for Syntax: syntax/oracle_test.mbt.

Renders a matrix of languages x themes x options with upstream Rich (and
Pygments 2.21) and emits MoonBit tests that rebuild the same Syntax and
compare the output byte for byte.

Upstream caches the ANSI codes of a Style object for the first color system
it is rendered with (and shares Style objects through lru_caches), so cases
are rendered in one fresh interpreter per color system.

    /Users/dii/git/rich.mbt/.venv/bin/python scripts/syntax_oracle.py
"""
import io
import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from mbt_literal import mbt_lines, mbt_str  # noqa: E402

from rich.console import Console  # noqa: E402
from rich.syntax import Syntax  # noqa: E402

OUT = Path(__file__).parent.parent / "syntax" / "oracle_test.mbt"

SAMPLES = {
    "python": '''\
import os

@decorator
class Foo(Base):
    """Docstring with a very long line that is going to need wrapping when the width is small."""

    def method(self, x: int = 0x1F) -> str:
        if x > 10 and not None:
\t\treturn f"value {x!r}"  # comment
        return 'café 中文'
''',
    "rust": '''\
use std::collections::HashMap;

/// Doc comment
fn main() {
    let mut map: HashMap<&str, i32> = HashMap::new();
    map.insert("one", 1);
    for (k, v) in &map {
        println!("{}: {}", k, v);
    }
}
''',
    "javascript": '''\
// A comment
const add = (a, b) => a + b;
class Point {
  constructor(x, y) { this.x = x; this.y = y; }
}
console.log(`sum: ${add(1, 2)}`, /re+gex/g, null);
''',
    "c": '''\
#include <stdio.h>

int main(int argc, char **argv) {
\tprintf("hello %d\\n", argc); /* block */
\treturn 0;
}
''',
    "html": '''\
<!DOCTYPE html>
<html>
  <body class="main">
    <p>Hello &amp; <b>world</b></p>
    <script>var x = 1;</script>
  </body>
</html>
''',
    "json": '''\
{
  "name": "rich",
  "version": [1, 2.5, -3e10],
  "ok": true,
  "none": null
}
''',
    "yaml": '''\
key: value
list:
  - one
  - "two"
nested:
  number: 42  # comment
''',
    "bash": '''\
#!/bin/bash
for f in *.txt; do
  echo "file: $f" | grep -v '^#' > /dev/null
done
export X=${HOME:-/tmp}
''',
    "sql": '''\
SELECT id, name FROM users
WHERE age > 21 AND name LIKE 'A%'
ORDER BY name DESC; -- comment
''',
    "diff": '''\
--- a/file.txt
+++ b/file.txt
@@ -1,3 +1,3 @@
 context
-removed line
+added line
''',
    "go": '''\
package main

import "fmt"

func main() {
\tch := make(chan int, 3)
\tfmt.Println("hi", len(ch))
}
''',
}

EXTRA_SAMPLES = {
    "css": "body > .main:hover {\n  color: #fff;\n  margin: 0 auto !important;\n}\n@media (max-width: 600px) { a { b: 1px } }\n",
    "ruby": "class Foo < Bar\n  def hello(name = \"x\")\n    puts \"hi #{name}\" if name =~ /\\w+/\n  end\nend\n",
    "php": "<?php\n$x = array(1, 2);\nforeach ($x as $k => $v) { echo \"$k: {$v}\\n\"; }\n?>\n<p>html</p>\n",
    "typescript": "interface P { x: number; y?: string }\nexport const f = <T,>(a: T): T => a;\nenum E { A = 1, B }\n",
    "toml": "[package]\nname = \"rich\"\nversion = \"0.1.0\" # comment\n[deps]\nx = { version = \"1\", features = [\"a\"] }\n",
    "docker": "FROM python:3.12-slim\nRUN pip install rich && \\\n    echo done\nCMD [\"python\", \"-m\", \"rich\"]\n",
    "make": "all: build\n\nbuild: $(SRC)\n\t$(CC) -o $@ $^ $(CFLAGS)\n.PHONY: all\n",
    "java": "public class Main {\n  @Override\n  public static void main(String[] args) {\n    System.out.println(\"hi\" + args.length);\n  }\n}\n",
    "haskell": "module Main where\nimport Data.List (sort)\nmain :: IO ()\nmain = print $ sort [3, 1, 2] -- comment\n",
    "lua": "local t = {a = 1, [2] = 'b'}\nfor k, v in pairs(t) do\n  print(k, v) -- comment\nend\n",
    "markdown": "# Title\n\nSome *emph* and **strong** text with `code`.\n\n- item\n\n```python\nprint(1)\n```\n",
    "ini": "[section]\nkey = value ; comment\nother=1\n",
    "perl": "my @a = (1, 2);\nprint \"$_\\n\" for grep { /\\d/ } @a;\n",
    "kotlin": "fun main() {\n    val xs = listOf(1, 2)\n    println(\"${xs.size}\")\n}\n",
    "scala": "object Main extends App {\n  val x: Int = 42\n  println(s\"x = $x\")\n}\n",
    "swift": "let x: [Int] = [1, 2]\nfunc f(_ a: Int) -> Int { return a * 2 }\n",
    "elixir": "defmodule M do\n  def f(x), do: x |> Enum.map(&(&1 * 2))\nend\n",
    "nim": "proc f(x: int): int =\n  result = x * 2\necho f(21)\n",
    "xml": "<?xml version=\"1.0\"?>\n<root a=\"1\"><!-- c --><child>t</child></root>\n",
    "tex": "\\\\documentclass{article}\n\\\\begin{document} $x^2$ % c\n\\\\end{document}\n",
    "console": "$ ls -la\ntotal 0\n# echo hi\nhi\n",
    "pycon": ">>> 1 + 1\n2\n>>> raise ValueError('x')\nTraceback (most recent call last):\n  File \"<stdin>\", line 1, in <module>\nValueError: x\n",
    "rst": "Title\n=====\n\n.. code:: python\n\n   print(1)\n\n*emph* ``lit``\n",
    "erlang": "-module(m).\nf(X) when X > 0 -> {ok, X};\nf(_) -> error.\n",
    "clojure": "(defn f [x] (* x 2)) ; c\n(println (f 21) :kw \"s\")\n",
}

THEMES = ["monokai", "default", "ansi_dark", "ansi_light", "dracula",
          "solarized-light", "github-dark", "nord", "emacs", "vim",
          "gruvbox-dark", "one-dark", "no-such-theme"]

OPTION_SETS = [
    {},
    {"line_numbers": True},
    {"line_numbers": True, "word_wrap": True, "code_width": 30},
    {"indent_guides": True},
    {"indent_guides": True, "line_numbers": True, "line_range": (2, 6)},
    {"line_range": (3, None), "highlight_lines": [4]},
    {"line_numbers": True, "highlight_lines": [1, 3], "start_line": 98},
    {"padding": (1, 2), "background_color": "#203040"},
    {"tab_size": 8, "word_wrap": True},
    {"dedent": True, "line_numbers": True, "line_range": (None, 4)},
    {"code_width": 20},
    {"padding": 1, "word_wrap": True, "line_numbers": True},
]

CONSOLES = [
    {"width": 60, "color_system": "truecolor"},
    {"width": 45, "color_system": "256"},
    {"width": 80, "color_system": "standard"},
    {"width": 50, "color_system": None},
]


def render(syntax, console_args, no_wrap=False):
    f = io.StringIO()
    console = Console(file=f, legacy_windows=False, force_terminal=True,
                      _environ={}, **console_args)
    console.print(syntax, no_wrap=no_wrap)
    return f.getvalue()


def mbt_option(key, value):
    if key in ("line_numbers", "word_wrap", "indent_guides", "dedent"):
        return f"{key}={'true' if value else 'false'}"
    if key in ("code_width", "tab_size", "start_line"):
        return f"{key}={value}"
    if key == "background_color":
        return f"{key}={mbt_str(value)}"
    if key == "line_range":
        a, b = value
        fmt = lambda v: "None" if v is None else f"Some({v})"  # noqa: E731
        return f"line_range=({fmt(a)}, {fmt(b)})"
    if key == "highlight_lines":
        return f"highlight_lines=[{', '.join(map(str, value))}]"
    if key == "padding":
        values = value if isinstance(value, tuple) else (value,)
        return f"padding=[{', '.join(map(str, values))}]"
    raise KeyError(key)


cases = []
langs = list(SAMPLES)
n = 0
for li, lang in enumerate(langs):
    for oi, options in enumerate(OPTION_SETS):
        theme = THEMES[(li * 5 + oi) % len(THEMES)]
        console_args = CONSOLES[(li + oi) % len(CONSOLES)]
        cases.append((lang, theme, options, console_args, False, None))
# more languages, one rendering each
for li, (lang, code) in enumerate(EXTRA_SAMPLES.items()):
    SAMPLES[lang] = code
    cases.append((lang, THEMES[li % len(THEMES)], OPTION_SETS[li % len(OPTION_SETS)],
                  CONSOLES[li % len(CONSOLES)], False, None))
# a few extra: stylize_range, no_wrap, explicit theme sweep on python
for theme in THEMES:
    cases.append(("python", theme, {"line_numbers": True},
                  {"width": 70, "color_system": "truecolor"}, False, None))
cases.append(("python", "monokai", {"line_numbers": True},
              {"width": 40, "color_system": "truecolor"}, True, None))
cases.append(("python", "monokai", {},
              {"width": 60, "color_system": "truecolor"}, False,
              [("bold red", (2, 0), (2, 3), False),
               ("on blue", (5, 4), (8, 2), True),
               ("underline", (9, 0), (9, 500), False)]))
cases.append(("rust", "ansi_dark", {"line_numbers": True, "word_wrap": True},
              {"width": 40, "color_system": "standard"}, False,
              [("reverse", (4, 4), (4, 7), False)]))



def build(case):
    lang, theme, options, console_args, no_wrap, ranges = case
    syntax = Syntax(SAMPLES[lang], lang, theme=theme, **options)
    for style, start, end, before in ranges or []:
        syntax.stylize_range(style, start, end, style_before=before)
    return syntax


if len(sys.argv) == 3 and sys.argv[1] == "--render":
    color_system = json.loads(sys.argv[2])
    results = {}
    for i, case in enumerate(cases):
        if case[3]["color_system"] == color_system:
            results[i] = render(build(case), case[3], case[4])
    json.dump(results, sys.stdout)
    sys.exit(0)

outputs = {}
for cs in {case[3]["color_system"] for case in cases}:
    proc = subprocess.run(
        [sys.executable, __file__, "--render", json.dumps(cs)],
        check=True, capture_output=True, text=True)
    outputs.update({int(k): v for k, v in json.loads(proc.stdout).items()})

out = ["// Generated by scripts/syntax_oracle.py. DO NOT EDIT.", ""]
for lang, code in SAMPLES.items():
    out.append("///|")
    out.append(mbt_lines(f"sample_{lang}", code).rstrip())
    out.append("")
out.append("""///|
fn oracle_render(
  syntax : @syntax.Syntax,
  width~ : Int,
  color_system~ : String?,
  no_wrap? : Bool = false,
) -> String raise {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    file~,
    width~,
    color_system~,
    force_terminal=true,
    legacy_windows=false,
    environ={},
  )
  console.print(syntax, no_wrap~)
  file.getvalue()
}
""")
for i, (lang, theme, options, console_args, no_wrap, ranges) in enumerate(cases):
    expected = outputs[i]
    args = [f"sample_{lang}", mbt_str(lang), f"theme={mbt_str(theme)}"]
    args += [mbt_option(k, v) for k, v in options.items()]
    desc = f"{lang} {theme} {options} {console_args}"
    cs = console_args["color_system"]
    cs = "None" if cs is None else f"Some({mbt_str(cs)})"
    out.append("///|")
    out.append(f"test {mbt_str(f'oracle {i}: {desc}')} {{")
    out.append(f"  let syntax = @syntax.Syntax::new({', '.join(args)})")
    for style, start, end, before in ranges or []:
        out.append(
            f"  syntax.stylize_range({mbt_str(style)}, {start}, {end}, "
            f"style_before={'true' if before else 'false'})")
    out.append(mbt_lines("expected", expected, indent="  ").rstrip())
    nw = ", no_wrap=true" if no_wrap else ""
    out.append(
        f"  assert_eq(oracle_render(syntax, width={console_args['width']}, "
        f"color_system={cs}{nw}), expected)")
    out.append("}")
    out.append("")
OUT.write_text("\n".join(out))
print(f"wrote {len(cases)} cases to {OUT}")
