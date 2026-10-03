# OMR 서버 접속·배포 방법

이 문서는 Codex, Cursor, Claude 등 이 저장소를 다루는 AI가 PDF→MusicXML 서버에 접속할 때 사용하는 반복 절차다. 개인키는 저장소에 넣지 않는다.

## 접속 정보

- SSH host: `34.10.15.222`
- SSH user: `hanso3366`
- 기본 작업 디렉터리: `/home/hanso3366`
- API: `https://34-10-15-222.sslip.io` (2026-10-03부터. 8080은 VM 안에서만 열려 있다)
- 앱 키(`OMR_TOKEN`): 저장소에 기록하지 않는다. 값은 VM의 `/etc/default/omr`에 있고, 빌드하는 PC는 저장소 루트의 `dart_defines.local.json`(gitignore)에 둔다 — 아래 "빌드용 앱 키 파일".
- 전용 개인키 경로(Mac): `~/.ssh/codex_omr_ed25519`
- 전용 개인키 경로(Windows PC, 2026-10-03 등록): `~/.ssh/omr_deploy_ed25519` (`ssh -i ~/.ssh/omr_deploy_ed25519 -o IdentitiesOnly=yes hanso3366@34.10.15.222`)
- 공개키 fingerprint: `SHA256:dRfq0j3MyQHJSuBHvKLyc45iE2+zPFiy0DVnAs2gy0Q`

서버 IP는 VM 재생성·중지 후 바뀔 수 있으므로 접속 실패 시 `OmrConvertConfig.defaultBaseUrl`과 이 문서를 함께 갱신한다. 개인키 내용·API 토큰을 새 문서나 로그에 출력하지 않는다.

## 접속 확인

```bash
ssh -i ~/.ssh/codex_omr_ed25519 -o BatchMode=yes hanso3366@34.10.15.222 whoami
ssh -i ~/.ssh/codex_omr_ed25519 -o BatchMode=yes hanso3366@34.10.15.222 id
```

