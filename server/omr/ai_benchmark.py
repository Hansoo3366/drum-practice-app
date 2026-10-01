"""Compare vision models on suspect measures (OMR spec Phase 3, §15-18).

    python3 ai_benchmark.py build  OUT SONG_DIR...   # crops + dataset.json
    python3 ai_benchmark.py run    OUT MODEL...      # answers per model
    python3 ai_benchmark.py score  OUT               # metrics against gold.json

A song directory holds one Audiveris book (*.omr), the exported score and the
server-corrected score (*.fixed.mxl, as the server keeps them). Items are the
measures the rule validator flags plus unflagged control measures, which
measure false corrections (§17: the metric that matters most).

gold.json maps item id to what the original prints in the target measure:
{"<id>": {"chords": ["F#m7", "A/C#"], "lyrics": {"1": "자격없는", "2": "..."}}}
"""

from __future__ import annotations

import json
import random
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import ai_verify
from omr_ai import _ai_item, _ai_prompt, _key_fifths
from omr_book import _load_book
from omr_score import _read_score
from omr_validate import _validate_score

def build(out: Path, songs: list[Path], controls_per_song: int = 3, max_per_song: int = 12,
          photos: bool = False) -> None:
    """With photos=True, crops come from SONG_DIR/pages/<sheet>.jpg (the upload) when present."""
    from PIL import Image

    out.mkdir(parents=True, exist_ok=True)
    (out / "crops").mkdir(exist_ok=True)
    random.seed(7)
    items = []
    for folder in songs:
        fixed = next(iter(sorted(folder.glob("*.fixed.mxl"))), None)
        if fixed is None:
            continue
        root = _read_score(fixed)
        issues = _validate_score(root)
        book = _load_book(_read_score(fixed), folder, ocr=False)
        if book is None:
            continue
        measures = root.find("part").findall("measure")
        entries = book["placements"][0]
        images = {n: (img, il) for n, _s, img, il, _st in book["sheets"]}
        originals = {} if photos else None
        flagged = {}
        for issue in issues:
            if issue["part"] == 0 and entries[issue["measureIndex"]] is not None:
                flagged.setdefault(issue["measureIndex"], []).append(f"{issue['rule']}: {issue['detail']}")
        picks = [(i, "suspect", flagged[i]) for i in sorted(flagged)]
        random.shuffle(picks)
        picks = picks[:max_per_song]
        clean = [i for i, e in enumerate(entries) if e is not None and i not in flagged and measures[i].findall("note")]
        picks += [(i, "control", []) for i in random.sample(clean, min(controls_per_song, len(clean)))]
        keys = _key_fifths(measures)

        def photo_crop(sheet, box, size):
            # Same region from the uploaded photo, in grey, instead of the binarized page.
            photo = originals.get(sheet)
            if photo is None:
                path = folder / "pages" / f"{sheet}.jpg"
                photo = originals[sheet] = Image.open(path).convert("L") if path.exists() else False
            if not photo:
                return None
            scale = photo.width / images[sheet][0].width
            area = tuple(round(v * scale) for v in box)
            return photo.crop(area).resize(size, Image.LANCZOS).convert("RGB")

        for index, kind, notes in picks:
            items.append(_ai_item(out, f"{folder.name}-m{index}", index, entries[index], images, measures,
                                    keys[index], photo_crop if photos else None,
                                    song=folder.name, kind=kind, issues=notes))
    (out / "dataset.json").write_text(json.dumps(items, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"{len(items)} items ({sum(i['kind'] == 'suspect' for i in items)} suspect)")


def run(out: Path, models: list[str], workers: int = 4) -> None:
    items = json.loads((out / "dataset.json").read_text(encoding="utf-8"))
    for model in models:
        path = out / f"answers-{model}.json"
        done = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}

        def ask(item):
            if item["id"] in done:
                return item["id"], done[item["id"]]
            try:
                return item["id"], ai_verify.verify(out / item["image"], _ai_prompt(item), model)
            except Exception as error:  # noqa: BLE001 - recorded per item
                return item["id"], {"error": str(error)}

        with ThreadPoolExecutor(workers) as pool:
            for item_id, answer in pool.map(ask, items):
                done[item_id] = answer
        path.write_text(json.dumps(done, ensure_ascii=False, indent=1), encoding="utf-8")
        errors = sum("error" in a for a in done.values())
        print(f"{model}: {len(done)} answers, {errors} errors")


