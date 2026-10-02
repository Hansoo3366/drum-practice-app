"""Lyrics and chord symbols re-read from the page images."""

from __future__ import annotations

import math
import re
import subprocess

from pathlib import Path
from xml.etree import ElementTree as ET

from omr_rules import _CHORD_KINDS, _LYRIC_MAX_BANDS, _TESSERACT_ENV, _chord_suffix, _harmony_element, _insert_lyric, _key_alter, _parse_chord_text
from omr_book import _align_verses, _chord_name_tops, _ocr_line, _text_bands, _tied_on


def _ocr_lyrics(book: dict, workdir: Path) -> dict:
    """Replace lyrics with a line-by-line OCR of the sheet images."""
    tesseract, sung = book["tesseract"], book["sung"]
    bands = 0
    placed_by_staff: dict[tuple, list[tuple[ET.Element, ET.Element]]] = {}
    systems_by_staff: dict[tuple, int] = {}
    for number, sheet, image, interline, staves in book["sheets"]:
        chord_tops = _chord_name_tops(sheet)
        ordered = sorted(staves, key=lambda s: s["top"])
        for position, staff in enumerate(ordered):
            notes = sorted(sung.get(id(staff), []), key=lambda item: item[0])
            if not notes:
                continue
            if position + 1 < len(ordered):
                below = ordered[position + 1]
                limit = min(below["top"] - interline * 0.5,
                            chord_tops.get(below["id"], math.inf) - interline * 0.2)
            else:
                limit = min(image.height, staff["bottom"] + interline * 10)
            box = (int(staff["left"]), int(staff["bottom"] + interline * 0.5),
                   int(staff["right"]), int(limit))
            if box[3] - box[1] < interline:
                continue
            lines = []
            for top, bottom in _text_bands(image, box, interline):
                if bands >= _LYRIC_MAX_BANDS:
                    break
                bands += 1
                line_box = (
                    max(0, int(staff["left"] - interline)), max(0, int(top - interline * 0.3)),
                    min(image.width, int(staff["right"] + interline)),
                    min(image.height, int(bottom + interline * 0.3)),
                )
                syllables = [
                    (x, text) for x, text in _ocr_line(tesseract, image, line_box, workdir)
                    if notes[0][0] - interline * 2 <= x <= notes[-1][0] + interline * 2
                ]
                if syllables:
                    lines.append(syllables)
            aligned = _align_verses(
                [[x for x, _ in line] for line in lines], [x for x, _ in notes],
                [interline if _tied_on(note) else 0.0 for _, note in notes], interline,
            )
            verses = [
                [(notes[j][1], line[i][1]) for i, j in pairs]
                for line, pairs in zip(lines, aligned)
                # Far more syllables than notes: not this staff's lyrics.
                if len(pairs) >= max(2, 0.6 * len(line))
            ]
            if not verses:
                continue
            for measure in book["staff_measures"].get(id(staff), []):
                for note in measure.findall("note"):
                    if int(note.findtext("staff") or "1") == staff["number"]:
                        for lyric in note.findall("lyric"):
                            note.remove(lyric)
            key = (staff["part"], staff["number"])
            for verse, assignments in enumerate(verses, start=1):
                for note, text in assignments:
                    lyric = ET.Element("lyric", number=str(verse))
                    ET.SubElement(lyric, "syllabic").text = "single"
                    ET.SubElement(lyric, "text").text = text
                    _insert_lyric(note, lyric)
                    placed_by_staff.setdefault(key, []).append((note, lyric))
            systems_by_staff[key] = systems_by_staff.get(key, 0) + 1
    # Lyrics belong to the singer's staff. In a vocal and piano score, notes
    # with ledger lines under the piano read as Hangul on a few systems; drop
    # lyrics of a staff that got them on under a quarter as many systems as
    # the staff with the most.
    most = max(systems_by_staff.values(), default=0)
    for key, count in systems_by_staff.items():
        if count < most * 0.25:
            for note, lyric in placed_by_staff.pop(key):
                note.remove(lyric)
    placed = sum(len(items) for items in placed_by_staff.values())
    removed = _drop_lyric_words(book["parts"])
    return {"syllables": placed, "bands": bands, "words_removed": removed}


# Chord letters survive an English-only read; a printed sharp then comes
# back as "j" or "i", which no chord suffix starts with.
_CHORD_WHITELIST = "ABCDEFGMmajdinsuo0123456789#b/()+-"


