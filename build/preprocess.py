#!/usr/bin/env python3
"""
General-purpose fixups that bridge the gap between the book's MathJax-flavoured
markdown and what pandoc + LaTeX accept.

Design goal: every transform targets a *class* of construct (a pattern), never a
specific string from today's text. If the upstream book changes wording, these
keep working; if it introduces a brand-new construct we don't handle, the
tolerant LaTeX compile (see build.sh) degrades that spot rather than failing.

Usage: python3 preprocess.py <combined-markdown-file>
"""

import re
import sys


def escape_underscores_in_text(s: str) -> str:
    """`_` inside \\text{...} is a literal underscore (text mode) and must be
    escaped, or LaTeX raises "Missing $ inserted"."""
    return re.sub(
        r"(\\text\{)([^{}]*)(\})",
        lambda m: m.group(1) + m.group(2).replace("_", r"\_") + m.group(3),
        s,
    )


def trim_inline_math_padding(s: str) -> str:
    """pandoc only opens inline math on a `$` *not* followed by whitespace, and
    only closes on a `$` *not* preceded by whitespace. The book sometimes pads
    delimiters (`$ x $`), which makes pandoc emit a literal `\\$`. Trim the
    padding just inside paired single-`$` spans. Lookarounds skip `$$` blocks."""
    return re.sub(
        r"(?<!\$)\$(?!\$)[ \t]*(.+?)[ \t]*(?<!\$)\$(?!\$)",
        lambda m: "$" + m.group(1) + "$",
        s,
    )


def guard_bracket_after_linebreak(s: str) -> str:
    """A line that starts with `[` immediately after a `\\` line break is read by
    LaTeX as the optional length argument of `\\` (`\\[len]`) -> "Missing number".
    Insert `{}` so the `[` is plain text."""
    out, prev_breaks = [], False
    for line in s.split("\n"):
        if prev_breaks and re.match(r"^[ \t]*\[", line):
            line = re.sub(r"\[", "{}[", line, count=1)
        out.append(line)
        prev_breaks = bool(re.search(r"\\\\[ \t]*$", line))
    return "\n".join(out)


def gif_to_png(s: str) -> str:
    """LaTeX cannot embed GIFs. build.sh flattens every assets/*.gif to a .png;
    repoint the references to match."""
    return s.replace(".gif", ".png")


# Unicode glyphs the PDF fonts lack. We map them to \ensuremath{...} equivalents
# that work in both text and math mode and depend only on amssymb + xcolor (both
# already loaded). Unmapped glyphs are merely a non-fatal "Missing character"
# warning, so this list is best-effort quality, not a correctness requirement.
GLYPH_MAP = {
    "⊗": r"\ensuremath{\otimes}",
    "✅": r"\ensuremath{\textcolor{green!60!black}{\checkmark}}",
    "❌": r"\ensuremath{\textcolor{red}{\times}}",
    "🤫": "",
    **{chr(0x2080 + d): rf"\ensuremath{{{{}}_{d}}}" for d in range(10)},  # ₀-₉
}


def map_unicode_glyphs(s: str) -> str:
    for ch, repl in GLYPH_MAP.items():
        s = s.replace(ch, repl)
    return s


TRANSFORMS = [
    escape_underscores_in_text,
    trim_inline_math_padding,
    guard_bracket_after_linebreak,
    gif_to_png,
    map_unicode_glyphs,
]


def main() -> None:
    path = sys.argv[1]
    with open(path, encoding="utf-8") as f:
        s = f.read()
    for fn in TRANSFORMS:
        s = fn(s)
    with open(path, "w", encoding="utf-8") as f:
        f.write(s)
    print(f"preprocess: applied {len(TRANSFORMS)} transforms to {path}")


if __name__ == "__main__":
    main()
