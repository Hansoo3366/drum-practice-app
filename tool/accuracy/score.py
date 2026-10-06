"""Scores each converted version of each song against the by-eye answer key.

Lines are matched first, then the bars inside each line, so a dropped line or two bars
run together do not push every later bar out of step."""
import itertools, json, os, re, sys
from extract import load, systems
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
# Pictures, answer keys and results live outside git (they hold whole lyrics).
DATA = os.environ.get('ACCURACY_DATA', os.path.join(ROOT, 'score_sample', '_accuracy'))
VERSIONS = ('raw', 'fixed', 'ai')
RUN = os.environ.get('RUN', '')
BAR_GAP, EMPTY = 7, {'chords': [], 'lyrics': [], 'onsets': None, 'signs': []}

def chord(text):
    t = text.strip().replace(' ', '').replace('♯', '#').replace('♭', 'b')
    if t.startswith('(') and t.endswith(')'): t = t[1:-1]
    t = t.replace('(', '').replace(')', '')
    t = re.sub(r'(?<=[A-G#b])M(?=7|9|11|13)', 'maj', t).replace('Maj', 'maj').replace('△', 'maj')
    t = t.replace('°', 'dim').replace('ø', 'm7b5')
    t = re.sub(r'(?<=[A-G#b])o(?=7|$)', 'dim', t)
    t = re.sub(r'sus(?!\d)', 'sus4', t)
    head, slash, bass = t.partition('/')
    if slash: t = head + '/' + bass[:1].upper() + bass[1:]
    return t

def syllables(items):
    text = re.sub(r'\d+\.', '', ''.join(items))
    return [c for c in text if c.isalnum()]

def distance(a, b):
    row = list(range(len(b) + 1))
    for i, x in enumerate(a, 1):
        prev, row[0] = row[0], i
        for j, y in enumerate(b, 1):
            prev, row[j] = row[j], min(row[j] + 1, row[j - 1] + 1, prev + (x != y))
    return row[-1]

def view(bar):
    return {
        'chords': [chord(c) for c in bar.get('chords') or []],
        'lyrics': [syllables(v) for v in bar.get('lyrics') or [] if syllables(v)],
        'onsets': bar.get('onsets'),
        'signs': sorted(s for s in bar.get('signs') or [] if s not in ('double-bar', 'final-bar')),
    }

def joined(a, b):
    """Two bars read as one (a barline was missed)."""
    lines = max(len(a['lyrics']), len(b['lyrics']))
    return {'chords': a['chords'] + b['chords'],
            'lyrics': [(a['lyrics'][i] if i < len(a['lyrics']) else []) + (b['lyrics'][i] if i < len(b['lyrics']) else []) for i in range(lines)],
            'onsets': (a['onsets'] or 0) + (b['onsets'] or 0), 'signs': sorted(set(a['signs']) | set(b['signs']))}

def lyric_pairs(t, g):
    """Each answer-key lyric line with the converted line that fits it best (a verse may
    have been given another verse number), then converted lines left over."""
    if len(t) <= 4 and len(g) <= 4 and t and g:
        best, best_cost = None, None
        size = max(len(t), len(g))
        tt, gg = t + [[]] * (size - len(t)), g + [[]] * (size - len(g))
        for order in itertools.permutations(range(size)):
            c = sum(distance(tt[i], gg[j]) for i, j in enumerate(order))
            if best_cost is None or c < best_cost: best, best_cost = order, c
        return [(tt[i], gg[j]) for i, j in enumerate(best)], best != tuple(range(size)) and best_cost < sum(distance(a, b) for a, b in zip(tt, gg))
    size = max(len(t), len(g))
    return [((t[i] if i < len(t) else []), (g[i] if i < len(g) else [])) for i in range(size)], False

def cost(t, g):
    c = distance(t['chords'], g['chords']) + sum(distance(a, b) for a, b in lyric_pairs(t['lyrics'], g['lyrics'])[0])
    return c + (0 if t['onsets'] == g['onsets'] else 1)

