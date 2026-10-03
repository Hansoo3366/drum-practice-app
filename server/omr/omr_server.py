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
import tempfile
import threading
import time
import uuid
import zipfile
from fractions import Fraction
from pathlib import Path
from xml.etree import ElementTree as ET

from flask import Flask, jsonify, request, send_file

from omr_score import PIPELINE, _find_score, _read_score, _write_mxl
from omr_rules import _clamp_backups, _add_lyric_dashes, _chords_from_words, _drop_bad_tempos, _drop_lyric_dash_articulations, _drop_placeholder_rests, _drop_second_chords, _drop_tie_dots, _merge_split_parts, _split_korean_lyrics, _tie_held_dashes, _title_from_credits
from omr_book import _load_book
from omr_marks import _add_segno_coda, _navigation_marks, _repeat_starts, _segno_coda_marks, _upload_photos
from omr_text import _attach_stray_accidentals, _drop_chord_junk, _ocr_chord_lines, _ocr_lyrics, _reread_chords
from omr_validate import _corrections, _validate
from omr_ai import ARRANGE_MAX_BRIEF, _ai_enabled, _ai_review, _arrange_advice
from omr_annotations import _separate_upload
from omr_clients import Clients, Quota

# The app key: every build of the app carries it, so it only says "this is the app".
TOKEN = os.environ.get("OMR_TOKEN", "piano-omr-dev")
# Builds from before installs registered send the app key with every request. "0" turns
# them away once they are no longer in use.
LEGACY_TOKEN = os.environ.get("OMR_LEGACY_TOKEN", "1") != "0"
CLIENTS = Clients(Path(os.environ.get("OMR_CLIENTS", "/opt/omr/state/clients.json")))
QUOTA = Quota(Path(os.environ.get("OMR_QUOTA", "/opt/omr/state/quota.json")))


def _most(name: str, default: int) -> int:
    return max(0, int(os.environ.get(name, str(default))))


# Most per day (UTC): for one install, one network address, and everyone together.
LIMITS = {
    "register": {"address": _most("OMR_REGISTER_PER_ADDRESS", 10), "all": _most("OMR_REGISTER_PER_DAY", 500)},
    "convert": {"client": _most("OMR_CONVERT_PER_CLIENT", 30), "address": _most("OMR_CONVERT_PER_ADDRESS", 60),
                "all": _most("OMR_CONVERT_PER_DAY", 500)},
    "ai": {"client": _most("OMR_AI_PER_CLIENT", 60), "address": _most("OMR_AI_PER_ADDRESS", 120),
           "all": _most("OMR_AI_PER_DAY", 1000)},
}
JOBS_DIR = Path(os.environ.get("OMR_JOBS", "/opt/omr/jobs"))
HOST = os.environ.get("OMR_HOST", "0.0.0.0")
PORT = int(os.environ.get("OMR_PORT", "8080"))
TIMEOUT_SEC = int(os.environ.get("OMR_TIMEOUT", "1200"))
KEEP_SEC = int(os.environ.get("OMR_KEEP_SEC", "21600"))
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


def _sent_keys() -> tuple[str, str]:
    """The app key header and the bearer secret of the request."""
    header = request.headers.get("X-Omr-Token", "")
    auth = request.headers.get("Authorization", "")
    return header, auth[7:].strip() if auth.lower().startswith("bearer ") else ""


def _caller() -> str | None:
    """The install that sent the request: its id, "legacy" for a build that only has the
    app key, or None."""
    header, bearer = _sent_keys()
    client = CLIENTS.find(bearer)
    if client:
        return client
    return "legacy" if LEGACY_TOKEN and TOKEN in (header, bearer) else None


def _authorized() -> bool:
    return _caller() is not None


def _address() -> str:
    """Where the request came from. Only our own proxy on this machine is believed about
    whom it forwards for."""
    remote = request.remote_addr or ""
    forwarded = request.headers.get("X-Forwarded-For", "")
    if forwarded and remote in ("127.0.0.1", "::1"):
        return forwarded.split(",")[-1].strip()
    return remote


