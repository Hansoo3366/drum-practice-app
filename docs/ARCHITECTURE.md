# Page-a-Diddle 아키텍처

## 기본 원칙

- 기능 중심(feature-first)으로 구성하고 기능 내부에서 presentation/domain/data 경계를 필요할 때 나눈다.
- UI와 비즈니스 로직은 Flutter/Dart에 두되 PDF와 오디오는 검증된 전문 엔진을 감싼다.
- 원본 악보 파일과 앱이 생성한 메타데이터를 분리한다.
- 공연 환경을 고려해 핵심 악보와 세트리스트는 오프라인 우선으로 동작한다.
- 추상화는 실제 두 번째 구현이 생길 때 도입하고, MVP에 필요하지 않은 계층은 미리 만들지 않는다.

## 디렉터리

```text
lib/
├─ app/                    # 앱 조립, 라우팅, 테마, 공통 셸
├─ core/
│  ├─ database/           # Drift 데이터베이스와 마이그레이션
│  ├─ storage/            # 로컬/외부 파일 접근 공통 기능
│  ├─ score_engine/       # PDF/Smart renderer 계약
│  ├─ audio/              # 음악, 메트로놈, Count-In 공통 clock
│  └─ session/            # Jam Session 상태와 realtime provider 계약
└─ features/
   └─ <feature>/
      ├─ presentation/    # 화면, 위젯, UI 상태
      ├─ domain/          # 기능 규칙과 엔티티
      └─ data/            # 저장소 구현과 DTO
```

빈 계층 폴더는 만들지 않고 첫 파일이 필요할 때 추가한다.

## 기술 결정

### 상태 관리와 의존성 주입

- `flutter_riverpod`을 상태 관리와 의존성 주입에 함께 사용한다.
- 화면 전용의 짧은 상태는 StatefulWidget으로 유지할 수 있다.
- 파일, DB, 오디오 엔진처럼 수명 관리가 필요한 객체는 Provider에서 생성하고 폐기한다.
- Provider에서 `BuildContext`를 참조하지 않는다.

### 라우팅

- `go_router`와 `StatefulShellRoute`로 모바일 NavigationBar와 태블릿 NavigationRail의 탭 상태를 보존한다.
- Viewer, Practice, Stage처럼 몰입형 화면은 추후 루트 셸 밖의 전체 화면 경로로 둔다.

### 제품 셸과 Android flavor

- 저장소를 복제하지 않고 `drum`과 `piano` Android product flavor를 사용한다.
- 드럼 진입점은 `lib/main.dart`, 앱 이름·Application ID는 `Page-a-Diddle`·`com.hansookim.pageadiddle`이다. 기존 PDF Viewer·메트로놈·드럼 연습 도구와 Setlist/Jam 화면은 이 셸에 남긴다.
- 피아노 진입점은 `lib/piano_main.dart`, 앱 이름·Application ID는 `Piano Score`·`com.hansookim.pianoscore`이다. `PianoAppShell`은 Library와 MusicXML 편집만 노출하고 Tap Tempo·Tempo Trainer·Setlist·Jam은 라우팅하지 않는다.
- 공통 Library의 PDF는 기존 `pdfrx` Viewer로 열고, MusicXML은 피아노 flavor에서 Lomse C++ FFI 편집 세션으로 연다. Flutter는 기존 UI·라우팅·로컬 파일·버전/sidecar 저장을 맡고, Lomse는 노테이션 편집 명령과 Undo/Redo를 맡는다.
- 드럼 셸은 현재 기능을 유지하고, Lomse FFI·3단 보표·MusicXML 왕복·피아노 편집 변경은 피아노 셸에만 반영한다. PDF→MusicXML OMR과 AI 편곡은 별도 서버/worker Future 경계다.

### 로컬 저장

- 구조화된 곡, 악보, 세트리스트, 연습 기록은 `Drift/SQLite`에 저장한다.
- PDF와 오디오는 앱 문서 디렉터리의 파일로 저장하고 DB에는 안정적인 상대 경로와 원본 출처를 기록한다.
- 원본 파일은 수정하지 않고 annotation과 Smart Score 메타데이터를 별도 데이터로 저장한다.
- DB 스키마 변경은 명시적인 버전과 마이그레이션 테스트를 동반한다.

### 엔진 경계