def align_bars(truth, got):
    """(truth indexes, got index or None): one-to-one, two answer-key bars read as one,
    a missed bar, or (None, got index) for a bar that is not in the original."""
    n, m, inf = len(truth), len(got), 10 ** 9
    table = [[inf] * (m + 1) for _ in range(n + 1)]
    back = [[None] * (m + 1) for _ in range(n + 1)]
    table[0][0] = 0
    for i in range(n + 1):
        for j in range(m + 1):
            here = table[i][j]
            if here >= inf: continue
            def offer(ni, nj, c, move):
                if here + c < table[ni][nj]: table[ni][nj], back[ni][nj] = here + c, (i, j, move)
            if i < n and j < m: offer(i + 1, j + 1, cost(truth[i], got[j]), 'pair')
            if i + 1 < n and j < m: offer(i + 2, j + 1, cost(joined(truth[i], truth[i + 1]), got[j]) + 2, 'merge')
            if i < n: offer(i + 1, j, BAR_GAP + len(truth[i]['chords']) + sum(map(len, truth[i]['lyrics'])), 'missing')
            if j < m: offer(i, j + 1, BAR_GAP + len(got[j]['chords']) + sum(map(len, got[j]['lyrics'])), 'extra')
    out, i, j = [], n, m
    while (i, j) != (0, 0):
        pi, pj, move = back[i][j]
        out.append({'pair': ([pi], pj), 'merge': ([pi, pi + 1], pj), 'missing': ([pi], None), 'extra': ([], pj)}[move])
        i, j = pi, pj
    return table[n][m], out[::-1]

def align_systems(truth, got):
    """Pairs of (truth system index or None, got system index or None)."""
    n, m = len(truth), len(got)
    if n == m: return [(i, i) for i in range(n)]
    weight = lambda bars: BAR_GAP * len(bars) + sum(len(b['chords']) + sum(map(len, b['lyrics'])) for b in bars)
    table = [[0] * (m + 1) for _ in range(n + 1)]
    for i in range(1, n + 1): table[i][0] = table[i - 1][0] + weight(truth[i - 1])
    for j in range(1, m + 1): table[0][j] = table[0][j - 1] + weight(got[j - 1])
    pair = {}
    for i in range(1, n + 1):
        for j in range(1, m + 1):
            pair[i, j] = align_bars(truth[i - 1], got[j - 1])[0]
            table[i][j] = min(table[i - 1][j - 1] + pair[i, j], table[i - 1][j] + weight(truth[i - 1]), table[i][j - 1] + weight(got[j - 1]))
    out, i, j = [], n, m
    while i or j:
        if i and j and table[i][j] == table[i - 1][j - 1] + pair[i, j]: out.append((i - 1, j - 1)); i -= 1; j -= 1
        elif i and table[i][j] == table[i - 1][j] + weight(truth[i - 1]): out.append((i - 1, None)); i -= 1
        else: out.append((None, j - 1)); j -= 1
    return out[::-1]

FIELDS = ('bars', 'got_bars', 'systems', 'got_systems', 'missing_systems', 'extra_systems', 'missing_bars',
          'merged_bars', 'extra_bars', 'chords', 'chord_errors', 'syllables', 'lyric_errors', 'verse_swaps',
          'onset_bars', 'onset_wrong', 'sign_bars', 'sign_wrong', 'bars_exact')

