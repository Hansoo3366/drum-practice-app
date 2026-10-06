# PDF Score Digitization System Specification

## 0. Document Purpose

본 문서는 스캔된 PDF 악보를 MusicXML/MXL 전자악보로 변환하고, OMR 오류를 AI로 검수하며, 단선율 악보에 코드 및 반주를 자동 추천하는 시스템의 구현 명세이다.

2026-10-06 제품 범위 변경: 이 문서의 코드·화성·편곡 생성은 사용자가 선택한 한 악기의 악보 버전 한 개를 만드는 기능이다. 별도 재생 반주 메뉴와 재생 시 자동 반주 추가는 삭제한다. 여러 악기의 동시 생성·통합 출력 선택을 제공하지 않으며, 원본과 기존 악보 버전은 보존한다.

본 문서는 다음 개발 AI가 직접 읽고 구현 작업을 수행할 수 있도록 작성한다.

- Codex
- Cursor
- Claude Code
- 기타 coding agent

핵심 설계 원칙:

1. AI가 전체 악보를 처음부터 생성하지 않는다.
2. 결정론적으로 처리 가능한 부분은 일반 알고리즘으로 처리한다.
3. AI는 불확실하거나 문맥 판단이 필요한 영역에만 사용한다.
4. 모든 AI 수정은 원본 데이터와 분리하여 기록한다.
5. AI의 잘못된 자동 수정(False Correction)을 최소화한다.
6. 각 처리 단계는 독립 모듈로 구현한다.

---

# 1. Primary Goals

시스템의 주요 목표는 다음과 같다.

## G1. PDF → MXL

입력:

```text
scanned_score.pdf
```

출력:

```text
score.mxl
```

지원 대상:

- 스캔 PDF
- 이미지 기반 PDF
- 일반 인쇄 악보
- 필기가 포함된 악보
- 단선율 악보
- 피아노 악보
- 보컬 + 피아노 악보

---

## G2. OMR Error Detection

OMR 결과 MusicXML을 분석하여 오류 가능성이 높은 마디 및 요소를 찾는다.

예:

```text
4/4 measure
detected duration = 3.5 beats
```

결과:

```json
{
  "measure": 18,
  "errorType": "duration_mismatch"
}
```

---

## G3. AI Error Verification

오류 후보만 Vision AI에 전달한다.

비교 대상 모델:

```text
Qwen3-VL-Flash
GPT-5.6 Luna
Gemini Flash-Lite
GPT-5.6 Terra
```

동일한 테스트 데이터에 대해 정확도, 비용, 지연시간 등을 비교한다.

---

## G4. Annotation Handling

악보 위에 사람이 작성한 필기를 탐지하고 OMR 입력에서 분리한다.

필기 예:

```text
Verse x2

여기 반복

작게

손가락 번호

화살표

동그라미

형광펜

연필 메모
```

원본 이미지는 절대 삭제하지 않는다.

---

## G5. Melody Harmonization

멜로디만 존재하는 MXL에 대해 다음 정보를 생성한다.

```text
Key
Chord Progression
Bass
Accompaniment
```

---

# 2. Non-Goals

초기 버전에서 다음 기능은 필수가 아니다.

```text
완벽한 손글씨 악보 인식
100% 자동 변환
오케스트라 총보 완전 지원
AI 단독 PDF → MusicXML 생성
DAW 수준의 MIDI 편곡
전문 작곡가 수준의 자동 편곡
```

---

# 3. High-Level Architecture

```text
PDF
 ↓
PDF Renderer
 ↓
Page Images
 ↓
Image Preprocessor
 ↓
Annotation Detector
 ↓
Clean Score Image
 ↓
OMR Engine
 ↓
MusicXML
 ↓
MusicXML Validator
 ↓
Suspicious Element Detection
 ↓
AI Verification
 ↓
Correction Engine
 ↓
Verified MusicXML
 ↓
MXL Export
```

선택적 후처리:

```text
Verified MusicXML
 ↓
Melody Analysis
 ↓
Chord Generation
 ↓
AI Harmony Selection
 ↓
Accompaniment Generation
 ↓
New MusicXML
 ↓
MXL
```

---

