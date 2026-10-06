"""Marks read from the page images: repeat starts, segno/coda signs, D.S./D.C./Fine text."""

from __future__ import annotations

import re
import shutil
import subprocess

from pathlib import Path
from xml.etree import ElementTree as ET

from omr_rules import _TESSERACT_ENV, _float


def _heavy_bar_width(image, staff: dict, x0: float, x1: float) -> float:
    """Widest run of columns inked over the whole staff height, in interlines."""
    top, bottom = int(staff["top"]), int(staff["bottom"])
    height = bottom - top + 1
    pixels = image.load()
    best = run = 0
    for x in range(max(0, int(x0)), min(image.width, int(x1))):
        dark = sum(1 for y in range(top, bottom + 1) if pixels[x, y] < 128)
        run = run + 1 if dark >= 0.9 * height else 0
        best = max(best, run)
    return best / staff["interline"]


def _repeat_starts(book: dict) -> int:
    """Forward repeat signs read as a dotted chord at the start of a measure.

    Audiveris sometimes takes the heavy bar and the two dots of a start repeat
    after the clef for a dotted half chord. A note stem never inks the whole
    staff height half an interline wide, so a heavy bar inside the measure
    (the measure's own left barline excluded) under the chord settles it.
    """
    images = {number: image for number, _sheet, image, _interline, _staves in book["sheets"]}
    fixed = 0
    for part, entries in zip(book["parts"], book["placements"]):
        for measure, entry in zip(part.findall("measure"), entries):
            notes = [e for e in measure if e.tag == "note"]
            if entry is None or not notes or notes[0].find("pitch") is None:
                continue
            group = [notes[0]]
            for note in notes[1:]:
                if note.find("chord") is None:
                    break
                group.append(note)
            if len(group) < 2 or not all(n.find("dot") is not None for n in group):
                continue
            sheet, _system, stack, siblings = entry
            number = int(group[0].findtext("staff") or "1")
            staff = next((s for s in siblings if s["number"] == number), siblings[0])
            left, right, _heads = staff["measures"][stack]
            width, x = _float(measure.get("width")), _float(group[0].get("default-x"))
            if not width or x is None:
                continue
            interline = staff["interline"]
            guess = left + x * (right - left) / width
            start = max(left + interline, guess - 2 * interline)
            if _heavy_bar_width(images[sheet], staff, start, guess + 1.5 * interline) < 0.45:
                continue
            removed = int(group[0].findtext("duration") or "0")
            position = list(measure).index(group[0])
            for note in group:
                measure.remove(note)
            # The voice got shorter: so does the first backup that rewinds it.
            for element in list(measure)[position:]:
                if element.tag == "backup":
                    duration = element.find("duration")
                    rest = int(duration.text or "0") - removed
                    if rest > 0:
                        duration.text = str(rest)
                    else:
                        measure.remove(element)
                    break
            barline = ET.Element("barline", location="left")
            ET.SubElement(barline, "bar-style").text = "heavy-light"
            ET.SubElement(barline, "repeat", direction="forward")
            head = sum(1 for e in measure if e.tag in ("print", "attributes"))
            measure.insert(head, barline)
            fixed += 1
    return fixed


