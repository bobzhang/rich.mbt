"""Differential data for the markdown package: markdown/corpus_data_test.mbt.

Run with the Python oracle (upstream Rich + markdown-it-py):

    /Users/dii/git/rich.mbt/.venv/bin/python scripts/markdown_oracle.py

It records, for every CommonMark spec example and a hand-written corpus,
the flattened markdown-it token stream Rich walks, and for the corpus (and
the spec examples) the rendered output at several widths / options.

Until the `syntax` package is available, code blocks are rendered by the
markdown package's plain fallback (see markdown/code_hook.mbt); pass
`--syntax` to record real `Syntax` output instead.
"""

from __future__ import annotations

import io
import re
import sys
from pathlib import Path

from markdown_it import MarkdownIt

from rich.console import Console
from rich.markdown import CodeBlock, Markdown
from rich.padding import Padding
from rich.text import Text

ROOT = Path(__file__).resolve().parent.parent
SPEC = ROOT / ".mooncakes/moonbit-community/cmark/src/data/test/spec.md"
OUT = ROOT / "markdown/corpus_data_test.mbt"

USE_SYNTAX = "--syntax" in sys.argv

if not USE_SYNTAX:

    def _fallback(self, console, options):  # mirrors markdown/code_hook.mbt
        code = str(self.text).rstrip()
        yield Padding(Text(code), 1, style="markdown.code_block")

    CodeBlock.__rich_console__ = _fallback


PARSER = MarkdownIt().enable("strikethrough").enable("table")
_FLATTEN = Markdown("")._flatten_tokens


def esc(s: str) -> str:
    return s.replace("\\", "\\\\").replace("\n", "\\n").replace("\t", "\\t")


def dump_tokens(markup: str) -> str:
    lines = []
    for t in _FLATTEN(PARSER.parse(markup)):
        attrs = {}
        for key in ("href", "src", "start", "style"):
            if key in (t.attrs or {}):
                attrs[key] = str(t.attrs[key])
        attr_s = ";".join(f"{k}={esc(attrs[k])}" for k in sorted(attrs))
        info = t.info if t.type == "fence" else ""
        lines.append(
            f"{t.type}\t{t.tag}\t{t.nesting}\t{esc(t.content)}\t{attr_s}\t{esc(info)}"
        )
    return "\n".join(lines)


RE_LINK_IDS = re.compile(r"id=[\d\.\-]*?;.*?\x1b")


def render(markup: str, width: int, hyperlinks: bool, justify, style) -> str:
    console = Console(
        width=width,
        file=io.StringIO(),
        color_system="truecolor",
        force_terminal=True,
        legacy_windows=False,
        _environ={},
    )
    kwargs = {"hyperlinks": hyperlinks}
    if justify is not None:
        kwargs["justify"] = justify
    if style is not None:
        kwargs["style"] = style
    console.print(Markdown(markup, **kwargs))
    return RE_LINK_IDS.sub("id=0;foo\x1b", console.file.getvalue())


def spec_examples() -> list[str]:
    text = SPEC.read_text(encoding="utf-8")
    fence = "`" * 32
    out = []
    for m in re.finditer(
        "^" + fence + r" example\n(.*?)^\.\n(.*?)^" + fence + "$",
        text,
        flags=re.M | re.S,
    ):
        out.append(m.group(1).replace("\u2192", "\t"))
    return out