# 4. Module Definition

## MODULE-01: PDF Renderer

### Input

```text
PDF file
```

### Output

페이지별 이미지:

```text
page_001.png
page_002.png
page_003.png
```

### Recommended Resolution

```text
300 DPI minimum
400~600 DPI preferred
```

### Requirements

- PDF 페이지 비율 유지
- 해상도 정보 저장
- page index 유지

---

# 5. MODULE-02: Image Preprocessor

목적:

OMR 정확도를 높이기 위한 이미지 정규화.

### Processing

```text
deskew
perspective correction
contrast normalization
noise reduction
binarization
staff enhancement
```

### Input

```text
page image
```

### Output

```text
normalized page image
```

원본 이미지는 별도로 보존한다.

---

# 6. MODULE-03: Annotation Detector

## Purpose

인쇄 악보와 사용자 필기를 가능한 범위에서 분리한다.

### Annotation Types

```text
handwriting
circle
arrow
highlight
finger number
text memo
manual chord
manual slur
manual marking
```

---

## Color Annotation

다음과 같은 필기는 비교적 쉽게 탐지 가능하다.

```text
red pen
blue pen
highlighter
```

처리 방법:

```text
RGB / HSV segmentation
```

가능하면 AI를 호출하지 않는다.

---

## Black Annotation

다음은 난도가 높다.

```text
pencil
black ballpoint pen
black marker
```

이 경우 다음 특징을 이용한다.

```text
stroke shape
printed glyph consistency
staff relationship
font consistency
local context
vision model
```

---

## Output

두 종류의 mask를 생성한다.

```text
printed_score_mask
annotation_mask
```

그리고 다음 이미지를 생성한다.

```text
original.png
clean_score.png
annotation.png
```

---

## Important Rule

필기가 음표 자체를 가리고 있는 경우:

```text
DO NOT reconstruct hidden notes automatically with high confidence.
```

대신:

```json
{
  "status": "uncertain",
  "reason": "annotation_occlusion"
}
```

으로 기록한다.

---

# 7. MODULE-04: OMR

초기 OMR 후보:

```text
Audiveris
```

### Input

```text
clean_score.png
```

### Output

```text
MusicXML
```

또는

```text
MXL
```

---

## Required Recognition Elements

```text
staff
clef
key signature
time signature
note
rest
duration
beam
accidental
tie
slur
tuplet
voice
measure
repeat
ending
lyrics
chord symbol
D.C.
D.S.
Coda
Fine
```

---

# 8. MODULE-05: MusicXML Validator

AI 호출 전에 반드시 실행한다.

목적:

일반 프로그램 로직으로 찾을 수 있는 오류를 탐지한다.

---

## Validation Rules

### V001 Measure Duration

예:

```text
time signature = 4/4
expected = 4 beats
detected = 3.5 beats
```

결과:

```json
{
  "rule": "V001",
  "severity": "high",
  "measure": 23
}
```

---

### V002 Voice Duration

각 Voice의 duration 합계를 검증한다.

---

### V003 Tie Validation

```text
tie-start exists
tie-stop missing
```

검출.

---

### V004 Tuplet Validation

```text
3:2
5:4
7:4
```

등 ratio와 실제 duration을 검증한다.

---

### V005 Beam Validation

비정상적인 beam group 탐지.

---

### V006 Pitch Outlier

주변 음역과 비교해 매우 비정상적인 pitch를 후보로 표시한다.

자동 수정하지 않는다.

---

### V007 Empty Measure

이미지에는 음표가 있는데 MusicXML 마디가 비어 있는 경우 후보 처리.

---

### V008 Key / Accidental Consistency

조표 및 임시표 관계 검사.

---

# 9. Suspicious Region Extraction

Validator가 오류를 감지하면 해당 요소 주변의 원본 이미지를 crop한다.

### Preferred Input Region

기본:

```text
previous measure
current measure
next measure
```

복잡한 경우:

```text
full system
```

페이지 전체 이미지를 기본 AI 입력으로 사용하지 않는다.

---

# 10. MODULE-06: AI Verification

## Model Candidates

동일 데이터셋에 아래 모델을 테스트한다.