def _spend(kind: str):
    """Count one [kind] for the caller. Returns the 429 answer when a daily limit is used
    up, else None. Builds that share the app key are counted by address and in total."""
    caller, most = _caller(), LIMITS[kind]
    limits = {f"address:{_address()}": most["address"], "all": most["all"]}
    if caller and caller != "legacy" and "client" in most:
        limits = {f"client:{caller}": most["client"], **limits}
    used_up = QUOTA.spend(kind, limits)
    if used_up is None:
        return None
    return jsonify(error="rate limited", scope=used_up.split(":")[0]), 429


def _own_job(job_id: str) -> dict | None:
    """The job, when the caller may see it: an install only sees what it uploaded."""
    job = _jobs.get(job_id)
    if job is None:
        return None
    owner = job.get("client")
    return job if not owner or owner == _caller() else None


def _public(job: dict) -> dict:
    return {
        "id": job["id"],
        "status": job["status"],
        "progress": job["progress"],
        "step": job.get("step") or "",
        "error": job.get("error") or "",
        "profile": job["profile"],
        # AI review: off, running, done (ai.mxl ready), unchanged, error.
        "ai": job.get("ai") or "off",
    }


_SAVED_FIELDS = ("id", "status", "progress", "step", "error", "result", "created", "finished",
                 "profile", "book", "ai", "client")


def _save_job(job: dict) -> None:
    """Keep a finished job on disk, so its results outlive a server restart."""
    if not job.get("root"):
        return
    state = {key: job.get(key) for key in _SAVED_FIELDS}
    try:
        (Path(job["root"]) / "job.json").write_text(json.dumps(state), encoding="utf-8")
    except OSError:
        pass


def _restore_jobs() -> None:
    """Register the jobs a previous server process left in JOBS_DIR. A job
    without a saved state was cut off by the restart and reports an error."""
    for root in JOBS_DIR.iterdir() if JOBS_DIR.is_dir() else []:
        if not root.is_dir() or root.name in _jobs:
            continue
        try:
            state = json.loads((root / "job.json").read_text(encoding="utf-8"))
        except (OSError, ValueError):
            finished = root.stat().st_mtime
            state = {"status": "error", "progress": 100, "error": "interrupted by a server restart",
                     "created": finished, "finished": finished, "profile": "standard"}
        if state.get("ai") == "running":
            state["ai"] = "error"
        _jobs[root.name] = {**state, "id": root.name, "root": root, "tracker": _SheetProgress()}


@app.get("/health")
def health():
    return jsonify(ok=True, pipeline=PIPELINE)


@app.post("/clients")
def register_client():
    """An install registers once and keeps the secret it gets."""
    header, bearer = _sent_keys()
    if TOKEN not in (header, bearer):
        return jsonify(error="unauthorized"), 401
    address = _address()
    most = LIMITS["register"]
    if QUOTA.spend("register", {f"address:{address}": most["address"], "all": most["all"]}) is not None:
        return jsonify(error="rate limited", scope="address"), 429
    client, secret = CLIENTS.register(address)
    return jsonify(client=client, secret=secret), 201


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
    limited = _spend("convert")
    if limited is not None:
        return limited

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
        "client": _caller(),
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
        job = _own_job(job_id)
        if job is None:
            return jsonify(error="not found"), 404
        payload = _public(job)
    return jsonify(payload)


@app.get("/jobs/<job_id>/result")
def job_result(job_id: str):
    if not _authorized():
        return jsonify(error="unauthorized"), 401
    with _lock:
        job = _own_job(job_id)
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
        job = _own_job(job_id)
        if job is None:
            return jsonify(error="not found"), 404
        report = Path(job["root"]) / "out" / "recognition.json"
    if not report.is_file():
        return jsonify(error="not ready"), 409
    return send_file(report, mimetype="application/json")