접속 사용자는 `sudo` 권한이 있어야 한다. 공개키를 처음 등록할 때는 기존 웹 SSH 세션에서 다음을 실행한다.

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
OMR_PUBLIC_KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFt7wJUXX0L/DTKHp3RCQWAItH1wVPxFmdpJ8scQ9g9v codex-omr-deploy'
grep -qxF "$OMR_PUBLIC_KEY" ~/.ssh/authorized_keys || printf '%s\n' "$OMR_PUBLIC_KEY" >> ~/.ssh/authorized_keys
unset OMR_PUBLIC_KEY
chmod 600 ~/.ssh/authorized_keys
```

### 공개키가 몇 분 뒤 다시 거부될 때

2026-09-28 확인: 웹 SSH에서 `authorized_keys`에 직접 추가한 키는 잠시 뒤 다시 `Permission denied (publickey)`가 된다. Google Cloud 게스트 에이전트가 콘솔 메타데이터의 SSH 키 목록으로 `authorized_keys`를 다시 쓰기 때문으로 보인다. 오래 쓰려면 Google Cloud 콘솔 → Compute Engine → VM 인스턴스 `piano-app` → 수정 → 보안 및 액세스 → **SSH 키 추가**에 아래 한 줄을 넣고 저장한다(사용자 이름 부분이 `hanso3366`이 되도록 끝에 붙인다).

```text
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFt7wJUXX0L/DTKHp3RCQWAItH1wVPxFmdpJ8scQ9g9v hanso3366
```

## 최신 서버 파일 업로드

로컬 저장소 루트에서 최신 서버 파일을 VM 사용자 홈에 올린다.

```bash
scp -i ~/.ssh/codex_omr_ed25519 server/omr/omr_server.py server/omr/update.sh server/omr/compare_musicxml.py hanso3366@34.10.15.222:/home/hanso3366/
```

## 파일을 VM 루트(`/`)로 이동해 배포

사용자가 루트에 파일을 올리는 운영 방식을 요구한 경우, 업로드 후 다음처럼 이동한다. 기존 대상이 있으면 덮어쓰므로 먼저 `ls -l`로 확인한다.

```bash
ssh -i ~/.ssh/codex_omr_ed25519 hanso3366@34.10.15.222 ls -l /omr_server.py /update.sh /compare_musicxml.py
ssh -i ~/.ssh/codex_omr_ed25519 hanso3366@34.10.15.222 sudo mv /home/hanso3366/omr_server.py /omr_server.py
ssh -i ~/.ssh/codex_omr_ed25519 hanso3366@34.10.15.222 sudo mv /home/hanso3366/update.sh /update.sh
ssh -i ~/.ssh/codex_omr_ed25519 hanso3366@34.10.15.222 sudo mv /home/hanso3366/compare_musicxml.py /compare_musicxml.py
ssh -i ~/.ssh/codex_omr_ed25519 hanso3366@34.10.15.222 sudo bash /update.sh /
```

`update.sh`는 `/omr_server.py`를 `/opt/omr/omr_server.py`에 설치하고, systemd 환경 파일 drop-in을 만든 뒤 `omr.service`를 재시작한다. 변환 서비스에 비교 도구는 필수가 아니지만, 서버에서 진단 비교를 하려면 함께 올린다.

홈 디렉터리 파일을 유지하고 싶으면 루트 이동 대신 다음처럼 실행해도 된다.

```bash
ssh -i ~/.ssh/codex_omr_ed25519 hanso3366@34.10.15.222 sudo bash /home/hanso3366/update.sh /home/hanso3366
```

## 배포 후 검증

```bash
ssh -i ~/.ssh/codex_omr_ed25519 hanso3366@34.10.15.222 curl --fail --silent http://127.0.0.1:8080/health
: "${OMR_TOKEN:?export OMR_TOKEN first}"
curl --fail --silent -H "X-Omr-Token: ${OMR_TOKEN}" http://34.10.15.222:8080/health
```

정상 최신 서버는 health 응답에 `"ok":true`와 `"pipeline":"pdf-multipass-v1"`을 포함해야 한다. 이후 같은 PDF를 앱에서 `코드·가사 악보` 프로필로 다시 변환하고, `/jobs/<id>/diagnostics`가 200인지 확인한다.

## 2026-09-28 배포 확인 및 장애 대응

최신 `server/omr` 파일을 VM 사용자 홈에 업로드한 뒤 `/omr_server.py`, `/update.sh`, `/compare_musicxml.py`로 이동하고 `sudo bash /update.sh /`를 실행했다. 외부 health는 HTTP 200이며 다음 응답을 확인했다.

```json
{"ok":true,"pipeline":"pdf-multipass-v1"}
```

`chords_lyrics` 프로필의 Job `b40ec0b42fbc47b2bc8149a40ce730de`와 diagnostics HTTP 200도 확인했다. 다만 Ditto PDF 결과는 1 part·104마디·1,302 음표이고 harmony/lyric은 각각 0개, `accuracy_verified=false`, OCR 언어는 `Audiveris default`였다. 따라서 서버 배포·프로필 라우팅은 확인됐지만 코드·가사 인식 품질은 아직 통과로 표시하지 않는다.

SSH가 한 번 접속된 뒤 `Permission denied (publickey)`로 바뀌면 서버가 중지됐다고 단정하지 말고, 웹 SSH에서 위 공개키 등록 명령을 다시 실행한 뒤 `whoami`를 재확인한다. HTTP health가 살아 있으면 API 서비스는 별도로 실행 중일 수 있다.

API 확인이 끝나면 현재 셸의 토큰 환경변수는 지운다.

```bash
unset OMR_TOKEN
```

## OCR(코드 심벌·가사) 설정 — 2026-09-28

Audiveris가 코드 심벌과 가사를 읽으려면 Tesseract 언어 데이터가 필요하다. 설정 전에는 로그에 `*** No installed OCR languages ***`가 찍히고 코드·가사가 0개였다.

- Ubuntu 패키지(`tesseract-ocr-eng`, `tesseract-ocr-kor`)의 데이터는 LSTM 전용이라 Audiveris의 legacy 모드에서 `Could not initialize TessBaseAPI languages: eng+kor in legacy mode`가 난다.
- 그래서 legacy 모델(`inttemp`)이 들어 있는 공식 `tessdata` 4.1.0 데이터를 `/opt/omr/tessdata`에 받아 쓴다(`eng`, `kor`, `osd`).
- `/etc/default/omr`(없던 파일, systemd `EnvironmentFiles`가 읽음):

```text
TESSDATA_PREFIX=/opt/omr/tessdata
OMR_OCR_LANGUAGES=eng+kor
```

- 적용: `sudo systemctl restart omr.service`. 확인: 작업 로그(`/opt/omr/jobs/<id>/out/**/*.log`)에 OCR 언어 경고가 없어야 한다.
- 되돌리기: `/etc/default/omr`를 지우고 서비스를 재시작한다. 시스템 패키지 `tesseract-ocr-kor`도 설치되어 있으나 Audiveris는 쓰지 않는다.

## Audiveris 설정 점검 — 2026-09-28

- 버전: Audiveris 5.11.0(내장 Tesseract 5.5.2). 최신 계열이라 업그레이드는 필요 없다.
- 흑백 변환(이진화): 기본값이 적응형(`ADAPTIVE`)이라 밝기가 고르지 않은 사진에 맞다. 바꾸지 않는다.
- `poorInputMode`: 5.11에서 폐기된 스위치(예전 파일 호환용). 쓸 수 없다.
- `indentations`(들여쓰기 = 새 악장): 찬양 악보는 줄 왼쪽의 A/B/C 구간 표시 때문에 들여쓴 줄로 보여 한 장이 여러 악장으로 쪼개지고, 2쪽부터 박자표가 빠져 `No target duration ... check time signatures` 경고와 마디 길이 검사 누락이 생겼다. 서버가 모든 프로필에서 `indentations=false`를 넘긴다.
- `dynamicsAboveStaff`/`dynamicsBelowStaff`: 코드·가사 프로필에서 한글 가사·코드 글자가 p·pp·mp로 오인식되어(예수 피를 힘입어 1쪽 11개, 원본 0개) 이 프로필에서만 끈다. 일반 악보 프로필은 셈여림을 계속 인식한다.
- 서버 후처리(코드·가사 프로필): 코드 줄 높이의 일반 글자 중 코드 문법에 맞는 것(`Fﬁm’l`→F♯m7, 조표로 ♯을 추정한 `Gum`→G♯m, `Aadd9`)을 코드로 바꾸고, 한 음표에 붙은 여러 글자 한글 가사를 가운데 음표 기준 연속 음표에 한 글자씩 나누고, 첫 쪽의 가장 큰 크레딧 글자를 제목으로 쓴다. 결과 파일은 `*.fixed.mxl`, 적용 횟수는 `recognition.json` 후보의 `repairs`에 남는다.
- 가사 줄 재인식(2026-09-28 추가): Audiveris는 쪽 전체를 Tesseract에 한 번에 넘긴다. 오선 아래 가사가 두 줄로 붙어 있으면 1절이 통째로 빠지거나("주의 보좌로…" 줄 없음) 깨지고, 2절은 다음 오선 위 일반 글자로 붙는다. 저장해 둔 `.omr`의 흑백 이미지와 오선·음표 머리 좌표로 오선 아래 글자 줄을 찾아 한 줄씩(`--psm 7`, 흰 여백 10px) 다시 읽고, 음표 머리 x좌표 순서대로 한 글자씩 배치한다(1절·2절 번호 유지). 음표 머리·붙임줄이 한글처럼 읽힌 줄은 한글 토큰 평균 신뢰도(가사 75~95, 잡음 약 50)로 거른다. 붙임줄 뒤 음표는 벌점을 줘 꼭 필요할 때만 쓰고, 내보내기에서 음표가 빠져 글자가 남으면 밀지 않고 남는 글자만 버린다.
- 코드 재인식: Korean이 켜져 있으면 `F♯m7`이 `태m7`처럼 한글로 읽힌다. 코드 줄의 해석되지 않은 글자는 그 상자만 영어·코드 문자로 다시 읽고(`j`/`i`/`4` → ♯, 사라진 ♯·♭은 조표), 코드 줄 전체도 같은 방식으로 읽어 Audiveris가 빠뜨린 코드(♯ 코드, `Gm⁷`처럼 작은 윗첨자 코드, `F/a`처럼 소문자 베이스)를 음표 위치에 채운다. 이미 코드가 있는 음표에는 넣지 않는다.
- 파트 합치기: 첫 줄은 `Vocal`, 다음 줄부터 `Vo.`처럼 이름이 다르면 Audiveris가 파트를 따로 만들고 없는 줄을 쉼표 마디로 채운다(날 자녀라 하시네: 3파트 × 121마디). 실제로 인쇄된 마디에만 `width`가 있으므로 마디마다 인쇄된 파트가 정확히 하나일 때만 한 파트로 합친다. 모든 프로필에 적용한다.
- 표지 쪽: 오선이 없는 쪽(표지)이 있으면 Audiveris가 책 전체 내보내기를 거부한다(`Could not export since transcription did not complete successfully`). 저장된 `.omr`에서 유효한 쪽만 `-sheets 2-9`로 다시 내보낸다(약 18초). 건너뛴 쪽은 `skipped_sheets`에 남는다.
- 서버 패키지: 재인식에 `tesseract-ocr`(이미 설치됨), `python3-pil`(2026-09-28 설치)을 쓴다. `install.sh`에 추가했다. 한국어 데이터가 보조 언어로 `chi_tra`를 찾는 경고가 로그에 남지만 인식에는 영향이 없다.


## HTTPS와 설치본 등록 (R-2, 2026-10-03 배포)

서버는 설치본 등록(`POST /clients`)·하루 한도·작업 소유 확인을 한다(`omr_clients.py`). 2026-10-03에 한 일과 지금 상태:

- 방화벽: 사용자가 콘솔에서 HTTP·HTTPS 허용.
- `update.sh`로 새 서버 배포. 그 전 파일은 VM `~/omr_backup_20261003/`(저장소 커밋 `846c21d`의 서버 파일과 같음).
- `sudo KEEP_HTTP=1 bash enable_https.sh 34-10-15-222.sslip.io` → Caddy 2.6.2(Ubuntu 패키지) 설치, 인증서 발급. 이어서 `/etc/default/omr`에 `OMR_TOKEN=<새 값>`, `OMR_LEGACY_TOKEN=0`, `OMR_HOST=127.0.0.1`을 넣고 재시작(그 전 파일은 `/etc/default/omr.bak-20261003`, 권한 600).
- 등록 정보·하루 카운터: `/opt/omr/state/clients.json`, `/opt/omr/state/quota.json`.
- 확인: `curl https://34-10-15-222.sslip.io/health` 200, `http://34.10.15.222:8080`은 밖에서 닫힘, 예전 키 401.
- 설치 때 "새 커널을 쓰려면 재부팅" 안내가 나왔다. 재부팅하지 않았다.

