"""Audiveris .omr books: staves, sheet images and text lines, OCR and alignment helpers."""

from __future__ import annotations

import math
import os
import shutil
import subprocess
import zipfile

from pathlib import Path
from xml.etree import ElementTree as ET

from omr_rules import _INK, _LYRIC_MIN_CONFIDENCE, _LYRIC_MIN_LINE_CONFIDENCE, _TESSERACT_ENV, _float


def _mean(values: list[float]) -> float:
    return sum(values) / len(values)


def _omr_staves(sheet: ET.Element) -> tuple[float, list[dict]]:
    """Interline and staves of one .omr sheet, each with its measures' heads."""
    interline = _float(sheet.find("scale/interline").get("main")) or 20.0
    chords = {chord.get("id"): chord for chord in sheet.iter("head-chord")}
    staves = []
    for system_index, system in enumerate(sheet.iter("system")):
        stacks = system.findall("stack")
        for part_index, part in enumerate(system.findall("part")):
            measures = part.findall("measure")
            for staff_index, staff in enumerate(part.findall("staff")):
                lines = staff.findall("lines/line")
                if len(lines) < 2:
                    continue
                heights = [[float(p.get("y")) for p in line.findall("point")] for line in lines]
                record = {
                    "id": staff.get("id"), "system": system_index, "part": part_index,
                    "number": staff_index + 1,
                    "top": _mean(heights[0]), "bottom": _mean(heights[-1]),
                    "left": float(staff.get("left")), "right": float(staff.get("right")),
                    "interline": interline, "measures": [],
                }
                for stack, measure in zip(stacks, measures):
                    heads = []
                    for chord_id in (measure.findtext("head-chords") or "").split():
                        chord = chords.get(chord_id)
                        bounds = chord.find("bounds") if chord is not None else None
                        if bounds is not None and chord.get("staff") == staff.get("id"):
                            heads.append(float(bounds.get("x")) + float(bounds.get("w")) / 2)
                    record["measures"].append(
                        (float(stack.get("left")), float(stack.get("right")), sorted(heads))
                    )
                staves.append(record)
    return interline, staves


def _chord_name_tops(sheet: ET.Element) -> dict[str, float]:
    tops: dict[str, float] = {}
    for sentence in sheet.iter("sentence"):
        bounds = sentence.find("bounds")
        if sentence.get("role") != "ChordName" or bounds is None:
            continue
        staff = sentence.get("staff")
        tops[staff] = min(tops.get(staff, math.inf), float(bounds.get("y")))
    return tops


def _ink_runs(rows: list[int], threshold: float, gap: float) -> list[tuple[int, int]]:
    runs: list[list[int]] = []
    for row, count in enumerate(rows):
        if count < threshold:
            continue
        if runs and row - runs[-1][1] <= gap:
            runs[-1][1] = row
        else:
            runs.append([row, row])
    return [(top, bottom) for top, bottom in runs]


def _text_bands(image, box: tuple[int, int, int, int], interline: float) -> list[tuple[int, int]]:
    """Rows of `box` that hold a line of text, as (top, bottom) page rows."""
    x0, y0, x1, y1 = box
    crop = image.crop(box)
    width = x1 - x0
    ink = crop.tobytes().translate(_INK)
    rows = [ink[row * width:(row + 1) * width].count(1) for row in range(y1 - y0)]
    threshold = max(2, width * 0.002)
    gap = max(2, interline * 0.25)
    bands = []
    for top, bottom in _ink_runs(rows, threshold, gap):
        pieces = [(top, bottom)]
        if bottom - top + 1 > interline * 4:
            # A tie or a low note under the staff can touch the lyric line;
            # keep only rows about as dense as text.
            strong = max(threshold, 0.3 * max(rows[top:bottom + 1]))
            pieces = [
                (top + a, top + b) for a, b in _ink_runs(rows[top:bottom + 1], strong, gap)
            ]
        for a, b in pieces:
            height = b - a + 1
            # Lyric type is often large next to small staves.
            if not interline * 0.5 <= height <= interline * 4:
                continue
            # Transposed, each image row is one column of the band.
            columns = crop.crop((0, a, width, b + 1)).transpose(5).tobytes().translate(_INK)
            covered = sum(1 for col in range(width) if 1 in columns[col * height:(col + 1) * height])
            if covered >= width * 0.08:
                bands.append((y0 + a, y0 + b + 1))
    return bands


