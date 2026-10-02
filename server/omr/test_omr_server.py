"""Command contract tests that do not need a running VM or Flask installation."""

import importlib.util
import io
import json
import os
import sys
import tempfile
import types
import unittest
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET
from unittest.mock import MagicMock, patch


class _FlaskStub:
    def __init__(self, _name):
        self.config = {}

    def get(self, _route):
        return lambda handler: handler

    def post(self, _route):
        return lambda handler: handler


flask = types.ModuleType("flask")
flask.Flask = _FlaskStub
flask.jsonify = lambda *args, **payload: args[0] if args else payload
flask.request = types.SimpleNamespace()
flask.send_file = lambda *args, **kwargs: None
with patch.dict(sys.modules, {"flask": flask}):
    spec = importlib.util.spec_from_file_location(
        "omr_server_for_test", Path(__file__).with_name("omr_server.py")
    )
    omr_server = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(omr_server)

import omr_ai  # noqa: E402
import omr_book  # noqa: E402
import omr_marks  # noqa: E402
import omr_rules  # noqa: E402
import omr_score  # noqa: E402
import omr_text  # noqa: E402
import omr_annotations  # noqa: E402
import omr_validate  # noqa: E402


class ConvertCommandTest(unittest.TestCase):
    def test_pdf_dpi_is_passed_to_audiveris(self):
        command = omr_server._convert_cmd(Path("score.pdf"), Path("out"), "standard", 400)
        self.assertIn("org.audiveris.omr.image.ImageLoading.pdfResolution=400", command)

    def test_dpi_configuration_is_bounded(self):
        with patch.dict(os.environ, {"OMR_PDF_DPIS": "300,400"}):
            self.assertEqual(omr_server._pdf_dpis(), [300, 400])
        for value in ("100", "600", "300,400,500", "invalid"):
            with patch.dict(os.environ, {"OMR_PDF_DPIS": value}):
                with self.assertRaises(ValueError):
                    omr_server._pdf_dpis()

    def test_standard_keeps_chord_recognition_disabled(self):
        with patch.dict(os.environ, {"OMR_OCR_LANGUAGES": ""}):
            command = omr_server._convert_cmd(
                Path("score.pdf"), Path("out"), "standard"
            )
        self.assertIn("-save", command)
        self.assertIn("-export", command)
        self.assertNotIn(
            "org.audiveris.omr.sheet.ProcessingSwitches.chordNames=true", command
        )
        self.assertEqual(command[-1], "score.pdf")

    def test_chords_lyrics_enables_chord_recognition_and_selected_languages(self):
        with patch.dict(os.environ, {"OMR_OCR_LANGUAGES": "kor+eng"}):
            command = omr_server._convert_cmd(
                Path("score.pdf"), Path("out"), "chords_lyrics"
            )
        self.assertIn(
            "org.audiveris.omr.sheet.ProcessingSwitches.chordNames=true", command
        )
        self.assertIn(
            "org.audiveris.omr.sheet.ProcessingSwitches.lyrics=true", command
        )
        self.assertIn(
            "org.audiveris.omr.text.Language.defaultSpecification=kor+eng", command
        )

    def test_indentation_never_starts_a_movement(self):
        for profile in ("standard", "chords_lyrics"):
            command = omr_server._convert_cmd(Path("score.pdf"), Path("out"), profile)
            self.assertIn(
                "org.audiveris.omr.sheet.ProcessingSwitches.indentations=false", command
            )

    def test_lead_sheets_skip_dynamics_but_standard_keeps_them(self):
        lead = omr_server._convert_cmd(Path("s.pdf"), Path("o"), "chords_lyrics")
        standard = omr_server._convert_cmd(Path("s.pdf"), Path("o"), "standard")
        for switch in ("dynamicsAboveStaff", "dynamicsBelowStaff"):
            flag = f"org.audiveris.omr.sheet.ProcessingSwitches.{switch}=false"
            self.assertIn(flag, lead)
            self.assertNotIn(flag, standard)

    def test_invalid_language_specification_fails_before_launch(self):
        with patch.dict(os.environ, {"OMR_OCR_LANGUAGES": "kor;eng"}):
            with self.assertRaises(ValueError):
                omr_server._convert_cmd(
                    Path("score.pdf"), Path("out"), "standard"
                )


def _note(duration=16, extra=""):
    return f'<note>{extra}<pitch><step>C</step><octave>4</octave></pitch><duration>{duration}</duration></note>'


def _document(body, implicit="no"):
    return f'''<score-partwise><part id="P1"><measure number="1" implicit="{implicit}">
    <attributes><divisions>4</divisions><time><beats>4</beats><beat-type>4</beat-type></time></attributes>
    {body}</measure></part></score-partwise>'''


