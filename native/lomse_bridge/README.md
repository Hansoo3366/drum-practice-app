# Piano Lomse bridge

이 디렉터리는 `piano` flavor 전용 Lomse C++ runtime 경계를 둔다. Flutter가
Lomse의 `Imo*`, `std::string`, LDP/LMD fragment를 직접 다루지 않도록
[`page_lomse_bridge.h`](include/page_lomse_bridge.h)의 opaque-handle C ABI만
공개한다.

현재 단계에서는 헤더·Dart command 계약, 최소 C++ bridge 구현, Dart FFI 세션
어댑터까지 추가되어 있다. 다만 Android/iOS production binary와 Flutter APK에는
아직 링크하지 않았다. Dart 어댑터는 라이브러리가 없을 때 `null`을 반환하므로
기존 피아노 Smoosic fallback을 깨지 않는다. 다음 PoC에서 해야 할 일은 다음과
같다.

1. [`dependencies.lock.yaml`](dependencies.lock.yaml)의 Lomse·FreeType commit을
   `third_party` 또는 CI cache에 재현 가능하게 가져오고, FreeType Android
   cross-build도 함께 고정한다.
2. CMake/NDK에서 `page_lomse_bridge`와 Lomse runtime을 `piano` source set에만
   연결해 Dart FFI 호출 경로를 만든다.
3. `load → execute_json → export → undo/redo`와 오류 문자열·버퍼 수명을
   Android instrumentation/host test로 검증한다.
4. AppElementId/EventLocator 기반 target mapping을 구현하고, export된 MusicXML을
   기존 `verovio_flutter`에 넣어 왕복 구조와 latency를 측정한다.

Android SDK의 `cmake 3.22.1`과 NDK로 Lomse 0.30.0 standalone macOS shared
library build를 확인했고, 임시로 교차 빌드한 Android arm64 FreeType을 주입해
Lomse와 `page_lomse_bridge` Android arm64 standalone target도 빌드했다. host
smoke는 MusicXML load/export, LDP insert, undo/redo까지 통과했다. 다만 이 결과는
Flutter APK에 연결된 상태가 아니며, Lomse와 FreeType의 재현 가능한 vendor/pin,
Gradle native packaging, Dart FFI 호출, Android instrumentation은 아직 남아 있다.

현재 bridge의 insert command는 cursor 위치에 LDP를 넣는 최소 smoke용 구현이다.
AppElementId/EventLocator target mapping과 Verovio 재렌더링은 아직 구현하지 않았으므로
production editor로 간주하지 않는다.

`lib/features/piano/data/lomse_ffi_editor_session.dart`의
`FfiLomseEditorSession`은 이 C ABI를 `LomseEditorSession` 계약으로 감싼다. native
라이브러리를 찾지 못하면 `tryCreate()`가 null을 반환한다. 따라서 이 어댑터를
추가한 것만으로 기존 UI가 Lomse 화면으로 바뀌지는 않으며, piano flavor native
packaging과 Verovio host/controller 연결이 완료된 뒤에만 editor 진입을 전환한다.

따라서 이 ABI를 추가했다고 Lomse 편집이 이미 앱에서 동작한다고 간주하지
않으며, 왕복 PoC 통과 전까지 기존 Smoosic 화면은 피아노 flavor의 fallback으로
남긴다.
