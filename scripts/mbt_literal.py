"""Helpers to emit MoonBit literals from Python values (used by the
*_oracle.py / gen_*.py scripts)."""


def mbt_str(s: str) -> str:
    """A MoonBit string literal for `s`."""
    out = ['"']
    for ch in s:
        o = ord(ch)
        if ch == "\\":
            out.append("\\\\")
        elif ch == '"':
            out.append('\\"')
        elif ch == "\n":
            out.append("\\n")
        elif ch == "\r":
            out.append("\\r")
        elif ch == "\t":
            out.append("\\t")
        elif o < 0x20 or o == 0x7F or 0x80 <= o < 0xA0:
            out.append("\\u{%x}" % o)
        else:
            out.append(ch)
    out.append('"')
    return "".join(out)


def mbt_lines(name: str, s: str, indent: str = "") -> str:
    """A `let` binding for a long string, split on new lines with `+`."""
    parts = s.splitlines(keepends=True) or [""]
    if len(parts) == 1:
        return f"{indent}let {name} : String = {mbt_str(s)}\n"
    body = (" +\n" + indent + "  ").join(mbt_str(p) for p in parts)
    return f"{indent}let {name} : String = {body}\n"
