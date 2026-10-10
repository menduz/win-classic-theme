"""Write one style sheet from the style sheets of the schemes of a theme.

Usage:
  merge-css.py OUT_DIR BASE_CSS [QUERY PREFIX CSS]...

The result goes to the standard output. It holds BASE_CSS, and then each CSS
in a block `@media (QUERY) { ... }`. GTK4 selects a block from the color
scheme and the contrast of the desktop, so one theme follows a change of the
scheme at run time.

The script puts the text of each `@import` in place of it, because GTK4 reads
no `@import` in an `@media` block. It writes each relative `url()` relative to
OUT_DIR, the directory of the result. It strips the comments.

GTK reads `@define-color` only outside an `@media` block. Thus the colors of a
block get PREFIX before their names, and their definitions go before the
block.
"""

import os
import re
import sys

COMMENT = re.compile(r"/\*.*?\*/", re.S)
IMPORT = re.compile(r"""@import\s+(?:url\(\s*(['"]?)(.*?)\1\s*\)|(['"])(.*?)\3)\s*;""")
URL = re.compile(r"""url\(\s*(['"]?)(.*?)\1\s*\)""")
DEFINE = re.compile(r"@define-color\s+([A-Za-z0-9_-]+)[^;]*;")
AT_RULE = re.compile(r"(?:^|[;{}])\s*@([A-Za-z-]+)")


def is_relative(ref):
    return not (ref == "" or ref.startswith("/") or re.match(r"[A-Za-z][A-Za-z0-9+.-]*:", ref))


def flatten(path, out_dir, seen=()):
    """The text of the style sheet at path, with its imports in place."""
    path = os.path.normpath(path)
    if path in seen:
        sys.exit(f"merge-css: {path} imports itself")
    with open(path, encoding="utf-8") as f:
        text = COMMENT.sub("", f.read())
    base = os.path.dirname(path)

    def rebase(match):
        quote, ref = match.group(1), match.group(2)
        if not is_relative(ref):
            return match.group(0)
        target = os.path.normpath(os.path.join(base, ref))
        return f'url("{os.path.relpath(target, out_dir)}")'

    def include(match):
        ref = match.group(2) if match.group(2) is not None else match.group(4)
        if not is_relative(ref):
            sys.exit(f"merge-css: {path}: cannot import {ref}")
        return flatten(os.path.join(base, ref), out_dir, seen + (path,))

    # The imports first: the URL of an import is relative to this file, and
    # the text that comes in has URLs relative to OUT_DIR already.
    parts = []
    last = 0
    for match in IMPORT.finditer(text):
        parts.append(URL.sub(rebase, text[last : match.start()]))
        parts.append(include(match))
        last = match.end()
    parts.append(URL.sub(rebase, text[last:]))
    return "".join(parts)


def block(text, prefix, query):
    """The text in an @media block, with the colors renamed."""
    names = set(DEFINE.findall(text))
    if names:
        alternatives = "|".join(map(re.escape, sorted(names, key=len, reverse=True)))
        # A reference "@name", and the name in "@define-color name".
        pattern = re.compile(r"(@|@define-color\s+)(" + alternatives + r")(?![A-Za-z0-9_-])")
        text = pattern.sub(lambda m: m.group(1) + prefix + m.group(2), text)
    defines = [m.group(0) for m in DEFINE.finditer(text)]
    # A definition outside the block applies to all schemes. With the name of
    # a color of BASE_CSS, it would replace that color.
    for m in DEFINE.finditer(text):
        if not m.group(1).startswith(prefix):
            sys.exit(f"merge-css: the color {m.group(1)} has no prefix {prefix}")
    rules = DEFINE.sub("", text)
    for name in AT_RULE.findall(rules):
        sys.exit(f"merge-css: @{name} cannot go into an @media block")
    return "\n".join(defines) + f"\n@media ({query}) {{\n{rules.strip()}\n}}\n"


def main(argv):
    if len(argv) < 2 or (len(argv) - 2) % 3:
        sys.exit(__doc__)
    out_dir = os.path.normpath(argv[0])
    out = [flatten(argv[1], out_dir).strip(), ""]
    rest = argv[2:]
    for i in range(0, len(rest), 3):
        query, prefix, css = rest[i : i + 3]
        out.append(block(flatten(css, out_dir), prefix, query))
    sys.stdout.write("\n".join(out))


if __name__ == "__main__":
    main(sys.argv[1:])
