"""Asks the server to run the AI review again for conversions whose review failed (every
bar an error: the provider refused, e.g. for lack of credit), and downloads the result.
Nothing is converted again and no conversion is counted; each review is counted against
the day's AI limit and costs what a review costs.

  python3 tool/accuracy/review_again.py <run> [--songs-file tool/accuracy/holdout.json] [--all]

Only songs whose downloaded ai_review.json shows errors for all its bars are asked again;
--all asks for every song of the run. The app key and the QA install's secret are read as
convert.py reads them and never printed."""
import argparse, json, os, sys, time, urllib.request, urllib.error
from pathlib import Path
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
DATA = os.environ.get('ACCURACY_DATA', os.path.join(ROOT, 'score_sample', '_accuracy'))
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('run')
parser.add_argument('--songs-file', default=os.path.join(HERE, 'songs.json'))
parser.add_argument('--all', action='store_true')
args = parser.parse_args()
defines = json.load(open(os.path.join(ROOT, 'dart_defines.local.json')))
BASE, KEY = defines['OMR_BASE_URL'].rstrip('/'), defines['OMR_TOKEN']
secret = (Path.home() / '.cache/piano-score-qa/omr-client').read_text().strip()
AUTH = {'X-Omr-Token': KEY, 'Authorization': f'Bearer {secret}'}


def call(method, path, timeout=120):
    req = urllib.request.Request(BASE + path, data=b'' if method == 'POST' else None, method=method, headers=AUTH)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()
    except Exception as e:  # network trouble
        return 0, repr(e).encode()


def failed(folder):
    try:
        review = json.load(open(f'{folder}/ai_review.json'))
    except (OSError, ValueError):
        return True
    return bool(review.get('measures')) and review.get('errors', 0) >= review['measures']


jobs = json.load(open(f'{DATA}/jobs{args.run}.json'))
for song in sorted(json.load(open(args.songs_file))):
    job, folder = jobs.get(song) or {}, f'{DATA}/out{args.run}/{song}'
    if job.get('status') != 'done' or not (args.all or failed(folder)):
        continue
    status, answer = call('POST', f"/jobs/{job['id']}/ai-review")
    if status != 202:
        print(song, 'not asked: http', status, answer[:120].decode('utf-8', 'replace'), flush=True)
        continue
    started, state = time.time(), 'running'
    while time.time() - started < 600:
        time.sleep(5)
        status, answer = call('GET', f"/jobs/{job['id']}")
        state = json.loads(answer).get('ai') if status == 200 else f'http {status}'
        if state != 'running':
            break
    got = []
    for name, path in (('ai.mxl', 'ai'), ('ai_review.json', 'ai-review')):
        status, data = call('GET', f"/jobs/{job['id']}/{path}")
        if status == 200:
            open(f'{folder}/{name}', 'wb').write(data); got.append(name)
        elif name == 'ai.mxl' and os.path.exists(f'{folder}/{name}'):
            os.remove(f'{folder}/{name}')  # the review changed nothing: no AI version
    review = json.load(open(f'{folder}/ai_review.json')) if os.path.exists(f'{folder}/ai_review.json') else {}
    print(song, 'review', state, round(time.time() - started), 's', 'errors', review.get('errors'), 'of', review.get('measures'),
          'applied', len(review.get('applied') or []), 'tokens', review.get('input_tokens'), review.get('output_tokens'), flush=True)