# Navigation text, longest phrase first, and what it makes the player do.
_NAVIGATION = [
    (re.compile(r"(?i)\bD\.?\s*S\.?\s*al\s*Coda\b"), "D.S. al Coda", {"dalsegno": "segno"}),
    (re.compile(r"(?i)\bD\.?\s*S\.?\s*al\s*Fine\b"), "D.S. al Fine", {"dalsegno": "segno"}),
    (re.compile(r"(?i)\bD\.?\s*C\.?\s*al\s*Coda\b"), "D.C. al Coda", {"dacapo": "yes"}),
    (re.compile(r"(?i)\bD\.?\s*C\.?\s*al\s*Fine\b"), "D.C. al Fine", {"dacapo": "yes"}),
    (re.compile(r"(?i)\bTo\s*Coda\b"), "To Coda", {"tocoda": "coda"}),
    (re.compile(r"(?i)\bD\.\s*S\.?(?=\s|$)"), "D.S.", {"dalsegno": "segno"}),
    (re.compile(r"(?i)\bD\.\s*C\.?(?=\s|$)"), "D.C.", {"dacapo": "yes"}),
    (re.compile(r"\bFine\b"), "Fine", {"fine": "yes"}),
]
_ENDING_LABEL = re.compile(r"^(\d{1,2})(?:\s*[-–~]\s*(\d{1,2}))?\.?$")
# "1.2." and "2.3.": one bracket for two passes.
_ENDING_LIST = re.compile(r"^(\d)[.,]\s*(\d)\.?$")


# Segno (U+E047) and coda (U+E048) from five SMuFL fonts (Bravura, Leland,
# Petaluma, Leipzig, Gootville), each fitted into a 20x20 square, row-major bits.
_MARK_SIZE = 20
_MARK_TEMPLATES = {
    "segno": [
        "0003007c300fc6019e6019cc01c0c01e1b00fb700ff3007f8001fe00cff00eff00d878018380339806798067900c3e00c080",
        "038100fe3018e2010e40300c0380801e1b81f9380ff1803f0008fc01cff01c9f8018780101c0300c02708067180c7f0081c0",
        "00002000040070c00f9801ff003060030c0031b003b7003f300cf801efc00d1e0030e0060600d0401b9c033f8061e0040000",
        "078180fc3019e3019e60180c01c0c01e19c1fb1c0ff1c07f8001fc038fe0399f0398780303806018067180c710187f0183c0",
        "0381007c3008e2008e600c0c00c0800e1900793803f1801f0000f8018fc01c9e019870030300203006710047300c7e0081c0",
    ],
    "coda": [
        "00200002000060001f80032c0062600e2700e2700e2707fffe1e6780e2700e2700627007260036c000f80002000020000200",
        "00400006000060001f80036c0066600e6700c6300c6301e6787fffe0c6300c6300e67006660036c001f80006000060000400",
        "00080000800008000080003e000ff001ff80309c0608c7ffff7ffff04008060080211803df001fe0007c0001000010000000",
        "006000060000f0003fc0076e0066e00e6700e6700e6703fffc3fffc0e6700e6700e670066e0076e003fc000f000060000600",
        "006000060000f0003fc0036c0076e0076e0076e00e6701fff81fff80e670076e0076e0076e0036c003fc000f000060000600",
    ],
}


def _template_bits(hexed: str) -> list[bool]:
    bits = bin(int(hexed, 16))[2:].zfill(_MARK_SIZE * _MARK_SIZE)
    return [b == "1" for b in bits]


_MARK_BITS = {kind: [_template_bits(h) for h in hexes] for kind, hexes in _MARK_TEMPLATES.items()}


