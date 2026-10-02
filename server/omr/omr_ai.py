"""AI review (OMR spec Phase 5): every placed measure against the original.

One question per staff line (system): the line's image, with the measure
numbers written in red above the bars, and what OMR read in each measure.
Asking per measure sent the same picture three times (previous, current,
next) and paid for an answer envelope per measure; a line is three to five
measures for one picture and one answer."""

from __future__ import annotations

import json
import os
import time

from pathlib import Path
from xml.etree import ElementTree as ET

from omr_score import _read_score, _write_mxl
from omr_rules import _harmony_element, _insert_lyric, _parse_chord_text
from omr_book import _load_book, _sung_note, _tied_on
from omr_validate import _measure_view, _validate_score


# --- AI review (OMR spec Phase 5): every placed measure against its crop -----

AI_MODEL = os.environ.get("OMR_AI_MODEL", "gemini-3.8-flash@low")
AI_WORKERS = int(os.environ.get("OMR_AI_WORKERS", "6"))
# A staff line is sent at most this wide: enough to read notes and Korean
# lyrics, and the picture's token cost is bounded.
AI_LINE_WIDTH = 1600
_NOTE_TYPES = {"whole": "w", "half": "h", "quarter": "q", "eighth": "8", "16th": "16", "32nd": "32"}


def _ai_enabled() -> bool:
    provider = AI_MODEL.split("-", 1)[0]
    key = {"gemini": "GEMINI_API_KEY", "qwen": "DASHSCOPE_API_KEY"}.get(provider, "OPENAI_API_KEY")
    return os.environ.get("OMR_AI", "1") != "0" and bool(os.environ.get(key))


def _notes_summary(measure: ET.Element) -> str:
    out = []
    for note in measure.findall("note"):
        if note.find("chord") is not None:
            continue
        kind = _NOTE_TYPES.get(note.findtext("type") or "", note.findtext("type") or "?")
        if note.find("dot") is not None:
            kind += "."
        if note.find("rest") is not None:
            out.append(f"rest {kind}")
            continue
        pitch = note.find("pitch")
        if pitch is None:
            continue
        alter = {"1": "#", "-1": "b"}.get(pitch.findtext("alter") or "", "")
        out.append(f"{pitch.findtext('step')}{alter}{pitch.findtext('octave')} {kind}")
    return ", ".join(out)


def _ai_summary(measure: ET.Element) -> dict:
    view = _measure_view(measure)
    return {"number": measure.get("number"), "chords": view["chords"],
            "lyrics": view["lyrics"], "notes": _notes_summary(measure)}


def _key_fifths(measures: list[ET.Element]) -> list[int]:
    """The key signature (fifths) in force at each measure."""
    fifths, keys = 0, []
    for measure in measures:
        value = measure.findtext("attributes/key/fifths")
        if value and value.strip().lstrip("-").isdigit():
            fifths = int(value)
        keys.append(fifths)
    return keys


def _ai_line(out: Path, item_id: str, group: list[tuple[int, int]], entry, images: dict,
             measures: list[ET.Element], fifths: int, flagged: dict[int, list[str]]) -> dict:
    """Save the picture of one staff line, its measure numbers written in red
    above the bars, and return the dataset item for its measures."""
    from PIL import Image, ImageDraw

    sheet, _system, _stack, staves = entry
    image, interline = images[sheet]
    bars = staves[0]["measures"]
    left = max(0, int(min(s["left"] for s in staves) - interline))
    right = min(image.width, int(max(s["right"] for s in staves) + interline))
    top = max(0, int(min(s["top"] for s in staves) - interline * 5))
    # 7 interlines cut off the second verse under some systems.
    bottom = min(image.height, int(max(s["bottom"] for s in staves) + interline * 10))
    crop = image.crop((left, top, right, bottom)).convert("RGB")
    scale = min(1.0, AI_LINE_WIDTH / max(1, crop.width))
    if scale < 1:
        crop = crop.resize((AI_LINE_WIDTH, max(1, round(crop.height * scale))), Image.LANCZOS)
    draw = ImageDraw.Draw(crop)
    for index, stack in group:
        x = (bars[stack][0] - left) * scale
        draw.line((x, 0, x, crop.height), fill=(220, 30, 30), width=2)
        draw.text((x + 4, 2), str(measures[index].get("number")), fill=(220, 30, 30))
    crop.save(out / "crops" / f"{item_id}.png")
    numbers = [measures[index].get("number") for index, _stack in group]
    return {"id": item_id, "song": "job", "measureIndex": [index for index, _ in group], "targets": numbers,
            "image": f"crops/{item_id}.png", "fifths": fifths,
            "measures": [_ai_summary(measures[index]) for index, _ in group],
            "issues": {str(measures[index].get("number")): flagged.get(index, []) for index, _ in group}}


