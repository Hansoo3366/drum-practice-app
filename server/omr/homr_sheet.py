"""Reads one page with homr: its bars and notes as MusicXML, and where on the page it saw
the staves and their barlines.

    <python of homr's environment> homr_sheet.py <page image>

Writes <page>.musicxml and <page>.json next to the image. Run by omr_hybrid, in homr's own
Python environment (OMR_HOMR_PYTHON): homr and what it needs are not installed in the
server's. homr is a separate program (AGPL-3.0, https://github.com/liebharc/homr), used as
it is published."""
import json
import os
import sys

import homr.main as reader
from homr.music_xml_generator import XmlGeneratorArguments

seen = {}
_detect_bar_lines = reader.detect_bar_lines
_detect_staffs_in_image = reader.detect_staffs_in_image


def _bar_lines(*args, **kwargs):
    seen["bars"] = _detect_bar_lines(*args, **kwargs)
    return seen["bars"]


def _staffs(*args, **kwargs):
    found = _detect_staffs_in_image(*args, **kwargs)
    seen["staffs"], seen["image"] = found[0], found[1]
    return found


def main(image: str) -> None:
    reader.detect_bar_lines = _bar_lines
    reader.detect_staffs_in_image = _staffs
    reader.ort.set_default_logger_severity(3)
    reader.download_weights(False, False, False)
    # No debug files, no cache, the whole page, on the processor.
    config = reader.ProcessingConfig(False, False, False, False, -1, False, False, False)
    reader.process_image(image, config, XmlGeneratorArguments(False, None, None))
    staffs = sorted((staff for group in seen.get("staffs") or [] for staff in group.staffs),
                    key=lambda staff: staff.min_y)
    out = []
    for staff in staffs:
        height = staff.max_y - staff.min_y
        reach = max(1.0, staff.max_x - staff.min_x)
        along = []
        for bar in seen.get("bars") or []:
            (x, y), _size, _angle = bar.box
            if (staff.min_y - height * 0.5 <= y <= staff.max_y + height * 0.5
                    and staff.min_x - 20 <= x <= staff.max_x + 20):
                along.append((float(x) - staff.min_x) / reach)
        out.append({"x1": float(staff.min_x), "x2": float(staff.max_x), "y1": float(staff.min_y),
                    "y2": float(staff.max_y), "bars": sorted(along)})
    shape = seen["image"].shape
    stem = os.path.splitext(image)[0]
    with open(stem + ".json", "w", encoding="utf-8") as target:
        json.dump({"image": [int(shape[1]), int(shape[0])], "staffs": out}, target)
    teaser = stem + "_teaser.png"
    if os.path.exists(teaser):
        os.remove(teaser)


if __name__ == "__main__":
    main(sys.argv[1])