@app.get("/jobs/<job_id>/raw")
def job_raw(job_id: str):
    """MusicXML as Audiveris exported it, before any server correction."""
    return _job_file(job_id, "raw.mxl", "application/vnd.recordare.musicxml+xml")


@app.get("/jobs/<job_id>/corrections")
def job_corrections(job_id: str):
    """Every server correction as before/after items (OMR spec §19)."""
    return _job_file(job_id, "corrections.json", "application/json")


@app.get("/jobs/<job_id>/validation")
def job_validation(job_id: str):
    """Rule-based suspect measures (OMR spec Phase 2)."""
    return _job_file(job_id, "validation.json", "application/json")


@app.get("/jobs/<job_id>/annotations")
def job_annotations(job_id: str):
    """Colour annotations taken out of the upload, with their page boxes (OMR spec §20)."""
    return _job_file(job_id, "annotations.json", "application/json")


@app.get("/jobs/<job_id>/annotations/<name>")
def job_annotation_image(job_id: str, name: str):
    """A page's annotations alone (`page-N.annotation.png`) or the page without them."""
    match = re.fullmatch(r"page-\d+\.(annotation\.png|clean\.jpg)", name)
    if match is None:
        return jsonify(error="not found"), 404
    return _job_file(
        job_id, f"annotations/{name}", "image/png" if name.endswith(".png") else "image/jpeg",
    )


@app.get("/jobs/<job_id>/ai")
def job_ai(job_id: str):
    """The AI version: chord and lyric suggestions applied to the result."""
    return _job_file(job_id, "ai.mxl", "application/vnd.recordare.musicxml+xml")


@app.get("/jobs/<job_id>/ai-review")
def job_ai_review(job_id: str):
    """Every AI suggestion per measure, applied or listed only."""
    return _job_file(job_id, "ai_review.json", "application/json")


@app.get("/jobs/<job_id>/suspects/<name>")
def job_suspect_image(job_id: str, name: str):
    """Original crop around one suspect measure."""
    if not re.fullmatch(r"p\d+-s\d+-m(?:\d+|all)\.png", name):
        return jsonify(error="not found"), 404
    return _job_file(job_id, f"suspects/{name}", "image/png")


@app.get("/jobs/<job_id>/layout")
def job_layout(job_id: str):
    """Where every measure is on the original: its staff-line image and place in it."""
    return _job_file(job_id, "layout.json", "application/json")


@app.get("/jobs/<job_id>/systems/<name>")
def job_system_image(job_id: str, name: str):
    """One staff line of the original page."""
    if not re.fullmatch(r"p\d+-s\d+(?:-part\d+)?\.jpg", name):
        return jsonify(error="not found"), 404
    return _job_file(job_id, f"systems/{name}", "image/jpeg")


