"""Compares note readers on what any of them can read: the bars and how many notes
start in each. Chords and lyrics are left out of the answer key, so a reader that
knows nothing of them (a second engine tried beside the server's) is scored on the
same footing as the server's own result.

  python3 tool/accuracy/score_notes.py NAME=SPEC [NAME=SPEC ...]

SPEC is one of
  mxl:<run>/<version>     out<run>/<song>/<version>.mxl of a server conversion (raw, fixed, ai)
  lines:<dir>             <dir>/<song>/<line>.musicxml, one file per line picture of the answer key
                          (lines/<song>/pP-sNN.png), as a reader run on each picture writes them
  pages:<dir>             <dir>/<song>/p<N>.musicxml, one file per page photo, lines marked in the file
                          (as a reader run on the whole page writes them)

With two or more readers it also says, bar by bar, how often they agree and how often
an agreement is right: what a second reader would be worth as a check on the first."""
import json, os, sys
from extract import load, systems
from score import DATA, align_bars, align_systems

def plain(bar):
    signs = sorted(s for s in bar.get('signs') or [] if s.startswith(('repeat', 'ending')))
    return {'chords': [], 'lyrics': [], 'onsets': bar.get('onsets'), 'signs': signs}

def read(spec, song, truth):
    kind, _, where = spec.partition(':')
    if kind == 'mxl':
        run, _, version = where.partition('/')
        path = f'{DATA}/out{run}/{song}/{version}.mxl'
        if not os.path.exists(path): return None
        lines = systems(load(path))
        if truth.get('partial'): lines = lines[:len(truth['systems'])]
        return [[plain(b) for b in line] for line in lines]
    if kind == 'lines':
        out, found = [], False
        for system in truth['systems']:
            path = os.path.join(where, song, system['file'].rsplit('.', 1)[0] + '.musicxml')
            if not os.path.exists(path): out.append([]); continue
            found = True
            try: out.append([plain(b) for line in systems(load(path)) for b in line])
            except Exception: out.append([])
        return out if found else None
    if kind == 'pages':
        out, page = [], 1
        while os.path.exists(path := os.path.join(where, song, f'p{page}.musicxml')):
            try: out += [[plain(b) for b in line] for line in systems(load(path))]
            except Exception: pass
            page += 1
        if page == 1: return None
        return out[:len(truth['systems'])] if truth.get('partial') else out
    raise SystemExit(f'unknown reader: {spec}')

def outcomes(truth_systems, got):
    """For every bar of the answer key: 'ok' (found, note count right), 'count', 'merged',
    'missing'; and how many bars the reader has that the original does not."""
    out, extra, signs = [], 0, [0, 0]
    pairs = align_systems(truth_systems, got) if len(got) != len(truth_systems) else [(i, i) for i in range(len(got))]
    for ti, gi in pairs:
        if ti is None: extra += len(got[gi]); continue
        tb = truth_systems[ti]
        if gi is None: out += ['missing'] * len(tb); continue
        marks = {}
        for indexes, g_index in align_bars(tb, got[gi])[1]:
            if not indexes: extra += 1; continue
            if g_index is None: marks[indexes[0]] = 'missing'; continue
            if len(indexes) == 2:
                for i in indexes: marks[i] = 'merged'
                continue
            t, g = tb[indexes[0]], got[gi][g_index]
            marks[indexes[0]] = 'ok' if t['onsets'] == g['onsets'] else 'count'
            if t['signs'] or g['signs']:
                signs[0] += 1; signs[1] += t['signs'] == g['signs']
        out += [marks.get(i, 'missing') for i in range(len(tb))]
    return out, extra, signs

if __name__ == '__main__':
    readers = dict(arg.split('=', 1) for arg in sys.argv[1:])
    if not readers: raise SystemExit(__doc__)
    per = {name: [] for name in readers}
    extras = {name: 0 for name in readers}
    signs = {name: [0, 0] for name in readers}
    songs = []
    for file in sorted(os.listdir(f'{DATA}/truth')):
        song = file[:-5]
        truth = json.load(open(f'{DATA}/truth/{file}'))
        t = [[plain(b) for b in s['bars']] for s in truth['systems']]
        row = {}
        for name, spec in readers.items():
            got = read(spec, song, truth)
            if got is None: row = None; break
            row[name] = outcomes(t, got)
        if row is None: continue
        songs.append((song, sum(map(len, t)), {n: sum(o == 'ok' for o in row[n][0]) for n in readers}))
        for name in readers:
            per[name] += row[name][0]; extras[name] += row[name][1]
            signs[name][0] += row[name][2][0]; signs[name][1] += row[name][2][1]
    total = len(next(iter(per.values())))
    print(f'{len(songs)} songs, {total} bars of the answer key\n')
    print(f"{'reader':10} {'right':>12} {'count off':>10} {'merged':>7} {'missing':>8} {'extra':>6} {'repeats/endings':>16}")
    for name, marks in per.items():
        c = {k: marks.count(k) for k in ('ok', 'count', 'merged', 'missing')}
        s = signs[name]
        print(f"{name:10} {c['ok']:>5} {100 * c['ok'] / total:5.1f}% {c['count']:>10} {c['merged']:>7} {c['missing']:>8} {extras[name]:>6} "
              f"{(f'{s[1]}/{s[0]}' if s[0] else '-'):>16}")
    print('\nby song (bars right):')
    for song, bars, right in songs:
        print(f"  {song:18} {bars:>4}  " + '  '.join(f"{n} {right[n]:>3} ({100 * right[n] / bars:3.0f}%)" for n in readers))
    names = list(readers)
    for i in range(len(names)):
        for j in range(i + 1, len(names)):
            a, b = per[names[i]], per[names[j]]
            both = sum(x == 'ok' and y == 'ok' for x, y in zip(a, b))
            only_a = sum(x == 'ok' and y != 'ok' for x, y in zip(a, b))
            only_b = sum(x != 'ok' and y == 'ok' for x, y in zip(a, b))
            neither = total - both - only_a - only_b
            print(f"\n{names[i]} and {names[j]}: both right {both}, only {names[i]} {only_a}, only {names[j]} {only_b}, neither {neither}")
            print(f"  a bar at least one of them reads right: {both + only_a + only_b} of {total} ({100 * (both + only_a + only_b) / total:.1f}%)")
