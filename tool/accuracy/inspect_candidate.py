"""Run installed rule repairs and validation on a NEW isolated engine candidate.

No service writes, credentials, model calls or original-file modifications.
Run on the OMR host with PYTHONPATH=/opt/omr and the normal OCR environment.
"""
import argparse
import json
import shutil
from pathlib import Path

from omr_server import _postprocess, _inspect_score, _validate
from omr_score import _read_score
from omr_validate import _corrections


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folder', type=Path)
    args = parser.parse_args()
    folder = args.folder
    if (folder/'fixed.mxl').exists():
        parser.error('already inspected; do not overwrite')
    raw = folder/'score.mxl'
    before = _read_score(raw)
    result, repairs = _postprocess(raw, 'chords_lyrics')
    shutil.copy2(result, folder/'fixed.mxl')
    (folder/'repairs.json').write_text(json.dumps(repairs, ensure_ascii=False, indent=2))
    (folder/'corrections.json').write_text(json.dumps(_corrections(before, _read_score(result)), ensure_ascii=False))
    validation = _validate(result, folder)
    print(json.dumps({'metrics': _inspect_score(result), 'validation': validation, 'repairs': repairs}, ensure_ascii=False))


if __name__ == '__main__':
    main()