def _job_file(job_id: str, name: str, mimetype: str):
    if not _authorized():
        return jsonify(error="unauthorized"), 401
    with _lock:
        job = _own_job(job_id)
        if job is None:
            return jsonify(error="not found"), 404
        if job["status"] != "done":
            return jsonify(error="not ready"), 409
        path = Path(job["root"]) / "out" / name
    if not path.is_file():
        return jsonify(error="not available"), 404
    return send_file(path, mimetype=mimetype, as_attachment=True, download_name=Path(name).name)


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
        # Colour pen and highlighter are taken out of what the engine reads;
        # the upload itself stays as it is (OMR spec MODULE-03).
        annotations = None
        try:
            source, annotations = _separate_upload(source, outgoing)
        except Exception as exc:  # noqa: BLE001 - a failed clean-up never fails a job
            annotations = {"error": str(exc)[-500:]}
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
                skipped = _skipped_sheets(folder)
                if skipped:
                    candidate["skipped_sheets"] = skipped
                raw = result
                result, repairs = _postprocess(result, profile)
                if repairs:
                    candidate["repairs"] = repairs
                candidate["raw_result"] = str(raw.relative_to(outgoing))
                if result != raw:
                    corrections = _corrections(_read_score(raw), _read_score(result))
                    corrections_file = result.with_name("corrections.json")
                    corrections_file.write_text(
                        json.dumps(corrections, ensure_ascii=False, indent=2), encoding="utf-8",
                    )
                    candidate["corrections"] = len(corrections["items"])
                candidate["metrics"] = _inspect_score(result)
                try:
                    candidate["validation"] = _validate(result, folder)
                except Exception as exc:  # noqa: BLE001 - validation never fails a job
                    candidate["validation_error"] = str(exc)[-500:]
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
            "annotations": (
                None if annotations is None
                else annotations if "error" in annotations
                else {"pages": sum(1 for page in annotations["pages"] if page["annotations"]),
                      "items": len(annotations["items"])}
            ),
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
        # The uncorrected export and the correction history, kept apart so
        # the app can store the original and let the user go back to it.
        shutil.copy2(outgoing / selected["raw_result"], outgoing / "raw.mxl")
        if (selected_file.parent / "corrections.json").is_file():
            shutil.copy2(selected_file.parent / "corrections.json", outgoing / "corrections.json")
        if (selected_file.parent / "validation.json").is_file():
            shutil.copy2(selected_file.parent / "validation.json", outgoing / "validation.json")
        if (selected_file.parent / "suspects").is_dir():
            shutil.copytree(selected_file.parent / "suspects", outgoing / "suspects", dirs_exist_ok=True)
        if (selected_file.parent / "layout.json").is_file():
            shutil.copy2(selected_file.parent / "layout.json", outgoing / "layout.json")
            shutil.copytree(selected_file.parent / "systems", outgoing / "systems", dirs_exist_ok=True)
        shutil.copy2(selected_file.parent / "audiveris.log", outgoing / "audiveris.log")
        ai = "off"
        if profile == "chords_lyrics" and _ai_enabled():
            _update(job_id, progress=96, step="ai-review")
            report["ai_review"], ai = _run_ai_review(result, selected_file.parent, outgoing)
            (outgoing / "recognition.json").write_text(
                json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8"
            )
        _update(
            job_id, status="done", progress=100, step="done",
            result=str(result), finished=time.time(), book=str(selected_file.parent), ai=ai,
        )
    except Exception as exc:  # noqa: BLE001
        _update(
            job_id, status="error", progress=100,
            error=str(exc)[-2000:], finished=time.time(),
        )


def _run_ai_review(result: Path, book: Path, outgoing: Path) -> tuple[dict, str]:
    """The review report and the job's AI state; AI review never fails a job."""
    (outgoing / "ai.mxl").unlink(missing_ok=True)
    try:
        review = _ai_review(result, book, outgoing)
    except Exception as exc:  # noqa: BLE001
        return {"status": "error", "error": str(exc)[-500:]}, "error"
    if (outgoing / "ai.mxl").is_file():
        return review, "done"
    measures = review.get("measures") or 0
    if review.get("status") == "skipped" or (measures and review.get("errors", 0) >= measures):
        return review, "error"
    return review, "unchanged"


@app.post("/jobs/<job_id>/ai-review")
def job_ai_retry(job_id: str):
    """Run the AI review again, e.g. after it failed for lack of API credit."""
    if not _authorized():
        return jsonify(error="unauthorized"), 401
    with _lock:
        job = _own_job(job_id)
        if job is None:
            return jsonify(error="not found"), 404
        if job["status"] != "done":
            return jsonify(error="not ready"), 409
        if job.get("ai") == "running":
            return jsonify(_public(job)), 202
        book = Path(job.get("book") or "")
        if job["profile"] != "chords_lyrics" or not job.get("book") or not book.is_dir():
            return jsonify(error="not available"), 404
        if not _ai_enabled():
            return jsonify(error="ai unavailable"), 503
        limited = _spend("ai")
        if limited is not None:
            return limited
        job["ai"] = "running"
        _save_job(job)
        payload = _public(job)
        result, outgoing = Path(job["result"]), Path(job["root"]) / "out"

    def run() -> None:
        _review, state = _run_ai_review(result, book, outgoing)
        _update(job_id, ai=state)

    threading.Thread(target=run, daemon=True).start()
    return jsonify(payload), 202