def _parse_reread_chord(text: str, fifths: int, fill_root: bool = True,
                        fill_bass: bool = True) -> dict | None:
    # "4" before a suffix letter is a sharp too ("F4m"); "sus4" is unaffected.
    # "E(sus4)" and "E<sus4>" print the suffix in brackets.
    text = re.sub(r"[(<]([^()<>]*)[)>]$", r"\1", text)
    # Some charts print the bass in lower case ("F/a").
    match = re.fullmatch(r"([A-G])([ji#b]|4(?=[a-z]))?([^/]*)(?:/([A-Ga-g])([ji#b]?))?", text)
    if not match:
        return None
    step, accidental, rest, bass, bass_accidental = match.groups()
    accidental = accidental or ""
    bass = bass.upper() if bass else bass
    if accidental == "b" and _chord_suffix(rest) is None and _chord_suffix("b" + rest) is not None:
        accidental, rest = "", "b" + rest
    suffix = _chord_suffix(rest)
    if suffix is None:
        return None

    def alter(letter: str, sign: str, fill: bool) -> int:
        # OCR often loses a printed sharp or flat. Where the caller has seen
        # a sign that was not read, it follows the key.
        if sign == "b":
            return -1
        if sign:
            return 1
        return _key_alter(letter, fifths) if fill else 0

    return {
        "step": step, "alter": alter(step, accidental, fill_root), "suffix": suffix,
        "bass": bass, "bass_alter": alter(bass, bass_accidental, fill_bass) if bass else 0,
    }


def _ocr_chord_text(tesseract: str, image, box, workdir: Path, psm: str, tsv: bool = False) -> str:
    from PIL import ImageOps

    x, y, w, h = box
    target = workdir / "chord.png"
    ImageOps.expand(
        image.crop((int(x) - 4, int(y) - 4, int(x + w) + 4, int(y + h) + 4)), 10, fill=255,
    ).save(target)
    command = [tesseract, str(target), "stdout", "-l", "eng", "--psm", psm,
               "-c", f"tessedit_char_whitelist={_CHORD_WHITELIST}"]
    if tsv:
        command += ["-c", "tessedit_create_tsv=1"]
    try:
        return subprocess.run(
            command, capture_output=True, text=True, timeout=60, check=False, env=_TESSERACT_ENV,
        ).stdout.strip()
    except (OSError, subprocess.TimeoutExpired):
        return ""


def _harmony_anchor(measure: ET.Element, harmony: ET.Element) -> ET.Element | None:
    children = list(measure)
    following = children[children.index(harmony) + 1:]
    return next((c for c in following if c.tag == "note" and c.find("chord") is None), None)


def _harmony_name(harmony: ET.Element) -> str:
    return "|".join((
        harmony.findtext("root/root-step") or "", harmony.findtext("root/root-alter") or "0",
        harmony.findtext("kind") or "", harmony.findtext("bass/bass-step") or "",
        harmony.findtext("bass/bass-alter") or "0",
    ))


def _add_missing_signs(existing: ET.Element, read: ET.Element) -> None:
    """Give a chord the sharp or flat a closer read of the same letters saw.

    Audiveris keeps "B" where the chart prints "B♭" in a hand-drawn font;
    the line read, which checks for a sign's trace, finds the flat.
    """
    for element, step, alter in (("root", "root-step", "root-alter"), ("bass", "bass-step", "bass-alter")):
        mine, theirs = existing.find(element), read.find(element)
        if mine is None or theirs is None or mine.findtext(step) != theirs.findtext(step):
            continue
        if (mine.findtext(alter) or "0").strip() in ("", "0") and (theirs.findtext(alter) or "0") != "0":
            node = mine.find(alter)
            if node is None:
                node = ET.Element(alter)
                mine.insert(list(mine).index(mine.find(step)) + 1, node)
            node.text = theirs.findtext(alter)