def _ocr_line(tesseract: str, image, box, workdir: Path) -> list[tuple[float, str]]:
    """Hangul syllables of one text line with their page x centres."""
    from PIL import ImageOps

    # Without a white border Tesseract drops or misreads syllables when the
    # crop moves by a pixel.
    pad = 10
    target = workdir / "line.png"
    ImageOps.expand(image.crop(box), pad, fill=255).save(target)
    try:
        output = subprocess.run(
            [tesseract, str(target), "stdout", "-l", "kor", "--psm", "7",
             "-c", "tessedit_create_tsv=1"],
            capture_output=True, text=True, timeout=60, check=False, env=_TESSERACT_ENV,
        ).stdout
    except (OSError, subprocess.TimeoutExpired):
        return []
    syllables = []
    hangul = other = 0  # tokens, to tell a lyric line from note heads read as text
    confidence = 0.0
    for line in output.splitlines():
        fields = line.split("\t")
        if len(fields) < 12 or fields[0] != "5":
            continue
        text = fields[11].strip()
        if not text or _float(fields[10]) is None or float(fields[10]) < _LYRIC_MIN_CONFIDENCE:
            continue
        left, width = float(fields[6]), float(fields[8])
        found = [
            (box[0] - pad + left + width * (index + 0.5) / len(text), char)
            for index, char in enumerate(text) if "가" <= char <= "힣"
        ]
        if found:
            hangul += 1
            confidence += float(fields[10])
            syllables.extend(found)
        else:
            other += 1
    if len(syllables) < 2 or hangul < 2 * other:
        return []
    if confidence / hangul < _LYRIC_MIN_LINE_CONFIDENCE:
        return []
    return syllables


def _align(syllables: list[float], notes: list[float], penalties: list[float]) -> list[tuple[int, int]]:
    return _align_with_cost(syllables, notes, penalties)[1]


def _align_verses(lines: list[list[float]], notes: list[float], penalties: list[float],
                  interline: float) -> list[list[tuple[int, int]]]:
    """Align every verse of a staff with one shared horizontal offset.

    Charts differ in where a syllable sits against its note: centred, or
    starting at the head and so a little to its right. Matching to the
    nearest note then slips a whole line by one note, and verses slip
    differently. Try offsets up to two staff spaces and keep the one that
    fits all verses best; a small charge keeps the offset near zero.
    """
    best = None
    for step in range(-8, 9):
        shift = step * interline / 4
        total, results = 0.0, []
        for line in lines:
            # A syllable with no note within three staff spaces is left out:
            # the export lost that bar's notes, and packing the line would
            # move every other syllable off its note.
            kept = [
                i for i, x in enumerate(line)
                if notes and min(abs(x - shift - note) for note in notes) <= interline * 3
            ]
            cost, pairs = _align_with_cost([line[i] - shift for i in kept], notes, penalties)
            total += cost % 1e9 + (len(line) - len(kept)) * interline * 3
            results.append([(kept[i], j) for i, j in pairs])
        total += abs(shift) * 0.1 * sum(len(line) for line in lines)
        if best is None or total < best[0]:
            best = (total, results)
    return best[1] if best else [[] for _ in lines]


def _align_with_cost(syllables: list[float], notes: list[float], penalties: list[float],
                     skip: float = 1e9) -> tuple[float, list[tuple[int, int]]]:
    """Pair syllables with notes in order with the least total x distance.

    Only the syllables that cannot fit are left out, which happens when the
    export lost notes that the image shows. `penalties` discourage notes
    that continue a tie.
    """
    n, m = len(syllables), len(notes)
    cost = [[0.0] * (m + 1) for _ in range(n + 1)]
    move = [[1] * (m + 1) for _ in range(n + 1)]  # 1 skip note, 2 pair, 3 skip syllable
    for i in range(1, n + 1):
        cost[i][0], move[i][0] = i * skip, 3
    for i in range(1, n + 1):
        for j in range(1, m + 1):
            cost[i][j], move[i][j] = min(
                (cost[i][j - 1], 1),
                (cost[i - 1][j - 1] + abs(syllables[i - 1] - notes[j - 1]) + penalties[j - 1], 2),
                (cost[i - 1][j] + skip, 3),
            )
    pairs = []
    i, j = n, m
    while i > 0 and j > 0:
        if move[i][j] == 2:
            pairs.append((i - 1, j - 1))
            i, j = i - 1, j - 1
        elif move[i][j] == 1:
            j -= 1
        else:
            i -= 1
    return cost[n][m], pairs[::-1]


def _sung_note(note: ET.Element) -> bool:
    if note.find("rest") is not None or note.find("chord") is not None:
        return False
    return note.find("grace") is None and note.find("cue") is None


def _tied_on(note: ET.Element) -> bool:
    return any(tie.get("type") == "stop" for tie in note.findall("tie"))