def _ai_dataset(root: ET.Element, book: dict, out: Path) -> list[dict]:
    """A picture and the recognized content of every staff line of the first
    part that was placed on a page."""
    (out / "crops").mkdir(parents=True, exist_ok=True)
    measures = root.find("part").findall("measure")
    entries = book["placements"][0]
    images = {n: (image, interline) for n, _s, image, interline, _st in book["sheets"]}
    flagged: dict[int, list[str]] = {}
    for issue in _validate_score(root):
        if issue["part"] == 0:
            flagged.setdefault(issue["measureIndex"], []).append(f"{issue['rule']}: {issue['detail']}")
    keys = _key_fifths(measures)
    # Consecutive measures on the same staff line.
    lines: list[tuple[tuple, list[tuple[int, int]]]] = []
    for index, entry in enumerate(entries):
        if entry is None or index >= len(measures) or entry[0] not in images:
            continue
        key = (entry[0], id(entry[3][0]))
        if lines and lines[-1][0] == key:
            lines[-1][1].append((index, entry[2]))
        else:
            lines.append((key, [(index, entry[2])]))
    items = [
        _ai_line(out, f"s{n}", group, entries[group[0][0]], images, measures, keys[group[0][0]], flagged)
        for n, (_key, group) in enumerate(lines)
    ]
    (out / "dataset.json").write_text(json.dumps(items, ensure_ascii=False, indent=1), encoding="utf-8")
    return items


def _ai_prompt(item: dict) -> str:
    import ai_verify

    issues = "; ".join(f"measure {number}: {' | '.join(found)}" for number, found in item["issues"].items() if found)
    context = {"time": None, "fifths": item["fifths"], "issue": issues or "none"}
    text = ai_verify.describe_measures(item["measures"], context)
    return text + (
        f"\nThe picture is one staff line with measures {', '.join(map(str, item['targets']))}; "
        "their numbers are written in red above the bar they start. Check every one of these "
        "measures and give each correction its measure number."
    )


def _ai_ask(out: Path, items: list[dict], model: str) -> dict:
    import ai_verify
    from concurrent.futures import ThreadPoolExecutor

    def ask(item):
        text = _ai_prompt(item)
        for attempt in range(2):
            try:
                return item["id"], ai_verify.verify(out / item["image"], text, model)
            except Exception as error:  # noqa: BLE001 - one retry, then recorded per item
                last = str(error)[-300:]
        return item["id"], {"error": last}

    with ThreadPoolExecutor(AI_WORKERS) as pool:
        answers = dict(pool.map(ask, items))
    (out / f"answers-{model}.json").write_text(json.dumps(answers, ensure_ascii=False, indent=1), encoding="utf-8")
    return answers


def _hangul(text: str) -> list[str]:
    """The syllables of a lyric suggestion, one per sung note: Hangul, and a
    dash ("-" or "—") for a note that holds the syllable before it."""
    return [("—" if ch in "-—–" else ch) for ch in str(text or "") if "가" <= ch <= "힣" or ch in "-—–"]


def _chord_list(value) -> list[str]:
    """Chord symbols out of a model's answer, however it wrote the list. A
    chord in brackets, "(D7)", is an optional chord on the page: it counts."""
    if isinstance(value, list):
        value = " ".join(str(v) for v in value)
    for mark in "[]'\",()":
        value = str(value).replace(mark, " ")
    return value.split()


