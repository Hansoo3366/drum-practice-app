"""Runs the server's post-processing here, on what the engine wrote for each song at
conversion time (the saved raw export and its .omr book), and writes the result as a run
that score.py scores. No conversion, no AI: what comes out is the server's "fixed" stage.

  TESSDATA_PREFIX=<tessdata 4.1.0 with kor, eng> python3 tool/accuracy/replay_post.py <source run> <new run> [song ...]

With OMR_HYBRID_NOTES=1 and HOMR_READ=<dir of saved homr results> the bars and notes come
from homr (server/omr/omr_hybrid.py).

It is how a change to the server's post-processing is measured before it is deployed. The
text reader here is not the server's build of it, so a few syllables may differ."""
import json, os, shutil, sys, tempfile
from pathlib import Path
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent.parent / 'server' / 'omr'))
os.environ.setdefault('OMR_OCR_LANGUAGES', 'eng+kor')
import score as scoring  # noqa: E402
import omr_server  # noqa: E402
import omr_ai  # noqa: E402

def replay(song, source_run, new_run, work):
    data = Path(scoring.DATA)
    source = data / f'out{source_run}' / song
    label = json.loads((data / 'out2' / song / 'diagnostics.json').read_text())['selected']
    book = data / 'books2' / song / label / 'score.omr'
    job = Path(work) / song
    folder = job / 'out' / label
    folder.mkdir(parents=True)
    (job / 'in').mkdir()
    shutil.copy2(data / 'pdf' / f'{song}.pdf', job / 'in' / 'score.pdf')
    shutil.copy2(book, folder / 'score.omr')
    shutil.copy2(source / 'raw.mxl', folder / 'score.mxl')
    # What the second reader read of each page, saved earlier (HOMR_READ=<dir> with
    # <song>/p<N>.musicxml and <song>/p<N>.json), where the server keeps it for a job.
    read = os.environ.get('HOMR_READ')
    if read:
        (folder / 'homr').mkdir()
        for page in sorted((Path(read) / song).glob('p*.musicxml')):
            seen = page.with_suffix('.json')
            if seen.is_file():
                shutil.copy2(page, folder / 'homr' / f'sheet{page.stem[1:]}.musicxml')
                shutil.copy2(seen, folder / 'homr' / f'sheet{page.stem[1:]}.json')
    result, report = omr_server._postprocess(folder / 'score.mxl', 'chords_lyrics')
    out = data / f'out{new_run}' / song
    out.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source / 'raw.mxl', out / 'raw.mxl')
    for name in ('fixed.mxl', 'ai.mxl'):
        shutil.copy2(result, out / name)
    (out / 'repairs.json').write_text(json.dumps(report, ensure_ascii=False, indent=1, default=str))
    # What the server does next with the result: the checks, the picture of every bar for
    # the app, and the pictures and descriptions the AI review is asked about (not asked here).
    report['validation'] = omr_server._validate(result, folder)
    for name in ('validation.json', 'layout.json'):
        if (folder / name).is_file():
            shutil.copy2(folder / name, out / name)
    book = omr_server._load_book(omr_server._read_score(result), folder, ocr=False)
    report['tied_to_page'] = book is not None and not book['unmatched']
    if book is not None:
        shutil.rmtree(out / 'ai', ignore_errors=True)
        report['ai_lines'] = len(omr_ai._ai_dataset(omr_server._read_score(result), book, out / 'ai'))
    return report

if __name__ == '__main__':
    source_run, new_run = sys.argv[1:3]
    data = Path(scoring.DATA)
    songs = sys.argv[3:] or sorted(p.stem for p in (data / 'truth').glob('*.json'))
    with tempfile.TemporaryDirectory() as work:
        for song in songs:
            try:
                report = replay(song, source_run, new_run, work)
                print(f"{song:18} chords reread {report.get('chords_reread')}, added {report.get('chords_added')}, "
                      f"lyrics {(report.get('lyrics_ocr') or {}).get('syllables')}, tied to page {report.get('tied_to_page')}, "
                      f"AI lines {report.get('ai_lines')}, hybrid {report.get('hybrid')}", flush=True)
            except Exception as error:  # a song that fails says so and the others go on
                print(f'{song:18} FAILED {error!r}', flush=True)
