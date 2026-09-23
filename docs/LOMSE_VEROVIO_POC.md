# Piano Lomse + Verovio 왕복 PoC

이 문서는 피아노 flavor에만 적용한다. 드럼 flavor의 PDF Viewer·메트로놈·기존 연습 흐름은 이 PoC의 범위가 아니다.

## 목표

기존 Flutter UI를 유지하면서 다음 파이프라인을 검증한다.

```text
MusicXML snapshot
        ↓
App Score Session
   ┌────┴────┐
   ▼         ▼
 Lomse     Verovio
 편집      렌더링
   │         │
   │         └─ SVG / HitMap → Flutter UI
   └─ MusicXML export
```

Lomse는 C++ 편집 런타임, Verovio는 화면·PDF 조판 엔진이다. 어느 엔진의 내부 ID도 저장 포맷이나 앱 영구 키가 되지 않는다.

## 세션 경계

```text
AppScoreSession
├── sourceMusicXml       저장·버전·복구 snapshot
├── sidecar              sections / arrangement / annotations
├── elementRegistry      AppElementId ↔ EventLocator
├── lomseSession         opaque native handle
└── verovioSession       render revision / page cache
```

### 앱 식별자

- `AppElementId`: 앱이 생성한 영구 UUID. note, rest, chord member, relation, measure에 부여한다.
- `MeasureUid`: 표시용 measure number와 분리된 앱 고유 UUID다.
- `EventLocator`: `partId`, `measureUid`, `staff`, `voice`, 공통 PPQ 기준 `onsetTicks`, `chordIndex`, `eventKind`로 구성한다.
- Verovio `xml:id`, Lomse `ImoId`: 현재 import/render session에서만 사용하는 임시 engine handle이다.

`measureIndex`와 `eventIndex`는 locator 계산에 사용할 수 있지만 영구 식별자로 저장하지 않는다. 마디·음표 삽입/삭제 또는 export/import 후에는 registry를 다시 계산한다.

## Native bridge 최소 API

Flutter가 Lomse 내부 타입을 직접 알지 않도록 C ABI 또는 동등한 opaque-handle API로 제한한다.

```text
lomse_session_create()
lomse_session_load_musicxml(session, utf8_xml)
lomse_session_execute_command(session, json_command)
lomse_session_undo(session)
lomse_session_redo(session)
lomse_session_export_musicxml(session)
lomse_session_dispose(session)
```

현재 저장소의 C ABI 초안은
`native/lomse_bridge/include/page_lomse_bridge.h`에 둔다. 구현이 연결되면 이
헤더를 Android `piano` source set에서만 빌드하며, 드럼 flavor에는 링크하지
않는다.

`lib/features/piano/data/lomse_ffi_editor_session.dart`의
`FfiLomseEditorSession`은 이 ABI를 Dart `LomseEditorSession`으로 감싼다. native
라이브러리가 아직 APK에 없으면 `tryCreate()`가 null을 반환해 피아노의 기존
fallback이 유지된다. library가 연결된 뒤에도 편집 UI는 이 세션의 MusicXML
snapshot을 Verovio 렌더러에 넘기는 host/controller가 완성된 후 전환한다.

JSON command에는 AppElementId/EventLocator와 음악적 변경값만 담는다. Lomse의 내부 `Imo*`, LDP/LMD fragment, allocator 수명은 bridge 안에 둔다.

## 편집 흐름

```text
Verovio HitMap 선택
  ↓
AppElementId 해석
  ↓
EventLocator로 Lomse 대상 탐색
  ↓
Lomse command 실행
  ↓
새 revision 발급
  ↓
MusicXML export
  ↓
Verovio load/reload + page render
  ↓
최신 revision만 Flutter 반영
```

단일 편집은 command 완료 후 즉시 다시 그린다. 연속 pitch 이동이나 드래그는 150~300ms command batch로 묶는다. 오래된 render future가 늦게 도착해 최신 악보를 덮어쓰지 않도록 revision을 검사한다.

## Sidecar

Verse·Chorus·Arrangement는 악보 엔진에 넣지 않는다.

```json
{
  "schemaVersion": 1,
  "scoreId": "score-001",
  "sourceRevision": "musicxml-hash",
  "sections": [
    {
      "id": "verse1",
      "label": "Verse 1",
      "startMeasureUid": "m-0012",
      "endMeasureUid": "m-0019"
    }
  ],
  "arrangement": [
    { "sectionId": "verse1", "playCount": 2 }
  ]
}
```

일반 재생은 원본 written score를 유지하고 timeline만 펼친다. 사용자가 별도 “악보 재구성”을 실행할 때만 Section을 복제·재배열한 export score를 만든다.

## 검증 fixture와 합격 조건

| Fixture | 검증 내용 |
|---|---|
| `test01.musicxml` | Grand Staff 및 3 Staff |
| `test02.musicxml` | 한 Staff 안의 Voice 1/2와 staff별 voice |
| `test03.musicxml` | Tuplet + Tie + Slur + Beam |
| `test04.musicxml` | Repeat + Volta + D.C. + D.S. |
| `test05.musicxml` | Tempo + Dynamic + Pedal + Direction |
| `test06.musicxml` | Section sidecar와 Verse/Chorus arrangement |
| `test07.musicxml` | 실제 10~20페이지 피아노 악보 |

각 fixture는 다음 순서로 실행한다.

```text
원본 MusicXML
 → Lomse import
 → 음표/Staff/Voice/관계 하나 수정
 → MusicXML export
 → Verovio render
 → 구조 비교 + SVG 시각 비교
```

합격 기준:

- 음표·rest·chord·staff·voice·tuplet·tie·slur·repeat 의미가 예기치 않게 사라지지 않는다.
- 수정한 AppElementId가 Verovio 재렌더 후에도 같은 논리 요소를 가리킨다.
- Section/Arrangement가 MusicXML export/import 때문에 소실되지 않는다.
- Android 실기기에서 3단·다중 Voice·10~20페이지의 edit→export→render p50/p95 latency와 메모리를 기록한다.
- 최신 revision만 화면에 적용되고, 연속 편집 중 이전 SVG가 최신 변경을 덮어쓰지 않는다.

## 보류 조건

- Lomse native Android build와 FreeType 교차 의존성이 재현되지 않는다.
- MusicXML 왕복에서 3 Staff 또는 다중 Voice가 손실된다.
- AppElementId 매핑이 chord·grace note·cross-staff에서 불안정하다.
- 실기기에서 편집 후 전체 렌더링이 제품 허용 latency를 넘는다.

보류 시 Verovio viewer와 기존 Flutter MusicScore 편집 모델을 유지하고, Lomse는 도입하지 않는다. PoC가 통과하기 전까지 기존 Smoosic WebView는 fallback으로만 유지한다.

현재 검증 결과: Lomse 0.30.0 macOS standalone shared-library build와 host
bridge smoke(load/export, LDP insert, undo/redo)는 통과했다. 임시로 교차 빌드한
Android arm64 FreeType을 주입해 Lomse 및 `page_lomse_bridge` Android arm64
standalone target build도 통과했다. 아직 Flutter APK에 연결하거나 Dart FFI·Android
instrumentation을 실행한 것은 아니다. 다음 native gate는 Lomse/FreeType dependency
pin·vendor와 piano flavor packaging, AppElementId/EventLocator target mapping,
Verovio 왕복 구조 비교·latency 측정이다.
