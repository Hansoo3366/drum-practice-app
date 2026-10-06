"""Replay book-symbol recovery + frozen AI answers; never overwrite source/truth.

This is NOT fresh conversion. Usage: python3 tool/accuracy/replay_rhythm.py --fetch --run 4
"""
import argparse
import copy
import json
import re
import shutil
import subprocess
from pathlib import Path

import score as scoring
from extract import load
from replay_ai import wrong_bars
from omr_book import _restore_exported_rhythm, _load_book
from omr_score import _write_mxl
from omr_validate import _corrections, _validate_score, _image_checks
import omr_ai


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', required=True)
    parser.add_argument('--fetch', action='store_true')
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9_-]+', args.run) or args.run in ('2', '3'):
        parser.error('choose a new simple run name, not 2 or 3')
    data = Path(scoring.DATA)
    destination = data / f'out{args.run}'
    if destination.exists():
        parser.error('destination already exists; do not overwrite')
    jobs = json.loads((data / 'jobs2.json').read_text())
    report = {'type': 'frozen_book_and_ai_replay', 'run': args.run, 'songs': {}}
    for song, job in sorted(jobs.items()):
        if not re.fullmatch(r'[A-Za-z0-9_-]+', song) or not re.fullmatch(r'[a-f0-9]{32}', job['id']):
            raise ValueError('unsafe song/job')
        source = data / 'out2' / song
        label = json.loads((source / 'diagnostics.json').read_text())['selected']
        if label not in ('dpi-300', 'dpi-400', 'original'):
            raise ValueError('unsupported candidate label')
        folder = data / 'books2' / song / label
        folder.mkdir(parents=True, exist_ok=True)
        book = folder / 'score.omr'
        if args.fetch and not book.exists():
            subprocess.run(['scp', '-q', '-i', str(Path.home() / '.ssh/codex_omr_ed25519'),
                            '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=10',
                            f'hanso3366@34.10.15.222:/opt/omr/jobs/{job["id"]}/out/{label}/score.omr', str(book)],
                           check=True, timeout=90)
        if not book.exists():
            raise FileNotFoundError(book)
        root = load(source / 'fixed.mxl')
        repairs = _restore_exported_rhythm(root, folder)
        outgoing = destination / song
        outgoing.mkdir(parents=True)
        for name in ('raw.mxl', 'layout.json'):
            if (source / name).exists():
                shutil.copy2(source / name, outgoing / name)
        _write_mxl(root, outgoing / 'fixed.mxl')
        (outgoing / 'corrections.json').write_text(json.dumps(_corrections(load(source / 'raw.mxl'), root), ensure_ascii=False))
        # Old runtime/candidate metrics and rule flags are not evidence about
        # this changed score. Preserve them with SOURCE-prefixed names only.
        for name in ('diagnostics.json', 'validation.json'):
            if (source / name).exists():
                shutil.copy2(source / name, outgoing / f'source_{name}')
        checked = copy.deepcopy(root)
        issues = _validate_score(checked)
        linked_book = _load_book(checked, folder, ocr=False)
        if linked_book is not None:
            issues += _image_checks(checked, linked_book)
        # Physical annotations and measure indexes are unchanged in this replay.
        original_flags = json.loads((source / 'validation.json').read_text())
        issues += [i for i in original_flags.get('issues', []) if i['rule'] == 'A001']
        summary = {}
        for issue in issues:
            summary[issue['rule']] = summary.get(issue['rule'], 0) + 1
        (outgoing / 'validation.json').write_text(json.dumps(
            {'source': 'frozen_replay/rules_and_book/annotation_flags_from_source', 'summary': summary, 'issues': issues},
            ensure_ascii=False, indent=2))
        cache = data / 'ai_cache2' / song
        model = json.loads((source / 'ai_review.json').read_text())['model']
        if not re.fullmatch(r'[A-Za-z0-9_.@-]+', model):
            raise ValueError('unsafe model')
        items = json.loads((cache / 'dataset.json').read_text())
        answers = json.loads((cache / f'answers-{model}.json').read_text())
        omr_ai._ai_apply(root, copy.deepcopy(items), copy.deepcopy(answers), model, outgoing)
        if not (outgoing / 'ai.mxl').exists():
            _write_mxl(root, outgoing / 'ai.mxl')
        truth = json.loads((data / 'truth' / f'{song}.json').read_text())
        scoring.RUN = '3'
        before = scoring.score(song, 'ai', truth)
        scoring.RUN = args.run
        after = scoring.score(song, 'ai', truth)
        old_wrong, new_wrong = wrong_bars(before, truth), wrong_bars(after, truth)
        row = {'before_exact': before['bars_exact'], 'after_exact': after['bars_exact'], 'bars': after['bars'],
               'before_onset_wrong': before['onset_wrong'], 'after_onset_wrong': after['onset_wrong'],
               'before_lyric_errors': before['lyric_errors'], 'after_lyric_errors': after['lyric_errors'],
               'repairs': repairs, 'fixed_bars': sorted(old_wrong - new_wrong),
               'regressed_bars': sorted(new_wrong - old_wrong)}
        report['songs'][song] = row
        print(song, row['before_exact'], '->', row['after_exact'], 'recovered', len(repairs),
              'regressed', len(row['regressed_bars']), flush=True)
    fields = ('before_exact', 'after_exact', 'bars', 'before_onset_wrong', 'after_onset_wrong',
              'before_lyric_errors', 'after_lyric_errors')
    report['totals'] = {f: sum(s[f] for s in report['songs'].values()) for f in fields}
    for f in ('fixed_bars', 'regressed_bars', 'repairs'):
        report['totals'][f] = sum(len(s[f]) for s in report['songs'].values())
    (data / f'rhythm-report-{args.run}.json').write_text(json.dumps(report, ensure_ascii=False, indent=2))
    print(report['totals'])


if __name__ == '__main__':
    main()
