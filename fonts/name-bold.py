# Give the bold file the name of the bold style of the regular family.
#
#     name-bold.py <source> <destination>
import sys

from fontTools.ttLib import TTFont

FAMILY = "MS Sans Serif"
STYLE = "Bold"

# The name table keeps one string for each of these numbers.
NAMES = {
    1: FAMILY,  # family
    2: STYLE,  # style
    3: f"{FAMILY} {STYLE}",  # identifier
    4: f"{FAMILY} {STYLE}",  # full name
    6: f"{FAMILY.replace(' ', '')}-{STYLE}",  # PostScript name
    16: FAMILY,  # typographic family
    17: STYLE,  # typographic style
}

source, destination = sys.argv[1], sys.argv[2]
font = TTFont(source)

for record in list(font["name"].names):
    text = NAMES.get(record.nameID)
    if text is not None:
        font["name"].setName(
            text, record.nameID, record.platformID, record.platEncID, record.langID
        )

for name_id in (16, 17):
    font["name"].setName(NAMES[name_id], name_id, 3, 1, 0x409)

# The three tables that tell a toolkit that the file holds a bold face.
font["OS/2"].usWeightClass = 700
font["OS/2"].fsSelection = (font["OS/2"].fsSelection & ~0x40) | 0x20
font["head"].macStyle |= 0x01

font.save(destination)
