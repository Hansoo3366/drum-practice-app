"""Lead-sheet repairs on the MusicXML alone: chords, lyrics, ties, rests, tempos, parts."""

from __future__ import annotations

import os
import re

from xml.etree import ElementTree as ET


# --- Lead sheet post-processing ------------------------------------------
#
# Audiveris reads chord symbols and lyrics through Tesseract. A printed sharp
# is not in the eng/kor models, so "F♯m7" comes back as plain words such as
# "Fﬁm’l" or "Gum" and never becomes a chord. Korean lyrics printed one
# syllable per note are often read as one word on the first note. These
# rules repair only what a strict grammar recognizes; everything else is left
# for the in-app proofreader.

_SHARP_ORDER = "FCGDAEB"

# Chord suffix as written -> MusicXML kind. "add" chords keep a degree.
_CHORD_KINDS = {
    "": "major", "M": "major", "maj": "major",
    "m": "minor", "min": "minor", "-": "minor",
    "7": "dominant", "maj7": "major-seventh", "M7": "major-seventh",
    "m7": "minor-seventh", "min7": "minor-seventh", "-7": "minor-seventh",
    "mM7": "major-minor", "mmaj7": "major-minor",
    "dim": "diminished", "o": "diminished", "dim7": "diminished-seventh",
    "aug": "augmented", "+": "augmented", "aug7": "augmented-seventh",
    "m7b5": "half-diminished", "ø": "half-diminished",
    "sus": "suspended-fourth", "sus4": "suspended-fourth",
    "sus2": "suspended-second", "7sus4": "suspended-fourth",
    "6": "major-sixth", "m6": "minor-sixth",
    "9": "dominant-ninth", "maj9": "major-ninth", "m9": "minor-ninth",
    "11": "dominant-11th", "m11": "minor-11th", "13": "dominant-13th",
    "add9": "major", "add2": "major", "madd9": "minor", "5": "power",
    "2": "suspended-second",
}
_ADDED_DEGREE = {"add9": 9, "add2": 2, "madd9": 9}
# How Tesseract tends to render a printed sharp between root and suffix.
_SHARP_GLYPHS = ("ﬁ", "ﬂ", "fi", "fl", "#", "♯")
_QUOTES = str.maketrans("", "", "’‘'`“”\"")


def _key_alter(step: str, fifths: int) -> int:
    if fifths > 0 and step in _SHARP_ORDER[:fifths]:
        return 1
    if fifths < 0 and step in _SHARP_ORDER[::-1][:-fifths]:
        return -1
    return 0


def _parse_chord_text(text: str, fifths: int) -> dict | None:
    """Parse OCR text as a chord symbol, or None when it is not one."""
    raw = text.strip().translate(_QUOTES).replace("♭", "b")
    match = re.fullmatch(r"([A-G])(.*?)(?:/([A-G])(#|♯|b)?)?", raw)
    if not match:
        return None
    step, rest, bass, bass_acc = match.groups()
    alter = 0
    for glyph in _SHARP_GLYPHS:
        if rest.startswith(glyph):
            alter, rest = 1, rest[len(glyph):]
            break
    else:
        if rest.startswith("b") and rest[1:] in _CHORD_KINDS:
            alter, rest = -1, rest[1:]
    suffix = _chord_suffix(rest)
    if suffix is None and alter == 0:
        # A sharp read as junk ("Gum", "C|:tm"): accept only when the key
        # signature sharpens (or flattens) this root anyway.
        junk = re.match(r"[^A-Za-z0-9+ø]{0,3}[uHt]?[^A-Za-z0-9+ø]{0,3}", rest)
        tail = rest[junk.end():] if junk else rest
        key = _key_alter(step, fifths)
        if junk and junk.end() > 0 and key != 0:
            suffix = _chord_suffix(tail)
            alter = key if suffix is not None else 0
    if suffix is None:
        return None
    return {
        "step": step, "alter": alter, "suffix": suffix,
        "bass": bass, "bass_alter": {"#": 1, "♯": 1, "b": -1}.get(bass_acc or "", 0),
    }


