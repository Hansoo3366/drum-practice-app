"""Notes from the second reader (omr_hybrid): no homr, no VM and no Flask needed."""

import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from xml.etree import ElementTree as ET

from test_omr_server import _omr_book, omr_server  # noqa: F401 - loads the server with a Flask stub

import omr_book
import omr_hybrid


def _note(step, duration=1, x=None, extra=""):
    place = f" default-x='{x}'" if x is not None else ""
    return (f"<note{place}><pitch><step>{step}</step><octave>4</octave></pitch>"
            f"<duration>{duration}</duration>{extra}</note>")


def _homr_page(folder, lines, staffs, size=(1200, 400), divisions=1):
    """What homr leaves for sheet 1: [lines] of bars (each the XML inside a measure) and,
    per line, where it saw the staff and its barlines."""
    home = folder / "homr"
    home.mkdir(exist_ok=True)
    measures, number = [], 0
    for index, line in enumerate(lines):
        for position, content in enumerate(line):
            number += 1
            layout = "<print new-system='yes'/>" if index and position == 0 else ""
            first = f"<attributes><divisions>{divisions}</divisions><key><fifths>1</fifths></key></attributes>" if number == 1 else ""
            measures.append(f"<measure number='{number}'>{layout}{first}{content}</measure>")
    (home / "sheet1.musicxml").write_text(
        f"<score-partwise><part id='P1'>{''.join(measures)}</part></score-partwise>", encoding="utf-8")
    (home / "sheet1.json").write_text(json.dumps({"image": list(size), "staffs": staffs}), encoding="utf-8")


class BarlinesTest(unittest.TestCase):
    def test_as_many_barlines_as_the_bars_need(self):
        self.assertEqual(omr_hybrid.boundaries([0.25, 0.5, 0.75, 1.0], 4), [0.25, 0.5, 0.75])

    def test_a_double_line_is_one_barline(self):
        self.assertEqual(omr_hybrid.boundaries([0.5, 0.51, 0.999], 2), [0.505])

    def test_the_repeat_sign_after_the_clef_ends_no_bar(self):
        self.assertEqual(omr_hybrid.boundaries([0.09, 0.4, 0.7], 3), [0.4, 0.7])

    def test_a_line_only_homr_saw_is_dropped_when_the_engine_saw_the_others(self):
        # A stem taken for a barline at 0.32: the engine's barlines tell which it is.
        self.assertEqual(
            omr_hybrid.boundaries([0.28, 0.32, 0.53, 0.77], 4, known=[0.281, 0.531, 0.772]), [0.28, 0.53, 0.77])

    def test_a_barline_homr_did_not_see_comes_from_the_engine(self):
        self.assertEqual(omr_hybrid.boundaries([0.25, 0.75], 4, known=[0.25, 0.5, 0.75]), [0.25, 0.5, 0.75])

    def test_barlines_that_do_not_come_to_the_bars_give_none(self):
        self.assertIsNone(omr_hybrid.boundaries([0.3, 0.6], 5))
        self.assertIsNone(omr_hybrid.boundaries([0.2, 0.4, 0.6, 0.8], 2))

    def test_barlines_are_given_where_the_engine_measures_the_staff(self):
        # homr's staff begins a little later than the engine's: every line is 0.01 early.
        moved = omr_hybrid._calibrate([0.24, 0.49], [0.24, 0.49, 0.99], [0.25, 0.5])
        self.assertEqual(moved, [0.25, 0.5])
        # A barline the engine did not see moves as the ones it did.
        moved = omr_hybrid._calibrate([0.24, 0.49, 0.74], [0.24, 0.49, 0.74, 0.99], [0.25, 0.5])
        self.assertAlmostEqual(moved[2], 0.75, places=3)


class LinesTest(unittest.TestCase):
    def test_as_many_lines_are_the_same_lines(self):
        self.assertEqual(omr_hybrid._match_lines([0.2, 0.5, 0.8], [0.1, 0.45, 0.9]), [0, 1, 2])

    def test_a_line_only_homr_saw_is_passed_over_in_another_frame(self):
        # homr cropped the photo: its lines lie elsewhere and wider apart, and it saw a
        # second line the engine missed.
        mine = [0.2, 0.4, 0.5]
        theirs = [0.1, 0.25, 0.4, 0.55]  # the engine's lie at 0.2 + (y - 0.1) * 2 / 3
        self.assertEqual(omr_hybrid._match_lines(mine, theirs), [0, 2, 3])

    def test_without_heights_differing_counts_match_nothing(self):
        self.assertEqual(omr_hybrid._match_lines([0.2, 0.5], [None, None, None]), [None, None])


