"""Cuts each page of each song into its systems (one staff with its chords above and
lyrics below) by finding the five staff lines, for reading the original by eye."""
import json, os, sys
import numpy as np
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
# Pictures, answer keys and results live outside git (they hold whole lyrics).
DATA = os.environ.get('ACCURACY_DATA', os.path.join(ROOT, 'score_sample', '_accuracy'))
SRC = os.path.join(ROOT, 'score_sample')
HERE = os.path.dirname(os.path.abspath(__file__))

def staves(gray):
    h, w = gray.shape
    paper = np.median(gray)
    dark = gray < paper - 45
    # A staff line is dark across most of the width of the music; staves do not always
    # span the page, so take the best of several windows.
    score = np.zeros(h)
    for x0, x1 in ((0.12, 0.92), (0.12, 0.55), (0.45, 0.92), (0.25, 0.75)):
        score = np.maximum(score, dark[:, int(w * x0):int(w * x1)].mean(axis=1))
    lines = [y for y in range(h) if score[y] > 0.5]
    groups = []
    for y in lines:
        if groups and y - groups[-1][-1] <= 2: groups[-1].append(y)
        else: groups.append([y])
    centres = [int(np.mean(g)) for g in groups]
    out, i = [], 0
    while i + 4 < len(centres):
        five = centres[i:i + 5]
        gaps = np.diff(five)
        if gaps.max() <= gaps.min() * 1.5 + 2 and gaps.max() < h * 0.02 and gaps.min() >= 4:
            out.append((five[0], five[-1])); i += 5
        else:
            i += 1
    return out

index = {}
for song, pages in sorted(json.load(open(f'{HERE}/songs.json')).items()):
    os.makedirs(f'{DATA}/lines/{song}', exist_ok=True)
    index[song] = []
    for p, name in enumerate(pages, 1):
        im = Image.open(f'{SRC}/{name}').convert('RGB')
        gray = np.asarray(im.convert('L'))
        found = staves(gray)
        h = gray.shape[0]
        for s, (top, bottom) in enumerate(found, 1):
            space = bottom - top
            above = found[s - 2][1] if s > 1 else None
            below = found[s][0] if s < len(found) else None
            # Chords sit above the staff, lyrics below: give lyrics the larger share.
            y0 = max(0, top - int(space * 2.6)) if above is None else max(above + int((top - above) * 0.55), top - int(space * 3))
            y1 = min(h, bottom + int(space * 3.2)) if below is None else min(bottom + int((below - bottom) * 0.72), bottom + int(space * 4.5))
            crop = im.crop((0, y0, im.size[0], y1))
            if crop.size[0] < 1900:
                scale = 1900 / crop.size[0]
                crop = crop.resize((1900, int(crop.size[1] * scale)), Image.LANCZOS)
            elif crop.size[0] > 2400:
                scale = 2400 / crop.size[0]
                crop = crop.resize((2400, int(crop.size[1] * scale)), Image.LANCZOS)
            path = f'{DATA}/lines/{song}/p{p}-s{s:02d}.png'
            crop.save(path)
            index[song].append(os.path.basename(path))
        print(song, f'page {p}', len(found), 'systems')
json.dump(index, open(f'{DATA}/lines/index.json', 'w'), indent=1)
print(sum(len(v) for v in index.values()), 'systems')