- PDF: `pdfrx`
- Piano MusicXML editor: Lomse C++ library through a narrow Flutter FFI bridge. Flutter owns the editor UI; Lomse owns the runtime score model, edition commands, selection/cursor, and undo/redo. The bridge exposes opaque session handles and JSON-safe commands/results only; Flutter never stores or references Lomse `Imo*` objects directly.
- Piano FFI adapter: `FfiLomseEditorSession` lazily opens `libpage_lomse_bridge` only in the piano editor path. If the optional native artifact is not packaged, it returns no session and the existing Smoosic fallback remains active. The adapter does not change the drum flavor.
- Native Digital Score 조판: `verovio_flutter` FFI가 포함한 Verovio 6.2.1. 내부 MusicScore를 MusicXML로 직렬화하고 Verovio SVG·HitMap을 Flutter 화면에 전달한다. Native page는 1/100mm 기준 A4 `2100×2970`으로 제한하며, Flutter 화면에서는 페이지 사이 간격·레터박스 없이 화면 폭으로 균일 축소해 연속 문서로 붙인다. PDF의 여백·페이지 나눔은 `PdfPageFormat.a4` 출력 경로에서 별도로 관리한다.
- Score session: MusicXML snapshot은 저장·버전·복구의 기준이고, Lomse session은 편집 런타임이다. Verovio `xml:id`와 Lomse `ImoId`는 세션 전용 엔진 핸들이며, 앱은 `AppElementId`와 `EventLocator`를 별도로 관리한다. Section/Arrangement는 MusicXML에 섞지 않고 프로젝트 manifest/sidecar에 보관한다.
- Edit/render bridge: 사용자가 Verovio SVG/HitMap에서 선택한 요소를 `AppElementId`로 해석하고, locator로 Lomse 객체를 찾아 command를 실행한다. command 후 MusicXML을 export하고 Verovio를 새 revision으로 reload한다. 연속 입력은 command batch/debounce로 묶으며 오래된 render 결과는 폐기한다.
- Native bridge PoC: Lomse import → edit command → MusicXML export → Verovio reload/render의 왕복 보존과 Android latency를 통과하기 전에는 기존 편집기를 제거하지 않는다. Lomse의 내부 API 및 LDP/LMD command 입력 의존성은 native bridge 내부에 격리한다.
- Native Digital Score 재생: `flutter_notemus`의 MusicXML 파싱·MIDI mapping과 네이티브 시퀀서 adapter를 조판 엔진과 분리한다.
- 음악/메트로놈/Count-In: `flutter_soloud`의 오디오 clock
- 외부 저장소: MVP 1은 OS File Picker, MVP 4부터 provider별 adapter

### Jam Session

- MVP 6에서 `JamSessionStore` 계약을 정의한다. 같은 Wi-Fi에서는 `LanJamSessionStore`가 호스트 기기에서 세션을 열고 코드로 참가한다. 클라우드 서버는 쓰지 않는다.
- Presence는 TCP 연결 상태와 ping으로 유지한다. 응답이 끊기면 참가자를 먼저 끊김으로 표시하고 이어서 목록에서 뺀다.
- 참가자는 생성·참가 시 보컬·기타·베이스·드럼·키보드 또는 직접 입력한 기타 파트를 고르고, 세션에는 악기 파트와 Conductor/Member 권한을 함께 표시·전달한다.
- 네트워크는 Session State와 기준 시작 시각만 전달하며, 오디오 click은 각 기기의 `flutter_soloud` clock에서 생성한다.
- `JamPermissions`로 Conductor(초대·리드)와 Member(Follow) 권한을 구분한다. 곡·BPM·Start/Stop 공유는 이후 항목에서 Conductor만 수행한다.
- Jam 입장은 대기실 상태로 시작한다. 새 Member는 `ready=false`이며 LAN `ready` 메시지로 상태를 공유하고, Conductor는 연결된 Member가 모두 준비된 뒤에만 `playing/startAt`을 발행한다. Member 화면은 이 상태를 받아 자신의 로컬 악보를 열고 같은 시작 시각의 로컬 메트로놈을 실행한다.
- Setlist 공유는 Conductor 기기의 세트리스트 스냅샷(`JamSharedSetlist`)을 세션 상태에 실어 보낸다. 스냅샷에는 세트리스트 UUID, 순서, 항목 UUID(`SetlistEntry.id`), 제목·아티스트·BPM만 포함하고 로컬 `Song.id`나 PDF 원본은 전송하지 않는다. 세션의 `currentEntryId`가 바뀌면 각 기기는 세트리스트 UUID+항목 UUID를 키로 자신의 악보를 선택·저장해 연다. 따라서 드러머·기타리스트가 같은 곡의 서로 다른 파트 PDF를 사용할 수 있다.
- Conductor Viewer의 페이지·마디는 `JamScorePosition`으로 공유되고, Member Viewer는 같은 곡을 보고 있을 때 위치를 따라간다.
- Conductor의 BPM·Section·박자표·음표 단위·박별 악센트는 `JamMusicState`로 공유되며, Member Viewer는 기본으로 같은 메트로놈 설정과 Section 표식 마디를 적용한다.
- Conductor 메트로놈 Start/Stop은 세션 `playing`으로 공유한다. 박자 시각 합의는 MVP 7이다.
- Count-In 마디 수(없음/1/2/4)는 세션 `countInBars`로 공유한다. Start 시 `startAt`(UTC, lead 750ms)을 합의하고 각 기기가 그 시각까지 기다린 뒤 로컬 클릭을 시작한다. 합주 중에는 `startAt`+BPM으로 절대 step을 계산해 박자 표시·클릭을 맞춘다(Metronome Sync). 기본은 Individual Click이라 모든 기기가 각자 클릭을 재생하고, 필요하면 Conductor가 Host Click으로 바꿔 Conductor만 재생할 수 있다. Conductor의 A-B Loop는 `JamLoopState`로 공유되고 Member Follow 시 같은 구간을 켠다. 시계 보정은 M7-07이다.
- Member는 기본으로 Conductor를 따르고(`Follow Conductor`), 수동 이동 시 따라가기를 끈 뒤 `Return to Live`로 현재 합주 위치에 복귀한다.
- realtime backend 구현을 domain/presentation과 분리해 provider 교체가 가능하도록 한다.

## 지원 기준

- 앱 이름: 기본 `Page-a-Diddle`, 피아노 flavor `Piano Score`
- Dart 패키지명: `page_a_diddle`
- Android Application ID: 드럼 `com.hansookim.pageadiddle`, 피아노 `com.hansookim.pianoscore`
- Android: API 26(Android 8.0) 이상
- iOS: 배포하지 않음 (개발 범위 제외)
