# 변환 정확도 측정 (출시 준비 4단계, R-5)

`score_sample/`의 악보 17곡을 실제 서버로 변환해, 원본을 눈으로 읽어 만든 정답지와
마디 단위로 비교한다. 서버 규칙을 고칠 때마다 같은 곡으로 다시 재서 좋아졌는지,
나빠진 곳은 없는지 본다.

사진, 정답지, 변환 결과는 `score_sample/_accuracy/`에 둔다. 가사 전문이 들어 있어
`score_sample/`과 마찬가지로 커밋하지 않는다(다른 곳에 두려면 `ACCURACY_DATA`).

## 순서

```bash
# 1. 곡마다 앱과 같은 방식으로 PDF를 만든다 (pdf/)
flutter test tool/accuracy/make_pdfs_test.dart
# 2. 원본을 줄 단위로 자른다 (lines/) — 정답지를 만들거나 차이를 눈으로 확인할 때 쓴다
python3 tool/accuracy/crop.py
# 3. 서버로 변환하고 원본 OMR·자동 보정·AI 보정 세 버전을 받는다 (out<이름>/)
#    dart_defines.local.json이 있어야 한다(docs/OMR_SERVER_ACCESS.md). 키는 출력하지 않는다.
SSL_CERT_FILE=/etc/ssl/cert.pem python3 tool/accuracy/convert.py 2
# 4. 채점한다 (scores<이름>.json). 서버 모듈을 불러 쓰므로 Pillow가 있는 파이썬으로 돈다.
RUN=2 python3 tool/accuracy/score.py ai
# 차이 난 줄을 원본에서 확인
python3 tool/accuracy/stack.py /tmp/check.png s06_living_lord/p1-s01 s06_living_lord/p1-s02
```

곡 목록은 `songs.json`(곡 이름 → `score_sample/`의 쪽 파일들)이다. 실행 이름은 결과를
분리할 뿐 설치본을 새로 만들지 않는다. QA 설치본 secret은 기본적으로 저장소 밖
`~/.cache/piano-score-qa/omr-client`(파일 0600)에 한 번만 등록하고 재사용한다.
`--client-file`로 저장소 밖의 기존 파일을 지정할 수 있다. 설치본당 하루 30회 한도나
전체 한도에 도달하면 멈추며, 새 설치본 등록으로 한도를 회피하지 않는다.
일부 곡만 새로 변환하려면 `--songs s17_way_of_life s07_perfect`처럼 지정한다.

## 정답지

`truth/<곡>.json`. 줄(잘라 낸 그림)마다 마디별로 코드, 가사(절별 음절), 음표가 시작하는
횟수, 도돌이·엔딩·D.S. 같은 기호, 구간 이름을 적는다. 읽는 규칙은 `READING.md`다.
변환 결과를 보지 않고 원본만 읽어 만든다(결과를 보면 결과 쪽으로 끌려간다). 색으로
쓴 필기는 악보가 아니므로 적지 않는다.

정답지도 틀릴 수 있다. 채점에서 차이가 나면 `stack.py`로 그 줄을 보고 어느 쪽이
맞는지 가린다. 2026-10-06에는 다섯 곡의 차이 20여 건을 대조해 모두 정답지가 맞았다.

## 채점

- 줄을 먼저 맞추고 그 안의 마디를 맞춘다. 한 줄이 빠지거나 두 마디가 하나로 합쳐져도
  뒤 마디가 밀리지 않는다.
- 코드는 표기를 맞춰 비교한다(`CM7`=`Cmaj7`, `D(sus4)`=`Dsus4`, `F/a`=`F/A`).
- 가사는 줄 긋는 표시와 절 번호를 빼고 음절 단위 편집 거리로 센다. 절 번호가 바뀐
  줄은 맞는 줄끼리 맞춘다.
- `exact`는 코드·가사·음표 수·기호가 모두 맞는 마디의 비율이다.
- `wrong`에는 틀린 마디마다 검토 화면이 그 마디를 가리키는지(`flagged`)를 적는다.

음높이와 음 길이는 재지 않는다(음표 수만 본다).

## 95% 목표와 재현 가능한 회귀 검사 (2026-10-06)

사용자 목표는 같은 마디 완전 일치 지표 최소 95%다. 766마디라면 최소 728마디가
맞아야 한다. 음높이·음가는 이 숫자에 포함되지 않으므로, 독립 표본과 사람이 검증한
음높이·음가 정답 대조 전에는 출시 정확도 95%라고 표시하지 않는다.

AI 실행 간 차이를 제거하고 적용 코드만 비교하려면 기존 응답을 고정해 재생한다:

```bash
python3 tool/accuracy/replay_ai.py --fetch --source-run 2 --run 3
RUN=3 python3 tool/accuracy/score.py ai
python3 tool/accuracy/gate.py score_sample/_accuracy/scores3.json
python3 -m unittest discover -s tool/accuracy -p 'test_*.py'
```