def _shape_bits(image, box: tuple[int, int, int, int]) -> list[bool]:
    """Dark pixels of a page box, centred in a square and scaled to the template size."""
    from PIL import Image

    crop = image.crop(box)
    side = max(crop.width, crop.height)
    square = Image.new("L", (side, side), 255)
    square.paste(crop, ((side - crop.width) // 2, (side - crop.height) // 2))
    return [v < 160 for v in square.resize((_MARK_SIZE, _MARK_SIZE), Image.BOX).getdata()]


def _dice(a: list[bool], b: list[bool]) -> float:
    both = sum(1 for x, y in zip(a, b) if x and y)
    total = sum(a) + sum(b)
    return 2 * both / total if total else 0.0


def _dark_components(image, box: tuple[int, int, int, int]) -> list[tuple[int, int, int, int]]:
    """Bounding boxes of 8-connected dark blobs inside a page box."""
    x0, y0, x1, y1 = (max(0, box[0]), max(0, box[1]), min(image.width, box[2]), min(image.height, box[3]))
    width, height = x1 - x0, y1 - y0
    if width <= 0 or height <= 0:
        return []
    pixels = image.load()
    seen = bytearray(width * height)
    blobs = []
    for sy in range(height):
        for sx in range(width):
            if seen[sy * width + sx] or pixels[x0 + sx, y0 + sy] >= 128:
                continue
            stack = [(sx, sy)]
            seen[sy * width + sx] = 1
            left, top, right, bottom = sx, sy, sx, sy
            while stack:
                cx, cy = stack.pop()
                left, right = min(left, cx), max(right, cx)
                top, bottom = min(top, cy), max(bottom, cy)
                for nx in (cx - 1, cx, cx + 1):
                    for ny in (cy - 1, cy, cy + 1):
                        if 0 <= nx < width and 0 <= ny < height and not seen[ny * width + nx] \
                                and pixels[x0 + nx, y0 + ny] < 128:
                            seen[ny * width + nx] = 1
                            stack.append((nx, ny))
            blobs.append((x0 + left, y0 + top, x0 + right + 1, y0 + bottom + 1))
    return blobs


def _segno_coda_marks(book: dict, photos: dict | None = None, threshold: float = 0.7) -> list[dict]:
    """Segno and coda signs above each staff, found by shape.

    Audiveris misses most of them and takes rehearsal boxes for codas. Blobs
    of the right size above a staff are compared with the glyphs of five music
    fonts; a blob must match one sign clearly better than the other.
    """
    marks = []
    for number, _sheet, binary, _interline, staves in book["sheets"]:
        pages = [binary] + ([photos[number]] if photos and number in photos else [])
        for image, staff in ((image, staff) for image in pages for staff in staves):
            interline = staff["interline"]
            box = (int(staff["left"] - 4 * interline), int(staff["top"] - 9 * interline),
                   int(staff["right"]), int(staff["top"] - 0.3 * interline))
            for left, top, right, bottom in _dark_components(image, box):
                # A blob cut off at the staff (a clef or stem running into it)
                # is part of something else; signs float clear of the staff.
                if bottom >= box[3] - 1:
                    continue
                w, h = right - left, bottom - top
                if not (1.8 * interline <= h <= 5.5 * interline and 1.0 * interline <= w <= 5 * interline):
                    continue
                bits = _shape_bits(image, (left, top, right, bottom))
                scores = {kind: max(_dice(bits, t) for t in templates) for kind, templates in _MARK_BITS.items()}
                kind = max(scores, key=scores.get)
                other = min(scores.values())
                if scores[kind] >= threshold and scores[kind] - other >= 0.08:
                    x, y = (left + right) / 2, (top + bottom) / 2
                    # The photo and the binarized page often find the same sign.
                    if any(m["sheet"] == number and m["kind"] == kind and abs(m["x"] - x) < 2 * interline
                           and abs(m["y"] - y) < 2 * interline for m in marks):
                        continue
                    marks.append({"sheet": number, "staff": staff, "kind": kind, "score": round(scores[kind], 3),
                                  "x": x, "y": y, "box": (left, top, right, bottom)})
    return marks


def _add_segno_coda(book: dict, marks: list[dict]) -> list[dict]:
    """Write found signs at the start of their measures, with playback sounds.

    A sign stands over the bar line that opens its measure, often a little past
    it, so it goes to the measure whose start is nearest.
    """
    measures = book["parts"][0].findall("measure")
    added = []
    for mark in marks:
        bars = mark["staff"]["measures"]
        if not bars:
            continue
        stack = min(range(len(bars)), key=lambda i: abs(bars[i][0] - mark["x"]))
        index = next((i for i, entry in enumerate(book["placements"][0])
                      if entry and entry[0] == mark["sheet"] and entry[1] == mark["staff"]["system"]
                      and entry[2] == stack), None)
        if index is None:
            continue
        measure = measures[index]
        kind = mark["kind"]
        if measure.find(f".//direction-type/{kind}") is not None:
            continue
        direction = ET.Element("direction", placement="above")
        ET.SubElement(ET.SubElement(direction, "direction-type"), kind)
        ET.SubElement(direction, "sound", {kind: kind})
        head = sum(1 for e in measure if e.tag in ("print", "attributes")
                   or (e.tag == "barline" and e.get("location") == "left"))
        measure.insert(head, direction)
        added.append({"measureIndex": index, "measure": measure.get("number"), "sign": kind,
                      "score": mark["score"]})
    return added


def _dark_photo_image(photo, size: tuple[int, int]):
    """The photo in grey from its darkest channel, so coloured print stays dark."""
    from PIL import Image, ImageChops

    red, green, blue = photo.convert("RGB").split()
    dark = ImageChops.darker(ImageChops.darker(red, green), blue)
    return dark if dark.size == size else dark.resize(size, Image.LANCZOS)


def _pdf_photos(pdf: Path) -> list[bytes]:
    """JPEG streams of a PDF made from photos (one image per page, in order)."""
    data = pdf.read_bytes()
    photos = []
    for match in re.finditer(rb"/DCTDecode[^>]*>>\s*stream\r?\n", data):
        end = data.find(b"endstream", match.end())
        if end > 0 and data[match.end():match.end() + 3] == b"\xff\xd8\xff":
            photos.append(data[match.end():end].rstrip(b"\r\n"))
    return photos


def _upload_photos(path: Path, book: dict) -> dict:
    """Per sheet, the uploaded photo in grey from its darkest channel (coloured
    print stays dark), from an image upload or a PDF the app made of photos."""
    import io
    from PIL import Image

    upload = next((c for c in sorted((path.parent.parent.parent / "in").glob("score.*"))), None)
    if upload is None:
        return {}
    sources: dict[str, object] = {}
    sheets = book["sheets"]
    if upload.suffix.lower() in (".jpg", ".jpeg", ".png") and len(sheets) == 1:
        sources[sheets[0][0]] = upload
    elif upload.suffix.lower() == ".pdf":
        photos = _pdf_photos(upload)
        for number, *_rest in sheets:
            index = int(number) - 1 if str(number).isdigit() else -1
            if 0 <= index < len(photos):
                sources[number] = io.BytesIO(photos[index])
    result = {}
    for number, _sheet, image, _interline, _staves in sheets:
        if number not in sources:
            continue
        try:
            photo = Image.open(sources[number])
            photo.load()
        except (OSError, ValueError):
            continue
        # A photo that is not this page (another shape) would misplace marks.
        if abs(photo.width / photo.height - image.width / image.height) > 0.02:
            continue
        result[number] = _dark_photo_image(photo, image.size)
    return result


def _page_lines(tesseract: str, image, workdir: Path, label: str, scale: float = 1.0) -> list[dict]:
    """Text lines Tesseract finds anywhere on a page, with page boxes."""
    target = workdir / f"page_{label}.png"
    image.save(target)
    base = workdir / f"page_{label}"
    try:
        subprocess.run(
            [tesseract, str(target), str(base), "-l", "eng", "--psm", "11",
             "-c", "tessedit_create_tsv=1"],
            capture_output=True, text=True, timeout=180, check=False, env=_TESSERACT_ENV,
        )
        rows = base.with_suffix(".tsv").read_text(encoding="utf-8").splitlines()
    except (OSError, subprocess.TimeoutExpired):
        return []
    lines: dict[tuple, dict] = {}
    for row in rows[1:]:
        fields = row.split("\t")
        if len(fields) < 12 or not fields[11].strip():
            continue
        try:
            key = tuple(int(v) for v in fields[2:5])
            x, y, w, h = (int(v) / scale for v in fields[6:10])
            confidence = float(fields[10])
        except ValueError:
            continue
        line = lines.setdefault(key, {"words": [], "x0": x, "y0": y, "x1": x + w, "y1": y + h})
        line["words"].append((fields[11].strip(), x, y, x + w, y + h, confidence))
        line["x0"], line["y0"] = min(line["x0"], x), min(line["y0"], y)
        line["x1"], line["y1"] = max(line["x1"], x + w), max(line["y1"], y + h)
    for line in lines.values():
        line["text"] = " ".join(word[0] for word in line["words"])
    return list(lines.values())


def _place_on_staff(book: dict, sheet: str, x: float, y: float) -> int | None:
    """Measure index (first part) of the staff nearest to a page point."""
    staves = next((s for n, _s, _i, _il, s in book["sheets"] if n == sheet), [])
    if not staves:
        return None

    def distance(staff):
        return staff["top"] - y if y < staff["top"] else max(0.0, y - staff["bottom"])

    staff = min(staves, key=distance)
    if distance(staff) > staff["interline"] * 10:
        return None
    return _measure_of(book, sheet, staff, x)


def _measure_of(book: dict, sheet: str, staff: dict, x: float) -> int | None:
    """Measure index (first part) of a staff's stack under page x."""
    bars = staff["measures"]
    stack = next((i for i, (left, right, _h) in enumerate(bars)
                  if left <= x <= right + staff["interline"]), None)
    if stack is None:
        stack = len(bars) - 1 if bars and x > bars[-1][1] else 0
    for index, entry in enumerate(book["placements"][0]):
        if entry and entry[0] == sheet and entry[1] == staff["system"] and entry[2] == stack:
            return index
    return None


def _navigation_marks(book: dict, workdir: Path, photos: dict | None = None) -> dict:
    """Read D.S., D.C., To Coda and Fine and ending labels ("1-5.") off the page.

    Audiveris leaves this text out. Tesseract reads the binarized page and,
    for an image upload, the photo with colour kept dark (the darkest channel),
    since these marks are often printed or written in colour.
    """
    tesseract = book["tesseract"] or shutil.which("tesseract")
    report = {"navigation": [], "endings": []}
    if tesseract is None:
        return report
    measures = book["parts"][0].findall("measure")
    found: dict[tuple[int, str], dict] = {}
    labels: list[tuple[str, dict]] = []
    for number, _sheet, image, _interline, _staves in book["sheets"]:
        lines = _page_lines(tesseract, image, workdir, f"{number}-binary")
        if photos and number in photos:
            from PIL import Image

            dark = photos[number].resize((image.width * 2, image.height * 2), Image.LANCZOS)
            lines += _page_lines(tesseract, dark, workdir, f"{number}-colour", 2.0)
        for line in lines:
            labels += [(number, {"text": w[0], "x0": w[1], "y0": w[2], "x1": w[3], "y1": w[4]})
                       for w in line["words"]]
            text = line["text"]
            for pattern, name, sound in _NAVIGATION:
                match = pattern.search(text)
                if not match:
                    continue
                text = text[:match.start()] + " " + text[match.end():]
                index = _place_on_staff(book, number, line["x1"], (line["y0"] + line["y1"]) / 2)
                if index is not None:
                    found.setdefault((index, name), {"sound": sound, "above": None, "line": line})
    for (index, name), mark in sorted(found.items()):
        measure = measures[index]
        if any(name == " ".join("".join(w.text or "" for w in d.iter("words")).split())
               for d in measure.findall("direction")):
            continue
        direction = ET.Element("direction", placement="below" if name in ("Fine", "D.S. al Fine",
                                                                           "D.C. al Fine") else "above")
        words = ET.SubElement(ET.SubElement(direction, "direction-type"), "words")
        words.text = name
        ET.SubElement(direction, "sound", mark["sound"])
        measure.append(direction)
        report["navigation"].append({"measureIndex": index, "measure": measure.get("number"), "text": name})
    # Ending labels: the number printed at the bracket's start, above the staff.
    previous_last = None
    for index, (measure, entry) in enumerate(zip(measures, book["placements"][0])):
        ending = next((e for e in measure.iter("ending") if e.get("type") == "start"), None)
        if ending is None:
            continue
        best = None
        if entry is not None:
            sheet, _system, stack, siblings = entry
            staff = siblings[0]
            left, _right, _heads = staff["measures"][stack]
            interline = staff["interline"]
            for number, word in labels:
                match = _ENDING_LABEL.match(word["text"]) or _ENDING_LIST.match(word["text"])
                if number != sheet or not match:
                    continue
                if left - interline <= word["x0"] <= left + 5 * interline \
                        and staff["top"] - 7 * interline <= word["y0"] <= staff["top"]:
                    best = match
                    break
        numbers = None
        if best and best.group(2) and int(best.group(1)) < int(best.group(2)) <= 12:
            numbers = list(range(int(best.group(1)), int(best.group(2)) + 1))
        elif previous_last is not None and ending.get("number") == "2" and previous_last > 1:
            # "1-5." then "6.": the next bracket starts after the range.
            numbers = [previous_last + 1]
        if numbers:
            value = ",".join(str(n) for n in numbers)
            if value != ending.get("number"):
                report["endings"].append({"measureIndex": index, "measure": measure.get("number"),
                                          "before": ending.get("number"), "after": value})
                ending.set("number", value)
                ending.text = f"{numbers[0]}-{numbers[-1]}." if len(numbers) > 1 else f"{numbers[0]}."
        last_ending = ending.get("number", "").split(",")[-1]
        previous_last = int(last_ending) if last_ending.isdigit() else None
    return report


def _ending_numbers(value: str | None) -> list[int]:
    """The passes an ending is for, from its number attribute: the run that counts up
    from the first number ("1,2" is [1, 2]; "2,13" and "1,,,2,9" keep what counts up)."""
    numbers = [int(n) for n in re.findall(r"\d+", value or "")]
    out = numbers[:1]
    for number in numbers[1:]:
        if number != out[-1] + 1:
            break
        out.append(number)
    return out if out and 1 <= out[0] <= 12 else []


def _tidy_endings(root: ET.Element) -> list[dict]:
    """Make the ending brackets of each part ones a player could follow.

    The engine takes any line with a hook above the staff for an ending: the boxes around
    instrument cues ("P, HiHat only") become first endings, one bracket is cut in two, and
    the bracket after a first ending is numbered 1 again. A first ending is told apart by
    what follows it: the repeat sign at its end and the next ending right after. So

    - a bracket labelled with words is not an ending;
    - a bracket with the same number a few bars after another, or one that runs on from a
      first ending to the repeat sign, is that bracket going on;
    - endings one after another count up from the first, with the repeat sign that sends
      the first back;
    - a first ending on its own stays only where it ends at a repeat sign it did not
      begin on; otherwise it is not one.

    Returns what changed, for the correction history.
    """
    changes = []
    for part in root.findall("part"):
        measures = part.findall("measure")

        def repeats(direction: str) -> set[int]:
            return {
                index for index, measure in enumerate(measures)
                if any(r.get("direction") == direction for r in measure.findall("barline/repeat"))
            }

        backward, forward = repeats("backward"), repeats("forward")
        brackets: list[dict] = []
        for index, measure in enumerate(measures):
            for barline in measure.findall("barline"):
                ending = barline.find("ending")
                if ending is None:
                    continue
                if ending.get("type") == "start":
                    brackets.append({"start": index, "at": (measure, barline, ending), "end": None, "stop": None,
                                     "numbers": _ending_numbers(ending.get("number")),
                                     "text": (ending.text or "").strip()})
                elif brackets and brackets[-1]["end"] is None:
                    brackets[-1]["end"], brackets[-1]["stop"] = index, (measure, barline, ending)

        def take_out(place) -> None:
            if place is None:
                return
            measure, barline, ending = place
            barline.remove(ending)
            if len(barline) == 0 or (len(barline) == 1 and barline[0].tag == "bar-style"
                                     and (barline[0].text or "").strip() == "regular"):
                measure.remove(barline)

        def note(bracket: dict, after: str) -> None:
            changes.append({"measureIndex": bracket["start"], "measure": measures[bracket["start"]].get("number"),
                            "before": bracket["at"][2].get("number"), "after": after})

        def drop(bracket: dict) -> None:
            note(bracket, "")
            take_out(bracket["at"])
            take_out(bracket["stop"])

        def closed(bracket: dict, before: int) -> bool:
            return any(index in backward for index in range(bracket["start"], before))

        # Words in the bracket: a cue box, not an ending.
        for bracket in [b for b in brackets if len(re.findall(r"[^\W\d_]", b["text"])) >= 3]:
            drop(bracket)
            brackets.remove(bracket)
        # One bracket cut in two.
        position = 0
        while position + 1 < len(brackets):
            first, second = brackets[position], brackets[position + 1]
            third = brackets[position + 2] if position + 2 < len(brackets) else None
            between = range(first["start"] + 1, second["start"] + 1)
            # The same number again a few bars on, with no repeat sign in between.
            same = ((not second["numbers"] or second["numbers"][:1] == first["numbers"][:1])
                    and second["start"] - first["start"] <= 4 and not any(i in forward for i in between))
            # "1" then "2" with no repeat sign between them, the "2" ending at the repeat
            # sign the next bracket follows: the "2" is the first ending going on.
            goes_on = (first["end"] is not None and second["start"] == first["end"] + 1
                       and second["end"] is not None and second["end"] in backward
                       and third is not None and third["start"] == second["end"] + 1)
            if not closed(first, second["start"]) and (same or goes_on):
                take_out(first["stop"])
                take_out(second["at"])
                first["end"], first["stop"] = second["end"], second["stop"]
                del brackets[position + 1]
                continue
            position += 1
        # Endings one after another count up, and all but the last send the player back.
        chained: set[int] = set()
        for position in range(len(brackets) - 1):
            first, second = brackets[position], brackets[position + 1]
            adjacent = first["end"] is not None and second["start"] == first["end"] + 1
            if not adjacent:
                continue
            if position not in chained:
                size = max(1, len(first["numbers"]))
                first["wanted"] = list(range(1, size + 1))
            chained.update((position, position + 1))
            start = first.get("wanted", first["numbers"])[-1] + 1
            second["wanted"] = list(range(start, start + max(1, len(second["numbers"]))))
            if first["end"] not in backward:
                measure = measures[first["end"]]
                barline = next((b for b in measure.findall("barline") if b.get("location") == "right"), None)
                if barline is None:
                    barline = ET.SubElement(measure, "barline", location="right")
                    ET.SubElement(barline, "bar-style").text = "light-heavy"
                ET.SubElement(barline, "repeat", direction="backward")
                backward.add(first["end"])
                changes.append({"measureIndex": first["end"], "measure": measure.get("number"),
                                "before": "", "after": "repeat"})
        for position, bracket in enumerate(brackets):
            if position in chained:
                continue
            if bracket["numbers"][:1] in ([], [1]):
                real = (bracket["end"] is not None and bracket["end"] in backward
                        and bracket["start"] not in forward)
                if not real:
                    drop(bracket)
                    continue
            bracket["wanted"] = bracket["numbers"] or [1]
        for bracket in brackets:
            wanted = bracket.get("wanted")
            if not wanted:
                continue
            value = ",".join(str(n) for n in wanted)
            ending = bracket["at"][2]
            if ending.get("number") != value:
                note(bracket, value)
                ending.set("number", value)
                if re.fullmatch(r"[\d.,\s–~-]*", bracket["text"]):
                    ending.text = f"{wanted[0]}-{wanted[-1]}." if len(wanted) > 2 else "".join(f"{n}." for n in wanted)
            if bracket["stop"] is not None:
                bracket["stop"][2].set("number", value)
    return changes