@app.post("/arrange/advice")
def arrange_advice():
    """Accompaniment style per section and chord symbols to look at again, for a lead sheet
    the app describes as text."""
    if not _authorized():
        return jsonify(error="unauthorized"), 401
    payload = request.get_json(silent=True) or {}
    brief, bars = payload.get("brief"), payload.get("bars")
    if (not isinstance(brief, str) or not brief.strip() or len(brief) > ARRANGE_MAX_BRIEF
            or not isinstance(bars, int) or isinstance(bars, bool) or bars < 1):
        return jsonify(error="bad request"), 400
    if not _ai_enabled():
        return jsonify(error="ai unavailable"), 503
    limited = _spend("ai")
    if limited is not None:
        return limited
    try:
        return jsonify(_arrange_advice(brief, bars))
    except Exception as error:  # noqa: BLE001 - the model call failed; the app falls back to its defaults
        return jsonify(error="ai failed", detail=str(error)[-200:]), 502


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
    started = time.monotonic()
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
        result = _export_valid_sheets(outgoing, env, timeout - (time.monotonic() - started))
    if result is None:
        raise RuntimeError(f"Audiveris failed (exit {code}); see {outgoing.name}/audiveris.log")
    return result


def _book_sheets(book: Path) -> tuple[list[int], list[int]]:
    """Valid and invalid sheet numbers recorded in a saved .omr book."""
    with zipfile.ZipFile(book) as archive:
        root = ET.fromstring(archive.read("book.xml"))
    valid, invalid = [], []
    for sheet in root.findall("sheet"):
        number = int(sheet.get("number", "0"))
        (invalid if sheet.get("invalid") == "true" else valid).append(number)
    return valid, invalid


def _sheet_ranges(numbers: list[int]) -> list[str]:
    ranges: list[str] = []
    for number in sorted(numbers):
        if ranges and ranges[-1].split("-")[-1] == str(number - 1):
            ranges[-1] = f"{ranges[-1].split('-')[0]}-{number}"
        else:
            ranges.append(str(number))
    return ranges


def _export_valid_sheets(outgoing: Path, env: dict, timeout: float) -> Path | None:
    """Export the sheets Audiveris could read when others were invalid.

    A cover or lyrics page has no staff, so Audiveris flags it invalid and
    then refuses to export the whole book. The saved book already holds the
    transcribed sheets, so exporting only those takes seconds.
    """
    books = sorted(outgoing.glob("*.omr"))
    if len(books) != 1 or timeout <= 0:
        return None
    try:
        valid, invalid = _book_sheets(books[0])
    except (OSError, KeyError, ValueError, zipfile.BadZipFile, ET.ParseError):
        return None
    if not valid or not invalid:
        return None
    command = [
        "xvfb-run", "-a", "/opt/audiveris/bin/Audiveris", "-batch", "-export",
        "-sheets", *_sheet_ranges(valid), "-output", str(outgoing), str(books[0]),
    ]
    with (outgoing / "audiveris.log").open("a", encoding="utf-8") as log:
        log.write(f"\n# Exporting valid sheets {valid}; skipping invalid sheets {invalid}\n")
        log.flush()
        proc = subprocess.Popen(
            command, stdout=log, stderr=subprocess.STDOUT, env=env,
            start_new_session=os.name == "posix",
        )
        try:
            code = proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            _stop_process(proc)
            proc.wait()
            return None
    return _find_score(outgoing) if code == 0 else None