def _apply_ai_measure(measure: ET.Element, corrections: list[dict], fifths: int) -> list[dict]:
    """Apply chord and lyric suggestions to one measure; notes stay as they are
    (models often misplace pitches by a staff step)."""
    applied = []
    heads = [n for n in measure.findall("note") if n.find("chord") is None]
    for fix in corrections:
        if fix.get("field") == "chords":
            chords = [c for c in (_parse_chord_text(t, fifths) for t in _chord_list(fix.get("suggested"))) if c]
            if not chords:
                continue
            before = _measure_view(measure)["chords"]
            template = measure.find("harmony")
            for harmony in measure.findall("harmony"):
                measure.remove(harmony)
            anchors = heads or measure.findall("note")
            # In order, each before its note. Several chords on one note (a
            # whole note under "G C/G D/G") are spread over that note with
            # an offset, so they stand apart in the order written.
            placed: dict[int, list[ET.Element]] = {}
            for i, chord in enumerate(chords):
                element = _harmony_element(chord, template if template is not None else ET.Element("harmony"))
                at = min(len(anchors) - 1, round(i * len(anchors) / len(chords))) if anchors else -1
                target = anchors[at] if anchors else None
                measure.insert(list(measure).index(target) if target is not None else len(measure), element)
                placed.setdefault(at, []).append(element)
            for at, elements in placed.items():
                if at < 0 or len(elements) < 2:
                    continue
                try:
                    length = int(float(anchors[at].findtext("duration") or 0))
                except ValueError:
                    length = 0
                for n, element in enumerate(elements[1:], start=1):
                    for old in element.findall("offset"):
                        element.remove(old)
                    offset = ET.SubElement(element, "offset")
                    offset.text = str(round(length * n / len(elements)))
            after = _measure_view(measure)["chords"]
            if after != before:
                applied.append({"field": "chords", "before": before, "after": after,
                                "confidence": fix.get("confidence")})
        elif fix.get("field") == "lyrics":
            syllables = _hangul(fix.get("suggested"))
            verse = str(fix.get("verse") or "1").strip() or "1"
            if not syllables or syllables[0] == "—":
                # Nothing, or a dash where nothing is held yet.
                continue
            before = _measure_view(measure)["lyrics"].get(verse, "")
            sung = [n for n in measure.findall("note") if _sung_note(n)]

            def own(note):
                return [l for l in note.findall("lyric") if (l.get("number") or "1") == verse]

            def held(note):
                return _tied_on(note) or any((l.findtext("text") or "") == "—" for l in own(note))

            # The answer names every note, held ones with a dash; or, as the
            # older answers did, only the notes that get a new syllable.
            if len(syllables) == len(sung):
                targets = sung
                # A dash only goes where nothing is sung yet: on a note that
                # had no syllable, or held one already. Over a syllable it
                # would silence it; such an answer is listed for review only.
                if any(sy == "—" and own(n) and not held(n) for n, sy in zip(sung, syllables)):
                    continue
            else:
                targets = [n for n in sung if not held(n)]
                syllables = [sy for sy in syllables if sy != "—"]
                if len(syllables) != len(targets):
                    # Notes were lost or added: the syllables have no clean
                    # home, so the suggestion is listed for review only.
                    continue
            for note, syllable in zip(targets, syllables):
                for lyric in own(note):
                    note.remove(lyric)
                lyric = ET.Element("lyric", number=verse)
                ET.SubElement(lyric, "syllabic").text = "single"
                ET.SubElement(lyric, "text").text = syllable
                _insert_lyric(note, lyric)
            after = _measure_view(measure)["lyrics"].get(verse, "")
            if after != before:
                applied.append({"field": "lyrics", "verse": verse, "before": before, "after": after,
                                "confidence": fix.get("confidence")})
    return applied


def _same_as_recognized(measure: ET.Element, fix: dict) -> bool:
    """A suggestion that says what the measure already has (the model wrote
    the lyrics without the spaces, or the chords as one string) is none."""
    view = _measure_view(measure)
    if fix.get("field") == "lyrics":
        verse = str(fix.get("verse") or "1").strip() or "1"
        current = [sy for sy in _hangul(view["lyrics"].get(verse, "")) if sy != "—"]
        return current == [sy for sy in _hangul(fix.get("suggested")) if sy != "—"]
    if fix.get("field") == "chords":
        return _chord_list(fix.get("suggested")) == list(view["chords"])
    return False


