#!/usr/bin/env python3
"""PDF/image → MusicXML worker. Jobs keep running if the app backgrounds."""

from __future__ import annotations

import math
import json
import os
import re
import shutil
import signal
import subprocess
import threading
import time
import uuid
import zipfile
from fractions import Fraction
from pathlib import Path
from xml.etree import ElementTree as ET

from flask import Flask, jsonify, request, send_file

TOKEN = os.environ.get("OMR_TOKEN", "piano-omr-dev")
JOBS_DIR = Path(os.environ.get("OMR_JOBS", "/opt/omr/jobs"))
HOST = os.environ.get("OMR_HOST", "0.0.0.0")
PORT = int(os.environ.get("OMR_PORT", "8080"))
TIMEOUT_SEC = int(os.environ.get("OMR_TIMEOUT", "1200"))
KEEP_SEC = int(os.environ.get("OMR_KEEP_SEC", "21600"))
PIPELINE = "pdf-multipass-v1"
# Each Java worker has a 4 GB heap. Do not launch one per uploaded document.
_JOB_SLOTS = threading.BoundedSemaphore(
    max(1, min(4, int(os.environ.get("OMR_MAX_PARALLEL", "1"))))
)

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = 40 * 1024 * 1024

ALLOWED = {".pdf", ".jpg", ".jpeg", ".png", ".tif", ".tiff"}
PROFILES = {"standard", "chords_lyrics"}
STEPS = [
    "LOAD",
    "BINARY",
    "SCALE",
    "GRID",
    "HEADERS",
    "STEM_SEEDS",
    "BEAMS",
    "LEDGERS",
    "HEADS",
    "STEMS",
    "SYMBOLS",
    "KEYS",
    "REDUCTION",
    "CUES",
    "TEXTS",
    "MEASURES",
    "CHORDS",
    "CURVES",
    "RHYTHMS",
    "PAGE",
]
STEP_INDEX = {name: index for index, name in enumerate(STEPS)}
# Later OMR steps take much longer than binarize/grid. Weights are relative time.
STEP_WEIGHTS = {
    "LOAD": 1,
    "BINARY": 1,
    "SCALE": 1,
    "GRID": 2,
    "HEADERS": 2,
    "STEM_SEEDS": 2,
    "BEAMS": 3,
    "LEDGERS": 2,
    "HEADS": 7,
    "STEMS": 3,
    "SYMBOLS": 4,
    "KEYS": 2,
    "REDUCTION": 3,
    "CUES": 2,
    "TEXTS": 6,
    "MEASURES": 4,
    "CHORDS": 5,
    "CURVES": 8,
    "RHYTHMS": 22,
    "PAGE": 12,
}
TOTAL_WEIGHT = float(sum(STEP_WEIGHTS.values()))
_STEP_RE = re.compile(r"STEPMONITORING[^|\n]*\|\s*([A-Z_]+)\b")
_STUB_RE = re.compile(r"Stub#(\d+)", re.I)
_SHEET_RE = re.compile(r"(?:Sheet#|sheet\s+)(\d+)", re.I)

_jobs: dict[str, dict] = {}
_lock = threading.Lock()


def _authorized() -> bool:
    header = request.headers.get("X-Omr-Token", "")
    auth = request.headers.get("Authorization", "")
    bearer = auth[7:].strip() if auth.lower().startswith("bearer ") else ""
    return header == TOKEN or bearer == TOKEN


def _public(job: dict) -> dict:
    return {
        "id": job["id"],
        "status": job["status"],
        "progress": job["progress"],
        "step": job.get("step") or "",
        "error": job.get("error") or "",
        "profile": job["profile"],
    }


@app.get("/health")
def health():
    return jsonify(ok=True, pipeline=PIPELINE)


@app.post("/convert")
def convert():
    if not _authorized():
        return jsonify(error="unauthorized"), 401
    uploaded = request.files.get("file")
    if uploaded is None or not uploaded.filename:
        return jsonify(error="file is required"), 400
    suffix = Path(uploaded.filename).suffix.lower()
    if suffix not in ALLOWED:
        return jsonify(error="pdf, jpg, or png is required"), 400
    profile = request.form.get("profile", "standard")
    if profile not in PROFILES:
        return jsonify(error="unsupported recognition profile"), 400

    job_id = uuid.uuid4().hex
    root = JOBS_DIR / job_id
    incoming = root / "in"
    outgoing = root / "out"
    incoming.mkdir(parents=True, exist_ok=True)
    outgoing.mkdir(parents=True, exist_ok=True)
    source = incoming / f"score{suffix}"
    uploaded.save(source)
    job = {
        "id": job_id,
        "status": "queued",
        "progress": 1,
        "step": "queued",
        "error": "",
        "result": None,
        "root": root,
        "created": time.time(),
        "finished": None,
        "tracker": _SheetProgress(),
        "profile": profile,
    }
    with _lock:
        _jobs[job_id] = job
    threading.Thread(
        target=_run_job,
        args=(job_id, source, outgoing, profile),
        daemon=True,
    ).start()
    return jsonify(_public(job)), 202


