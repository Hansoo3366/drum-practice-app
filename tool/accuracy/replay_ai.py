"""Replay frozen AI answers without new model calls or changed answer keys.

Usage: python3 tool/accuracy/replay_ai.py --fetch --source-run 2 --run 3
The SSH cache contains score content, never credentials. Keep it out of git.
This measures application-code changes, NOT a fresh end-to-end conversion.
"""
from __future__ import annotations

import argparse
import copy
import json
import re
import shutil
import subprocess
from pathlib import Path

import score as scoring
from extract import load
import omr_ai
from omr_score import _write_mxl


def wrong_bars(result: dict, truth: dict) -> set[tuple[str, int]]:
    wrong = set()
    sizes = {s['file']: len(s['bars']) for s in truth['systems']}
    for file, number, kind, _before, _after in result['diffs']:
        if kind in ('verse-number', 'extra-bar', 'extra-system'):
            continue
        if kind == 'missing-system':
            wrong.update((file, n) for n in range(1, sizes[file] + 1))
        elif number is not None:
            wrong.add((file, number))
            if kind == 'merged-bars':
                wrong.add((file, number + 1))
    return wrong


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-run', default='2')
    parser.add_argument('--run', required=True)
    parser.add_argument('--fetch', action='store_true')
    args = parser.parse_args()
    for value in (args.source_run, args.run):
        if re.fullmatch(r'[A-Za-z0-9_-]+', value) is None:
            parser.error('run must be a simple name')
    if args.run == args.source_run:
        parser.error('never overwrite the source run')
    data = Path(scoring.DATA)
    destination = data / f'out{args.run}'
    if destination.exists():
        parser.error(f'{destination} already exists; choose a new run')
    cache = data / f'ai_cache{args.source_run}'
    jobs = json.loads((data / f'jobs{args.source_run}.json').read_text())
    report = {'type': 'frozen_ai_replay', 'source_run': args.source_run, 'run': args.run,
              'songs': {}, 'totals': {}}
    for song, job in sorted(jobs.items()):
        if re.fullmatch(r'[A-Za-z0-9_-]+', song) is None or re.fullmatch(r'[a-f0-9]{32}', job['id']) is None:
            raise ValueError('unsafe song/job identifier')
        source = data / f'out{args.source_run}' / song
        model = json.loads((source / 'ai_review.json').read_text())['model']
        if re.fullmatch(r'[A-Za-z0-9_.@-]+', model) is None:
            raise ValueError('unsafe model identifier')
        local_cache = cache / song
        local_cache.mkdir(parents=True, exist_ok=True)
        files = ['dataset.json', f'answers-{model}.json']
        if args.fetch:
            for name in files:
                if not (local_cache / name).exists():
                    subprocess.run(['scp', '-q', '-i', str(Path.home() / '.ssh/codex_omr_ed25519'),
                                    '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=10',
                                    f'hanso3366@34.10.15.222:/opt/omr/jobs/{job["id"]}/out/ai/{name}',
                                    str(local_cache / name)], check=True, timeout=60)
        items = json.loads((local_cache / files[0]).read_text())
        answers = json.loads((local_cache / files[1]).read_text())
        outgoing = destination / song
        outgoing.mkdir(parents=True)
        for name in ('raw.mxl', 'fixed.mxl', 'layout.json', 'validation.json', 'corrections.json', 'diagnostics.json'):
            if (source / name).exists():
                shutil.copy2(source / name, outgoing / name)
        root = load(source / 'fixed.mxl')
        omr_ai._ai_apply(root, copy.deepcopy(items), copy.deepcopy(answers), model, outgoing)
        # No applied suggestions is a valid unchanged result, not a missing score.
        if not (outgoing / 'ai.mxl').exists():
            _write_mxl(root, outgoing / 'ai.mxl')
        truth = json.loads((data / 'truth' / f'{song}.json').read_text())
        scoring.RUN = args.source_run
        before = scoring.score(song, 'ai', truth)
        scoring.RUN = args.run
        after = scoring.score(song, 'ai', truth)
        old_wrong, new_wrong = wrong_bars(before, truth), wrong_bars(after, truth)
        row = {'bars': after['bars'], 'before_exact': before['bars_exact'], 'after_exact': after['bars_exact'],
               'before_chord_errors': before['chord_errors'], 'after_chord_errors': after['chord_errors'],
               'before_lyric_errors': before['lyric_errors'], 'after_lyric_errors': after['lyric_errors'],
               'fixed_bars': sorted(old_wrong - new_wrong), 'regressed_bars': sorted(new_wrong - old_wrong)}
        report['songs'][song] = row
        print(song, f"{row['before_exact']}/{row['bars']} -> {row['after_exact']}/{row['bars']}",
              'regressions', len(row['regressed_bars']), flush=True)
    for field in ('bars', 'before_exact', 'after_exact', 'before_chord_errors', 'after_chord_errors',
                  'before_lyric_errors', 'after_lyric_errors'):
        report['totals'][field] = sum(s[field] for s in report['songs'].values())
    report['totals']['regressed_bars'] = sum(len(s['regressed_bars']) for s in report['songs'].values())
    report['totals']['fixed_bars'] = sum(len(s['fixed_bars']) for s in report['songs'].values())
    target = data / f'replay-report-{args.run}.json'
    target.write_text(json.dumps(report, ensure_ascii=False, indent=2))
    print(json.dumps(report['totals']), flush=True)


if __name__ == '__main__':
    main()
