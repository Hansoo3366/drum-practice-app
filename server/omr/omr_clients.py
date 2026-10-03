"""Who may use the worker, and how much.

An install of the app registers once, with the app key every build carries,
and gets a secret of its own; its requests then carry that secret. Conversions
and AI calls are counted per install, per network address and in total, per
day, so a key or a secret taken out of an APK can only spend so much.
"""

from __future__ import annotations

import hashlib
import json
import os
import secrets
import threading
import time
from pathlib import Path


def _write(path: Path, data: dict) -> None:
    """Replace [path] in one step. A worker that cannot write keeps what it has in memory."""
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        draft = path.with_suffix(path.suffix + ".tmp")
        draft.write_text(json.dumps(data), encoding="utf-8")
        os.replace(draft, path)
    except OSError:
        pass


def _read(path: Path) -> dict:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    return data if isinstance(data, dict) else {}


class Clients:
    """The installs that registered. Only a hash of each secret is kept."""

    def __init__(self, path: Path):
        self._path = path
        self._lock = threading.Lock()
        self._by_hash: dict[str, dict] = {
            key: value for key, value in (_read(path).get("clients") or {}).items()
            if isinstance(value, dict) and value.get("id")
        }

    @staticmethod
    def _hash(secret: str) -> str:
        return hashlib.sha256(secret.encode("utf-8")).hexdigest()

    def register(self, address: str, now: float | None = None) -> tuple[str, str]:
        """A new install: its id, and the secret it must keep (not stored here)."""
        client, secret = secrets.token_hex(8), secrets.token_urlsafe(32)
        with self._lock:
            self._by_hash[self._hash(secret)] = {
                "id": client, "created": int(now if now is not None else time.time()), "address": address,
            }
            _write(self._path, {"clients": self._by_hash})
        return client, secret

    def find(self, secret: str) -> str | None:
        """The id of the install [secret] belongs to."""
        if not secret:
            return None
        with self._lock:
            entry = self._by_hash.get(self._hash(secret))
        return entry["id"] if entry else None


class Quota:
    """Daily counters. A day is a UTC date; yesterday's counts are dropped."""

    def __init__(self, path: Path):
        self._path = path
        self._lock = threading.Lock()
        saved = _read(path)
        self._day = saved.get("day") or ""
        self._counts: dict[str, int] = {
            key: value for key, value in (saved.get("counts") or {}).items() if isinstance(value, int)
        }

    def spend(self, kind: str, limits: dict[str, int], now: float | None = None) -> str | None:
        """Count one [kind] against every counter in [limits] (name -> most per day).

        Returns None when it was counted, or the name of the first counter that is used up;
        then nothing is counted. A name reads "client:<id>", "address:<ip>" or "all".
        """
        day = time.strftime("%Y-%m-%d", time.gmtime(now if now is not None else time.time()))
        with self._lock:
            if day != self._day:
                self._day, self._counts = day, {}
            for name, most in limits.items():
                if self._counts.get(f"{kind}|{name}", 0) >= most:
                    return name
            for name in limits:
                key = f"{kind}|{name}"
                self._counts[key] = self._counts.get(key, 0) + 1
            _write(self._path, {"day": self._day, "counts": self._counts})
        return None
