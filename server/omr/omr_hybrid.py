"""Notes from a second reader, words from this one.

The engine misses barlines and notes on phone photos of lead sheets, and everything the
server reads afterwards (chord symbols, lyrics, repeats) is hung on the notes it did read.
homr reads the bars and notes of such pages far better and reads no words at all. Here the
two are put together, staff line by staff line: homr's bars and notes take the place of
the engine's, each given the place on the page where it stands, and what the engine's bars
carried (chords, words, repeats and endings) is moved to the bar it stands in. The reading
of chord symbols and lyrics that follows then works on these notes as it did on the
engine's.

Off unless OMR_HYBRID_NOTES=1. A line that does not line up (homr did not see it, or its
barlines do not come to its bars) stays as the engine read it; the score is never left
half done. Where the bars and notes of a reread line stand on the page is written next to
the book (hybrid.json): omr_book._load_book ties the score to the page by it.
"""
from __future__ import annotations

import bisect
import copy
import json
import math
import os
import subprocess
import time
from pathlib import Path
from xml.etree import ElementTree as ET

from omr_rules import _key_alter

MARK = "omr-"
SIDECAR = "hybrid.json"
_CARRIED = ("key", "time", "clef")
# Two readers place the same barline within about half a percent of the staff's length.
_SAME_BARLINE = 0.012
# Lines of one page lie several percent of its height apart.
_SAME_LINE = 0.03


def _python() -> str:
    return os.environ.get("OMR_HOMR_PYTHON", "").strip()


def enabled() -> bool:
    return os.environ.get("OMR_HYBRID_NOTES", "").strip() == "1"


def unfit(root: ET.Element) -> str | None:
    """Why this score is not one for the second reader (it reads one staff of one part: a
    melody line), or None."""
    parts = root.findall("part")
    if len(parts) != 1:
        return "more than one part"
    if not parts[0].findall("measure"):
        return "no bars"
    if any(int(_number(note.findtext("staff"), 1)) > 1 for note in parts[0].iter("note")):
        return "more than one staff"
    return None


def _sheet_images(path: Path, book: dict) -> dict[str, bytes]:
    """Per sheet, the picture homr reads: the photo that was uploaded (homr was taught on
    photos), else the page as the engine saw it."""
    import io
    from omr_marks import _pdf_photos

    out: dict[str, bytes] = {}
    sheets = book["sheets"]
    upload = next(iter(sorted((path.parent.parent.parent / "in").glob("score.*"))), None)
    try:
        if upload is not None and upload.suffix.lower() in (".jpg", ".jpeg", ".png") and len(sheets) == 1:
            out[sheets[0][0]] = upload.read_bytes()
        elif upload is not None and upload.suffix.lower() == ".pdf":
            photos = _pdf_photos(upload)
            for number, *_rest in sheets:
                index = int(number) - 1 if str(number).isdigit() else -1
                if 0 <= index < len(photos):
                    out[number] = photos[index]
    except OSError:
        out = {}
    for number, _sheet, image, _interline, _staves in sheets:
        if number not in out:
            data = io.BytesIO()
            image.save(data, format="PNG")
            out[number] = data.getvalue()
    return out


def read_sheets(path: Path, book: dict, budget: float | None = None) -> dict:
    """Have homr read every sheet of the book that it has not read yet for this job; the
    two resolutions the engine tries share what it reads. [path] is the engine's export.
    Says how many sheets it read and how long that took; a sheet it fails on is left out,
    and the lines of that sheet stay the engine's."""
    python = _python()
    script = Path(__file__).with_name("homr_sheet.py")
    if not python or not Path(python).is_file() or not script.is_file():
        return {"status": "off", "reason": "OMR_HOMR_PYTHON is not set to homr's Python"}
    target = path.parent.parent / "homr"
    target.mkdir(parents=True, exist_ok=True)
    limit = _number(os.environ.get("OMR_HOMR_SHEET_SECONDS"), 240.0)
    started = time.monotonic()
    read, failed = 0, []
    images = None
    for number, *_rest in book["sheets"]:
        stem = target / f"sheet{number}"
        if stem.with_suffix(".musicxml").is_file() and stem.with_suffix(".json").is_file():
            continue
        if stem.with_suffix(".failed").is_file():
            failed.append(number)
            continue
        left = limit if budget is None else min(limit, budget - (time.monotonic() - started))
        if left < 20:
            failed.append(number)
            continue
        if images is None:
            images = _sheet_images(path, book)
        data = images.get(number)
        picture = stem.with_suffix(".jpg" if data[:3] == b"\xff\xd8\xff" else ".png")
        picture.write_bytes(data)
        try:
            done = subprocess.run(
                [python, str(script), str(picture)], capture_output=True, text=True, timeout=left, check=False,
            )
            ok = done.returncode == 0 and stem.with_suffix(".json").is_file() and stem.with_suffix(".musicxml").is_file()
            if not ok:
                stem.with_suffix(".log").write_text((done.stderr or "")[-4000:], encoding="utf-8")
        except (OSError, subprocess.TimeoutExpired) as error:
            ok = False
            stem.with_suffix(".log").write_text(str(error)[-2000:], encoding="utf-8")
        picture.unlink(missing_ok=True)
        if ok:
            read += 1
        else:
            # Not again for the engine's second resolution: it would fail the same way.
            stem.with_suffix(".musicxml").unlink(missing_ok=True)
            stem.with_suffix(".json").unlink(missing_ok=True)
            stem.with_suffix(".failed").write_text("", encoding="utf-8")
            failed.append(number)
    return {"status": "done", "sheets_read": read, "sheets_failed": failed,
            "seconds": round(time.monotonic() - started, 1)}


