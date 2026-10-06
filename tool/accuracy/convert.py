"""Converts every song through the public HTTPS API as the app does (register an
install, upload the PDF with the chords_lyrics profile, poll, download the versions).
The app key comes from the build file the project documents (docs/OMR_SERVER_ACCESS.md,
"빌드용 앱 키 파일"); this script never reads it from the server and never prints it."""
import argparse, json, os, re, sys, threading, time, urllib.request, urllib.error, uuid
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
# Pictures, answer keys and results live outside git (they hold whole lyrics).
DATA = os.environ.get('ACCURACY_DATA', os.path.join(ROOT, 'score_sample', '_accuracy'))
LOCAL = os.path.join(ROOT, 'dart_defines.local.json')
if not os.path.exists(LOCAL):
    sys.exit('dart_defines.local.json is missing: see docs/OMR_SERVER_ACCESS.md')
defines = json.load(open(LOCAL))
BASE, KEY = defines['OMR_BASE_URL'].rstrip('/'), defines['OMR_TOKEN']

def call(method, path, headers=None, data=None, timeout=120, tries=4):
    """One request; a dropped connection or timeout is tried again (reads only)."""
    for attempt in range(tries):
        req = urllib.request.Request(BASE + path, data=data, method=method, headers=headers or {})
        try:
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return r.status, r.read()
        except urllib.error.HTTPError as e:
            return e.code, e.read()
        except Exception as e:  # network trouble
            if method != 'GET' or attempt == tries - 1:
                return 0, repr(e).encode()
            time.sleep(5)

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('run')
parser.add_argument('--client-run', help='reuse an EXISTING QA install; never register one to evade quota')
parser.add_argument('--client-file', help='QA install secret OUTSIDE the repository (default: user cache)')
parser.add_argument('--songs', nargs='+', help='explicit subset, otherwise all songs')
args = parser.parse_args()
RUN = args.run
if not re.fullmatch(r'[A-Za-z0-9_-]+', RUN) or not re.fullmatch(r'[A-Za-z0-9_-]+', args.client_run or RUN):
    parser.error('run/client-run must be simple names')
if args.client_run and args.client_file:
    parser.error('choose client-run or client-file, not both')
if args.client_run:
    secret_path = Path(f'{DATA}/.client{args.client_run}')
    if not secret_path.exists():
        sys.exit('existing QA install is missing; no registration or credential creation performed')
else:
    secret_path = Path(args.client_file).expanduser() if args.client_file else Path.home() / '.cache/piano-score-qa/omr-client'
    secret_path = secret_path.resolve()
    if secret_path.is_relative_to(Path(ROOT).resolve()):
        parser.error('credentials must stay outside the repository')
    if not secret_path.exists():
        status, body = call('POST', '/clients', {'X-Omr-Token': KEY})
        if status != 201:
            sys.exit(f'register failed: http {status}')
        secret_path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        fd = os.open(secret_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, 'w') as f:
            f.write(json.loads(body)['secret'])
secret = secret_path.read_text().strip()
AUTH = {'X-Omr-Token': KEY, 'Authorization': f'Bearer {secret}'}

def multipart(fields, name, content):
    boundary = uuid.uuid4().hex
    parts = [f'--{boundary}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n'.encode() for k, v in fields.items()]
    parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{name}"\r\n'
                 f'Content-Type: application/pdf\r\n\r\n'.encode() + content + b'\r\n')
    parts.append(f'--{boundary}--\r\n'.encode())
    return b''.join(parts), f'multipart/form-data; boundary={boundary}'

jobs_path = f'{DATA}/jobs{RUN}.json'
jobs = json.load(open(jobs_path)) if os.path.exists(jobs_path) else {}
jobs_lock = threading.Lock()

def save_job(song, value):
    # Concurrent completions must not truncate/interleave the resumable cache.
    with jobs_lock:
        jobs[song] = value
        temporary = jobs_path + '.tmp'
        with open(temporary, 'w') as f:
            json.dump(jobs, f, indent=1)
        os.replace(temporary, jobs_path)
FILES = {'fixed.mxl': 'result', 'raw.mxl': 'raw', 'ai.mxl': 'ai', 'ai_review.json': 'ai-review',
         'layout.json': 'layout', 'validation.json': 'validation', 'corrections.json': 'corrections',
         'diagnostics.json': 'diagnostics'}

def run(song):
    try:
        _run(song)
    except Exception as e:
        print(song, 'client error', repr(e)[:200], flush=True)

def _run(song):
    known = jobs.get(song, {})
    if known.get('status') == 'submitted':
        # Uploaded by an earlier run: wait for that job instead of converting again.
        started, info = time.time(), {}
        while time.time() - started < 1800:
            status, answer = call('GET', f"/jobs/{known['id']}", AUTH)
            info = json.loads(answer) if status == 200 else {'status': f'http {status}'}
            if info.get('status') in ('done', 'failed', 'error') or status == 404: break
            time.sleep(8)
        save_job(song, {'id': known['id'], 'status': info.get('status'), 'error': info.get('error') or '', 'seconds': None})
    elif known.get('status') != 'done':
        body, ctype = multipart({'profile': 'chords_lyrics'}, f'{song}.pdf', open(f'{DATA}/pdf/{song}.pdf', 'rb').read())
        started = time.time()
        status, answer = call('POST', '/convert', {**AUTH, 'Content-Type': ctype}, body, timeout=300)
        if status != 202:
            save_job(song, {'status': 'rejected', 'http': status, 'body': answer[:200].decode('utf-8', 'replace')})
            print(song, 'rejected', status, flush=True); return
        job = json.loads(answer)['id']
        save_job(song, {'id': job, 'status': 'submitted'})
        info = {}
        while time.time() - started < 1800:
            time.sleep(8)
            status, answer = call('GET', f'/jobs/{job}', AUTH)
            info = json.loads(answer) if status == 200 else {'status': f'http {status}'}
            if info.get('status') in ('done', 'failed', 'error'): break
        save_job(song, {'id': job, 'status': info.get('status'), 'error': info.get('error') or '', 'seconds': round(time.time() - started)})
    job = jobs[song]
    got = []
    if job['status'] == 'done':
        os.makedirs(f'{DATA}/out{RUN}/{song}', exist_ok=True)
        for name, path in FILES.items():
            status, data = call('GET', f"/jobs/{job['id']}/{path}", AUTH)
            if status == 200:
                open(f'{DATA}/out{RUN}/{song}/{name}', 'wb').write(data); got.append(name.split('.')[0])
    print(song, job['status'], job.get('seconds'), 's', (job.get('error') or '')[:120], 'files:', ' '.join(got), flush=True)

songs = sorted(json.load(open(f'{HERE}/songs.json')))
if args.songs:
    if not set(args.songs).issubset(songs):
        parser.error('unknown song')
    songs = sorted(set(args.songs))
with ThreadPoolExecutor(2) as pool:
    for future in [pool.submit(run, song) for song in songs]:
        future.result()
json.dump(jobs, open(jobs_path, 'w'), indent=1)
print('done', flush=True)