```text
Qwen3-VL-Flash
GPT-5.6 Luna
Gemini Flash-Lite
GPT-5.6 Terra
```

---

# 11. AI Input

AI에는 다음 데이터를 제공한다.

```text
1. cropped score image
2. current MusicXML representation
3. time signature
4. key signature
5. validation error
6. previous measure information
7. next measure information
```

---

## Example

```text
TIME_SIGNATURE:
4/4

KEY:
D Major

VALIDATION_ERROR:
measure_duration_mismatch

CURRENT_MEASURE:

note1 = D4 quarter
note2 = F#4 quarter
note3 = A4 quarter
note4 = B4 eighth

EXPECTED_DURATION:
4

CURRENT_DURATION:
3.5
```

AI task:

```text
Inspect the score image.

Determine whether any recognized element is incorrect.

Do not rewrite the entire measure.

Only return corrections for elements that can be visually verified.
```

---

# 12. AI Output Schema

AI 출력은 반드시 구조화된 데이터로 받는다.

```json
{
  "hasError": true,
  "corrections": [
    {
      "elementId": "note_4",
      "property": "duration",
      "currentValue": "eighth",
      "suggestedValue": "quarter",
      "confidence": 0.97
    }
  ],
  "overallConfidence": 0.95
}
```

---

## Allowed Error Types

```text
pitch
duration
accidental
rest
beam
tie
slur
tuplet
voice
clef
key_signature
time_signature
measure
repeat
unknown
```

---

# 13. AI Safety Rule

AI가 새로운 악보를 자유롭게 생성하지 못하게 한다.

금지:

```text
rewrite entire MusicXML
guess invisible notes
invent missing measures
change unrelated elements
```

허용:

```text
identify incorrect element
suggest property correction
report uncertainty
```

---

# 14. Confidence Policy

초기 기준값:

```text
confidence >= 0.95
    → automatic correction candidate

0.75 <= confidence < 0.95
    → user review recommended

confidence < 0.75
    → escalate or manual review
```

실제 threshold는 테스트 데이터 결과를 보고 조정한다.

---

# 15. Multi-Model Evaluation

## Dataset

최소:

```text
200 error regions
```

권장:

```text
500+
```

---

## Dataset Categories

```text
single melody
piano
vocal + piano
CCM
pop
dense 16th notes
tuplet
multi voice
tie-heavy
slur-heavy
complex key
low-quality scan
handwritten annotation
colored annotation
pencil annotation
```

---

# 16. Ground Truth

각 테스트 샘플에 사람이 정답 데이터를 기록한다.

예:

```json
{
  "sampleId": "test_0012",
  "measure": 17,
  "errorType": "duration",
  "target": "note_4",
  "correctValue": "quarter"
}
```

---

# 17. Evaluation Metrics

## 2026-10-06 사용자 정확도 목표

- 최소 목표는 기존 17곡 766마디의 코드·가사·음표 수·기호 **마디 완전 일치 95%**다(728마디 이상). 요소별 정확도 평균이나 일부 성공 곡으로 대신하지 않는다.
- 이 지표는 음높이·음가 정확도가 아니다. 사람이 검증한 음높이·음가 정답과 독립 표본을 추가로 대조하기 전에는 제품의 악보 정확도가 95%라고 표시하지 않는다.
- 적용 알고리즘 변경은 입력·정답지·AI 응답을 고정한 회귀 검사와 별도 최신 서버 실변환으로 나눠 검증한다. 원래 맞던 마디가 틀려진 수와 False Correction을 따로 기록한다.
- 목표 미달이면 완료·출시 가능으로 표시하지 않는다. 음표를 추측해 채우거나 자동 승인 범위를 넓혀 지표를 올리지 않는다.
- 합쳐진 마디·음표 누락·가사 배치·반복 기호를 우선 개선한다. 불확실한 음표 변경은 기존대로 사람 승인 및 별도 버전 저장을 유지한다.

각 모델마다 다음 값을 측정한다.

```text
Detection Accuracy
Correction Accuracy
False Correction Rate
False Negative Rate
Confidence Calibration
Structured Output Success Rate
Latency
Input Cost
Output Cost
Cost per Corrected Measure
```

---