def _chord_suffix(rest: str) -> str | None:
    if rest in _CHORD_KINDS:
        return rest
    # A trailing 7 is often read as l, I or |.
    if rest and rest[-1] in "lI|" and rest[:-1] + "7" in _CHORD_KINDS:
        return rest[:-1] + "7"
    return None


def _harmony_element(chord: dict, template: ET.Element) -> ET.Element:
    harmony = ET.Element("harmony", placement="above")
    for name in ("default-y", "relative-x", "default-x"):
        if template.get(name) is not None:
            harmony.set(name, template.get(name))
    root = ET.SubElement(harmony, "root")
    ET.SubElement(root, "root-step").text = chord["step"]
    if chord["alter"]:
        ET.SubElement(root, "root-alter").text = str(chord["alter"])
    kind = ET.SubElement(harmony, "kind", text=chord["suffix"])
    kind.text = _CHORD_KINDS[chord["suffix"]]
    if chord["bass"]:
        bass = ET.SubElement(harmony, "bass")
        ET.SubElement(bass, "bass-step").text = chord["bass"]
        if chord["bass_alter"]:
            ET.SubElement(bass, "bass-alter").text = str(chord["bass_alter"])
    if chord["suffix"] in _ADDED_DEGREE:
        degree = ET.SubElement(harmony, "degree")
        ET.SubElement(degree, "degree-value").text = str(_ADDED_DEGREE[chord["suffix"]])
        ET.SubElement(degree, "degree-alter").text = "0"
        ET.SubElement(degree, "degree-type").text = "add"
    return harmony


def _float(value: str | None) -> float | None:
    try:
        return float(value) if value is not None else None
    except ValueError:
        return None