class NotePlacesTest(unittest.TestCase):
    def test_a_head_for_every_note(self):
        self.assertEqual(omr_hybrid._place_notes([0.0, 0.5, 0.75], [110, 300, 420], 100, 500, 20, False), [110, 300, 420])

    def test_a_note_without_a_head_stands_between_its_neighbours(self):
        xs = omr_hybrid._place_notes([0.0, 0.25, 0.5, 0.75], [120, 320, 420], 100, 500, 20, False)
        self.assertEqual([xs[0], xs[2], xs[3]], [120, 320, 420])
        self.assertTrue(120 < xs[1] < 320)

    def test_notes_stay_in_order_inside_the_bar_without_any_head(self):
        xs = omr_hybrid._place_notes([0.0, 0.5], [], 100, 500, 20, True)
        self.assertTrue(100 < xs[0] < xs[1] < 500)


class TiesTest(unittest.TestCase):
    def measures(self, second):
        slur = "<notations><slur type='{}' number='1'/></notations>"
        return [ET.fromstring("<measure>" + _note("F", extra=slur.format("start")) + "</measure>"),
                ET.fromstring("<measure>" + _note(second, extra=slur.format("stop")) + _note("G") + "</measure>")]

    def test_a_slur_to_the_same_pitch_is_a_tie(self):
        bars = self.measures("F")
        self.assertEqual(omr_hybrid._ties_from_slurs(bars), 1)
        first, second = bars[0].find("note"), bars[1].find("note")
        self.assertEqual([t.get("type") for t in first.findall("tie")], ["start"])
        self.assertEqual([t.get("type") for t in second.findall("tie")], ["stop"])
        self.assertEqual(first.find("notations/tied").get("type"), "start")
        self.assertIsNone(first.find("notations/slur"))
        self.assertTrue(omr_book._tied_on(second))
        # The tie stands right after the duration, as MusicXML orders a note.
        self.assertEqual([child.tag for child in second][:3], ["pitch", "duration", "tie"])

    def test_a_slur_to_another_pitch_stays_a_slur(self):
        bars = self.measures("A")
        self.assertEqual(omr_hybrid._ties_from_slurs(bars), 0)
        self.assertIsNotNone(bars[0].find("note/notations/slur"))
        self.assertEqual(bars[0].find("note").findall("tie"), [])


