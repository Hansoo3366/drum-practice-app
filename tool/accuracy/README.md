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

## 다른 음표 판독기와 견주기 (2026-10-11)

`score_notes.py`는 정답지에서 코드와 가사를 빼고 **마디와 마디별 음표 수**만으로 채점한다.
코드·가사를 읽지 못하는 판독기(공개 OMR 모델)를 서버 결과와 같은 잣대로 재기 위한 것이다.

```bash
# 서버 결과(out5의 ai 버전)와, 다른 판독기가 쪽 사진마다 쓴 MusicXML(<폴더>/<곡>/p<N>.musicxml)
python3 tool/accuracy/score_notes.py audiveris=mxl:5/ai homr=pages:/path/to/homr/pages
# 줄 그림(lines/<곡>/pP-sNN.png)마다 돌린 결과는 lines:<폴더>
# 독립 표본은 ACCURACY_DATA=score_sample/_accuracy/holdout 로 정답지 폴더를 바꾼다
```

판독기 둘 이상이면 마디별로 둘 다 맞음·한쪽만 맞음·둘 다 틀림도 센다(두 번째 판독기를
검산용으로 쓸 때의 값어치). 음높이와 음 길이는 정답지에 없어 여기서도 재지 않는다.

2026-10-11 측정(17곡 766마디, 마디를 찾았고 음표 수가 맞은 비율):
서버(Audiveris+규칙+AI) 614마디 80.2%, 합쳐진 마디 46 · homr 0.7.0을 쪽 사진에 그대로
돌린 것 753마디 98.3%, 합쳐진 마디 0. 독립 표본 2곡 65마디는 95.4% 대 96.9%.
homr는 코드·가사·도돌이표를 읽지 않으므로 음표 판독만의 비교다.

## 피아노 악보 (2026-10-11)

`score_piano.py`는 정답 MusicXML이 있는 피아노 악보를 음표 단위로 채점한다: 마디 안의 자리,
음높이, 길이(보표·성부는 구분하지 않고, 꾸밈음·쉼표는 뺀다). 마디는 순서대로 맞춘다.

```bash
# 자료는 score_sample/_accuracy/piano/ (pdf/<곡>.pdf, truth/<곡>.musicxml, songs.json)
ACCURACY_DATA=score_sample/_accuracy/piano SSL_CERT_FILE=/etc/ssl/cert.pem \
  python3 tool/accuracy/convert.py p1 --profile standard --songs-file score_sample/_accuracy/piano/songs.json
ACCURACY_DATA=score_sample/_accuracy/piano \
  python3 tool/accuracy/score_piano.py server=mxl:p1/fixed homr=pages:/path/to/homr/piano
```

정답지는 앱이 조판해 내보낸 PDF와 그 원본 MusicXML의 쌍이다(같은 버전에서 PDF와 MusicXML을
함께 내보낸다). 2026-10-11 측정: 2곡 210마디에서 마디가 통째로 맞은 비율은 서버 22.9%,
homr 20.0%. 두 곡 모두 어려운 고전곡이라, 보통 난이도의 정답지를 더 만들어야 한다.

## 음표는 homr, 코드·가사는 서버 (2026-10-12)

서버 후처리 안에서 두 판독기를 합친다(`server/omr/omr_hybrid.py`, `OMR_HYBRID_NOTES=1`일 때만).
줄마다 homr가 읽은 마디·음표로 바꾸고, 각 음표에 쪽 위의 가로 위치를 준 뒤, 서버가 하던 코드 줄·
가사 줄 다시 읽기를 그 음표 위에서 그대로 돌린다. 줄이 맞지 않으면 그 줄만 엔진 결과로 둔다.

`replay_post.py`는 변환 때 엔진이 남긴 자료(`out<실행>/<곡>/raw.mxl`, `books2/<곡>/<후보>/score.omr`,
`pdf/<곡>.pdf`)로 서버 후처리(`_postprocess`)만 이 컴퓨터에서 다시 돌려 `out<새 실행>/`에 쓴다.
변환도 AI 호출도 하지 않으므로 나온 것은 서버의 **`fixed` 단계**다. 이어서 검증(`validation.json`,
`layout.json`)과 AI 검토에 보낼 줄 그림·설명(`ai/crops`, `ai/dataset.json`)까지 만들어, 바뀐 마디가
뒤 단계와 맞물리는지 본다.

```bash
# tessdata 4.1.0의 kor·eng(서버와 같은 것)을 받아 둔 폴더가 필요하다.
export TESSDATA_PREFIX=/path/to/tessdata
# 서버만: 스위치를 끄면 결과가 기존과 바이트 단위로 같다(17곡 확인).
python3 tool/accuracy/replay_post.py 5 r2
# 분업: homr가 미리 읽어 둔 결과(<곡>/p<N>.musicxml, p<N>.json)를 쓰거나,
OMR_HYBRID_NOTES=1 HOMR_READ=/path/to/homr/read python3 tool/accuracy/replay_post.py 5 h10
# 서버가 하듯 homr를 직접 부른다(OMR_HOMR_PYTHON=homr를 설치한 파이썬).
OMR_HYBRID_NOTES=1 OMR_HOMR_PYTHON=/path/to/venv/bin/python python3 tool/accuracy/replay_post.py 5 h11
RUN=h10 python3 tool/accuracy/score.py fixed
```

