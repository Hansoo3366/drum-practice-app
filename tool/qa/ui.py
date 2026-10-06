"""Small adb driver: screenshots and label-based taps via uiautomator.

  ui.py shot NAME        screenshot -> $QA_OUT/shots/NAME.png (half size)
  ui.py dump [FILTER]    list labelled nodes (content-desc/text) with centers
  ui.py tap LABEL [N]    tap the Nth node whose label contains LABEL
  ui.py xy X Y           tap device coordinates
  ui.py back | text S | swipe X1 Y1 X2 Y2 [MS]
"""
import os
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET

ADB = os.environ.get("QA_ADB") or shutil.which("adb") or os.path.expandvars(
    r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
)
HERE = os.environ.get("QA_OUT", os.path.dirname(os.path.abspath(__file__)))
SHOTS = os.path.join(HERE, "shots")
os.makedirs(SHOTS, exist_ok=True)


def adb(*args, binary=False):
    out = subprocess.run([ADB, *args], capture_output=True, check=True, timeout=20)
    return out.stdout if binary else out.stdout.decode("utf-8", "replace")


def nodes():
    dumped = adb("shell", "uiautomator", "dump", "/sdcard/ui.xml")
    if "dumped to:" not in dumped:
        raise RuntimeError(f"UI dump failed; refusing to read a stale screen: {dumped.strip()}")
    raw = adb("exec-out", "cat", "/sdcard/ui.xml", binary=True)
    root = ET.fromstring(raw.decode("utf-8", "replace"))
    found = []
    for node in root.iter("node"):
        label = (node.get("content-desc") or node.get("text") or "").strip()
        if not label:
            continue
        m = re.match(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", node.get("bounds"))
        x1, y1, x2, y2 = map(int, m.groups())
        found.append((label, (x1 + x2) // 2, (y1 + y2) // 2, node.get("clickable") == "true",
                      node.get("selected") == "true" or node.get("checked") == "true"))
    return found


def matches(want):
    current = nodes()
    exact = [node for node in current if node[0] == want]
    if exact:
        return exact
    contains = [node for node in current if want in node[0]]
    return [node for node in contains if node[3]] or contains


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    cmd = sys.argv[1]
    if cmd == "shot":
        from PIL import Image
        import io
        display = os.environ.get("QA_DISPLAY")
        display_args = ["-d", display] if display else []
        png = adb("exec-out", "screencap", *display_args, "-p", binary=True)
        image = Image.open(io.BytesIO(png))
        image = image.resize((image.width // 2, image.height // 2))
        path = os.path.join(SHOTS, sys.argv[2] + ".png")
        image.save(path)
        print(path)
    elif cmd == "dump":
        flt = sys.argv[2] if len(sys.argv) > 2 else ""
        for label, x, y, click, sel in nodes():
            if flt in label:
                flags = ("C" if click else "-") + ("S" if sel else "-")
                print(f"{flags} ({x},{y}) {label!r}")
    elif cmd == "tap":
        want = sys.argv[2]
        nth = int(sys.argv[3]) if len(sys.argv) > 3 else 0
        hits = matches(want)
        if len(hits) <= nth:
            print("NOT FOUND:", want, "| have", len(hits))
            sys.exit(1)
        label, x, y, _, _ = hits[nth]
        adb("shell", "input", "tap", str(x), str(y))
        print(f"tapped {label!r} at ({x},{y})")
    elif cmd == "xy":
        adb("shell", "input", "tap", sys.argv[2], sys.argv[3])
    elif cmd == "back":
        adb("shell", "input", "keyevent", "4")
    elif cmd == "text":
        adb("shell", "input", "text", sys.argv[2])
    elif cmd == "swipe":
        adb("shell", "input", "swipe", *sys.argv[2:])


if __name__ == "__main__":
    main()