def _place_harmony(book: dict, measure: ET.Element, x: float, interline: float,
                   harmony: ET.Element) -> bool:
    """Insert `harmony` before the note under page x, once per note."""
    harmony.attrib.pop("default-x", None)
    harmony.attrib.pop("relative-x", None)
    notes = book["onsets"].get(id(measure), [])
    anchor = min(notes, key=lambda item: abs(item[0] - x - interline * 0.5), default=None)
    if anchor is None:
        return False
    # Voices are written one after the other, so compare page positions, not
    # document order, with the chords already there. The same chord read
    # twice lands a note or two apart, so it counts within a wider reach.
    position = {id(note): px for px, note in notes}
    for existing in measure.findall("harmony"):
        other = _harmony_anchor(measure, existing)
        distance = abs(position.get(id(other), math.inf) - anchor[0]) if other is not None else math.inf
        same = _harmony_name(existing) == _harmony_name(harmony)
        if distance < interline * (5 if same else 2):
            if distance < interline * 2:
                _add_missing_signs(existing, harmony)
            return False
    measure.insert(list(measure).index(anchor[1]), harmony)
    return True


def _split_chord_tokens(text: str) -> list[tuple[int, str]]:
    """Split glued chords ("Bsus4B") at each new root, with char offsets."""
    starts = [0] + [
        i for i in range(1, len(text))
        if text[i] in "ABCDEFG" and text[i - 1] != "/"
    ]
    return [(a, text[a:b]) for a, b in zip(starts, starts[1:] + [len(text)])]


def _chord_chars(tesseract: str, image, box, workdir: Path) -> list[tuple[str, float, float, float]]:
    """Characters of a chord line with page x0, x1 and height, left to right."""
    from PIL import ImageOps

    x, y, w, h = box
    target = workdir / "chord_line.png"
    ImageOps.expand(
        image.crop((int(x) - 4, int(y) - 4, int(x + w) + 4, int(y + h) + 4)), 10, fill=255,
    ).save(target)
    base = workdir / "chord_line"
    try:
        subprocess.run(
            [tesseract, str(target), str(base), "-l", "eng", "--psm", "7",
             "-c", f"tessedit_char_whitelist={_CHORD_WHITELIST}", "-c", "tessedit_create_boxfile=1"],
            capture_output=True, text=True, timeout=60, check=False, env=_TESSERACT_ENV,
        )
        lines = (base.with_suffix(".box")).read_text(encoding="utf-8").splitlines()
    except (OSError, subprocess.TimeoutExpired):
        return []
    chars = []
    for line in lines:
        fields = line.split(" ")
        if len(fields) < 5 or not fields[0].strip():
            continue
        try:
            x0, y0, x1, y1 = (float(v) for v in fields[1:5])
        except ValueError:
            continue
        chars.append((fields[0], int(x) - 14 + x0, int(x) - 14 + x1, y1 - y0))
    return sorted(chars, key=lambda c: c[1])


