"""AI review (OMR spec Phase 5): every placed measure against its crop."""

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


def _ai_item(out: Path, item_id: str, index: int, entry, images: dict, measures: list[ET.Element],
             fifths: int, photo_crop=None, **fields) -> dict:
    """Save the crop for one measure (previous, current, next; current framed in
    red) and return its dataset item. photo_crop(sheet, box, size) may return a
    crop of the same region from another image, e.g. the uploaded photo."""
    from PIL import ImageDraw

    sheet, _system, stack, staves = entry
    image, interline = images[sheet]
    bars = staves[0]["measures"]
    first, last = max(0, stack - 1), min(len(bars) - 1, stack + 1)
    left, right = bars[first][0] - interline, bars[last][1] + interline
    top = min(s["top"] for s in staves) - interline * 5
    # 7 interlines cut off the second verse under some systems.
    bottom = max(s["bottom"] for s in staves) + interline * 10
    box = (max(0, int(left)), max(0, int(top)), min(image.width, int(right)), min(image.height, int(bottom)))
    crop = image.crop(box).convert("RGB")
    if photo_crop is not None:
        crop = photo_crop(sheet, box, crop.size) or crop
    a, b = bars[stack][0] - box[0], bars[stack][1] - box[0]
    ImageDraw.Draw(crop).rectangle((a + 2, 2, b - 2, crop.height - 3), outline=(220, 30, 30), width=3)
    crop.save(out / "crops" / f"{item_id}.png")
    shown = [measures[j] for j in range(index - (stack - first), index + (last - stack) + 1)]
    return {"id": item_id, **fields, "measureIndex": index, "target": measures[index].get("number"),
            "image": f"crops/{item_id}.png", "fifths": fifths,
            "measures": [_ai_summary(m) for m in shown], "current": _ai_summary(measures[index])}


def _ai_dataset(root: ET.Element, book: dict, out: Path) -> list[dict]:
    """A crop and the recognized content for every measure of the first part placed on a page."""
    (out / "crops").mkdir(parents=True, exist_ok=True)
    measures = root.find("part").findall("measure")
    entries = book["placements"][0]
    images = {n: (image, interline) for n, _s, image, interline, _st in book["sheets"]}
    flagged: dict[int, list[str]] = {}
    for issue in _validate_score(root):
        if issue["part"] == 0:
            flagged.setdefault(issue["measureIndex"], []).append(f"{issue['rule']}: {issue['detail']}")
    keys = _key_fifths(measures)
    items = [
        _ai_item(out, f"m{index}", index, entry, images, measures, keys[index], song="job",
                 kind="suspect" if index in flagged else "control", issues=flagged.get(index, []))
        for index, entry in enumerate(entries)
        if entry is not None and index < len(measures)
    ]
    (out / "dataset.json").write_text(json.dumps(items, ensure_ascii=False, indent=1), encoding="utf-8")
    return items


def _ai_prompt(item: dict) -> str:
    import ai_verify

    context = {"time": None, "fifths": item["fifths"], "issue": "; ".join(item["issues"]) or "none"}
    text = ai_verify.describe_measures(item["measures"], context)
    return text + f"\nThe measure framed in red is measure {item['target']}. Check that measure only."


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
    return [ch for ch in str(text or "") if "가" <= ch <= "힣"]


def _chord_list(value) -> list[str]:
    if isinstance(value, list):
        value = " ".join(str(v) for v in value)
    for mark in "[]'\",":
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
            for i, chord in reversed(list(enumerate(chords))):
                element = _harmony_element(chord, template if template is not None else ET.Element("harmony"))
                target = anchors[min(len(anchors) - 1, round(i * len(anchors) / len(chords)))] if anchors else None
                measure.insert(list(measure).index(target) if target is not None else len(measure), element)
            after = _measure_view(measure)["chords"]
            if after != before:
                applied.append({"field": "chords", "before": before, "after": after,
                                "confidence": fix.get("confidence")})
        elif fix.get("field") == "lyrics":
            syllables = _hangul(fix.get("suggested"))
            verse = str(fix.get("verse") or "1").strip() or "1"
            if not syllables:
                continue
            before = _measure_view(measure)["lyrics"].get(verse, "")
            sung = [n for n in measure.findall("note") if _sung_note(n) and not _tied_on(n)]
            targets, removed = [], []
            for note in sung:
                own = [l for l in note.findall("lyric") if (l.get("number") or "1") == verse]
                if any((l.findtext("text") or "") == "—" for l in own):
                    continue  # a held-syllable dash stays in place
                for lyric in own:
                    note.remove(lyric)
                removed.append((note, own))
                targets.append(note)
            if len(syllables) != len(targets):
                # Notes were lost or added: the syllables have no clean home,
                # so the suggestion is listed for review only.
                for note, lyrics in removed:
                    for lyric in lyrics:
                        _insert_lyric(note, lyric)
                continue
            for note, syllable in zip(targets, syllables):
                lyric = ET.Element("lyric", number=verse)
                ET.SubElement(lyric, "syllabic").text = "single"
                ET.SubElement(lyric, "text").text = syllable
                _insert_lyric(note, lyric)
            after = _measure_view(measure)["lyrics"].get(verse, "")
            if after != before:
                applied.append({"field": "lyrics", "verse": verse, "before": before, "after": after,
                                "confidence": fix.get("confidence")})
    return applied


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
    for item in items:
        answer = answers.get(item["id"]) or {}
        if "error" in answer:
            continue
        target = str(item["target"])
        mine = [c for c in answer["answer"].get("corrections", []) if str(c.get("measure")) == target]
        unsure = [u for u in answer["answer"].get("uncertain", []) if str(u.get("measure")) == target]
        if mine or unsure:
            suggestions.append({"measureIndex": item["measureIndex"], "measure": target,
                                "corrections": mine, "uncertain": unsure})
        for change in _apply_ai_measure(measures[item["measureIndex"]], mine, item["fifths"]):
            applied.append({"measureIndex": item["measureIndex"], "measure": target, **change})
    report = {
        "model": model, "measures": len(items),
        "errors": sum(1 for a in answers.values() if "error" in a),
        "seconds": round(time.monotonic() - started, 1),
        "applied": applied, "suggestions": suggestions,
        "note": ("Chord suggestions, and lyric suggestions whose syllables match the sung notes, are "
                 "applied in ai.mxl; note suggestions and the rest are listed only."),
    }
    if applied:
        _write_mxl(root, outgoing / "ai.mxl")
    (outgoing / "ai_review.json").write_text(json.dumps(report, ensure_ascii=False, indent=1), encoding="utf-8")
    return {k: report[k] for k in ("model", "measures", "errors", "seconds")} | {"applied": len(applied)}


# --- Piano accompaniment advice: a style per section, chords to look at again ---

ARRANGE_PATTERNS = ("held", "beats", "broken")
ARRANGE_REGISTERS = ("middle", "low")
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
more often than every four bars.

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
                "required": ["bar", "pattern", "register"],
                "properties": {"bar": {"type": "integer"}, **_ARRANGE_STYLE},
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
        sections.append({"bar": bar, **style})
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
