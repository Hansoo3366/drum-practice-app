"""Fail closed below the requested accuracy target; never call note counts pitch accuracy."""
from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path


def evaluate(scores: dict, minimum: float = 95.0) -> dict:
    if not 0 < minimum <= 100:
        raise ValueError('minimum must be in (0, 100]')
    fields = ('bars', 'bars_exact', 'chords', 'chord_errors', 'syllables', 'lyric_errors',
              'onset_bars', 'onset_wrong', 'sign_bars', 'sign_wrong', 'merged_bars', 'missing_bars')
    totals = {field: 0 for field in fields}
    missing = []
    for song, versions in scores.items():
        result = versions.get('ai')
        if result is None:
            missing.append(song)
            continue
        for field in fields:
            totals[field] += result[field]
    bars = totals['bars']
    required = math.ceil(bars * minimum / 100)
    exact = 100 * totals['bars_exact'] / bars if bars else 0.0
    target_met = bool(scores) and bars > 0 and not missing and totals['bars_exact'] >= required
    return {'requested_percent': minimum, 'measured_metric': 'chords_lyrics_onset_count_signs_exact_bar',
            'bars': bars, 'correct_bars': totals['bars_exact'], 'exact_percent': exact,
            'required_correct_bars': required, 'additional_correct_bars_needed': max(0, required - totals['bars_exact']),
            'coarse_target_met': target_met, 'release_ready': False,
            'pitch_accuracy': 'not_measured', 'duration_accuracy': 'not_measured',
            'independent_holdout': 'not_verified', 'missing_songs': missing, 'totals': totals}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('scores', type=Path)
    parser.add_argument('--minimum', type=float, default=95.0)
    args = parser.parse_args()
    result = evaluate(json.loads(args.scores.read_text()), args.minimum)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    # Even the coarse target cannot certify release quality without pitch,
    # rhythm and independent data. The gate never silently waives those gaps.
    sys.exit(0 if result['release_ready'] else 1)


if __name__ == '__main__':
    main()