CORPUS = [
    # headings
    "# H1\n## H2\n### H3\n#### H4\n##### H5\n###### H6",
    "Setext one\n===\n\nSetext two\n---",
    "# Heading with *emphasis* and `code`\n\nText after.",
    "#\n\n# \n\nempty headings above",
    "### closing hashes ###\n\n#hashtag is not a heading",
    # paragraphs and wrapping
    "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor "
    "incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis "
    "nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.",
    "First paragraph\nwith a soft break.\n\nSecond paragraph  \nwith a hard break.\\\nAnd a backslash break.",
    "Supercalifragilisticexpialidocious-is-a-very-long-word-that-must-be-folded-somewhere-in-the-output",
    "中文字符的宽度是二，日本語の文字も同じです。한국어도 마찬가지입니다。" * 2,
    # emphasis
    "*em* _em_ **strong** __strong__ ***both*** *__mixed__*",
    "**bold with *nested em* inside** and *em with **nested strong** inside*",
    "snake_case_word and 2*3*4 and * not em *",
    "*unclosed em and **unclosed strong",
    # strikethrough
    "~~struck~~ and ~single~ and ~~~triple~~~ and ~~~~quad~~~~",
    "~~*em in strike*~~ and *~~strike in em~~* and **~~both~~**",
    "a~~b~~c and ~~ spaced ~~ and \\~~escaped~~ and `~~code~~`",
    "~~unclosed strike and ~~another~~",
    "~~strike across\nlines~~ end",
    # code
    "Inline `code` and ``code with ` backtick`` and ` padded `.",
    "```\nplain fence\n```",
    "```python\ndef f(x):\n    return x * 2\n```",
    "``` python extra words\nprint(1)\n```",
    "~~~ruby\nputs 1\n~~~",
    "    indented code\n    second line\n\n    after blank",
    "```\nunclosed fence\n\nstill code",
    "Paragraph\n\n```js\nconsole.log('a very long line of code that will need to wrap at narrow widths, yes indeed');\n```\n\nAfter",
    # links and images
    "An [inline link](http://example.com) and [with title](http://example.com \"Title\").",
    "[Reference link][ref] and [collapsed][] and [shortcut].\n\n[ref]: http://example.com/ref\n[collapsed]: /collapsed\n[shortcut]: <http://example.com/short cut>",
    "Autolinks: <http://example.com/path?q=1> and <user@example.com> and <https://例子.测试/路径>.",
    "[*emphasis* and `code` in link](https://example.com/é)",
    "[link with ~~strike~~](http://x.com)",
    "![alt text](https://example.com/images/picture.png)",
    "![](https://example.com/images/empty-alt.png)",
    "![alt *with* markup](/local/path/) after image",
    "[![image in link](http://img.com/i.png)](http://link.com)",
    "Text before ![inline image](i.png) text after.",
    "[javascript link](javascript:alert(1)) and <javascript:alert(1)>",
    "[link](</with spaces>) and [link](foo\\_bar) and [link](a&amp;b)",
    # html
    "Press <kbd>Ctrl</kbd>+<kbd>C</kbd> to copy. <b>bold html</b> is ignored.",
    "<div>\nhtml block\n</div>\n\nparagraph after html",
    "<!-- comment -->\n\ntext",
    # block quotes
    "> Quote line one\n> quote line two\n>\n> Second paragraph",
    "> Outer\n>\n> > Inner quote\n> > continues\n>\n> back to outer",
    "> - list in quote\n> - second item\n>\n> ```\n> code in quote\n> ```",
    "> lazy\ncontinuation",
    # lists
    "* apples\n* oranges\n* pears",
    "- one\n- two\n\n- loose three",
    "1. first\n2. second\n3. third",
    "5. five\n6. six\n7. seven\n8. eight\n9. nine\n10. ten\n11. eleven",
    "0. zero start\n1. one",
    "99. ninety-nine\n100. hundred",
    "- level 1\n  - level 2\n    - level 3\n      - level 4\n  - back to 2\n- back to 1",
    "1. ordered\n   - bullet inside\n   - another\n2. second ordered\n   1. nested ordered\n   2. more",
    "- item with paragraph\n\n  second paragraph in item\n\n- next item",
    "- item\n\n      indented code in item\n\n- next",
    "-\n- empty first item",
    "+ plus\n+ list\n\n* star\n* list",
    "1) paren\n2) list",
    "- A long list item that definitely needs to wrap when the console is narrow, because it is long.",
    "- [ ] task looking item\n- [x] checked looking item",
    "- quote in list:\n  > quoted\n  > text",
    # horizontal rules
    "Above\n\n---\n\nBelow\n\n***\n\n___",
    "---\n# Heading after rule",
    "* * *\n- - -",
    # tables
    "| a | b |\n|---|---|\n| 1 | 2 |",
    "| Left | Center | Right | None |\n|:-----|:------:|------:|------|\n| l | c | r | n |\n| longer left | longer center | longer right | x |",
    "a | b\n--|--\n1 | 2",
    "| a | b |\n| - | - |\n| only one |\n| x | y | z |",
    "| a |\n|---|\n|   |\n| x |",
    "| escaped \\| pipe | `code \\| pipe` |\n|---|---|\n| *em* | **strong** |",
    "Paragraph before\n| a | b |\n|---|---|\n| 1 | 2 |\nmore row text",
    "| a | b |\n|---|---|\n| 1 | 2 |\n\nParagraph after table",
    "> | quoted | table |\n> |---|---|\n> | 1 | 2 |",
    "- | table | in list |\n  |---|---|\n  | 1 | 2 |",
    "| header only |\n|---|",
    "| a | b |\n|---|---|\n| [link](http://e.com) | ![img](i.png) |",
    "| a | b |\n|---|---|\n| 1 | 2 |\n- list ends table",
    "| a | b |\n|---|---|\n| 1 | 2 |\n# heading ends table",
    "|a|b|\n|-|-|\n|~~s~~|<kbd>k</kbd>|",
    "| not | a table |\n| -- | -- | -- |",
    "| a | b |\n|---|---|\n| 1 | 2 |\n---",
    "Title | Value\n:--- | ---:\nα | 1\nβ | 22",
    # entities, escapes
    "&amp; &lt; &gt; &quot; &copy; &#35; &#x1F600; &nbsp;x &unknown;",
    "\\*not em\\* \\# not heading \\[not link\\]",
    # mixed document
    "# Title\n\nSome *text* with a [link](http://example.com).\n\n> A quote\n\n- item 1\n- item 2\n\n1. one\n2. two\n\n---\n\n| x | y |\n|---|---|\n| 1 | 2 |\n\n```\ncode\n```\n\nEnd.",
]

