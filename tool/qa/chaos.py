"""Uses the app the way nobody planned: a random walk over what is on screen.

  chaos.py SEED STEPS [PACKAGE]

Each step looks at the labelled things on screen and does something to one
of them, or something rude: taps twice at once, holds, swipes, types
nonsense, goes back, turns the screen, leaves and returns, or kills the app
and starts it again. Unlike `adb shell monkey`, most touches land on real
controls, so it gets deep into screens and dialogs; in the system file
picker it sometimes picks a file (see make_odd_files.py for odd ones).

After every step the device log is read. An exception, a layout overflow
or a crash is printed with the steps that led to it. The same SEED repeats
the same choices as far as the app answers the same way. Use a debug build:
it reports errors a release build swallows.
"""
import random
import re
import subprocess
import sys
import time

import ui

PACKAGE = sys.argv[3] if len(sys.argv) > 3 else "com.hansookim.pianoscore"
ERRORS = re.compile(
    r"EXCEPTION CAUGHT BY|Unhandled Exception|overflowed by|FATAL EXCEPTION|ANR in "
    + re.escape(PACKAGE)
    + r"|setState\(\) called after dispose|Null check operator|Another exception was thrown"
)
NONSENSE = ["0", "-1", "99999999999", " ", "a" * 150, "C#m7b5/G#", "'; DROP TABLE songs;--",
            "%s%n%d", "../../etc/passwd", "Verse", "1e9", "\\n\\t", "<b>x</b>", "🙂"]


def adb(*args):
    return ui.adb(*args)


def focused_package():
    out = adb("shell", "dumpsys", "window", "displays")
    match = re.search(r"mCurrentFocus=Window\{[^ ]+ [^ ]+ ([^/ }]+)", out)
    return match.group(1) if match else ""


def launch():
    adb("shell", "monkey", "-p", PACKAGE, "-c", "android.intent.category.LAUNCHER", "1")
    time.sleep(6)


def log_lines():
    out = subprocess.run([ui.ADB, "logcat", "-d", "-v", "brief"], capture_output=True).stdout
    return out.decode("utf-8", "replace").splitlines()


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    seed, steps = int(sys.argv[1]), int(sys.argv[2])
    rng = random.Random(seed)
    adb("logcat", "-c")
    width, height = 1344, 2992
    size = re.search(r"(\d+)x(\d+)", adb("shell", "wm", "size"))
    if size:
        width, height = int(size.group(1)), int(size.group(2))
    trail = []
    found = []
    for step in range(steps):
        package = focused_package()
        if PACKAGE not in package and "documentsui" not in package:
            adb("shell", "input", "keyevent", "4")
            time.sleep(0.5)
            if PACKAGE not in focused_package():
                launch()
            trail.append("(back to app)")
            continue
        try:
            nodes = ui.nodes()
        except Exception:  # the dump failed while the screen was changing
            nodes = []
        roll = rng.random()
        if "documentsui" in package:
            # The system file picker: usually leave, sometimes pick something.
            files = [node for node in nodes if "." in node[0] and len(node[0]) < 60]
            if files and roll < 0.45:
                label, x, y, *_ = rng.choice(files)
                adb("shell", "input", "tap", str(x), str(y - 250))
                did = f"pick file {label!r}"
            elif roll < 0.6 and any(node[0] == "SAVE" for node in nodes):
                x, y = next((n[1], n[2]) for n in nodes if n[0] == "SAVE")
                adb("shell", "input", "tap", str(x), str(y))
                did = "save in picker"
            else:
                adb("shell", "input", "keyevent", "4")
                did = "back from picker"
        elif roll < 0.60 and nodes:
            label, x, y, *_ = rng.choice(nodes)
            adb("shell", "input", "tap", str(x), str(y))
            did = f"tap {label[:40]!r}"
        elif roll < 0.66 and nodes:
            label, x, y, *_ = rng.choice(nodes)
            subprocess.Popen([ui.ADB, "shell", "input", "tap", str(x), str(y)])
            adb("shell", "input", "tap", str(x), str(y))
            did = f"double tap {label[:40]!r}"
        elif roll < 0.71 and nodes:
            label, x, y, *_ = rng.choice(nodes)
            adb("shell", "input", "swipe", str(x), str(y), str(x), str(y), "900")
            did = f"hold {label[:40]!r}"
        elif roll < 0.78:
            adb("shell", "input", "keyevent", "4")
            did = "back"
        elif roll < 0.84:
            x, y = rng.randrange(width), rng.randrange(200, height - 100)
            adb("shell", "input", "tap", str(x), str(y))
            did = f"tap anywhere ({x},{y})"
        elif roll < 0.90:
            a, b = rng.randrange(width), rng.randrange(300, height - 200)
            c, d = rng.randrange(width), rng.randrange(300, height - 200)
            adb("shell", "input", "swipe", str(a), str(b), str(c), str(d), str(rng.choice([60, 300])))
            did = f"swipe ({a},{b})->({c},{d})"
        elif roll < 0.94:
            text = rng.choice(NONSENSE)
            adb("shell", "input", "text", text.replace(" ", "%s").replace("'", "\\'").replace(";", "\\;")
                .replace("<", "\\<").replace(">", "\\>").replace("&", "\\&").replace("(", "\\(")
                .replace(")", "\\)").replace("|", "\\|"))
            if rng.random() < 0.5:
                adb("shell", "input", "keyevent", "66")
            did = f"type {text[:20]!r}"
        elif roll < 0.97:
            turn = rng.choice(["0", "1"])
            adb("shell", "settings", "put", "system", "accelerometer_rotation", "0")
            adb("shell", "settings", "put", "system", "user_rotation", turn)
            did = f"rotate {turn}"
        elif roll < 0.99:
            adb("shell", "input", "keyevent", "3")
            time.sleep(1)
            launch()
            did = "home and back"
        else:
            adb("shell", "am", "force-stop", PACKAGE)
            launch()
            did = "kill and restart"
        trail.append(did)
        time.sleep(0.5)
        # Read and empty the log each step: its buffer is a ring.
        fresh = log_lines()
        adb("logcat", "-c")
        for index, line in enumerate(fresh):
            if ERRORS.search(line):
                context = " | ".join(text.split("): ", 1)[-1][:150] for text in fresh[index:index + 4])
                found.append((step, context, trail[-10:]))
                print(f"\n!! step {step}: {context}\n   after: {' > '.join(trail[-10:])}", flush=True)
                break
        if step % 25 == 24:
            print(f"   step {step + 1}: {did}", flush=True)
    adb("shell", "settings", "put", "system", "user_rotation", "0")
    print(f"\nseed {seed}: {steps} steps, {len(found)} error(s)")


if __name__ == "__main__":
    main()