def _norm_chords(chords) -> list[str]:
    # Models sometimes return the list as one string ("['F', 'G7']").
    if isinstance(chords, str):
        chords = [chords]
    flat = []
    for chord in chords:
        flat += str(chord).replace("[", " ").replace("]", " ").replace("'", " ") \
            .replace('"', " ").replace(",", " ").split()
    return [c.replace("♯", "#").replace("♭", "b").replace("maj7", "M7") for c in flat]


def _norm_lyric(text: str) -> str:
    return "".join(ch for ch in (text or "") if "가" <= ch <= "힣")


def _verse_for(suggested: str, verse, truth: dict) -> str:
    """Model verse numbers are unreliable; pair with the closest gold verse."""
    verses = list(truth.get("lyrics", {})) or ["1"]
    if len(verses) == 1:
        return verses[0]
    text = _norm_lyric(suggested)
    best = max(verses, key=lambda v: sum(ch in _norm_lyric(truth["lyrics"][v]) for ch in text))
    return best if text else str(verse or "1")


def score(out: Path) -> None:
    items = {i["id"]: i for i in json.loads((out / "dataset.json").read_text(encoding="utf-8"))}
    gold = {}
    for path in sorted(out.glob("gold*.json")):
        if path.name.startswith("gold_todo"):
            continue
        gold.update(json.loads(path.read_text(encoding="utf-8")))
    gold = {k: v for k, v in gold.items() if not v.get("unreadable")}
    for path in sorted(out.glob("answers-*.json")):
        answers = json.loads(path.read_text(encoding="utf-8"))
        m = {"fields": 0, "wrong_before": 0, "fixed": 0, "false_correction": 0, "bad_fix": 0,
             "missed": 0, "invalid": 0, "latency": 0.0, "in": 0, "out": 0, "calls": 0}
        for item_id, truth in gold.items():
            item, answer = items.get(item_id), answers.get(item_id)
            if item is None or answer is None or "error" in answer:
                continue
            m["calls"] += 1
            m["latency"] += answer["latency"]
            m["in"] += answer["input_tokens"]
            m["out"] += answer["output_tokens"]
            m["invalid"] += not answer["valid_json"]
            target = item["target"]
            fixes = [c for c in answer["answer"]["corrections"] if str(c["measure"]) == str(target)]
            current = item["current"]
            # Fields: the chord list, and each verse of lyrics.
            fields = [("chords", None, _norm_chords(current["chords"]), _norm_chords(truth.get("chords", [])))]
            verses = set(truth.get("lyrics", {})) | set(current["lyrics"])
            fields += [("lyrics", v, _norm_lyric(current["lyrics"].get(v, "")),
                        _norm_lyric(truth.get("lyrics", {}).get(v, ""))) for v in sorted(verses)]
            for field, verse, now, right in fields:
                m["fields"] += 1
                fix = next((c for c in fixes if c["field"] == field
                            and (field != "lyrics" or _verse_for(c["suggested"], c["verse"], truth) == verse)), None)
                after = now if fix is None else (
                    _norm_chords(fix["suggested"]) if field == "chords" else _norm_lyric(fix["suggested"]))
                if now != right:
                    m["wrong_before"] += 1
                    if after == right:
                        m["fixed"] += 1
                    elif fix is None:
                        m["missed"] += 1
                    else:
                        m["bad_fix"] += 1
                elif after != right:
                    m["false_correction"] += 1
        calls = max(1, m["calls"])
        print(json.dumps({
            "model": path.stem[len("answers-"):], "items": m["calls"], "fields": m["fields"],
            "wrong_before": m["wrong_before"], "fixed": m["fixed"], "missed": m["missed"],
            "bad_fix": m["bad_fix"], "false_correction": m["false_correction"],
            "false_correction_rate": round(m["false_correction"] / max(1, m["fields"] - m["wrong_before"]), 3),
            "correction_accuracy": round(m["fixed"] / max(1, m["wrong_before"]), 3),
            "invalid_json": m["invalid"], "avg_latency_s": round(m["latency"] / calls, 1),
            "avg_input_tokens": m["in"] // calls, "avg_output_tokens": m["out"] // calls,
        }, ensure_ascii=False))


if __name__ == "__main__":
    command, target = sys.argv[1], Path(sys.argv[2])
    if command == "build":
        build(target, [Path(p) for p in sys.argv[3:]])
    elif command == "run":
        run(target, sys.argv[3:])
    elif command == "score":
        score(target)