def _chords_from_words(root: ET.Element) -> int:
    """Turn above-staff words that parse as chord symbols into <harmony>."""
    heights = sorted(
        y for y in (_float(h.get("default-y")) for h in root.iter("harmony")) if y is not None
    )
    median = heights[len(heights) // 2] if heights else None
    converted = 0
    for part in root.findall("part"):
        fifths = 0
        for measure in part.findall("measure"):
            for child in list(measure):
                if child.tag == "attributes":
                    value = child.findtext("key/fifths")
                    if value and value.strip().lstrip("-").isdigit():
                        fifths = int(value)
                    continue
                if child.tag != "direction" or child.get("placement") != "above":
                    continue
                types = child.findall("direction-type")
                if len(types) != 1 or [c.tag for c in types[0]] != ["words"]:
                    continue
                words = types[0][0]
                y = _float(words.get("default-y"))
                size = _float(words.get("font-size"))
                if y is None or (size is not None and size > 24):
                    continue
                in_band = abs(y - median) <= 8 if median is not None else 15 <= y <= 45
                if not in_band:
                    continue
                chord = _parse_chord_text(words.text or "", fifths)
                if chord is None:
                    continue
                index = list(measure).index(child)
                measure.remove(child)
                measure.insert(index, _harmony_element(chord, words))
                converted += 1
    return converted


_HANGUL = re.compile(r"[가-힣]+")


_DIATONIC = {"C": 0, "D": 1, "E": 2, "F": 3, "G": 4, "A": 5, "B": 6}
# Diatonic number of the bottom staff line per clef sign (E4 treble, G2 bass, F3 alto).
_BOTTOM_LINE = {"G": 4 * 7 + 2, "F": 2 * 7 + 4, "C": 3 * 7 + 3}


def _drop_lyric_dash_articulations(root: ET.Element) -> list[tuple[ET.Element, str]]:
    """Remove articulations that are really the dashes of the lyric line.

    Lead sheets hold a syllable with a dash ("마운—친구—") and Audiveris reads
    those dashes as tenuto, staccato or accent marks. A real mark below a note
    sits about one interline under the head; these sit in the lyric line, well
    over two interlines (20 tenths) lower. Returns (note, verse) per dash, the
    verse being the exported lyric line nearest in height (else "1").
    """
    removed = []
    for part in root.findall("part"):
        clef = "G"
        for measure in part.findall("measure"):
            sign = measure.findtext("attributes/clef/sign")
            if sign:
                clef = sign
            heights: dict[str, list[float]] = {}
            for lyric in measure.iter("lyric"):
                y = _float(lyric.get("default-y"))
                if y is not None:
                    heights.setdefault(lyric.get("number") or "1", []).append(y)
            lines = {verse: sum(ys) / len(ys) for verse, ys in heights.items()}
            for note in measure.findall("note"):
                pitch = note.find("pitch")
                marks = note.find("notations/articulations")
                if pitch is None or marks is None or clef not in _BOTTOM_LINE:
                    continue
                steps = int(pitch.findtext("octave") or "4") * 7 + _DIATONIC.get(pitch.findtext("step"), 0)
                head = -40 + (steps - _BOTTOM_LINE[clef]) * 5
                for mark in list(marks):
                    y = _float(mark.get("default-y"))
                    if mark.get("placement") == "below" and y is not None and head - y > 20:
                        marks.remove(mark)
                        verse = min(lines, key=lambda v: abs(lines[v] - y), default="1")
                        removed.append((note, verse))
                if not len(marks):
                    notations = note.find("notations")
                    notations.remove(marks)
                    if not len(notations):
                        note.remove(notations)
    return removed


def _drop_placeholder_rests(root: ET.Element) -> int:
    """Remove whole-measure rests of extra voices on single-staff parts.

    Audiveris takes some slur and tie arcs for a second or third voice and
    fills that voice with a measure rest, drawn as a stray block. A lead-sheet
    staff sings one voice, so such a rest carries nothing.
    """
    removed = 0
    for part in root.findall("part"):
        if any((s.text or "1").strip() not in ("", "1") for s in part.iter("staves")):
            continue
        for measure in part.findall("measure"):
            notes = measure.findall("note")
            if not notes:
                continue
            main = notes[0].findtext("voice") or "1"
            sounding = {n.findtext("voice") or "1" for n in notes if n.find("rest") is None}
            for note in notes:
                rest = note.find("rest")
                voice = note.findtext("voice") or "1"
                if rest is None or voice == main or voice in sounding:
                    continue
                if rest.get("measure") != "yes" and note.find("type") is not None:
                    continue
                items = list(measure)
                at = items.index(note)
                before = items[at - 1] if at else None
                after = items[at + 1] if at + 1 < len(items) else None
                # The rewind of this voice goes with it: the one that brought
                # the cursor back to write it, or else the one that takes the
                # cursor back over it for the next voice.
                if before is not None and before.tag == "backup" \
                        and before.findtext("duration") == note.findtext("duration"):
                    measure.remove(before)
                elif after is not None and after.tag == "backup" \
                        and after.findtext("duration") == note.findtext("duration"):
                    measure.remove(after)
                measure.remove(note)
                removed += 1
            # A rewind with nothing after it is left over from the removed voice.
            while len(measure) and measure[-1].tag == "backup":
                measure.remove(measure[-1])
    return removed


def _drop_tie_dots(root: ET.Element) -> int:
    """Remove staccato dots on tied notes.

    A tied note is held into the next one, so a staccato on it contradicts the
    tie; these dots are a thick part of the tie arc read as a dot.
    """
    removed = 0
    for note in root.iter("note"):
        marks = note.find("notations/articulations")
        if marks is None or not any(t.get("type") in ("start", "stop") for t in note.findall("tie")):
            continue
        for mark in list(marks):
            if mark.tag in ("staccato", "staccatissimo"):
                marks.remove(mark)
                removed += 1
        if not len(marks):
            notations = note.find("notations")
            notations.remove(marks)
            if not len(notations):
                note.remove(notations)
    return removed


def _single_staff(part: ET.Element) -> bool:
    return not any((s.text or "1").strip() not in ("", "1") for s in part.iter("staves"))


def _diatonic(note: ET.Element) -> int | None:
    pitch = note.find("pitch")
    if pitch is None or not (pitch.findtext("octave") or "").isdigit():
        return None
    return int(pitch.findtext("octave")) * 7 + _DIATONIC.get(pitch.findtext("step"), 0)


def _drop_second_chords(root: ET.Element) -> int:
    """Remove a chord tone one step from its note on a single-staff melody.

    A tie or slur crossing a staff line next to a note head is read as a
    second head; a sung line does not stack neighbouring notes.
    """
    removed = 0
    for part in root.findall("part"):
        if not _single_staff(part):
            continue
        for measure in part.findall("measure"):
            base = None
            for note in measure.findall("note"):
                if note.find("chord") is None:
                    base = note
                    continue
                here, there = _diatonic(note), _diatonic(base) if base is not None else None
                if here is not None and there is not None and abs(here - there) == 1:
                    measure.remove(note)
                    removed += 1
    return removed


def _tie_held_dashes(root: ET.Element) -> int:
    """Tie a dashed note to the note before it when both have the same pitch.

    A lyric dash holds the previous syllable, so a same-pitch note under it
    continues that note; Audiveris misses ties that run along a staff line.
    """
    def same_pitch(a: ET.Element, b: ET.Element) -> bool:
        pa, pb = a.find("pitch"), b.find("pitch")
        return all((pa.findtext(k) or "0") == (pb.findtext(k) or "0") for k in ("step", "alter", "octave"))

    def add_tie(note: ET.Element, kind: str) -> None:
        if any(t.get("type") == kind for t in note.findall("tie")):
            return
        duration = note.find("duration")
        at = list(note).index(duration) + 1 if duration is not None else len(note)
        note.insert(at, ET.Element("tie", type=kind))
        notations = note.find("notations")
        if notations is None:
            notations = ET.Element("notations")
            lyrics = [i for i, e in enumerate(note) if e.tag in ("lyric", "play", "listen")]
            note.insert(lyrics[0] if lyrics else len(note), notations)
        notations.insert(0, ET.Element("tied", type=kind))

    tied = 0
    for part in root.findall("part"):
        if not _single_staff(part):
            continue
        previous = None
        for measure in part.findall("measure"):
            for note in measure.findall("note"):
                if note.find("chord") is not None or note.find("grace") is not None:
                    continue
                if note.find("pitch") is None:
                    previous = None
                    continue
                dashed = any((l.findtext("text") or "") == "—" for l in note.findall("lyric"))
                if dashed and previous is not None and same_pitch(previous, note) \
                        and not any(t.get("type") == "start" for t in previous.findall("tie")):
                    add_tie(previous, "start")
                    add_tie(note, "stop")
                    tied += 1
                previous = note
    return tied


def _drop_bad_tempos(root: ET.Element) -> int:
    """Remove metronome marks and tempo sounds no player could use.

    Stray text read as a metronome mark ("1cz", "2371}I| 갈음") becomes a
    tempo of 1 or 9484 BPM and stretches playback to hours.
    """
    removed = 0
    for direction in list(root.iter("direction")):
        for kind in list(direction.findall("direction-type")):
            metronome = kind.find("metronome")
            if metronome is None:
                continue
            text = (metronome.findtext("per-minute") or "").strip()
            clean = re.fullmatch(r"\d{2,3}(?:\.\d+)?", text)
            if not clean or not 20 <= float(text) <= 400:
                direction.remove(kind)
                removed += 1
    for sound in root.iter("sound"):
        tempo = _float(sound.get("tempo"))
        if tempo is not None and not 20 <= tempo <= 400:
            del sound.attrib["tempo"]
            removed += 1
    # Directions left with nothing to show or play.
    for measure in root.iter("measure"):
        for direction in list(measure.findall("direction")):
            sound = direction.find("sound")
            if direction.find("direction-type") is None and (sound is None or not sound.attrib):
                measure.remove(direction)
    return removed


def _add_lyric_dashes(dashes: list[tuple[ET.Element, str]]) -> int:
    """Print the held-syllable dashes in the lyric line, as the original does.

    Runs after the lyric OCR so a dash never takes a syllable's note. A note
    that already sings a syllable in that verse keeps it.
    """
    added = 0
    for note, verse in dashes:
        if any((lyric.get("number") or "1") == verse for lyric in note.findall("lyric")):
            continue
        lyric = ET.Element("lyric", number=verse)
        ET.SubElement(lyric, "syllabic").text = "single"
        ET.SubElement(lyric, "text").text = "—"
        _insert_lyric(note, lyric)
        added += 1
    return added


def _split_korean_lyrics(root: ET.Element) -> int:
    """Spread a run of Hangul syllables on one note over neighbouring notes.

    Korean is sung one syllable per note, but OCR often reads a printed line
    such as "자 격 없 는 내 힘 이" as one word, and Audiveris attaches the
    word to the note under its middle. Choose the run of consecutive notes,
    one per syllable, that contains that note, stays between the neighbouring
    lyrics of the same verse, and whose centre is closest to it on the page.
    """
    split = 0
    for part in root.findall("part"):
        voices: dict[tuple[str, str], list[tuple[ET.Element, int, float | None]]] = {}
        system, offset = 0, 0.0
        for measure in part.findall("measure"):
            layout = measure.find("print")
            if layout is not None and layout.get("new-system") == "yes":
                system, offset = system + 1, 0.0
            for note in measure.findall("note"):
                if note.find("chord") is not None or note.find("grace") is not None:
                    continue
                if note.find("rest") is not None:
                    continue
                if any(t.get("type") == "stop" for t in note.findall("tie")):
                    continue
                x = _float(note.get("default-x"))
                key = (note.findtext("voice") or "1", note.findtext("staff") or "1")
                voices.setdefault(key, []).append(
                    (note, system, offset + x if x is not None else None)
                )
            offset += _float(measure.get("width")) or 0.0
        for notes in voices.values():
            for index in range(len(notes)):
                for lyric in list(notes[index][0].findall("lyric")):
                    if _spread_lyric(notes, index, lyric):
                        split += 1
    return split


def _spread_lyric(notes: list, index: int, lyric: ET.Element) -> bool:
    text = (lyric.findtext("text") or "").strip()
    if len(text) < 2 or not _HANGUL.fullmatch(text):
        return False
    number = lyric.get("number", "1")

    def has_verse(position: int) -> bool:
        return any(l.get("number", "1") == number for l in notes[position][0].findall("lyric"))

    before = 0
    while index - before - 1 >= 0 and not has_verse(index - before - 1):
        before += 1
    after = 0
    while index + after + 1 < len(notes) and not has_verse(index + after + 1):
        after += 1
    count = len(text)
    starts = [
        start for start in range(max(index - before, index - count + 1),
                                 min(index, index + after - count + 1) + 1)
        if all(notes[p][1] == notes[index][1] for p in range(start, start + count))
    ]
    if not starts:
        return False

    def distance(start: int) -> float:
        first, last, anchor = notes[start][2], notes[start + count - 1][2], notes[index][2]
        if None in (first, last, anchor):
            return abs(start + (count - 1) / 2 - index)
        return abs((first + last) / 2 - anchor)

    start = min(starts, key=lambda s: (distance(s), s))
    notes[index][0].remove(lyric)
    for syllable, position in zip(text, range(start, start + count)):
        copy = ET.fromstring(ET.tostring(lyric))
        copy.find("text").text = syllable
        _set_syllabic(copy)
        _insert_lyric(notes[position][0], copy)
    return True


def _set_syllabic(lyric: ET.Element) -> None:
    syllabic = lyric.find("syllabic")
    if syllabic is None:
        syllabic = ET.Element("syllabic")
        lyric.insert(0, syllabic)
    syllabic.text = "single"


_AFTER_LYRIC = ("play", "listen")


def _insert_lyric(note: ET.Element, lyric: ET.Element) -> None:
    children = list(note)
    index = len(children)
    for position, child in enumerate(children):
        if child.tag in _AFTER_LYRIC:
            index = position
            break
    note.insert(index, lyric)


def _title_from_credits(root: ET.Element) -> str | None:
    """Use the largest credit text on page one as the movement title.

    OCR fragments ("마") and subtitles ("(Vocal)") never qualify, so a
    missed title leaves Audiveris' own choice in place.
    """
    best = None
    for credit in root.findall("credit"):
        if credit.get("page", "1") != "1" or credit.findtext("credit-type") in ("composer", "lyricist"):
            continue
        for words in credit.findall("credit-words"):
            size = _float(words.get("font-size")) or 0
            text = (words.text or "").strip()
            letters = sum(1 for char in text if char.isalpha())
            if letters < 2 or size < 12 or text.startswith("("):
                continue
            if best is None or size > best[0]:
                best = (size, text)
    if best is None:
        return None
    title = root.find("movement-title")
    if title is None:
        title = ET.Element("movement-title")
        position = 0
        for index, child in enumerate(list(root)):
            if child.tag in ("work", "movement-number"):
                position = index + 1
        root.insert(position, title)
    if title.text == best[1]:
        return None
    title.text = best[1]
    return best[1]


# Audiveris hands the whole sheet to Tesseract at once. Two lyric lines
# printed close under a staff then come back garbled ("나 하 갈 때 에 윅 뽀
# 곡") or not at all, and a lower verse is often attached to the next staff
# as plain words. Read lyrics again one line at a time: find the text bands
# under each staff in the sheet image kept in the .omr book, OCR each band
# as a single line, and place its syllables on the staff's note heads in
# order.

# Correct Hangul often scores 10-20; bands of noise are rejected as a whole:
# note heads and ties read as Hangul average about 50, lyric lines 75-95.
_LYRIC_MIN_CONFIDENCE = 10
_LYRIC_MIN_LINE_CONFIDENCE = 65
_LYRIC_MAX_BANDS = 400
# One line per call is tiny; Tesseract's thread pool only adds overhead.
_TESSERACT_ENV = {**os.environ, "OMP_THREAD_LIMIT": "1"}
# Maps a grey byte to 1 for ink, 0 for paper, so bytes.count(1) counts ink.
_INK = bytes(1 if value < 128 else 0 for value in range(256))


_CARRIED = ("divisions", "key", "time", "clef")


def _merge_split_parts(root: ET.Element) -> int:
    """Join parts that are one staff split by name, system by system.

    When the first system labels its staff "Vocal" and later ones "Vo.",
    Audiveris makes a part per name and fills the systems where a part is
    absent with measure rests. Only measures printed on the page carry a
    width, so when every measure has exactly one printed part, the parts
    are one staff. Real multi-part scores print all parts in every system
    and are left alone. Returns the number of parts merged away.
    """
    parts = root.findall("part")
    if len(parts) < 2:
        return 0
    measures = [part.findall("measure") for part in parts]
    count = len(measures[0])
    if count == 0 or any(len(m) != count for m in measures):
        return 0
    if any(
        (staves := measure.findtext("attributes/staves")) and staves.strip() != "1"
        for part in measures for measure in part
    ):
        return 0
    owners = []
    for index in range(count):
        printed = [p for p in range(len(parts)) if measures[p][index].get("width") is not None]
        if len(printed) != 1:
            return 0
        owners.append(printed[0])

    # Attribute state each part has reached before every measure.
    states: list[list[dict]] = []
    for part_measures in measures:
        state: dict[str, str] = {}
        before = []
        for measure in part_measures:
            before.append(dict(state))
            for attributes in measure.findall("attributes"):
                for name in _CARRIED:
                    element = attributes.find(name)
                    if element is not None:
                        state[name] = ET.tostring(element, encoding="unicode")
        states.append(before)

    merged = ET.Element("part", id=parts[owners[0]].get("id"))
    current: dict[str, str] = {}
    for index, owner in enumerate(owners):
        measure = measures[owner][index]
        own = states[owner][index]
        declared = {
            element.tag for attributes in measure.findall("attributes")
            for element in attributes if element.tag in _CARRIED
        }
        missing = [
            name for name in _CARRIED
            if name in own and own[name] != current.get(name) and name not in declared
        ]
        if missing:
            restated = ET.Element("attributes")
            for name in missing:
                restated.append(ET.fromstring(own[name]))
            position = 1 if len(measure) and measure[0].tag == "print" else 0
            measure.insert(position, restated)
        merged.append(measure)
        current = dict(own)
        for attributes in measure.findall("attributes"):
            for name in _CARRIED:
                element = attributes.find(name)
                if element is not None:
                    current[name] = ET.tostring(element, encoding="unicode")

    keep = parts[owners[0]].get("id")
    part_list = root.find("part-list")
    if part_list is not None:
        for score_part in part_list.findall("score-part"):
            if score_part.get("id") != keep:
                part_list.remove(score_part)
    position = list(root).index(parts[0])
    for part in parts:
        root.remove(part)
    root.insert(position, merged)
    return len(parts) - 1


# Rule-based validation (OMR spec Phase 2, §8-9): find measures that are
# probably wrong without any AI, and crop the original around each so a
# later reviewer (AI or user) looks at a few bars, never at whole pages.

_SEVERITY = {
    "V001": "high", "V002": "medium", "V003": "medium", "V004": "medium",
    "V006": "low", "V007": "high", "V008": "medium", "V009": "medium", "S001": "high", "L001": "low",
    "A001": "medium",
}
_STEP_SEMITONE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def _clamp_backups(root: ET.Element) -> int:
    """A `<backup>` cannot go before the start of its measure: shorten it to
    where the measure starts, or drop it when it is already there. Readers
    reject a measure that does (two backups in a row, after a voice was removed)."""
    changed = 0
    for measure in root.iter("measure"):
        cursor = 0
        for element in list(measure):
            duration = element.find("duration")
            try:
                length = int(float(duration.text)) if duration is not None else 0
            except (TypeError, ValueError):
                length = 0
            if element.tag == "note":
                if element.find("chord") is None and element.find("grace") is None:
                    cursor += length
            elif element.tag == "forward":
                cursor += length
            elif element.tag == "backup":
                if length > cursor:
                    changed += 1
                    if cursor <= 0:
                        measure.remove(element)
                        continue
                    duration.text = str(cursor)
                    length = cursor
                cursor -= length
    return changed
_MAX_SUSPECT_IMAGES = 200
# Words that are instructions, not leftovers of misread chords or lyrics.
_CLEAN_WORDS = re.compile(
    r"(?:[A-Za-z가-힣]+\.?(?:\s+[A-Za-z가-힣]+\.?)*|[xX]\s?\d+|\d+\s?[xX])"
)


_INSTRUCTION_WORDS = {
    "all", "bass", "break", "bridge", "chorus", "coda", "ending", "fade", "fill", "fine",
    "inst", "intro", "key", "men", "outro", "pad", "rit", "solo", "tag", "unison", "up",
    "verse", "women", "drums", "end", "a", "tempo",
}
