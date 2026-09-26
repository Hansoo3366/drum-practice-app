import importlib.util
import tempfile
import unittest
from pathlib import Path


spec = importlib.util.spec_from_file_location(
    "compare_musicxml_for_test", Path(__file__).with_name("compare_musicxml.py")
)
compare_musicxml = importlib.util.module_from_spec(spec)
spec.loader.exec_module(compare_musicxml)


def _score(divisions: int, second_pitch: str) -> str:
    return f"""<score-partwise version="4.0">
      <part id="P1"><measure number="1">
        <attributes><divisions>{divisions}</divisions></attributes>
        <note><pitch><step>C</step><octave>4</octave></pitch><duration>{divisions}</duration></note>
        <note><pitch><step>{second_pitch}</step><octave>4</octave></pitch><duration>{divisions}</duration></note>
      </measure></part>
    </score-partwise>"""


class CompareMusicXmlTest(unittest.TestCase):
    def test_normalizes_divisions_and_counts_wrong_pitch(self):
        with tempfile.TemporaryDirectory() as directory:
            reference = Path(directory) / "reference.musicxml"
            candidate = Path(directory) / "candidate.musicxml"
            reference.write_text(_score(480, "D"), encoding="utf-8")
            candidate.write_text(_score(10080, "E"), encoding="utf-8")
            report = compare_musicxml.compare(reference, candidate)
        self.assertEqual(report["matching_pitch_duration_events"], 1)
        self.assertEqual(report["event_recall_percent"], 50.0)
        self.assertEqual(report["event_precision_percent"], 50.0)
        self.assertEqual(report["exact_measures"], 0)

    def test_missing_empty_measure_is_not_counted_as_exact(self):
        with tempfile.TemporaryDirectory() as directory:
            reference = Path(directory) / "reference.musicxml"
            candidate = Path(directory) / "candidate.musicxml"
            reference.write_text(
                '<score-partwise><part id="P1"><measure number="1"/></part></score-partwise>',
                encoding="utf-8",
            )
            candidate.write_text(
                '<score-partwise><part id="P1"/></score-partwise>',
                encoding="utf-8",
            )
            report = compare_musicxml.compare(reference, candidate)
        self.assertEqual(report["exact_measures"], 0)


if __name__ == "__main__":
    unittest.main()
