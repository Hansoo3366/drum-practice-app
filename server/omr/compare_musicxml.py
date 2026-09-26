#!/usr/bin/env python3
"""Compare an OMR result with a manually corrected MusicXML reference.

The overlap is a diagnostic for pitch and duration. It does not judge layout,
lyrics, ties, voices, or musical equivalence.
"""

from __future__ import annotations

import argparse
import json
import zipfile
from collections import Counter
from fractions import Fraction
from pathlib import Path
from xml.etree import ElementTree as ET


def _local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def _children(element: ET.Element, name: str) -> list[ET.Element]:
    return [child for child in element if _local_name(child.tag) == name]


def _child_text(element: ET.Element, name: str) -> str:
    matches = _children(element, name)
    return (matches[0].text or "").strip() if matches else ""


def _read_xml(path: Path) -> ET.Element:
    if path.suffix.lower() != ".mxl":
        return ET.fromstring(path.read_bytes())
    with zipfile.ZipFile(path) as archive:
        container = ET.fromstring(archive.read("META-INF/container.xml"))
        rootfile = next(
            (node for node in container.iter() if _local_name(node.tag) == "rootfile"),
            None,
        )
        if rootfile is None or not rootfile.get("full-path"):
            raise ValueError(f"{path}: MXL rootfile is missing")
        return ET.fromstring(archive.read(rootfile.get("full-path")))


def _pitch(note: ET.Element) -> str:
    if _children(note, "rest"):
        return "rest"
    unpitched = _children(note, "unpitched")
    if unpitched:
        return "unpitched"
    pitches = _children(note, "pitch")
    if not pitches:
        return "unknown"
    pitch = pitches[0]
    return (
        f"{_child_text(pitch, 'step')}"
        f"{_child_text(pitch, 'alter') or '0'}:"
        f"{_child_text(pitch, 'octave')}"
    )


def score_events(path: Path) -> dict[tuple[int, int], Counter[tuple[str, Fraction]]]:
    root = _read_xml(path)
    if _local_name(root.tag) != "score-partwise":
        raise ValueError(f"{path}: only score-partwise MusicXML is supported")
    events = {}
    for part_index, part in enumerate(_children(root, "part")):
        divisions = 1
        for measure_index, measure in enumerate(_children(part, "measure")):
            for attributes in _children(measure, "attributes"):
                value = _child_text(attributes, "divisions")
                if value:
                    divisions = int(value)
                    if divisions <= 0:
                        raise ValueError(f"{path}: divisions must be positive")
            notes = Counter()
            for note in _children(measure, "note"):
                if _children(note, "grace"):
                    continue
                duration = _child_text(note, "duration")
                notes[(_pitch(note), Fraction(int(duration), divisions) if duration else Fraction(0))] += 1
            events[(part_index, measure_index)] = notes
    return events


def compare(reference: Path, candidate: Path) -> dict[str, int | float]:
    expected = score_events(reference)
    actual = score_events(candidate)
    keys = expected.keys() | actual.keys()
    matched = sum(sum((expected.get(key, Counter()) & actual.get(key, Counter())).values()) for key in keys)
    expected_count = sum(sum(notes.values()) for notes in expected.values())
    actual_count = sum(sum(notes.values()) for notes in actual.values())
    exact_measures = sum(
        key in expected and key in actual and expected[key] == actual[key]
        for key in keys
    )
    return {
        "reference_measures": len(expected),
        "candidate_measures": len(actual),
        "exact_measures": exact_measures,
        "reference_notes_and_rests": expected_count,
        "candidate_notes_and_rests": actual_count,
        "matching_pitch_duration_events": matched,
        "event_recall_percent": round(100 * matched / expected_count, 1) if expected_count else 0.0,
        "event_precision_percent": round(100 * matched / actual_count, 1) if actual_count else 0.0,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("reference", type=Path, help="manually corrected .mxl or .musicxml")
    parser.add_argument("candidate", type=Path, help="Audiveris .mxl or .musicxml")
    args = parser.parse_args()
    print(json.dumps(compare(args.reference, args.candidate), indent=2))


if __name__ == "__main__":
    main()