def _number(text, default: float = 0.0) -> float:
    try:
        return float(text)
    except (TypeError, ValueError):
        return default


def strip(root: ET.Element) -> None:
    """Take out what was written on the score for the steps in between: where homr's notes
    stand is a matter of the page, not of the score."""
    for measure in root.iter("measure"):
        if measure.attrib.pop(MARK + "reread", None) is None:
            continue
        measure.attrib.pop("width", None)
        for note in measure.findall("note"):
            note.attrib.pop("default-x", None)


def _lines(measures: list[ET.Element]) -> list[list[ET.Element]]:
    out: list[list[ET.Element]] = []
    for index, measure in enumerate(measures):
        mark = measure.find("print")
        if index == 0 or (
            mark is not None and (mark.get("new-system") == "yes" or mark.get("new-page") == "yes")
        ):
            out.append([])
        out[-1].append(measure)
    return out


def _onsets(measure: ET.Element) -> list[tuple[ET.Element, float]]:
    """The notes of a bar that begin something, each with when in the bar it begins (0 to 1)."""
    found, cursor, end = [], 0.0, 0.0
    for child in measure:
        if child.tag in ("backup", "forward"):
            step = _number(child.findtext("duration"))
            cursor += step if child.tag == "forward" else -step
        elif child.tag == "note" and child.find("grace") is None:
            if child.find("chord") is not None:
                continue
            if child.find("rest") is None:
                found.append((child, cursor))
            cursor += _number(child.findtext("duration"))
        end = max(end, cursor)
    return [(note, start / end if end > 0 else 0.0) for note, start in found]


def _rests(measure: ET.Element) -> list[tuple[ET.Element, float]]:
    """The rests of a bar, each with when in the bar it begins (0 to 1)."""
    found, cursor, end = [], 0.0, 0.0
    for child in measure:
        if child.tag in ("backup", "forward"):
            step = _number(child.findtext("duration"))
            cursor += step if child.tag == "forward" else -step
        elif child.tag == "note" and child.find("grace") is None and child.find("chord") is None:
            if child.find("rest") is not None:
                found.append((child, cursor))
            cursor += _number(child.findtext("duration"))
        end = max(end, cursor)
    return [(note, start / end if end > 0 else 0.0) for note, start in found]


def boundaries(barlines: list[float], bars: int, known: list[float] | None = None) -> list[float] | None:
    """Where the bars of a line divide (0 to 1 along the staff), from the barlines homr saw:
    as many as the line has bars less one, or None when what it saw does not come to that.

    [known] are the barlines the engine saw on the same staff. A line homr saw too many of
    is one of those the engine did not see (a repeat sign after the clef, a stem); one homr
    did not see is added where the engine saw one."""
    inner: list[float] = []
    for x in sorted(barlines):
        if not 0.02 < x < 0.98:
            continue
        if inner and x - inner[-1] < 0.025:
            inner[-1] = (inner[-1] + x) / 2  # a double line
        else:
            inner.append(x)
    need = bars - 1
    known = [x for x in sorted(known or []) if 0.02 < x < 0.98]

    def apart(x: float, others: list[float]) -> float:
        return min((abs(x - other) for other in others), default=math.inf)

    if len(inner) > need and known:
        doubtful = sorted((x for x in inner if apart(x, known) > _SAME_BARLINE),
                          key=lambda x: -apart(x, known))
        if len(inner) - len(doubtful) <= need:
            for x in doubtful[: len(inner) - need]:
                inner.remove(x)
    # A repeat sign after the clef is a line too, and no end of a bar.
    while len(inner) > need and inner and inner[0] < 0.16:
        inner.pop(0)
    while len(inner) > need and inner and inner[-1] > 0.95:
        inner.pop()
    if len(inner) < need:
        missed = [x for x in known if apart(x, inner) > 0.03]
        if len(inner) + len(missed) == need:
            inner = sorted(inner + missed)
    return inner if len(inner) == need else None


def _calibrate(divides: list[float], barlines: list[float], known: list[float]) -> list[float]:
    """[divides], which are where homr saw them along its own staff, as places along the
    engine's staff: the words were measured there, and the two do not begin a staff at quite
    the same point. A barline both saw is where the engine saw it; the others are moved as
    those were."""
    pairs = []
    for mine in known + [1.0]:
        near = min(barlines, key=lambda x: abs(x - mine), default=None)
        if near is not None and abs(near - mine) < 0.03:
            pairs.append((near, mine))
    if not pairs:
        return list(divides)
    mean_h = sum(h for h, _ in pairs) / len(pairs)
    mean_k = sum(k for _, k in pairs) / len(pairs)
    spread = sum((h - mean_h) ** 2 for h, _ in pairs)
    scale = sum((h - mean_h) * (k - mean_k) for h, k in pairs) / spread if spread > 0.01 else 1.0
    if not 0.9 < scale < 1.1:
        scale = 1.0
    out = []
    for x in divides:
        seen = min(pairs, key=lambda pair: abs(pair[0] - x))
        out.append(seen[1] if abs(seen[0] - x) < 0.004 else mean_k + scale * (x - mean_h))
    return out if all(a < b for a, b in zip(out, out[1:])) else list(divides)


