"""Audiveris .omr books: staves, sheet images and text lines, OCR and alignment helpers."""

from __future__ import annotations

import math
import os
import re
import shutil
import subprocess
import zipfile
from fractions import Fraction

from pathlib import Path
from xml.etree import ElementTree as ET

from omr_rules import _INK, _LYRIC_MIN_CONFIDENCE, _LYRIC_MIN_LINE_CONFIDENCE, _TESSERACT_ENV, _float, _key_alter


def _book_events(system: ET.Element, measure: ET.Element, staff: str, excluded: set[str] | None = None) -> list[dict] | None:
    """Read explicit monophonic rhythm symbols; no beat/pitch completion guesses.

    This is deliberately narrower than Audiveris: one head per chord, ordinary
    treble notes/rests, no tuplets, cue notes, tremolos or cross-staff notation.
    A caller must still verify meter and every already exported note.
    """
    vertices = {n.get("id"): n for n in system.iter() if n.get("id") and n.find("bounds") is not None}
    edges: dict[str, list[tuple[str, ET.Element]]] = {}
    for relation in system.iter("relation"):
        if len(relation) != 1:
            continue
        a, b = relation.get("source"), relation.get("target")
        edges.setdefault(a, []).append((b, relation[0]))
        edges.setdefault(b, []).append((a, relation[0]))

    def linked(identifier, tag):
        return [(vertices.get(other), rel) for other, rel in edges.get(identifier, []) if rel.tag == tag]

    events = []
    identifiers = ((measure.findtext("head-chords") or "") + " " + (measure.findtext("rest-chords") or "")).split()
    for identifier in identifiers:
        chord = vertices.get(identifier)
        if chord is None or linked(identifier, "chord-tuplet"):
            return None
        members = [n for n, _r in linked(identifier, "containment") if n is not None and n.tag in ("head", "rest")]
        if len(members) != 1 or members[0].get("staff") != staff:
            return None
        member = members[0]
        if excluded and member.get("id") in excluded:
            continue
        shape = member.get("shape")
        pitch = None
        if member.tag == "rest":
            base = {"WHOLE_REST": Fraction(1), "HALF_REST": Fraction(1, 2),
                    "QUARTER_REST": Fraction(1, 4), "EIGHTH_REST": Fraction(1, 8),
                    "ONE_16TH_REST": Fraction(1, 16), "ONE_32ND_REST": Fraction(1, 32)}.get(shape)
        else:
            position = _float(member.get("pitch"))
            if position is None or position != int(position):
                return None
            # Audiveris staff pitch 0 is the middle line (B4 in ordinary treble).
            diatonic = 4 * 7 + 6 - int(position)
            pitch = ("CDEFGAB"[diatonic % 7], diatonic // 7)
            stems = linked(identifier, "chord-stem")
            if shape == "WHOLE_NOTE" and not stems:
                base = Fraction(1)
            elif shape in ("NOTEHEAD_BLACK", "NOTEHEAD_VOID") and len(stems) == 1 and stems[0][0] is not None:
                stem = stems[0][0]
                beams = linked(stem.get("id"), "beam-stem")
                flags = linked(stem.get("id"), "flag-stem")
                if beams and flags:
                    return None
                count = len(beams)
                for flag, _rel in flags:
                    match = re.fullmatch(r"FLAG_([1-5])(?:_UP|_DOWN)?", flag.get("shape", "") if flag is not None else "")
                    if match is None:
                        return None
                    count += int(match.group(1))
                if count > 4 or (shape == "NOTEHEAD_VOID" and count):
                    return None
                base = Fraction(1, 2) if shape == "NOTEHEAD_VOID" else Fraction(1, 4 * 2 ** count)
            else:
                return None
        if base is None:
            return None
        # A second augmentation dot is a separate relation, not an inferred dot.
        dots = linked(member.get("id"), "augmentation")
        if len(dots) > 1:
            return None
        dot_count = len(dots)
        if dots:
            extras = linked(dots[0][0].get("id"), "double-dot") if dots[0][0] is not None else []
            if extras:
                return None  # unsupported until independently tested
        alter = None
        accidentals = linked(member.get("id"), "alter-head")
        if len(accidentals) > 1:
            return None
        if accidentals:
            accidental = accidentals[0][0]
            alter = {"SHARP": 1, "FLAT": -1, "NATURAL": 0, "DOUBLE_SHARP": 2, "DOUBLE_FLAT": -2}.get(
                accidental.get("shape") if accidental is not None else "")
            if alter is None:
                return None
        ties = []
        for slur, relation in linked(member.get("id"), "slur-head"):
            if slur is not None and slur.get("tie") == "true":
                side = relation.get("side")
                if side not in ("LEFT", "RIGHT") or slur.get("left-extension") or slur.get("right-extension"):
                    return None
                ties.append("start" if side == "LEFT" else "stop")
        bounds = member.find("bounds")
        events.append({"id": identifier, "head": member.get("id"), "x": float(bounds.get("x")) + float(bounds.get("w")) / 2,
                       "width": float(bounds.get("w")), "grade": _float(member.get("ctx-grade") or member.get("grade")) or 0,
                       "pitch": pitch, "alter": alter, "base": base, "dots": dot_count,
                       "duration": base * (Fraction(3, 2) if dot_count else 1), "ties": ties})
    events.sort(key=lambda e: e["x"])
    if any(b["x"] - a["x"] < .5 * max(a["width"], b["width"]) for a, b in zip(events, events[1:])):
        return None
    return events


def _printed_four_four(book: dict, number: str, staff: dict, left: float) -> tuple | None:
    """Verify a missed 4/4 against two confirmed digits from the SAME page.

    Both digits must independently match >= .92, at staff time-signature
    height, in the bar's left margin. This is image evidence, not a meter
    inferred from durations. Other meters/fonts without references are skipped.
    """
    from omr_marks import _shape_bits, _dice

    _number, sheet, image, interline, _staves = next(s for s in book["sheets"] if s[0] == number)
    refs = {}
    for node in sheet.iter("time-number"):
        bounds = node.find("bounds")
        if node.get("value") != "4" or node.get("frozen") != "true" or bounds is None:
            continue
        if (_float(node.get("ctx-grade")) or 0) < .9:
            continue
        x, y, w, h = (float(bounds.get(k)) for k in ("x", "y", "w", "h"))
        if not (1.2 * interline <= w <= 2 * interline and 1.8 * interline <= h <= 2.2 * interline):
            continue
        refs.setdefault(node.get("side"), (_shape_bits(image, (int(x), int(y), int(x+w), int(y+h))), round(w), round(h)))
    if set(refs) != {"TOP", "BOTTOM"}:
        return None
    top, w, h = refs["TOP"]
    bottom, bw, bh = refs["BOTTOM"]
    if abs(w-bw) > 2 or abs(h-bh) > 2:
        return None
    best = None
    # Only the first four staff spaces; never search the melody for a fraction.
    for x in range(round(left + .4 * interline), round(left + 4 * interline)):
        for y in range(round(staff["top"] - .2 * interline), round(staff["top"] + .2 * interline) + 1):
            score = min(_dice(top, _shape_bits(image, (x, y, x+w, y+h))),
                        _dice(bottom, _shape_bits(image, (x, y+h, x+bw, y+h+bh))))
            if score >= .92 and (best is None or score > best[0]):
                best = (score, (x, y, x + max(w, bw), y + h + bh))
    return best


def _restore_exported_rhythm(root: ET.Element, folder: Path) -> list[dict]:
    """Recover omitted, explicitly recognized events in strictly verified bars.

    Only a single ordinary treble staff with non-overlapping symbols and an
    exact meter total is eligible. Existing notes must agree with the book's
    exported voice IDs, pitches, accidentals and durations. Ambiguity means
    no change. Raw MXL/book are never written; the caller saves a fixed version.
    """
    book = _load_book(root, folder, ocr=False)
    if book is None:
        return []
    sheets = {number: sheet for number, sheet, _img, _il, _st in book["sheets"]}
    changes = []
    types = {Fraction(1): "whole", Fraction(1, 2): "half", Fraction(1, 4): "quarter",
             Fraction(1, 8): "eighth", Fraction(1, 16): "16th", Fraction(1, 32): "32nd", Fraction(1, 64): "64th"}
    for part_index, (part, placements) in enumerate(zip(book["parts"], book["placements"])):
        # Do not reconstruct a melody lane inside a polyphonic part. Empty
        # exported voices are allowed; simultaneous written notes are not.
        all_measures = part.findall("measure")
        if any(len({n.findtext("voice") or "1" for n in m.findall("note")}) > 1
               or any(n.find("chord") is not None or (n.findtext("staff") or "1") != "1" for n in m.findall("note"))
               for m in all_measures):
            continue
        if any(e is not None and len(e[3]) != 1 for e in placements):
            continue
        first_change = len(changes)
        divisions, expected, fifths, clef = Fraction(1), None, 0, None
        for index, (measure, entry) in enumerate(zip(part.findall("measure"), placements)):
            attrs = measure.find("attributes")
            if attrs is not None:
                if attrs.findtext("divisions"):
                    divisions = Fraction(attrs.findtext("divisions"))
                if attrs.findtext("key/fifths"):
                    fifths = int(attrs.findtext("key/fifths"))
                if attrs.find("clef") is not None:
                    clef = (attrs.findtext("clef/sign"), attrs.findtext("clef/line"), attrs.findtext("clef/clef-octave-change") or "0")
                time = attrs.find("time")
                if time is not None:
                    try:
                        expected = sum(Fraction(n) for n in time.findtext("beats").split("+")) / Fraction(time.findtext("beat-type"))
                    except (TypeError, ValueError, ZeroDivisionError, AttributeError):
                        expected = None
            if entry is None or clef != ("G", "2", "0") or expected is None or divisions <= 0:
                continue
            number, system_index, stack_index, siblings = entry
            if len(siblings) != 1:
                continue
            staff = siblings[0]
            system = list(sheets[number].iter("system"))[system_index]
            omr_part = system.findall("part")[staff["part"]]
            if len(omr_part.findall("staff")) != 1:
                continue
            kept = _system_stacks(system, staff["interline"])
            position, stack, dropped = kept[stack_index]
            source = omr_part.findall("measure")[position]
            if dropped or source.get("abnormal") != "true":
                continue
            vertices = {n.get("id"): n for n in system.iter() if n.get("id") and n.find("bounds") is not None}
            staff_node = omr_part.find("staff")
            graph_clef = vertices.get(staff_node.findtext("header/clef"))
            if graph_clef is None or graph_clef.get("kind") != "TREBLE" or graph_clef.get("shape") != "G_CLEF":
                continue
            left, right, _heads = staff["measures"][stack_index]
            meter_evidence = None
            excluded = set()
            target_meter = expected
            initial_events = _book_events(system, source, staff["id"])
            if expected != 1 and initial_events and sum((e["duration"] for e in initial_events), Fraction(0)) != expected:
                if measure.find("attributes/time") is not None:
                    continue
                meter_evidence = _printed_four_four(book, number, staff, left)
                if meter_evidence is None:
                    continue
                target_meter = Fraction(1)
                _score, (x0, y0, x1, y1) = meter_evidence
                for identifier, vertex in vertices.items():
                    bounds = vertex.find("bounds")
                    if vertex.tag != "head" or bounds is None:
                        continue
                    x, y, w, h = (float(bounds.get(k)) for k in ("x", "y", "w", "h"))
                    if x0 <= x + w/2 <= x1 and y0 <= y + h/2 <= y1:
                        excluded.add(identifier)
            events = _book_events(system, source, staff["id"], excluded)
            old = measure.findall("note")
            if not events or not old or sum((e["duration"] for e in events), Fraction(0)) != target_meter:
                continue
            if any(n.find(t) is not None for n in old for t in ("chord", "grace", "cue", "time-modification")):
                continue
            if len({n.findtext("voice") or "1" for n in old}) != 1 or measure.find("forward") is not None:
                continue
            voices = [v for v in source.findall("voice") if v.findall("slots/entry")]
            if len(voices) != 1:
                continue
            exported = [v.get("chord") for v in voices[0].findall("slots/entry/value") if v.get("status") == "BEGIN"]
            if len(exported) != len(old) or len(set(exported)) != len(exported):
                continue
            old_by_id = dict(zip(exported, old))
            discarded = []
            for identifier in list(old_by_id):
                if any(other.get("id") in excluded for other, _rel in
                       [(vertices.get(r.get("target")), r[0]) for r in system.iter("relation")
                        if r.get("source") == identifier and r.find("containment") is not None]
                       if other is not None):
                    discarded.append(old_by_id.pop(identifier))
            if not old_by_id or (len(old_by_id) >= len(events) and meter_evidence is None):
                continue
            exported = list(old_by_id)
            if not set(exported).issubset(e["id"] for e in events):
                continue
            # Accidentals carry through the bar, but never guessed across a barline.
            accidental_state = {}
            safe = True
            for e in events:
                if e["pitch"] is not None:
                    step, octave = e["pitch"]
                    if e["alter"] is not None:
                        accidental_state[(step, octave)] = e["alter"]
                    e["resolved_alter"] = accidental_state.get((step, octave), _key_alter(step, fifths))
                ticks = e["duration"] * 4 * divisions
                if ticks.denominator != 1:
                    safe = False
                    break
                n = old_by_id.get(e["id"])
                if n is None:
                    if e["grade"] < (.85 if e["pitch"] is not None else .75):
                        safe = False
                        break
                    continue
                pitch = n.find("pitch")
                if (pitch is None) != (e["pitch"] is None) or Fraction(n.findtext("duration") or "0") != ticks:
                    safe = False
                    break
                if pitch is not None and ((pitch.findtext("step"), int(pitch.findtext("octave"))) != e["pitch"]
                                          or Fraction(pitch.findtext("alter") or "0") != e["resolved_alter"]):
                    safe = False
                    break
            if not safe:
                continue
            width = _float(measure.get("width"))
            if not width or right <= left:
                continue
            if meter_evidence is not None:
                attributes = measure.find("attributes")
                if attributes is None:
                    attributes = ET.Element("attributes")
                    measure.insert(next((i for i, n in enumerate(measure) if n.tag != "print"), 0), attributes)
                time = ET.Element("time")
                ET.SubElement(time, "beats").text = "4"
                ET.SubElement(time, "beat-type").text = "4"
                # attributes order: divisions, key, time, staves, clef, ...
                attributes.insert(next((i for i, n in enumerate(attributes) if n.tag not in ("divisions", "key")), len(attributes)), time)
                expected = target_meter
            for n in discarded:
                measure.remove(n)
            additions = []
            voice = old[0].findtext("voice") or "1"
            for e in events:
                n = old_by_id.get(e["id"])
                if n is None:
                    n = ET.Element("note")
                    if e["pitch"] is None:
                        ET.SubElement(n, "rest")
                    else:
                        pitch = ET.SubElement(n, "pitch")
                        ET.SubElement(pitch, "step").text = e["pitch"][0]
                        if e["resolved_alter"]:
                            ET.SubElement(pitch, "alter").text = str(e["resolved_alter"])
                        ET.SubElement(pitch, "octave").text = str(e["pitch"][1])
                    ET.SubElement(n, "duration").text = str(int(e["duration"] * 4 * divisions))
                    for kind in e["ties"]:
                        ET.SubElement(n, "tie", type=kind)
                    ET.SubElement(n, "voice").text = voice
                    ET.SubElement(n, "type").text = types[e["base"]]
                    for _ in range(e["dots"]):
                        ET.SubElement(n, "dot")
                    if e["alter"] is not None:
                        ET.SubElement(n, "accidental").text = {0: "natural", 1: "sharp", -1: "flat", 2: "double-sharp", -2: "flat-flat"}[e["alter"]]
                    if e["ties"]:
                        notations = ET.SubElement(n, "notations")
                        for kind in e["ties"]:
                            ET.SubElement(notations, "tied", type=kind)
                    additions.append(e["id"])
                e["note"] = n
                n.set("default-x", f"{(e['x'] - left) * width / (right - left):.3f}")
            # Preserve directions, harmonies, layout and existing note annotations.
            # Insert omitted events before the next existing event or right barline.
            pending = []
            for e in events:
                if e["id"] not in old_by_id:
                    pending.append(e["note"])
                    continue
                at = list(measure).index(e["note"])
                for n in pending:
                    measure.insert(at, n)
                    at += 1
                pending = []
            at = next((i for i, n in enumerate(measure) if n.tag in ("backup", "barline") and (n.tag == "backup" or n.get("location", "right") == "right")), len(measure))
            for n in pending:
                measure.insert(at, n)
                at += 1
            for backup in measure.findall("backup"):
                measure.remove(backup)
            changes.append({"part": part_index, "measureIndex": index, "measure": measure.get("number"),
                            "before": len(old), "after": len(events), "recoveredChordIds": additions,
                            "discardedTimeGlyphNotes": len(discarded),
                            "meterRecovered": "4/4" if meter_evidence is not None else None,
                            "meterImageScore": round(meter_evidence[0], 4) if meter_evidence is not None else None,
                            "evidence": "book-symbols/exact-meter/existing-notes-agree"})
        if len(changes) > first_change:
            # The engine may renumber its ONLY melody voice at a line break.
            # A restored tie then crosses voice 1 -> 2 and will not sustain
            # in players. Unify this verified single-staff, single-voice lane.
            normalized = []
            for index, measure in enumerate(all_measures):
                for note in measure.findall("note"):
                    voice = note.find("voice")
                    if voice is not None and voice.text != "1":
                        voice.text = "1"
                        if index not in normalized:
                            normalized.append(index)
            changes[first_change]["singleMelodyVoiceNormalized"] = normalized
    return changes


def _mean(values: list[float]) -> float:
    return sum(values) / len(values)


def _dropped_bar(stack: ET.Element, measures: list[ET.Element], interline: float) -> bool:
    """A real bar the engine took for the signature announced at the end of a line.

    Audiveris calls the last stack of a system cautionary when it read no note or rest
    in it, and leaves it out of the export. A true one is narrow and holds the key, time
    or clef to come; a bar of rhythm slashes, of a note it did not read, or an empty bar
    is as wide as a bar.
    """
    if stack.get("special") != "CAUTIONARY":
        return False
    left, right = _float(stack.get("left")), _float(stack.get("right"))
    if left is None or right is None or right - left < 5 * interline:
        return False
    return not any(m.find(tag) is not None for m in measures for tag in ("times", "keys", "clefs"))


def _system_stacks(system: ET.Element, interline: float) -> list[tuple[int, ET.Element, bool]]:
    """The stacks of a system that are bars of the score, as (position, stack, dropped).

    The cautionary stack at the end of a line is not a bar and is not exported; a bar the
    engine mistook for one is ([_dropped_bar]) and is put back by [_restore_dropped_bars].
    """
    stacks = system.findall("stack")
    parts = [part.findall("measure") for part in system.findall("part")]
    out = []
    for position, stack in enumerate(stacks):
        dropped = _dropped_bar(stack, [m[position] for m in parts if position < len(m)], interline)
        if stack.get("special") != "CAUTIONARY" or dropped:
            out.append((position, stack, dropped))
    return out


def _omr_staves(sheet: ET.Element) -> tuple[float, list[dict]]:
    """Interline and staves of one .omr sheet, each with its measures' heads."""
    interline = _float(sheet.find("scale/interline").get("main")) or 20.0
    chords = {chord.get("id"): chord for chord in sheet.iter("head-chord")}
    staves = []
    for system_index, system in enumerate(sheet.iter("system")):
        kept = _system_stacks(system, interline)
        for part_index, part in enumerate(system.findall("part")):
            every = part.findall("measure")
            stacks = [stack for position, stack, _dropped in kept if position < len(every)]
            measures = [every[position] for position, _stack, _dropped in kept if position < len(every)]
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


def _score_systems(part: ET.Element) -> list[list[int]]:
    """Measure indices of [part], one list per printed system."""
    groups: list[list[int]] = []
    for index, measure in enumerate(part.findall("measure")):
        layout = measure.find("print")
        if not groups or (layout is not None and "yes" in (
            layout.get("new-system"), layout.get("new-page"),
        )):
            groups.append([])
        groups[-1].append(index)
    return groups


def _restore_dropped_bars(root: ET.Element, folder: Path) -> list[dict]:
    """Put back the last bar of a line that the engine left out of the export.

    The .omr book next to the score still has the bar ([_dropped_bar]). It comes back
    empty, as the engine read nothing in it, so the bars after it keep their place, the
    chord line above it can be read, and the review lists it. Returns the bars added.
    """
    books = sorted(folder.glob("*.omr"))
    parts = root.findall("part")
    if len(books) != 1 or not parts:
        return []
    systems = []
    try:
        with zipfile.ZipFile(books[0]) as archive:
            book = ET.fromstring(archive.read("book.xml"))
            for sheet_entry in book.findall("sheet"):
                if sheet_entry.get("invalid") == "true":
                    continue
                number = sheet_entry.get("number")
                sheet = ET.fromstring(archive.read(f"sheet#{number}/sheet#{number}.xml"))
                interline = _float(sheet.find("scale/interline").get("main")) or 20.0
                systems += [(system, interline) for system in sheet.iter("system")]
    except (OSError, KeyError, ValueError, AttributeError, zipfile.BadZipFile, ET.ParseError):
        return []
    groups = _score_systems(parts[0])
    if len(systems) != len(groups):
        return []
    added = []
    # Last system first, so the measure indices before it stay true.
    for (system, interline), group in reversed(list(zip(systems, groups))):
        kept = _system_stacks(system, interline)
        if not kept or not kept[-1][2] or len(kept) != len(group) + 1 or any(d for _p, _s, d in kept[:-1]):
            continue
        stack = kept[-1][1]
        # Stack pixels to MusicXML tenths, from the bars of this line.
        pixels = sum(_float(s.get("right")) - _float(s.get("left")) for _p, s, _d in kept[:-1])
        for part in parts:
            measures = part.findall("measure")
            if group[-1] >= len(measures):
                continue
            tenths = sum(_float(measures[i].get("width")) or 0 for i in group)
            last = measures[group[-1]]
            width = (_float(stack.get("right")) - _float(stack.get("left"))) * tenths / pixels if pixels and tenths else 0
            bar = ET.Element("measure", {"number": "", "width": str(round(width))} if width else {"number": ""})
            bar.tail = last.tail
            part.insert(list(part).index(last) + 1, bar)
            _number_inserted(part, group[-1] + 1)
        added.append({"measureIndex": group[-1] + 1})
    if not added:
        return []
    added.reverse()
    measures = parts[0].findall("measure")
    for item in added:
        # Bars put back before this one moved it along.
        item["measureIndex"] += sum(1 for other in added if other["measureIndex"] < item["measureIndex"])
    for item in added:
        item["measure"] = measures[item["measureIndex"]].get("number")
    return added


def _number_inserted(part: ET.Element, index: int) -> None:
    """Number the measure put in at [index] one after the bar before it, and move the
    numbers after it along by one; the engine's own scheme (a pickup 0, "X12" for the
    second half of a split bar, a repeated number) stays as it was."""
    measures = part.findall("measure")
    before = (measures[index - 1].get("number") or "").lstrip("X") if index else "0"
    if not before.isdigit():
        return
    measures[index].set("number", str(int(before) + 1))
    for measure in measures[index + 1:]:
        old = measure.get("number") or ""
        digits = old.lstrip("X")
        if digits.isdigit():
            measure.set("number", old[: len(old) - len(digits)] + str(int(digits) + 1))


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
    groups = _score_systems(parts[0])
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
                    systems.append((number, system_index, system, staves, interline))
    except (OSError, KeyError, ValueError, AttributeError, zipfile.BadZipFile, ET.ParseError):
        return None
    if len(systems) != len(groups):
        return None
    unmatched = []
    for (number, system_index, system, staves, interline), group in zip(systems, groups):
        # The bars of the system: the signature announced at the end of a line is not one.
        if len(_system_stacks(system, interline)) != len(group):
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