def _skipped_sheets(folder: Path) -> list[int]:
    books = sorted(folder.glob("*.omr"))
    if len(books) != 1:
        return []
    try:
        return _book_sheets(books[0])[1]
    except (OSError, KeyError, ValueError, zipfile.BadZipFile, ET.ParseError):
        return []


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
        if "finished" in fields or "ai" in fields:
            _save_job(job)


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
    # Section letters (A/B/C) in the left margin make a system look indented,
    # and Audiveris then starts a new movement there. A movement drops the
    # time signature, so later bars lose their target duration. An uploaded
    # file is always one song, so indentation never means a new movement.
    command += [
        "-constant",
        "org.audiveris.omr.sheet.ProcessingSwitches.indentations=false",
    ]
    if profile == "chords_lyrics":
        command += [
            "-constant",
            "org.audiveris.omr.sheet.ProcessingSwitches.chordNames=true",
            "-constant",
            "org.audiveris.omr.sheet.ProcessingSwitches.lyrics=true",
            # Lead sheets rarely print dynamics, while OCR noise from Korean
            # lyrics and chord symbols is often taken for p, pp or mp.
            "-constant",
            "org.audiveris.omr.sheet.ProcessingSwitches.dynamicsAboveStaff=false",
            "-constant",
            "org.audiveris.omr.sheet.ProcessingSwitches.dynamicsBelowStaff=false",
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


def _postprocess(path: Path, profile: str) -> tuple[Path, dict]:
    """Apply structural repairs, and lead-sheet repairs for chords and lyrics."""
    root = _read_score(path)
    if profile != "chords_lyrics":
        merged = _merge_split_parts(root)
        if not merged:
            return path, {}
        stem = path.name[: -len(path.suffix)] if path.suffix else path.name
        return _write_mxl(root, path.with_name(f"{stem}.fixed.mxl")), {"parts_merged": merged}
    original = ET.tostring(root)
    dashes = _drop_lyric_dash_articulations(root)
    report = {"chords_from_words": _chords_from_words(root), "chords_reread": 0, "lyrics_ocr": None,
              "lyric_dashes_removed": len(dashes), "placeholder_rests_removed": _drop_placeholder_rests(root),
              "tie_dots_removed": _drop_tie_dots(root), "second_chords_removed": _drop_second_chords(root),
              "bad_tempos_removed": _drop_bad_tempos(root)}
    book = _load_book(root, path.parent)
    if book is not None:
        report["repeat_starts"] = _repeat_starts(book)
        if report["repeat_starts"]:
            # Sung notes and onsets were indexed with the removed chords.
            book = _load_book(root, path.parent)
    if book is not None:
        with tempfile.TemporaryDirectory(dir=path.parent) as workdir:
            report["chords_reread"] = _reread_chords(book, Path(workdir))
            report["chords_added"] = _ocr_chord_lines(book, Path(workdir))
            report["chord_signs_attached"] = _attach_stray_accidentals(book["parts"])
            report["chord_junk_removed"] = _drop_chord_junk(book["parts"])
            report["lyrics_ocr"] = _ocr_lyrics(book, Path(workdir))
            photos = _upload_photos(path, book)
            report["navigation"] = _navigation_marks(book, Path(workdir), photos)
            report["signs"] = _add_segno_coda(book, _segno_coda_marks(book, photos))
    report["lyrics_split"] = _split_korean_lyrics(root)
    report["lyric_dashes"] = _add_lyric_dashes(dashes)
    report["ties_added"] = _tie_held_dashes(root)
    report["title"] = _title_from_credits(root)
    # Last: the repairs above address parts by their position in the book.
    report["parts_merged"] = _merge_split_parts(root)
    report["backups_clamped"] = _clamp_backups(root)
    # Every repair edits the tree, so an unchanged tree means nothing was fixed.
    if ET.tostring(root) == original:
        return path, report
    stem = path.name[: -len(path.suffix)] if path.suffix else path.name
    return _write_mxl(root, path.with_name(f"{stem}.fixed.mxl")), report


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
    with _lock:
        _restore_jobs()
    threading.Thread(target=_reaper, daemon=True).start()
    app.run(host=HOST, port=PORT, threaded=True)


if __name__ == "__main__":
    main()
