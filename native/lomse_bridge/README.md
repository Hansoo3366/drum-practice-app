# Piano Lomse bridge

이 디렉터리는 `piano` flavor 전용 Lomse C++ runtime 경계를 둔다. Flutter가
Lomse의 `Imo*`, `std::string`, LDP/LMD fragment를 직접 다루지 않도록
[`page_lomse_bridge.h`](include/page_lomse_bridge.h)의 opaque-handle C ABI만
공개한다.

현재 단계에서는 헤더·Dart command 계약, 최소 C++ bridge 구현, Dart FFI 세션
어댑터와 Android `arm64-v8a`/`x86_64` 패키징 경로까지 추가되어 있다. `build_android.ps1`은
`dependencies.lock.yaml`의 고정 커밋을 `native/.cache`에 가져오고, FreeType과
Lomse를 정적으로 묶은 `libpage_lomse_bridge.so` 및 `libc++_shared.so`를
`build/native/piano-jni-libs`에 만든다. Gradle은 이 디렉터리를 `piano` source set에만
연결하므로 `drum` flavor는 두 라이브러리를 패키징하지 않는다.

Android arm64 staging과 piano APK 빌드는 다음 순서로 실행한다.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File native\lomse_bridge\build_android.ps1
flutter build apk --debug --flavor piano -t lib/piano_main.dart --no-pub
```

에뮬레이터용 x86_64 bridge는 다음처럼 별도로 만든다.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File native\lomse_bridge\build_android.ps1 -Abi x86_64
```

이미 고정 커밋이 `native/.cache`에 있으면 `-Offline`을 추가해 네트워크 없이
재빌드할 수 있다.

현재 `PianoEditorScreen`은 Lomse FFI session과 Verovio viewer를 연결한 커스텀
피아노 편집 화면이다. Dart 어댑터는 라이브러리가 없을 때 `null`을 반환하고 화면은
명시적인 오류 상태를 표시한다. Smoosic WebView fallback은 소스·의존성·제품
라우트에서 제거했다. 다음 PoC에서 해야 할 일은 다음과 같다.

1. 앱의 AppElementId/EventLocator 기반 target mapping을 확장한다. 현재
   staff tap → semantic target → Lomse cursor 이동까지 구현했다.
2. note/rest/chord/voice/measure command와 오류·버퍼 수명 경계를 확장한다.
3. export된 MusicXML을
   기존 `verovio_flutter`에 넣어 왕복 구조와 latency를 측정한다.
4. 3단·다중 Voice·10~20페이지 fixture로 구조 보존과 Android p50/p95를 검증한다.
5. CMake/NDK 패키징 결과를 CI에서도 같은 lock과 script로 재현한다.

Android SDK의 `cmake 3.22.1`과 NDK로 고정된 Lomse 0.30.0/FreeType 2.13.3을
정적 링크하고, `libpage_lomse_bridge.so`를 실제 piano debug APK에 포함하는 데
성공했다. host smoke는 MusicXML load/export, LDP insert, undo/redo까지 통과했고,
APK zip에서 piano에는 bridge와 C++ runtime이, drum에는 둘 다 없음을 확인했다.
`Pixel_10_Pro_XL` x86_64 에뮬레이터에서도 Dart FFI load→insert/export→undo→redo,
Verovio render, 새 악보 저장·재진입을 통과했다.

현재 bridge의 insert command는 cursor 위치 또는 AppElementId/EventLocator가
지정한 Lomse cursor 위치에 LDP를 넣는다. Flutter registry는 MusicXML snapshot에서
measureUid·staff·voice·onsetTicks를 재계산하고, native ImoId는 보존하지 않는다.
Verovio 재렌더링은 export 후 매번 실행되며, 전체 production command 집합으로는
간주하지 않는다.

`lib/features/piano/data/lomse_ffi_editor_session.dart`의
`FfiLomseEditorSession`은 이 C ABI를 `LomseEditorSession` 계약으로 감싼다. native
라이브러리를 찾지 못하면 `tryCreate()`가 null을 반환하고, piano 화면은 오류 상태를
표시한다. piano flavor native packaging과 Verovio host/controller 연결은 이미
완료되어 현재 Lomse 커스텀 editor 진입에 사용한다.

따라서 현재 구현은 cursor 및 staff-target 기반 note/rest 삽입과 Undo/Redo를 포함한
수직 슬라이스로 간주한다. chord/voice/measure command, 전체 fixture 왕복·성능
게이트가 남아 있으므로 전체 production command 집합으로 확대하는 작업은 계속한다.