def _chord_tokens(chars: list[tuple[str, float, float, float]]) -> list[dict]:
    """Chord tokens from line characters, each with its left x.

    A new token starts at a space or at a root letter (A-G) not after "/".
    A root with no gap after the previous chord is its bass with a lost
    slash ("GB" is G/B). A sign that was printed but not read leaves a
    trace: its letter box is too wide (the sharp merged in) or a gap sits
    where it was, so only then does a missing sign follow the key.
    """
    if not chars:
        return []
    heights = sorted(c[3] for c in chars)
    height = heights[len(heights) // 2] or 1.0
    upper = sorted(c[2] - c[1] for c in chars if c[0] in "ABCDEFG")
    # Lower quartile: letters with a merged sign or suffix ("Csus") are wide
    # and would lift a median.
    upper_width = upper[len(upper) // 4] if upper else height * 0.8
    narrowest: dict[str, float] = {}
    for c in chars:
        narrowest[c[0]] = min(narrowest.get(c[0], math.inf), c[2] - c[1])
    counts: dict[str, int] = {}
    for c in chars:
        counts[c[0]] = counts.get(c[0], 0) + 1

    def sign_trace(index: int) -> bool:
        letter = chars[index]
        if letter[2] - letter[1] > upper_width * 1.25:
            return True
        if index + 1 < len(chars):
            after = chars[index + 1]
            gap = after[1] - letter[2]
            if gap > (letter[2] - letter[1]) * 0.5 and gap < height * 0.9:
                return True
            if counts[after[0]] > 1 and after[2] - after[1] > narrowest[after[0]] * 1.3:
                return True
        return False

    tokens: list[dict] = []
    for index, (char, x0, x1, _h) in enumerate(chars):
        gap = x0 - chars[index - 1][2] if index else math.inf
        root = char in "ABCDEFG" and (index == 0 or chars[index - 1][0] != "/")
        if tokens and root and gap < height * 0.15 and "/" not in tokens[-1]["text"]:
            tokens[-1]["text"] += "/" + char
            tokens[-1]["bass_trace"] = sign_trace(index)
        elif not tokens or gap > height * 0.5 or root:
            tokens.append({"x": x0, "text": char, "root_trace": sign_trace(index), "bass_trace": False})
        else:
            tokens[-1]["text"] += char
            if char in "ABCDEFG" and tokens[-1]["text"].endswith("/" + char):
                tokens[-1]["bass_trace"] = sign_trace(index)
    return tokens


def _chord_line_above(book: dict, image, staff: dict, interline: float, workdir: Path) -> list[dict]:
    """Chord tokens of the text line above a staff when most of it reads as chords."""
    top = max(0, int(staff["top"] - interline * 4))
    region = (int(staff["left"]), top, int(staff["right"]), int(staff["top"] - interline * 0.3))
    if region[3] - region[1] < interline:
        return []
    left = staff["left"] - interline
    # Nearest the staff first; notes above the staff read as noise.
    for band_top, band_bottom in reversed(_text_bands(image, region, interline)):
        box = (left, band_top - interline * 0.3, staff["right"] + interline - left,
               band_bottom - band_top + interline * 0.6)
        tokens = [
            t for t in _chord_tokens(_chord_chars(book["tesseract"], image, box, workdir))
            if any(char.isalpha() for char in t["text"])
        ]
        chords = [t for t in tokens if _parse_reread_chord(t["text"], 0) is not None]
        if len(chords) >= 2 and len(chords) >= 0.6 * len(tokens):
            return tokens
    return []


def _ocr_chord_lines(book: dict, workdir: Path) -> int:
    """Add chords Audiveris dropped by reading each chord line in English.

    Audiveris skips most chords whose sharp it cannot read. The whole line,
    read with chord characters only and character by character, finds them
    with their exact position. Where Audiveris found no chord line at all
    (small raised numbers such as "Gm⁷" defeat it), the text line above the
    staff is used when it reads as chords. A chord is added only where its
    note has none yet.
    """
    added = 0
    for part, entries in zip(book["parts"], book["placements"]):
        by_staff: dict[tuple, dict[int, ET.Element]] = {}
        for measure, entry in zip(part.findall("measure"), entries):
            if entry is not None:
                sheet, _system, index, siblings = entry
                by_staff.setdefault((sheet, siblings[0]["id"]), {})[index] = measure
        for number, sheet, image, interline, staves in book["sheets"]:
            chords = [s for s in sheet.iter("sentence") if s.get("role") == "ChordName"]
            for staff in staves:
                measures = by_staff.get((number, staff["id"]))
                if not measures:
                    continue
                bounds = [
                    b for b in (c.find("bounds") for c in chords if c.get("staff") == staff["id"])
                    if b is not None
                ]
                if bounds:
                    left = staff["left"] - interline
                    top = min(float(b.get("y")) for b in bounds) - interline * 0.3
                    bottom = max(float(b.get("y")) + float(b.get("h")) for b in bounds) + interline * 0.3
                    box = (left, top, staff["right"] + interline - left, bottom - top)
                    tokens = _chord_tokens(_chord_chars(book["tesseract"], image, box, workdir))
                else:
                    # No chord line found by Audiveris: try the text line just
                    # above the staff, and keep it only if it reads as chords.
                    tokens = _chord_line_above(book, image, staff, interline, workdir)
                for token in tokens:
                    # A chord starts at its note; right after a bar line the
                    # letter may begin a hair before the bar's first note.
                    x = token["x"] + interline * 0.3
                    index = next(
                        (i for i, (a, b, _) in enumerate(staff["measures"]) if a <= x < b), None,
                    )
                    measure = measures.get(index)
                    if measure is None:
                        continue
                    chord = _parse_reread_chord(
                        token["text"], book["keys"][id(measure)],
                        token["root_trace"], token["bass_trace"],
                    )
                    if chord is None:
                        continue
                    harmony = _harmony_element(chord, ET.Element("words"))
                    if _place_harmony(book, measure, token["x"], interline, harmony):
                        added += 1
    return added


def _reread_chords(book: dict, workdir: Path) -> int:
    """Re-read chord-line words that are not chords with an English OCR.

    Tesseract reads "F♯m7" as Hangul ("태m7") when Korean is enabled. The
    .omr book keeps each word's box, so read that box again, alone, with
    only chord characters allowed, and put the chord on the note under it.
    """
    converted = 0
    for part, entries in zip(book["parts"], book["placements"]):
        by_staff: dict[tuple, list[ET.Element]] = {}
        for measure, entry in zip(part.findall("measure"), entries):
            if entry is not None:
                sheet, _system, index, siblings = entry
                by_staff.setdefault((sheet, siblings[0]["id"]), []).append((index, measure))
        for number, sheet, image, interline, staves in book["sheets"]:
            chords = [s for s in sheet.iter("sentence") if s.get("role") == "ChordName"]
            for staff in staves:
                measures = dict(by_staff.get((number, staff["id"]), []))
                bands = [
                    (float(b.get("y")), float(b.get("y")) + float(b.get("h")))
                    for b in (c.find("bounds") for c in chords if c.get("staff") == staff["id"])
                    if b is not None
                ]
                if not measures or not bands:
                    continue
                top = min(a for a, _ in bands) - interline * 0.5
                bottom = max(b for _, b in bands) + interline * 0.5
                for word in sheet.iter("word"):
                    bounds = word.find("bounds")
                    value = (word.get("value") or "").strip()
                    if word.get("staff") != staff["id"] or bounds is None or not value:
                        continue
                    x, y, w, h = (float(bounds.get(k)) for k in "xywh")
                    if not top <= y + h / 2 <= bottom:
                        continue
                    index = next(
                        (i for i, (left, right, _) in enumerate(staff["measures"]) if left <= x < right),
                        None,
                    )
                    measure = measures.get(index)
                    if measure is None:
                        continue
                    direction = next(
                        (d for d in measure.findall("direction")
                         if value in " ".join(w.text or "" for w in d.iter("words")).split()),
                        None,
                    )
                    if direction is None:
                        continue
                    fifths = book["keys"][id(measure)]
                    chord = _parse_chord_text(value, fifths)
                    if chord is None:
                        text = _ocr_chord_text(book["tesseract"], image, (x, y, w, h), workdir, "8")
                        # A sign read as Hangul ("태" for F♯) or as marks no
                        # chord uses ("E10\"" for E/G♯) shows one was printed;
                        # only then may a sign lost again follow the key.
                        traced = any(
                            not (char.isascii() and (char.isalnum() or char in "/#()+-"))
                            for char in value
                        )
                        chord = _parse_reread_chord(text, fifths, traced, traced)
                    if chord is None:
                        continue
                    words = next(direction.iter("words"))
                    if _place_harmony(book, measure, x, interline, _harmony_element(chord, words)):
                        converted += 1
                    # Either placed now or its note already has a chord.
                    remaining = [t for t in (words.text or "").split() if t != value]
                    if remaining:
                        words.text = " ".join(remaining)
                    else:
                        measure.remove(direction)
    return converted


def _drop_lyric_words(parts) -> int:
    """Remove words that repeat lyrics sung in this or the eight bars before.

    A lower verse printed close to the next staff is exported as words above
    that staff; once the line has been read as lyrics the words duplicate it.
    Measures are compared in score order so this also works on systems whose
    measures could not be matched to the book.
    """
    from collections import Counter

    removed = 0
    for part in parts:
        measures = part.findall("measure")
        sung = [
            [lyric.findtext("text") or "" for note in m.findall("note") for lyric in note.findall("lyric")]
            for m in measures
        ]
        for index, measure in enumerate(measures):
            pool = Counter(
                char for texts in sung[max(0, index - 8):index + 1]
                for text in texts for char in text
            )
            if not pool:
                continue
            for direction in measure.findall("direction"):
                text = "".join(
                    (words.text or "") for words in direction.iter("words")
                ).replace(" ", "")
                hangul = [char for char in text if "가" <= char <= "힣"]
                if len(hangul) < 2 or len(hangul) < 0.8 * len(text):
                    continue
                matched = sum((Counter(hangul) & pool).values())
                if matched >= 0.6 * len(hangul):
                    measure.remove(direction)
                    removed += 1
    return removed


def _attach_stray_accidentals(parts) -> int:
    """Put a sign read apart from its chord back on the chord.

    Charts that space a chord out ("B ♭ 2") come back as the chord "B" and
    the words "b 2" beside it. Words that are only a sign, optionally with
    the root before it and a suffix after it ("b", "b 2", "2-E b 2"), set
    that sign and suffix on the nearest chord of the same root in the
    measure, and are removed.
    """
    pattern = re.compile(r"(?:.*?([A-G]))?([b#♭♯])(.*)")
    fixed = 0
    for part in parts:
        for measure in part.findall("measure"):
            for direction in list(measure.findall("direction")):
                types = direction.findall("direction-type")
                if len(types) != 1 or [c.tag for c in types[0]] != ["words"]:
                    continue
                compact = "".join((types[0][0].text or "").split())
                match = pattern.fullmatch(compact)
                if not match or any("가" <= c <= "힣" for c in compact):
                    continue
                step, sign, rest = match.groups()
                suffix = _chord_suffix(rest)
                if suffix is None:
                    continue
                children = list(measure)
                position = children.index(direction)
                candidates = [
                    (abs(children.index(h) - position), h) for h in measure.findall("harmony")
                    if (step is None or h.findtext("root/root-step") == step)
                    and not (h.findtext("root/root-alter") or "").strip("0")
                ]
                if not candidates:
                    continue
                harmony = min(candidates, key=lambda item: item[0])[1]
                root = harmony.find("root")
                alter = ET.SubElement(root, "root-alter")
                alter.text = "-1" if sign in "b♭" else "1"
                if suffix:
                    kind = harmony.find("kind")
                    kind.set("text", suffix)
                    kind.text = _CHORD_KINDS[suffix]
                measure.remove(direction)
                fixed += 1
    return fixed


def _drop_chord_junk(parts) -> int:
    """Remove above-staff words left from chords OCR could not read.

    Once the chord line has been read again, what stays behind as words is
    noise such as "G7F", "87", "6717", "0/58m?" or "D/a", or a chord such as
    "G/B C" that the chord line already carries: short, no Hangul, starting
    like a chord or a digit, and holding a digit, slash or "?" or reading as
    a chord. Also the end of a chord read on its own ("m7" as "rn?", "m?",
    "sus4"), and a slash chord whose slash came out as a letter ("D/E" as
    "DIE"). Words such as "Solo", "rit.", "Fine" or "x2" stay.
    """
    removed = 0
    junk = re.compile(r"[A-G0-9][A-Za-z0-9#/?'\".,:|+()\-]{0,7}")
    # "m" is often read as "rn"; the figure after it as "?".
    # A bare "m" is the end of a minor chord; "dim" alone is an instruction.
    suffix = re.compile(r"(?:rn|m)[0-9?]{0,2}|(?:M|maj|sus|dim|aug|add)[0-9?]{1,2}")
    slash = re.compile(r"([A-G])[#b]?(?:m7?|7|M7|maj7|sus4)?[Il1|]([A-G])[#b]?")
    # Words that count or number: "2x", "x3", "1.", "2nd", "8va".
    counted = re.compile(r"\d+\s?[xX]|[xX]\s?\d+|\d+\.|\d+(?:st|nd|rd|th)|\d+(?:va|vb|ma)")
    for part in parts:
        for measure in part.findall("measure"):
            for direction in measure.findall("direction"):
                if direction.get("placement") != "above":
                    continue
                types = direction.findall("direction-type")
                if len(types) != 1 or [c.tag for c in types[0]] != ["words"]:
                    continue
                tokens = (types[0][0].text or "").split()
                if not tokens or any(counted.fullmatch(token) for token in tokens):
                    continue
                # "DIE" is the "D/E" of this measure; without that chord it is
                # a word ("BIG", "DID").
                slashes = {
                    (h.findtext("root/root-step"), h.findtext("bass/bass-step"))
                    for h in measure.findall("harmony")
                }

                def misread_slash(token: str) -> bool:
                    match = slash.fullmatch(token)
                    return match is not None and match.groups() in slashes

                if all(
                    suffix.fullmatch(token) or misread_slash(token) or
                    junk.fullmatch(token) and (
                        any(c in "/?(" or c.isdigit() for c in token)
                        # A chord the chord line already carries.
                        or _parse_reread_chord(token, 0) is not None
                    )
                    for token in tokens
                ):
                    measure.remove(direction)
                    removed += 1
    return removed
