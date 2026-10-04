"""Runs a list of UI steps and prints what changed on screen after each.

  steps.py STEP [STEP ...]

A step is a label to tap ("한 칸 위"), `LABEL#N` for the Nth match,
`xy:X,Y`, `back`, `text:WORDS`, `wait:SECONDS` or `shot:NAME`. After every
step the labels that appeared or disappeared since the step before are
printed (messages, counters, dialogs), so a run reads as a trace.
"""
import subprocess
import sys
import time

import ui

sys.stdout.reconfigure(encoding="utf-8")


def labels():
    return [label for label, *_ in ui.nodes()]


def main():
    before = set(labels())
    for step in sys.argv[1:]:
        if step.startswith("wait:"):
            time.sleep(float(step[5:]))
            continue
        if step.startswith("shot:"):
            subprocess.run([sys.executable, ui.__file__, "shot", step[5:]], capture_output=True)
            continue
        if step == "back":
            ui.adb("shell", "input", "keyevent", "4")
        elif step.startswith("xy:"):
            x, y = step[3:].split(",")
            ui.adb("shell", "input", "tap", x, y)
        elif step.startswith("text:"):
            ui.adb("shell", "input", "text", step[5:])
        else:
            want, _, nth = step.partition("#")
            hits = [node for node in ui.nodes() if want in node[0]]
            if len(hits) <= int(nth or 0):
                print(f"[{step}] NOT FOUND")
                continue
            _, x, y, _, _ = hits[int(nth or 0)]
            ui.adb("shell", "input", "tap", str(x), str(y))
        time.sleep(1.6)
        after = set(labels())
        shown = sorted(after - before)
        gone = sorted(before - after)
        print(f"[{step}]"
              + "".join(f"\n   + {text!r}"[:170] for text in shown[:8])
              + "".join(f"\n   - {text!r}"[:120] for text in gone[:4]))
        before = after


if __name__ == "__main__":
    main()