def _ai_review(result: Path, folder: Path, outgoing: Path, model: str | None = None) -> dict:
    """Ask the vision model about every placed measure, write the AI version
    (chords and lyrics applied) and the full review for the app."""
    model = model or AI_MODEL
    started = time.monotonic()
    root = _read_score(result)
    book = _load_book(root, folder, ocr=False)
    if book is None:
        return {"status": "skipped", "reason": "book and score do not line up"}
    work = outgoing / "ai"
    items = _ai_dataset(root, book, work)
    answers = _ai_ask(work, items, model)
    return _ai_apply(root, items, answers, model, outgoing, started)


def _ai_apply(root: ET.Element, items: list[dict], answers: dict, model: str, outgoing: Path,
              started: float | None = None) -> dict:
    """Write ai.mxl and ai_review.json from the model's answers."""
    started = started if started is not None else time.monotonic()
    measures = root.find("part").findall("measure")
    suggestions, applied = [], []
    covered = failed = 0
    tokens_in = tokens_out = 0
    for item in items:
        answer = answers.get(item["id"]) or {}
        covered += len(item["targets"])
        if "error" in answer or "answer" not in answer:
            failed += len(item["targets"])
            continue
        tokens_in += answer.get("input_tokens") or 0
        tokens_out += answer.get("output_tokens") or 0
        for index, target in zip(item["measureIndex"], item["targets"]):
            target = str(target)
            mine = [c for c in answer["answer"].get("corrections", [])
                    if str(c.get("measure")) == target and not _same_as_recognized(measures[index], c)]
            unsure = [u for u in answer["answer"].get("uncertain", []) if str(u.get("measure")) == target]
            if mine or unsure:
                suggestions.append({"measureIndex": index, "measure": target,
                                    "corrections": mine, "uncertain": unsure})
            for change in _apply_ai_measure(measures[index], mine, item["fifths"]):
                applied.append({"measureIndex": index, "measure": target, **change})
    report = {
        "model": model, "measures": covered, "lines": len(items),
        "errors": failed, "input_tokens": tokens_in, "output_tokens": tokens_out,
        "seconds": round(time.monotonic() - started, 1),
        "applied": applied, "suggestions": suggestions,
        "note": ("Chord suggestions, and lyric suggestions whose syllables match the sung notes, are "
                 "applied in ai.mxl; note suggestions and the rest are listed only."),
    }
    if applied:
        _write_mxl(root, outgoing / "ai.mxl")
    (outgoing / "ai_review.json").write_text(json.dumps(report, ensure_ascii=False, indent=1), encoding="utf-8")
    return {k: report[k] for k in ("model", "measures", "lines", "errors", "input_tokens", "output_tokens", "seconds")} | {"applied": len(applied)}


# --- Piano accompaniment advice: a style per section, chords to look at again ---

ARRANGE_PATTERNS = ("held", "beats", "broken")
ARRANGE_REGISTERS = ("middle", "low")
ARRANGE_ROLES = ("intro", "verse", "prechorus", "chorus", "bridge", "interlude", "solo", "outro", "other")
ARRANGE_MAX_BRIEF = 60000

ARRANGE_INSTRUCTIONS = """You plan a simple piano accompaniment for a lead sheet: one melody line
with chord symbols, usually a worship or pop song. A rule engine writes the
notes (right hand: the chord in close position, left hand: the bass note). You
only choose how the right hand plays, for the whole song ("base") and for
sections that should differ from it, and you point out chord symbols that look
misread.

Right-hand patterns:
- held: the chord is struck once and held until the next chord. Calm, sparse:
  intros, endings, quiet verses, bars where the melody is busy.
- beats: the chord is struck again on every beat. Steady drive: choruses,
  faster songs.
- broken: the chord tones one after the other in eighth notes. Flowing:
  ballads, verses where the melody holds long notes.

Register of the right hand:
- middle: around middle C to the C above (the default).
- low: about a fourth lower. Choose it when the melody of the section lies
  mostly below E4, so the chords stay out of its way.

Sections: give "bar" as the first bar of a stretch that gets its own style;
the style holds until the next entry. Use the given section starts when there
are any, otherwise only split where the music clearly changes. Leave
"sections" empty when one style fits the whole song. Do not change style
more often than every four bars. "role" says what the stretch is (intro,
verse, prechorus, chorus, bridge, interlude, solo, outro, or other): the
other instruments (organ, strings, pad, brass) play a verse thin and a chorus
full by it, and the brass rests in verses and bridges.

Chords: the symbols come from optical music recognition and may be misread.
Suggest a correction only when a symbol is clearly implausible in the key and
against the melody notes of its bar, and name the symbol you expect, written
like F#m7, Bb/D, Esus4. "index" is the position of the symbol within its bar,
counted from 1. When unsure, suggest nothing: a wrong correction is worse
than none.

"note": one short sentence in Korean explaining the choice of style."""

