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

현재 저장소의 C ABI는
`native/lomse_bridge/include/page_lomse_bridge.h`에 둔다. 이 헤더와 구현은
Android `piano` source set에서만 빌드·패키징하며, 드럼 flavor에는 링크하지
않는다.

`lib/features/piano/data/lomse_ffi_editor_session.dart`의
`FfiLomseEditorSession`은 이 ABI를 Dart `LomseEditorSession`으로 감싼다. native
라이브러리를 찾지 못하면 `tryCreate()`가 null을 반환하고 피아노 화면은 오류
상태를 표시한다. Smoosic WebView fallback은 더 이상 제품 경로에 두지 않는다.
현재 피아노 화면은 이 세션의 MusicXML snapshot을 Verovio 렌더러에 넘기는
host/controller 수직 슬라이스를 사용한다.

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

- 고정 dependency와 Android NDK bridge build가 clean/CI 환경에서도 재현되지 않는다.
- MusicXML 왕복에서 3 Staff 또는 다중 Voice가 손실된다.
- AppElementId 매핑이 chord·grace note·cross-staff에서 불안정하다.
- 실기기에서 편집 후 전체 렌더링이 제품 허용 latency를 넘는다.

보류 시 Verovio viewer와 현재 Lomse 커스텀 편집기의 검증된 범위만 유지하고,
미검증 명령·대형 악보 최적화는 확장하지 않는다. Smoosic WebView를 fallback으로
재도입하지 않는다.

현재 검증 결과: Lomse 0.30.0 macOS standalone shared-library build와 host
bridge smoke(load/export, LDP insert, undo/redo)는 통과했다. 고정된 Lomse/FreeType
commit을 `native/.cache`에 가져와 Android `arm64-v8a`와 `x86_64` 정적 링크 target을
빌드하고, `piano` flavor APK에는 `libpage_lomse_bridge.so`와 `libc++_shared.so`만
추가되는 경로를 연결했다. APK zip에서 piano 포함과 drum 미포함을 확인했다.
`Pixel_10_Pro_XL` 에뮬레이터에서 실제 Dart FFI load→insert/export→undo→redo와
Verovio 재렌더링, 새 악보 저장→Library 재진입을 확인했으며 logcat 치명적 오류는
없었다. 현재 staff tap → AppElementId/EventLocator → Lomse cursor target mapping과
target insert/export/undo/redo smoke까지 연결했다. 다음 native gate는 chord·voice·measure
명령 확대, chord·grace·cross-staff mapping edge case, Verovio 왕복 구조 비교·latency
측정이다.

## 2026-09-25 가능성 재검토

- Verovio viewer: **현재 구현 가능**. `verovio_flutter` 패키지 복구 후 대상
  analyze가 통과했고, 피아노/드럼 debug flavor APK가 모두 생성됐다. 피아노 APK에는
  `libverovio_flutter.so`가 포함된다.
- Lomse editor: **수직 슬라이스 구현 가능, 전체 production은 조건부**. 피아노
  domain/FFI 계약 테스트와 편집·레이아웃 관련 테스트, 고정 native Android
  `arm64-v8a`/`x86_64` bridge build가 통과했고 piano APK에는
  `libpage_lomse_bridge.so`와 C++ runtime이 포함된다. 현재 `PianoEditorScreen`은
  Lomse FFI session과 Verovio viewer를 연결한 커스텀 화면을 사용한다.
- Android `Pixel_10_Pro_XL` 에뮬레이터에서 piano APK 설치·실행 후 `Edit score` →
  `Piano editor`를 열고 `Lomse r1`에서 insert/export, undo, redo revision과
  Verovio `ImageView` 렌더링을 확인했다. 새 악보를 저장해 Library에 표시하고 다시
  열었으며, logcat에서 `FATAL EXCEPTION`·`SIGSEGV`·`page_lomse` 오류가 없었다.
  16KB page-size compatibility 안내창은 에뮬레이터 OS 경고이며 앱 오류가 아니다.

- 따라서 현재 제품의 다음 순서는
  `mapping edge case 보강 → note/rest/chord/voice/measure 명령 확대 →
  MusicXML export/Verovio reload 구조 비교 → Android latency`다. 이 게이트들은
  Lomse 커스텀 편집기의 품질을 높이기 위한 것이며, Smoosic 재도입 조건이 아니다.
