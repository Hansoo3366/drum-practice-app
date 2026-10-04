"""AI verification of suspect measures (OMR spec Phase 3/5, §10-14).

The OMR engine and the server rules produce the score; a vision model only
looks at a crop of the original around a suspect measure next to what was
recognized there, and returns corrections for what it can see. It never
rewrites a measure, and every answer carries a confidence so the caller can
split automatic fixes from user review (§14).
"""

from __future__ import annotations

import base64
import json
import os
import time
import urllib.error
import urllib.request
from pathlib import Path

OPENAI_URL = "https://api.openai.com/v1/responses"
# Gemini and Qwen speak the OpenAI chat-completions dialect at these endpoints.
CHAT_PROVIDERS = {
    "gemini": ("https://generativelanguage.googleapis.com/v1beta/openai/chat/completions", "GEMINI_API_KEY"),
    "qwen": ("https://dashscope-intl.aliyuncs.com/compatible-mode/v1/chat/completions", "DASHSCOPE_API_KEY"),
}

INSTRUCTIONS = """You check the result of optical music recognition (OMR) of a lead sheet
against a picture of the printed original: one staff line, with the number
of each measure written in red above the bar it starts. You get what OMR
recognized for those measures as text.

Rules:
- Only report differences you can clearly see in the image. Never guess
  hidden or unreadable content; report it under "uncertain" instead, with
  the reason as one short sentence in Korean.
- Do not rewrite measures. Report each wrong element separately.
- Chord symbols: write them like F#m7, Bb/D, Esus4, C(add2). Report the full
  list of chords of a measure in order when the recognized list is wrong.
- Lyrics: Korean lyrics, one syllable per sung note, written without spaces.
  Report the full syllable string of one verse of one measure when wrong.
  A syllable sung over several notes (a melisma, printed with a line after
  it) is written once, then one "-" for each further note it is held on:
  "잊어버리고-앞에". Never repeat the syllable instead.
- Notes: report only clear pitch or duration errors, by note position (1-based
  within the measure).
- Melody: when a measure's notes are missing or mostly wrong (several notes
  off, or the measure is empty or far too short or long), give the whole
  measure once under field "melody" instead of note by note: every note and
  rest left to right as "pitch duration" tokens separated by commas, in the
  notation of RECOGNIZED (pitch like C5, F#4, Bb3, or rest; duration w, h,
  q, 8, 16, 32, a dot for dotted). Example: "G4 q, A4 8, B4 8., C5 16, rest q".
  It must fill the measure exactly for its time signature. Only when every
  note is clearly readable; tuplets and chords cannot be written this way,
  so leave such measures alone.
- confidence is your probability (0-1) that the suggested value is exactly
  what the original shows.
- If everything you can see matches, return an empty corrections list."""

SCHEMA = {
    "type": "object",
    "additionalProperties": False,
    "required": ["hasError", "corrections", "uncertain", "overallConfidence"],
    "properties": {
        "hasError": {"type": "boolean"},
        "corrections": {
            "type": "array",
            "items": {
                "type": "object",
                "additionalProperties": False,
                "required": ["measure", "field", "verse", "note", "current", "suggested", "confidence"],
                "properties": {
                    "measure": {"type": "string", "description": "measure number as given"},
                    "field": {"type": "string", "enum": ["chords", "lyrics", "pitch", "duration", "melody", "other"]},
                    "verse": {"type": ["string", "null"], "description": "lyric verse number, else null"},
                    "note": {"type": ["integer", "null"], "description": "1-based note position for pitch/duration, else null"},
                    "current": {"type": "string"},
                    "suggested": {"type": "string"},
                    "confidence": {"type": "number"},
                },
            },
        },
        "uncertain": {
            "type": "array",
            "items": {
                "type": "object",
                "additionalProperties": False,
                "required": ["measure", "reason"],
                "properties": {"measure": {"type": "string"},
                               "reason": {"type": "string", "description": "one short sentence in Korean"}},
            },
        },
        "overallConfidence": {"type": "number"},
    },
}