class OneLineMisreadTest(unittest.TestCase):
    """homr reads key and clef anew on every staff, and now and then reads one wrong."""

    def lines(self, heads):
        out = []
        for head in heads:
            out.append([ET.fromstring(f"<measure>{head}" + _note("B", extra="") + _note("F") + "</measure>")])
        return out

    def head(self, fifths=None, clef=None, time=None):
        inner = ""
        if fifths is not None:
            inner += f"<key><fifths>{fifths}</fifths></key>"
        if time is not None:
            inner += f"<time><beats>{time[0]}</beats><beat-type>{time[1]}</beat-type></time>"
        if clef is not None:
            inner += f"<clef><sign>{clef[0]}</sign><line>{clef[1]}</line></clef>"
        return f"<attributes>{inner}</attributes>" if inner else ""

    def test_a_key_only_one_line_has_is_put_right_with_its_notes(self):
        # Two flats on the middle line where the lines around it have none: its B was
        # read as B flat because of that key, and is B.
        lines = self.lines([self.head(0, ("G", 2)), self.head(-2), self.head(0)])
        lines[1][0].find("note/pitch").insert(1, ET.fromstring("<alter>-1</alter>"))
        report = omr_hybrid._settle(lines)
        self.assertEqual(report["keys_put_right"], 1)
        self.assertEqual([line[0].findtext("attributes/key/fifths") for line in lines], ["0", "0", "0"])
        self.assertIsNone(lines[1][0].find("note/pitch/alter"))

    def test_a_key_that_stays_is_a_change_of_key(self):
        lines = self.lines([self.head(-1, ("G", 2)), "", self.head(1), ""])
        self.assertEqual(omr_hybrid._settle(lines)["keys_put_right"], 0)
        self.assertEqual([line[0].findtext("attributes/key/fifths") for line in lines], ["-1", "-1", "1", "1"])

    def test_a_sharp_written_before_the_note_stays_when_the_key_is_put_right(self):
        lines = self.lines([self.head(1, ("G", 2)), self.head(0), self.head(1)])
        lines[1][0].findall("note")[1].find("pitch").insert(1, ET.fromstring("<alter>1</alter>"))
        omr_hybrid._settle(lines)
        # F sharp was written out in a line read without a key: it stays F sharp.
        self.assertEqual(lines[1][0].findall("note")[1].findtext("pitch/alter"), "1")

    def test_a_clef_only_one_line_has_is_put_right_with_its_notes(self):
        # The alto clef on the middle line: the note on its middle line is the B of the
        # treble clef, not C.
        lines = self.lines([self.head(0, ("G", 2)), self.head(clef=("C", 3)), self.head(clef=("G", 2))])
        pitch = lines[1][0].find("note/pitch")
        pitch.find("step").text, pitch.find("octave").text = "C", "4"
        report = omr_hybrid._settle(lines)
        self.assertEqual(report["clefs_put_right"], 1)
        self.assertEqual((pitch.findtext("step"), pitch.findtext("octave")), ("B", "4"))
        self.assertEqual([line[0].findtext("attributes/clef/sign") for line in lines], ["G", "G", "G"])

    def test_a_time_no_score_is_printed_in_and_one_the_engine_did_not_read_are_dropped(self):
        lines = self.lines([self.head(0, ("G", 2), ("4", "4")), self.head(time=("16", "16")),
                            self.head(time=("2", "4")), self.head(time=("3", "4"))])
        engine = [{("4", "4")}, set(), set(), {("3", "4")}]
        self.assertEqual(omr_hybrid._settle_times(lines, engine), 2)
        self.assertEqual([line[0].findtext("attributes/time/beats") for line in lines], ["4", None, None, "3"])

    def test_only_changes_are_stated(self):
        lines = self.lines([self.head(0, ("G", 2)), "", self.head(2), ""])
        omr_hybrid._settle(lines)
        bars = [line[0] for line in lines]
        omr_hybrid._drop_restated(bars)
        self.assertEqual([bar.findtext("attributes/key/fifths") for bar in bars], ["0", None, "2", None])
        self.assertEqual([bar.find("attributes/clef") is not None for bar in bars], [True, False, False, False])