2026-10-12 측정(17곡 766마디, **AI 검토 전 `fixed` 단계끼리** 비교, homr 0.7.0을 프로세서만으로 실행):

| | 서버만 | 분업 |
|---|---|---|
| 찾은 마디 | 743/766 | 763/766 |
| 합쳐 읽은 마디 | 44 | 0 |
| 마디별 음표 수 | 83.6% | 98.3% |
| 가사 | 81.7% | 88.1% |
| 코드 | 63.3% | 67.5% |
| 도돌이·엔딩 등 | 72.5% | 72.3% |
| 마디 완전 일치 | 38.1% | 46.5% |

곡별로 완전 일치·코드·음표 수가 내려간 곡은 없다(가사 s08 −0.5, 기호 s07 −33은 있음). 17곡 211줄이
모두 homr 줄로 바뀌었고, 결과는 모두 쪽 그림과 묶였다. **AI 검토 뒤 최종 수치(기준 67.8%)는 이
컴퓨터에 AI 키가 없어 재생으로는 재지 못한다.** 서버에 올려 `convert.py`로 다시 변환해 잰다(아래).

**서버 실변환(2026-10-12, `convert.py hy1`, AI 검토 포함)**: 17곡 완전 일치 519 → 636/766
(67.8% → **83.0%**), 음표 수 98.3%, 가사 87.9% → 94.8%, 코드 92.1% → 94.4%, 기호 72.5% → 74.2%,
합쳐 읽은 마디 0. 15곡 상승, 1곡 동일, 1곡 하락(s11 한 마디). 독립 표본 3곡은 86.8% → 87.9%
(두 파트 악보 한 곡은 분업 대상이 아니어서 동일). 증거: `outhy1/`, `scoreshy1.json`,
`holdout/outhy1/`(비공개). AI가 고칠 것이 없으면 서버는 `ai.mxl`을 만들지 않으므로, 그런 곡은
`fixed.mxl`을 `ai.mxl`로 복사해 채점한다(이번에는 s13). 95%까지 92마디가 더 맞아야 한다.

음높이·음가는 이 정답지로 재지 않는다. 두 판독기가 음표 수가 같은 587마디에서 음높이가 같은 마디는
78.2%이고, 다른 것의 대부분은 엔진이 조표를 잘못 읽은 한 곡(s01, 실제 6플랫을 2플랫으로)이다.
homr는 조표·음자리표를 줄마다 새로 읽어 한 줄씩 틀리는 일이 있어(17곡에서 조표 2줄, 음자리표 2줄,
박자표 3개), 이웃 줄과 다른 한 줄은 이웃을 따르게 고친다.

## AI 검토 적용만 다시 해 보기 (2026-10-12)

`replay_review.py <원본 실행> <새 실행>`은 변환 때 내려받은 `ai_review.json`의 제안을 `fixed.mxl`에
이 컴퓨터의 서버 코드로 다시 적용해 `out<새 실행>/`에 쓴다. AI를 부르지 않으므로, 제안을 **적용하는
규칙**(`omr_ai._apply_ai_measure`)을 바꿨을 때의 효과만 잰다. 코드를 바꾸기 전에 원본 실행의 점수가
그대로 나오는지 먼저 확인한다.

```bash
python3 tool/accuracy/replay_review.py hy1 rv2
RUN=rv2 python3 tool/accuracy/score.py ai
```

2026-10-12: 붙임줄로 이어 받은 첫 음을 "-"로 적은 가사 제안을 받게 고쳐 83.0% → 85.9%, 가사 94.8% → 95.9%.

`--review-from <실행>`을 주면 그 실행의 AI 응답을 `<원본 실행>`의 규칙 보정본에 적용한다(AI 앞 규칙을
바꿨을 때. 줄이 늘거나 줄었으면 줄의 마디 수로 줄을 맞춰 마디 번호를 옮긴다). 로컬 기준선은 변경 전
코드로 같은 자료를 재생한 실행에 같은 응답을 적용한 것으로 둔다. 옛 응답을 다시 적용하므로 바뀐
마디의 득은 거의 안 잡히고 옛 답이 안 맞게 된 곳은 손해로 잡힌다: 상대 비교로만 쓰고, 실제 값은
서버 실변환으로 잰다.

2026-10-12 오후: 8가지 수정(작업 로그 참조) 로컬 재생 — 규칙 단계 완전 일치 46.5% → 50.5%, 찾은 마디
766/766, 빠진·늘어난 마디 0, AI 재적용 뒤 80.5% → 81.5%. 증거 `outh10`(기준 규칙 단계), `outrvb`,
`outh19`, `outrv8`(비공개).

## 정답지 수정 이력

- 2026-10-12: `s17_way_of_life` — 색으로 인쇄된 진행 기호 3마디 추가(`ds`, `to-coda`, `coda`). 원본은
  `truth_before_20261012/`. 이 날 이전의 수치는 고치기 전 정답지 기준이다(지금 서버 실변환 83.0% →
  고친 기준 83.3%, 분업 전 67.8% → 67.9%).