VM 주소가 바뀌면 sslip.io 이름도 바뀐다: `sudo bash enable_https.sh <새 이름>`을 다시 실행하고 `dart_defines.local.json`의 `OMR_BASE_URL`과 `OmrConvertConfig.defaultBaseUrl`을 고친다. 도메인을 쓰면 이 일이 없다.

### 빌드용 앱 키 파일

저장소 루트에 `dart_defines.local.json`이 있어야 변환이 되는 앱이 빌드된다(없으면 자리 표시 키로 401). 값을 화면에 찍지 않고 만든다:

```bash
ssh -i ~/.ssh/<키> hanso3366@34.10.15.222 'sudo grep ^OMR_TOKEN= /etc/default/omr | cut -d= -f2' | \
  python3 -c "import sys,json; json.dump({'OMR_BASE_URL':'https://34-10-15-222.sslip.io','OMR_TOKEN':sys.stdin.read().strip()}, open('dart_defines.local.json','w'), indent=2)"
flutter build apk --release --flavor piano -t lib/piano_main.dart \
  --dart-define-from-file=dart_defines.json --dart-define-from-file=dart_defines.local.json
```

### 서버 코드를 다시 올릴 때

`server/omr/`의 `omr_server.py`, `omr_*.py` 전부(`omr_clients.py` 포함), `ai_verify.py`, `update.sh`를 VM의 한 폴더에 올리고 `sudo bash update.sh <그 폴더>`. Windows에서 올릴 때는 줄바꿈이 LF인지 확인한다(작업 폴더의 `.py`는 CRLF일 수 있다 — `tr -d '\r'`로 걸러 올렸다). health 주소는 VM 안에서 여전히 `http://127.0.0.1:8080/health`다.

한도 조정(`/etc/default/omr`, 하루·UTC): `OMR_CONVERT_PER_CLIENT`(30), `OMR_CONVERT_PER_ADDRESS`(60), `OMR_CONVERT_PER_DAY`(500), `OMR_AI_PER_CLIENT`(60), `OMR_AI_PER_ADDRESS`(120), `OMR_AI_PER_DAY`(1000), `OMR_REGISTER_PER_ADDRESS`(10), `OMR_REGISTER_PER_DAY`(500). 바꾼 뒤 `sudo systemctl restart omr.service`.