@app.get("/jobs/<job_id>")
def job_status(job_id: str):
    if not _authorized():
        return jsonify(error="unauthorized"), 401
    with _lock:
        job = _jobs.get(job_id)
        if job is None:
            return jsonify(error="not found"), 404
        payload = _public(job)
    return jsonify(payload)


@app.get("/jobs/<job_id>/result")
def job_result(job_id: str):
    if not _authorized():
        return jsonify(error="unauthorized"), 401
    with _lock:
        job = _jobs.get(job_id)
        if job is None:
            return jsonify(error="not found"), 404
        if job["status"] != "done" or not job.get("result"):
            return jsonify(error="not ready"), 409
        result = Path(job["result"])
    return send_file(
        result,
        mimetype="application/vnd.recordare.musicxml+xml",
        as_attachment=True,
        download_name=result.name,
    )


@app.get("/jobs/<job_id>/diagnostics")
def job_diagnostics(job_id: str):
    if not _authorized():
        return jsonify(error="unauthorized"), 401
    with _lock:
        job = _jobs.get(job_id)
        if job is None:
            return jsonify(error="not found"), 404
        report = Path(job["root"]) / "out" / "recognition.json"
    if not report.is_file():
        return jsonify(error="not ready"), 409
    return send_file(report, mimetype="application/json")


def _run_job(job_id: str, source: Path, outgoing: Path, profile: str) -> None:
    with _JOB_SLOTS:
        _run_job_serial(job_id, source, outgoing, profile)


def _pdf_dpis() -> list[int]:
    values = [int(value.strip()) for value in os.environ.get("OMR_PDF_DPIS", "300,400").split(",")]
    if not values or len(values) > 2 or any(value < 200 or value > 500 for value in values):
        raise ValueError("OMR_PDF_DPIS must contain one or two DPI values in 200..500")
    return list(dict.fromkeys(values))


def _run_job_serial(job_id: str, source: Path, outgoing: Path, profile: str) -> None:
    _update(job_id, status="running", progress=5, step="start")
    try:
        dpis = _pdf_dpis() if source.suffix.lower() == ".pdf" else [None]
        deadline = time.monotonic() + TIMEOUT_SEC
        candidates = []
        for index, dpi in enumerate(dpis):
            label = f"dpi-{dpi}" if dpi else "original"
            folder = outgoing / label
            folder.mkdir(parents=True, exist_ok=True)
            candidate = {"label": label, "dpi": dpi, "status": "error"}
            candidates.append(candidate)
            with _lock:
                job = _jobs.get(job_id)
                if job is not None:
                    job["tracker"] = _SheetProgress(index, len(dpis))
            _update(job_id, step=f"{label}:start")
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                candidate["error"] = "job time budget exhausted"
                continue
            attempt_started = time.monotonic()
            try:
                # Reserve time for the second pass instead of letting the first use it all.
                result = _run_audiveris(
                    job_id, source, folder, profile, dpi,
                    max(0.1, remaining / (len(dpis) - index)),
                )
                candidate["metrics"] = _inspect_score(result)
                candidate["status"] = "ok"
                candidate["result"] = str(result.relative_to(outgoing))
            except Exception as exc:  # A failed retry must not discard a usable baseline.
                candidate["error"] = str(exc)[-2000:]
            finally:
                candidate["elapsed_seconds"] = round(time.monotonic() - attempt_started, 2)
        selected, reason = _select_candidate(candidates)
        report = {
            "pipeline": PIPELINE, "profile": profile,
            "selected": selected["label"] if selected else None,
            "selection_reason": reason, "candidates": candidates,
            "accuracy_verified": False,
            "ocr_languages": os.environ.get("OMR_OCR_LANGUAGES", "").strip() or "Audiveris default",
        }
        (outgoing / "recognition.json").write_text(
            json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8"
        )
        if selected is None:
            raise RuntimeError("No valid MusicXML result; see recognition.json and candidate logs")
        selected_file = outgoing / selected["result"]
        result = outgoing / selected_file.name
        shutil.copy2(selected_file, result)
        shutil.copy2(selected_file.parent / "audiveris.log", outgoing / "audiveris.log")
        _update(
            job_id, status="done", progress=100, step="done",
            result=str(result), finished=time.time(),
        )
    except Exception as exc:  # noqa: BLE001
        _update(
            job_id, status="error", progress=100,
            error=str(exc)[-2000:], finished=time.time(),
        )


