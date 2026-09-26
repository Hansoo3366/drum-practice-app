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
flask.jsonify = lambda **payload: payload
flask.request = types.SimpleNamespace()
flask.send_file = lambda *args, **kwargs: None
with patch.dict(sys.modules, {"flask": flask}):
    spec = importlib.util.spec_from_file_location(
        "omr_server_for_test", Path(__file__).with_name("omr_server.py")
    )
    omr_server = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(omr_server)


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
                omr_server._find_score(folder)


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


if __name__ == "__main__":
    unittest.main()