OPTIONS = [
    (40, True, None, None),
    (80, True, None, None),
    (120, False, None, None),
    (80, False, None, None),
]

EXTRA_RENDER = [
    # (markup, width, hyperlinks, justify, style)
    ("Justified paragraph text that is long enough to wrap over several lines of output.", 30, True, "full", None),
    ("Centered paragraph text that wraps.\n\n# Heading\n\n- item", 30, True, "center", None),
    ("Right aligned text that wraps around.", 30, True, "right", None),
    ("Styled *markdown* with a [link](http://e.com)\n\n> quote", 40, True, None, "bold red"),
    ("Styled on background\n\n- item\n\n```\ncode\n```", 40, True, None, "on blue"),
]


def mbt_str(s: str) -> str:
    out = ['"']
    for ch in s:
        o = ord(ch)
        if ch == "\\":
            out.append("\\\\")
        elif ch == '"':
            out.append('\\"')
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


def mbt_opt(s):
    return "None" if s is None else f"Some({mbt_str(s)})"


def main() -> None:
    spec = spec_examples()
    out = [
        "// Generated by scripts/markdown_oracle.py. DO NOT EDIT.",
        f"// Code blocks rendered with {'Syntax' if USE_SYNTAX else 'the plain fallback'}.",
        "",
        "///|",
        "/// CommonMark spec examples: (markdown, markdown-it token dump).",
        "let spec_token_cases : Array[(String, String)] = [",
    ]
    for ex in spec:
        out.append(f"  ({mbt_str(ex)}, {mbt_str(dump_tokens(ex))}),")
    out += [
        "]",
        "",
        "///|",
        "/// Hand-written corpus: (markdown, markdown-it token dump).",
        "let corpus_token_cases : Array[(String, String)] = [",
    ]
    for ex in CORPUS:
        out.append(f"  ({mbt_str(ex)}, {mbt_str(dump_tokens(ex))}),")
    out += [
        "]",
        "",
        "///|",
        "/// Rendered output: (markdown, width, hyperlinks, justify, style, output).",
        "let render_cases : Array[(String, Int, Bool, String?, String?, String)] = [",
    ]
    cases = []
    for ex in CORPUS:
        for width, hyperlinks, justify, style in OPTIONS:
            cases.append((ex, width, hyperlinks, justify, style))
    cases += EXTRA_RENDER
    for ex in spec:
        cases.append((ex, 80, True, None, None))
    for ex, width, hyperlinks, justify, style in cases:
        try:
            rendered = render(ex, width, hyperlinks, justify, style)
        except Exception as error:  # upstream crashes on some inputs
            print(f"skipping {ex!r}: {error!r}", file=sys.stderr)
            continue
        out.append(
            f"  ({mbt_str(ex)}, {width}, {'true' if hyperlinks else 'false'}, "
            f"{mbt_opt(justify)}, {mbt_opt(style)}, {mbt_str(rendered)}),"
        )
    out.append("]")
    OUT.write_text("\n".join(out) + "\n", encoding="utf-8")
    print(f"wrote {OUT} ({len(spec)} spec examples, {len(CORPUS)} corpus, {len(cases)} renders)")


if __name__ == "__main__":
    main()
