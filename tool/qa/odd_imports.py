"""Imports every odd file (make_odd_files.py) and says what the app answered.

  odd_imports.py

For each file in the device's Download folder whose name starts with
"odd_": opens the matching import (MusicXML, PDF, or conversion for the
PDFs as well), picks the file through the system picker's search, confirms,
and prints the messages that appeared and any error in the device log.
A score that was imported is then opened, played for a moment and closed.
"""
import re
import subprocess
import sys
import time

import ui

PACKAGE = "com.hansookim.worshipeasypeasy"
ERRORS = re.compile(r"EXCEPTION CAUGHT BY|Unhandled Exception|overflowed by|FATAL EXCEPTION|Another exception")


def adb(*args):
    return ui.adb(*args)


def labels():
    try:
        return [node[0] for node in ui.nodes()]
    except Exception:
        return []


def tap(label, nth=0, exact=False):
    hits = [n for n in ui.nodes() if (n[0] == label if exact else label in n[0])]
    if len(hits) <= nth:
        return False
    adb("shell", "input", "tap", str(hits[nth][1]), str(hits[nth][2]))
    return True


def errors():
    out = subprocess.run([ui.ADB, "logcat", "-d", "-v", "brief"], capture_output=True).stdout
    lines = out.decode("utf-8", "replace").splitlines()
    adb("logcat", "-c")
    found = []
    for index, line in enumerate(lines):
        if ERRORS.search(line):
            found.append(" | ".join(t.split("): ", 1)[-1][:140] for t in lines[index:index + 5]))
    return found


def home():
    for _ in range(6):
        now = labels()
        if "라이브러리" in now and "가져오기" in now:
            return
        adb("shell", "input", "keyevent", "4")
        time.sleep(1)
    adb("shell", "am", "force-stop", PACKAGE)
    adb("shell", "monkey", "-p", PACKAGE, "-c", "android.intent.category.LAUNCHER", "1")
    time.sleep(8)


def pick(name):
    """In the system picker: search for [name] and tap it."""
    time.sleep(2.5)
    if not tap("Search", exact=True):
        return False
    time.sleep(1)
    adb("shell", "input", "text", name)
    time.sleep(2.5)
    hits = [n for n in ui.nodes() if n[0] == name]
    if not hits:
        return False
    # The last match is the result row (the first is the search field).
    adb("shell", "input", "tap", str(hits[-1][1]), str(hits[-1][2] - 150))
    time.sleep(3)
    return True


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    names = sorted(n for n in adb("shell", "ls", "/sdcard/Download").split() if n.startswith("odd_"))
    adb("logcat", "-c")
    for name in names:
        ways = ["PDF 가져오기", "전자악보로 변환"] if name.endswith(".pdf") else ["MusicXML 가져오기"]
        for way in ways:
            home()
            before = set(labels())
            tap("가져오기", exact=True)
            time.sleep(1.2)
            tap(way)
            time.sleep(2)
            tap("내 기기")  # the conversion picker has no source sheet
            picked = pick(name)
            shown = [text for text in labels() if text not in before]
            said = []
            if picked:
                # A sheet asking for a title, or the kind of score: confirm it.
                if tap("코드·가사 악보"):
                    time.sleep(6)
                elif tap("가져오기", nth=1):
                    time.sleep(4)
                said = [text for text in labels() if text not in before and text not in shown]
            title = name.rsplit(".", 1)[0]
            listed = [text for text in labels() if title in text or "odd" in text.lower()]
            print(f"{name} via {way}: picked={picked}")
            for text in (shown + said)[:6]:
                print(f"    saw {text[:110]!r}")
            for text in listed[:2]:
                print(f"    library {text[:110]!r}")
            # Open what came in, play a moment, come back.
            opened = [n for n in ui.nodes() if n[0].startswith("XML\n") and "방금" not in n[0][:3]][:1]
            if said or listed:
                if tap(listed[0][:30] if listed else "XML\n"):
                    time.sleep(7)
                    inside = labels()
                    print(f"    opened: {[t[:40] for t in inside[:6]]}")
                    if tap("재생", exact=True):
                        time.sleep(2)
                        tap("재생", nth=1, exact=True)
                        time.sleep(3)
            for error in errors():
                print(f"    !! {error[:400]}")
    home()


if __name__ == "__main__":
    main()