`--fetch`는 문서에 지정된 SSH 키로 기존 작업의 dataset·answers만 받아
`ai_cache2/`에 둔다. 새 AI 호출·변환은 하지 않고 원본 `out2`와 정답지를 바꾸지
않는다. 새 실행 폴더가 이미 있으면 덮어쓰지 않는다. 키·API 토큰은 출력하지 않는다.
실행 결과에는 기존 AI 버전에서 맞던 마디가 틀려진 `regressed_bars`도 기록한다.

3차는 **응답 고정 재생**이며 새로운 종단간 서버 변환 측정이 아니다. 결과:
500/766(65.3%) → 512/766(66.8%), 코드 91.4% → 92.1%, 가사 87.0% 그대로.
이 변경 때문에 기존 정답 마디가 틀려진 것은 0개다(전체 AI의 오수정률 0이라는 뜻은 아님).
`gate.py`는 목표 미달·누락 곡·미측정 음높이/음가를 숨기지 않고 실패(exit 1)한다.
현재 목표까지 최소 216마디가 더 맞아야 한다. 먼저 합쳐진 44마디와 음표 수 오류
134마디, 가사 배치, 도돌이·엔딩을 원본과 대조한다. 성공한 곡만 골라 평균을 내지 않는다.

## 음표 내보내기 누락 복원 (2026-10-06)

원본 OMR book의 기호는 읽혔으나 voice/slot 계산 실패로 내보내지 못한 음표가 있다.
한 보표·한 멜로디 성부, 명시적인 head/stem/beam/rest/dot/pitch, 마디 음가 합계와
이미 내보낸 모든 음표의 음높이·음가가 일치할 때만 별도 자동 보정본으로 복원한다.
다성부·큐·잇단음표·음높이/음가 불일치·낮은 확신도·해석 불가능한 기호는 건너뛴다.
박자표는 음가 합계로 추측하지 않는다. 빠진 4/4는 같은 쪽의 확정된 4 두 개와
원본 픽셀을 각각 0.92 이상 대조한 경우만 복원한다. 원본 MXL/book은 보존하고
rhythm/time 이력 및 인식 기호 ID를 기록한다.

```bash
python3 tool/accuracy/replay_rhythm.py --fetch --run 5
RUN=5 python3 tool/accuracy/score.py ai
python3 tool/accuracy/gate.py score_sample/_accuracy/scores5.json
```

5차도 **book·AI 응답 고정 재생**이다. 17곡 766마디 전체에서 512→519 완전 일치
(66.8→67.8%), 음표 수 오류 134→121, 가사 오류 366→341/2821(87.0→87.9%),
기존 정답 추가 회귀 0. s17의 13마디에서 복원했으며 완전 일치 7→14/37이다.
붙임줄의 성부 번호 불연속도 단선 멜로디에 한해 통일했다. 하나의 원본 마디에서
10음표의 음높이·음가를 대조했지만 전체 음높이/음가 검증을 대체하지 않는다.
합쳐진 44마디는 그대로다. 최소 209마디 추가 정답이 필요하며 95% 게이트는 실패한다.
증거: `rhythm-report-5.json`, `scores5.json`, `out5/`, `books2/`(모두 비공개·gitignore).
현재 replay 도구는 복원 후 Validator도 다시 계산하며 예전 진단/검증은
`source_diagnostics.json`·`source_validation.json`으로 보존한다. 예전 out5는 기준
Validator를 복사했으므로 검토 화면 탐지율에는 쓰지 않는다. 이 문제를 정정한 out7도
같은 519/766·추가 회귀 0이며 `scores7.json`·`rhythm-report-7.json`이 최신 증거다.
새 실변환 `live5`/`live6`는 캐시 재생과 합산하지 않고 별도 기록한다.

## 독립 표본 (`holdout.json`)

17곡에 맞춰 규칙을 고치면 그 17곡에서만 좋아질 수 있다. 고칠 때 쓰지 않은 곡을 따로 두고
같은 방식으로 잰다. 데이터는 `score_sample/_accuracy/holdout/`(줄 그림, 정답지, 결과).

```bash
ACCURACY_DATA=$PWD/score_sample/_accuracy/holdout SSL_CERT_FILE=/etc/ssl/cert.pem \
  python3 tool/accuracy/convert.py h1 --songs-file tool/accuracy/holdout.json
ACCURACY_DATA=$PWD/score_sample/_accuracy/holdout RUN=h1 python3 tool/accuracy/score.py ai
```

정답지에 `"partial": true`가 있으면 그 곡은 앞쪽 줄만 채점한다(긴 악보의 앞 두 쪽만 읽은 경우).

2026-10-06 첫 실행에서 "글자가 적힌 괄호는 엔딩이 아니다"라는 규칙이 "Repeat Vs." /
"Go to Ch."라고 적힌 진짜 엔딩을 지우는 것을 이 표본이 잡았다. 17곡에서는 보이지 않던 문제다.
지금 표본 3곡은 이전 개발에서 본 곡이라 완전히 새 악보가 아니다. 새 악보가 생기면 바꾼다.