def _stop_process(proc) -> None:
    try:
        if os.name == "posix":
            os.killpg(proc.pid, signal.SIGKILL)
        else:
            proc.kill()
    except ProcessLookupError:
        pass


def _run_audiveris(
    job_id: str, source: Path, outgoing: Path, profile: str,
    dpi: int | None, timeout: float,
) -> Path:
    env = {**os.environ, "JAVA_TOOL_OPTIONS": "-Xmx4g"}
    proc = subprocess.Popen(
        _convert_cmd(source, outgoing, profile, dpi),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        env=env,
        start_new_session=os.name == "posix",
    )
    assert proc.stdout is not None
    timed_out = threading.Event()

    def _kill_on_timeout() -> None:
        if proc.poll() is not None:
            return
        timed_out.set()
        _stop_process(proc)

    timeout_timer = threading.Timer(timeout, _kill_on_timeout)
    timeout_timer.start()
    stop_hb = threading.Event()

    def _heartbeat() -> None:
        while not stop_hb.wait(1.5):
            with _lock:
                job = _jobs.get(job_id)
                if job is None:
                    return
                tracker = job.get("tracker")
                if tracker is None:
                    continue
                percent = tracker.tick()
                job["progress"] = max(int(job.get("progress") or 0), percent)

    threading.Thread(target=_heartbeat, daemon=True).start()
    try:
        with (outgoing / "audiveris.log").open("w", encoding="utf-8") as log:
            for line in proc.stdout:
                log.write(line)
                progress, step = _observe_progress(job_id, line)
                if progress or step:
                    fields = {"progress": progress}
                    if step:
                        fields["step"] = step
                    _update(job_id, **fields)
        code = proc.wait()
    finally:
        stop_hb.set()
        timeout_timer.cancel()
        if proc.poll() is None:
            _stop_process(proc)
            proc.wait()
        proc.stdout.close()
    if timed_out.is_set():
        raise TimeoutError("convert timed out")
    result = _find_score(outgoing)
    if code != 0 or result is None:
        raise RuntimeError(f"Audiveris failed (exit {code}); see {outgoing.name}/audiveris.log")
    return result


class _SheetProgress:
    def __init__(self, attempt: int = 0, attempts: int = 1) -> None:
        self.attempt = attempt
        self.attempts = attempts
        self.sheet = 1
        self.sheets = 1
        self.step_index = -1
        self.percent = 1
        self.step_started = time.time()

    def _band(self, index: int) -> tuple[float, float]:
        sheets = max(self.sheets, self.sheet, 1)
        before = sum(STEP_WEIGHTS[STEPS[i]] for i in range(index))
        weight = STEP_WEIGHTS[STEPS[index]]
        start = (self.sheet - 1 + before / TOTAL_WEIGHT) / sheets
        end = (self.sheet - 1 + (before + weight) / TOTAL_WEIGHT) / sheets
        return (
            8 + (self.attempt + start) * 90 / self.attempts,
            8 + (self.attempt + end) * 90 / self.attempts,
        )

    def tick(self) -> int:
        if self.step_index < 0:
            return self.percent
        lo, hi = self._band(self.step_index)
        weight = STEP_WEIGHTS[STEPS[self.step_index]]
        estimated = max(10.0, weight * 3.0)
        elapsed = max(0.0, time.time() - self.step_started)
        # Approach the end of this step's band without leaving it.
        t = 1.0 - math.exp(-elapsed / estimated)
        dripped = lo + (hi - lo - 1) * t
        self.percent = max(self.percent, min(99, int(dripped)))
        return self.percent

    def observe(self, line: str) -> tuple[int, str]:
        for pattern in (_STUB_RE, _SHEET_RE):
            for match in pattern.finditer(line):
                number = max(1, int(match.group(1)))
                self.sheet = max(self.sheet, number)
                self.sheets = max(self.sheets, self.sheet)
        match = _STEP_RE.search(line.upper())
        if not match:
            return self.tick(), ""
        step = match.group(1)
        index = STEP_INDEX.get(step)
        if index is None:
            return self.tick(), ""
        if index != self.step_index:
            self.step_index = index
            self.step_started = time.time()
        lo, _hi = self._band(index)
        self.percent = max(self.percent, min(99, int(lo)))
        return self.percent, step


