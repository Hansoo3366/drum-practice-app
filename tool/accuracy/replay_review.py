"""Applies the AI review a conversion already got (the downloaded ai_review.json) to its
rule-corrected version (fixed.mxl) again, with the server's code as it is here, and writes
the run that score.py scores. No model is asked anything: this measures a change to how
answers are applied (omr_ai._apply_ai_measure), not a new review.

  python3 tool/accuracy/replay_review.py <source run> <new run> [--review-from <run>] [song ...]

With --review-from, the review is that run's and the rule-corrected version the source run's:
for a change to the rules before the review (the bars must still be the same).

A song whose review changed nothing has no ai.mxl on the server; here its ai.mxl is its
fixed.mxl, as the app shows it."""
import json, shutil, sys, tempfile
from pathlib import Path
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent.parent / 'server' / 'omr'))
import score as scoring  # noqa: E402
import omr_ai  # noqa: E402
import omr_hybrid  # noqa: E402
from omr_score import _read_score  # noqa: E402


def _index_map(reviewed, current):
    """For each bar of the score the review was made of, the same bar of the score as it is
    now, when lines were put in or left out since (lines matched by their bar counts); None
    when the bars are the same."""
    import difflib
    old = [len(line) for line in omr_hybrid._lines(reviewed.find('part').findall('measure'))]
    new = [len(line) for line in omr_hybrid._lines(current.find('part').findall('measure'))]
    if old == new:
        return None
    starts_old = [sum(old[:i]) for i in range(len(old))]
    starts_new = [sum(new[:i]) for i in range(len(new))]
    mapping = {}
    for a, b, size in difflib.SequenceMatcher(None, old, new, autojunk=False).get_matching_blocks():
        for k in range(size):
            for bar in range(old[a + k]):
                mapping[starts_old[a + k] + bar] = starts_new[b + k] + bar
    return mapping


def replay(song, source_run, new_run, review_run=None):
    data = Path(scoring.DATA)
    source, out = data / f'out{source_run}' / song, data / f'out{new_run}' / song
    reviewed_run = review_run or source_run
    review = json.loads((data / f'out{reviewed_run}' / song / 'ai_review.json').read_text())
    root = _read_score(source / 'fixed.mxl')
    measures = root.find('part').findall('measure')
    keys = omr_ai._key_fifths(measures)
    mapping = _index_map(_read_score(data / f'out{reviewed_run}' / song / 'fixed.mxl'), root)
    items, answers = [], {}
    for suggestion in review['suggestions']:
        index = suggestion['measureIndex']
        if mapping is not None:
            index = mapping.get(index)
            if index is None:
                continue
        name = f'm{index}'
        items.append({'id': name, 'measureIndex': [index], 'targets': [suggestion['measure']], 'fifths': keys[index]})
        corrections = [{k: v for k, v in fix.items() if k != 'status'} for fix in suggestion['corrections']]
        answers[name] = {'answer': {'corrections': corrections, 'uncertain': suggestion.get('uncertain') or []}}
    out.mkdir(parents=True, exist_ok=True)
    for name in ('raw.mxl', 'fixed.mxl'):
        shutil.copy2(source / name, out / name)
    with tempfile.TemporaryDirectory() as work:
        report = omr_ai._ai_apply(root, items, answers, review.get('model') or 'replay', Path(work))
        made = Path(work) / 'ai.mxl'
        shutil.copy2(made if made.is_file() else source / 'fixed.mxl', out / 'ai.mxl')
        shutil.copy2(Path(work) / 'ai_review.json', out / 'ai_review.json')
    return report['applied'], len(review['applied'])


if __name__ == '__main__':
    source_run, new_run = sys.argv[1:3]
    rest = sys.argv[3:]
    review_run = None
    if rest[:1] == ['--review-from']:
        review_run, rest = rest[1], rest[2:]
    data = Path(scoring.DATA)
    songs = rest or sorted(p.name for p in (data / f'out{review_run or source_run}').iterdir() if (p / 'ai_review.json').is_file())
    for song in songs:
        now, before = replay(song, source_run, new_run, review_run)
        print(f'{song:18} applied {before} -> {now}', flush=True)