class RereadTest(unittest.TestCase):
    """The engine read two bars as one; homr read both."""

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.folder = Path(self.directory.name)
        _omr_book(self.folder, [[(0, 800, None, "")], [(0, 400, None, ""), (400, 800, None, "")]])
        chord = ("<harmony relative-x='0'><root><root-step>{}</root-step></root><kind>major</kind></harmony>")
        lyric = "<lyric number='1'><syllabic>single</syllabic><text>{}</text></lyric>"
        self.score = ET.fromstring(
            "<score-partwise><part id='P1'>"
            "<measure number='1' width='800'><attributes><divisions>2</divisions>"
            "<key><fifths>2</fifths></key><time><beats>4</beats><beat-type>4</beat-type></time></attributes>"
            "<barline location='left'><repeat direction='forward'/></barline>"
            + chord.format("G") + _note("C", 4, 100, lyric.format("가"))
            + chord.format("D") + _note("D", 4, 500, lyric.format("나"))
            + "<barline location='right'><repeat direction='backward'/></barline></measure>"
            "<measure number='2' width='400'><print new-system='yes'/>" + _note("E", 8, 100) + "</measure>"
            "<measure number='3' width='400'>" + _note("F", 8, 100) + "</measure>"
            "</part></score-partwise>")
        self.book = omr_book._load_book(self.score, self.folder, ocr=False)

    def tearDown(self):
        self.directory.cleanup()

    def bars(self):
        return self.score.find("part").findall("measure")

    def test_the_line_gets_homrs_bars_and_keeps_what_the_engine_read_on_it(self):
        _homr_page(self.folder,
                   [[_note("C", 2) + _note("C", 2), _note("D", 4)], [_note("E", 4), _note("F", 4)]],
                   [{"x1": 0, "x2": 800, "y1": 100, "y2": 180, "bars": [0.5, 1.0]},
                    {"x1": 0, "x2": 800, "y1": 300, "y2": 380, "bars": [0.5, 1.0]}], size=(1200, 600))
        held = [(self.bars()[0].findall("note")[1], "1")]
        report, undo = omr_hybrid.apply(self.score, self.book, self.folder, held)
        self.assertEqual((report["status"], report["bars_before"], report["bars"], report["lines_reread"]), ("done", 3, 4, 2))
        bars = self.bars()
        self.assertEqual([bar.get("number") for bar in bars], ["1", "2", "3", "4"])
        self.assertEqual([len(bar.findall("note")) for bar in bars], [2, 1, 1, 1])
        # Each chord and syllable in the bar it stands in on the page.
        self.assertEqual([[h.findtext("root/root-step") for h in bar.findall("harmony")] for bar in bars[:2]], [["G"], ["D"]])
        self.assertEqual([[l.findtext("text") for l in bar.iter("lyric")] for bar in bars[:2]], [["가"], ["나"]])
        # The repeat signs at the ends of the line, not in the middle of it.
        self.assertEqual(bars[0].find("barline").get("location"), "left")
        self.assertIsNone(bars[0].find("barline[@location='right']"))
        self.assertEqual(bars[1].find("barline/repeat").get("direction"), "backward")
        # One count of time for the whole score; homr's key, and the time it did not read.
        self.assertEqual([d.text for d in self.score.iter("divisions")], ["2"])
        self.assertEqual(bars[0].findtext("attributes/key/fifths"), "1")
        self.assertEqual(bars[0].findtext("attributes/time/beats"), "4")
        self.assertEqual([n.findtext("duration") for n in bars[0].findall("note")], ["4", "4"])
        self.assertEqual(bars[2].find("print").get("new-system"), "yes")
        # The held syllable goes with the note that stands for the engine's.
        self.assertIs(held[0][0], bars[1].find("note"))
        # What the two readers agreed on, bar by bar: the engine read one note where homr
        # read two (nothing to hold them against), and the same notes in the other bars.
        self.assertEqual((report["bars_same"], report["bars_differ"], report["bars_alone"]), (3, 0, 1))
        found = omr_hybrid.reader_checks(self.score, self.folder)
        self.assertEqual([(f["rule"], f["measureIndex"]) for f in found], [("N002", 0), ("K001", 0)])
        self.assertIn("as 1 here, as 2 by the other reader", found[1]["detail"])
        # The page is tied to the new bars: steps that follow find each bar and note on it.
        book = omr_book._load_book(self.score, self.folder, ocr=False)
        self.assertEqual(book["unmatched"], [])
        self.assertEqual([entry[2] for entry in book["placements"][0]], [0, 1, 0, 1])
        staff = book["placements"][0][0][3][0]
        self.assertEqual([bar[:2] for bar in staff["measures"]], [(0.0, 400.0), (400.0, 800.0)])
        self.assertEqual(len(book["onsets"][id(bars[0])]), 2)
        first, second = (x for x, _note in book["onsets"][id(bars[0])])
        self.assertTrue(0 < first < second < 400)
        # Taken out before the score is written: a note's page place is no MusicXML.
        omr_hybrid.strip(self.score)
        self.assertTrue(all(n.get("default-x") is None for n in bars[0].findall("note")))
        self.assertIsNone(bars[0].get("omr-reread"))
        undo()
        self.assertEqual([bar.get("number") for bar in self.bars()], ["1", "2", "3"])
        self.assertFalse((self.folder / omr_hybrid.SIDECAR).exists())

    def test_a_line_homr_cannot_be_trusted_on_stays_the_engines(self):
        # homr saw three barlines where it wrote two bars: the first line stays as it was.
        _homr_page(self.folder,
                   [[_note("C", 4), _note("D", 4)], [_note("E", 4), _note("F", 4)]],
                   [{"x1": 0, "x2": 800, "y1": 100, "y2": 180, "bars": [0.3, 0.5, 0.7, 1.0]},
                    {"x1": 0, "x2": 800, "y1": 300, "y2": 380, "bars": [0.5, 1.0]}], size=(1200, 600), divisions=4)
        report, _undo = omr_hybrid.apply(self.score, self.book, self.folder)
        self.assertEqual((report["status"], report["lines_reread"], len(report["lines_kept"])), ("done", 1, 1))
        bars = self.bars()
        self.assertEqual([len(bar.findall("note")) for bar in bars], [2, 1, 1])
        # Counted in one unit: the engine's halves of a quarter are now quarters of one.
        self.assertEqual([d.text for d in self.score.iter("divisions")], ["4"])
        self.assertEqual([n.findtext("duration") for n in bars[0].findall("note")], ["8", "8"])
        self.assertEqual(bars[0].findtext("attributes/key/fifths"), "2")
        # Homr's line starts in homr's key.
        self.assertEqual(bars[1].findtext("attributes/key/fifths"), "1")
        book = omr_book._load_book(self.score, self.folder, ocr=False)
        self.assertEqual([entry[2] for entry in book["placements"][0]], [0, 0, 1])

    def test_nothing_changes_without_homrs_reading(self):
        before = ET.tostring(self.score)
        report, undo = omr_hybrid.apply(self.score, self.book, self.folder)
        self.assertEqual(report["status"], "skipped")
        self.assertIsNone(undo)
        self.assertEqual(ET.tostring(self.score), before)

    def test_homrs_repeat_signs_stand_where_the_engine_read_none(self):
        repeat = "<barline location='{}'><bar-style>{}</bar-style><repeat direction='{}'/></barline>"
        # homr writes a start repeat first in the bar it begins and calls the side "right".
        _homr_page(self.folder,
                   [[repeat.format("right", "heavy-light", "forward") + _note("C", 4) + _note("D", 4)
                     + repeat.format("right", "light-heavy", "backward"),
                     repeat.format("right", "heavy-light", "forward") + _note("E", 4), _note("F", 4)],
                    [_note("G", 4), _note("A", 4)]],
                   [{"x1": 0, "x2": 800, "y1": 100, "y2": 180, "bars": [0.4, 0.7, 1.0]},
                    {"x1": 0, "x2": 800, "y1": 300, "y2": 380, "bars": [0.5, 1.0]}], size=(1200, 600))
        # The engine read a start repeat on the first bar and no end repeat anywhere.
        first = self.bars()[0]
        first.remove(first.find("barline[@location='right']"))
        report, _undo = omr_hybrid.apply(self.score, self.book, self.folder)
        self.assertEqual(report["bars"], 5)
        bars = self.bars()
        # Bar 1: the engine's own start repeat, once; homr's end repeat added.
        self.assertEqual([b.get("location") for b in bars[0].findall("barline")], ["left", "right"])
        self.assertEqual(bars[0].find("barline[@location='right']/repeat").get("direction"), "backward")
        self.assertEqual(bars[1].find("barline[@location='left']/repeat").get("direction"), "forward")
        self.assertEqual(bars[1].find("barline").get("location"), "left")
        self.assertEqual(bars[2].findall("barline"), [])

    def test_a_line_the_engine_left_out_is_put_in_from_homr(self):
        # The page has three staves; the engine's book has the first and the third. homr
        # read all three: its middle line goes in between, where it stands on the page.
        _homr_page(self.folder,
                   [[_note("C", 4), _note("D", 4)], [_note("E", 4), _note("F", 4)], [_note("G", 4), _note("A", 4)]],
                   [{"x1": 0, "x2": 800, "y1": 100, "y2": 180, "bars": [0.5, 1.0]},
                    {"x1": 0, "x2": 800, "y1": 200, "y2": 280, "bars": [0.5, 1.0]},
                    {"x1": 0, "x2": 800, "y1": 300, "y2": 380, "bars": [0.5, 1.0]}], size=(1200, 600))
        report, _undo = omr_hybrid.apply(self.score, self.book, self.folder)
        self.assertEqual((report["lines"], report["lines_reread"], report["lines_added"], report["bars"]), (3, 2, 1, 6))
        bars = self.bars()
        self.assertEqual([n.findtext("pitch/step") for n in bars[2].findall("note") + bars[3].findall("note")], ["E", "F"])
        self.assertEqual(bars[2].find("print").get("new-system"), "yes")
        self.assertEqual(bars[4].find("print").get("new-system"), "yes")
        # The page is tied to the new line too: a staff of its own, numbered in between.
        book = omr_book._load_book(self.score, self.folder, ocr=False)
        self.assertIsNotNone(book)
        self.assertEqual(book["unmatched"], [])
        self.assertEqual([entry[1] for entry in book["placements"][0]], [0, 0, 1, 1, 2, 2])
        staff = book["placements"][0][2][3][0]
        self.assertTrue(staff["id"].startswith("homr-"))
        self.assertEqual((staff["top"], staff["bottom"], staff["left"], staff["right"]), (200.0, 280.0, 0.0, 800.0))
        self.assertEqual([bar[:2] for bar in staff["measures"]], [(0.0, 400.0), (400.0, 800.0)])
        self.assertEqual(len(book["onsets"][id(bars[2])]), 1)
        # The third line's staff is now system 2.
        self.assertEqual(book["placements"][0][4][3][0]["system"], 2)

    def test_a_bar_the_readers_read_differently_is_a_finding(self):
        # Same number of notes in the first bar, but the engine has D where homr has E.
        _homr_page(self.folder,
                   [[_note("C", 4) + _note("E", 4)], [_note("E", 4), _note("F", 4)]],
                   [{"x1": 0, "x2": 800, "y1": 100, "y2": 180, "bars": [1.0]},
                    {"x1": 0, "x2": 800, "y1": 300, "y2": 380, "bars": [0.5, 1.0]}], size=(1200, 600))
        omr_hybrid.apply(self.score, self.book, self.folder)
        found = [f for f in omr_hybrid.reader_checks(self.score, self.folder) if f["rule"] == "N001"]
        self.assertEqual([(f["measureIndex"], f["measure"]) for f in found], [(0, "1")])
        self.assertIn("the other read C4 D4", found[0]["detail"])
        # Bars taken off or put in afterwards: the findings no longer name the right bars.
        part = self.score.find("part")
        part.remove(part.findall("measure")[-1])
        self.assertEqual(omr_hybrid.reader_checks(self.score, self.folder), [])

    def test_a_score_of_two_staves_is_not_one_for_the_second_reader(self):
        self.assertIsNone(omr_hybrid.unfit(self.score))
        self.bars()[0].find("note").append(ET.fromstring("<staff>2</staff>"))
        self.assertEqual(omr_hybrid.unfit(self.score), "more than one staff")
        report, undo = omr_hybrid.apply(self.score, self.book, self.folder)
        self.assertEqual((report["status"], undo), ("skipped", None))

    def test_an_empty_bar_before_the_repeat_sign_is_no_bar(self):
        _homr_page(self.folder,
                   [["", _note("C", 4), _note("D", 4)], [_note("E", 4), _note("F", 4)]],
                   [{"x1": 0, "x2": 800, "y1": 100, "y2": 180, "bars": [0.08, 0.5, 1.0]},
                    {"x1": 0, "x2": 800, "y1": 300, "y2": 380, "bars": [0.5, 1.0]}], size=(1200, 600))
        report, _undo = omr_hybrid.apply(self.score, self.book, self.folder)
        self.assertEqual((report["bars"], report["lines_reread"]), (4, 2))
        self.assertEqual(self.bars()[0].findtext("attributes/key/fifths"), "1")


