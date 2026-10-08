"""Draw all the icons of some icon themes in a series of images.

Each image has 32 icons in each row, and 32 rows of icons at most. Each icon
is 16x16 pixels, with a margin of 1 pixel on each side. Each row of icons comes
two times: first on the background of the light scheme, then on the background
of the dark scheme. When an image is full, the next icon goes in the next
image.

The order of the icons comes from a list of names. The script keeps the order
of the old list and adds the new names at the end, in sorted order. Thus a new
icon does not move the other icons, and a visual diff shows only the changes.
A name that the themes do not hold any more keeps its cell, and the cell
stays empty.

Each scheme has its own icon theme. The script finds the file of each name in
the icon theme of the scheme and in the themes that it inherits, as GTK does
for an icon of 16 pixels at scale 1. Thus a cell can show a different file on
each background. GTK paints a symbolic SVG icon in the colors of the scheme,
and the script does the same with the style sheet of GTK.
"""

import argparse
import base64
import configparser
import io
import os
import subprocess
import sys

from PIL import Image

SIZE = 16
MARGIN = 1
CELL = SIZE + 2 * MARGIN
COLUMNS = 32
ROWS = 32
# The suffixes in the order of GTK3: in one directory, the first one wins.
# "name.symbolic.png" gives the icon "name".
EXTENSIONS = (".symbolic.png", ".png", ".svg", ".xpm")
SYMBOLIC_SUFFIXES = ("-symbolic.svg", "-symbolic-ltr.svg", "-symbolic-rtl.svg")


def read_index(theme):
    index = configparser.ConfigParser(interpolation=None, strict=False)
    index.optionxform = str
    with open(os.path.join(theme, "index.theme"), encoding="utf-8") as f:
        index.read_file(f)
    inherits = index["Icon Theme"].get("Inherits", "").split(",")
    inherits = [name.strip() for name in inherits if name.strip()]
    names = index["Icon Theme"]["Directories"].split(",")
    directories = []
    for name in filter(None, (n.strip() for n in names)):
        if name not in index:
            continue
        section = index[name]
        if int(section.get("Scale", "1")) != 1:
            continue
        size = int(section["Size"])
        directories.append(
            {
                "path": name,
                "type": section.get("Type", "Threshold"),
                "size": size,
                "min": int(section.get("MinSize", size)),
                "max": int(section.get("MaxSize", size)),
                "threshold": int(section.get("Threshold", "2")),
            }
        )
    return directories, inherits


# The two functions below come from the icon theme specification.
def matches_size(d):
    if d["type"] == "Fixed":
        return d["size"] == SIZE
    if d["type"] == "Scalable":
        return d["min"] <= SIZE <= d["max"]
    return d["size"] - d["threshold"] <= SIZE <= d["size"] + d["threshold"]


def size_distance(d):
    if d["type"] == "Fixed":
        return abs(d["size"] - SIZE)
    if d["type"] == "Scalable":
        low, high = d["min"], d["max"]
    else:
        low, high = d["size"] - d["threshold"], d["size"] + d["threshold"]
    if SIZE < low:
        return low - SIZE
    if SIZE > high:
        return SIZE - high
    return 0


def find_icons(theme):
    """Give the file of each icon name, as a lookup at 16 pixels finds it, and
    the names of the parent themes."""
    best = {}
    directories, inherits = read_index(theme)
    for order, d in enumerate(directories):
        path = os.path.join(theme, d["path"])
        if not os.path.isdir(path):
            continue
        rank = (0 if matches_size(d) else 1, size_distance(d), order)
        for entry in sorted(os.listdir(path)):
            extension = next((e for e in EXTENSIONS if entry.endswith(e)), None)
            if extension is None:
                continue
            name = entry[: -len(extension)]
            if not os.path.isfile(os.path.join(path, entry)):
                continue
            key = (rank, EXTENSIONS.index(extension))
            if name not in best or key < best[name][0]:
                best[name] = (key, os.path.join(path, entry))
    return {name: value[1] for name, value in best.items()}, inherits