def describe_measures(measures: list[dict], context: dict) -> str:
    """Text for the model: what OMR recognized in the cropped measures."""
    lines = [
        f"TIME_SIGNATURE: {context.get('time') or 'unknown'}",
        f"KEY_FIFTHS: {context.get('fifths')}",
        f"VALIDATION: {context.get('issue') or 'none'}",
        "RECOGNIZED (left to right in the crop):",
    ]
    for measure in measures:
        lyrics = "; ".join(f"verse {v}: {t}" for v, t in sorted(measure.get("lyrics", {}).items())) or "none"
        lines.append(
            f"- measure {measure['number']}: chords={measure.get('chords') or []}; "
            f"lyrics: {lyrics}; notes: {measure.get('notes') or 'none'}"
        )
    return "\n".join(lines)


def verify(image: Path, text: str, model: str, api_key: str | None = None,
           timeout: float = 120.0) -> dict:
    """Ask `model` about one crop. Returns the parsed answer plus usage and latency."""
    provider = next((p for p in CHAT_PROVIDERS if model.startswith(p)), None)
    if provider is not None:
        return _verify_chat(provider, image, text, model, api_key, timeout)
    key = api_key or os.environ.get("OPENAI_API_KEY", "")
    if not key:
        raise RuntimeError("OPENAI_API_KEY is not set")
    # "gpt-5.6-terra@low" asks for less reasoning: most of this model's cost
    # is its thinking. Answers stay keyed by the full name.
    model, _, effort = model.partition("@")
    picture = base64.b64encode(image.read_bytes()).decode("ascii")
    body = {
        "model": model,
        **({"reasoning": {"effort": effort}} if effort else {}),
        "instructions": INSTRUCTIONS,
        "input": [{
            "role": "user",
            "content": [
                {"type": "input_text", "text": text},
                {"type": "input_image", "image_url": f"data:image/png;base64,{picture}"},
            ],
        }],
        "text": {"format": {"type": "json_schema", "name": "omr_check", "schema": SCHEMA, "strict": True}},
    }
    request = urllib.request.Request(
        OPENAI_URL, data=json.dumps(body).encode("utf-8"),
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
    )
    started = time.monotonic()
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", "replace")[:500]
        raise RuntimeError(f"OpenAI {error.code}: {detail}") from error
    latency = time.monotonic() - started
    text_out = "".join(
        part.get("text", "")
        for item in payload.get("output", []) if item.get("type") == "message"
        for part in item.get("content", []) if part.get("type") == "output_text"
    )
    usage = payload.get("usage", {})
    return _result(text_out, latency, usage.get("input_tokens", 0), usage.get("output_tokens", 0),
                   payload.get("model", model))


def _result(text_out: str, latency: float, tokens_in: int, tokens_out: int, model: str) -> dict:
    # Some models wrap JSON in a ```json fence despite the response format.
    body = text_out.strip()
    if body.startswith("```"):
        body = body.split("\n", 1)[-1].rsplit("```", 1)[0]
    try:
        answer = json.loads(body)
        valid = isinstance(answer, dict) and isinstance(answer.get("corrections"), list)
    except json.JSONDecodeError:
        valid = False
    if not valid:
        answer = {"hasError": False, "corrections": [], "uncertain": [], "overallConfidence": 0}
    return {
        "answer": answer, "valid_json": valid, "latency": round(latency, 2),
        "input_tokens": tokens_in, "output_tokens": tokens_out, "model": model,
    }


