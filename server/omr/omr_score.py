"""MusicXML files: read and write .mxl/.musicxml, merge Audiveris movements."""

from __future__ import annotations

import re
import zipfile

from pathlib import Path
from xml.etree import ElementTree as ET


PIPELINE = "pdf-multipass-v1"


_MOVEMENT = re.compile(r"^(?P<base>.+)\.mvt(?P<number>\d+)\.(?:mxl|xml|musicxml)$", re.IGNORECASE)


def _find_score(folder: Path) -> Path | None:
    files = sorted(folder.glob("*.mxl"))
    if not files:
        files = sorted(folder.glob("*.xml")) + sorted(folder.glob("*.musicxml"))
    files = [
        path for path in files
        if path.name.lower() != "container.xml"
        and ".merged." not in path.name and ".fixed." not in path.name
    ]
    if len(files) <= 1:
        return files[0] if files else None
    movements = [_MOVEMENT.match(path.name) for path in files]
    if all(movements) and len({match["base"] for match in movements}) == 1:
        # Audiveris splits one page into movements when a system starts
        # without a time signature or with an indent. It is still one song.
        ordered = [path for _, path in sorted(
            zip((int(match["number"]) for match in movements), files),
        )]
        return _merge_movements(ordered, folder / f"{movements[0]['base']}.merged.mxl")
    raise ValueError("Multiple exported scores; refusing to return only the first movement")


def _merge_movements(paths: list[Path], target: Path) -> Path:
    """Append the measures of each movement to the first, part by part."""
    base = _read_score(paths[0])
    base_parts = base.findall("part")
    for path in paths[1:]:
        parts = _read_score(path).findall("part")
        if len(parts) != len(base_parts):
            raise ValueError("Movements have different parts; refusing to merge")
        for into, part in zip(base_parts, parts):
            into.extend(part.findall("measure"))
    for part in base_parts:
        number = 1
        for measure in part.findall("measure"):
            if measure.get("implicit") == "yes" and number == 1:
                measure.set("number", "0")
                continue
            measure.set("number", str(number))
            number += 1
    return _write_mxl(base, target)


def _write_mxl(root: ET.Element, target: Path) -> Path:
    xml = ET.tostring(root, encoding="unicode")
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as archive:
        archive.writestr(
            "META-INF/container.xml",
            '<?xml version="1.0" encoding="UTF-8"?>'
            '<container><rootfiles><rootfile full-path="score.xml" '
            'media-type="application/vnd.recordare.musicxml+xml"/>'
            '</rootfiles></container>',
        )
        archive.writestr("score.xml", '<?xml version="1.0" encoding="UTF-8"?>\n' + xml)
    return target


def _read_score(path: Path) -> ET.Element:
    if path.suffix.lower() == ".mxl":
        with zipfile.ZipFile(path) as archive:
            container = ET.fromstring(archive.read("META-INF/container.xml"))
            entries = [node for node in container.iter() if node.tag.rsplit("}", 1)[-1] == "rootfile"]
            if not entries or not entries[0].get("full-path"):
                raise ValueError("MXL rootfile is missing")
            info = archive.getinfo(entries[0].get("full-path"))
            if info.file_size > 64 * 1024 * 1024:
                raise ValueError("MusicXML is too large to inspect")
            root = ET.fromstring(archive.read(info))
    else:
        if path.stat().st_size > 64 * 1024 * 1024:
            raise ValueError("MusicXML is too large to inspect")
        root = ET.fromstring(path.read_bytes())
    for node in root.iter():
        node.tag = node.tag.rsplit("}", 1)[-1]
    if root.tag != "score-partwise":
        raise ValueError("Expected score-partwise MusicXML")
    return root