class Themes:
    """The icon themes in the search path."""

    def __init__(self, search):
        self.search = search
        self.found = {}

    def get(self, name):
        if name not in self.found:
            self.found[name] = None
            for directory in self.search:
                path = os.path.join(directory, name)
                if os.path.isfile(os.path.join(path, "index.theme")):
                    self.found[name] = find_icons(path)
                    break
        return self.found[name]

    def chain(self, name):
        """Give the icons of the theme, then of its parents, depth first, then
        of hicolor. GTK looks in the themes in this order, and it takes the
        first theme that holds the name."""
        names = []

        def add(theme):
            if theme in names or self.get(theme) is None:
                return
            names.append(theme)
            for parent in self.get(theme)[1]:
                add(parent)

        add(name)
        add("hicolor")
        if name not in names:
            raise SystemExit(f"icon-sheet: no icon theme {name} in the search path")
        return [self.get(theme)[0] for theme in names]


def look_up(chain, name):
    for icons in chain:
        if name in icons:
            return icons[name]
    return None


def read_order(path):
    if not path:
        return []
    with open(path, encoding="utf-8") as f:
        return [line.strip() for line in f if line.strip()]


def symbolic_svg(data, colors):
    """Wrap the icon as GTK does before it gives the icon to librsvg."""
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n'
        '<svg version="1.1"\n'
        '     xmlns="http://www.w3.org/2000/svg"\n'
        '     xmlns:xi="http://www.w3.org/2001/XInclude"\n'
        f'     width="{SIZE}"\n'
        f'     height="{SIZE}">\n'
        '  <style type="text/css">\n'
        "    rect,circle,path {\n"
        f"      fill: {colors['fg']} !important;\n"
        "    }\n"
        "    .warning {\n"
        f"      fill: {colors['warning']} !important;\n"
        "    }\n"
        "    .error {\n"
        f"      fill: {colors['error']} !important;\n"
        "    }\n"
        "    .success {\n"
        f"      fill: {colors['success']} !important;\n"
        "    }\n"
        "  </style>\n"
        '  <xi:include href="data:text/xml;base64,'
        + base64.b64encode(data).decode("ascii")
        + '"/>\n'
        "</svg>"
    ).encode("utf-8")


def render_svg(data):
    result = subprocess.run(
        [
            "rsvg-convert",
            "--width",
            str(SIZE),
            "--height",
            str(SIZE),
            "--keep-aspect-ratio",
            "--format",
            "png",
        ],
        input=data,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.decode(errors="replace").strip())
    return Image.open(io.BytesIO(result.stdout)).convert("RGBA")


def fit(image):
    """Scale the image to 16 pixels, and put it in the middle of the cell."""
    image = image.convert("RGBA")
    if image.size != (SIZE, SIZE):
        scale = SIZE / max(image.size)
        width = max(1, round(image.width * scale))
        height = max(1, round(image.height * scale))
        image = image.resize((width, height), Image.Resampling.BILINEAR)
    cell = Image.new("RGBA", (SIZE, SIZE))
    cell.paste(image, ((SIZE - image.width) // 2, (SIZE - image.height) // 2))
    return cell


def hex_color(value):
    value = value.lstrip("#")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))


def color_symbolic_png(image, colors):
    """Paint a symbolic PNG as GTK3 does. The red, green and blue channels give
    the parts of the success, warning and error colors, and the rest of the
    pixel takes the text color. The integer arithmetic is that of GTK3, also
    for a PNG that has more color than a symbolic PNG can have."""
    fg, success, warning, error = (
        hex_color(colors[key]) for key in ("fg", "success", "warning", "error")
    )
    data = image.tobytes()
    pixels = []
    for offset in range(0, len(data), 4):
        c2, c3, c4, a = data[offset : offset + 4]
        if a == 0:
            pixels.append((0, 0, 0, 0))
        elif c2 == 0 and c3 == 0 and c4 == 0:
            pixels.append((*fg, a))
        else:
            c1 = 255 - c2 - c3 - c4
            channels = (
                (fg[i] * c1 + success[i] * c2 + warning[i] * c3 + error[i] * c4)
                % 2**32
                // 255
                % 256
                for i in range(3)
            )
            pixels.append((*channels, a))
    colored = Image.new("RGBA", image.size)
    colored.putdata(pixels)
    return colored


