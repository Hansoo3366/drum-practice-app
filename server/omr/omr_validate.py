"""Rule-based validation, suspect crops, correction history and candidate inspection."""

from __future__ import annotations

import json

from fractions import Fraction
from pathlib import Path
from xml.etree import ElementTree as ET

from omr_score import PIPELINE, _read_score
from omr_rules import _BOTTOM_LINE, _CLEAN_WORDS, _DIATONIC, _INSTRUCTION_WORDS, _MAX_SUSPECT_IMAGES, _SEVERITY, _STEP_SEMITONE
from omr_book import _load_book


def _garbled_chord(text: str) -> bool:
    """A short token starting like a chord that is no known word ("DWF", "Elm")."""
    return any(
        len(token) <= 4 and token[0] in "ABCDEFG" and token.strip(".").lower() not in _INSTRUCTION_WORDS
        for token in text.split()
    )


def _midi(note: ET.Element) -> int | None:
    pitch = note.find("pitch")
    if pitch is None:
        return None
    try:
        return (int(pitch.findtext("octave") or "4") + 1) * 12 + _STEP_SEMITONE[
            pitch.findtext("step") or "C"
        ] + int(float(pitch.findtext("alter") or "0"))
    except (KeyError, ValueError):
        return None


def _validate_score(root: ET.Element) -> list[dict]:
    """Issues found by rules alone, per part and measure index."""
    issues: list[dict] = []

    def add(rule: str, part: int, index: int, measure: ET.Element, detail: str) -> None:
        issues.append({
            "rule": rule, "severity": _SEVERITY[rule], "part": part,
            "measureIndex": index, "measure": measure.get("number"), "detail": detail,
        })

    for part_index, part in enumerate(root.findall("part")):
        measures = part.findall("measure")
        divisions, expected = Fraction(1), None
        keys: list[tuple[int, int]] = []
        # Per voice and staff, notes sounding together: pitches and ties.
        onsets: dict[tuple, list[dict]] = {}
        for index, measure in enumerate(measures):
            cursor = extent = last_onset = Fraction(0)
            voices: dict[str, Fraction] = {}
            tuplets: dict[tuple, int] = {}
            for item in measure:
                if item.tag == "attributes":
                    if item.findtext("divisions"):
                        divisions = Fraction(item.findtext("divisions")) or Fraction(1)
                    time = item.find("time")
                    if time is not None and time.findtext("beats") and time.findtext("beat-type"):
                        try:
                            expected = sum(Fraction(v) for v in time.findtext("beats").split("+")) \
                                * 4 / Fraction(time.findtext("beat-type"))
                        except (ValueError, ZeroDivisionError):
                            expected = None
                    fifths = item.findtext("key/fifths")
                    if fifths and fifths.strip().lstrip("-").isdigit():
                        keys.append((index, int(fifths)))
                elif item.tag in ("backup", "forward"):
                    amount = Fraction(item.findtext("duration") or "0") / divisions
                    cursor += amount if item.tag == "forward" else -amount
                    extent = max(extent, cursor)
                elif item.tag == "note":
                    if item.find("grace") is not None or item.find("cue") is not None:
                        continue
                    duration = Fraction(item.findtext("duration") or "0") / divisions
                    chord = item.find("chord") is not None
                    onset = last_onset if chord else cursor
                    extent = max(extent, onset + duration)
                    voice = item.findtext("voice") or "1"
                    if not chord:
                        last_onset = cursor
                        cursor += duration
                        voices[voice] = voices.get(voice, Fraction(0)) + duration
                    modification = item.find("time-modification")
                    if modification is not None and not chord:
                        actual = modification.findtext("actual-notes") or "0"
                        tuplets[(voice, actual)] = tuplets.get((voice, actual), 0) + 1
                    midi = _midi(item)
                    if midi is None:
                        continue
                    lane = (voice, item.findtext("staff") or "1")
                    types = {t.get("type") for t in item.findall("tie")}
                    groups = onsets.setdefault(lane, [])
                    if chord and groups:
                        group = groups[-1]
                    else:
                        group = {"index": index, "measure": measure, "pitches": set(),
                                 "starts": set(), "stops": set(), "chord": False}
                        groups.append(group)
                    group["chord"] = group["chord"] or chord
                    group["pitches"].add(midi)
                    if "start" in types:
                        group["starts"].add(midi)
                    if "stop" in types:
                        group["stops"].add(midi)
            has_notes = any(n.find("rest") is None for n in measure.findall("note"))
            if expected is not None and measure.findall("note"):
                implicit = measure.get("implicit") == "yes" or (index == 0 and extent < expected)
                if extent > expected or (not implicit and extent != expected):
                    add("V001", part_index, index, measure,
                        f"measure lasts {float(extent):g} quarters, time signature wants {float(expected):g}")
                elif len(voices) > 1:
                    short = [v for v, total in voices.items() if 0 < total < expected]
                    if short:
                        add("V002", part_index, index, measure,
                            f"voice {', '.join(short)} does not fill the measure")
            for (voice, actual), count in tuplets.items():
                if actual.isdigit() and int(actual) > 1 and count % int(actual):
                    add("V004", part_index, index, measure,
                        f"{count} notes in {actual}-tuplets in voice {voice}")
            if not has_notes and 0 < index < len(measures) - 1:
                # Checked against the note heads on the page in _image_checks.
                measure.set("__empty__", "1")
        for groups in onsets.values():
            # V003: a tie must end on the same pitch at the next onset.
            for group, following in zip(groups, groups[1:] + [None]):
                missing = group["starts"] - (following["pitches"] if following else set())
                if missing:
                    add("V003", part_index, group["index"], group["measure"],
                        "tie start has no matching note at the next onset")
            # V006: in a melody line only (chords and octaves leap by nature),
            # a pitch far from the notes around it.
            if sum(g["chord"] for g in groups) > len(groups) * 0.1:
                continue
            line = [(max(g["pitches"]), g["index"], g["measure"]) for g in groups]
            for position, (midi, index, measure) in enumerate(line):
                window = [p for p, _, _ in line[max(0, position - 6):position + 7] if p != midi]
                if len(window) >= 6:
                    middle = sorted(window)[len(window) // 2]
                    if abs(midi - middle) > 12:
                        add("V006", part_index, index, measure,
                            f"pitch {midi} is {abs(midi - middle)} semitones from its neighbours")
        # V008: a key change undone within eight measures is usually a misread.
        for (at, fifths), (back, again) in zip(keys, keys[1:]):
            before = [f for i, f in keys if i < at]
            if before and again == before[-1] and back - at <= 8 and fifths != again:
                add("V008", part_index, at, measures[at],
                    f"key {fifths} for {back - at} measures between key {again}")
        for index, measure in enumerate(measures):
            for direction in measure.findall("direction"):
                text = " ".join(
                    "".join(w.text or "" for w in direction.iter("words")).split()
                )
                if text and (not _CLEAN_WORDS.fullmatch(text) or _garbled_chord(text)):
                    add("L001", part_index, index, measure, f"leftover text {text!r}")
        # V009: a lone voice's rest drawn on or beyond the outer staff lines is
        # usually a slur or tie arc read as a rest.
        clef = "G"
        for index, measure in enumerate(measures):
            clef = measure.findtext("attributes/clef/sign") or clef
            notes = measure.findall("note")
            if clef not in _BOTTOM_LINE or len({n.findtext("voice") or "1" for n in notes}) != 1:
                continue
            bottom = _BOTTOM_LINE[clef]
            for note in notes:
                rest = note.find("rest")
                step, octave = (rest.findtext("display-step"), rest.findtext("display-octave")) if rest is not None else (None, None)
                if step in _DIATONIC and octave and octave.isdigit():
                    position = int(octave) * 7 + _DIATONIC[step] - bottom
                    if position <= 0 or position >= 8:
                        add("V009", part_index, index, measure,
                            f"{note.findtext('type') or 'measure'} rest drawn at {step}{octave}, outside the staff")
                        break
    return issues


def _validate(path: Path, folder: Path) -> dict:
    """Write validation.json and suspect crops for one candidate folder."""
    root = _read_score(path)
    issues = _validate_score(root)
    book = _load_book(_read_score(path), folder, ocr=False)
    crops = folder / "suspects"
    if book is not None:
        issues += _image_checks(root, book)
        issues += _annotation_checks(root, book, _annotations(folder))
        crops.mkdir(exist_ok=True)
        _crop_suspects(book, issues, crops)
        try:
            _crop_systems(book, folder)
        except Exception:  # noqa: BLE001 - the originals are an extra; the report must not fail for them
            (folder / "layout.json").unlink(missing_ok=True)
    for measure in root.iter("measure"):
        measure.attrib.pop("__empty__", None)
    order = {"high": 0, "medium": 1, "low": 2}
    issues.sort(key=lambda i: (order[i["severity"]], i["part"], i["measureIndex"]))
    summary: dict[str, int] = {}
    for issue in issues:
        summary[issue["rule"]] = summary.get(issue["rule"], 0) + 1
    report = {"pipeline": PIPELINE, "summary": summary, "issues": issues}
    (folder / "validation.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8",
    )
    return summary


def _image_checks(root: ET.Element, book: dict) -> list[dict]:
    """V007 empty measures with heads on the page, S001 unmatched systems."""
    issues = []
    parts = root.findall("part")
    for part_index, (part, entries) in enumerate(zip(parts, book["placements"])):
        for index, (measure, entry) in enumerate(zip(part.findall("measure"), entries)):
            if entry is None or measure.get("__empty__") != "1":
                continue
            staff = entry[3][0]
            if staff["measures"][entry[2]][2]:
                issues.append({
                    "rule": "V007", "severity": _SEVERITY["V007"], "part": part_index,
                    "measureIndex": index, "measure": measure.get("number"),
                    "detail": f"no notes exported, {len(staff['measures'][entry[2]][2])} heads on the page",
                })
    first = parts[0].findall("measure") if parts else []
    for group, _sheet, _staves in book["unmatched"]:
        for index in group:
            if index < len(first):
                issues.append({
                    "rule": "S001", "severity": _SEVERITY["S001"], "part": 0,
                    "measureIndex": index, "measure": first[index].get("number"),
                    "detail": "the system's measures do not match the page; chords and lyrics were not read",
                })
    return issues


def _annotations(folder: Path) -> dict | None:
    """What was taken out of the upload before recognition, from the job folder."""
    try:
        return json.loads((folder.parent / "annotations.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None


def _annotation_checks(root: ET.Element, book: dict, annotations: dict | None) -> list[dict]:
    """A001: ink that touched print lay over the measure. What it covered was
    taken out with it and is not guessed (OMR spec MODULE-03)."""
    if not annotations:
        return []
    widths = {str(number): image.width for number, _s, image, _i, _st in book["sheets"]}
    pages = {str(page["page"]): page for page in annotations.get("pages", [])}
    boxes: dict[str, list[tuple[float, float, float, float]]] = {}
    for item in annotations.get("items", []):
        page = str(item.get("page"))
        if item.get("type") != "ink" or not item.get("touches_print"):
            continue
        if page not in widths or not pages.get(page, {}).get("width"):
            continue
        # The sheet is the page as the engine rendered it: another size.
        scale = widths[page] / pages[page]["width"]
        region = item["region"]
        boxes.setdefault(page, []).append((
            region["x"] * scale, region["y"] * scale,
            (region["x"] + region["width"]) * scale, (region["y"] + region["height"]) * scale,
        ))
    if not boxes:
        return []
    issues = []
    parts = root.findall("part")
    for part_index, (part, entries) in enumerate(zip(parts, book["placements"])):
        for index, (measure, entry) in enumerate(zip(part.findall("measure"), entries)):
            if entry is None:
                continue
            number, _system, stack, staves = entry
            covered = False
            for left, top, right, bottom in boxes.get(str(number), []):
                for staff in staves:
                    if stack >= len(staff["measures"]):
                        continue
                    bar_left, bar_right, _heads = staff["measures"][stack]
                    pad = staff["interline"] * 1.5
                    if (left < bar_right and right > bar_left
                            and top < staff["bottom"] + pad and bottom > staff["top"] - pad):
                        covered = True
            if covered:
                issues.append({
                    "rule": "A001", "severity": _SEVERITY["A001"], "part": part_index,
                    "measureIndex": index, "measure": measure.get("number"),
                    "detail": "a colour annotation lay over the measure; what it covered was not read",
                })
    return issues


def _crop_suspects(book: dict, issues: list[dict], folder: Path) -> None:
    """Crop the previous, current and next measure (or the whole system)."""
    systems = {}
    for group, sheet, staves in book["unmatched"]:
        for index in group:
            systems[index] = (sheet, staves, None)
    # Per crop: its file, and where in it the measure itself is (as fractions
    # of the width), since the crop shows its neighbours too.
    made: dict[tuple, tuple[str, list[float] | None]] = {}
    images = {number: (image, interline) for number, _s, image, interline, _st in book["sheets"]}
    for issue in issues:
        entries = book["placements"][issue["part"]] if issue["part"] < len(book["placements"]) else []
        index = issue["measureIndex"]
        entry = entries[index] if index < len(entries) else None
        if entry is not None:
            sheet, staves, stack = entry[0], entry[3], entry[2]
        elif index in systems:
            sheet, staves, stack = systems[index]
        else:
            continue
        key = (sheet, id(staves[0]), stack)
        if key not in made:
            if len(made) >= _MAX_SUSPECT_IMAGES:
                continue
            image, interline = images[sheet]
            bars = staves[0]["measures"]
            if stack is None or not bars:
                left, right = min(s["left"] for s in staves), max(s["right"] for s in staves)
            else:
                left = bars[max(0, stack - 1)][0]
                right = bars[min(len(bars) - 1, stack + 1)][1]
            top = min(s["top"] for s in staves) - interline * 5
            bottom = max(s["bottom"] for s in staves) + interline * 7
            name = f"p{sheet}-s{staves[0]['system'] + 1}-m{'all' if stack is None else stack + 1}.png"
            x0, x1 = max(0, int(left - interline)), min(image.width, int(right + interline))
            image.crop((x0, max(0, int(top)), x1, min(image.height, int(bottom)))).save(folder / name)
            focus = None
            if stack is not None and bars and x1 > x0:
                focus = [
                    round(min(1.0, max(0.0, (edge - x0) / (x1 - x0))), 4)
                    for edge in bars[stack][:2]
                ]
            made[key] = (name, focus)
        issue["image"], focus = made[key]
        if focus is not None:
            issue["focus"] = focus


# A staff line of the page is kept this wide at most: enough to read, and a
# song of three pages stays near a megabyte.
_SYSTEM_WIDTH = 1600


def _crop_systems(book: dict, folder: Path) -> None:
    """The original of every measure: each staff line of the page as one image
    (`systems/pN-sM[-partK].jpg`), and in `layout.json` for every measure of
    every part its image and where in it the measure is (fractions of the
    width). A measure that was not matched to the page has none."""
    from PIL import Image

    out = folder / "systems"
    out.mkdir(exist_ok=True)
    images = {number: (image, interline) for number, _s, image, interline, _st in book["sheets"]}
    made: dict[tuple, tuple[str, float, float]] = {}
    parts = []
    for part_index, entries in enumerate(book["placements"]):
        measures = []
        for entry in entries:
            if entry is None or entry[0] not in images:
                measures.append(None)
                continue
            sheet, stack, staves = entry[0], entry[2], entry[3]
            bars = staves[0]["measures"]
            if not bars or stack is None or stack >= len(bars):
                measures.append(None)
                continue
            key = (sheet, id(staves[0]))
            if key not in made:
                image, interline = images[sheet]
                left = max(0, int(min(s["left"] for s in staves) - interline))
                right = min(image.width, int(max(s["right"] for s in staves) + interline))
                top = max(0, int(min(s["top"] for s in staves) - interline * 5))
                bottom = min(image.height, int(max(s["bottom"] for s in staves) + interline * 7))
                if right <= left or bottom <= top:
                    measures.append(None)
                    continue
                name = f"p{sheet}-s{staves[0]['system'] + 1}" + (f"-part{part_index + 1}" if part_index else "") + ".jpg"
                strip = image.crop((left, top, right, bottom)).convert("L")
                if strip.width > _SYSTEM_WIDTH:
                    strip = strip.resize(
                        (_SYSTEM_WIDTH, max(1, round(strip.height * _SYSTEM_WIDTH / strip.width))), Image.LANCZOS,
                    )
                strip.save(out / name, quality=72, optimize=True)
                made[key] = (name, left, right)
            name, left, right = made[key]
            measures.append({
                "image": name,
                "focus": [
                    round(min(1.0, max(0.0, (edge - left) / (right - left))), 4)
                    for edge in bars[stack][:2]
                ],
            })
        parts.append(measures)
    (folder / "layout.json").write_text(
        json.dumps({"parts": parts}, ensure_ascii=False), encoding="utf-8",
    )


def _harmony_label(harmony: ET.Element) -> str:
    sign = {"1": "#", "-1": "b"}
    text = (harmony.findtext("root/root-step") or "") + sign.get(harmony.findtext("root/root-alter") or "", "")
    kind = harmony.find("kind")
    suffix = kind.get("text") if kind is not None else None
    if not suffix and kind is not None:
        suffix = {
            "minor": "m", "dominant": "7", "major-seventh": "maj7",
            "minor-seventh": "m7", "major-minor": "mM7", "diminished": "dim",
            "diminished-seventh": "dim7", "augmented": "aug",
            "augmented-seventh": "aug7", "half-diminished": "m7b5",
            "suspended-second": "sus2", "suspended-fourth": "sus4",
            "major-sixth": "6", "minor-sixth": "m6", "dominant-ninth": "9",
            "major-ninth": "maj9", "minor-ninth": "m9", "dominant-11th": "11",
            "minor-11th": "m11", "dominant-13th": "13", "power": "5",
        }.get(kind.text, "")
    text += suffix or ""
    bass = harmony.findtext("bass/bass-step")
    if bass:
        text += "/" + bass + sign.get(harmony.findtext("bass/bass-alter") or "", "")
    return text


def _measure_view(measure: ET.Element) -> dict:
    lyrics: dict[str, list[str]] = {}
    for note in measure.findall("note"):
        for lyric in note.findall("lyric"):
            lyrics.setdefault(lyric.get("number", "1"), []).append(lyric.findtext("text") or "")
    return {
        "chords": [_harmony_label(h) for h in measure.findall("harmony")],
        "lyrics": {verse: " ".join(texts) for verse, texts in sorted(lyrics.items())},
        "words": [
            "".join(w.text or "" for w in d.iter("words")).strip()
            for d in measure.findall("direction") if "".join(w.text or "" for w in d.iter("words")).strip()
        ],
    }


def _printed_measures(root: ET.Element) -> list[ET.Element]:
    """One measure per bar: the printed one when a staff was split into parts."""
    parts = [part.findall("measure") for part in root.findall("part")]
    if not parts:
        return []
    bars = []
    for index in range(len(parts[0])):
        choices = [measures[index] for measures in parts if index < len(measures)]
        bars.append(next((m for m in choices if m.get("width") is not None), choices[0]))
    return bars


def _corrections(raw: ET.Element, fixed: ET.Element) -> dict:
    """Before/after items of what the server changed (OMR spec §19).

    Compared bar by bar on the first part (the printed measure where a staff
    was split into parts), so the app can list and undo automatic changes.
    """
    items = []
    raw_parts, fixed_parts = len(raw.findall("part")), len(fixed.findall("part"))
    if raw_parts != fixed_parts:
        items.append({"kind": "parts", "before": raw_parts, "after": fixed_parts})
    raw_title, fixed_title = raw.findtext("movement-title"), fixed.findtext("movement-title")
    if raw_title != fixed_title:
        items.append({"kind": "title", "before": raw_title, "after": fixed_title})
    before_bars = _printed_measures(raw)
    after_bars = fixed.find("part").findall("measure") if fixed.find("part") is not None else []
    for index, (before, after) in enumerate(zip(before_bars, after_bars)):
        old, new = _measure_view(before), _measure_view(after)
        def rhythm(bar):
            return [{"pitch": [n.findtext("pitch/step"), n.findtext("pitch/alter") or "0", n.findtext("pitch/octave")],
                     "rest": n.find("rest") is not None, "duration": n.findtext("duration"),
                     "voice": n.findtext("voice") or "1", "staff": n.findtext("staff") or "1",
                     "chord": n.find("chord") is not None, "grace": n.find("grace") is not None,
                     "ties": sorted(t.get("type") or "" for t in n.findall("tie"))}
                    for n in bar.findall("note")]
        for kind, snapshots in (("rhythm", [rhythm(before), rhythm(after)]),
                                ("time", [[ET.tostring(t, encoding="unicode") for t in bar.findall("attributes/time")]
                                          for bar in (before, after)])):
            if snapshots[0] != snapshots[1]:
                items.append({"kind": kind, "measureIndex": index, "measure": after.get("number"),
                              "before": snapshots[0], "after": snapshots[1]})
        repeats = [
            any(r.get("direction") == "forward" for r in bar.iter("repeat")) for bar in (before, after)
        ]
        jumps = [
            sorted(" ".join("".join(w.text or "" for w in d.iter("words")).split())
                   or next((c.tag for t in d.findall("direction-type") for c in t), "")
                   for d in bar.findall("direction") if d.find("sound") is not None and d.find("sound").attrib)
            for bar in (before, after)
        ]
        if jumps[0] != jumps[1]:
            items.append({
                "kind": "navigation", "measureIndex": index, "measure": after.get("number"),
                "before": jumps[0], "after": jumps[1],
            })
        endings = [[e.get("number") for e in bar.iter("ending") if e.get("type") == "start"] for bar in (before, after)]
        if endings[0] != endings[1]:
            items.append({
                "kind": "ending", "measureIndex": index, "measure": after.get("number"),
                "before": endings[0], "after": endings[1],
            })
        marks = [len(bar.findall(".//articulations/*")) for bar in (before, after)]
        if marks[0] != marks[1]:
            items.append({
                "kind": "articulations", "measureIndex": index, "measure": after.get("number"),
                "before": marks[0], "after": marks[1],
            })
        if repeats[0] != repeats[1]:
            items.append({
                "kind": "repeat", "measureIndex": index, "measure": after.get("number"),
                "before": "dotted chord" if repeats[1] else "start repeat",
                "after": "start repeat" if repeats[1] else "dotted chord",
            })
        for kind in ("chords", "words"):
            if old[kind] != new[kind]:
                items.append({
                    "kind": kind, "measureIndex": index, "measure": after.get("number"),
                    "before": old[kind], "after": new[kind],
                })
        for verse in sorted(set(old["lyrics"]) | set(new["lyrics"])):
            if old["lyrics"].get(verse) != new["lyrics"].get(verse):
                items.append({
                    "kind": "lyrics", "measureIndex": index, "measure": after.get("number"),
                    "verse": verse, "before": old["lyrics"].get(verse, ""),
                    "after": new["lyrics"].get(verse, ""),
                })
    return {"source": f"server-rules/{PIPELINE}", "items": items}