def _observe_progress(job_id: str, line: str) -> tuple[int, str]:
    with _lock:
        job = _jobs.get(job_id)
        if job is None:
            return 0, ""
        tracker: _SheetProgress = job.setdefault("tracker", _SheetProgress())
        return tracker.observe(line)


def _update(job_id: str, **fields) -> None:
    with _lock:
        job = _jobs.get(job_id)
        if job is None:
            return
        for key, value in fields.items():
            if key == "progress":
                if not value:
                    continue
                job[key] = max(int(job.get("progress") or 0), int(value))
            else:
                job[key] = value


def _convert_cmd(
    source: Path, outgoing: Path, profile: str, dpi: int | None = None,
) -> list[str]:
    audiveris = "/opt/audiveris/bin/Audiveris"
    command = [
        "xvfb-run",
        "-a",
        audiveris,
        "-batch",
        "-save",
        "-export",
        "-output",
        str(outgoing),
    ]
    if dpi is not None:
        if not 200 <= dpi <= 500:
            raise ValueError("PDF DPI must be in 200..500")
        command += [
            "-constant", f"org.audiveris.omr.image.ImageLoading.pdfResolution={dpi}",
        ]
    if profile == "chords_lyrics":
        command += [
            "-constant",
            "org.audiveris.omr.sheet.ProcessingSwitches.chordNames=true",
            "-constant",
            "org.audiveris.omr.sheet.ProcessingSwitches.lyrics=true",
        ]
    languages = os.environ.get("OMR_OCR_LANGUAGES", "").strip()
    if languages:
        if not re.fullmatch(r"[a-z]{3}(?:\+[a-z]{3})*", languages):
            raise ValueError("OMR_OCR_LANGUAGES must be codes like kor+eng")
        command += [
            "-constant",
            f"org.audiveris.omr.text.Language.defaultSpecification={languages}",
        ]
    return [*command, str(source)]


def _find_score(folder: Path) -> Path | None:
    files = sorted(folder.glob("*.mxl"))
    if not files:
        files = sorted(folder.glob("*.xml")) + sorted(folder.glob("*.musicxml"))
    files = [path for path in files if path.name.lower() != "container.xml"]
    if len(files) > 1:
        raise ValueError("Multiple exported scores; refusing to return only the first movement")
    return files[0] if files else None


def _read_score(path: Path) -> ET.Element:
    if path.suffix.lower() == ".mxl":
        with zipfile.ZipFile(path) as archive:
            container = ET.fromstring(archive.read("META-INF/container.xml"))
            entries = [node for node in container.iter() if node.tag.rsplit("}", 1)[-1] == "rootfile"]
            if not entries or not entries[0].get("full-path"):
                raise ValueError("MXL rootfile is missing")
            info = archive.getinfo(entries[0].get("full-path"))
            if info.file_size > 64 * 1024 * 1024:
                raise ValueError("MusicXML is too large to inspect")
            root = ET.fromstring(archive.read(info))
    else:
        if path.stat().st_size > 64 * 1024 * 1024:
            raise ValueError("MusicXML is too large to inspect")
        root = ET.fromstring(path.read_bytes())
    for node in root.iter():
        node.tag = node.tag.rsplit("}", 1)[-1]
    if root.tag != "score-partwise":
        raise ValueError("Expected score-partwise MusicXML")
    return root