def _load_book(root: ET.Element, folder: Path, ocr: bool = True) -> dict | None:
    """Tie the exported score to the pixels of the .omr book next to it.

    Returns None when OCR is needed but cannot run here, or the book and the
    score do not line up system for system; the steps that need it are then
    skipped.
    """
    languages = os.environ.get("OMR_OCR_LANGUAGES", "")
    tesseract = shutil.which("tesseract")
    books = sorted(folder.glob("*.omr"))
    if len(books) != 1:
        return None
    if ocr and ("kor" not in languages.split("+") or tesseract is None):
        return None
    try:
        from PIL import Image
    except ImportError:
        return None
    import io

    parts = root.findall("part")
    if not parts:
        return None
    # MusicXML systems, as measure indices, from the first part's layout.
    groups: list[list[int]] = []
    for index, measure in enumerate(parts[0].findall("measure")):
        layout = measure.find("print")
        if not groups or (layout is not None and "yes" in (
            layout.get("new-system"), layout.get("new-page"),
        )):
            groups.append([])
        groups[-1].append(index)
    # Per part and measure: (sheet, system, stack index, staves) or None
    # where the book and the score disagree on that system's measures.
    placements: list[list[tuple | None]] = [
        [None] * len(part.findall("measure")) for part in parts
    ]
    sheets = []
    systems = []
    try:
        with zipfile.ZipFile(books[0]) as archive:
            book = ET.fromstring(archive.read("book.xml"))
            for sheet_entry in book.findall("sheet"):
                if sheet_entry.get("invalid") == "true":
                    continue
                number = sheet_entry.get("number")
                sheet = ET.fromstring(archive.read(f"sheet#{number}/sheet#{number}.xml"))
                image = Image.open(
                    io.BytesIO(archive.read(f"sheet#{number}/BINARY.png"))
                ).convert("L")
                interline, staves = _omr_staves(sheet)
                sheets.append((number, sheet, image, interline, staves))
                for system_index, system in enumerate(sheet.iter("system")):
                    systems.append((number, system_index, system, staves))
    except (OSError, KeyError, ValueError, AttributeError, zipfile.BadZipFile, ET.ParseError):
        return None
    if len(systems) != len(groups):
        return None
    unmatched = []
    for (number, system_index, system, staves), group in zip(systems, groups):
        if len(system.findall("stack")) != len(group):
            unmatched.append((group, number, [s for s in staves if s["system"] == system_index]))
            continue
        for part_index, part in enumerate(system.findall("part")):
            # A system may hold only some of the parts; the id is the part's
            # position in the score.
            logical = part.get("id", "")
            target = int(logical) - 1 if logical.isdigit() else part_index
            if len(parts) == 1:
                # Parts split by name and merged back into one.
                target = 0
            if not 0 <= target < len(parts):
                continue
            siblings = [
                s for s in staves if s["system"] == system_index and s["part"] == part_index
            ]
            if not siblings:
                continue
            for stack_index, measure_index in enumerate(group):
                if measure_index < len(placements[target]):
                    placements[target][measure_index] = (
                        number, system_index, stack_index, siblings,
                    )

    # Page x of the notes, per staff record: sung notes snap to a note head.
    sung: dict[int, list[tuple[float, ET.Element]]] = {}
    onsets: dict[int, list[tuple[float, ET.Element]]] = {}
    staff_measures: dict[int, list[ET.Element]] = {}
    keys: dict[int, int] = {}
    for part, entries in zip(parts, placements):
        fifths = 0
        for measure, entry in zip(part.findall("measure"), entries):
            value = measure.findtext("attributes/key/fifths")
            if value and value.strip().lstrip("-").isdigit():
                fifths = int(value)
            keys[id(measure)] = fifths
            if entry is None:
                continue
            _sheet, _system, index, siblings = entry
            for staff in siblings:
                staff_measures.setdefault(id(staff), []).append(measure)
            width = _float(measure.get("width"))
            for note in measure.findall("note"):
                number = int(note.findtext("staff") or "1")
                staff = next((s for s in siblings if s["number"] == number), None)
                x = _float(note.get("default-x"))
                if staff is None or x is None or not width or note.find("chord") is not None:
                    continue
                left, right, heads = staff["measures"][index]
                guess = left + x * (right - left) / width
                onsets.setdefault(id(measure), []).append((guess, note))
                if not _sung_note(note):
                    continue
                nearest = min(heads, key=lambda head: abs(head - guess), default=None)
                if nearest is None or abs(nearest - guess) > staff["interline"] * 1.2:
                    continue
                notes = sung.setdefault(id(staff), [])
                # Voices sharing a head take one syllable, on the first voice.
                if all(head != nearest for head, _ in notes):
                    notes.append((nearest, note))
    return {
        "tesseract": tesseract, "parts": parts, "placements": placements, "sheets": sheets,
        "sung": sung, "onsets": onsets, "staff_measures": staff_measures, "keys": keys,
        "unmatched": unmatched,
    }