def score(song, version, truth):
    path = f'{DATA}/out{RUN}/{song}/{version}.mxl'
    if not os.path.exists(path): return None
    g_systems, counter = [], 0
    lines = systems(load(path))
    if truth.get('partial'):
        # The answer key covers only the first lines of a long score.
        lines = lines[:len(truth['systems'])]
    for line in lines:
        g_systems.append([])
        for b in line:
            g_systems[-1].append(dict(view(b), index=counter)); counter += 1
    flagged = flags(song) if version == 'ai' else set()
    t_systems = [[view(b) for b in s['bars']] for s in truth['systems']]
    files = [s['file'] for s in truth['systems']]
    r = {k: 0 for k in FIELDS}
    r.update(bars=sum(map(len, t_systems)), got_bars=sum(map(len, g_systems)), systems=len(t_systems),
             got_systems=len(g_systems), diffs=[], wrong=[])
    def note(file, number, g, kinds):
        # A bar whose chords, lyrics or barlines are not as printed, and whether the app
        # would point the user at it (server check or an AI suggestion left for review).
        if kinds: r['wrong'].append({'file': file, 'bar': number, 'index': g.get('index'), 'kinds': kinds,
                                     'flagged': g.get('index') in flagged})
    def add(file, bar, kind, t, g): r['diffs'].append((file, bar, kind, t, g))
    def compare(file, number, t, g, found, merged=False):
        r['chords'] += len(t['chords']); ce = distance(t['chords'], g['chords']); r['chord_errors'] += ce
        if ce and found: add(file, number, 'chords', ' '.join(t['chords']), ' '.join(g['chords']))
        kinds = (['chords'] if ce else [])
        pairs, swapped = lyric_pairs(t['lyrics'], g['lyrics'])
        le = 0
        for v, (a, b) in enumerate(pairs):
            r['syllables'] += len(a); d = distance(a, b); le += d
            if d and found: add(file, number, f'lyrics{v + 1}', ''.join(a), ''.join(b))
        r['lyric_errors'] += le
        if le: kinds.append('lyrics')
        if not found: kinds = ['missing']
        if merged: kinds.insert(0, 'merged')
        note(file, number, g, kinds)
        if swapped: r['verse_swaps'] += 1; add(file, number, 'verse-number', '', '')
        wrong_onsets = wrong_signs = False
        if found:
            r['onset_bars'] += 1
            if t['onsets'] != g['onsets']:
                wrong_onsets = True; r['onset_wrong'] += 1; add(file, number, 'onsets', str(t['onsets']), str(g['onsets']))
            if t['signs'] or g['signs']:
                r['sign_bars'] += 1
                if t['signs'] != g['signs']:
                    wrong_signs = True; r['sign_wrong'] += 1; add(file, number, 'signs', ' '.join(t['signs']), ' '.join(g['signs']))
        return found and not ce and not le and not wrong_onsets and not wrong_signs
    for ti, gi in align_systems(t_systems, g_systems):
        if ti is None:
            r['extra_systems'] += 1; r['extra_bars'] += len(g_systems[gi]); add('?', None, 'extra-system', '', f'{len(g_systems[gi])} bars'); continue
        file, tb = files[ti], t_systems[ti]
        if gi is None:
            r['missing_systems'] += 1; r['missing_bars'] += len(tb); add(file, None, 'missing-system', f'{len(tb)} bars', '')
            for n, t in enumerate(tb, 1): compare(file, n, t, EMPTY, False)
            continue
        for indexes, g_index in align_bars(tb, g_systems[gi])[1]:
            if not indexes:
                r['extra_bars'] += 1; add(file, None, 'extra-bar', '', json.dumps(g_systems[gi][g_index], ensure_ascii=False)); note(file, None, g_systems[gi][g_index], ['extra']); continue
            number = indexes[0] + 1
            if g_index is None:
                r['missing_bars'] += 1; add(file, number, 'missing-bar', json.dumps(tb[indexes[0]], ensure_ascii=False), '')
                compare(file, number, tb[indexes[0]], EMPTY, False); continue
            if len(indexes) == 2:
                r['merged_bars'] += 2; add(file, number, 'merged-bars', f'bars {number} and {number + 1}', 'one bar')
                compare(file, number, joined(tb[indexes[0]], tb[indexes[1]]), g_systems[gi][g_index], True, True)
                continue
            r['bars_exact'] += compare(file, number, tb[indexes[0]], g_systems[gi][g_index], True)
    return r

def flags(song):
    """Measure indexes the review screen lists: a server check fired or the AI left a
    suggestion for the user to decide."""
    out = set()
    try:
        for issue in json.load(open(f'{DATA}/out{RUN}/{song}/validation.json'))['issues']:
            if issue.get('part', 0) == 0: out.add(issue['measureIndex'])
        for item in json.load(open(f'{DATA}/out{RUN}/{song}/ai_review.json')).get('suggestions', []):
            if any(c.get('status') != 'applied' for c in item.get('corrections', [])) or item.get('uncertain'):
                out.add(item['measureIndex'])
    except (OSError, ValueError, KeyError):
        pass
    return out

def pct(a, b): return f'{100 * (1 - a / b):5.1f}%' if b else '   — '

def row(name, v, r):
    return (f"{name:18} {v:5} {r['got_bars']:>4}/{r['bars']:<4} {r['missing_bars']:>4} {r['merged_bars']:>4} {r['extra_bars']:>4} "
            f"{pct(r['chord_errors'], r['chords']):>8} {pct(r['lyric_errors'], r['syllables']):>8} "
            f"{pct(r['onset_wrong'], r['onset_bars']):>8} {pct(r['sign_wrong'], r['sign_bars']):>8} {100 * r['bars_exact'] / r['bars']:6.1f}%")

if __name__ == '__main__':
    result = {}
    for name in sorted(os.listdir(f'{DATA}/truth')):
        song = name[:-5]
        truth = json.load(open(f'{DATA}/truth/{name}'))
        result[song] = {v: score(song, v, truth) for v in VERSIONS}
    json.dump(result, open(f'{DATA}/scores{RUN}.json', 'w'), ensure_ascii=False, indent=1)
    only = sys.argv[1:] or VERSIONS
    print(f"{'song':18} {'ver':5} {'bars':>9} {'miss':>4} {'mrgd':>4} {'xtra':>4} {'chords':>8} {'lyrics':>8} {'onsets':>8} {'signs':>8} {'exact':>7}")
    total = {v: None for v in VERSIONS}
    for song, versions in result.items():
        for v, r in versions.items():
            if r is None: continue
            if v in only: print(row(song, v, r))
            t = total[v] = total[v] or {k: 0 for k in FIELDS}
            for k in FIELDS: t[k] += r[k]
    for v, r in total.items():
        if r: print(row('TOTAL', v, r), f"  ({r['chords']} chords, {r['syllables']} syllables, lines missing {r['missing_systems']}, verse swaps {r['verse_swaps']})")