def _inspect_score(path: Path) -> dict:
    """Measure structural evidence, not accuracy; never rewrite recognized notes."""
    root = _read_score(path)
    parts = root.findall("part")
    metrics = {
        "parts": len(parts), "measures_by_part": [], "pitched_notes": 0,
        "notes_and_rests": 0, "pages": 1, "empty_measures": 0,
        "rhythm_issues": 0, "invalid_durations": 0, "unresolved_ties": 0,
        "measures_with_time": 0,
    }
    for part in parts:
        measures = part.findall("measure")
        metrics["measures_by_part"].append(len(measures))
        divisions = Fraction(1)
        expected = None
        ties = {}
        pages = 1
        for measure in measures:
            cursor = Fraction(0)
            extent = Fraction(0)
            last_onset = Fraction(0)
            note_count = 0
            for item in measure:
                if item.tag == "print" and item.get("new-page") == "yes":
                    # A first-measure print can mark the first page, not an extra page.
                    if measure is not measures[0]:
                        pages += 1
                elif item.tag == "attributes":
                    value = item.findtext("divisions")
                    if value:
                        divisions = Fraction(value)
                        if divisions <= 0:
                            raise ValueError("MusicXML divisions must be positive")
                    time_signature = item.find("time")
                    if time_signature is not None:
                        beats = time_signature.findall("beats")
                        types = time_signature.findall("beat-type")
                        if beats and len(beats) == len(types):
                            expected = sum(
                                (sum(Fraction(v) for v in (beat.text or "").split("+"))
                                 * 4 / Fraction(kind.text or "0"))
                                for beat, kind in zip(beats, types)
                            )
                        else:
                            expected = None
                elif item.tag in {"backup", "forward"}:
                    amount = Fraction(item.findtext("duration", "0")) / divisions
                    if amount <= 0:
                        metrics["invalid_durations"] += 1
                    cursor += amount if item.tag == "forward" else -amount
                    if cursor < 0:
                        metrics["invalid_durations"] += 1
                    extent = max(extent, cursor)
                elif item.tag == "note":
                    note_count += 1
                    metrics["notes_and_rests"] += 1
                    pitch = item.find("pitch")
                    if pitch is not None or item.find("unpitched") is not None:
                        metrics["pitched_notes"] += 1
                    if item.find("grace") is not None:
                        continue
                    duration = Fraction(item.findtext("duration", "0")) / divisions
                    if duration <= 0:
                        metrics["invalid_durations"] += 1
                    is_chord = item.find("chord") is not None
                    onset = last_onset if is_chord else cursor
                    extent = max(extent, onset + duration)
                    if not is_chord:
                        last_onset = cursor
                        cursor += duration
                    if pitch is not None:
                        key = (
                            item.findtext("voice", "1"), pitch.findtext("step"),
                            pitch.findtext("alter", "0"), pitch.findtext("octave"),
                        )
                        types = {tie.get("type") for tie in item.findall("tie")}
                        types.update(tie.get("type") for tie in item.findall("notations/tied"))
                        if "stop" in types:
                            if ties.get(key, 0) > 0:
                                ties[key] -= 1
                            else:
                                metrics["unresolved_ties"] += 1
                        if "start" in types:
                            ties[key] = ties.get(key, 0) + 1
            if not note_count:
                metrics["empty_measures"] += 1
            if expected is not None and note_count:
                metrics["measures_with_time"] += 1
                # A shorter pickup is legal; a longer pickup is not.
                implicit = measure.get("implicit") == "yes"
                if extent > expected or (not implicit and extent != expected):
                    metrics["rhythm_issues"] += 1
        metrics["pages"] = max(metrics["pages"], pages)
        metrics["unresolved_ties"] += sum(ties.values())
    if not parts or not metrics["pitched_notes"]:
        raise ValueError("No recognized pitched/unpitched notes in MusicXML")
    return metrics


def _select_candidate(candidates: list[dict]) -> tuple[dict | None, str]:
    valid = [candidate for candidate in candidates if candidate["status"] == "ok"]
    if not valid:
        return None, "all_attempts_failed"
    baseline = valid[0]
    if baseline is not candidates[0]:
        return baseline, "baseline_failed_using_valid_retry"
    reference = baseline["metrics"]
    keys = ("invalid_durations", "empty_measures", "rhythm_issues", "unresolved_ties")
    for candidate in valid[1:]:
        metrics = candidate["metrics"]
        # Do not reward lost parts/pages/measures or dramatically fewer notes.
        coverage = (
            metrics["measures_by_part"] == reference["measures_by_part"]
            and metrics["pages"] == reference["pages"]
            and metrics["pitched_notes"] * 100 >= reference["pitched_notes"] * 98
            and metrics["measures_with_time"] >= reference["measures_with_time"]
        )
        no_worse = all(metrics[key] <= reference[key] for key in keys)
        improves = any(metrics[key] < reference[key] for key in keys)
        if coverage and no_worse and improves:
            return candidate, "retry_improves_structure_with_coverage_guard"
    return baseline, "baseline_retained_no_safe_structural_improvement"


def _reaper() -> None:
    while True:
        time.sleep(60)
        now = time.time()
        with _lock:
            stale = [
                job_id
                for job_id, job in _jobs.items()
                if job.get("finished") and now - job["finished"] > KEEP_SEC
            ]
            for job_id in stale:
                job = _jobs.pop(job_id, None)
                if job and job.get("root"):
                    shutil.rmtree(job["root"], ignore_errors=True)


def main() -> None:
    JOBS_DIR.mkdir(parents=True, exist_ok=True)
    threading.Thread(target=_reaper, daemon=True).start()
    app.run(host=HOST, port=PORT, threaded=True)


if __name__ == "__main__":
    main()
