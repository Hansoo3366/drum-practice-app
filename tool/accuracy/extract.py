"""What a converted MusicXML says, system by system and bar by bar, in the same shape
as the by-eye answer key (truth/*.json)."""
import io, json, os, sys, zipfile
import xml.etree.ElementTree as ET
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), 'server', 'omr'))
from omr_validate import _harmony_label, _printed_measures  # noqa: E402

def load(path):
    data = open(path, 'rb').read()
    if data[:2] == b'PK':
        z = zipfile.ZipFile(io.BytesIO(data))
        name = next(n for n in z.namelist() if not n.startswith('META-INF') and n.endswith(('.xml', '.musicxml')))
        data = z.read(name)
    return ET.fromstring(data)

def bar(measure):
    lyrics = {}
    onsets = 0
    for note in measure.findall('note'):
        if note.find('grace') is not None:
            continue
        if note.find('rest') is None and note.find('chord') is None:
            onsets += 1
        for lyric in note.findall('lyric'):
            lyrics.setdefault(lyric.get('number', '1'), []).append((lyric.findtext('text') or '').strip())
    signs, endings = [], []
    for barline in measure.findall('barline'):
        repeat = barline.find('repeat')
        if repeat is not None:
            signs.append('repeat-start' if repeat.get('direction') == 'forward' else 'repeat-end')
        ending = barline.find('ending')
        if ending is not None:
            import re as _re
            numbers = [n for n in _re.split(r'[,\s]+', ending.get('number') or '') if n]
            endings.append((barline.get('location') or 'right', ending.get('type'), numbers))
    for sound in measure.iter('sound'):
        for attr, sign in (('segno', 'segno'), ('coda', 'coda'), ('tocoda', 'to-coda'), ('dalsegno', 'ds'),
                           ('dacapo', 'dc'), ('fine', 'fine')):
            if sound.get(attr) is not None: signs.append(sign)
    for d in measure.findall('direction'):
        if d.find('direction-type/segno') is not None and 'segno' not in signs: signs.append('segno')
        if d.find('direction-type/coda') is not None and 'coda' not in signs: signs.append('coda')
    marks = [r.text.strip() for r in measure.iter('rehearsal') if (r.text or '').strip()]
    words = [''.join(w.text or '' for w in d.iter('words')).strip() for d in measure.findall('direction')]
    time = measure.find('attributes/time')
    return {
        'number': measure.get('number'),
        'endings': endings,
        'chords': [_harmony_label(h) for h in measure.findall('harmony')],
        'lyrics': [lyrics[k] for k in sorted(lyrics, key=lambda v: int(v) if v.isdigit() else 99)],
        'onsets': onsets,
        'signs': sorted(set(signs)),
        'mark': marks[0] if marks else None,
        'words': [w for w in words if w],
        'time': f"{time.findtext('beats')}/{time.findtext('beat-type')}" if time is not None else None,
        'fifths': measure.findtext('attributes/key/fifths'),
    }

def systems(root):
    out, open_endings = [], []
    for index, measure in enumerate(_printed_measures(root)):
        first = measure.find('print')
        new = index == 0 or (first is not None and (first.get('new-system') == 'yes' or first.get('new-page') == 'yes'))
        if new: out.append([])
        b = bar(measure)
        # A bracket covers every bar from its start to its stop, as the answer key marks it.
        for _where, kind, numbers in b['endings']:
            if kind == 'start': open_endings = numbers
        b['signs'] = sorted(set(b['signs']) | {f'ending-{n}' for n in open_endings})
        if any(kind in ('stop', 'discontinue') for _w, kind, _n in b['endings']): open_endings = []
        del b['endings']
        out[-1].append(b)
    return out

if __name__ == '__main__':
    root = load(sys.argv[1])
    lines = systems(root)
    print(len(root.findall('part')), 'parts,', len(lines), 'systems,', sum(map(len, lines)), 'bars')
    for line in lines[:int(sys.argv[2]) if len(sys.argv) > 2 else 3]:
        for b in line:
            print(' ', json.dumps(b, ensure_ascii=False))
        print()