_ARRANGE_STYLE = {
    "pattern": {"type": "string", "enum": list(ARRANGE_PATTERNS)},
    "register": {"type": "string", "enum": list(ARRANGE_REGISTERS)},
}

ARRANGE_SCHEMA = {
    "type": "object",
    "additionalProperties": False,
    "required": ["base", "sections", "chords", "note"],
    "properties": {
        "base": {
            "type": "object", "additionalProperties": False,
            "required": ["pattern", "register"], "properties": _ARRANGE_STYLE,
        },
        "sections": {
            "type": "array",
            "items": {
                "type": "object", "additionalProperties": False,
                "required": ["bar", "role", "pattern", "register"],
                "properties": {
                    "bar": {"type": "integer"},
                    "role": {"type": "string", "enum": list(ARRANGE_ROLES)},
                    **_ARRANGE_STYLE,
                },
            },
        },
        "chords": {
            "type": "array",
            "items": {
                "type": "object", "additionalProperties": False,
                "required": ["bar", "index", "suggested", "reason"],
                "properties": {
                    "bar": {"type": "integer"},
                    "index": {"type": "integer"},
                    "suggested": {"type": "string"},
                    "reason": {"type": "string", "description": "one short sentence in Korean"},
                },
            },
        },
        "note": {"type": "string"},
    },
}


def _arrange_style(raw) -> dict | None:
    if not isinstance(raw, dict):
        return None
    if raw.get("pattern") not in ARRANGE_PATTERNS or raw.get("register") not in ARRANGE_REGISTERS:
        return None
    return {"pattern": raw["pattern"], "register": raw["register"]}


def _arrange_clean(answer: dict, bars: int) -> dict:
    """Keep what fits a score of `bars` bars: known styles, bars that exist, readable chords."""
    sections = []
    seen = set()
    for raw in answer.get("sections") or []:
        style = _arrange_style(raw)
        bar = raw.get("bar") if isinstance(raw, dict) else None
        if style is None or not isinstance(bar, int) or isinstance(bar, bool):
            continue
        if bar < 1 or bar > bars or bar in seen:
            continue
        seen.add(bar)
        role = raw.get("role") if raw.get("role") in ARRANGE_ROLES else "other"
        sections.append({"bar": bar, "role": role, **style})
    sections.sort(key=lambda item: item["bar"])
    chords = []
    for raw in answer.get("chords") or []:
        if not isinstance(raw, dict):
            continue
        bar, index = raw.get("bar"), raw.get("index")
        suggested = str(raw.get("suggested") or "").strip()
        if not isinstance(bar, int) or not isinstance(index, int) or isinstance(bar, bool):
            continue
        if bar < 1 or bar > bars or index < 1 or _parse_chord_text(suggested, 0) is None:
            continue
        chords.append({"bar": bar, "index": index, "suggested": suggested,
                       "reason": str(raw.get("reason") or "")[:200]})
    return {
        "base": _arrange_style(answer.get("base")) or {"pattern": "held", "register": "middle"},
        "sections": sections,
        "chords": chords,
        "note": str(answer.get("note") or "")[:300],
    }


def _arrange_advice(brief: str, bars: int, model: str | None = None) -> dict:
    """Ask the model for accompaniment advice on the lead sheet described by `brief`."""
    import ai_verify

    model = model or AI_MODEL
    result = ai_verify.complete_json(ARRANGE_INSTRUCTIONS, brief, ARRANGE_SCHEMA, "arrangement", model)
    if result["answer"] is None:
        raise RuntimeError("the model did not answer in JSON")
    advice = _arrange_clean(result["answer"], bars)
    advice["usage"] = {key: result[key] for key in ("model", "latency", "input_tokens", "output_tokens")}
    return advice
