"""Press stop then play, grab frames as fast as adb allows, and report where
the playback highlight (peach box) is in each frame.

  play_trace.py STOP_X STOP_Y PLAY_X PLAY_Y SECONDS [Y0 Y1]
"""
import io
import os
import subprocess
import sys
import time

import numpy as np
from PIL import Image

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")


def adb(*args):
    return subprocess.run([ADB, *args], capture_output=True).stdout


sx, sy, px, py, seconds = sys.argv[1:6]
y0, y1 = (int(sys.argv[6]), int(sys.argv[7])) if len(sys.argv) > 7 else (300, 2200)
adb("shell", "input", "tap", sx, sy)
time.sleep(1)
adb("shell", "input", "tap", px, py)
start = time.time()
last = None
while time.time() - start < float(seconds):
    at = time.time() - start
    image = Image.open(io.BytesIO(adb("exec-out", "screencap", "-p"))).convert("RGB")
    a = np.asarray(image).astype(int)[y0:y1]
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mask = (r > 245) & (g > 205) & (g < 240) & (b > 180) & (b < 228) & (r - b > 25)
    if mask.sum() < 500:
        box = "none"
    else:
        ys, xs = np.where(mask)
        box = f"x {xs.min()}-{xs.max()} y {ys.min() + y0}-{ys.max() + y0}"
    if box != last:
        print(f"{at:6.2f}s  {box}", flush=True)
        last = box
print(f"{time.time() - start:6.2f}s  end of capture")