class SheetImagesTest(unittest.TestCase):
    def job(self, clean: bool):
        job = Path(self.directory.name)
        (job / "in").mkdir(exist_ok=True)
        (job / "in" / "score.jpg").write_bytes(b"photo")
        (job / "out" / "dpi-300").mkdir(parents=True, exist_ok=True)
        if clean:
            (job / "out" / "annotations").mkdir(exist_ok=True)
            (job / "out" / "annotations" / "page-1.clean.jpg").write_bytes(b"clean")
        from PIL import Image
        book = {"sheets": [("1", None, Image.new("L", (10, 10), 255), 20.0, [])]}
        return omr_hybrid._sheet_images(job / "out" / "dpi-300" / "score.mxl", book)

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()

    def tearDown(self):
        self.directory.cleanup()

    def test_the_photo_as_uploaded(self):
        self.assertEqual(self.job(clean=False), {"1": b"photo"})

    def test_the_page_with_the_pen_taken_out_when_there_is_one(self):
        self.assertEqual(self.job(clean=True), {"1": b"clean"})


class AddRepeatTest(unittest.TestCase):
    def test_a_start_repeat_stands_at_the_left_and_joins_the_barline_there(self):
        bar = ET.fromstring("<measure><print/><attributes/><note/><barline location='right'>"
                            "<bar-style>light-light</bar-style></barline></measure>")
        self.assertTrue(omr_hybrid.add_repeat(bar, True))
        self.assertEqual([c.tag for c in bar], ["print", "attributes", "barline", "note", "barline"])
        self.assertEqual((bar[2].get("location"), bar[2].findtext("bar-style"), bar[2].find("repeat").get("direction")),
                         ("left", "heavy-light", "forward"))
        self.assertFalse(omr_hybrid.add_repeat(bar, True))
        # The end repeat joins the barline the bar already has at its right.
        self.assertTrue(omr_hybrid.add_repeat(bar, False))
        right = bar.findall("barline")[1]
        self.assertEqual((right.findtext("bar-style"), right.find("repeat").get("direction")), ("light-heavy", "backward"))
        self.assertEqual(len(bar.findall("barline")), 2)