def render(path, colors):
    """Give the icon in the colors of one scheme."""
    if path.endswith(".symbolic.png"):
        return color_symbolic_png(fit(Image.open(path)), colors)
    if path.endswith(".svg"):
        with open(path, "rb") as f:
            data = f.read()
        if path.endswith(SYMBOLIC_SUFFIXES):
            data = symbolic_svg(data, colors)
        return fit(render_svg(data))
    return fit(Image.open(path))


def scheme(value):
    keys = ("theme", "bg", "fg", "warning", "error", "success")
    colors = value.split(",")
    if len(colors) != len(keys):
        raise argparse.ArgumentTypeError(
            "give the scheme as theme,bg,fg,warning,error,success"
        )
    return dict(zip(keys, colors))


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--search",
        action="append",
        required=True,
        help="a directory that holds icon themes, as share/icons",
    )
    parser.add_argument(
        "--names",
        action="append",
        required=True,
        help="an icon theme that gives names to the sheets",
    )
    parser.add_argument("--order", help="the old list of names, if there is one")
    parser.add_argument("--light", type=scheme, required=True)
    parser.add_argument("--dark", type=scheme, required=True)
    parser.add_argument(
        "--out-prefix", required=True, help="the sheets are <prefix>-01.png and on"
    )
    parser.add_argument("--out-txt", required=True)
    args = parser.parse_args()

    themes = Themes(args.search)
    names = set()
    for theme in args.names:
        if themes.get(theme) is None:
            raise SystemExit(f"icon-sheet: no icon theme {theme} in the search path")
        names.update(themes.get(theme)[0])
    schemes = (args.light, args.dark)
    chains = [themes.chain(colors["theme"]) for colors in schemes]

    order = read_order(args.order)
    known = set(order)
    order += sorted(name for name in names if name not in known)
    files = {}
    for name in order:
        found = [look_up(chain, name) for chain in chains]
        if None not in found:
            files[name] = found
    missing = [name for name in order if name not in files]
    differ = sum(1 for found in files.values() if found[0] != found[1])

    failed = []
    per_page = ROWS * COLUMNS
    for page in range((len(order) + per_page - 1) // per_page):
        page_names = order[page * per_page : (page + 1) * per_page]
        rows = (len(page_names) + COLUMNS - 1) // COLUMNS
        sheet = Image.new("RGBA", (COLUMNS * CELL, rows * 2 * CELL))
        for band, colors in enumerate(schemes):
            for row in range(rows):
                y = (2 * row + band) * CELL
                sheet.paste(colors["bg"], (0, y, COLUMNS * CELL, y + CELL))

        for number, name in enumerate(page_names):
            if name not in files:
                continue
            row, column = divmod(number, COLUMNS)
            for band, colors in enumerate(schemes):
                path = files[name][band]
                try:
                    icon = render(path, colors)
                except Exception as error:  # noqa: BLE001
                    failed.append(f"{path}: {error}")
                    break
                x = column * CELL + MARGIN
                y = (2 * row + band) * CELL + MARGIN
                sheet.alpha_composite(icon, (x, y))

        path = f"{args.out_prefix}-{page + 1:02d}.png"
        sheet.convert("RGB").save(path, optimize=True)
    with open(args.out_txt, "w", encoding="utf-8") as f:
        f.writelines(name + "\n" for name in order)

    theme = os.path.basename(args.out_prefix)
    print(
        f"icon-sheet: {theme}: {len(files)} icons, {len(order) - len(known)} new,"
        f" {len(missing)} names without an icon, {differ} icons with a different"
        " file on each scheme"
    )
    for name in missing:
        print(f"icon-sheet: {theme}: no icon for {name}")
    for line in failed:
        print(f"icon-sheet: {theme}: cannot render {line}", file=sys.stderr)
    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
