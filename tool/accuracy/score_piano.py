"""Scores note readers on piano scores whose exact score is known (a MusicXML the page was
engraved from): which notes they read, at the right place in the bar, at the right pitch, of
the right length.

  ACCURACY_DATA=score_sample/_accuracy/piano python3 tool/accuracy/score_piano.py NAME=SPEC ...

The answer key is truth/<song>.musicxml. SPEC is one of
  mxl:<run>/<version>   out<run>/<song>/<version>.mxl, a server conversion
  pages:<dir>           <dir>/<song>/p-<N>.musicxml (or p<N>.musicxml), one file per page in order

A note is a pitch that begins at a place in a bar (staves and voices are not told apart: a
note read on the wrong staff is still the right note). Bars are matched in order, so a bar
that is missing or read twice does not put every later bar out of step. Grace notes and
rests are left out."""
import glob, io, json, os, re, sys, zipfile
import xml.etree.ElementTree as ET
from collections import Counter
from fractions import Fraction

DATA = os.environ.get('ACCURACY_DATA', os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), 'score_sample', '_accuracy', 'piano'))
STEP = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}

def load(path):
    data = open(path, 'rb').read()
    if data[:2] == b'PK':
        z = zipfile.ZipFile(io.BytesIO(data))
        data = z.read(next(n for n in z.namelist() if not n.startswith('META-INF') and n.endswith(('.xml', '.musicxml'))))
    return ET.fromstring(data)

def bars(root):
    """Per bar: a list of (onset in quarters, midi, length in quarters), every part and staff."""
    parts = root.findall('part')
    count = max((len(p.findall('measure')) for p in parts), default=0)
    out = [[] for _ in range(count)]
    for part in parts:
        divisions = 1
        for index, measure in enumerate(part.findall('measure')):
            cursor = last = Fraction(0)
            for child in measure:
                if child.tag == 'attributes':
                    d = child.findtext('divisions')
                    if d and int(d) > 0: divisions = int(d)
                elif child.tag in ('backup', 'forward'):
                    length = Fraction(int(child.findtext('duration') or 0), divisions)
                    cursor += length if child.tag == 'forward' else -length
                elif child.tag == 'note':
                    if child.find('grace') is not None: continue
                    length = Fraction(int(child.findtext('duration') or 0), divisions)
                    chord = child.find('chord') is not None
                    onset = last if chord else cursor
                    pitch = child.find('pitch')
                    if pitch is not None:
                        midi = 12 * (int(pitch.findtext('octave') or 4) + 1) + STEP.get(pitch.findtext('step') or 'C', 0) + round(float(pitch.findtext('alter') or 0))
                        out[index].append((onset, midi, length))
                    if not chord:
                        last = cursor; cursor += length
    return out

def read(spec, song):
    kind, _, where = spec.partition(':')
    if kind == 'mxl':
        run, _, version = where.partition('/')
        path = f'{DATA}/out{run}/{song}/{version}.mxl'
        return bars(load(path)) if os.path.exists(path) else None
    if kind == 'pages':
        files = glob.glob(os.path.join(where, song, 'p*.musicxml'))
        if not files: return None
        files.sort(key=lambda f: int(re.findall(r'(\d+)', os.path.basename(f))[-1]))
        out = []
        for f in files:
            try: out += bars(load(f))
            except Exception: pass
        return out
    raise SystemExit(f'unknown reader: {spec}')

def overlap(a, b): return sum((Counter(a) & Counter(b)).values())

def f1(t, g):
    if not t and not g: return 1.0
    m = overlap(t, g)
    return 2 * m / (len(t) + len(g)) if t or g else 1.0

def align(truth, got):
    """Pairs (truth index or None, got index or None), bars in order, most notes matched."""
    place = lambda bar: [(o, p) for o, p, _l in bar]
    n, m = len(truth), len(got)
    tp, gp = [place(b) for b in truth], [place(b) for b in got]
    cost = [[0.0] * (m + 1) for _ in range(n + 1)]
    for i in range(1, n + 1): cost[i][0] = i * 0.6
    for j in range(1, m + 1): cost[0][j] = j * 0.6
    for i in range(1, n + 1):
        for j in range(1, m + 1):
            cost[i][j] = min(cost[i - 1][j - 1] + 1 - f1(tp[i - 1], gp[j - 1]), cost[i - 1][j] + 0.6, cost[i][j - 1] + 0.6)
    out, i, j = [], n, m
    while i or j:
        if i and j and abs(cost[i][j] - (cost[i - 1][j - 1] + 1 - f1(tp[i - 1], gp[j - 1]))) < 1e-9: out.append((i - 1, j - 1)); i -= 1; j -= 1
        elif i and abs(cost[i][j] - (cost[i - 1][j] + 0.6)) < 1e-9: out.append((i - 1, None)); i -= 1
        else: out.append((None, j - 1)); j -= 1
    return out[::-1]

def score(truth, got):
    r = Counter(bars=len(truth), got_bars=len(got))
    for ti, gi in align(truth, got):
        if ti is None: r['extra_bars'] += 1; r['got_notes'] += len(got[gi]); continue
        t = truth[ti]; r['notes'] += len(t)
        if gi is None: r['missing_bars'] += 1; continue
        g = got[gi]; r['got_notes'] += len(g)
        r['pitch_anywhere'] += overlap([p for _o, p, _l in t], [p for _o, p, _l in g])
        r['placed'] += overlap([(o, p) for o, p, _l in t], [(o, p) for o, p, _l in g])
        r['whole'] += overlap(t, g)
        r['bars_placed'] += Counter((o, p) for o, p, _l in t) == Counter((o, p) for o, p, _l in g)
        r['bars_whole'] += Counter(t) == Counter(g)
    return r

if __name__ == '__main__':
    readers = dict(arg.split('=', 1) for arg in sys.argv[1:])
    if not readers: raise SystemExit(__doc__)
    total = {name: Counter() for name in readers}
    rows = []
    for file in sorted(os.listdir(f'{DATA}/truth')):
        song = file.rsplit('.', 1)[0]
        truth = bars(load(f'{DATA}/truth/{file}'))
        row = {}
        for name, spec in readers.items():
            got = read(spec, song)
            if got is not None: row[name] = score(truth, got); total[name] += row[name]
        rows.append((song, row))
    def line(name, r):
        pct = lambda a, b: f'{100 * a / b:5.1f}%' if b else '   — '
        return (f"{name:12} bars {r['got_bars']:>4}/{r['bars']:<4} missing {r['missing_bars']:>3} extra {r['extra_bars']:>3} | "
                f"notes read {r['got_notes']:>5}/{r['notes']:<5} | right pitch in the bar {pct(r['pitch_anywhere'], r['notes'])} "
                f"at the right place {pct(r['placed'], r['notes'])} and length {pct(r['whole'], r['notes'])} "
                f"(of what it read {pct(r['placed'], r['got_notes'])}) | bars all right: place {pct(r['bars_placed'], r['bars'])} place+length {pct(r['bars_whole'], r['bars'])}")
    for song, row in rows:
        print(song)
        for name, r in row.items(): print('  ' + line(name, r))
    print('TOTAL')
    for name, r in total.items():
        if r: print('  ' + line(name, r))