class ScoreInspectionTest(unittest.TestCase):
    def inspect(self, xml):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "score.musicxml"
            path.write_text(xml, encoding="utf-8")
            return omr_server._inspect_score(path)

    def test_backup_and_chord_do_not_double_measure_duration(self):
        body = _note() + _note(extra="<chord/>") + '<backup><duration>16</duration></backup>' + _note(extra="<voice>2</voice><staff>2</staff>")
        metrics = self.inspect(_document(body))
        self.assertEqual(metrics["rhythm_issues"], 0)
        self.assertEqual(metrics["pitched_notes"], 3)

    def test_legitimate_pickup_is_not_a_rhythm_error(self):
        self.assertEqual(self.inspect(_document(_note(4), "yes"))["rhythm_issues"], 0)
        self.assertEqual(self.inspect(_document(_note(20), "yes"))["rhythm_issues"], 1)

    def test_underfull_measure_and_zero_duration_are_detected(self):
        metrics = self.inspect(_document(_note(4) + _note(0)))
        self.assertEqual(metrics["rhythm_issues"], 1)
        self.assertEqual(metrics["invalid_durations"], 1)

    def test_time_divisions_inheritance_and_additive_meter(self):
        xml = _document(_note(10)).replace('<beats>4</beats><beat-type>4</beat-type>', '<beats>3+2</beats><beat-type>8</beat-type>')
        xml = xml.replace('</part>', '<measure number="2">' + _note(10) + '</measure></part>')
        metrics = self.inspect(xml)
        self.assertEqual(metrics["measures_with_time"], 2)
        self.assertEqual(metrics["rhythm_issues"], 0)

    def test_tie_notations_are_not_double_counted(self):
        xml = _document(_note(8, '<tie type="start"/><notations><tied type="start"/></notations>') + _note(8, '<tie type="stop"/><notations><tied type="stop"/></notations>'))
        self.assertEqual(self.inspect(xml)["unresolved_ties"], 0)
        self.assertEqual(self.inspect(_document(_note(extra='<tie type="start"/>')))["unresolved_ties"], 1)

    def test_no_chords_or_lyrics_is_not_a_defect(self):
        metrics = self.inspect(_document(_note()))
        for key in ("empty_measures", "rhythm_issues", "invalid_durations", "unresolved_ties"):
            self.assertEqual(metrics[key], 0)

    def test_reads_namespaced_mxl_container_and_score(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "score.mxl"
            with zipfile.ZipFile(path, "w") as archive:
                archive.writestr("META-INF/container.xml", '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="music/score.xml"/></rootfiles></container>')
                archive.writestr("music/score.xml", _document(_note()).replace('<score-partwise>', '<score-partwise xmlns="http://www.musicxml.org/ns/musicxml">'))
            self.assertEqual(omr_server._inspect_score(path)["pitched_notes"], 1)

    def test_empty_export_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "No recognized"):
            self.inspect(_document(""))

    def test_multiple_exports_are_not_silently_truncated(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            (folder / "score-1.mxl").touch()
            (folder / "score-2.mxl").touch()
            with self.assertRaisesRegex(ValueError, "Multiple exported"):
                omr_score._find_score(folder)

    def test_movements_of_one_page_are_merged_in_order(self):
        def movement(folder, name, notes):
            measures = "".join(
                f'<measure number="{i + 1}">{_note()}</measure>' for i in range(notes)
            )
            xml = f'<score-partwise><part-list><score-part id="P1"/></part-list><part id="P1">{measures}</part></score-partwise>'
            with zipfile.ZipFile(folder / name, "w") as archive:
                archive.writestr("META-INF/container.xml", '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="score.xml"/></rootfiles></container>')
                archive.writestr("score.xml", xml)

        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            movement(folder, "score.mvt1.mxl", 2)
            movement(folder, "score.mvt10.mxl", 1)
            movement(folder, "score.mvt2.mxl", 3)
            merged = omr_score._find_score(folder)
            self.assertEqual(merged.name, "score.merged.mxl")
            root = omr_score._read_score(merged)
            numbers = [m.get("number") for m in root.find("part").findall("measure")]
            self.assertEqual(numbers, ["1", "2", "3", "4", "5", "6"])
            # Running the finder again ignores the merged file it wrote.
            self.assertEqual(omr_score._find_score(folder).name, "score.merged.mxl")

    def test_movements_with_different_parts_are_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            for name, parts in (("score.mvt1.mxl", 1), ("score.mvt2.mxl", 2)):
                body = "".join(f'<part id="P{i}"><measure number="1"/></part>' for i in range(parts))
                with zipfile.ZipFile(folder / name, "w") as archive:
                    archive.writestr("META-INF/container.xml", '<container><rootfiles><rootfile full-path="s.xml"/></rootfiles></container>')
                    archive.writestr("s.xml", f"<score-partwise>{body}</score-partwise>")
            with self.assertRaisesRegex(ValueError, "different parts"):
                omr_score._find_score(folder)


def _candidate(label, **overrides):
    metrics = {
        "measures_by_part": [10], "pages": 1, "pitched_notes": 100,
        "measures_with_time": 10, "invalid_durations": 0,
        "empty_measures": 0, "rhythm_issues": 3, "unresolved_ties": 0,
        **overrides,
    }
    return {"label": label, "status": "ok", "metrics": metrics}


class CandidateSelectionTest(unittest.TestCase):
    def test_retry_is_selected_only_on_structural_improvement(self):
        baseline = _candidate("dpi-300")
        retry = _candidate("dpi-400", rhythm_issues=1)
        self.assertIs(omr_server._select_candidate([baseline, retry])[0], retry)
        self.assertIs(omr_server._select_candidate([baseline, _candidate("equal")])[0], baseline)

    def test_missing_measures_pages_notes_or_time_cannot_win(self):
        baseline = _candidate("dpi-300")
        for overrides in ({"measures_by_part": [9]}, {"pages": 2}, {"pitched_notes": 97}, {"measures_with_time": 9}):
            retry = _candidate("dpi-400", rhythm_issues=0, **overrides)
            self.assertIs(omr_server._select_candidate([baseline, retry])[0], baseline)

    def test_fixing_rhythm_cannot_hide_other_regressions(self):
        baseline = _candidate("dpi-300")
        retry = _candidate("dpi-400", rhythm_issues=0, unresolved_ties=1)
        self.assertIs(omr_server._select_candidate([baseline, retry])[0], baseline)

    def test_failed_baseline_uses_retry_but_all_failed_returns_none(self):
        failed = {"label": "dpi-300", "status": "error"}
        retry = _candidate("dpi-400")
        self.assertIs(omr_server._select_candidate([failed, retry])[0], retry)
        self.assertIsNone(omr_server._select_candidate([failed])[0])

    def test_progress_bands_do_not_finish_during_first_attempt(self):
        first = omr_server._SheetProgress(0, 2)
        second = omr_server._SheetProgress(1, 2)
        self.assertLessEqual(first._band(len(omr_server.STEPS) - 1)[1], 53)
        self.assertGreaterEqual(second._band(0)[0], 53)
        self.assertLessEqual(second._band(len(omr_server.STEPS) - 1)[1], 98)


class PipelineTest(unittest.TestCase):
    def run_pipeline(self, fail_dpi=None, image=False):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            outgoing = root / "out"
            outgoing.mkdir()
            job_id = "pipeline-test"
            omr_server._jobs[job_id] = {"status": "queued", "progress": 1}
            calls = []

            def convert(_job_id, _source, folder, _profile, dpi, timeout):
                calls.append(dpi)
                self.assertGreater(timeout, 0)
                (folder / "audiveris.log").write_text("Audiveris test output", encoding="utf-8")
                if (dpi == fail_dpi or fail_dpi == "all") and not image:
                    raise RuntimeError("simulated engine failure")
                result = folder / "score.musicxml"
                result.write_text(_document(_note(4 if dpi == 300 else 16)), encoding="utf-8")
                return result

            try:
                with patch.dict(os.environ, {"OMR_PDF_DPIS": "300,400"}), patch.object(omr_server, "_run_audiveris", side_effect=convert):
                    omr_server._run_job(job_id, root / ("score.png" if image else "score.pdf"), outgoing, "standard")
                job = omr_server._jobs[job_id].copy()
                report = json.loads((outgoing / "recognition.json").read_text(encoding="utf-8"))
                if job["status"] == "done":
                    self.assertTrue(Path(job["result"]).is_file())
                    self.assertTrue((outgoing / "audiveris.log").is_file())
                    self.assertTrue((outgoing / "raw.mxl").is_file())
                return job, report, calls
            finally:
                del omr_server._jobs[job_id]

    def test_pdf_two_passes_publish_improved_candidate_and_evidence(self):
        job, report, calls = self.run_pipeline()
        self.assertEqual(job["status"], "done")
        self.assertEqual(calls, [300, 400])
        self.assertEqual(report["selected"], "dpi-400")
        self.assertFalse(report["accuracy_verified"])

    def test_retry_failure_preserves_baseline(self):
        job, report, _ = self.run_pipeline(fail_dpi=400)
        self.assertEqual(job["status"], "done")
        self.assertEqual(report["selected"], "dpi-300")
        self.assertEqual(report["candidates"][1]["status"], "error")

    def test_baseline_failure_uses_valid_retry(self):
        _, report, _ = self.run_pipeline(fail_dpi=300)
        self.assertEqual(report["selected"], "dpi-400")

    def test_image_is_not_falsely_upscaled_by_pdf_setting(self):
        _, report, calls = self.run_pipeline(image=True)
        self.assertEqual(calls, [None])
        self.assertEqual(report["selected"], "original")


    def test_all_failed_keeps_diagnostics_and_does_not_publish_result(self):
        job, report, _ = self.run_pipeline(fail_dpi="all")
        self.assertEqual(job["status"], "error")
        self.assertIsNone(report["selected"])
        self.assertNotIn("result", job)


class EngineLifecycleTest(unittest.TestCase):
    def test_success_closes_stdout_cancels_timer_and_uses_own_process_group(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            result = folder / "score.musicxml"
            result.write_text(_document(_note()), encoding="utf-8")
            proc = MagicMock()
            proc.stdout = io.StringIO("Audiveris test output\n")
            proc.wait.return_value = 0
            proc.poll.return_value = 0
            with patch.object(omr_server.subprocess, "Popen", return_value=proc) as popen, patch.object(omr_server.threading, "Timer") as timer, patch.object(omr_server.threading, "Thread"):
                actual = omr_server._run_audiveris("unused", Path("score.pdf"), folder, "standard", 400, 30)
            self.assertEqual(actual, result)
            self.assertTrue(proc.stdout.closed)
            timer.return_value.cancel.assert_called_once()
            self.assertEqual(popen.call_args.kwargs["start_new_session"], os.name == "posix")

    def test_timeout_stops_engine_and_is_not_reported_as_success(self):
        proc = MagicMock()
        proc.stdout = io.StringIO("")
        proc.poll.return_value = None
        proc.wait.return_value = -9

        def immediate_timer(_seconds, callback):
            timer = MagicMock()
            timer.start.side_effect = callback
            return timer

        with tempfile.TemporaryDirectory() as directory, patch.object(omr_server.subprocess, "Popen", return_value=proc), patch.object(omr_server.threading, "Timer", side_effect=immediate_timer), patch.object(omr_server.threading, "Thread"), patch.object(omr_server, "_stop_process") as stop:
            with self.assertRaises(TimeoutError):
                omr_server._run_audiveris("unused", Path("score.pdf"), Path(directory), "standard", 300, 1)
            stop.assert_called_with(proc)
            self.assertTrue(proc.stdout.closed)



def _lead_sheet(measures, fifths=4, credits=""):
    body = "".join(
        f'<measure number="{i + 1}" width="400">'
        + ('<print new-system="yes"/>' if isinstance(m, tuple) else "")
        + (f"<attributes><divisions>1</divisions><key><fifths>{fifths}</fifths></key>"
           "<time><beats>4</beats><beat-type>4</beat-type></time></attributes>" if i == 0 else "")
        + (m[0] if isinstance(m, tuple) else m)
        + "</measure>"
        for i, m in enumerate(measures)
    )
    return f"<score-partwise>{credits}<part-list><score-part id=\"P1\"/></part-list><part id=\"P1\">{body}</part></score-partwise>"


def _words(text, y=24, size=13, placement="above"):
    return (f'<direction placement="{placement}"><direction-type>'
            f'<words default-y="{y}" font-size="{size}">{text}</words></direction-type></direction>')


def _harmony(step="E", y=24):
    return (f'<harmony default-y="{y}" placement="above"><root><root-step>{step}</root-step>'
            '</root><kind text="">major</kind></harmony>')


def _sung(x, lyric=None, step="E"):
    text = f'<lyric number="1" default-y="-78"><syllabic>single</syllabic><text>{lyric}</text></lyric>' if lyric else ""
    return (f'<note default-x="{x}"><pitch><step>{step}</step><octave>4</octave></pitch>'
            f'<duration>1</duration><voice>1</voice><type>quarter</type>{text}</note>')


class LeadSheetRepairTest(unittest.TestCase):
    def repair(self, xml, profile="chords_lyrics"):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "score.mxl"
            with zipfile.ZipFile(path, "w") as archive:
                archive.writestr("META-INF/container.xml", '<container><rootfiles><rootfile full-path="s.xml"/></rootfiles></container>')
                archive.writestr("s.xml", xml)
            result, report = omr_server._postprocess(path, profile)
            return omr_score._read_score(result), report, result.name

    def chords(self, root):
        out = []
        for h in root.iter("harmony"):
            alter = {"1": "#", "-1": "b"}.get(h.findtext("root/root-alter") or "", "")
            bass = h.findtext("bass/bass-step")
            out.append(h.findtext("root/root-step") + alter + (h.find("kind").get("text") or "")
                       + (f"/{bass}" if bass else ""))
        return out

    def test_parses_sharps_read_as_ligatures_or_junk_using_the_key(self):
        cases = {
            "Fﬁm’l": ("F", 1, "m7"), "Gﬂm": ("G", 1, "m"), "F#m7": ("F", 1, "m7"),
            "Gum": ("G", 1, "m"), "C|:tm": ("C", 1, "m"), "Aadd9": ("A", 0, "add9"),
            "Bsus4": ("B", 0, "sus4"), "E/G#": ("E", 0, ""), "Bbmaj7": ("B", -1, "maj7"),
        }
        for text, (step, alter, suffix) in cases.items():
            chord = omr_rules._parse_chord_text(text, 4)
            self.assertIsNotNone(chord, text)
            self.assertEqual((chord["step"], chord["alter"], chord["suffix"]), (step, alter, suffix), text)
        self.assertEqual(omr_rules._parse_chord_text("E/G#", 4)["bass_alter"], 1)
        for text in ("태m7", "E10\"", "rit.", "Verse", "나 여전히"):
            self.assertIsNone(omr_rules._parse_chord_text(text, 4), text)
        # Without a key that sharpens G, junk is not taken for a sharp.
        self.assertIsNone(omr_rules._parse_chord_text("Gum", 0))

    def test_only_words_on_the_chord_line_become_chords(self):
        root, report, name = self.repair(_lead_sheet([
            _harmony() + _words("Fﬁm7") + _sung(20) + _words("Gum") + _sung(60)
            + _words("나 여전히", y=63, size=36) + _words("B", y=-20) + _words("Aadd9") + _sung(100),
        ]))
        self.assertEqual(self.chords(root), ["E", "F#m7", "G#m", "Aadd9"])
        self.assertEqual(report["chords_from_words"], 3)
        self.assertEqual([w.text for w in root.iter("words")], ["나 여전히", "B"])
        self.assertEqual(name, "score.fixed.mxl")
        add = [h for h in root.iter("harmony") if h.find("degree") is not None]
        self.assertEqual(add[0].findtext("degree/degree-value"), "9")

    def test_spreads_glued_korean_syllables_around_the_middle_note(self):
        # "자격없는" printed under four notes, read as one word on the third.
        root, report, _ = self.repair(_lead_sheet([
            _sung(10, "가") + _sung(40) + _sung(70) + _sung(100, "자격없는") + _sung(130)
            + _sung(160, "닌"),
        ]))
        texts = [n.findtext("lyric/text") for n in root.iter("note")]
        self.assertEqual(texts, ["가", "자", "격", "없", "는", "닌"])
        self.assertEqual(report["lyrics_split"], 1)

    def test_leaves_syllables_that_do_not_fit(self):
        root, report, name = self.repair(_lead_sheet([
            _sung(10, "가") + _sung(40, "자격없는내") + _sung(70, "닌"),
        ]))
        self.assertEqual([n.findtext("lyric/text") for n in root.iter("note")], ["가", "자격없는내", "닌"])
        self.assertEqual(report["lyrics_split"], 0)
        self.assertEqual(name, "score.mxl")

    def test_largest_credit_becomes_the_title(self):
        credits = ('<credit page="1"><credit-words font-size="30">I-ABC-ABCC</credit-words></credit>'
                   '<credit page="1"><credit-words font-size="51">예수 피를 힘입어</credit-words></credit>'
                   '<credit page="1"><credit-type>composer</credit-type><credit-words font-size="60">Composer</credit-words></credit>')
        root, report, _ = self.repair(_lead_sheet([_sung(10)], credits=credits))
        self.assertEqual(root.findtext("movement-title"), "예수 피를 힘입어")
        self.assertEqual(report["title"], "예수 피를 힘입어")

    def test_standard_profile_is_untouched(self):
        root, report, name = self.repair(_lead_sheet([_words("Fﬁm7") + _sung(20)]), "standard")
        self.assertEqual(report, {})
        self.assertEqual(name, "score.mxl")

    def test_ocr_fragments_and_subtitles_never_become_the_title(self):
        credits = ('<credit page="1"><credit-words font-size="16">마</credit-words></credit>'
                   '<credit page="1"><credit-words font-size="15">(Vocal)</credit-words></credit>'
                   '<credit page="1"><credit-words font-size="7">ah</credit-words></credit>')
        root, report, _ = self.repair(_lead_sheet([_sung(10)], credits=credits))
        self.assertIsNone(root.findtext("movement-title"))
        self.assertIsNone(report["title"])


def _split_part(pid, owned, divisions=4, name="Vo."):
    measures = []
    for number in range(1, 5):
        head = (f"<attributes><divisions>{divisions}</divisions><key><fifths>-6</fifths></key>"
                "<time><beats>4</beats><beat-type>4</beat-type></time>"
                "<clef><sign>G</sign><line>2</line></clef></attributes>" if number == 1 else "")
        if number in owned:
            body = (f'<note default-x="20"><pitch><step>C</step><octave>5</octave></pitch>'
                    f"<duration>{4 * divisions}</duration><voice>1</voice></note>")
            measures.append(f'<measure number="{number}" width="300">{head}{body}</measure>')
        else:
            measures.append(f'<measure number="{number}">{head}<note><rest measure="yes"/>'
                            f"<duration>{4 * divisions}</duration><voice>1</voice></note></measure>")
    return (f'<score-part id="{pid}"><part-name>{name}</part-name></score-part>',
            f'<part id="{pid}">{"".join(measures)}</part>')


def _split_score(*parts):
    names = "".join(p[0] for p in parts)
    bodies = "".join(p[1] for p in parts)
    return ET.fromstring(f"<score-partwise><part-list>{names}</part-list>{bodies}</score-partwise>")


class SplitPartMergeTest(unittest.TestCase):
    def test_one_staff_split_by_part_name_becomes_one_part(self):
        root = _split_score(_split_part("P1", {3, 4}), _split_part("P2", {1, 2}, name="Vocal"))
        self.assertEqual(omr_rules._merge_split_parts(root), 1)
        parts = root.findall("part")
        self.assertEqual([p.get("id") for p in parts], ["P2"])
        self.assertEqual([m.get("width") for m in parts[0].findall("measure")], ["300"] * 4)
        self.assertEqual([sp.get("id") for sp in root.iter("score-part")], ["P2"])
        # Both parts declared the same attributes, so nothing is restated.
        self.assertEqual(len(parts[0].findall("measure/attributes")), 1)

    def test_changed_divisions_are_restated_where_the_owner_switches(self):
        root = _split_score(_split_part("P1", {1, 2}), _split_part("P2", {3, 4}, divisions=12))
        omr_rules._merge_split_parts(root)
        third = root.find("part").findall("measure")[2]
        self.assertEqual(third.findtext("attributes/divisions"), "12")
        self.assertIsNone(third.find("attributes/key"))

    def test_parts_printed_in_the_same_system_are_left_alone(self):
        root = _split_score(_split_part("P1", {1, 2, 3, 4}), _split_part("P2", {1, 2, 3, 4}))
        self.assertEqual(omr_rules._merge_split_parts(root), 0)
        self.assertEqual(len(root.findall("part")), 2)

    def test_standard_profile_merges_split_parts(self):
        xml = ET.tostring(_split_score(_split_part("P1", {3, 4}), _split_part("P2", {1, 2})),
                          encoding="unicode")
        root, report, name = LeadSheetRepairTest.repair(self, xml, "standard")
        self.assertEqual(report, {"parts_merged": 1})
        self.assertEqual(len(root.findall("part")), 1)
        self.assertEqual(name, "score.fixed.mxl")


class ValidSheetExportTest(unittest.TestCase):
    def book(self, folder, invalid):
        sheets = "".join(
            f'<sheet number="{n}"{" invalid=\"true\"" if n in invalid else ""}/>' for n in range(1, 6)
        )
        with zipfile.ZipFile(folder / "score.omr", "w") as archive:
            archive.writestr("book.xml", f"<book>{sheets}</book>")

    def test_ranges_are_compact(self):
        self.assertEqual(omr_server._sheet_ranges([2, 3, 4, 6, 8, 9]), ["2-4", "6", "8-9"])

    def test_cover_page_is_skipped_and_the_rest_exported(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            self.book(folder, {1})
            (folder / "audiveris.log").write_text("first run\n", encoding="utf-8")
            proc = MagicMock()

            def export(command, **_kwargs):
                (folder / "score.mxl").write_text(_document(_note()), encoding="utf-8")
                return proc

            proc.wait.return_value = 0
            with patch.object(omr_server.subprocess, "Popen", side_effect=export) as popen:
                result = omr_server._export_valid_sheets(folder, {}, 60)
            command = popen.call_args.args[0]
            self.assertEqual(command[command.index("-sheets") + 1], "2-5")
            self.assertLess(command.index("-sheets"), command.index("-output"))
            self.assertEqual(result, folder / "score.mxl")
            self.assertIn("skipping invalid sheets [1]", (folder / "audiveris.log").read_text(encoding="utf-8"))
            self.assertEqual(omr_server._skipped_sheets(folder), [1])

    def test_no_retry_when_every_sheet_is_valid_or_invalid(self):
        for invalid in (set(), {1, 2, 3, 4, 5}):
            with tempfile.TemporaryDirectory() as directory:
                folder = Path(directory)
                self.book(folder, invalid)
                with patch.object(omr_server.subprocess, "Popen") as popen:
                    self.assertIsNone(omr_server._export_valid_sheets(folder, {}, 60))
                popen.assert_not_called()


class LineOcrTest(unittest.TestCase):
    def tsv(self, *words):
        rows = ["level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext"]
        for left, width, conf, text in words:
            rows.append(f"5\t1\t1\t1\t1\t1\t{left}\t5\t{width}\t30\t{conf}\t{text}")
        return "\n".join(rows)

    def read(self, output):
        image = MagicMock()
        with tempfile.TemporaryDirectory() as directory, patch.object(
            omr_server.subprocess, "run", return_value=types.SimpleNamespace(stdout=output),
        ), patch.dict(sys.modules, {"PIL": types.SimpleNamespace(ImageOps=MagicMock())}):
            return omr_book._ocr_line("tesseract", image, (100, 0, 900, 40), Path(directory))

    def test_syllables_get_page_x_including_glued_words(self):
        syllables = self.read(self.tsv((20, 30, 95, "주"), (60, 60, 90, "의보"), (130, 20, 12, "좌"), (160, 10, 90, "_")))
        self.assertEqual([text for _, text in syllables], ["주", "의", "보", "좌"])
        # Crop starts at 100 and carries a 10 px border.
        self.assertEqual([x for x, _ in syllables], [125.0, 165.0, 195.0, 230.0])

    def test_note_heads_read_as_hangul_are_rejected(self):
        self.assertEqual(self.read(self.tsv((20, 30, 50, "골"), (60, 30, 45, "공"), (100, 30, 56, "호"))), [])
        self.assertEqual(self.read(self.tsv((20, 30, 95, "가"), (60, 30, 90, "-"), (100, 30, 90, "<"), (140, 30, 90, "@"))), [])


class AlignmentTest(unittest.TestCase):
    def test_extra_syllables_are_left_out_not_shifted(self):
        pairs = omr_book._align([10, 50, 90, 130], [10, 50, 130], [0, 0, 0])
        self.assertEqual(pairs, [(0, 0), (1, 1), (3, 2)])

    def test_verses_share_one_offset_and_lost_bars_drop_their_syllables(self):
        notes = [100, 150, 200, 250, 300, 800]
        # Syllables printed 25 px right of their heads, plus two syllables
        # over a bar whose notes the export lost (x 500-560).
        verse1 = [125, 175, 225, 275, 500, 560, 825]
        verse2 = [125, 175, 225]
        one, two = omr_book._align_verses([verse1, verse2], notes, [0] * 6, 20.0)
        self.assertEqual(one, [(0, 0), (1, 1), (2, 2), (3, 3), (6, 5)])
        self.assertEqual(two, [(0, 0), (1, 1), (2, 2)])

    def test_tied_notes_are_used_only_when_needed(self):
        self.assertEqual(omr_book._align([10, 60], [10, 50, 70], [0, 20, 0]), [(0, 0), (1, 2)])
        self.assertEqual(omr_book._align([10, 50, 70], [10, 50, 70], [0, 20, 0]), [(0, 0), (1, 1), (2, 2)])


class ChordJunkTest(unittest.TestCase):
    def test_noise_and_repeated_chords_go_but_words_stay(self):
        measure = "".join(_words(t) for t in (
            "G7F", "87", "6717", "0/58m?", "D/a", "G/B C", "Am", "Solo", "rit.", "Fine", "x2", "나 여전히",
        ))
        root = ET.fromstring(_lead_sheet([measure]))
        self.assertEqual(omr_text._drop_chord_junk(root.findall("part")), 7)
        self.assertEqual([w.text for w in root.iter("words")], ["Solo", "rit.", "Fine", "x2", "나 여전히"])

    def test_chord_endings_and_slash_chords_read_as_words_go(self):
        # "F#m7" leaves its "m7" behind as "rn?" or "m?"; "D/E" is read "DIE".
        slash_chord = ('<harmony><root><root-step>D</root-step></root><kind>major</kind>'
                       '<bass><bass-step>E</bass-step></bass></harmony>')
        measure = slash_chord + "".join(_words(t) for t in (
            "rn?", "m?", "m7", "sus4", "DIE", "Al1G", "m", "Uerse'", "D.S. al Fine", "men", "more", "dim",
            # No G/B or B/G here: these are words.
            "BIG", "GIG",
            # Counts and numbers.
            "2x", "3 x", "1.", "2nd", "8va",
        ))
        root = ET.fromstring(_lead_sheet([measure]))
        self.assertEqual(omr_text._drop_chord_junk(root.findall("part")), 7)
        self.assertEqual(
            [w.text for w in root.iter("words")],
            ["Uerse'", "D.S. al Fine", "men", "more", "dim", "BIG", "GIG", "2x", "3 x", "1.", "2nd", "8va"],
        )

    def test_jump_instructions_are_not_leftover_text(self):
        for text in ("D.S. al Fine", "D.C.", "To Coda", "D.S. al Coda", "rit.", "x2"):
            self.assertIsNotNone(omr_rules._CLEAN_WORDS.fullmatch(text), text)
            self.assertFalse(omr_validate._garbled_chord(text), text)
        for text in ("rn?", "Uerse'", "DWF"):
            self.assertTrue(
                omr_rules._CLEAN_WORDS.fullmatch(text) is None or omr_validate._garbled_chord(text), text,
            )

    def test_lyric_words_repeating_recent_lyrics_are_removed(self):
        root = ET.fromstring(_lead_sheet([
            _sung(10, "나") + _sung(40, "가") + _sung(70, "난") + _sung(100, "함"),
            _words("나가난함", y=65, size=26) + _words("간주", y=65, size=26) + _sung(10),
        ]))
        self.assertEqual(omr_text._drop_lyric_words(root.findall("part")), 1)
        self.assertEqual([w.text for w in root.iter("words")], ["간주"])


def _pitch(step, octave=4, duration=1, extra="", chord=False, voice=1):
    return (f'<note>{"<chord/>" if chord else ""}<pitch><step>{step}</step><octave>{octave}</octave></pitch>'
            f"<duration>{duration}</duration><voice>{voice}</voice>{extra}</note>")


class ValidatorTest(unittest.TestCase):
    def rules(self, measures, fifths=0):
        root = ET.fromstring(_lead_sheet(measures, fifths=fifths))
        return [(i["rule"], i["measureIndex"]) for i in omr_validate._validate_score(root)]

    def test_measure_length_against_the_time_signature(self):
        full = _pitch("C") * 4
        self.assertEqual(self.rules([full, _pitch("C") * 3, full]), [("V001", 1)])
        # A short first measure is a pickup, not an error.
        self.assertEqual(self.rules([_pitch("C"), full]), [])

    def test_ties_across_chords_and_a_dangling_tie(self):
        tie = '<tie type="start"/>'
        stop = '<tie type="stop"/>'
        chord_tie = (_pitch("C", extra=tie) + _pitch("E", extra=tie, chord=True)
                     + _pitch("C", extra=stop) + _pitch("E", extra=stop, chord=True) + _pitch("C") * 2)
        self.assertEqual(self.rules([chord_tie]), [])
        self.assertEqual(self.rules([_pitch("C", extra=tie) + _pitch("D") * 3]), [("V003", 0)])

    def test_melody_outlier_but_not_piano_octaves(self):
        melody = [_pitch(s) for s in "CDEFGAB"] + [_pitch("C", octave=7)] + [_pitch(s) for s in "BAGFEDC"]
        bars = ["".join(melody[i:i + 4]) for i in range(0, 16, 4)]
        bars[-1] += _pitch("C")
        self.assertIn(("V006", 1), self.rules(bars))
        octaves = "".join(_pitch("C") + _pitch("C", octave=6, chord=True) for _ in range(4))
        self.assertNotIn("V006", [r for r, _ in self.rules([octaves] * 4)])

    def test_key_undone_soon_and_leftover_text(self):
        key = lambda f: f"<attributes><key><fifths>{f}</fifths></key></attributes>"
        full = _pitch("C") * 4
        bars = [full, key(-2) + full, full, key(0) + full, full + _words("Solo") + _words("DWF")]
        found = self.rules(bars)
        self.assertIn(("V008", 1), found)
        self.assertIn(("L001", 4), found)
        self.assertEqual([r for r in found if r[0] == "L001"], [("L001", 4)])


class CorrectionHistoryTest(unittest.TestCase):
    def test_changes_are_listed_bar_by_bar(self):
        raw = ET.fromstring(_lead_sheet([
            _words("Fﬁm7") + _sung(10, "자격없는") + _sung(40),
            _sung(10),
        ]))
        fixed = ET.fromstring(_lead_sheet([
            _harmony("F") + _sung(10, "자") + _sung(40, "격"),
            _sung(10),
        ]))
        fixed.find(".//harmony/root").append(ET.fromstring("<root-alter>1</root-alter>"))
        history = omr_validate._corrections(raw, fixed)
        kinds = [(i["kind"], i["measureIndex"], i["before"], i["after"]) for i in history["items"]]
        self.assertIn(("chords", 0, [], ["F#"]), kinds)
        self.assertIn(("words", 0, ["Fﬁm7"], []), kinds)
        self.assertIn(("lyrics", 0, "자격없는", "자 격"), kinds)
        self.assertEqual(len(kinds), 3)

    def test_split_parts_compare_the_printed_measure(self):
        raw = _split_score(_split_part("P1", {3, 4}), _split_part("P2", {1, 2}))
        fixed = ET.fromstring(ET.tostring(raw))
        omr_rules._merge_split_parts(fixed)
        history = omr_validate._corrections(raw, fixed)
        self.assertEqual(history["items"], [{"kind": "parts", "before": 2, "after": 1}])


class RepeatStartTest(unittest.TestCase):
    MEASURE = """<measure number="1" width="400"><attributes><divisions>12</divisions></attributes>
      <note default-x="90"><pitch><step>F</step><octave>4</octave></pitch><duration>36</duration><voice>1</voice><type>half</type><dot/></note>
      <note default-x="90"><chord/><pitch><step>B</step><octave>4</octave></pitch><duration>36</duration><voice>1</voice><type>half</type><dot/></note>
      <note default-x="200"><pitch><step>A</step><octave>4</octave></pitch><duration>48</duration><voice>1</voice><type>whole</type></note>
      <backup><duration>84</duration></backup>
      <note default-x="200"><rest/><duration>48</duration><voice>2</voice></note></measure>"""

    def _book(self, bar_x):
        from PIL import Image, ImageDraw

        image = Image.new("L", (500, 200), 255)
        draw = ImageDraw.Draw(image)
        for y in range(60, 141, 20):
            draw.line((0, y, 500, y), fill=0)
        draw.rectangle((bar_x, 60, bar_x + 11, 140), fill=0)  # heavy bar, 0.55 interline
        staff = {"number": 1, "top": 60.0, "bottom": 140.0, "interline": 20.0,
                 "measures": [(0.0, 400.0, [])]}
        part = ET.fromstring(f"<part id='P1'>{self.MEASURE}</part>")
        return part, {"parts": [part], "placements": [[(1, 0, 0, [staff])]],
                      "sheets": [(1, None, image, 20.0, [staff])]}

    def test_heavy_bar_under_the_chord_becomes_a_start_repeat(self):
        part, book = self._book(80)
        self.assertEqual(omr_marks._repeat_starts(book), 1)
        measure = part.find("measure")
        self.assertEqual([n.findtext("pitch/step") for n in measure.findall("note")], ["A", None])
        self.assertEqual(measure.findtext("backup/duration"), "48")
        self.assertEqual(measure.find("barline").get("location"), "left")
        self.assertEqual(measure.find("barline/repeat").get("direction"), "forward")
        history = omr_validate._corrections(
            ET.fromstring(f"<score-partwise><part id='P1'>{self.MEASURE}</part></score-partwise>"),
            ET.fromstring(f"<score-partwise>{ET.tostring(part, encoding='unicode')}</score-partwise>"),
        )
        self.assertIn(("repeat", "start repeat"), [(i["kind"], i["after"]) for i in history["items"]])

    def test_the_measures_own_barline_is_not_a_repeat(self):
        part, book = self._book(0)
        self.assertEqual(omr_marks._repeat_starts(book), 0)
        self.assertEqual(len(part.find("measure").findall("note")), 4)


class LyricDashTest(unittest.TestCase):
    def test_marks_in_the_lyric_line_go_and_marks_at_the_head_stay(self):
        # C4 head at -50: a tenuto at -85 is in the lyric line, one at -62 is a real mark.
        root = ET.fromstring("""<score-partwise><part id="P1"><measure number="1">
          <attributes><clef><sign>G</sign><line>2</line></clef></attributes>
          <note><pitch><step>C</step><octave>4</octave></pitch><duration>1</duration>
            <notations><articulations><tenuto placement="below" default-y="-85"/></articulations></notations>
            <lyric number="1"><text>운</text></lyric></note>
          <note><pitch><step>C</step><octave>4</octave></pitch><duration>1</duration>
            <notations><articulations><tenuto placement="below" default-y="-62"/>
            <accent placement="below" default-y="-80"/></articulations></notations></note>
        </measure></part></score-partwise>""")
        dashes = omr_rules._drop_lyric_dash_articulations(root)
        first, second = root.iter("note")
        self.assertEqual(dashes, [(first, "1"), (second, "1")])
        self.assertIsNone(first.find("notations"))
        self.assertEqual([m.tag for m in second.find("notations/articulations")], ["tenuto"])
        # The syllable on the first note stays; the held second note shows a dash.
        self.assertEqual(omr_rules._add_lyric_dashes(dashes), 1)
        self.assertEqual([l.findtext("text") for l in first.findall("lyric")], ["운"])
        self.assertEqual([l.findtext("text") for l in second.findall("lyric")], ["—"])


class ArcRestTest(unittest.TestCase):
    MEASURE = """<score-partwise><part id="P1"><measure number="3">
      <attributes><divisions>12</divisions><time><beats>4</beats><beat-type>4</beat-type></time>
        <clef><sign>G</sign><line>2</line></clef></attributes>
      <note><rest><display-step>B</display-step><display-octave>4</display-octave></rest><duration>12</duration><voice>1</voice><type>quarter</type></note>
      <note><pitch><step>A</step><octave>4</octave></pitch><duration>12</duration><voice>1</voice><type>quarter</type></note>
      <note><rest><display-step>F</display-step><display-octave>5</display-octave></rest><duration>24</duration><voice>1</voice><type>half</type></note>
      <backup><duration>48</duration></backup>
      <note><rest measure="yes"/><duration>48</duration><voice>2</voice></note>
      <backup><duration>48</duration></backup>
      <note><rest/><duration>48</duration><voice>3</voice></note>
    </measure></part></score-partwise>"""

    def test_extra_voice_measure_rests_go(self):
        root = ET.fromstring(self.MEASURE)
        self.assertEqual(omr_rules._drop_placeholder_rests(root), 2)
        measure = root.find("part/measure")
        self.assertEqual({n.findtext("voice") for n in measure.findall("note")}, {"1"})
        self.assertIsNone(measure.find("backup"))

    def test_a_rest_on_the_top_line_is_flagged(self):
        root = ET.fromstring(self.MEASURE)
        omr_rules._drop_placeholder_rests(root)
        issues = [i for i in omr_validate._validate_score(root) if i["rule"] == "V009"]
        self.assertEqual([i["measure"] for i in issues], ["3"])
        self.assertIn("F5", issues[0]["detail"])

    def test_piano_staves_keep_their_rests(self):
        root = ET.fromstring(self.MEASURE.replace("<clef>", "<staves>2</staves><clef>", 1))
        self.assertEqual(omr_rules._drop_placeholder_rests(root), 0)


class NavigationTest(unittest.TestCase):
    SCORE = """<score-partwise><part id="P1">
      <measure number="1"><note><pitch><step>C</step><octave>5</octave></pitch><duration>4</duration></note></measure>
      <measure number="2"><barline location="left"><ending number="1" type="start"/></barline>
        <note><pitch><step>C</step><octave>5</octave></pitch><duration>4</duration></note></measure>
      <measure number="3"><barline location="left"><ending number="2" type="start"/></barline>
        <note><pitch><step>C</step><octave>5</octave></pitch><duration>4</duration></note></measure>
    </part></score-partwise>"""

    @staticmethod
    def _line(text, x0, y0, x1, y1):
        words, x, step = [], x0, (x1 - x0) / max(1, len(text.split()))
        for word in text.split():
            words.append((word, x, y0, x + step, y1, 90.0))
            x += step
        return {"text": text, "words": words, "x0": x0, "y0": y0, "x1": x1, "y1": y1}

    def test_jumps_and_ending_labels_are_placed_on_their_measures(self):
        root = ET.fromstring(self.SCORE)
        part = root.find("part")
        staff = {"number": 1, "system": 0, "top": 200.0, "bottom": 280.0, "interline": 20.0,
                 "measures": [(0.0, 300.0, []), (300.0, 600.0, []), (600.0, 900.0, [])]}
        book = {"tesseract": "tesseract", "parts": [part], "sheets": [("1", None, None, 20.0, [staff])],
                "placements": [[("1", 0, 0, [staff]), ("1", 0, 1, [staff]), None]]}
        lines = [
            self._line("To Coda", 180, 150, 290, 175),       # above measure 1
            self._line("D.S. al Coda", 520, 150, 590, 175),  # above measure 2
            self._line("Fine", 520, 300, 590, 325),          # below measure 2
            self._line("1-5.", 305, 110, 345, 135),          # bracket label of measure 2
        ]
        with patch.object(omr_marks, "_page_lines", return_value=lines):
            report = omr_marks._navigation_marks(book, Path("/tmp"))
        placed = {(n["measure"], n["text"]) for n in report["navigation"]}
        # Measure 3 sits in a system the book could not place: its "6." is inferred.
        self.assertEqual(placed, {("1", "To Coda"), ("2", "D.S. al Coda"), ("2", "Fine")})
        sounds = {m.get("number"): [s.attrib for s in m.iter("sound")] for m in part.findall("measure")}
        self.assertEqual(sounds["1"], [{"tocoda": "coda"}])
        self.assertEqual(sounds["2"], [{"dalsegno": "segno"}, {"fine": "yes"}])
        endings = [e.get("number") for e in part.iter("ending")]
        self.assertEqual(endings, ["1,2,3,4,5", "6"])


class SegnoCodaTest(unittest.TestCase):
    def test_a_drawn_coda_is_found_and_written_at_the_measure_start(self):
        from PIL import Image, ImageDraw

        image = Image.new("L", (600, 300), 255)
        draw = ImageDraw.Draw(image)
        for y in range(200, 281, 20):
            draw.line((0, y, 600, y), fill=0)
        # A coda: ring crossed by a vertical and a horizontal line, 3 interlines tall.
        draw.ellipse((340, 120, 372, 170), outline=0, width=5)
        draw.line((356, 110, 356, 180), fill=0, width=4)
        draw.line((330, 145, 382, 145), fill=0, width=4)
        staff = {"number": 1, "system": 0, "top": 200.0, "bottom": 280.0, "left": 0.0, "right": 600.0,
                 "interline": 20.0, "measures": [(0.0, 300.0, []), (300.0, 600.0, [])]}
        part = ET.fromstring("""<part id="P1"><measure number="1"><note><rest/><duration>4</duration></note></measure>
          <measure number="2"><note><rest/><duration>4</duration></note></measure></part>""")
        book = {"parts": [part], "sheets": [("1", None, image, 20.0, [staff])],
                "placements": [[("1", 0, 0, [staff]), ("1", 0, 1, [staff])]]}
        marks = omr_marks._segno_coda_marks(book)
        self.assertEqual([m["kind"] for m in marks], ["coda"])
        added = omr_marks._add_segno_coda(book, marks)
        self.assertEqual([(a["measure"], a["sign"]) for a in added], [("2", "coda")])
        second = part.findall("measure")[1]
        self.assertEqual(second[0].tag, "direction")
        self.assertEqual(second.find("direction/sound").attrib, {"coda": "coda"})


class AiLineTest(unittest.TestCase):
    """The AI review asks one staff line at a time."""

    @staticmethod
    def _score(numbers):
        return ET.fromstring(_lead_sheet([_pitch("C") * 4 for _ in numbers]))

    def test_measures_are_grouped_by_staff_line(self):
        from PIL import Image

        root = self._score(range(5))
        first = {"top": 400.0, "bottom": 460.0, "left": 100.0, "right": 1300.0, "system": 0,
                 "measures": [(100.0, 500.0, []), (500.0, 900.0, []), (900.0, 1300.0, [])]}
        second = {"top": 900.0, "bottom": 960.0, "left": 100.0, "right": 1300.0, "system": 1,
                  "measures": [(100.0, 700.0, []), (700.0, 1300.0, [])]}
        book = {
            "sheets": [("1", None, Image.new("L", (1400, 1400), 255), 10.0, [first, second])],
            # Measure 3 (index 2) was not placed; the others sit on two lines.
            "placements": [[("1", 0, 0, [first]), ("1", 0, 1, [first]), None,
                            ("1", 1, 0, [second]), ("1", 1, 1, [second])]],
            "unmatched": [],
        }
        with tempfile.TemporaryDirectory() as folder:
            items = omr_ai._ai_dataset(root, book, Path(folder))
            self.assertEqual([i["targets"] for i in items], [["1", "2"], ["4", "5"]])
            self.assertEqual([i["measureIndex"] for i in items], [[0, 1], [3, 4]])
            picture = Image.open(Path(folder) / items[0]["image"])
            self.assertEqual(picture.width, 1220)
        prompt = omr_ai._ai_prompt(items[1])
        self.assertIn("measures 4, 5", prompt)
        self.assertIn("- measure 4:", prompt)
        self.assertIn("- measure 5:", prompt)

    def test_a_wide_line_is_scaled_to_the_token_budget(self):
        from PIL import Image

        root = self._score(range(1))
        staff = {"top": 400.0, "bottom": 460.0, "left": 100.0, "right": 3300.0, "system": 0,
                 "measures": [(100.0, 3300.0, [])]}
        book = {"sheets": [("1", None, Image.new("L", (3400, 1400), 255), 10.0, [staff])],
                "placements": [[("1", 0, 0, [staff])]], "unmatched": []}
        with tempfile.TemporaryDirectory() as folder:
            items = omr_ai._ai_dataset(root, book, Path(folder))
            self.assertEqual(Image.open(Path(folder) / items[0]["image"]).width, omr_ai.AI_LINE_WIDTH)

    def test_answers_for_a_line_are_sorted_into_its_measures(self):
        root = self._score(range(3))
        items = [{"id": "s0", "measureIndex": [0, 1], "targets": ["1", "2"], "fifths": 0},
                 {"id": "s1", "measureIndex": [2], "targets": ["3"], "fifths": 0}]
        answers = {
            "s0": {"answer": {"hasError": True, "corrections": [
                       {"measure": "2", "field": "chords", "suggested": "Am", "confidence": 0.9},
                       {"measure": "1", "field": "pitch", "note": 1, "suggested": "D4", "confidence": 0.5},
                       # Sure enough to list, not to write.
                       {"measure": "1", "field": "chords", "suggested": "F", "confidence": 0.6},
                       # Sure, but the syllables do not fit the four notes.
                       {"measure": "1", "field": "lyrics", "verse": "1", "suggested": "예수사랑합니다", "confidence": 0.99},
                   ], "uncertain": [{"measure": "1", "reason": "smudged"}]},
                   "input_tokens": 900, "output_tokens": 120},
            "s1": {"error": "gemini 429: quota"},
        }
        with tempfile.TemporaryDirectory() as folder:
            summary = omr_ai._ai_apply(root, items, answers, "test-model", Path(folder))
            report = json.loads((Path(folder) / "ai_review.json").read_text())
            self.assertTrue((Path(folder) / "ai.mxl").is_file())
        self.assertEqual((summary["measures"], summary["lines"], summary["errors"]), (3, 2, 1))
        self.assertEqual((summary["input_tokens"], summary["output_tokens"]), (900, 120))
        self.assertEqual([(s["measure"], len(s["corrections"]), len(s["uncertain"])) for s in report["suggestions"]],
                         [("1", 3, 1), ("2", 1, 0)])
        self.assertEqual([(a["measure"], a["field"]) for a in report["applied"]], [("2", "chords")])
        self.assertEqual([c["status"] for c in report["suggestions"][0]["corrections"]],
                         ["notes", "low_confidence", "no_fit"])
        self.assertEqual(report["suggestions"][1]["corrections"][0]["status"], "applied")
        self.assertEqual(report["applyConfidence"], 0.9)
        # The low-confidence chord was not written: measure 1 has no chord.
        self.assertEqual(omr_validate._measure_view(root.find("part").findall("measure")[0])["chords"], [])


class AiApplyTest(unittest.TestCase):
    def test_chords_and_lyrics_are_applied_and_dashes_stay(self):
        measure = ET.fromstring("""<measure number="3">
          <harmony><root><root-step>F</root-step></root><kind>major</kind></harmony>
          <note><pitch><step>A</step><octave>4</octave></pitch><duration>1</duration>
            <lyric number="1"><text>나</text></lyric></note>
          <note><pitch><step>C</step><octave>5</octave></pitch><duration>1</duration>
            <lyric number="1"><text>—</text></lyric></note>
          <note><pitch><step>C</step><octave>5</octave></pitch><duration>1</duration>
            <lyric number="1"><text>깨</text></lyric></note>
          <note><rest/><duration>1</duration></note>
        </measure>""")
        applied = omr_ai._apply_ai_measure(measure, [
            {"field": "chords", "suggested": ["Dm", "F/A"], "confidence": 0.95},
            {"field": "lyrics", "verse": "1", "suggested": "나는", "confidence": 0.9},
            {"field": "pitch", "note": 1, "suggested": "B4"},  # notes are never applied
        ], -1)
        self.assertEqual([a["field"] for a in applied], ["chords", "lyrics"])
        self.assertEqual(omr_validate._measure_view(measure)["chords"], ["Dm", "F/A"])
        texts = [[l.findtext("text") for l in n.findall("lyric")] for n in measure.findall("note")]
        # The dash note keeps its dash; the other two sung notes take 나 and 는.
        self.assertEqual(texts, [["나"], ["—"], ["는"], []])
        self.assertEqual(measure.findall("note")[0].findtext("pitch/step"), "A")
        # Syllables that do not match the sung notes are not applied.
        applied = omr_ai._apply_ai_measure(
            measure, [{"field": "lyrics", "verse": "1", "suggested": "나는깨지"}], -1)
        self.assertEqual(applied, [])
        texts = [[l.findtext("text") for l in n.findall("lyric")] for n in measure.findall("note")]
        self.assertEqual(texts, [["나"], ["—"], ["는"], []])


    def test_a_held_syllable_is_written_as_a_dash(self):
        def measure():
            return ET.fromstring("""<measure number="29">
              <note><pitch><step>D</step><octave>5</octave></pitch><duration>1</duration>
                <lyric number="1"><text>버</text></lyric></note>
              <note><pitch><step>C</step><octave>5</octave></pitch><duration>1</duration>
                <lyric number="1"><text>리</text></lyric></note>
              <note><pitch><step>B</step><octave>4</octave></pitch><duration>1</duration>
                <lyric number="1"><text>고</text></lyric></note>
              <note><pitch><step>B</step><octave>4</octave></pitch><duration>1</duration></note>
              <note><pitch><step>A</step><octave>4</octave></pitch><duration>1</duration>
                <lyric number="1"><text>앞</text></lyric></note>
            </measure>""")

        def texts(m):
            return [[l.findtext("text") for l in n.findall("lyric")] for n in m.findall("note")]

        held = measure()
        applied = omr_ai._apply_ai_measure(
            held, [{"field": "lyrics", "verse": "1", "suggested": "잊어버리고-앞", "confidence": 0.98}], 3)
        # Six syllables for five notes: not applied as it is...
        self.assertEqual(applied, [])
        applied = omr_ai._apply_ai_measure(
            held, [{"field": "lyrics", "verse": "1", "suggested": "버리고-앞", "confidence": 0.98}], 3)
        # ...five for five: the held note gets a dash, not a second 고.
        self.assertEqual([a["field"] for a in applied], ["lyrics"])
        self.assertEqual(texts(held), [["버"], ["리"], ["고"], ["—"], ["앞"]])
        # A measure's words cannot begin with a dash.
        fresh = measure()
        self.assertEqual(omr_ai._apply_ai_measure(
            fresh, [{"field": "lyrics", "verse": "1", "suggested": "-버리고앞", "confidence": 0.9}], 3), [])
        self.assertEqual(texts(fresh), [["버"], ["리"], ["고"], [], ["앞"]])

    def test_an_answer_naming_held_notes_with_dashes_fits_a_tied_note(self):
        measure = ET.fromstring("""<measure number="3">
          <note><pitch><step>C</step><octave>5</octave></pitch><duration>1</duration>
            <lyric number="1"><text>사</text></lyric></note>
          <note><pitch><step>D</step><octave>5</octave></pitch><duration>1</duration>
            <lyric number="1"><text>할</text></lyric></note>
          <note><pitch><step>E</step><octave>5</octave></pitch><duration>1</duration><tie type="start"/>
            <lyric number="1"><text>니</text></lyric></note>
          <note><pitch><step>E</step><octave>5</octave></pitch><duration>1</duration><tie type="stop"/></note>
          <note><pitch><step>F</step><octave>5</octave></pitch><duration>1</duration>
            <lyric number="1"><text>온</text></lyric></note>
        </measure>""")
        applied = omr_ai._apply_ai_measure(
            measure, [{"field": "lyrics", "verse": "1", "suggested": "사합니-온", "confidence": 0.99}], 1)
        self.assertEqual(applied[0]["after"], "사 합 니 — 온")
        texts = [[l.findtext("text") for l in n.findall("lyric")] for n in measure.findall("note")]
        self.assertEqual(texts, [["사"], ["합"], ["니"], ["—"], ["온"]])

    def test_a_dash_never_replaces_a_sung_syllable(self):
        measure = ET.fromstring("""<measure number="16">
          <note><pitch><step>C</step><octave>5</octave></pitch><duration>1</duration>
            <lyric number="1"><text>합</text></lyric></note>
          <note><pitch><step>D</step><octave>5</octave></pitch><duration>1</duration>
            <lyric number="1"><text>니</text></lyric></note>
          <note><pitch><step>E</step><octave>5</octave></pitch><duration>1</duration>
            <lyric number="1"><text>다</text></lyric></note>
        </measure>""")
        applied = omr_ai._apply_ai_measure(
            measure, [{"field": "lyrics", "verse": "1", "suggested": "합니-", "confidence": 0.9}], 1)
        self.assertEqual(applied, [])
        texts = [[l.findtext("text") for l in n.findall("lyric")] for n in measure.findall("note")]
        self.assertEqual(texts, [["합"], ["니"], ["다"]])

    def test_a_suggestion_equal_to_the_recognition_is_dropped(self):
        measure = ET.fromstring("""<measure number="1">
          <harmony><root><root-step>G</root-step></root><kind text="">major</kind></harmony>
          <note><pitch><step>B</step><octave>4</octave></pitch><duration>2</duration>
            <lyric number="1"><text>예</text></lyric></note>
          <note><pitch><step>B</step><octave>4</octave></pitch><duration>2</duration>
            <lyric number="1"><text>수</text></lyric></note>
        </measure>""")
        self.assertTrue(omr_ai._same_as_recognized(
            measure, {"field": "lyrics", "verse": "1", "current": "예 수", "suggested": "예수"}))
        self.assertTrue(omr_ai._same_as_recognized(measure, {"field": "chords", "suggested": "['G']"}))
        self.assertFalse(omr_ai._same_as_recognized(measure, {"field": "lyrics", "verse": "1", "suggested": "예수님"}))
        self.assertFalse(omr_ai._same_as_recognized(measure, {"field": "chords", "suggested": "G, D"}))
        self.assertFalse(omr_ai._same_as_recognized(measure, {"field": "pitch", "note": 1, "suggested": "A4"}))

    def test_several_chords_on_one_note_keep_their_order(self):
        measure = ET.fromstring("""<measure number="8">
          <harmony><root><root-step>G</root-step></root><kind>major</kind></harmony>
          <note><pitch><step>G</step><octave>4</octave></pitch><duration>4</duration><type>whole</type></note>
        </measure>""")
        applied = omr_ai._apply_ai_measure(
            measure, [{"field": "chords", "suggested": "G, C/G, D/G", "confidence": 0.95}], 1)
        self.assertEqual(applied[0]["after"], ["G", "C/G", "D/G"])
        self.assertEqual(omr_validate._measure_view(measure)["chords"], ["G", "C/G", "D/G"])
        # Spread over the whole note: at its start, a third and two thirds in.
        self.assertEqual([h.findtext("offset") for h in measure.findall("harmony")], [None, "1", "3"])

    def test_a_bracketed_chord_is_a_chord(self):
        self.assertEqual(omr_ai._chord_list('["Am7", "(D7)"]'), ["Am7", "D7"])
        measure = ET.fromstring("""<measure number="12">
          <harmony><root><root-step>A</root-step></root><kind text="m7">minor-seventh</kind></harmony>
          <note><pitch><step>C</step><octave>5</octave></pitch><duration>2</duration><type>half</type></note>
          <harmony><root><root-step>D</root-step></root><kind text="7">dominant</kind></harmony>
          <note><pitch><step>D</step><octave>5</octave></pitch><duration>2</duration><type>half</type></note>
        </measure>""")
        # The page shows "Am7 (D7)": the same chords as recognized, so nothing changes.
        applied = omr_ai._apply_ai_measure(
            measure, [{"field": "chords", "suggested": '["Am7", "(D7)"]', "confidence": 0.95}], 1)
        self.assertEqual(applied, [])
        self.assertEqual(omr_validate._measure_view(measure)["chords"], ["Am7", "D7"])


class PdfPhotoTest(unittest.TestCase):
    def test_jpeg_pages_come_out_of_an_app_made_pdf(self):
        from PIL import Image

        jpegs = []
        for shade in (0, 128):
            buffer = io.BytesIO()
            Image.new("RGB", (40, 60), (shade, 0, 0)).save(buffer, format="JPEG")
            jpegs.append(buffer.getvalue())
        body = b"%PDF-1.4\n"
        for n, jpeg in enumerate(jpegs, 1):
            body += (f"{n} 0 obj << /Type /XObject /Subtype /Image /Filter /DCTDecode "
                     f"/Length {len(jpeg)} >>\nstream\n").encode() + jpeg + b"\nendstream\nendobj\n"
        with tempfile.TemporaryDirectory() as folder:
            pdf = Path(folder) / "score.pdf"
            pdf.write_bytes(body)
            self.assertEqual(omr_marks._pdf_photos(pdf), jpegs)


class TieDotTest(unittest.TestCase):
    def test_staccato_on_a_tied_note_goes(self):
        root = ET.fromstring("""<score-partwise><part id="P1"><measure number="1">
          <note><pitch><step>D</step><octave>4</octave></pitch><duration>1</duration><tie type="start"/>
            <notations><tied type="start"/><articulations><staccato placement="below"/></articulations></notations></note>
          <note><pitch><step>D</step><octave>4</octave></pitch><duration>1</duration>
            <notations><articulations><staccato placement="below"/></articulations></notations></note>
        </measure></part></score-partwise>""")
        self.assertEqual(omr_rules._drop_tie_dots(root), 1)
        tied, plain = root.iter("note")
        self.assertIsNone(tied.find("notations/articulations"))
        self.assertIsNotNone(tied.find("notations/tied"))
        self.assertIsNotNone(plain.find("notations/articulations/staccato"))


class HeldNoteTest(unittest.TestCase):
    MEASURE = """<score-partwise><part id="P1"><measure number="4">
      <note><pitch><step>G</step><octave>4</octave></pitch><duration>3</duration><voice>1</voice><type>16th</type>
        <lyric number="1"><text>나</text></lyric></note>
      <note><pitch><step>G</step><octave>4</octave></pitch><duration>24</duration><voice>1</voice><type>half</type>
        <lyric number="1"><text>—</text></lyric></note>
      <note><chord/><pitch><step>A</step><octave>4</octave></pitch><duration>24</duration><voice>1</voice><type>half</type></note>
    </measure></part></score-partwise>"""

    def test_a_stray_second_goes_and_the_dashed_note_is_tied(self):
        root = ET.fromstring(self.MEASURE)
        self.assertEqual(omr_rules._drop_second_chords(root), 1)
        self.assertEqual(omr_rules._tie_held_dashes(root), 1)
        first, second = root.iter("note")
        self.assertEqual([t.get("type") for t in first.findall("tie")], ["start"])
        self.assertEqual(first.find("notations/tied").get("type"), "start")
        self.assertEqual([t.get("type") for t in second.findall("tie")], ["stop"])
        # MusicXML order: tie right after duration, notations before lyric.
        self.assertEqual([e.tag for e in second], ["pitch", "duration", "tie", "voice", "type", "notations", "lyric"])
        self.assertEqual(omr_rules._tie_held_dashes(root), 0)

    def test_piano_staves_keep_their_chords(self):
        root = ET.fromstring(self.MEASURE.replace('<measure number="4">', '<measure number="4"><attributes><staves>2</staves></attributes>', 1))
        self.assertEqual(omr_rules._drop_second_chords(root), 0)


class TempoTest(unittest.TestCase):
    def test_unusable_metronome_marks_go_and_real_ones_stay(self):
        root = ET.fromstring("""<score-partwise><part id="P1"><measure number="1">
          <direction><direction-type><metronome><beat-unit>quarter</beat-unit><per-minute>1cz</per-minute></metronome></direction-type><sound tempo="1"/></direction>
          <direction><direction-type><metronome><beat-unit>quarter</beat-unit><per-minute>96</per-minute></metronome></direction-type><sound tempo="96"/></direction>
          <note><pitch><step>C</step><octave>5</octave></pitch><duration>1</duration></note>
          <sound tempo="9484"/>
        </measure></part></score-partwise>""")
        self.assertEqual(omr_rules._drop_bad_tempos(root), 3)
        self.assertEqual([m.findtext("per-minute") for m in root.iter("metronome")], ["96"])
        self.assertEqual([s.get("tempo") for s in root.iter("sound") if s.get("tempo")], ["96"])
        self.assertEqual(len(root.findall(".//direction")), 1)


class ChordTokenTest(unittest.TestCase):
    def chars(self, spec):
        # (char, x0, width) at height 34
        return [(c, float(x), float(x + w), 34.0) for c, x, w in spec]

    def test_tokens_positions_and_sign_traces(self):
        tokens = omr_text._chord_tokens(self.chars([
            ("E", 100, 30), ("F", 300, 45), ("m", 350, 38), ("7", 390, 22),
            ("G", 600, 34), ("m", 637, 58), ("C", 900, 31), ("m", 934, 38),
            ("B", 1200, 30), ("s", 1233, 15), ("u", 1250, 24), ("s", 1276, 15), ("4", 1293, 24),
            ("B", 1360, 30), ("G", 1600, 32), ("B", 1633, 30),
        ]))
        self.assertEqual([t["text"] for t in tokens], ["E", "Fm7", "Gm", "Cm", "Bsus4", "B", "G/B"])
        self.assertEqual([t["x"] for t in tokens][:3], [100.0, 300.0, 600.0])
        # F's box swallowed the sharp; G's sharp widened the m after it.
        self.assertEqual([t["root_trace"] for t in tokens], [False, True, True, False, False, False, False])

    def test_a_traced_sign_is_added_to_the_same_chord(self):
        root = ET.fromstring(_lead_sheet([_harmony("B") + _sung(10)]))
        existing = root.find(".//harmony")
        read = omr_rules._harmony_element(
            omr_text._parse_reread_chord("B", -1, True, True), ET.Element("words"),
        )
        omr_text._add_missing_signs(existing, read)
        self.assertEqual(LeadSheetRepairTest.chords(self, root), ["Bb"])
        # No trace, no key fill: a plain F in G major stays F.
        self.assertEqual(omr_text._parse_reread_chord("F", 1, False, False)["alter"], 0)
        self.assertEqual(omr_text._parse_reread_chord("E(sus4)", 4)["suffix"], "sus4")
        self.assertEqual(omr_text._parse_reread_chord("FM7", 1, False)["suffix"], "M7")


class StrayAccidentalTest(unittest.TestCase):
    def test_spaced_flat_and_suffix_join_the_chord_beside_them(self):
        root = ET.fromstring(_lead_sheet([
            _harmony("B") + _words("b 2") + _sung(10),
            _harmony("E") + _harmony("A") + _words("2-E b 2") + _sung(10),
            _harmony("C") + _words("Solo") + _sung(10),
        ]))
        self.assertEqual(omr_text._attach_stray_accidentals(root.findall("part")), 2)
        chords = LeadSheetRepairTest.chords(self, root)
        self.assertEqual(chords, ["Bb2", "Eb2", "A", "C"])
        self.assertEqual([w.text for w in root.iter("words")], ["Solo"])


class ChordRereadTest(unittest.TestCase):
    def name(self, text, fifths=4):
        chord = omr_text._parse_reread_chord(text, fifths)
        if chord is None:
            return None
        alter = {1: "#", -1: "b"}.get(chord["alter"], "")
        bass = chord["bass"] or ""
        if bass:
            bass = "/" + bass + {1: "#", -1: "b"}.get(chord["bass_alter"], "")
        return chord["step"] + alter + chord["suffix"] + bass

    def test_sharps_read_as_letters_or_lost_follow_the_key(self):
        self.assertEqual(self.name("Fjm7"), "F#m7")
        self.assertEqual(self.name("Gim"), "G#m")
        self.assertEqual(self.name("F4m"), "F#m")
        self.assertEqual(self.name("F"), "F#")
        self.assertEqual(self.name("E/Gi"), "E/G#")
        self.assertEqual(self.name("E/G"), "E/G#")
        self.assertEqual(self.name("Bsus4"), "Bsus4")
        self.assertEqual(self.name("Aadd9"), "Aadd9")
        self.assertEqual(self.name("Cm", 0), "Cm")

    def test_flat_keys_and_lower_case_bass(self):
        self.assertEqual(self.name("F/a", -1), "F/A")
        self.assertEqual(self.name("B", -1), "Bb")
        self.assertEqual(self.name("C/b", -1), "C/Bb")
        self.assertEqual(self.name("F2", -1), "F2")
        self.assertIsNone(self.name("Cns", -1))
        self.assertIsNone(self.name("9", -1))

    def test_glued_chords_split_at_each_root(self):
        split = omr_text._split_chord_tokens
        self.assertEqual(split("Bsus4B"), [(0, "Bsus4"), (5, "B")])
        self.assertEqual(split("C/bAm7"), [(0, "C/b"), (3, "Am7")])
        self.assertEqual(split("E/G"), [(0, "E/G")])


@unittest.skipUnless(importlib.util.find_spec("PIL"), "Pillow is not installed")
class TextBandTest(unittest.TestCase):
    def test_finds_lyric_lines_and_splits_a_tie_touching_one(self):
        from PIL import Image, ImageDraw

        image = Image.new("L", (1000, 300), 255)
        draw = ImageDraw.Draw(image)
        for x in range(50, 950, 60):  # two lines of "syllables"
            draw.rectangle((x, 100, x + 40, 130), fill=0)
            draw.rectangle((x, 150, x + 40, 180), fill=0)
        draw.rectangle((300, 30, 330, 99), fill=0)  # a tie and low note touching line one
        draw.rectangle((100, 0, 130, 15), fill=0)  # a lone head: too narrow for text
        bands = omr_book._text_bands(image, (0, 0, 1000, 300), 20.0)
        self.assertEqual(bands, [(100, 131), (150, 181)])


class JobPersistenceTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.jobs = Path(self.tmp.name)
        patcher = patch.multiple(omr_server, JOBS_DIR=self.jobs, _jobs={})
        patcher.start()
        self.addCleanup(patcher.stop)

    def _done_job(self, job_id="a1", ai="error"):
        root = self.jobs / job_id
        (root / "out").mkdir(parents=True)
        book = root / "out" / "dpi-300"
        book.mkdir()
        job = {"id": job_id, "status": "done", "progress": 100, "step": "done", "error": "",
               "result": str(root / "out" / "score.fixed.mxl"), "created": 1.0, "finished": 2.0,
               "profile": "chords_lyrics", "book": str(book), "ai": ai, "root": root}
        omr_server._save_job(job)
        return job

    def test_finished_jobs_come_back_after_a_restart(self):
        self._done_job("a1", ai="done")
        (self.jobs / "b2").mkdir()  # cut off mid-run

        omr_server._restore_jobs()

        done, cut = omr_server._jobs["a1"], omr_server._jobs["b2"]
        self.assertEqual((done["status"], done["ai"]), ("done", "done"))
        self.assertEqual(omr_server._public(done)["ai"], "done")
        self.assertEqual(cut["status"], "error")
        self.assertIn("restart", cut["error"])

    def test_ai_review_runs_again_on_request(self):
        self._done_job("a1", ai="error")
        omr_server._restore_jobs()
        with patch.object(omr_server, "_authorized", return_value=True), \
                patch.object(omr_server, "_ai_enabled", return_value=True), \
                patch.object(omr_server, "_run_ai_review", return_value=({}, "done")), \
                patch.object(omr_server.threading, "Thread") as thread:
            payload, status = omr_server.job_ai_retry("a1")
            self.assertEqual((status, payload["ai"]), (202, "running"))
            thread.call_args.kwargs["target"]()

        self.assertEqual(omr_server._jobs["a1"]["ai"], "done")
        saved = json.loads((self.jobs / "a1" / "job.json").read_text(encoding="utf-8"))
        self.assertEqual(saved["ai"], "done")

    def test_ai_state_tells_failure_from_no_change(self):
        out = self.jobs / "out"
        out.mkdir()
        score = Path("x")
        with patch.object(omr_server, "_ai_review", side_effect=RuntimeError("429")):
            self.assertEqual(omr_server._run_ai_review(score, out, out)[1], "error")
        with patch.object(omr_server, "_ai_review", return_value={"measures": 4, "errors": 4}):
            self.assertEqual(omr_server._run_ai_review(score, out, out)[1], "error")
        with patch.object(omr_server, "_ai_review", return_value={"measures": 4, "errors": 0}):
            self.assertEqual(omr_server._run_ai_review(score, out, out)[1], "unchanged")

        def writes(*_args):
            (out / "ai.mxl").write_bytes(b"x")
            return {"measures": 4, "errors": 0}

        with patch.object(omr_server, "_ai_review", side_effect=writes):
            self.assertEqual(omr_server._run_ai_review(score, out, out)[1], "done")



class ArrangeAdviceTest(unittest.TestCase):
    def test_keeps_only_advice_that_fits_the_score(self):
        answer = {
            "base": {"pattern": "broken", "register": "low"},
            "sections": [
                {"bar": 9, "role": "chorus", "pattern": "beats", "register": "middle"},
                {"bar": 5, "role": "pre", "pattern": "held", "register": "middle"},
                {"bar": 9, "pattern": "held", "register": "low"},       # the same bar twice
                {"bar": 40, "pattern": "beats", "register": "middle"},  # past the end
                {"bar": 3, "pattern": "stride", "register": "middle"},  # unknown pattern
            ],
            "chords": [
                {"bar": 1, "index": 1, "suggested": "D/F#", "reason": "G장조"},
                {"bar": 2, "index": 1, "suggested": "not a chord", "reason": ""},
                {"bar": 99, "index": 1, "suggested": "C", "reason": ""},
                {"bar": 2, "index": 0, "suggested": "C", "reason": ""},
            ],
            "note": "잔잔한 곡",
        }

        advice = omr_ai._arrange_clean(answer, bars=16)

        self.assertEqual(advice["base"], {"pattern": "broken", "register": "low"})
        self.assertEqual(advice["sections"], [
            {"bar": 5, "role": "other", "pattern": "held", "register": "middle"},
            {"bar": 9, "role": "chorus", "pattern": "beats", "register": "middle"},
        ])
        self.assertEqual(advice["chords"], [{"bar": 1, "index": 1, "suggested": "D/F#", "reason": "G장조"}])
        self.assertEqual(advice["note"], "잔잔한 곡")

    def test_an_unusable_answer_falls_back_to_the_default_style(self):
        advice = omr_ai._arrange_clean({"base": {"pattern": "?"}, "sections": "x"[:0], "chords": None}, bars=4)

        self.assertEqual(advice["base"], {"pattern": "held", "register": "middle"})
        self.assertEqual((advice["sections"], advice["chords"]), ([], []))

    def _post(self, payload, authorized=True, enabled=True):
        request = types.SimpleNamespace(get_json=lambda silent=False: payload)
        with patch.object(omr_server, "request", request), \
                patch.object(omr_server, "_authorized", return_value=authorized), \
                patch.object(omr_server, "_ai_enabled", return_value=enabled):
            return omr_server.arrange_advice()

    def test_endpoint_asks_the_model_once_and_returns_clean_advice(self):
        answer = {"base": {"pattern": "beats", "register": "middle"}, "sections": [], "chords": [], "note": "n"}
        result = {"answer": answer, "latency": 1.2, "input_tokens": 300, "output_tokens": 40, "model": "m"}
        with patch("ai_verify.complete_json", return_value=result) as ask:
            advice = self._post({"brief": "bars: 4", "bars": 4})
            bad = self._post({"brief": "", "bars": 4})
            denied = self._post({"brief": "bars: 4", "bars": 4}, authorized=False)

        self.assertEqual(advice["base"], {"pattern": "beats", "register": "middle"})
        self.assertEqual(advice["usage"]["input_tokens"], 300)
        self.assertEqual(ask.call_count, 1)
        self.assertEqual(ask.call_args.args[1], "bars: 4")
        self.assertEqual((bad[1], denied[1]), (400, 401))

    def test_endpoint_reports_a_failed_model_call(self):
        with patch("ai_verify.complete_json", side_effect=RuntimeError("OpenAI 429: quota")):
            failed = self._post({"brief": "bars: 4", "bars": 4})
        off = self._post({"brief": "bars: 4", "bars": 4}, enabled=False)

        self.assertEqual((failed[1], failed[0]["error"]), (502, "ai failed"))
        self.assertEqual(off[1], 503)




class BackupTest(unittest.TestCase):
    def test_a_backup_never_goes_before_the_start_of_its_measure(self):
        root = ET.fromstring(
            "<score-partwise><part id='P1'><measure number='1'>"
            "<note><pitch><step>B</step><octave>4</octave></pitch><duration>6</duration></note>"
            "<note><rest/><duration>6</duration></note>"
            "<backup><duration>12</duration></backup><backup><duration>48</duration></backup>"
            "<forward><duration>6</duration></forward>"
            "<note><pitch><step>E</step><octave>4</octave></pitch><duration>12</duration></note>"
            "<backup><duration>30</duration></backup>"
            "<note><pitch><step>C</step><octave>4</octave></pitch><duration>6</duration></note>"
            "</measure></part></score-partwise>"
        )

        changed = omr_rules._clamp_backups(root)

        self.assertEqual(changed, 2)
        backups = [b.find("duration").text for b in root.iter("backup")]
        # The second backup, already at the start, is dropped; the last one
        # goes back the 18 there are, not 30.
        self.assertEqual(backups, ["12", "18"])
        self.assertEqual(omr_rules._clamp_backups(root), 0)


    def test_a_removed_placeholder_rest_takes_the_backup_over_it_along(self):
        # Voice 1 is short, voice 2 is a stray measure rest, voice 3 the tune:
        # without the rest, the rewind over it would go before the bar.
        root = ET.fromstring(
            "<score-partwise><part id='P1'><measure number='1'>"
            "<note><pitch><step>B</step><octave>4</octave></pitch><duration>6</duration><voice>1</voice><type>eighth</type></note>"
            "<note><rest/><duration>6</duration><voice>1</voice><type>eighth</type></note>"
            "<backup><duration>12</duration></backup>"
            "<note><rest measure='yes'/><duration>48</duration><voice>2</voice></note>"
            "<backup><duration>48</duration></backup>"
            "<forward><duration>6</duration></forward>"
            "<note><pitch><step>E</step><octave>4</octave></pitch><duration>42</duration><voice>3</voice><type>half</type></note>"
            "</measure></part></score-partwise>"
        )

        self.assertEqual(omr_rules._drop_placeholder_rests(root), 1)

        self.assertEqual([b.find("duration").text for b in root.iter("backup")], ["12"])
        self.assertEqual(omr_rules._clamp_backups(root), 0)


class AnnotationTest(unittest.TestCase):
    """Colour pen and highlighter are taken out of what the engine reads."""

    @staticmethod
    def _page(annotated=True):
        from PIL import Image, ImageDraw

        page = Image.new("RGB", (800, 600), (250, 248, 240))  # slightly warm paper
        draw = ImageDraw.Draw(page)
        for y in (200, 215, 230, 245, 260):
            draw.line([(40, y), (760, y)], fill=(20, 20, 20), width=2)
        draw.rectangle([300, 190, 312, 270], fill=(10, 10, 10))  # a printed bar
        if annotated:
            # Highlighter over the printed bar: yellow over paper, the bar still dark.
            for x in range(260, 360):
                for y in range(180, 280):
                    red, green, blue = page.getpixel((x, y))
                    if red > 100:
                        page.putpixel((x, y), (255, 240, 90))
            # A red pen stroke across the staff, and a blue one in the margin.
            draw.line([(500, 170), (560, 290)], fill=(225, 40, 45), width=7)
            draw.line([(600, 60), (700, 60)], fill=(30, 90, 220), width=7)
        return page

    def test_printed_colour_stays_and_vivid_colour_goes(self):
        from PIL import ImageDraw

        page = self._page(annotated=False)
        draw = ImageDraw.Draw(page)
        # A repeat barline and an ending bracket printed in navy.
        draw.rectangle([400, 195, 408, 265], fill=(58, 90, 134))
        draw.line([(420, 150), (700, 150)], fill=(83, 109, 146), width=3)
        # A vivid pen note beside them.
        draw.line([(100, 100), (220, 100)], fill=(243, 27, 27), width=8)

        clean, _annotation, mask, core = omr_annotations._separate(page)
        regions = omr_annotations._regions(mask, core, _annotation, clean)

        self.assertLess(clean.getpixel((404, 222)), 120)      # the navy barline is still there
        self.assertLess(clean.getpixel((560, 150)), 150)      # and the bracket
        self.assertGreater(clean.getpixel((160, 100)), 235)   # the pen is gone
        self.assertEqual([(r["type"], r["color"]) for r in regions], [("ink", "red")])

    def test_any_highlighter_keeps_the_print_under_it(self):
        from PIL import Image, ImageDraw

        # Pink, orange and light blue highlighter; and yellow on a dim photo.
        for paper, tint in (((250, 248, 240), (255, 130, 180)), ((250, 248, 240), (245, 190, 110)),
                            ((250, 248, 240), (150, 205, 250)), ((185, 182, 175), (190, 186, 80))):
            page = Image.new("RGB", (800, 600), paper)
            draw = ImageDraw.Draw(page)
            for y in (200, 215, 230, 245, 260):
                draw.line([(40, y), (760, y)], fill=(20, 20, 20), width=2)
            draw.rectangle([300, 190, 312, 270], fill=(10, 10, 10))
            for x in range(260, 360):
                for y in range(180, 280):
                    if page.getpixel((x, y))[0] > 100:
                        page.putpixel((x, y), tint)

            clean, annotation, mask, core = omr_annotations._separate(page)
            regions = omr_annotations._regions(mask, core, annotation, clean)

            self.assertLess(clean.getpixel((306, 230)), 60, tint)     # the bar
            self.assertLess(clean.getpixel((280, 215)), 80, tint)     # a staff line under it
            self.assertGreater(clean.getpixel((280, 222)), 235, tint)  # the tint is gone
            self.assertEqual([r["type"] for r in regions], ["highlight"], tint)

    def test_a_transparent_page_is_read_on_white(self):
        from PIL import Image, ImageDraw

        page = Image.new("RGBA", (600, 400), (255, 255, 255, 0))
        draw = ImageDraw.Draw(page)
        draw.line([(40, 200), (560, 200)], fill=(0, 0, 0, 255), width=3)
        draw.line([(100, 80), (300, 80)], fill=(255, 0, 0, 255), width=8)

        clean, _annotation, _mask, _core = omr_annotations._separate(page)

        self.assertGreater(clean.getpixel((300, 300)), 235)  # the paper is white, not black
        self.assertLess(clean.getpixel((300, 200)), 60)      # the printed line
        self.assertGreater(clean.getpixel((200, 80)), 235)   # the red stroke is gone

    def test_a_turned_pdf_page_is_left_alone(self):
        photo = io.BytesIO()
        self._page().save(photo, "JPEG", quality=92)
        with tempfile.TemporaryDirectory() as folder:
            upload = Path(folder) / "score.pdf"
            upload.write_bytes(
                b"%PDF-1.4\n1 0 obj << /Type /Page /Rotate 90 >> endobj\n"
                b"2 0 obj << /Filter /DCTDecode /Length " + str(len(photo.getvalue())).encode()
                + b" >>\nstream\n" + photo.getvalue() + b"\nendstream endobj\n"
            )
            self.assertIsNone(omr_annotations._upload_pages(upload))
            upload.write_bytes(upload.read_bytes().replace(b" /Rotate 90", b""))
            self.assertEqual(len(omr_annotations._upload_pages(upload)), 1)

    def test_highlighter_goes_and_the_print_under_it_stays(self):
        clean, annotation, mask, _core = omr_annotations._separate(self._page())

        self.assertLess(clean.getpixel((306, 230)), 60)       # the bar under the highlighter
        self.assertGreater(clean.getpixel((280, 222)), 235)   # highlighted paper is white
        self.assertGreater(clean.getpixel((530, 223)), 235)   # the pen stroke is gone
        self.assertLess(clean.getpixel((100, 215)), 80)       # a staff line elsewhere
        self.assertEqual(mask.getpixel((100, 100)), 0)
        self.assertEqual(annotation.getpixel((100, 100)), (255, 255, 255))
        self.assertGreater(annotation.getpixel((650, 60))[2], 180)

    def test_a_page_without_colour_is_left_alone(self):
        self.assertIsNone(omr_annotations._separate(self._page(annotated=False)))

    def test_annotations_are_listed_by_kind_colour_and_place(self):
        clean, annotation, mask, core = omr_annotations._separate(self._page())

        regions = omr_annotations._regions(mask, core, annotation, clean)

        kinds = {(item["type"], item["color"]): item for item in regions}
        self.assertEqual(set(kinds), {("highlight", "yellow"), ("ink", "red"), ("ink", "blue")})
        # The red stroke crosses the staff; the blue one touches nothing.
        self.assertTrue(kinds[("ink", "red")]["touches_print"])
        self.assertFalse(kinds[("ink", "blue")]["touches_print"])
        box = kinds[("ink", "blue")]["region"]
        self.assertTrue(580 <= box["x"] <= 600 and box["x"] + box["width"] >= 700)
        self.assertTrue(all(item["text"] is None for item in regions))

    def test_an_image_upload_is_read_from_a_cleaned_copy(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "in").mkdir()
            (root / "out").mkdir()
            source = root / "in" / "score.png"
            self._page().save(source)
            before = source.read_bytes()
            with patch.object(omr_annotations.shutil, "which", return_value=None):
                target, report = omr_annotations._separate_upload(source, root / "out")

            self.assertEqual(target, root / "out" / "annotations" / "score.png")
            self.assertEqual(source.read_bytes(), before)  # the upload is untouched
            saved = json.loads((root / "out" / "annotations.json").read_text(encoding="utf-8"))
            self.assertEqual(saved["pages"][0]["annotations"], 3)
            self.assertEqual({item["page"] for item in saved["items"]}, {1})
            self.assertTrue((root / "out" / "annotations" / "page-1.annotation.png").is_file())
            self.assertEqual(report["pages"][0]["width"], 800)

            plain = root / "in" / "plain.png"
            self._page(annotated=False).save(plain)
            self.assertEqual(omr_annotations._separate_upload(plain, root / "out"), (plain, None))
            with patch.dict(os.environ, {"OMR_ANNOTATIONS": "0"}):
                self.assertEqual(omr_annotations._separate_upload(source, root / "out"), (source, None))

    def test_a_pdf_of_photos_is_rebuilt_and_any_other_pdf_is_left_alone(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "out").mkdir()
            source = root / "score.pdf"
            pages = [self._page(), self._page(annotated=False)]
            pages[0].save(source, "PDF", save_all=True, append_images=pages[1:], quality=95)
            with patch.object(omr_annotations.shutil, "which", return_value=None):
                target, report = omr_annotations._separate_upload(source, root / "out")

            self.assertEqual(target, root / "out" / "annotations" / "score.pdf")
            data = target.read_bytes()
            self.assertEqual(omr_annotations._pdf_pages(data), 2)
            self.assertEqual(len(omr_annotations._pdf_photos(data)), 2)
            self.assertEqual([page["annotations"] for page in report["pages"]], [3, 0])

            vector = root / "vector.pdf"
            vector.write_bytes(source.read_bytes() + b"\n<< /Font << /F1 5 0 R >> >>\n")
            self.assertEqual(omr_annotations._separate_upload(vector, root / "out"), (vector, None))

    def test_a_crop_says_where_its_own_measure_is(self):
        from PIL import Image

        staff = {"top": 400.0, "bottom": 460.0, "left": 100.0, "right": 1300.0, "system": 0,
                 "measures": [(100.0, 500.0, []), (500.0, 900.0, []), (900.0, 1300.0, [])]}
        book = {
            "sheets": [("1", None, Image.new("L", (1600, 800), 255), 10.0, [staff])],
            "placements": [[("1", 0, 0, [staff]), ("1", 0, 1, [staff]), ("1", 0, 2, [staff])]],
            "unmatched": [],
        }
        issues = [{"part": 0, "measureIndex": 1}, {"part": 0, "measureIndex": 0},
                  {"part": 0, "measureIndex": 1}]
        with tempfile.TemporaryDirectory() as folder:
            omr_validate._crop_suspects(book, issues, Path(folder))
            middle = Image.open(Path(folder) / issues[0]["image"])
            # Bars 1-3 with a margin of one interline: 90..1310, 1220 wide.
            self.assertEqual(middle.width, 1220)
        self.assertEqual(issues[0]["focus"], [round(410 / 1220, 4), round(810 / 1220, 4)])
        # The first bar has no bar before it: its crop starts with it.
        self.assertEqual(issues[1]["focus"], [round(10 / 820, 4), 0.5])
        # Two issues of one measure share the crop and its focus.
        self.assertEqual(issues[2]["image"], issues[0]["image"])
        self.assertEqual(issues[2]["focus"], issues[0]["focus"])

    def test_every_measure_knows_its_place_on_its_staff_line(self):
        from PIL import Image

        def staff(system, top):
            return {"top": top, "bottom": top + 60.0, "left": 100.0, "right": 1300.0, "system": system,
                    "measures": [(100.0, 500.0, []), (500.0, 1300.0, [])]}

        first, second = staff(0, 400.0), staff(1, 900.0)
        book = {
            "sheets": [("1", None, Image.new("L", (3400, 1400), 255), 10.0, [first, second])],
            # Four measures on two lines; a fifth was not matched to the page.
            "placements": [[("1", 0, 0, [first]), ("1", 0, 1, [first]),
                            ("1", 1, 0, [second]), ("1", 1, 1, [second]), None]],
            "unmatched": [],
        }
        with tempfile.TemporaryDirectory() as folder:
            omr_validate._crop_systems(book, Path(folder))
            layout = json.loads((Path(folder) / "layout.json").read_text())["parts"][0]
            line = Image.open(Path(folder) / "systems" / "p1-s1.jpg")
            self.assertEqual(sorted(p.name for p in (Path(folder) / "systems").iterdir()),
                             ["p1-s1.jpg", "p1-s2.jpg"])
        # The line from 90 to 1310 (one interline of margin), 1220 wide.
        self.assertEqual(line.size, (1220, 180))
        self.assertEqual([m and m["image"] for m in layout],
                         ["p1-s1.jpg", "p1-s1.jpg", "p1-s2.jpg", "p1-s2.jpg", None])
        self.assertEqual(layout[0]["focus"], [round(10 / 1220, 4), round(410 / 1220, 4)])
        self.assertEqual(layout[1]["focus"], [round(410 / 1220, 4), round(1210 / 1220, 4)])

    def test_a_wide_staff_line_is_scaled_down(self):
        from PIL import Image

        staff = {"top": 400.0, "bottom": 460.0, "left": 100.0, "right": 3300.0, "system": 0,
                 "measures": [(100.0, 3300.0, [])]}
        book = {"sheets": [("1", None, Image.new("L", (3400, 1400), 255), 10.0, [staff])],
                "placements": [[("1", 0, 0, [staff])]], "unmatched": []}
        with tempfile.TemporaryDirectory() as folder:
            omr_validate._crop_systems(book, Path(folder))
            self.assertEqual(Image.open(Path(folder) / "systems" / "p1-s1.jpg").width, 1600)

    def test_ink_over_a_measure_marks_it_for_review(self):
        root = ET.fromstring(
            '<score-partwise><part id="P1">'
            '<measure number="1"/><measure number="2"/><measure number="3"/>'
            '</part></score-partwise>'
        )
        staff = {"top": 400.0, "bottom": 460.0, "interline": 15.0,
                 "measures": [(100.0, 500.0, []), (500.0, 900.0, []), (900.0, 1300.0, [])]}
        image = types.SimpleNamespace(width=1600)
        book = {
            "sheets": [("1", None, image, 15.0, [staff])],
            "placements": [[("1", 0, 0, [staff]), ("1", 0, 1, [staff]), ("1", 0, 2, [staff])]],
        }
        annotations = {
            "pages": [{"page": 1, "width": 800, "height": 600, "annotations": 3}],
            "items": [
                # On the page at half the sheet's size: over bar 2 of the sheet.
                {"page": 1, "type": "ink", "touches_print": True,
                 "region": {"x": 300, "y": 190, "width": 40, "height": 50}},
                # Highlighter and ink clear of print hide nothing.
                {"page": 1, "type": "highlight", "touches_print": False,
                 "region": {"x": 60, "y": 190, "width": 100, "height": 50}},
                {"page": 1, "type": "ink", "touches_print": False,
                 "region": {"x": 500, "y": 190, "width": 40, "height": 50}},
                # Far above the staff.
                {"page": 1, "type": "ink", "touches_print": True,
                 "region": {"x": 300, "y": 20, "width": 40, "height": 40}},
            ],
        }

        issues = omr_validate._annotation_checks(root, book, annotations)

        self.assertEqual([(issue["rule"], issue["measure"], issue["severity"]) for issue in issues],
                         [("A001", "2", "medium")])
        self.assertEqual(omr_validate._annotation_checks(root, book, None), [])


if __name__ == "__main__":
    unittest.main()