def _verify_chat(provider: str, image: Path, text: str, model: str, api_key: str | None,
                 timeout: float) -> dict:
    url, env = CHAT_PROVIDERS[provider]
    # "gemini-3.8-flash@low" asks for a reasoning effort; answers stay keyed by the full name.
    model, _, effort = model.partition("@")
    key = api_key or os.environ.get(env, "")
    if not key:
        raise RuntimeError(f"{env} is not set")
    picture = base64.b64encode(image.read_bytes()).decode("ascii")
    if provider == "qwen":
        # DashScope only guarantees json_object, so the schema goes in the prompt.
        instructions = INSTRUCTIONS + "\n\nAnswer with one JSON object matching this schema:\n" + json.dumps(SCHEMA)
        response_format = {"type": "json_object"}
    else:
        instructions = INSTRUCTIONS
        response_format = {"type": "json_schema",
                           "json_schema": {"name": "omr_check", "schema": SCHEMA, "strict": True}}
    body = {
        "model": model,
        "messages": [
            {"role": "system", "content": instructions},
            {"role": "user", "content": [
                {"type": "text", "text": text},
                {"type": "image_url", "image_url": {"url": f"data:image/png;base64,{picture}"}},
            ]},
        ],
        "response_format": response_format,
    }
    if provider == "qwen":
        # Thinking multiplies latency ~10x with no gain on this lookup task.
        body["enable_thinking"] = False
    if effort:
        body["reasoning_effort"] = effort
    request = urllib.request.Request(
        url, data=json.dumps(body).encode("utf-8"),
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
    )
    started = time.monotonic()
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", "replace")[:500]
        raise RuntimeError(f"{provider} {error.code}: {detail}") from error
    latency = time.monotonic() - started
    choices = payload.get("choices") or [{}]
    text_out = (choices[0].get("message") or {}).get("content") or ""
    usage = payload.get("usage") or {}
    return _result(text_out, latency, usage.get("prompt_tokens", 0), usage.get("completion_tokens", 0),
                   payload.get("model", model))


def complete_json(instructions: str, text: str, schema: dict, name: str, model: str,
                  api_key: str | None = None, timeout: float = 120.0) -> dict:
    """Ask `model` a text-only question answered as JSON matching `schema`.

    Returns {"answer": dict | None, "latency", "input_tokens", "output_tokens", "model"}.
    """
    provider = next((p for p in CHAT_PROVIDERS if model.startswith(p)), None)
    started = time.monotonic()
    if provider is None:
        key = api_key or os.environ.get("OPENAI_API_KEY", "")
        if not key:
            raise RuntimeError("OPENAI_API_KEY is not set")
        url, label = OPENAI_URL, "OpenAI"
        body = {
            "model": model,
            "instructions": instructions,
            "input": [{"role": "user", "content": [{"type": "input_text", "text": text}]}],
            "text": {"format": {"type": "json_schema", "name": name, "schema": schema, "strict": True}},
        }
    else:
        url, env = CHAT_PROVIDERS[provider]
        label = provider
        model, _, effort = model.partition("@")
        key = api_key or os.environ.get(env, "")
        if not key:
            raise RuntimeError(f"{env} is not set")
        if provider == "qwen":
            system = instructions + "\n\nAnswer with one JSON object matching this schema:\n" + json.dumps(schema)
            response_format = {"type": "json_object"}
        else:
            system = instructions
            response_format = {"type": "json_schema",
                               "json_schema": {"name": name, "schema": schema, "strict": True}}
        body = {
            "model": model,
            "messages": [{"role": "system", "content": system}, {"role": "user", "content": text}],
            "response_format": response_format,
        }
        if provider == "qwen":
            body["enable_thinking"] = False
        if effort:
            body["reasoning_effort"] = effort
    request = urllib.request.Request(
        url, data=json.dumps(body).encode("utf-8"),
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", "replace")[:500]
        raise RuntimeError(f"{label} {error.code}: {detail}") from error
    if provider is None:
        text_out = "".join(
            part.get("text", "")
            for item in payload.get("output", []) if item.get("type") == "message"
            for part in item.get("content", []) if part.get("type") == "output_text"
        )
        usage = payload.get("usage", {})
        tokens = usage.get("input_tokens", 0), usage.get("output_tokens", 0)
    else:
        choices = payload.get("choices") or [{}]
        text_out = (choices[0].get("message") or {}).get("content") or ""
        usage = payload.get("usage") or {}
        tokens = usage.get("prompt_tokens", 0), usage.get("completion_tokens", 0)
    body_text = text_out.strip()
    if body_text.startswith("```"):
        body_text = body_text.split("\n", 1)[-1].rsplit("```", 1)[0]
    try:
        answer = json.loads(body_text)
    except json.JSONDecodeError:
        answer = None
    return {
        "answer": answer if isinstance(answer, dict) else None,
        "latency": round(time.monotonic() - started, 2),
        "input_tokens": tokens[0], "output_tokens": tokens[1], "model": payload.get("model", model),
    }