class CompareTest(unittest.TestCase):
    def test_the_states(self):
        self.assertEqual(omr_hybrid._compare([], [])["state"], "empty")
        self.assertEqual(omr_hybrid._compare([{"C4"}, {"E4"}], [{"C4"}, {"E4"}])["state"], "same")
        # Two notes struck together are the same whichever is written first.
        self.assertEqual(omr_hybrid._compare([{"E4", "C4"}], [{"C4", "E4"}])["state"], "same")
        self.assertEqual(omr_hybrid._compare([{"C4"}, {"E4"}], [{"C4"}, {"G6"}]), {"state": "differ", "other": "C4 G6"})
        self.assertEqual(omr_hybrid._compare([{"C4"}, {"E4"}], [{"C4"}]), {"state": "alone", "other": 1})


class ReaderTest(unittest.TestCase):
    def test_off_by_default(self):
        with patch.dict(os.environ, {}, clear=False):
            os.environ.pop("OMR_HYBRID_NOTES", None)
            self.assertFalse(omr_hybrid.enabled())

    def test_homr_is_not_called_without_its_python(self):
        with patch.dict(os.environ, {"OMR_HOMR_PYTHON": ""}), patch.object(omr_hybrid.subprocess, "run") as run:
            report = omr_hybrid.read_sheets(Path("/nowhere/out/dpi-300/score.mxl"), {"sheets": []})
        self.assertEqual(report["status"], "off")
        run.assert_not_called()

    def test_a_sheet_homr_fails_on_is_not_tried_again(self):
        with tempfile.TemporaryDirectory() as directory:
            job = Path(directory)
            (job / "out" / "dpi-300").mkdir(parents=True)
            python = job / "python"
            python.write_text("")
            from PIL import Image
            book = {"sheets": [("1", None, Image.new("L", (10, 10), 255), 20.0, [])]}
            failed = type("Done", (), {"returncode": 1, "stderr": "no staff found"})()
            with patch.dict(os.environ, {"OMR_HOMR_PYTHON": str(python)}), \
                    patch.object(omr_hybrid.subprocess, "run", return_value=failed) as run:
                first = omr_hybrid.read_sheets(job / "out" / "dpi-300" / "score.mxl", book)
                second = omr_hybrid.read_sheets(job / "out" / "dpi-400" / "score.mxl", book)
            self.assertEqual((first["sheets_read"], first["sheets_failed"], second["sheets_failed"]), (0, ["1"], ["1"]))
            self.assertEqual(run.call_count, 1)
            self.assertEqual(sorted(p.name for p in (job / "out" / "homr").iterdir()), ["sheet1.failed", "sheet1.log"])


if __name__ == "__main__":
    unittest.main()