## Highest Priority Metric

```text
False Correction Rate
```

정상 악보를 잘못 변경하는 것이 오류를 못 고치는 것보다 위험하다.

---

# 18. Model Selection Strategy

테스트 후 두 방식 중 하나를 선택한다.

### Strategy A

단일 모델 사용.

```text
Validator
 ↓
Best Cost/Accuracy Model
```

---

### Strategy B

다단계 모델 사용.

```text
Validator
 ↓
Cheap Vision Model
 ↓
Low Confidence
 ↓
Higher Capability Model
 ↓
Manual Review
```

예:

```text
Qwen3-VL-Flash
        ↓
GPT-5.6 Luna
        ↓
GPT-5.6 Terra
```

단, 실제 모델 순서는 benchmark 결과를 기준으로 결정한다.

미리 특정 모델을 우승 모델로 가정하지 않는다.

---

# 19. Correction History

AI 수정은 직접 원본 데이터를 덮어쓰지 않는다.

각 변경사항을 저장한다.

```json
{
  "measure": 23,
  "element": "note_4",
  "before": "eighth",
  "after": "quarter",
  "source": "GPT-5.6-Luna",
  "confidence": 0.97
}
```

사용자가 언제든 수정 전 상태로 되돌릴 수 있어야 한다.

---

# 20. Annotation Preservation

필기를 제거한 Clean Score와 별개로 원본 annotation 정보를 보존한다.

예:

```json
{
  "page": 2,
  "region": {
    "x": 420,
    "y": 280,
    "width": 150,
    "height": 80
  },
  "type": "handwriting",
  "text": "Verse x2"
}
```

OCR 결과가 불확실한 경우:

```text
text = null
```

로 저장한다.

---

# 21. Musical Annotation Interpretation

후기 버전에서는 다음 필기를 의미 데이터로 변환할 수 있다.

예:

```text
Verse x2
Chorus x4
Repeat
여기부터 작게
Crescendo
```

결과:

```json
{
  "measure": 32,
  "instruction": "repeat_section",
  "section": "verse",
  "count": 2
}
```

---

# 22. Melody-Only Score Detection

전자악보 변환 완료 후 악보 구조를 분석한다.

단선율로 판단할 수 있는 조건 예:

```text
single staff
mostly one voice
no chord accompaniment
monophonic dominant structure
```

판단 결과:

```json
{
  "scoreType": "melody_only"
}
```

---

# 23. Key Detection

멜로디 데이터를 이용하여 조성을 분석한다.

Input:

```text
pitch
duration
measure position
accidental
cadence
```

Output:

```json
{
  "key": "C",
  "mode": "major",
  "confidence": 0.91
}
```

---

# 24. Chord Candidate Generation

AI가 처음부터 코드 진행을 만드는 것을 기본 방식으로 사용하지 않는다.

먼저 음악 이론 기반 엔진으로 후보를 생성한다.

고려 요소:

```text
key
scale
strong beat notes
long notes
melody note
phrase
cadence
previous chord
next chord
functional harmony
bass motion
```

---

## Example

Melody:

```text
G B D F
```

Key:

```text
C Major
```

Candidates:

```text
G
G7
Em7
Dm/G
```

---

# 25. AI Harmony Selection

AI는 후보 코드의 선택 및 재화성에 사용한다.

Input:

```text
melody
key
candidate chords
previous harmony
next harmony
music style
difficulty
```

Output:

```json
{
  "selectedChord": "G7",
  "confidence": 0.93
}
```

---

# 26. Harmonization Modes

사용자는 선택한 한 악기의 악보 생성 난이도를 선택할 수 있다. 이 설정은 새 악보에 기록되며 별도 재생 반주 설정을 만들지 않는다.

```text
Simple
Standard
Advanced
```

---

## Simple

예:

```text
C
Am
F
G
```

---

## Standard

예:

```text
Cmaj7
Am7
Dm7
G7
```

---

## Advanced

예:

```text
Cmaj7
E7/G#
Am7
Gm7 C7
Fmaj7
Dm7
G7sus4 G7
```

---

# 27. Accompaniment Style

초기 지원 후보:

```text
Basic
Ballad
CCM
Pop
Arpeggio
Waltz
Jazz
```