def _pitch(note: ET.Element) -> tuple | None:
    pitch = note.find("pitch")
    if pitch is None:
        return None
    return pitch.findtext("step"), pitch.findtext("alter") or "0", pitch.findtext("octave")


def _ties_from_slurs(measures: list[ET.Element]) -> int:
    """homr writes a tie as a slur. A slur from a note to the next note, of the same pitch,
    is a tie: the second note is held, not sung again."""
    made = 0
    started: dict[str, ET.Element] = {}
    between: dict[str, int] = {}
    for measure in measures:
        for note in measure.findall("note"):
            if note.find("chord") is not None or note.find("grace") is not None:
                continue
            if note.find("rest") is None:
                for number in between:
                    between[number] += 1
            for slur in note.findall("notations/slur"):
                number = slur.get("number") or "1"
                if slur.get("type") == "stop":
                    first = started.pop(number, None)
                    apart = between.pop(number, 0)
                    if first is None or apart != 1 or _pitch(first) is None or _pitch(first) != _pitch(note):
                        continue
                    for which, kind in ((first, "start"), (note, "stop")):
                        marks = which.find("notations")
                        for other in marks.findall("slur"):
                            if (other.get("number") or "1") == number and other.get("type") == kind:
                                marks.remove(other)
                                break
                        marks.insert(0, ET.Element("tied", type=kind))
                        tie = ET.Element("tie", type=kind)
                        after = which.find("duration")
                        children = list(which)
                        which.insert(children.index(after) + 1 if after is not None else len(children), tie)
                    made += 1
                elif slur.get("type") == "start":
                    started[number] = note
                    between[number] = 0
    return made


def _load_pages(folder: Path, sheets: list[str]) -> dict[str, dict]:
    """What homr read of each sheet: its bars line by line, and where it saw the staves and
    barlines. From <folder>/homr/sheet<N>.musicxml and .json; a sheet it did not read, or
    whose staves do not come to its lines, is left out."""
    pages = {}
    for number in sheets:
        # Read once for the job, next to the folders of the engine's tries.
        home = next((base / "homr" for base in (folder, folder.parent)
                     if (base / "homr" / f"sheet{number}.json").is_file()), None)
        if home is None:
            continue
        score, seen = home / f"sheet{number}.musicxml", home / f"sheet{number}.json"
        if not score.is_file():
            continue
        try:
            root = ET.fromstring(score.read_bytes())
            page = json.loads(seen.read_text())
            staffs, size = page["staffs"], page.get("image") or [0, 0]
        except (ET.ParseError, ValueError, KeyError, OSError):
            continue
        part = root.find("part")
        measures = part.findall("measure") if part is not None else []
        lines = _lines(measures)
        if not measures or len(lines) != len(staffs):
            continue
        for line in lines:
            # The repeat sign after the clef ends no bar: what homr wrote before it (the
            # clef, the key) belongs to the bar after it.
            while len(line) > 1 and not line[0].findall("note"):
                empty = line.pop(0)
                kept = [child for child in empty if child.tag in ("print", "attributes")]
                for child in reversed(kept):
                    line[0].insert(0, child)
        _ties_from_slurs([measure for line in lines for measure in line])
        height = _number(size[1]) if len(size) == 2 else 0.0
        pages[number] = {
            "lines": lines, "staffs": staffs,
            "down": [(_number(s.get("y1")) + _number(s.get("y2"))) / 2 / height if height > 0 else None
                     for s in staffs],
        }
    return pages


def _match_lines(mine: list[float], theirs: list[float | None]) -> list[int | None]:
    """For each of the engine's lines of a page (how far down the page each is, 0 to 1), the
    line of homr's that is the same staff, or None. The two do not see the page in the same
    frame (homr crops a photo to the sheet), so heights are compared after the stretch and
    shift that brings most lines together; as many lines on both sides are the same lines."""
    if len(mine) == len(theirs):
        return list(range(len(mine)))
    if any(value is None for value in theirs) or len(mine) < 2 or len(theirs) < 2:
        return [None] * len(mine)
    gaps = sorted(b - a for a, b in zip(mine, mine[1:]))
    near = max(1e-4, gaps[len(gaps) // 2] * 0.3)
    best: list[int | None] = [None] * len(mine)
    most = 1
    for i0 in range(len(mine)):
        for i1 in range(i0 + 1, len(mine)):
            for j0 in range(len(theirs)):
                for j1 in range(j0 + (i1 - i0), len(theirs)):
                    scale = (mine[i1] - mine[i0]) / (theirs[j1] - theirs[j0]) if theirs[j1] != theirs[j0] else 0.0
                    if not 0.5 < scale < 2.0:
                        continue
                    moved = [mine[i0] + (y - theirs[j0]) * scale for y in theirs]
                    out: list[int | None] = []
                    used = -1
                    for down in mine:
                        pick = min(range(used + 1, len(moved)), key=lambda k: abs(moved[k] - down), default=None)
                        if pick is not None and abs(moved[pick] - down) <= near:
                            out.append(pick)
                            used = pick
                        else:
                            out.append(None)
                    count = sum(1 for value in out if value is not None)
                    if count > most:
                        best, most = out, count
    return best


def _place_notes(times: list[float], heads: list[float], left: float, right: float,
                 interline: float, first: bool) -> list[float]:
    """Page x of the notes of a bar that begin at [times] (0 to 1, rising), from the note
    heads the engine saw in that bar: head for note where there are as many, else each note
    the head nearest where its time puts it, and the notes without a head in between."""
    if not times:
        return []
    heads = sorted(heads)
    if len(heads) == len(times):
        return list(heads)
    if len(heads) >= 2:
        low, high = heads[0], heads[-1]
    else:
        # The first bar of a line begins after the clef and the key.
        low = left + (right - left) * (0.3 if first else 0.12)
        high = right - (right - left) * 0.12
        if heads:
            low = min(low, heads[0])
            high = max(high, heads[0])
    reach = times[-1] - times[0]
    guess = [low + (high - low) * ((t - times[0]) / reach if reach > 0 else 0.0) for t in times]
    # Notes and heads in order, each pair at most once; leaving one out costs a head's reach.
    skip = interline * 1.5
    count, room = len(times), len(heads)
    best = [[0.0] * (room + 1) for _ in range(count + 1)]
    for i in range(1, count + 1):
        best[i][0] = best[i - 1][0] + skip
    for i in range(1, count + 1):
        for j in range(1, room + 1):
            best[i][j] = min(best[i - 1][j] + skip, best[i][j - 1],
                             best[i - 1][j - 1] + abs(guess[i - 1] - heads[j - 1]))
    xs: list[float | None] = [None] * count
    i, j = count, room
    while i > 0 and j > 0:
        if best[i][j] == best[i - 1][j - 1] + abs(guess[i - 1] - heads[j - 1]):
            xs[i - 1] = heads[j - 1]
            i, j = i - 1, j - 1
        elif best[i][j] == best[i][j - 1]:
            j -= 1
        else:
            i -= 1
    known = [(times[k], x) for k, x in enumerate(xs) if x is not None]
    for k in range(count):
        if xs[k] is not None:
            continue
        before = [(t, x) for t, x in known if t < times[k]]
        after = [(t, x) for t, x in known if t > times[k]]
        if before and after:
            (t0, x0), (t1, x1) = before[-1], after[0]
            xs[k] = x0 + (x1 - x0) * (times[k] - t0) / (t1 - t0)
        else:
            xs[k] = guess[k]
    # In order and apart, inside the bar.
    out: list[float] = []
    for x in xs:
        x = min(max(x, left + 1.0), right - 1.0)
        out.append(max(x, out[-1] + 1.0) if out else x)
    return out


def _line(engine: list[tuple[ET.Element, float, float]], homr: list[ET.Element], cuts: list[float],
          heads: list[float], interline: float, moved: dict[int, ET.Element]) -> tuple[list[ET.Element], list[list[float]]]:
    """homr's bars of a line, between the page x of [cuts], with what the engine's bars of
    that line (each with its span on the page) carry; and the page x of every bar's notes.
    [moved] takes, for every note of the engine's (by id), the note that stands for it."""
    out = [copy.deepcopy(bar) for bar in homr]
    placed: list[list[tuple[float, ET.Element]]] = []   # the notes of each bar, by page x
    anchors: list[list[tuple[float, ET.Element]]] = []  # and with its rests
    for index, bar in enumerate(out):
        for child in list(bar):
            if child.tag in ("harmony", "barline", "print", "direction", "sound"):
                bar.remove(child)
        for note in bar.findall("note"):
            note.attrib.pop("default-x", None)
            for lyric in note.findall("lyric"):
                note.remove(lyric)
        left, right = cuts[index], cuts[index + 1]
        found = _onsets(bar)
        times = sorted({round(when, 4) for _note, when in found})
        xs = dict(zip(times, _place_notes(
            times, [x for x in heads if left <= x < right], left, right, interline, index == 0,
        )))
        bar.set("width", f"{right - left:.1f}")
        bar.set(MARK + "reread", "1")
        row = []
        for note, when in found:
            x = xs[round(when, 4)]
            note.set("default-x", f"{x - left:.1f}")
            row.append((x, note))
        placed.append(sorted(row, key=lambda item: item[0]))
        # A rest stands where its time puts it among the notes: a chord may be written
        # over it.
        known = sorted(xs.items())
        silent = []
        for note, when in _rests(bar):
            before = [(t, x) for t, x in known if t < when]
            after = [(t, x) for t, x in known if t > when]
            if before and after:
                (t0, x0), (t1, x1) = before[-1], after[0]
                x = x0 + (x1 - x0) * (when - t0) / (t1 - t0)
            elif after:
                x = max(left + (right - left) * (0.3 if index == 0 else 0.12), after[0][1] - interline * 3) \
                    if when < after[0][0] else after[0][1]
                x = min(x, after[0][1] - 1.0)
            elif before:
                x = before[-1][1] + (right - interline - before[-1][1]) * (when - before[-1][0]) / max(1e-6, 1.0 - before[-1][0])
            else:
                low = left + (right - left) * (0.3 if index == 0 else 0.12)
                x = low + (right - (right - left) * 0.12 - low) * when
            x = min(max(x, left + 1.0), right - 1.0)
            note.set("default-x", f"{x - left:.1f}")
            silent.append((x, note))
        anchors.append(sorted(row + silent, key=lambda item: item[0]))

    def bar_at(x: float) -> int:
        return min(len(out) - 1, max(0, bisect.bisect_right(cuts, x) - 1))

    def note_at(bar: int, x: float, rests: bool = False) -> ET.Element | None:
        return min((anchors if rests else placed)[bar], key=lambda item: abs(item[0] - x), default=(0.0, None))[1]

    for measure, first, last in engine:
        children = list(measure)
        width = _number(measure.get("width"))

        def page_x(note: ET.Element | None, shift: float = 0.0) -> float | None:
            x = _number(note.get("default-x"), -1.0) if note is not None else -1.0
            if width <= 0 or x < 0:
                return None
            return first + min(max(x + shift, 0.0), width) * (last - first) / width

        for position, child in enumerate(children):
            if child.tag == "note":
                x = page_x(child)
                if x is None or child.find("rest") is not None:
                    continue
                target = note_at(bar_at(x), x)
                if target is None:
                    continue
                if child.find("chord") is None and child.find("grace") is None:
                    moved[id(child)] = target
                for lyric in child.findall("lyric"):
                    verse = lyric.get("number") or "1"
                    if all((l.get("number") or "1") != verse for l in target.findall("lyric")):
                        target.append(copy.deepcopy(lyric))
            elif child.tag in ("harmony", "direction", "sound"):
                later = next(
                    (c for c in children[position + 1:] if c.tag == "note" and c.find("chord") is None), None,
                )
                words = child if child.tag == "harmony" else child.find("direction-type/*")
                shift = _number(words.get("relative-x")) if words is not None else 0.0
                x = page_x(later, shift)
                if x is None:
                    # Nothing to go by but its place among the bar's children.
                    x = first + (last - first) * (0.02 + 0.9 * position / max(1, len(children)))
                bar = bar_at(x + interline * 0.5)
                element = copy.deepcopy(child)
                target = note_at(bar, x + interline * 0.5, rests=True)
                if target is not None:
                    out[bar].insert(list(out[bar]).index(target), element)
                else:
                    out[bar].append(element)
            elif child.tag == "barline":
                if child.get("location") == "left":
                    edge = min(len(out) - 1, min(range(len(cuts)), key=lambda k: abs(cuts[k] - first)))
                    out[edge].insert(0, copy.deepcopy(child))
                else:
                    edge = max(1, min(range(len(cuts)), key=lambda k: abs(cuts[k] - last)))
                    out[edge - 1].append(copy.deepcopy(child))
    return out, [[round(x, 1) for x, _note in row] for row in placed]


def _state_after(state: dict[str, ET.Element], bars: list[ET.Element]) -> dict[str, ET.Element]:
    out = dict(state)
    for bar in bars:
        for attributes in bar.findall("attributes"):
            for tag in _CARRIED:
                found = attributes.find(tag)
                if found is not None:
                    out[tag] = found
    return out


def _states(lines: list[list[ET.Element]]) -> list[dict[str, ET.Element]]:
    """The key, time and clef in force before each line."""
    out, state = [], {}
    for line in lines:
        out.append(state)
        state = _state_after(state, line)
    return out


def _divisions(lines: list[list[ET.Element]]) -> list[int]:
    """The divisions of a quarter in force in each line (as stated in or before it)."""
    out, current = [], 1
    for line in lines:
        stated = next((int(_number(a.findtext("divisions"), 0)) for bar in line
                       for a in bar.findall("attributes") if a.find("divisions") is not None), 0)
        current = stated or current
        out.append(max(1, current))
    return out


def _rescale(bars: list[ET.Element], factor: int) -> None:
    for bar in bars:
        for attributes in bar.findall("attributes"):
            for stated in attributes.findall("divisions"):
                attributes.remove(stated)
            if not len(attributes):
                bar.remove(attributes)
        if factor == 1:
            continue
        for element in bar.iter():
            if element.tag in ("duration", "offset") and element.text:
                value = _number(element.text, math.nan)
                if not math.isnan(value):
                    element.text = str(int(round(value * factor)))


_STEPS = "CDEFGAB"
# The time signatures a lead sheet is printed in: another one is a misreading.
_TIMES = {("2", "4"), ("3", "4"), ("4", "4"), ("5", "4"), ("6", "4"), ("2", "2"), ("3", "2"),
          ("3", "8"), ("6", "8"), ("9", "8"), ("12", "8")}


def _clef_of(element: ET.Element | None) -> tuple[str, int, int]:
    if element is None:
        return "G", 2, 0
    return (element.findtext("sign") or "G", int(_number(element.findtext("line"), 2)),
            int(_number(element.findtext("clef-octave-change"), 0)))


def _bottom_line(clef: tuple[str, int, int]) -> int:
    """The note on the bottom line under [clef], counted in steps from C0."""
    sign, line, octaves = clef
    marked = {"G": 4 * 7 + 4, "C": 4 * 7, "F": 3 * 7 + 3}.get(sign, 4 * 7 + 4)
    return marked - 2 * (line - 1) + 7 * octaves


def _reread_line(line: list[ET.Element], key: tuple[int, int], clef: tuple[tuple, tuple]) -> None:
    """The notes of a line that was read in a wrong key or clef (the first of each pair), as
    they are in the right one: a note stays on its place on the staff, and one that took
    its sharp or flat from the key takes it from the right key."""
    shift = _bottom_line(clef[1]) - _bottom_line(clef[0])
    for bar in line:
        for pitch in bar.iter("pitch"):
            step, octave = pitch.findtext("step") or "C", int(_number(pitch.findtext("octave"), 4))
            alter = int(_number(pitch.findtext("alter"), 0))
            from_key = alter == _key_alter(step, key[0])
            place = octave * 7 + _STEPS.index(step) + shift
            step, octave = _STEPS[place % 7], place // 7
            pitch.find("step").text = step
            pitch.find("octave").text = str(octave)
            if from_key:
                alter = _key_alter(step, key[1])
            stated = pitch.find("alter")
            if alter and stated is None:
                stated = ET.Element("alter")
                pitch.insert(list(pitch).index(pitch.find("step")) + 1, stated)
            if stated is not None:
                if alter:
                    stated.text = str(alter)
                else:
                    pitch.remove(stated)


def _lone(values: list) -> dict[int, object]:
    """The places in [values] where one value stands alone among neighbours that agree with
    each other, and what the neighbours say: one line read wrong, not a change."""
    out = {}
    for index, value in enumerate(values):
        if index == 0:
            around = values[1:3]
        elif index == len(values) - 1:
            around = values[-3:-1]
        else:
            around = [values[index - 1], values[index + 1]]
        if len(around) == 2 and around[0] == around[1] and around[0] != value and value is not None and around[0] is not None:
            out[index] = around[0]
    return out


def _settle(lines: list[list[ET.Element]]) -> dict:
    """homr reads key and clef anew on every staff. Give every line the ones it was read in,
    stated at its start, after putting right a line whose key or clef none of its neighbours
    has. A line that changes key or clef within itself is left as it is."""
    keys: list[int | None] = []
    clefs: list[tuple | None] = []
    key, clef = 0, ("G", 2, 0)
    for line in lines:
        for attributes in line[0].findall("attributes"):
            if attributes.find("key/fifths") is not None:
                key = int(_number(attributes.findtext("key/fifths"), 0))
            if attributes.find("clef") is not None:
                clef = _clef_of(attributes.find("clef"))
        changes = any(a.find("key") is not None or a.find("clef") is not None
                      for bar in line[1:] for a in bar.findall("attributes"))
        keys.append(None if changes else key)
        clefs.append(None if changes else clef)
        for bar in line[1:]:
            for attributes in bar.findall("attributes"):
                if attributes.find("key/fifths") is not None:
                    key = int(_number(attributes.findtext("key/fifths"), 0))
                if attributes.find("clef") is not None:
                    clef = _clef_of(attributes.find("clef"))
    wrong_keys, wrong_clefs = _lone(keys), _lone(clefs)
    for index, line in enumerate(lines):
        if keys[index] is None:
            continue
        key = wrong_keys.get(index, keys[index])
        clef = wrong_clefs.get(index, clefs[index])
        if (key, clef) != (keys[index], clefs[index]):
            _reread_line(line, (keys[index], key), (clefs[index], clef))
        first = line[0]
        for attributes in first.findall("attributes"):
            for tag in ("key", "clef"):
                for stated in attributes.findall(tag):
                    attributes.remove(stated)
            if not len(attributes):
                first.remove(attributes)
        attributes = ET.Element("attributes")
        ET.SubElement(ET.SubElement(attributes, "key"), "fifths").text = str(key)
        stated = ET.SubElement(attributes, "clef")
        ET.SubElement(stated, "sign").text = clef[0]
        ET.SubElement(stated, "line").text = str(clef[1])
        if clef[2]:
            ET.SubElement(stated, "clef-octave-change").text = str(clef[2])
        # After the divisions and before a time, as MusicXML orders them.
        others = first.findall("attributes")
        at = list(first).index(others[0]) if others else next(
            (i for i, child in enumerate(first) if child.tag not in ("print", "barline")), len(first))
        first.insert(at, attributes)
        if others:
            attributes.extend(list(others[0]))
            first.remove(others[0])
            # As MusicXML orders them.
            rank = {"divisions": 0, "key": 1, "time": 2, "staves": 3, "clef": 5}
            attributes[:] = sorted(attributes, key=lambda child: rank.get(child.tag, 4))
    return {"keys_put_right": len(wrong_keys), "clefs_put_right": len(wrong_clefs)}


def _time_of(element: ET.Element) -> tuple[str, str]:
    return (element.findtext("beats") or "").strip(), (element.findtext("beat-type") or "").strip()


def _settle_times(lines: list[list[ET.Element]], engine: list[set]) -> int:
    """Take out the time signatures homr read that are none: one no score is printed in, and,
    after the first line, one the engine did not read in that line or the next to it
    ([engine]: per line, the times the engine read there). Returns how many."""
    dropped = 0
    for index, line in enumerate(lines):
        for bar in line:
            for attributes in bar.findall("attributes"):
                for stated in attributes.findall("time"):
                    time = _time_of(stated)
                    seen = set().union(*engine[max(0, index - 1):index + 2]) if engine else set()
                    if time in _TIMES and (index == 0 or time in seen):
                        continue
                    attributes.remove(stated)
                    dropped += 1
                if not len(attributes):
                    bar.remove(attributes)
    return dropped


def _drop_restated(measures: list[ET.Element]) -> None:
    """A key, time or clef said again while it is in force says nothing: only changes stay."""
    force: dict[str, ET.Element] = {}
    for measure in measures:
        for attributes in measure.findall("attributes"):
            for tag in _CARRIED:
                for stated in attributes.findall(tag):
                    if _same(force.get(tag), stated):
                        attributes.remove(stated)
                    else:
                        force[tag] = stated
            if not len(attributes):
                measure.remove(attributes)


def _same(a: ET.Element | None, b: ET.Element | None) -> bool:
    if a is None or b is None:
        return a is b
    return "".join(ET.tostring(a, encoding="unicode").split()) == "".join(ET.tostring(b, encoding="unicode").split())


def apply(root: ET.Element, book: dict, folder: Path, dashes: list | None = None):
    """Give the score homr's bars and notes where the two readers line up, keeping what the
    engine's bars carry. [dashes], the (note, verse) held syllables found on the engine's
    notes, are moved to the notes that stand for them. Returns what it did and, when it
    changed the score, a function that puts the score back as it was."""
    (folder / SIDECAR).unlink(missing_ok=True)
    reason = unfit(root)
    if reason is not None:
        return {"status": "skipped", "reason": reason}, None
    part = root.find("part")
    measures = part.findall("measure")
    entries = book["placements"][0]
    heights = {number: image.height for number, _sheet, image, _interline, _staves in book["sheets"]}
    server = _lines(measures)
    # Per line of the engine's: its sheet, system and staff, and the span of each bar.
    placed: list[tuple | None] = []
    position = 0
    for line in server:
        found = entries[position:position + len(line)]
        position += len(line)
        keys = {(entry[0], entry[1]) if entry is not None else None for entry in found}
        if len(keys) != 1 or None in keys or not heights.get(found[0][0]):
            placed.append(None)
            continue
        staff = found[0][3][0]
        if any(entry[2] >= len(staff["measures"]) for entry in found) or staff["right"] <= staff["left"]:
            placed.append(None)
            continue
        placed.append((found[0][0], found[0][1], staff, [staff["measures"][entry[2]][:2] for entry in found]))
    sheets = sorted({key[0] for key in placed if key is not None}, key=lambda s: (len(s), s))
    pages = _load_pages(folder, sheets)
    if not pages:
        return {"status": "skipped", "reason": "homr has read no sheet"}, None
    # Which of homr's lines stands for each of the engine's.
    theirs: list[tuple[str, int] | None] = [None] * len(server)
    for sheet, page in pages.items():
        mine = [index for index, key in enumerate(placed) if key is not None and key[0] == sheet]
        down = [(placed[index][2]["top"] + placed[index][2]["bottom"]) / 2 / heights[sheet] for index in mine]
        for index, match in zip(mine, _match_lines(down, page["down"])):
            if match is not None:
                theirs[index] = (sheet, match)
    server_divisions = _divisions(server)
    server_states = _states(server)
    # homr's lines of the whole score in order: what a page is read in carries to the next.
    order = [(sheet, row) for sheet in sheets if sheet in pages for row in range(len(pages[sheet]["lines"]))]
    every = [pages[sheet]["lines"][row] for sheet, row in order]
    settled = _settle(every)
    engine_line = {match: index for index, match in enumerate(theirs) if match is not None}
    engine_times = [
        {_time_of(t) for bar in server[engine_line[key]] for t in bar.findall("attributes/time")}
        if key in engine_line else set()
        for key in order
    ]
    settled["times_dropped"] = _settle_times(every, engine_times)
    homr_divisions = dict(zip(order, _divisions(every)))
    homr_states = dict(zip(order, _states(every)))
    common = 1
    for value in server_divisions + list(homr_divisions.values()):
        common = common * value // math.gcd(common, value)
    if common > 20160:
        return {"status": "skipped", "reason": "the two readers count time too differently"}, None

    merged: list[list[ET.Element]] = []
    sources: list[str] = []
    spans: list[dict] = []
    kept: list[str] = []
    moved: dict[int, ET.Element] = {}
    for index, line in enumerate(server):
        match = theirs[index]
        divides = None
        if placed[index] is None:
            kept.append(f"line {index + 1}: not tied to the page")
        elif match is None:
            kept.append(f"line {index + 1}: homr has no such line")
        else:
            sheet, row = match
            staff, bar_spans = placed[index][2], placed[index][3]
            reach = staff["right"] - staff["left"]
            bars = pages[sheet]["lines"][row]
            known = [(right - staff["left"]) / reach for _left, right in bar_spans[:-1]]
            seen = pages[sheet]["staffs"][row].get("bars") or []
            divides = boundaries(seen, len(bars), known)
            if divides is not None and known:
                divides = _calibrate(divides, seen, known)
            if divides is None and len(line) == len(bars):
                # Its barlines do not come to its bars, but the two readers have as many
                # bars: they divide where the engine's do.
                divides = known
            if divides is None:
                kept.append(f"line {index + 1}: homr's barlines do not come to its bars")
        if divides is None:
            own = [copy.deepcopy(bar) for bar in line]
            for old, new in zip(line, own):
                for a, b in zip(old.findall("note"), new.findall("note")):
                    moved[id(a)] = b
            _rescale(own, common // server_divisions[index])
            merged.append(own)
            sources.append("engine")
            continue
        source = [copy.deepcopy(bar) for bar in line]
        ids = {id(new): id(old) for old_bar, new_bar in zip(line, source)
               for old, new in zip(old_bar.findall("note"), new_bar.findall("note"))}
        _rescale(source, common // server_divisions[index])
        fresh = [copy.deepcopy(bar) for bar in bars]
        _rescale(fresh, common // homr_divisions[match])
        cuts = [staff["left"]] + [staff["left"] + x * reach for x in divides] + [staff["right"]]
        heads = sorted(head for _l, _r, found in staff["measures"] for head in found)
        mine: dict[int, ET.Element] = {}
        bars_out, xs = _line(
            [(bar, left, right) for bar, (left, right) in zip(source, bar_spans)],
            fresh, cuts, heads, staff["interline"], mine,
        )
        moved.update({ids[key]: note for key, note in mine.items() if key in ids})
        merged.append(bars_out)
        sources.append("homr")
        spans.append({
            "sheet": placed[index][0], "system": placed[index][1],
            "spans": [[round(a, 1), round(b, 1)] for a, b in zip(cuts, cuts[1:])], "heads": xs,
        })
    if "homr" not in sources:
        return {"status": "skipped", "reason": "no line lines up", "lines_kept": kept}, None

    # Each line starts in the key, time and clef of its reader; a time homr never read is
    # the engine's.
    force: dict[str, ET.Element] = {}
    before = None
    for index, (bars, source) in enumerate(zip(merged, sources)):
        if source == "homr":
            state = dict(homr_states[theirs[index]])
            engine_time = _state_after(server_states[index], server[index][:1]).get("time")
            if "time" not in state and "time" not in _state_after({}, bars[:1]) and engine_time is not None:
                state["time"] = engine_time
        else:
            state = dict(server_states[index])
        own = _state_after({}, bars[:1])
        missing = [
            copy.deepcopy(state[tag]) for tag in _CARRIED
            if tag in state and tag not in own and (source != before or tag == "time") and not _same(force.get(tag), state[tag])
        ]
        if missing:
            attributes = ET.Element("attributes")
            attributes.extend(missing)
            at = next((i for i, child in enumerate(bars[0]) if child.tag not in ("print", "barline")), len(bars[0]))
            bars[0].insert(at, attributes)
        force = _state_after(force, bars)
        before = source

    for measure in measures:
        part.remove(measure)
    number = 0 if measures[0].get("implicit") == "yes" else 1
    page = None
    for index, bars in enumerate(merged):
        sheet = placed[index][0] if placed[index] is not None else page
        for position, bar in enumerate(bars):
            for mark in bar.findall("print"):
                bar.remove(mark)
            bar.set("number", str(number))
            if number == 0:
                bar.set("implicit", "yes")
            elif sources[index] == "homr":
                bar.attrib.pop("implicit", None)
            number += 1
            if position == 0 and index > 0:
                bar.insert(0, ET.Element("print", {"new-page": "yes"} if sheet != page else {"new-system": "yes"}))
            part.append(bar)
        page = sheet
    first = part.find("measure")
    attributes = first.find("attributes")
    if attributes is None:
        attributes = ET.Element("attributes")
        at = next((i for i, child in enumerate(first) if child.tag not in ("print", "barline")), len(first))
        first.insert(at, attributes)
    stated = ET.Element("divisions")
    stated.text = str(common)
    attributes.insert(0, stated)
    _drop_restated(part.findall("measure"))
    (folder / SIDECAR).write_text(json.dumps({"lines": spans}), encoding="utf-8")
    held = list(dashes) if dashes is not None else []
    if dashes is not None:
        dashes[:] = [(moved[id(note)], verse) for note, verse in held if id(note) in moved]

    def undo() -> None:
        for measure in part.findall("measure"):
            part.remove(measure)
        part.extend(measures)
        if dashes is not None:
            dashes[:] = held
        (folder / SIDECAR).unlink(missing_ok=True)

    return {
        "status": "done", "bars": sum(map(len, merged)), "bars_before": len(measures),
        "lines": len(merged), "lines_reread": sources.count("homr"), "lines_kept": kept, **settled,
    }, undo


def placed_lines(folder: Path) -> dict[tuple[str, int], list[tuple[float, float, list[float]]]]:
    """Per sheet and system of a reread line: the span of each bar on the page and the page
    x of its notes."""
    try:
        lines = json.loads((folder / SIDECAR).read_text())["lines"]
        return {
            (str(line["sheet"]), int(line["system"])): [
                (float(a), float(b), [float(x) for x in heads])
                for (a, b), heads in zip(line["spans"], line["heads"])
            ]
            for line in lines
        }
    except (OSError, ValueError, KeyError, TypeError):
        return {}