---

# 28. Accompaniment Generator

코드가 결정되면 실제 악보 데이터를 생성한다.

예:

```text
Melody
+
Chord
+
Bass
+
Accompaniment Notes
```

---

## Piano Example

Left Hand:

```text
root
fifth
octave
```

Right Hand:

```text
chord
inversion
arpeggio
```

---

# 29. Generated Score

최종 구조:

```text
Treble Staff
    Melody

Treble/Inner Voice
    Chord accompaniment

Bass Staff
    Bass accompaniment
```

MusicXML로 생성하고 MXL로 export한다.

---

# 30. Final User Workflow

```text
Upload PDF
 ↓
Detect pages
 ↓
Preprocess
 ↓
Detect annotations
 ↓
Remove annotations for OMR
 ↓
OMR
 ↓
Generate MusicXML
 ↓
Validate
 ↓
AI review suspicious regions
 ↓
User review uncertain regions
 ↓
Export MXL
```

단선율일 경우 추가 기능:

```text
MXL
 ↓
Analyze Melody
 ↓
Detect Key
 ↓
Generate Chord Candidates
 ↓
AI Harmony Selection
 ↓
Select Accompaniment Style
 ↓
Generate Accompaniment
 ↓
Preview
 ↓
Export New MXL
```

---

# 31. Required User Review UI

AI가 확신하지 못한 부분만 사용자에게 표시한다.

예:

```text
23마디

원본 이미지:
[IMAGE]

현재 인식:
8분음표

AI 추천:
4분음표

Confidence:
82%

[현재 유지]
[AI 수정 적용]
[직접 수정]
```

사용자가 전체 악보를 일일이 검수하지 않아도 되도록 한다.

---

# 32. Data Preservation Policy

반드시 다음 데이터를 별도로 보존한다.

```text
original PDF
original page image
normalized image
annotation mask
clean score image
raw OMR MusicXML
AI corrections
user corrections
final MusicXML
final MXL
```

---

# 33. Recommended Development Order

## Phase 1

```text
PDF
→ image
→ Audiveris
→ MusicXML
→ MXL
```

목표:

기본 변환 기능 완성.

---

## Phase 2

```text
MusicXML Validator
```

목표:

AI 없이 오류 후보 자동 탐지.

---

## Phase 3

4개 AI 모델 비교 테스트.

```text
Qwen3-VL-Flash
GPT-5.6 Luna
Gemini Flash-Lite
GPT-5.6 Terra
```

목표:

가성비 모델 선정.

---

## Phase 4

```text
Annotation Detection
```

지원:

```text
color pen
highlighter
pencil
handwriting
```

---

## Phase 5

```text
AI Correction Pipeline
```

---

## Phase 6

```text
Melody
→ Key
→ Chord
```

---

## Phase 7

```text
Chord
→ Accompaniment
→ MusicXML
```

---

## Phase 8

다음 기능과 통합:

```text
Verse
Chorus
Bridge

Section Repeat

Verse x2
Chorus x4

Playback Order
```

---

# 34. Success Criteria

## PDF → MXL

깨끗한 인쇄 악보:

```text
사용자가 일부 오류만 수정하면 실제 사용 가능한 수준
```

목표는 100% 자동 인식이 아니다.

---

## AI Verification

핵심 목표:

```text
False Correction 최소화
```

AI가 확신하지 못하면 반드시:

```text
uncertain
```

으로 반환하도록 한다.

---

## Melody Harmonization

최초 목표:

```text
멜로디를 해치지 않는 자연스러운 기본 코드 진행 생성
```

이후:

```text
style
difficulty
reharmonization
```

기능을 추가한다.

---

# 35. Core Design Principle

전체 시스템의 핵심 구조는 다음과 같다.

```text
Deterministic Processing
        +
Rule-based Validation
        +
Selective AI
        +
Human Review
```

AI는 시스템의 중심 엔진이 아니라:

```text
uncertainty resolver
```

역할을 담당한다.

즉:

```text
확실한 작업
→ 알고리즘

애매한 작업
→ AI

AI도 확신하지 못함
→ 사용자
```

의 구조를 유지한다.
