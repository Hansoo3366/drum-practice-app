# 작업 로그

최신 작업을 문서 상단에 추가한다. 기존 기록은 수정하거나 삭제하지 않는다.

## 2026-09-20 00:45 KST — 구간 표기 빌드를 폰에 설치

- 작업자: Cursor Grok 4.6
- 목표: 너비 맞춤·핀치 줌·줄 앞 구간 표기가 들어간 debug APK를 SM-S937N에 넣는다
- 관련 로드맵: M8-06 보완, B-017
- 변경 파일:
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - `flutter build apk --debug --no-pub --dart-define-from-file=dart_defines.json --target-platform android-arm64`로 `app-debug.apk` 239MB를 만들었다.
  - `adb install -r` Success 후 MainActivity를 실행했다.
- 검증:
  - 기기 `R5CY43JMZ7N` / SM-S937N, PID 14015, SHA-256 `92ee122effabf2e1fbde32c51ecf2bfed97bca6dd334542c0b52aee91a1647c6`
  - `versionName=1.0.0`, `lastUpdateTime=2026-09-20 00:44:54`
- 남은 일:
  - 폰에서 구간 표기, 너비 맞춤, 핀치 줌을 확인한다.

## 2026-09-20 00:44 KST — 구간 표기를 붙인 줄만

- 작업자: Cursor Grok 4.6
- 목표: 구간 이름이 높은음자리표에 빨갛게 반복되지 않게 한다
- 관련 로드맵: M8-06 보완, B-017
- 변경 파일:
  - `lib/features/digital_score/domain/playback_sequence.dart`
  - `lib/features/digital_score/presentation/piano_score_view.dart`
  - `assets/alphatab/index.html`
  - `test/features/digital_score/domain/playback_sequence_test.dart`
  - `test/features/digital_score/presentation/alphatab_asset_test.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - 구간 이름은 실제로 붙인 마디에만 네모로 올린다.
  - 줄이 이어져도 다음 마디·다음 줄에 같은 글을 반복하지 않는다.
- 검증:
  - `flutter analyze --no-pub` 대상 변경 Dart 파일: 문제 없음
  - `flutter test --no-pub -j 1 --dart-define-from-file=dart_defines.json` 연주 순서·렌더러·조판: 11개 통과
- 남은 일:
  - 폰에서 붙인 줄 앞에만 구간 표기가 있는지 확인한다.

## 2026-09-20 00:42 KST — 너비 맞춤과 핀치 줌

- 작업자: Cursor Grok 4.6
- 목표: 전자악보를 화면 너비에 맞춰 줄이고, 흰 배경에서 핀치로 확대·이동한다
- 관련 로드맵: M8-06 보완, B-017
- 변경 파일:
  - `assets/alphatab/index.html`
  - `lib/features/digital_score/presentation/piano_score_view.dart`
  - `lib/features/digital_score/presentation/digital_score_screen.dart`
  - `lib/core/score_engine/alphatab_bridge.dart`
  - `test/features/digital_score/presentation/alphatab_asset_test.dart`
  - `test/features/score_viewer/alphatab_bridge_test.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - A4 폭으로 그린 뒤 화면 너비 비율로 줄인다.
  - 배경을 흰색으로 고정했다.
  - 핀치로 1~4배 확대하고 끌어 이동한다.
- 검증:
  - `flutter analyze --no-pub` 대상 변경 Dart 파일: 문제 없음
  - `flutter test --no-pub -j 1 --dart-define-from-file=dart_defines.json` 렌더러 자산·bridge·조판: 27개 통과
- 남은 일:
  - 폰에서 너비 맞춤, 흰 배경, 핀치 줌을 확인한다.

## 2026-09-20 00:36 KST — 조옮김 빌드를 폰에 설치

- 작업자: Cursor Grok 4.6
- 목표: 조옮김·A4 조판이 들어간 debug APK를 SM-S937N에 넣는다
- 관련 로드맵: M8-07 보완, B-017
- 변경 파일:
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - `flutter build apk --debug --no-pub --dart-define-from-file=dart_defines.json --target-platform android-arm64`로 `app-debug.apk` 239MB를 만들었다.
  - `adb install -r` Success 후 MainActivity를 실행했다.
- 검증:
  - 기기 `R5CY43JMZ7N` / SM-S937N, PID 9209, SHA-256 `cdfe10fe8130faba89664266b28387804f03c6979c62dc263444b18f775c095d`
  - `versionName=1.0.0`, `lastUpdateTime=2026-09-20 00:36:17`
- 남은 일:
  - 폰에서 조옮김 버튼, A4 조판, 줄 주황 박스를 확인한다.

## 2026-09-20 00:34 KST — 이조를 조옮김으로

- 작업자: Cursor Grok 4.6
- 목표: 화면에 보이는 용어를 조옮김으로 통일한다
- 관련 로드맵: M8-07 보완
- 변경 파일:
  - `lib/l10n/app_ko.arb`
  - `lib/l10n/app_localizations_ko.dart`
  - `test/features/digital_score/presentation/score_transpose_panel_test.dart`
  - `test/features/digital_score/presentation/score_playback_bar_test.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - 앱바·시트 문구를 `조옮김`으로 바꿨다.
- 검증:
  - `flutter test --no-pub -j 1 --dart-define-from-file=dart_defines.json` 조옮김 시트·재생 막대: 7개 통과
- 남은 일:
  - 폰에서 조옮김 버튼을 확인한다.

## 2026-09-20 00:32 KST — A4 폭 조판과 줄 단위 구간

- 작업자: Cursor Grok 4.6
- 목표: 4마디 고정을 빼고 A4처럼 조판한 뒤 폰에 맞춘다
- 관련 로드맵: M8-06 보완, B-017
- 변경 파일:
  - `lib/features/digital_score/domain/score_layout.dart`
  - `lib/features/digital_score/domain/score_editor.dart`
  - `lib/features/digital_score/presentation/digital_score_screen.dart`
  - `lib/features/digital_score/presentation/piano_score_view.dart`
  - `lib/core/score_engine/alphatab_bridge.dart`
  - `assets/alphatab/index.html`
  - `test/features/digital_score/domain/score_layout_test.dart`
  - `test/features/digital_score/presentation/alphatab_asset_test.dart`
  - `test/features/score_viewer/alphatab_bridge_test.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - 악보는 A4 폭으로 그리고 화면 너비에 맞게 줄인다.
  - 구간은 렌더된 한 줄의 첫 마디에 붙인다.
- 검증:
  - `flutter analyze --no-pub` 대상 변경 Dart 파일: 문제 없음
  - `flutter test --no-pub -j 1 --dart-define-from-file=dart_defines.json`: 전체 273개 통과
- 남은 일:
  - 폰에서 A4 조판과 줄 구간을 확인한다.

## 2026-09-20 00:28 KST — 4마디 한 줄과 줄 선택

- 작업자: Cursor Grok 4.6
- 목표: 한 줄을 4마디로 맞추고, 구간을 줄 단위로 붙이며, 주황 박스가 실제로 뜨게 한다
- 관련 로드맵: M8-06 보완, B-017
- 변경 파일:
  - `lib/features/digital_score/domain/score_layout.dart`
  - `lib/features/digital_score/domain/score_editor.dart`
  - `lib/features/digital_score/presentation/digital_score_screen.dart`
  - `lib/features/digital_score/presentation/piano_score_view.dart`
  - `assets/alphatab/index.html`
  - `test/features/digital_score/domain/score_layout_test.dart`
  - `test/features/digital_score/presentation/alphatab_asset_test.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - 조판을 한 줄 4마디로 고정했다.
  - 구간은 그 줄의 첫 마디에만 붙인다.
  - 연주 순서에서 오선 탭은 WebView가 삼키지 않고, 줄 전체에 주황 박스를 그린다.
  - alphaTab 좌표는 `findMasterBarByIndex`와 staff system bounds를 쓴다.
- 검증:
  - `flutter analyze --no-pub` 대상 변경 Dart 파일: 문제 없음
  - `flutter test --no-pub -j 1 --dart-define-from-file=dart_defines.json`: 전체 273개 통과
- 남은 일:
  - 폰에서 4마디 한 줄, 줄 선택 박스, 줄 구간을 확인한다.

## 2026-09-20 00:23 KST — 마디 박스 빌드를 폰에 설치

- 작업자: Cursor Grok 4.6
- 목표: 마디 전체 주황 박스가 들어간 debug APK를 SM-S937N에 넣는다
- 관련 로드맵: M8-06 보완, B-017
- 변경 파일:
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - `flutter build apk --debug --no-pub --dart-define-from-file=dart_defines.json --target-platform android-arm64`로 `app-debug.apk` 239MB를 만들었다.
  - `adb install -r` Success 후 MainActivity를 실행했다.
- 검증:
  - 기기 `R5CY43JMZ7N` / SM-S937N, PID 30126, SHA-256 `4c6237574c05f6b5c776e655adf50c9c071e2d2296e026933ea1fd0854befcdd`
  - `versionName=1.0.0`, `lastUpdateTime=2026-09-20 00:23:46`
- 남은 일:
  - 폰에서 마디를 눌렀을 때 주황 박스가 뜨는지 확인한다.

## 2026-09-20 00:22 KST — 선택 마디에 떠 있는 색 박스

- 작업자: Cursor Grok 4.6
- 목표: 마디를 누르면 그 칸 전체에 변경 중인 박스가 바로 보이게 한다
- 관련 로드맵: M8-06 보완, B-017
- 변경 파일:
  - `assets/alphatab/index.html`
  - `lib/features/digital_score/presentation/digital_score_screen.dart`
  - `test/features/digital_score/presentation/alphatab_asset_test.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - 오선·음표를 누르면 Flutter를 기다리지 않고 그 마디 전체를 주황 박스가 감싼다.
  - 높은·낮은음자리표를 한 칸으로 묶고, 좌표가 비면 다시 그린다.
- 검증:
  - `flutter test --no-pub -j 1 --dart-define-from-file=dart_defines.json`: 전체 271개 통과
- 남은 일:
  - 폰에서 마디를 눌렀을 때 박스가 뜨는지 확인한다.

## 2026-09-20 00:20 KST — 구간을 악보에 표시하고 마디 추가

- 작업자: Cursor Grok 4.6
- 목표: 구간 이름이 오선에 보이게 하고, 다음 마디 추가가 실제로 되게 한다
- 관련 로드맵: M8-06 보완, B-017
- 변경 파일:
  - `lib/features/digital_score/domain/playback_sequence.dart`
  - `lib/core/score_engine/alphatab_bridge.dart`
  - `lib/features/digital_score/data/music_xml_codec.dart`
  - `lib/features/digital_score/presentation/piano_score_view.dart`
  - `lib/features/digital_score/presentation/playback_sequence_panel.dart`
  - `lib/features/digital_score/presentation/score_editor_panel.dart`
  - `lib/features/digital_score/presentation/digital_score_screen.dart`
  - `assets/alphatab/index.html`
  - `test/features/digital_score/domain/playback_sequence_test.dart`
  - `test/features/digital_score/presentation/playback_sequence_panel_test.dart`
  - `test/features/digital_score/presentation/score_editor_panel_test.dart`
  - `test/features/score_viewer/alphatab_bridge_test.dart`
  - `test/features/digital_score/presentation/alphatab_asset_test.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - 붙은 구간은 오선 위 각 마디에 벌스·코러스로 올린다.
  - 연주 순서와 쓰기 팔레트에 `다음 마디 추가`를 다시 넣었다.
- 검증:
  - `flutter analyze --no-pub` 대상 변경 Dart 파일: 문제 없음
  - `flutter test --no-pub -j 1 --dart-define-from-file=dart_defines.json`: 전체 271개 통과
- 남은 일:
  - 폰에서 구간 표시와 마디 추가를 확인한다.

## 2026-09-20 00:12 KST — 마디별 조 표시 빌드를 폰에 설치

- 작업자: Cursor Grok 4.6
- 목표: 각 마디 위 조 이름이 들어간 debug APK를 SM-S937N에 넣는다
- 관련 로드맵: M8-07 보완, B-017
- 변경 파일:
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - `flutter build apk --debug --no-pub --dart-define-from-file=dart_defines.json --target-platform android-arm64`로 `app-debug.apk` 239MB를 만들었다.
  - `adb install -r` Success 후 MainActivity를 실행했다.
- 검증:
  - 기기 `R5CY43JMZ7N` / SM-S937N, PID 26411, SHA-256 `1174219853a7f5c9423ab8dd60dbe1ca29ade75838fe2297353e7a389e4ba946`
  - `versionName=1.0.0`, `lastUpdateTime=2026-09-20 00:11:58`
- 남은 일:
  - 폰에서 각 마디 위 조 이름과 이조 뒤 갱신을 확인한다.

## 2026-09-20 00:50 KST — 마디마다 조를 악보에 표시

- 작업자: Cursor Grok 4.6
- 목표: 이조 뒤에도 각 마디의 조가 오선 위에서 보이게 한다
- 관련 로드맵: M8-07 보완, B-017
- 변경 파일:
  - `lib/features/digital_score/domain/score_transpose.dart`
  - `lib/core/score_engine/alphatab_bridge.dart`
  - `lib/features/digital_score/presentation/piano_score_view.dart`
  - `assets/alphatab/index.html`
  - `test/features/digital_score/domain/score_transpose_test.dart`
  - `test/features/score_viewer/alphatab_bridge_test.dart`
  - `test/features/digital_score/presentation/alphatab_asset_test.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - 각 마디의 조 fifths를 렌더 좌표에 C·G·B♭ 같은 으뜸음으로 올린다.
  - 저장된 MusicXML에는 가짜 가사를 넣지 않는다.
- 검증:
  - `flutter analyze --no-pub` 대상 변경 Dart 파일: 문제 없음
  - `flutter test --no-pub -j 1 --dart-define-from-file=dart_defines.json`: 전체 271개 통과
- 남은 일:
  - 폰에서 각 마디 위 조 이름과 이조 뒤 갱신을 확인한다.

## 2026-09-20 00:35 KST — 마디 활성화를 악보 탭으로

- 작업자: Cursor Grok 4.6
- 목표: 연주 순서 옵션 색칠을 빼고, 오선을 누르면 그 마디가 악보에서 켜지게 한다
- 관련 로드맵: M8-06 보완, B-017
- 변경 파일:
  - `lib/features/digital_score/presentation/playback_sequence_panel.dart`
  - `lib/features/digital_score/presentation/digital_score_screen.dart`
  - `lib/features/digital_score/presentation/piano_score_view.dart`
  - `assets/alphatab/index.html`
  - `test/features/digital_score/presentation/playback_sequence_panel_test.dart`
  - `test/features/digital_score/presentation/alphatab_asset_test.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - 구간·반복 줄의 주황 테두리를 제거했다.
  - 오선 탭은 렌더 좌표로 마디를 찾고, 그 마디를 악보 위에 표시한다.
- 검증:
  - `flutter analyze --no-pub` 대상 변경 Dart 파일: 문제 없음
  - `flutter test --no-pub -j 1 --dart-define-from-file=dart_defines.json`: 전체 270개 통과
- 남은 일:
  - 폰에서 오선을 눌렀을 때 그 마디가 켜지는지 확인한다.

## 2026-09-20 00:30 KST — 원곡 조 빌드를 폰에 설치

- 작업자: Cursor Grok 4.6
- 목표: 원곡 조·선택 마디 강조가 들어간 debug APK를 SM-S937N에 넣는다
- 관련 로드맵: M8-06·M8-07 보완, B-017
- 변경 파일:
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - `flutter build apk --debug --no-pub --dart-define-from-file=dart_defines.json --target-platform android-arm64`로 `app-debug.apk` 239MB를 만들었다.
  - `adb install -r` Success 후 MainActivity를 실행했다.
- 검증:
  - 기기 `R5CY43JMZ7N` / SM-S937N, PID 22424, SHA-256 `c03b0e161bc1d7fbefcb5d0202827649c0d8a48491d97b5cdf040964d34c5428`
  - `versionName=1.0.0`, `lastUpdateTime=2026-09-20 00:02:35`
- 남은 일:
  - 폰에서 원곡 조와 연주 순서 선택 마디를 확인한다.

## 2026-09-20 00:25 KST — 원곡 조와 선택 구간 표시

- 작업자: Cursor Grok 4.6
- 목표: 이조 뒤에도 원곡 조를 남기고, 연주 순서에서 고른 마디와 구간을 구분한다
- 관련 로드맵: M8-06·M8-07 보완, B-017
- 변경 파일:
  - `lib/features/digital_score/presentation/score_transpose_panel.dart`
  - `lib/features/digital_score/presentation/playback_sequence_panel.dart`
  - `lib/features/digital_score/presentation/digital_score_screen.dart`
  - `lib/features/digital_score/data/digital_score_data.dart`
  - `lib/features/digital_score/data/digital_score_editor_service.dart`
  - `lib/core/storage/song_file_storage.dart`
  - `lib/features/library/data/song_repository.dart`
  - `assets/alphatab/index.html`
  - `lib/l10n/app_ko.arb`, `lib/l10n/app_en.arb`
  - `test/features/digital_score/presentation/score_transpose_panel_test.dart`
  - `test/features/digital_score/presentation/playback_sequence_panel_test.dart`
  - `test/features/digital_score/data/digital_score_editor_service_test.dart`
  - `test/core/storage/song_file_storage_test.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - 이조 시트에 원곡 조를 고정하고, 처음 연 조의 fifths를 sidecar에 한 번만 저장한다.
  - 연주 순서는 고른 마디 번호를 주황 칸으로 보여주고, 그 마디의 구간 행과 악보 위 선택 마디를 같은 색으로 강조한다.
- 검증:
  - `flutter analyze --no-pub` 대상 변경 Dart 파일: 문제 없음
  - `flutter test --no-pub -j 1 --dart-define-from-file=dart_defines.json`: 전체 271개 통과
- 남은 일:
  - 폰에서 원곡 조와 선택 마디 구분을 확인한다.

## 2026-09-20 00:15 KST — YDP 피아노 빌드를 폰에 설치

- 작업자: Cursor Grok 4.6
- 목표: 그랜드 피아노 음색이 들어간 최신 debug APK를 SM-S937N에 넣는다
- 관련 로드맵: M8-05 보완, B-017
- 변경 파일:
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - `flutter build apk --debug --no-pub --dart-define-from-file=dart_defines.json --target-platform android-arm64`로 `app-debug.apk` 239MB를 만들었다.
  - USB가 한번 끊긴 뒤 `adb install -r` Success, MainActivity를 실행했다.
- 검증:
  - 기기 `R5CY43JMZ7N` / SM-S937N, PID 18564, SHA-256 `fa101a472f46dbe7fb5501993f33abcc615a6dd2ecf2a9ad19bedd9f4b2c0bb5`
  - `versionName=1.0.0`, `lastUpdateTime=2026-09-19 23:52:53`
- 남은 일:
  - 폰에서 피아노 음색과, 악보를 나갈 때 재생이 멈추는지 확인한다.

## 2026-09-20 00:10 KST — 재생 음색을 그랜드 피아노 샘플로

- 작업자: Cursor Grok 4.6
- 목표: 기계음처럼 들리던 SONiVOX 합성음을 실제 피아노 샘플로 바꾼다
- 관련 로드맵: M8-05 보완, B-017
- 변경 파일:
  - `assets/alphatab/vendor/soundfont/ydp-grand-piano.sf2`
  - `assets/alphatab/vendor/soundfont/YDP-GrandPiano-NOTICE.txt`
  - `assets/alphatab/vendor/soundfont/CC-BY-3.0.txt`
  - `assets/alphatab/vendor/soundfont/README.md`
  - `assets/alphatab/index.html`
  - `assets/alphatab/THIRD_PARTY_NOTICES.md`
  - `test/features/digital_score/presentation/alphatab_asset_test.dart`
  - `test/features/digital_score/data/alphatab_asset_server_test.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - 1.3MB SONiVOX EAS를 제거하고 FreePats YDP Grand Piano(Yamaha Disklavier Pro 샘플, CC BY 3.0)를 앱 자산으로 넣는다.
  - 재생 엔진은 그대로 alphaTab 합성기이며, SoundFont 경로만 바꾼다.
- 검증:
  - `flutter test --no-pub -j 1 --dart-define-from-file=dart_defines.json`: 전체 267개 통과
  - SoundFont는 RIFF/`sfbk` 헤더와 CC BY 3.0 고지를 확인했다.
- 남은 일:
  - 폰에서 피아노 음색과 첫 재생 준비 시간을 확인한다.

## 2026-09-19 23:59 KST — 연주 순서·이조·나가면 정지

- 작업자: Cursor Grok 4.6
- 목표: 연주 순서를 역할·반복만 남기고, 이조를 단독 메뉴로 두며, 악보를 나가면 재생을 멈춘다
- 관련 로드맵: M8-06·M8-07 보완, B-017
- 변경 파일:
  - `lib/features/digital_score/presentation/digital_score_screen.dart`
  - `lib/features/digital_score/presentation/playback_sequence_panel.dart`
  - `lib/features/digital_score/presentation/piano_score_view.dart`
  - `lib/l10n/app_ko.arb`, `lib/l10n/app_en.arb`
  - `test/features/digital_score/presentation/playback_sequence_panel_test.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - 연주 순서는 오선에서 고른 마디에 벌스·코러스를 붙이고, 그 역할의 반복 횟수만 바꾼다.
  - 마디 번호·추가·순서·조표·박자와 반주 메뉴는 화면에서 뺀다.
  - 이조는 앱바 단독 버튼이다.
  - 악보 화면을 닫을 때 재생을 멈춘다.
- 검증:
  - `flutter analyze --no-pub` 대상 변경 Dart 파일: 문제 없음
  - `flutter test --no-pub -j 1 --dart-define-from-file=dart_defines.json`: 전체 267개 통과
- 남은 일:
  - 폰에서 나가면 정지, 연주 순서, 이조 버튼을 확인한다.

## 2026-09-19 23:55 KST — 재생 버튼은 되고 소리는 안 남

- 작업자: Cursor Grok 4.6
- 목표: 길이는 보이지만 재생·탐색이 안 되던 문제를 고친다
- 관련 로드맵: M8-05 보완, B-017
- 변경 파일:
  - `lib/features/digital_score/data/alphatab_asset_server.dart`
  - `lib/features/digital_score/presentation/piano_score_view.dart`
  - `lib/core/score_engine/alphatab_bridge.dart`
  - `assets/alphatab/index.html`
  - `android/app/src/main/AndroidManifest.xml`
  - `android/app/src/main/res/xml/network_security_config.xml`
  - `test/features/digital_score/data/alphatab_asset_server_test.dart`
  - `test/features/digital_score/presentation/alphatab_asset_test.dart`
  - `test/features/score_viewer/alphatab_bridge_test.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - Flutter 자산 로더는 워커/SoundFont fetch를 막아서, `127.0.0.1` 로컬 서버로 index·스크립트·sf2를 제공한다.
  - 재생은 출력 장치를 연 뒤 토글하고, 탐색은 엔진이 받은 위치를 Flutter 상태에 남긴다.
- 검증:
  - `flutter test --no-pub -j 1 --dart-define-from-file=dart_defines.json`: 전체 266개 통과
  - `flutter analyze --no-pub` 대상 변경 Dart 파일: 문제 없음
  - SM-S937N에 debug APK `adb install -r` Success, PID 13225, SHA-256 `2c8637846bf9b12f39023ced749660ad7821936acfc523819791d93613d393d8`
- 남은 일:
  - 폰에서 재생 소리와 탐색이 유지되는지 확인한다.

## 2026-09-19 23:50 KST — 전자악보 재생 0초 고정

- 작업자: Cursor Grok 4.6
- 목표: 재생이 안 되고 길이가 0:00으로만 보이던 문제를 고친다
- 관련 로드맵: M8-05 보완, B-017
- 변경 파일:
  - `assets/alphatab/index.html`
  - `lib/features/digital_score/domain/score_playback.dart`
  - `lib/features/digital_score/presentation/piano_score_view.dart`
  - `test/features/digital_score/domain/score_playback_test.dart`
  - `test/features/digital_score/presentation/alphatab_asset_test.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - WebView 워커가 `importScripts`로 alphaTab을 다시 받지 못해 합성기가 안 뜨는 경로를, 메인에서 받은 스크립트 블롭 워커로 바꿨다.
  - 길이는 `endTime`·틱·악보 템포/박자 추정으로 채우고, 재생을 켤 때 오디오 잠금을 연다.
- 검증:
  - `flutter test --no-pub -j 1 --dart-define-from-file=dart_defines.json`: 전체 264개 통과
  - SM-S937N에 debug APK `adb install -r` Success, PID 11355, SHA-256 `76f0b36afda26010f7f610c78154041048d0a2e0941b68d72538b7bbf81fc752`
- 남은 일:
  - 폰에서 재생을 켠 뒤 길이와 소리를 확인한다.

## 2026-09-19 23:45 KST — 마디 설정을 연주 순서로 분리

- 작업자: Cursor Grok 4.6
- 목표: 쓰기 메뉴에서 마디 설정·개수·순서를 빼고 연주 순서에서 다루며 바꿀 마디를 강조한다
- 관련 로드맵: M8-04·M8-06 보완, B-017
- 변경 파일:
  - `lib/features/digital_score/presentation/digital_score_screen.dart`, `score_editor_panel.dart`, `playback_sequence_panel.dart`, `piano_score_view.dart`
  - `lib/features/digital_score/domain/score_editor.dart`
  - `lib/core/score_engine/alphatab_bridge.dart`
  - `assets/alphatab/index.html`
  - `lib/l10n/app_ko.arb`, `lib/l10n/app_en.arb`
  - `test/features/digital_score/presentation/score_editor_panel_test.dart`, `playback_sequence_panel_test.dart`, `alphatab_asset_test.dart`
  - `test/features/digital_score/domain/score_editor_test.dart`
  - `test/features/score_viewer/alphatab_bridge_test.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - 쓰기 팔레트는 음가·쉼표·임시표와 실행 취소·삭제만 남겼다.
  - 연주 순서 패널에서 마디 번호·추가·순서 변경·삭제, 구간·조표·박자, 반복 순서를 바꾼다.
  - 선택한 마디는 번호 칩과 악보 주황 박스로 표시한다.
- 검증:
  - `flutter test --no-pub -j 1 --dart-define-from-file=dart_defines.json`: 전체 263개 통과
  - `flutter analyze --no-pub` 대상 변경 Dart 파일: 문제 없음
- 남은 일:
  - 폰에서 연주 순서 강조와 쓰기 메뉴가 음표만인지 확인한다.

## 2026-09-19 23:25 KST — 재생 길이 0초 고정 수정

- 작업자: Cursor Grok 4.6
- 목표: 재생을 켜도 시간이 0:00으로만 보이던 문제를 고친다
- 관련 로드맵: M8-05 보완, B-017
- 변경 파일:
  - `assets/alphatab/index.html`
  - `lib/features/digital_score/domain/score_playback.dart`
  - `lib/features/digital_score/presentation/piano_score_view.dart`
  - `lib/core/score_engine/alphatab_bridge.dart`
  - `test/features/digital_score/domain/score_playback_test.dart`
  - `test/features/digital_score/presentation/alphatab_asset_test.dart`
  - `test/features/score_viewer/alphatab_bridge_test.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - SoundFont 준비 직후 `endTime`이 0이어도 악보 MIDI가 생긴 뒤 길이를 다시 읽는다.
  - 0초 이벤트가 이미 아는 길이를 덮지 않는다.
- 검증:
  - `flutter test --no-pub -j 1 --dart-define-from-file=dart_defines.json`: 전체 263개 통과
  - `flutter analyze --no-pub` 대상 변경 Dart 파일: 문제 없음
  - SM-S937N에 `adb install -r` Success, PID 1735, SHA-256 `851a9c55e9876e54ecab748070598ca7594d44d425d966b7b9688c46ad818367`
- 남은 일:
  - 폰에서 재생을 켠 뒤 길이가 0:00이 아닌지 확인한다.

## 2026-09-19 23:20 KST — 구간·반복 분리와 선택 재생

- 작업자: Cursor Grok 4.6
- 목표: 벌스·코러스는 악보 수정에서, 반복은 별도 메뉴에서 다루고 재생 커서를 선택으로 만든다
- 관련 로드맵: M8-04·M8-05·M8-06 보완, B-017
- 변경 파일:
  - `lib/features/digital_score/domain/performance_score.dart`
  - `lib/features/digital_score/presentation/digital_score_screen.dart`, `score_editor_panel.dart`, `piano_score_view.dart`
  - `lib/core/score_engine/alphatab_bridge.dart`
  - `assets/alphatab/index.html`
  - `test/features/digital_score/domain/playback_sequence_test.dart`
  - `test/features/digital_score/presentation/score_editor_panel_test.dart`, `alphatab_asset_test.dart`
  - `test/features/score_viewer/alphatab_bridge_test.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - 쓰기 팔레트에서 현재 마디에 구간을 붙인다. 마디 설정에서는 구간을 뺐다.
  - 연주 순서 버튼에서만 반복 횟수와 순서를 바꾼다.
  - 재생은 기본 꺼짐이다. 켜야 재생 막대가 나오고, 실제로 재생 중일 때만 커서가 보이며 펼친 악보를 보여 준다.
  - 이조·코드·마디는 쓰기 중 도구, 반주는 연주 도구로 남겼다.
- 검증:
  - `flutter test --no-pub -j 1 --dart-define-from-file=dart_defines.json`: 전체 262개 통과
  - `flutter analyze --no-pub` 대상 변경 Dart 파일: 문제 없음
  - SM-S937N에 `adb install -r` Success, PID 32128, SHA-256 `92290649ef20a4183fb6315b88bb9350827d5f2335fa6e333418f5ed96bbfc10`
- 남은 일:
  - 폰에서 구간→반복→재생 켜기 순서를 확인한다.

## 2026-09-19 23:10 KST — 전자악보 재생 수정과 기능 분리

- 작업자: Cursor Grok 4.6
- 목표: 실기기 재생을 살리고 편집 UX를 재생/쓰기/도구로 나눈다
- 관련 로드맵: M8-04·M8-05 보완, B-017
- 변경 파일:
  - `assets/alphatab/index.html`
  - `lib/core/score_engine/alphatab_bridge.dart`
  - `lib/features/digital_score/presentation/digital_score_screen.dart`, `piano_score_view.dart`, `score_editor_panel.dart`
  - `android/app/src/main/AndroidManifest.xml`
  - `lib/l10n/app_ko.arb`, `lib/l10n/app_en.arb`
  - `test/features/digital_score/presentation/score_editor_panel_test.dart`, `alphatab_asset_test.dart`, `score_playback_bar_test.dart`
  - `test/features/score_viewer/alphatab_bridge_test.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - 재생 막대는 재생·정지·탐색만 남겼다.
  - 쓰기 모드는 음가·쉼표·임시표와 삭제·마디 추가만 두고 오선을 눌러 넣는다.
  - 이조·연주 순서·반주·코드·마디 설정은 도구 메뉴로 옮겼다.
  - alphaTab 출력을 `WebAudioScriptProcessor`로 바꿔 Android WebView AudioWorklet 실패를 피한다.
- 검증:
  - `flutter test --no-pub -j 1 --dart-define-from-file=dart_defines.json`: 전체 261개 통과
  - `flutter analyze --no-pub` 대상 변경 Dart 파일: 문제 없음
  - SM-S937N(R5CY43JMZ7N)에 `adb install -r` Success, MainActivity PID 31157, SHA-256 `77473528902a136855669f075ffdbaf7f4877a9e9b36ba8533d3c854a03f77d5`
- 남은 일:
  - 폰에서 재생과 오선 입력을 확인한다.

## 2026-09-19 22:53 KST — SM-S937N 최신 release 재설치

- 작업자: Cursor Grok 4.6
- 목표: 꺼져 있던 폰이 다시 켜진 뒤 오선 입력·재생·MXL 출처 선택이 들어간 APK를 넣는다
- 관련 로드맵: B-017
- 변경 파일:
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - `flutter build apk --release --dart-define-from-file=dart_defines.json --target-platform android-arm64`로 만든 `app-release.apk`(SHA-256 `6fa2daaf6a18c0c480e1dddc5136fd34bcb6dafb253636fc510285879b532571`, 75MB)를 SM-S937N(R5CY43JMZ7N)에 `adb install -r`로 넣었다.
  - MainActivity PID 26424, versionCode 2, lastUpdateTime 2026-09-19 22:52:41.
- 검증:
  - `adb install -r` Success, `am start` Success, `pidof` 26424
- 남은 일:
  - 폰에서 MusicXML 출처 선택, 오선 입력, 재생, 완료 여백, 내보내기·재열기를 확인한다.

## 2026-09-20 00:30 KST — MusicXML 가져오기 출처를 PDF와 맞춤

- 작업자: Cursor Grok 4.6
- 목표: MXL도 PDF처럼 기기·드라이브·Dropbox·WebDAV에서 고른다
- 관련 로드맵: M8-02 보완, M4-01·M4-02
- 변경 파일:
  - `lib/features/library/domain/score_file_filter.dart`
  - `lib/features/library/presentation/library_screen.dart`
  - `lib/features/storage/cloud/data/google_drive_service.dart`, `dropbox_service.dart`, `cloud_storage.dart`
  - `lib/features/storage/cloud/domain/cloud_models.dart`
  - `lib/features/storage/cloud/presentation/cloud_browser_screen.dart`
  - `lib/features/storage/data/webdav_connection.dart`
  - `lib/features/storage/presentation/webdav_browser_screen.dart`
  - `lib/app/router/app_router.dart`
  - `test/features/library/domain/score_file_filter_test.dart`
  - `test/features/storage/webdav_connection_test.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - Library에서 MusicXML을 고르면 PDF와 같은 출처 시트가 열린다.
  - Google Drive·Dropbox·WebDAV는 `.musicxml`·`.mxl`·`.xml`만 보여 준다.
- 검증:
  - `flutter test --no-pub -j 1 --dart-define-from-file=dart_defines.json`: 전체 261개 통과
  - `flutter analyze --no-pub` 대상 변경 파일: 문제 없음
- 남은 일:
  - 폰에 다시 설치해야 출처 선택이 보인다.

## 2026-09-20 00:10 KST — 전자악보 편집·재생·안내·여백

- 작업자: Cursor Grok 4.6
- 목표: 오선 직접 입력, 재생, 연주 순서/반주 안내, 완료 버튼 가림을 고친다
- 관련 로드맵: M8-04·M8-05·M8-06·M8-08 보완, B-017
- 변경 파일:
  - `assets/alphatab/index.html`
  - `lib/core/score_engine/alphatab_bridge.dart`
  - `lib/app/widgets/sheet_insets.dart`
  - `lib/features/digital_score/domain/staff_note_input.dart`, `score_playback.dart`
  - `lib/features/digital_score/presentation/digital_score_screen.dart`, `piano_score_view.dart`, `score_editor_panel.dart`, `score_playback_bar.dart`, `arrangement_panel.dart`, `playback_sequence_panel.dart`, `score_transpose_panel.dart`
  - `lib/features/library/presentation/create_music_xml_sheet.dart`, `library_screen.dart`
  - `lib/l10n/app_en.arb`, `app_ko.arb`, 생성된 `app_localizations*.dart`
  - `test/features/digital_score/domain/staff_note_input_test.dart` 및 관련 패널·bridge·자산 테스트
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - 음가·쉼표·임시표를 고른 뒤 오선을 누르면 음표가 바로 들어가고, 끌어 높이를 바꾼다.
  - 악보를 누르면 Web Audio를 열고, SoundFont가 늦어도 재생을 이어 받는다.
  - 벌스·코러스는 편집 줄의 구간에서 지정한다. 코드가 없으면 반주는 `코드 없음`이다.
  - 완료/저장 버튼은 시스템 뒤로·홈·최근앱 위에 뜨도록 하단 여백을 넣었다.
- 검증:
  - `flutter test --no-pub -j 1 --dart-define-from-file=dart_defines.json`: 전체 259개 통과
  - `flutter analyze --no-pub` 대상 변경 파일: 문제 없음
- 남은 일:
  - 폰에 다시 설치해야 네 가지 수정이 보인다.

## 2026-09-19 23:55 KST — 빈 피아노 악보 만들기

- 작업자: Cursor Grok 4.6
- 목표: 가져온 XML 없이 Library에서 전자악보를 직접 만든다
- 관련 로드맵: M8-04 보완
- 변경 파일:
  - `lib/features/digital_score/domain/blank_piano_score.dart`
  - `lib/features/digital_score/data/music_xml_import_service.dart`
  - `lib/features/library/presentation/create_music_xml_sheet.dart`, `library_screen.dart`
  - `lib/l10n/app_en.arb`, `app_ko.arb`, `app_ja.arb`, `app_zh.arb`, `app_la.arb`, 생성된 `app_localizations*.dart`
  - `test/features/digital_score/domain/blank_piano_score_test.dart`
  - `test/features/digital_score/data/music_xml_import_service_test.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - Library `+` → `악보 만들기`에서 곡명·아티스트·BPM을 넣고 빈 피아노 Grand Staff 한 마디를 저장한다.
  - 저장 후 편집 화면을 연다. 가져오기는 그대로다.
- 검증:
  - `flutter test --no-pub -j 1 --dart-define-from-file=dart_defines.json`: 전체 254개 통과
  - `flutter analyze --no-pub` 대상 생성 파일: 문제 없음
- 남은 일:
  - 폰에 다시 설치해야 `악보 만들기`가 보인다.

## 2026-09-19 23:45 KST — OpenLyrics 가사 XML 거부 안내

- 작업자: Cursor Grok 4.6
- 목표: `.xml`이 MusicXML이 아닐 때 기술 오류 대신 원인을 한 줄로 알린다
- 관련 로드맵: M8-02 보완
- 변경 파일:
  - `lib/features/digital_score/data/music_xml_codec.dart`
  - `test/features/digital_score/data/music_xml_codec_test.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - `21세기 새찬송가 - 괴로움과 고통을.xml`은 갓피플 OpenLyrics 가사다. 음표·보표가 없어 Score Document로 바꾸지 않는다.
  - OpenLyrics는 `가사 파일입니다`, score-timewise는 `이 악보 형식은 열 수 없습니다`, 그 밖은 `악보가 아닙니다`.
- 검증:
  - `flutter test --no-pub -j 1 --dart-define-from-file=dart_defines.json`: 전체 252개 통과
  - `flutter analyze --no-pub` 대상 코덱: 문제 없음
- 남은 일:
  - 폰에 다시 설치해야 새 안내가 보인다.

## 2026-09-19 23:35 KST — SM-S937N release 설치

- 작업자: Cursor Grok 4.6
- 목표: 연결된 폰에 최신 앱을 설치한다
- 관련 로드맵: B-017 설치 진행, smoke 대기
- 변경 파일:
  - `android/build.gradle.kts`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - pdfium CMake가 Android 타깃에서 심볼릭 링크를 쓰다 실패해서, Windows 호스트는 junction/복사로 우회했다.
  - `flutter build apk --release --dart-define-from-file=dart_defines.json --target-platform android-arm64` 성공. APK 74.4MB, SHA-256 `1299bd3c8998de5c229fac87f498118521aa21fb160e74b5d70601d1e9777c87`.
  - 서명 불일치로 기존 `com.hansookim.pageadiddle`을 지운 뒤 SM-S937N(R5CY43JMZ7N)에 설치하고 MainActivity(PID 9696)를 실행했다.
- 검증:
  - `adb install` Success, `am start` Success, `pidof` 9696
  - 가져오기·재생·내보내기 화면 확인은 하지 않았다
- 남은 일:
  - 같은 폰에서 MVP 8 전체 경로와 주석 PDF 재열기를 확인한다.

## 2026-09-19 23:15 KST — 클라우드 OAuth 키를 빌드 기본값으로 고정

- 작업자: Cursor Grok 4.6
- 목표: Google Drive·Dropbox 클라이언트 ID를 빌드마다 빠지지 않게 넣는다
- 관련 로드맵: M4-01·M4-02 보완, D-124, B-017 검증 대기
- 변경 파일:
  - `lib/features/storage/cloud/data/cloud_oauth_config.dart`
  - `dart_defines.json`
  - `.vscode/settings.json`, `.vscode/launch.json`
  - `.github/workflows/flutter_ci.yml`
  - `test/features/storage/cloud/cloud_oauth_config_test.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - 제품 기본 키를 소스에 두고, 빈 `--dart-define`이 있어도 OAuth를 끄지 않는다.
  - Cursor/VS Code 실행과 CI 테스트는 `dart_defines.json`을 항상 넘긴다.
  - `flutter build apk`에 플래그를 안 넣어도 소스 기본값으로 Drive·Dropbox 로그인을 연다.
  - 사용자는 이전에 실계정 다운로드가 된다고 확인했다.
- 검증:
  - `flutter test --no-pub -j 1 --dart-define-from-file=dart_defines.json`: 전체 251개 통과
  - `flutter analyze --no-pub` 대상 OAuth 설정: 문제 없음
- 남은 일:
  - B-017 해결 뒤 APK 재빌드에서 키 문자열과 실기기 가져오기를 다시 본다.

## 2026-09-19 22:50 KST — 구형 MusicXML `.xml` 내보내기

- 작업자: Cursor Grok 4.6
- 목표: 기획서의 `.musicxml`·구형 `.xml`·`.mxl` 읽기/쓰기 중 빠져 있던 `.xml` 내보내기를 맞춘다
- 관련 로드맵: M8-09 보완, B-017 검증 대기
- 변경 파일:
  - `lib/features/digital_score/data/score_export_service.dart`
  - `lib/features/digital_score/presentation/digital_score_screen.dart`
  - `test/features/digital_score/data/score_export_service_test.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - 내려받기 메뉴에 `.xml`을 넣었다. 바이트는 `.musicxml`과 같고 파일 이름만 다르다.
  - 가져오기는 이미 `musicxml|mxl|xml`을 허용한다.
- 검증:
  - `flutter test --no-pub -j 1`: 전체 250개 통과
  - `flutter analyze --no-pub` 대상 내보내기 파일: 문제 없음
  - `.xml`과 `.musicxml` 바이트가 같고 `<score-partwise version="4.0">`를 포함하며 다시 읽힌다.
- 남은 일:
  - B-017 해결 뒤 Android에서 내보내기·재열기·재생 전체 경로를 수동 검증한다.

## 2026-09-19 22:40 KST — 재구성 MusicXML·MIDI·PDF·프로젝트 내보내기

- 작업자: Cursor Grok 4.6
- 목표: M8-09에서 화면과 같은 이조·연주 순서·반주 결과를 새 파일로 내보낸다
- 관련 로드맵: M8-09 완료, B-017 검증 대기
- 변경 파일:
  - `lib/features/digital_score/domain/performance_score.dart`
  - `lib/features/digital_score/data/score_export_service.dart`, `midi_codec.dart`, `score_pdf_exporter.dart`, `score_project_codec.dart`
  - `lib/features/digital_score/presentation/digital_score_screen.dart`
  - `lib/l10n/app_en.arb`, `app_ko.arb`, 생성된 `app_localizations*.dart`
  - `test/features/digital_score/data/score_export_service_test.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - `.musicxml` `.mxl` `.mid` `.pdf`는 현재 편집본에 연주 순서와 반주를 펼친 점수를 쓴다.
  - PDF는 A4 가로 Grand Staff를 벡터로 조판하고 12마디마다 쪽을 나눈다.
  - 프로젝트 zip은 원본 MusicXML과 Sequence·반주 JSON만 담아 다시 열 수 있게 한다.
  - 모두 사용자가 고른 새 경로에 저장하며 앱 내부 원본은 덮어쓰지 않는다. 취소·실패 때도 원본은 그대로다.
- 검증:
  - `flutter test --no-pub -j 1`: 전체 249개 통과
  - `flutter analyze --no-pub` 대상 내보내기 파일: 문제 없음
  - INTRO×4→VERSE×2→CHORUS×1 MusicXML 7마디·반주 보존, SMF C4, 13마디 PDF 2쪽 이상, 프로젝트 왕복을 테스트했다.
  - Android에서 내보낸 PDF를 앱·일반 Viewer로 재여는 확인은 B-017로 남아 있다.
- 남은 일:
  - B-017 해결 뒤 Android에서 내보내기·재열기·재생 전체 경로를 수동 검증한다.
  - Future 서버 기능은 사용자가 순서를 바꾸기 전까지 시작하지 않는다.

## 2026-09-19 22:25 KST — 코드 기반 피아노 반주 프로필

- 작업자: Cursor Grok 4.6
- 목표: M8-08에서 코드 진행으로 기본 피아노 반주를 만들고 원본은 덮어쓰지 않는다
- 관련 로드맵: M8-08 완료, M8-09 진행 시작
- 변경 파일:
  - `lib/features/digital_score/domain/arrangement_profile.dart`
  - `lib/features/digital_score/data/digital_score_data.dart`, `digital_score_editor_service.dart`
  - `lib/features/digital_score/presentation/arrangement_panel.dart`, `digital_score_screen.dart`, `score_playback_bar.dart`
  - `lib/core/storage/song_file_storage.dart`, `lib/features/library/data/song_repository.dart`
  - `lib/l10n/app_en.arb`, `app_ko.arb`, 생성된 `app_localizations*.dart`
  - `test/features/digital_score/**`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - 끔/블록/박/분산 프로필만 `arrangement_profiles/<songId>.json`에 저장한다. MusicXML 음표는 바꾸지 않는다.
  - 코드 심벌에서 베이스와 화음을 만들고, 슬래시 베이스와 장·단·7·sus 간격을 규칙으로 처리한다.
  - 편집 화면은 원본을 보여 주고, 편집이 꺼져 있을 때만 Sequence를 펼친 뒤 반주를 올려 Grand Staff와 재생에 연결한다.
  - 곡 삭제·복제 시 sidecar도 함께 정리하거나 복사한다.
- 검증:
  - `flutter test --no-pub -j 1`: 전체 244개 통과
  - `flutter analyze --no-pub` 대상 digital_score 파일: 문제 없음
  - 블록 멜로디 보존, 박 4회, 분산 8분음, Am/C, JSON·sidecar, 시트·재생 막대를 테스트했다.
  - Android에서 반주 렌더·재생은 B-017로 남아 있다.
- 남은 일:
  - M8-09에서 이조·반주·Playback Sequence를 반영한 MusicXML·MIDI·PDF를 새 파일로 내보낸다.
  - B-017 해결 뒤 Android에서 반주 저장·재생·재열기를 수동 검증한다.

## 2026-09-19 22:10 KST — 음표·코드·조표 이조

- 작업자: Cursor Grok 4.6
- 목표: M8-07에서 반음 또는 목표 조로 음표·코드·조표를 이조하고 화면에 바로 반영한다
- 관련 로드맵: M8-07 완료, M8-08 진행 시작
- 변경 파일:
  - `lib/features/digital_score/domain/score_transpose.dart`, `music_score.dart`, `score_editor.dart`
  - `lib/features/digital_score/presentation/score_transpose_panel.dart`, `score_playback_bar.dart`, `digital_score_screen.dart`
  - `lib/l10n/app_en.arb`, `app_ko.arb`, 생성된 `app_localizations*.dart`
  - `test/features/digital_score/domain/score_transpose_test.dart`, `presentation/score_transpose_panel_test.dart`, `presentation/score_playback_bar_test.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - `TransposeScoreCommand`가 모든 파트의 음표 pitch, harmony root/bass, 마디 keyFifths를 같은 간격으로 옮긴다. 쉼표와 구간 표식은 그대로 둔다.
  - 조표는 5도권으로 옮긴 뒤 -7~7에 맞추고, 음이름은 각 마디의 도착 조표를 따른다. 같은 반음에서 C♯과 D♭를 구분할 수 있다.
  - 옥타브만 옮기면 조표는 유지한다. MIDI 0~127을 벗어나면 거부한다.
  - 재생 막대에서 반음 스테퍼와 목표 조를 고르면 undo 가능한 편집본과 Grand Staff·재생 타임라인이 바로 바뀐다.
- 검증:
  - `flutter test --no-pub -j 1`: 전체 234개 통과
  - `flutter analyze --no-pub lib/features/digital_score/domain/score_transpose.dart ...`: 문제 없음
  - C→D, C→D♭, C♯ 표기, +12 옥타브, 마디별 전조, undo, 범위 거부, 시트·재생 막대를 테스트했다.
  - Android에서 이조 후 렌더·재생은 B-017로 남아 있다.
- 남은 일:
  - M8-08에서 코드 진행 기반 기본 피아노 반주와 로컬 편곡 프로필을 구현한다.
  - B-017 해결 뒤 Android에서 이조·저장·재열기·재생을 수동 검증한다.
  - M8-09에서 이조·편곡·Playback Sequence를 반영한 전자악보 PDF를 내보낸다.

## 2026-09-19 21:55 KST — Playback Sequence와 펼친 재생 타임라인

- 작업자: Cursor Grok 4.6
- 목표: M8-06에서 Section 반복 횟수와 순서를 원본과 분리해 저장하고 재생 때 펼친다
- 관련 로드맵: M8-06 완료, M8-07 진행 시작
- 변경 파일:
  - `lib/features/digital_score/domain/playback_sequence.dart`, `music_score.dart`, `score_editor.dart`
  - `lib/features/digital_score/data/digital_score_data.dart`, `digital_score_editor_service.dart`
  - `lib/features/digital_score/presentation/digital_score_screen.dart`, `playback_sequence_panel.dart`, `score_editor_panel.dart`, `score_playback_bar.dart`
  - `lib/core/storage/song_file_storage.dart`, `lib/features/library/data/song_repository.dart`
  - `lib/l10n/app_en.arb`, `app_ko.arb`, 생성된 `app_localizations*.dart`
  - `test/features/digital_score/**`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - 마디 rehearsal 표식에서 INTRO/VERSE/PRE/CHORUS/BRIDGE/OUTRO 구간을 찾고, 순서와 1~16회 반복만 `playback_sequences/<songId>.json`에 저장한다.
  - 원본 MusicXML 마디는 복제하지 않는다. 편집 화면은 원본을 보여 주고, 편집이 꺼져 있을 때만 펼친 선형 악보를 alphaTab 재생과 Cursor에 올린다.
  - 마디 설정에서 구간을 지정하고, 재생 막대의 연주 순서 시트에서 항목을 추가·위아래 이동·횟수 변경·삭제한다.
  - 곡 삭제·복제 시 sidecar도 함께 정리하거나 복사한다.
- 검증:
  - `flutter test --no-pub -j 1`: 전체 223개 통과
  - `flutter analyze --no-pub lib/features/digital_score ...`: 문제 없음
  - `INTRO × 4 → VERSE × 2 → CHORUS × 1` 펼치기, 원본 불변, JSON 왕복, 알 수 없는 구간·256마디 초과 거부, sidecar 저장, 시트 편집을 테스트했다.
  - Android에서 펼친 악보 재생·Cursor는 B-017로 남아 있다.
- 남은 일:
  - M8-07에서 목표 조 또는 반음 단위 이조를 음표·코드·조표에 적용한다.
  - B-017 해결 뒤 Android에서 Sequence 저장·펼친 재생·재열기를 수동 검증한다.
  - M8-09에서 펼친 선형 Grand Staff PDF 내보내기를 구현한다.

## 2026-09-19 21:45 KST — 로컬 피아노 재생과 Bar/Beat Cursor

- 작업자: Cursor Grok 4.6
- 목표: M8-05에서 확정한 alphaTab MIDI 합성기 + SONiVOX SoundFont 경로를 구현하고 재생 위치와 Cursor를 하나의 타임라인으로 묶는다
- 관련 로드맵: M8-05 완료, M8-06 진행 시작
- 변경 파일:
  - `assets/alphatab/index.html`, `assets/alphatab/vendor/soundfont/**`, `assets/alphatab/THIRD_PARTY_NOTICES.md`
  - `lib/core/score_engine/alphatab_bridge.dart`
  - `lib/features/digital_score/domain/score_playback.dart`
  - `lib/features/digital_score/presentation/piano_score_view.dart`, `score_playback_bar.dart`, `digital_score_screen.dart`
  - `pubspec.yaml`
  - `test/features/digital_score/**`, `test/features/score_viewer/alphatab_bridge_test.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - 기존 flutter_soloud 메트로놈/PDF 오디오와 별도 Dart 음원 타이머를 쓰지 않고, alphaTab 1.8.4 플레이어와 공식 SONiVOX `sonivox.sf2`를 로컬 자산으로 고정했다.
  - 재생·일시정지·정지·탐색 명령을 bridge로 보내고, `playerReady`·위치·`playedBeatChanged`로 같은 타임라인의 마디/박을 받는다.
  - alphaTab `enableCursor`로 실제 렌더 Bar/Beat Cursor를 표시하고, 전자악보 화면에 아이콘 재생 막대를 연결했다.
  - Android WebView는 사용자 제스처 없이 미디어 재생을 허용하고 Flutter asset 호스트만 탐색한다. SoundFont·폰트·렌더러 하위 경로를 `pubspec.yaml`에 명시했다.
- 검증:
  - `flutter test --no-pub -j 1`: 전체 215개 통과
  - `flutter analyze --no-pub lib/features/digital_score lib/core/score_engine/alphatab_bridge.dart`: 문제 없음
  - SoundFont 존재·라이선스, 로컬 player 설정, 재생 bridge 이벤트, 재생 막대 활성/비활성·탐색 위젯 테스트를 확인했다.
  - Android WebView 실제 청취와 Cursor 추적은 B-017로 남아 있다.
- 남은 일:
  - M8-06에서 Section 반복 횟수와 순서를 Playback Sequence로 저장하고 재생 타임라인에 펼친다.
  - B-017 해결 뒤 Android에서 MusicXML 재생·Cursor·편집·저장·재열기를 수동 검증한다.
  - M8-09에서 Playback Sequence·이조·반주 결과까지 펼친 전자악보 PDF 내보내기를 구현한다.

## 2026-09-19 20:07 KST — 피아노 전자악보 작성·수정과 undo/redo

- 작업자: Codex
- 목표: M8-04 내부 Score Document를 Android 앱에서 직접 작성·수정하고 안전하게 저장
- 관련 로드맵: M8-04 완료, M8-05 진행 시작
- 변경 파일:
  - `lib/features/digital_score/domain/music_score.dart`, `score_editor.dart`
  - `lib/features/digital_score/data/digital_score_editor_service.dart`
  - `lib/features/digital_score/presentation/digital_score_screen.dart`, `piano_score_view.dart`, `score_editor_panel.dart`
  - `lib/core/score_engine/alphatab_bridge.dart`, `lib/core/storage/song_file_storage.dart`
  - `assets/alphatab/index.html`
  - `lib/l10n/app_en.arb`, `app_ko.arb`, 생성된 `app_localizations*.dart`
  - `test/features/digital_score/**`, `test/features/score_viewer/alphatab_bridge_test.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - Score Document의 parts·measures·events 컬렉션을 외부에서 바꿀 수 없는 불변 모델로 만들고 삽입·교체·삭제·조표/박자표·마디 추가/삭제 명령을 구현했다.
  - 전체 Score Document 스냅샷을 최대 100단계 보관해 undo/redo, 저장 지점 dirty 판정과 분기 이력 제거를 처리한다.
  - 같은 성부·위치의 음표를 MusicXML chord로 자동 정규화하고 같은 성부에서 쉼표가 다른 이벤트와 겹치는 입력, 마디 길이를 넘는 음표, 기존 음표가 들어가지 않는 짧은 박자표 변경을 거부한다.
  - alphaTab note bounds의 `noteMouseDown`을 part·measure·staff·onset·MIDI 정보로 전달해 렌더링된 음표를 직접 선택한다. 쉼표와 코드 심벌을 포함한 마디 이벤트는 악보 아래 가로 목록에서도 선택한다.
  - 음표/쉼표의 음높이·임시표·옥타브·음가·위치·보표·성부, 코드 심벌의 root·종류·위치, 마디의 조표·박자표를 입력·수정하는 시트를 추가했다.
  - 편집 변경마다 현재 Score Document를 MusicXML로 다시 직렬화해 Grand Staff를 즉시 재조판하고, 저장 전 이탈 시 저장·버리기·취소를 선택한다.
  - 가져온 앱 내부 `.musicxml`/`.mxl` 형식을 유지해 코덱 왕복 검증 후 같은 디렉터리 임시 파일과 백업으로 원자 교체한다. 실패하면 기존 파일을 복원하고 MusicXML/MXL 내보내기는 저장 여부와 관계없이 현재 편집본을 사용한다.
- 검증:
  - `flutter test --no-pub -j 1`: 전체 207개 통과
  - `flutter analyze lib/features/digital_score lib/core/score_engine/alphatab_bridge.dart lib/core/storage/song_file_storage.dart`: 문제 없음
  - `flutter analyze --no-pub`: 신규 오류·경고 없음. 기존 ScoreViewer 미사용 private method 4건과 Setlist `onReorder` deprecation 1건만 남음
  - MusicXML/MXL 형식 유지 저장·재검증·빈 교체 거부, 불변 컬렉션·undo/redo·다중 파트 마디·동시음 chord·겹침 방어·렌더 음표 주소 매핑, 편집 패널·쉼표 시트를 자동 테스트했다.
- 남은 일:
  - M8-05에서 로컬 피아노 재생 타임라인과 실제 Bar/Beat Cursor를 구현한다.
  - B-017 해결 뒤 Android WebView에서 음표 직접 선택, 편집·회전 재조판, MusicXML/MXL 저장·앱 재실행 후 재열기를 수동 검증한다.
  - M8-09에서 Playback Sequence·이조·반주 결과까지 펼친 전자악보 PDF 내보내기를 구현한다.

## 2026-09-19 19:41 KST — 오프라인 피아노 Grand Staff 렌더링

- 작업자: Codex
- 목표: M8-03 내부 Score Document를 Android 전자악보 화면에서 피아노 Grand Staff로 표시하고 화면 폭에 맞춰 재배치
- 관련 로드맵: M8-03 완료, M8-04 진행 시작
- 변경 파일:
  - `assets/alphatab/index.html`, `assets/alphatab/THIRD_PARTY_NOTICES.md`, `assets/alphatab/vendor/**`
  - `lib/core/score_engine/alphatab_bridge.dart`
  - `lib/features/digital_score/presentation/digital_score_screen.dart`, `piano_score_view.dart`
  - `test/features/score_viewer/alphatab_bridge_test.dart`
  - `test/features/digital_score/presentation/alphatab_asset_test.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - `@coderline/alphatab` 1.8.4의 브라우저 SVG 렌더러와 Bravura WOFF2·WOFF·OTF를 앱 자산으로 고정하고 MPL-2.0·OFL-1.1 라이선스를 포함했다.
  - 기존 `@latest` CDN 의존성과 드럼 트랙 필터를 제거했다. 렌더러는 `file://` Flutter asset만 사용하고 worker와 재생 사운드폰트는 M8-05 전까지 포함하지 않는다.
  - 내부 Score Document를 정규화 MusicXML로 직렬화해 alphaTab에 전달하고, 한 피아노 파트의 두 staff뿐 아니라 파일의 모든 part를 렌더링한다.
  - page layout·자동 bars-per-row와 480dp/840dp 폭 경계 스케일을 적용해 모바일·태블릿 크기 변경 때 악보 시스템을 다시 조판한다.
  - 전자악보 화면의 메타데이터 요약을 실제 악보 우선 화면으로 바꾸고 WebView 준비·렌더 완료·오류·재시도 상태를 연결했다.
  - JavaScript 숫자가 int 또는 double로 전달돼도 안전하게 읽고 렌더 시작·완료·viewport width 이벤트를 처리하도록 bridge를 보강했다.
- 검증:
  - headless Chrome `file://` runtime smoke: alphaTab 준비, MusicXML 수용, score surface 1개와 SVG 3개 생성 확인
  - runtime 캡처에서 피아노 중괄호, 높은음자리표·낮은음자리표와 양손 Grand Staff 표시 확인 후 임시 프로필·캡처 삭제
  - `flutter test`: 전체 193개 통과
  - `flutter analyze`: 신규 오류·경고 없음. 기존 ScoreViewer 미사용 private method 4건과 Setlist `onReorder` deprecation 1건만 남음
  - 로컬 자산·버전 고정·라이선스·CDN 부재·반응형 설정과 bridge 회귀 테스트 19개 통과
- 남은 일:
  - M8-04에서 선택 가능한 음표·쉼표·마디 편집 모델과 undo/redo 명령을 구현한다.
  - Windows 개발자 모드 또는 심볼릭 링크 권한 환경에서 APK를 빌드하고 Android 실기기 MusicXML 열기·회전 재배치·스크롤을 확인한다(B-017).
  - M8-05에서 사운드폰트 또는 MIDI 재생 방식을 결정하고 Bar/Beat Cursor를 실제 렌더 위치와 연결한다.

## 2026-09-19 19:19 KST — MusicXML/MXL 내부 악보 모델과 로컬 가져오기·내보내기

- 작업자: Codex
- 목표: M8-02 피아노 전자악보의 내부 Score Document를 만들고 MusicXML/MXL 파일을 Library에서 가져와 다시 내보내는 Android 로컬 흐름 구현
- 관련 로드맵: M8-02 완료, M8-03 진행 시작
- 변경 파일:
  - `lib/features/digital_score/**`
  - `lib/features/library/domain/score_type.dart`
  - `lib/features/library/data/song_repository.dart`
  - `lib/features/library/presentation/import_score_sheet.dart`, `library_screen.dart`, `score_thumbnail.dart`
  - `lib/core/storage/song_file_storage.dart`, `lib/app/router/app_router.dart`
  - `test/features/digital_score/**`, `test/core/storage/song_file_storage_test.dart`, `test/features/library/song_repository_test.dart`
  - `pubspec.yaml`, `pubspec.lock`
  - `드럼 악보 앱 기획서 v4.md`, `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - MusicXML 4.0 `score-partwise`를 피아노 중심 내부 모델로 정규화했다. part·measure·attributes·staff·voice·onset·duration·pitch·rest·chord·grace·tie·tempo·rehearsal·harmony를 표현한다.
  - MusicXML의 `backup`·`forward`를 보이스별 절대 onset으로 읽고, 내보낼 때 다시 유효한 다중 보이스 순서로 직렬화한다.
  - `.musicxml`·`.xml`과 표준 `.mxl`을 읽고 쓴다. MXL은 첫 `mimetype` 엔트리를 비압축으로 두고 `META-INF/container.xml` rootfile을 사용한다.
  - MXL 엔트리 수·압축 해제 크기·rootfile 크기를 제한하고 절대 경로·상위 경로·Windows drive 경로를 거부한다.
  - Library `+`에서 PDF와 MusicXML을 선택하고, MusicXML의 곡명·작곡가·템포를 등록 폼에 자동 채우도록 연결했다.
  - Songs의 `scoreType=musicxml`을 보존하고 메타데이터 수정·복제에서 PDF로 덮어쓰지 않도록 저장소를 수정했다.
  - 공통 `/score/:songId` 진입점에서 PDF Viewer와 전자악보 화면을 유형별로 분기하고, 전자악보 화면에서 정규화 결과 확인과 `.musicxml`·`.mxl` 저장을 지원한다.
  - Library 썸네일에서 전자악보를 XML 유형으로 구분한다.
- 검증:
  - `flutter test`: 전체 191개 통과
  - MusicXML/MXL 코덱 6개, import 서비스 2개, 저장소·scoreType 회귀 테스트 통과
  - `flutter analyze`: 이번 변경 오류·신규 경고 없음. 기존 ScoreViewer 미사용 private method 4건과 Setlist `onReorder` deprecation 1건만 남음
  - 공식 W3C MusicXML 4.0의 score-partwise 구조, 다중 staff·voice의 backup/forward, MXL container·mimetype 규격을 구현 기준으로 확인
- 남은 일:
  - M8-03에서 내부 Score Document를 실제 피아노 Grand Staff로 렌더링하고 화면 너비별 시스템 재배치를 구현한다.
  - Windows 개발자 모드 또는 심볼릭 링크 권한 환경에서 Android APK를 빌드하고 MusicXML 가져오기·열기·두 형식 저장 smoke를 수행한다(B-017).
  - score-timewise·unpitched는 현재 피아노 범위 밖이며, 빔·슬러·아티큘레이션·tuplets의 정밀 표기는 M8-03~04 렌더링·편집 범위에서 확장한다.

## 2026-09-19 18:45 KST — 재구성 전자악보 PDF 내보내기 요구사항 확정

- 작업자: Codex
- 목표: 이조·편곡·반복 순서를 적용해 재구성한 전자악보를 Android에서 PDF로 내보내는 요구사항을 MVP 8 완료 조건에 반영
- 변경 파일:
  - `드럼 악보 앱 기획서 v4.md`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - 기존 PDF에 펜 주석을 합성하는 M8-01과 전자악보 음표 데이터를 다시 조판하는 M8-09를 별도 기능으로 구분했다.
  - M8-09 PDF에 작성·수정 내용, 현재 조·이조, 반주·편곡 프로필과 Playback Sequence의 Section 순서·반복 횟수를 반영하도록 확정했다.
  - `INTRO × 4 → VERSE × 2 → CHORUS × 1`은 반복 기호만 추가하지 않고 마디를 해당 순서대로 실제 펼친 선형 Grand Staff PDF로 생성하도록 완료 조건을 추가했다.
  - Android 앱 내부 오프라인 처리, 새 파일 저장, 원본 Score Document 보존, 앱·일반 PDF Viewer 재열기와 다중 페이지 조판 검증을 명시했다. iOS는 계속 범위에서 제외한다.
- 검증:
  - 문서 전용 변경으로 코드 테스트는 재실행하지 않았다.
  - ROADMAP 완료/전체 수는 72/101로 변동 없다.
- 남은 일:
  - M8-02 Score Document에서 Section 반복·이조·편곡 상태를 손실 없이 표현해 이후 M8-09 PDF 조판의 단일 입력으로 사용한다.

## 2026-09-19 18:37 KST — 로컬 피아노 전자악보 기획 재개와 주석 PDF 내보내기

- 작업자: Codex
- 목표: 서버 기능은 후순위로 분리하고 앱 내부 피아노 전자악보 개발 계획을 확정한 뒤, PDF 펜 주석을 포함한 비파괴 내보내기를 첫 기능으로 구현
- 변경 파일:
  - `드럼 악보 앱 기획서 v4.md`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
  - `lib/features/score_viewer/data/annotated_pdf_exporter.dart`
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `lib/features/score_viewer/presentation/viewer_settings_sheet.dart`
  - `lib/l10n/app_en.arb`, `lib/l10n/app_ko.arb`, `lib/l10n/app_localizations*.dart`
  - `pubspec.yaml`, `pubspec.lock`
  - `test/features/score_viewer/annotated_pdf_exporter_test.dart`
  - `test/core/storage/song_file_storage_test.dart`
  - `android/gradle.properties`, `lib/app/theme/app_theme.dart`
- 완료 내용:
  - MusicXML/MXL을 전자악보 교환 기준으로 두고 작성·수정·재생·Section 반복 순서·이조·기본 피아노 반주·MusicXML/MIDI/PDF/앱 프로젝트 내보내기를 MVP 8 로컬 우선 항목으로 재구성했다.
  - PDF→MusicXML OMR, 스트링·오르간·브라스 고급 AI 편곡, 레퍼런스 영상 분석과 음색 조합 추천은 서버 기반 Future로 분리했다.
  - Viewer 설정에 `주석 포함 PDF 내보내기`를 추가했다. 원본 PDF 페이지를 렌더링하고 저장된 정규화 펜 stroke를 합성해 새 PDF를 만들며, 원본 PDF와 편집 가능한 주석 JSON은 변경하지 않는다.
  - 지우개는 주석 전용 투명 레이어에만 적용해 원본 악보 인쇄 내용을 지우지 않도록 했다. 긴 문서는 페이지별 최대 렌더 크기를 제한하고 파일 저장 중 중복 요청을 막는다.
  - Flutter 3.44 자동 Android 마이그레이션 플래그와 Cupertino 전환 import를 반영하고, Windows에서도 기존 저장소 테스트가 경로 구분자에 의존하지 않도록 보정했다.
- 검증:
  - `flutter test --no-pub -j 1`: 전체 181개 통과
  - `flutter analyze --no-pub`: 오류 없음. 기존 ScoreViewer 미사용 private method 경고 4건과 Flutter 3.44에서 표시된 Setlist `onReorder` deprecation 1건
  - `dart format`: 변경 Dart 파일 형식 통과
  - 주석 합성 테스트: 안전한 파일명, 색상 펜, 지우개가 원본을 보존하는 동작, 잘못된 BGRA 크기 거부 통과
  - `flutter build apk --debug --no-pub`: Google Sign-In Kotlin 증분 산출물은 재생성했으나 `pdfium_flutter` CMake가 Windows 심볼릭 링크 권한 부족으로 `.lib/latest`를 만들지 못해 중단
- 남은 일:
  - B-017 환경에서 Android debug APK를 다시 빌드하고 실기기 파일 저장·재열기 smoke를 수행한다.
  - M8-02에서 피아노 Grand Staff 최소 범위의 내부 Score Document 모델과 MusicXML/MXL 왕복 parser를 구현한다.

## 2026-08-31 11:01 KST — 메트로놈·주석 경계 검수와 Android 설치

- 작업자: Codex
- 목표: 메트로놈 런타임 오류 분기를 보강하고 설정·타임라인·주석 입력 경계를 낱낱이 회귀 검증한 뒤 최신 Android APK를 설치
- 변경 파일:
  - `lib/features/tools/domain/metronome_sequence.dart`
  - `lib/features/tools/data/metronome_settings.dart`
  - `lib/features/tools/data/metronome_click_player.dart`
  - `lib/features/tools/presentation/metronome_screen.dart`
  - `lib/features/tools/presentation/tempo_trainer_screen.dart`
  - `lib/features/score_viewer/domain/annotation_stroke.dart`
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `test/features/tools/metronome_sequence_test.dart`
  - `test/features/tools/metronome_settings_test.dart`
  - `test/features/score_viewer/annotation_stroke_test.dart`
  - `test/features/jam/jam_metronome_sync_test.dart`
  - `test/features/jam/jam_clock_sync_test.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - BPM 40~240, 연음 1~6, 박자표 1~12, Count-In 없음/1/2/4마디, 악센트 강·기본·뮤트, 마디 순환·절대 step·음수 입력·JSON 구형/손상 입력의 보정·무시 경계를 테스트했다.
  - 중복 시작, 정지·곡 전환 중 남은 voice, 비동기 stale 재생 요청, Count-In 1~12 음성 자산 선행 로딩을 방어했다.
  - malformed/non-finite 주석 좌표·색·선 굵기·투명도를 안전하게 건너뛰거나 범위 보정했다.
  - `metronome` 패키지는 현재 per-beat 악센트·연음·Count-In·Jam 절대 timeline을 대체하지 못하고, `pdf_annotations`는 현재 `pdfrx` renderer와 교체 비용·낮은 채택도가 있어 신규 의존성으로 넣지 않았다. 기존 `flutter_soloud`·`pdfrx`를 유지했다.
- 검증:
  - `flutter test -j 1`: 전체 177개 통과
  - `flutter analyze --no-pub`: 기존 `score_viewer_screen.dart` 미사용 private method 경고 4개만 남음
  - `dart format --output=none --set-exit-if-changed`: 통과
  - `flutter build apk --release`: 성공, [app-release.apk](../build/app/outputs/flutter-apk/app-release.apk), SHA-256 `90ef58d3d521a65afccf10764fdb960f184a47cc36abcce1b8f52f83c5104c06`
  - `emulator-5554`에 versionCode 2 재설치·PID 실행 확인. 메트로놈 Start→박자 표시→Stop smoke와 치명 예외 없는 로그를 확인했다.
- 남은 일:
  - 현재 ADB에는 `emulator-5554`만 연결되어 실제 Android 기기 스피커/이어폰 청취와 두 기기 Jam 동시성은 B-005/B-012에서 수동 검증한다.

## 2026-08-27 17:13 KST — Jam 혼합 보기 모드·메트로놈 동기화 보강

- 작업자: Codex
- 목표: 호스트·참가자의 맞춤/2쪽/스크롤 보기 조합에서 페이지 전환을 즉시 반영하고 기기별 메트로놈 시작 시차를 줄임
- 변경 파일:
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - Jam 원격 페이지를 각 기기의 로컬 보기 모드 기준으로 정규화해 2쪽 보기의 동일 스프레드 재이동을 막았다.
  - Member가 startAt까지 기다린 뒤 오디오 자산을 준비하던 순서를 제거해, 자산을 먼저 준비하고 공통 startAt/로컬 clock offset에서 클릭을 시작하도록 했다.
  - 실행 중 clock offset 보정은 현재 마디를 유지하고 다음 마디부터 새 offset을 사용하도록 수정했다.
- 검증:
  - `dart format --set-exit-if-changed`: 통과
  - `flutter analyze --no-pub`: 기존 `score_viewer_screen.dart` 미사용 private method 경고 4개만 남음
  - `flutter test -j 1`: 전체 154개 통과
  - `flutter build apk --release`: 성공
  - APK SHA-256 `6b9b5358a50a8eaef5f89022ff5438a4c6e584a92bc7155ada5c87002ecec756`
  - `emulator-5554`에 versionCode 2 재설치·앱 실행·설치 APK 해시 일치 확인
- 남은 일:
  - 새 실기기가 현재 ADB에서 빠져 실제 3기기 혼합 보기·메트로놈 청취는 기기 재연결 후 B-012/B-005에서 확인한다.

## 2026-08-27 16:21 KST — 합주 Follow 다음 곡 자동 진입 수정

- 작업자: Codex
- 목표: 참가자 Viewer가 방장 곡 변경을 감지하고 다음 악보로 자동 진입
- 변경 파일:
  - `lib/features/jam/presentation/jam_session_screen.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - 참가자 화면이 이미 악보 라우트를 열고 있어도 세션의 `currentEntryId`가 바뀌면 새 곡을 연다.
  - 같은 곡의 재시작·메트로놈 상태 갱신에는 중복 라우팅하지 않는다.
- 검증:
  - `dart format --set-exit-if-changed`: 통과
  - `flutter analyze --no-pub`: 기존 `score_viewer_screen.dart` 미사용 private method 경고 4개만 남음
  - `flutter test -j 1`: 전체 154개 통과
  - `flutter build apk --release`: 성공
  - APK SHA-256 `9862af2986df1378a04fda4d67867c4f871dd8382f982fc3060200df3b95a61f`
  - `R54Y600GBKY`(SM-X620)·`emulator-5554`에 versionCode 2 재설치 및 앱 프로세스 실행 확인
- 남은 일:
  - 실제 두 Android 기기에서 방장 곡 변경→참가자 자동 진입과 공통 메트로놈을 수동 확인한다(B-012/B-005).

## 2026-08-27 16:11 KST — Viewer 세트리스트 다음 악보 전환 수정

- 작업자: Codex
- 목표: 악보 따라가기/끝 페이지에서 다음 세트리스트 악보가 열리지 않는 경로 수정
- 변경 파일:
  - `lib/app/router/app_router.dart`
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - `/score/:songId`의 고정 `state.pageKey` 대신 실제 URI를 페이지 키로 사용해 곡 교체 시 PDF Viewer의 기존 State·컨트롤러를 재사용하지 않도록 했다.
  - 마지막 페이지의 다음/이전 곡 이동에서 setlist stream이 아직 로딩 중이어도 `SetlistRepository.getItems()` 최신 snapshot으로 진행 정보를 재확인한다.
  - 오디오가 끝나면 수동 자동진행 일시정지 상태가 아닌 경우 다음 세트리스트 악보를 연다.
- 검증:
  - `dart format --set-exit-if-changed`: 통과
  - `flutter analyze --no-pub`: 기존 `score_viewer_screen.dart` 미사용 private method 경고 4개만 남음
  - `flutter test -j 1`: 전체 154개 통과
  - `flutter build apk --release`: 성공
  - APK SHA-256 `aec70656ded600c16d6dc5b9d39992f83242475bf6fa0bc9b113045e7ba5041f`
  - `R54Y600GBKY`(SM-X620)·`emulator-5554`에 versionCode 2 재설치 및 앱 프로세스 실행 확인
- 남은 일:
  - 실제 기기에서 악보 따라가기 오디오 종료→다음 곡 전환과 두 Android 기기 Jam 곡 전환·오디오 동시성을 수동 확인한다(B-012/B-005).

## 2026-08-27 14:51 KST — Jam 현재 곡·핵심 동작 플로팅 컨트롤 통합

- 작업자: Codex
- 목표: 합주 화면에서 현재 선택된 곡과 시작/정지·준비 동작을 스크롤과 분리된 한 위치에 고정
- 변경 파일:
  - `lib/features/jam/presentation/jam_session_screen.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - 기존 현재 곡 카드의 중복 시작/준비 UI를 제거하고 화면 하단에 현재 곡 플로팅 컨트롤을 추가했다.
  - 곡 제목 영역을 탭하면 악보를 열고, Conductor는 이전·다음 곡과 시작/정지를, Member는 준비 토글을 같은 바에서 처리한다.
  - Member가 아직 곡을 받지 않은 상태에서도 준비 버튼을 사용할 수 있도록 빈 곡 상태를 유지했다.
  - 스크롤 하단 패딩과 SafeArea를 적용해 마지막 참가자/설정이 플로팅 바에 가려지지 않게 했다.
- 검증:
  - `flutter test -j 1`: 전체 154개 통과
  - `flutter analyze --no-pub`: 기존 `score_viewer_screen.dart` 미사용 private method 경고 4개만 남음
  - `dart format`: 변경 파일 통과
  - `flutter build apk --release` 성공
  - APK SHA-256 `1143faebd8417ed18902b68187997522943788b18d0a2927541d84ba60364a0d`
  - `R54Y600GBKY`(SM-X620)·`RFKL40AXPCP`(SM-F966N)·`emulator-5554`에 versionCode 2 재설치, 앱 프로세스 실행 확인
- 남은 일:
  - 실제 두 Android 기기에서 플로팅 시작/준비 동작과 참가자별 보기 모드·오디오 동시성을 수동 확인한다(B-012/B-005).

## 2026-08-27 14:30 KST — Viewer 페이지 경계와 Jam 로컬 보기 모드 보강

- 작업자: Codex
- 목표: 맞춤·2쪽 보기에서 다음 페이지가 비치는 문제를 막고, 합주 참가자별 보기 방식 차이를 안전하게 처리
- 변경 파일:
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - `맞춤`·`2쪽` 모드의 매트릭스를 현재 페이지/스프레드 영역으로 정규화해 세로 스크롤·두 손가락 이동·휠로 다음 페이지가 노출되지 않게 했다.
  - 페이지 선택·마디 이동·오디오 진행·Jam 원격 위치·세트리스트 곡 이동을 공통 `_goToViewerPage` 경로로 통일했다.
  - `스크롤` 모드만 연속 세로 이동과 마우스 휠을 허용한다.
  - Jam은 보기 모드를 공유하지 않고 각 기기의 맞춤·2쪽·스크롤 설정을 유지한다. 호스트의 논리 페이지/마디를 각 로컬 모드의 표시 방식으로 매핑한다.
- 검증:
  - `flutter test -j 1`: 전체 154개 통과
  - `flutter analyze --no-pub`: 기존 `score_viewer_screen.dart` 미사용 private method 경고 4개만 남음
  - `flutter build apk --release` 성공
  - APK SHA-256 `9c1e6cedfa1c3cd749540c54530737e62436f1d490f17ca9d9fc702d440326bd`
  - `R54Y600GBKY`(SM-X620)·`RFKL40AXPCP`(SM-F966N)·`emulator-5554`에 versionCode 2 재설치, 앱 프로세스 실행 확인
- 남은 일:
  - 실제 두 Android 기기에서 참가자별 보기 모드 조합(맞춤/2쪽/스크롤), 원격 페이지 표시와 오디오 동시성을 수동 확인한다(B-012/B-005).

## 2026-08-27 14:12 KST — 주변 방·곡별 메트로놈 UI와 무대 시작 보강

- 작업자: Codex
- 목표: 주변 방 목록 여백과 Wi-Fi 미연결 안내를 보강하고, Jam 곡 선택·곡별 메트로놈 설정 흐름과 무대 시작 오류를 정리
- 변경 파일:
  - `lib/features/jam/presentation/jam_hub_screen.dart`
  - `lib/features/jam/presentation/jam_session_screen.dart`
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `lib/features/tools/data/metronome_click_player.dart`
  - `lib/l10n/app_*.arb`, 생성된 localization 파일
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - 주변 방 카드의 내부·항목 간 여백을 늘리고, 검색 실패를 화면 안의 Wi-Fi 안내로 표시한다. 안내 문구는 Wi-Fi를 켠 뒤 다시 시도하도록 명시한다.
  - Jam 화면에서 세트리스트와 곡 선택을 곡별 메트로놈 설정 위로 배치하고 설정 카드를 분리해 현재 곡 변경과 설정 값을 한 흐름으로 보이게 한다.
  - 무대/Jam 자동 시작은 클릭 자산을 먼저 준비한 뒤 세션 playing을 갱신하도록 순서를 바꿨다. Count-In 음성은 첫 필요 시 지연 로딩해 불필요한 시작 실패를 줄이고, Viewer 준비 시 세션 상태가 확인된 뒤에만 자동 시작한다.
- 검증:
  - `flutter test -j 1`: 전체 154개 통과
  - `flutter analyze --no-pub`: 기존 `score_viewer_screen.dart` 미사용 private method 경고 4개만 남음
  - `dart format --output=none --set-exit-if-changed` 대상 변경 Dart 파일 통과
  - `flutter build apk --release` 성공
  - APK SHA-256 `43b429397d49427957aa3fa4f7c29307dc1db8f95b1e3567961bc06d93f13288`
  - `R54Y600GBKY`(SM-X620)·`RFKL40AXPCP`(SM-F966N)·`emulator-5554`에 versionCode 2 재설치, 세 기기 앱 프로세스 실행 확인
- 남은 일:
  - 실제 두 Android 기기에서 주변 방 Wi-Fi 안내, 곡 전환별 메트로놈 값, 무대/Jam 클릭 청취와 동시성을 수동 확인한다(B-012/B-005).

## 2026-08-27 13:49 KST — Jam Viewer 초기화 덮어쓰기 수정

- 작업자: Codex
- 목표: 호스트 Viewer가 전역 기본 메트로놈으로 초기화되며 저장된 곡별 프로필을 덮어쓰는 경로 제거
- 변경 파일:
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - 현재 Jam 곡의 `JamMusicState` 프로필을 Viewer 초기 BPM·박자표·음표 단위·악센트에 우선 적용했다.
  - 프로필이 없는 구형/BPM-only 곡은 기존 Song BPM과 전역 기본값으로 계속 동작한다.
- 검증:
  - 관련 Jam·Setlist·DB 테스트 35개 통과
  - `flutter test -j 1`: 전체 154개 통과
  - `flutter analyze --no-pub`: 기존 ScoreViewer 미사용 private method 경고 4개만 남음
  - `flutter build apk --release` 성공
  - APK SHA-256 `d57f4a65443d41bd093a7f96a4928baa00a2ce773695791200a7dccc49e01074`
  - `R54Y600GBKY`(SM-X620)·`RFKL40AXPCP`(SM-F966N)·`emulator-5554`에 versionCode 2 재설치 및 MainActivity 실행 확인
- 남은 일:
  - 실제 두 Android 기기에서 곡별 프로필 전환과 공통 메트로놈 오디오 동시성을 수동 확인한다(B-012).

## 2026-08-27 13:41 KST — 세트리스트 곡별 메트로놈 프로필

- 작업자: Codex
- 목표: 세트리스트 곡마다 다른 BPM·박자표·음표 단위·박별 악센트를 저장하고 Jam 곡 전환에 적용
- 변경 파일:
  - `lib/core/database/app_database.dart`, `lib/core/database/app_database.g.dart`
  - `lib/core/session/jam_session.dart`
  - `lib/core/session/jam_session_store.dart`, `lib/core/session/lan_jam_session_store.dart`
  - `lib/features/setlists/domain/setlist_song.dart`, `lib/features/setlists/data/setlist_repository.dart`
  - `lib/features/jam/domain/jam_shared_setlist_mapper.dart`, `lib/features/jam/presentation/jam_session_screen.dart`
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - 관련 DB·Setlist·Memory/LAN Jam 테스트
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - `SetlistEntries` DB v16에 nullable `metronome_json`을 추가하고 entry별 리듬 프로필을 저장·복원한다.
  - 기존 `tempoOverride`/BPM-only 항목과 구형 `songId`·BPM Jam payload를 계속 읽는다.
  - Jam 공유 곡 payload에 프로필을 포함하고, 호스트가 곡을 바꾸면 해당 프로필을 적용한다. Jam 설정 변경은 현재 entry 프로필을 갱신하며 `section`·`count-in`은 세션 상태로 유지한다.
- 검증:
  - `flutter test -j 1`: 전체 154개 통과
  - `flutter analyze --no-pub`: 기존 ScoreViewer 미사용 private method 경고 4개만 남음
  - `flutter build apk --release` 성공
  - APK SHA-256 `4d702d869b1f98e8d8b85c5dd26ce1fd978e4c1bbf036371608f1840726e59da`
  - `R54Y600GBKY`(SM-X620)·`RFKL40AXPCP`(SM-F966N)·`emulator-5554`에 versionCode 2 재설치 및 MainActivity 실행 확인
- 남은 일:
  - 실제 두 Android 기기에서 곡별 프로필 전환과 공통 메트로놈 오디오 동시성을 수동 확인한다(B-012).

## 2026-08-27 11:43 KST — LAN query-response 단순화 및 최종 APK

- 작업자: Codex
- 목표: 네트워크 단절·라우팅 오류 때 호스트 UDP listener가 닫히지 않도록 방 탐색 경로를 최소화
- 변경 파일:
  - `lib/core/session/lan_jam_session_store.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - 호스트의 불필요한 주기 announce를 제거하고 브라우저 query에만 방 정보를 응답하도록 정리했다.
  - 제한 브로드캐스트·인터페이스 주소 query와 UDP read 큐 drain으로 기존 방 탐색·코드 참가 경로를 유지했다.
- 검증:
  - `flutter test -j 1`: 전체 152개 통과
  - `test/features/jam`: 54개 통과
  - `flutter analyze --no-pub`: 기존 ScoreViewer 미사용 private method 경고 4개만 남음
  - `flutter build apk --release` 성공
  - APK SHA-256 `99603fab4d29f6726c0ce5ae704249b1fb616fa34ecbc472ab0e7b769c35b209`
  - `SM-X620`(R54Y600GBKY)·`emulator-5554` versionCode 2 재설치 및 앱 프로세스 실행 확인
- 남은 일:
  - 실제 두 Android 기기에서 주변 방 검색·ready→start·공통 메트로놈 오디오 동시성을 수동 확인한다(B-012).

## 2026-08-27 11:37 KST — LAN 주변 방 탐색 라우팅 오류 수정

- 작업자: Codex
- 목표: 같은 Wi-Fi 방 탐색이 특정 네트워크에서 멈추거나 호스트 UDP 수신이 닫히는 문제 수정
- 변경 파일:
  - `lib/core/session/lan_jam_session_store.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - `NetworkInterface` 주소만으로 잘못 추정한 directed broadcast를 제거하고 limited broadcast·인터페이스 주소만 사용한다. `/23` 환경에서 존재하지 않는 broadcast로 `No route to host`가 발생해 호스트 UDP listener가 닫히던 원인을 제거했다.
  - 호스트·주변 방 탐색·코드 참가 UDP 수신기가 한 read 이벤트에서 대기 중인 datagram을 모두 처리하도록 보강했다.
- 검증:
  - 주변 방 탐색 targeted test 12회 연속 통과
  - `flutter test -j 1`: 전체 152개 통과
  - `flutter analyze --no-pub`: 기존 ScoreViewer 미사용 private method 경고 4개만 남음
  - `flutter build apk --release` 성공
  - APK SHA-256 `7134aba53aa24a5ee9e737c02e7f6e9ae7541adc0e5762322920e983740b7a49`
  - `SM-X620`(R54Y600GBKY)·`emulator-5554` versionCode 2 재설치 및 앱 프로세스 실행 확인
- 남은 일:
  - 실제 두 Android 기기에서 주변 방 검색·ready→start·공통 메트로놈 오디오 동시성을 수동 확인한다(B-012).

## 2026-08-27 11:08 KST — Jam 메트로놈·방 탐색·세트리스트 전환

- 작업자: Codex
- 목표: Individual Click 선택 제거, 합주 메트로놈 설정 제공, 활성/주변 방 관리 개선, 세트리스트 끝 페이지 전환 수정
- 변경 파일:
  - `lib/core/session/jam_session.dart`
  - `lib/core/session/jam_lan_codec.dart`
  - `lib/core/session/jam_session_store.dart`
  - `lib/core/session/lan_jam_session_store.dart`
  - `lib/features/jam/presentation/jam_hub_screen.dart`
  - `lib/features/jam/presentation/jam_session_screen.dart`
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `lib/features/tools/presentation/metronome_settings_sheet.dart`
  - `lib/l10n/app_*.arb`, 생성된 localization 파일
  - `test/features/jam/jam_lan_session_test.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - Jam UI에서 Individual/Host Click 선택을 제거하고 모든 기기가 공통 `startAt`·설정의 로컬 클릭을 재생하도록 정리했다. 호스트 메트로놈 시트에서 BPM(±1/직접 입력), 박자표, 음표 단위, Count-In, 박별 악센트를 변경하면 `JamMusicState`로 전파한다.
  - Jam 허브에 활성 방 복귀 카드와 UDP 기반 같은 Wi-Fi 주변 방 검색·방 제목·참가 인원 목록을 추가했다. 기존 코드 입력/QR 참가도 유지한다.
  - 일반 세트리스트 Viewer가 첫·마지막 페이지에서 좌우 이동 시 다음·이전 곡으로 자동 전환하도록 Stage 전용 조건을 제거했다.
- 검증:
  - `flutter test -j 1` 전체 152개 통과
  - `flutter analyze --no-pub` 통과 — 기존 ScoreViewer 미사용 private method 경고 4개
  - `flutter build apk --release` 성공
  - APK SHA-256 `dbd819ad2a1c8b8e2d3114e242760baf72156b523c0933a7be703e76faca1e22`
  - `SM-X620`(R54Y600GBKY)·`emulator-5554` 재설치 및 앱 프로세스 실행 확인
- 남은 일:
  - 실제 두 Android 기기에서 주변 방 검색·ready→start·공통 메트로놈 오디오 동시성을 수동 확인한다(B-012).
  - Google Drive·Dropbox 실제 계정 승인과 파일 목록은 별도 수동 검증한다(AUDIT-CLOUD-001).

## 2026-08-27 10:37 KST — Jam 방장 악보 fallback 최종 검증

- 작업자: Codex
- 목표: 방장 PDF 전송 경로의 연결 종료 방어와 설치본 최종 확인
- 변경 파일:
  - `lib/core/session/lan_jam_session_store.dart`
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - 요청을 보낸 참가자 소켓이 먼저 끊기면 방장 PDF 응답을 쓰지 않도록 방어했다.
  - 임시 방장 악보에서 오디오 파일 연결 경로도 편집 잠금 규칙을 따른다.
- 검증:
  - `flutter test -j 1` 전체 151개 통과
  - `flutter analyze --no-pub` 통과 — 기존 ScoreViewer 미사용 private method 경고 4개
  - `flutter build apk --release` 성공
  - APK SHA-256 `4e252ab3083af3874cb39e0be05416c7daa7963859b00a8b12c29d00adc4c858`
  - `SM-X620`(R54Y600GBKY)·`emulator-5554` 재설치 및 앱 프로세스 실행 확인
- 남은 일:
  - 실제 두 Android 기기에서 로컬 악보 우선·방장 fallback·동시 메트로놈을 수동 확인

## 2026-08-27 10:30 KST — Jam 방장 악보 fallback

- 작업자: Codex
- 목표: 참가자가 자기 기기 악보가 없을 때 방장 악보로 합주를 시작
- 변경 파일:
  - `lib/core/session/jam_session_store.dart`
  - `lib/core/session/lan_jam_session_store.dart`
  - `lib/core/storage/song_file_storage.dart`
  - `lib/core/storage/storage_provider.dart`
  - `lib/features/library/data/song_repository.dart`
  - `lib/features/jam/presentation/jam_session_screen.dart`
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `lib/features/score_viewer/presentation/viewer_chrome.dart`
  - `lib/features/score_viewer/presentation/viewer_settings_sheet.dart`
  - `test/core/storage/song_file_storage_test.dart`
  - `test/features/jam/jam_session_store_test.dart`
  - `test/features/jam/jam_lan_session_test.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - Member는 오프라인 자기 악보를 먼저 사용하고, 없으면 필요한 entry의 PDF만 `score-request`/`score-response`로 방장에게 요청한다.
  - 받은 PDF는 헤더·24MB 제한을 확인한 뒤 `jam_host` 임시 Song으로 저장하고 Library에는 숨긴다.
  - 임시 방장 악보는 주석 편집을 잠그고 Jam 화면 종료 또는 다음 Jam 진입 시 정리한다.
- 검증:
  - `flutter test -j 1` 전체 151개 통과
  - `flutter analyze --no-pub` 통과 — 기존 ScoreViewer 미사용 private method 경고 4개
  - `flutter build apk --release` 성공
  - APK SHA-256 `6660579539f4a119610dc8dcbc06b59cad7f59e02b58f24c41e10109b9fbebd4`
  - `SM-X620`(R54Y600GBKY)·`emulator-5554`에 재설치 후 앱 프로세스 실행 확인
- 남은 일:
  - 실제 두 Android 기기에서 자기 악보 우선·방장 fallback·동시 메트로놈을 함께 확인

## 2026-08-27 10:06 KST — Jam 연결 오류 방어와 최종 APK

- 작업자: Codex
- 목표: 외부 악보 선택 중 예외가 화면 밖으로 전파되지 않게 하고 최종 설치본을 갱신
- 변경 파일:
  - `lib/features/jam/presentation/jam_session_screen.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - Jam의 Library·기기·클라우드·WebDAV 연결 흐름에서 발생한 예외를 공통 `importFailed` 안내로 처리한다.
- 검증:
  - `dart format`·`flutter analyze` 통과 — 기존 ScoreViewer 미사용 private method 경고 4개
  - `flutter build apk --release` 성공
  - APK SHA-256 `784f21ec4b987ef29e20df47a86ac8effb269a834774c57c533717c8a328bddb`
  - `SM-X620`(R54Y600GBKY)·`emulator-5554`에 versionCode 2 APK 설치 후 앱 프로세스 실행 확인
- 남은 일:
  - 실제 WebDAV/Google Drive/Dropbox 승인과 두 Android 기기 LAN Jam 실사용 검증

## 2026-08-27 10:03 KST — Jam WebDAV 즉시 다운로드

- 작업자: Codex
- 목표: Jam에서 선택한 WebDAV 악보가 Library에 등록만 되고 바로 열리지 않는 경로 보완
- 변경 파일:
  - `lib/features/storage/presentation/webdav_browser_screen.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - Jam 전용 WebDAV 브라우저 선택 모드를 추가했다.
  - 새 WebDAV 항목은 Library 등록 후 즉시 PDF를 다운로드하고, 이미 등록된 Cloud Only 항목도 선택 시 오프라인 파일을 확보한다.
  - 일반 Library WebDAV 브라우저의 기존 등록 동작은 유지한다.
- 검증:
  - `dart format`·`flutter analyze` 통과 — 기존 ScoreViewer 미사용 private method 경고 4개
  - WebDAV RemoteScoreService·SetlistRepository 관련 테스트 8개 통과
  - `flutter build apk --release` 성공
  - APK SHA-256 `7a7c72162818348769bd16198370b9805554391b914adb65f2ed468cde3daa1f`
  - `SM-X620`(R54Y600GBKY)·`emulator-5554`에 versionCode 2 APK 설치 후 앱 프로세스 실행 확인
- 남은 일:
  - 실제 WebDAV HTTPS 서버에서 등록·다운로드를 확인한다.

## 2026-08-27 09:59 KST — Jam 공유 세트리스트 자동 저장과 다중 악보 소스 연결

- 작업자: Codex
- 목표: 참가자가 호스트 세트리스트를 자신의 목록에 자동 보관하고, 곡별로 기기·Google Drive·Dropbox·WebDAV·기존 Library 악보를 연결
- 변경 파일:
  - `lib/core/storage/storage_provider.dart`
  - `lib/features/library/data/song_repository.dart`
  - `lib/features/library/presentation/import_score_sheet.dart`
  - `lib/features/library/presentation/library_screen.dart`
  - `lib/features/setlists/data/setlist_repository.dart`
  - `lib/features/jam/presentation/jam_session_screen.dart`
  - `lib/features/storage/cloud/presentation/cloud_browser_screen.dart`
  - `lib/features/storage/presentation/webdav_browser_screen.dart`
  - `test/features/setlists/setlist_repository_test.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - Jam Member가 공유 Setlist를 받으면 현재 Drift Setlists에 idempotent upsert하고 entryId·순서·제목·아티스트·BPM을 보존한다.
  - 로컬 매칭 악보는 즉시 연결하고, 없는 곡은 Library에 노출하지 않는 `jam_pending` 대기 Song으로 유지한다.
  - 곡별 연결 소스 시트를 추가해 기존 Library, 기기 PDF, Google Drive, Dropbox, WebDAV를 선택한다.
  - 기기·클라우드 PDF는 기존 `PdfImportService`를 통해 Library에 저장하고, WebDAV는 `RemoteScoreService.register` 결과를 받아 SetlistEntry의 Song으로 연결한다.
  - PDF import sheet와 cloud browser가 가져온 Song.id를 호출자에게 반환하도록 공통 경로를 확장했다.
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과 — 기존 ScoreViewer 미사용 private method 경고 4개
  - SetlistRepository 회귀 테스트 통과
  - 전체 테스트 실행 결과 144개 통과, LAN discovery 4개는 현재 환경에서 `jamJoinTimedOut`
  - `flutter build apk --release` 성공
  - APK SHA-256 `874e8e02cabe33208b909fb95646a7222ca58c4257a4484122da58f352dc140f`
  - `SM-X620`(R54Y600GBKY)·`emulator-5554`에 versionCode 2 APK 설치 후 앱 프로세스 실행 확인
- 남은 일:
  - 실제 Android 기기에서 Google/Dropbox OAuth 승인·파일 목록·다운로드, WebDAV 서버, Jam 세트리스트 자동 저장과 동시 메트로놈을 수동 확인한다.
  - 앱 삭제·새 기기 간 로컬 세트리스트 복원은 B-016 범위로 남아 있다.

## 2026-08-27 09:30 KST — 클라우드 OAuth 기본값과 Jam 세트리스트 snapshot 보강

- 작업자: Codex
- 목표: 태블릿의 Drive/Dropbox가 시스템 파일 선택기로 열리는 원인과 Jam에서 기존 세트리스트가 없다고 표시되는 경로 수정
- 변경 파일:
  - `lib/features/storage/cloud/data/cloud_oauth_config.dart`
  - `lib/features/setlists/data/setlist_repository.dart`
  - `lib/features/jam/presentation/jam_session_screen.dart`
  - `test/features/setlists/setlist_repository_test.dart`
  - `test/features/storage/cloud/cloud_oauth_config_test.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 원인:
  - 일반 release 빌드에서 `GOOGLE_SERVER_CLIENT_ID`·`DROPBOX_CLIENT_ID` dart-define을 생략해 `canAttempt=false`가 되었고 Library가 Android DocumentsUI로 fallback했다.
  - Jam 세트리스트 선택이 `setlistsProvider.future`의 오래된 첫 빈 값을 재사용해, 이후 생성·갱신된 목록이 있어도 없다고 판단할 수 있었다.
  - 세트리스트는 `page_a_diddle` Drift 로컬 DB와 앱 문서 디렉터리에만 저장되고 `allowBackup=false`라 앱 삭제·새 기기에서 자동 복원되지 않는다.
- 완료 내용:
  - 제공된 Google 웹 클라이언트 ID와 Dropbox App Key를 Android 기본값으로 포함하고 build define override를 유지했다. Dropbox redirect는 `db-usuggo1fabglt8p://oauth`로 유지한다.
  - `SetlistRepository.getSetlists()` 현재 목록 snapshot을 추가하고 Jam 선택·복귀에서 사용해 cached stream 빈 값 문제를 제거했다.
  - 현재 기기 내 기존 세트리스트 선택은 수정했지만, 앱 삭제·새 기기 간 세트리스트 export/import·동기화는 별도 범위로 남겼다(B-016).
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과 — 기존 ScoreViewer 미사용 private method 경고 4개
  - `flutter test -j 1` 전체 147개 통과
  - `flutter build apk --release` 성공
  - APK SHA-256 `3ffd293f0220fd9d43842f058280d3780658c1f9552f2ee1a76cae557ea88e8a`에 두 클라이언트 값·Dropbox redirect 문자열 포함 확인
  - `SM-X620`(R54Y600GBKY)·`emulator-5554`에 versionCode 2 APK 재설치, MainActivity·앱 프로세스 실행 확인
- 남은 일:
  - Android 실기기에서 Google/Dropbox 실제 계정 승인·목록·다운로드·redirect를 확인한다.
  - 앱 삭제·새 기기 간 세트리스트 이동이 필요하면 B-016의 명시적 export/import 또는 동기화를 별도 결정한다.

## 2026-08-27 09:18 KST — 넓은 화면 홈 브랜드 아이콘 중복 제거

- 작업자: Codex
- 목표: 폴드 펼침·태블릿 메인 화면에서 제목 옆 아이콘이 NavigationRail 아이콘과 중복되지 않게 정리
- 변경 파일:
  - `lib/app/widgets/app_layout.dart`
  - `lib/app/widgets/app_shell.dart`
  - `lib/features/home/presentation/home_screen.dart`
  - `test/widget_test.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - NavigationRail breakpoint와 홈 헤더 조건을 공통 760dp 기준으로 통일했다.
  - 760dp 미만 모바일은 홈 제목 옆 AppBrandMark를 유지하고, 760dp 이상 폴드 펼침·태블릿은 NavigationRail 아이콘만 표시한다.
  - 모바일/넓은 화면 아이콘 표시 여부와 wide NavigationRail 중복 제거를 위젯 테스트로 고정했다.
- 검증:
  - `flutter test -j 1` 전체 145개 통과
  - `flutter analyze` 통과 — 기존 ScoreViewer 미사용 private method 경고 4개
  - `flutter build apk --release` 성공
  - 최신 APK SHA-256 `8017adc008c9893c5a39bcc1f45a89ce9346e3415c38e50a1eaa64786547746f`를 SM-X620·emulator-5554에 설치·실행 확인
- 남은 일:
  - 실제 Fold 펼침 상태에서의 화면 확인은 해당 실기기 재연결 후 수동 확인한다.

## 2026-08-27 09:03 KST — Android 태블릿 APK 설치

- 작업자: Codex
- 목표: 새로 연결한 X620 태블릿에 현재 release APK 설치
- 변경 파일:
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - `SM-X620`(ADB `R54Y600GBKY`)를 ADB에서 확인했다.
  - `build/app/outputs/flutter-apk/app-release.apk` versionCode 2를 설치하고 MainActivity 실행을 전달했다.
- 검증:
  - `lastUpdateTime=2026-08-27 09:03:01`
  - 앱 프로세스 PID `15325` 실행 확인
  - 설치 APK SHA-256이 release 산출물과 일치
- 남은 일:
  - 실제 두 Android 기기 LAN Jam ready→start·오디오 동시성 검증은 B-012로 남아 있다.

## 2026-08-26 17:41 KST — Jam 참가자 곡별 악보 연결

- 작업자: Codex
- 목표: 참가자가 공유 세트리스트의 각 곡에 자기 기기 악보를 등록할 진입점 추가
- 변경 파일:
  - `lib/features/jam/presentation/jam_session_screen.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - 참가자 곡 목록 오른쪽에 로컬 악보 연결 아이콘을 추가했다.
  - 제목·아티스트 후보 또는 전체 Library에서 악보를 고르면 `Setlist.id`+`SetlistEntry.id`별 `Song.id`를 기존 `JamLocalSongBindingStore`에 저장한다.
  - 연결된 곡은 같은 아이콘으로 다시 선택할 수 있고, 호스트의 곡 선택·세트리스트 편집 권한은 바꾸지 않았다.
- 검증:
  - `flutter test -j 1` 전체 144개 통과
  - 연결 테스트의 일시적 LAN timeout은 단일 테스트 재실행 후 통과했고 전체 재실행도 144개 통과
  - `flutter analyze` 통과 — 기존 ScoreViewer 미사용 private method 경고 4개
  - `flutter build apk --release` 성공
  - versionCode 2 APK를 `R3CX70AFANJ`, `RFKL40AXPCP`, `emulator-5554`에 설치·실행하고 설치 APK SHA-256이 release 산출물과 일치함을 확인
- 남은 일:
  - 참가자 기기 Library에 악보가 없는 경우는 기존 `noOpenableScore` 안내를 표시한다. 실제 두 Android 기기 LAN Jam ready→start·오디오 동시성은 B-012에서 수동 확인한다.

## 2026-08-26 17:30 KST — 기존 세트리스트 Jam 등록 로더 보강

- 작업자: Codex
- 목표: 목록에는 보이지만 Jam에서 기존 세트리스트를 선택하면 불러오기 실패가 나는 경로 수정
- 변경 파일:
  - `lib/features/setlists/data/setlist_repository.dart`
  - `lib/features/jam/presentation/jam_controller.dart`
  - `test/features/setlists/setlist_repository_test.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - Jam 전용 세트리스트 로딩을 Drift live stream의 첫 이벤트 대기에서 일회성 `getItems()` DB snapshot 조회로 분리했다.
  - 기존 곡 순서와 tempoOverride/defaultTempo가 snapshot에 그대로 전달되는 회귀 경로를 고정했다.
- 검증:
  - `flutter test -j 1` 전체 144개 통과
  - `flutter analyze` 기존 ScoreViewer 미사용 private method 경고 4개만 확인
  - `flutter build apk --release` 성공
  - `R3CX70AFANJ`(SM-F741N) 17:29:31, `emulator-5554` 17:29:32에 versionCode 2 APK 재설치 및 프로세스 실행 확인
- 남은 일:
  - `RFKL40AXPCP`가 다시 연결되면 동일 APK를 재설치하고, 실제 두 Android 기기 LAN Jam ready→start·오디오 동시성을 B-012로 수동 확인한다.

## 2026-08-26 17:11 KST — 최종 Android release APK 재설치

- 작업자: Codex
- 목표: 최종 LAN discovery·Jam 대기실 변경이 포함된 APK를 연결된 Android 기기에 반영
- 변경 파일:
  - `build/app/outputs/flutter-apk/app-release.apk`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 검증:
  - `flutter build apk --release` 성공
  - `R3CX70AFANJ` 17:10:37, `RFKL40AXPCP` 17:10:56, `emulator-5554` 17:11:02에 versionCode 2 APK 설치 및 MainActivity 실행 확인
- 남은 일:
  - 실제 두 Android 기기에서 같은 Wi-Fi ready→start→악보·메트로놈·오디오 동시성을 B-012로 수동 확인한다.

## 2026-08-26 17:05 KST — LAN 소켓 수명·세트리스트 진입 최종 보강

- 작업자: Codex
- 목표: 합주 discovery의 간헐적 UDP 수신 공백을 줄이고, 새 세트리스트 생성 후 Jam 공유까지 한 흐름으로 연결
- 변경 파일:
  - `lib/core/session/lan_jam_session_store.dart`
  - `lib/features/jam/presentation/jam_session_screen.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - discovery를 700ms 단위 소켓 재생성 방식에서 단일 UDP 소켓·120ms 재시도로 바꾸고, 호스트 UDP 구독을 보관·종료 시 취소한다.
  - 호스트 UDP 구독을 종료 시 순서대로 취소하고, 소켓 종료 뒤 짧은 정리 지연을 둔다.
  - Jam에 세트리스트가 없을 때 새 목록 화면에서 돌아오면 최신 목록을 자동 공유한다.
- 검증:
  - `flutter test -j 1` 전체 144개 통과
  - `flutter test -j 1 test/features/jam` Jam 51개 통과
  - `flutter analyze`에서 기존 ScoreViewer 미사용 private method 경고 4개만 확인
  - `flutter build apk --release` 성공
  - `R3CX70AFANJ` 17:04:25, `RFKL40AXPCP` 17:04:39, `emulator-5554` 17:04:44에 versionCode 2 APK 설치 및 MainActivity 실행 확인
- 남은 일:
  - 같은 Wi-Fi 실기기 두 대에서 ready→start→양쪽 악보·메트로놈과 실제 오디오 동시성을 B-012로 수동 확인한다.

## 2026-08-26 16:49 KST — LAN 탐색 안정화 및 APK 재설치

- 작업자: Codex
- 목표: 대기실 ready/start 흐름을 포함한 LAN 탐색의 간헐적 초기 타임아웃을 줄이고 최신 APK를 연결 기기에 배포
- 변경 파일:
  - `lib/core/session/lan_jam_session_store.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - 호스트 UDP listener가 등록된 뒤 생성이 완료되도록 40ms 준비 지연을 추가했다.
  - discovery 대상은 루프백을 먼저 질의하고, 20ms 초기 지연 후 120ms마다 재시도하도록 정리했다. LAN directed broadcast/direct 전송은 유지한다.
- 검증:
  - `flutter test -j 1` 전체 144개 통과
  - `flutter test -j 1 test/features/jam` Jam 51개 통과
  - `flutter analyze`에서 기존 ScoreViewer 미사용 private method 경고 4개만 확인
  - `flutter build apk --release` 성공
  - `R3CX70AFANJ` lastUpdateTime 16:48:04, `RFKL40AXPCP` 16:48:22, `emulator-5554` 16:48:26에 versionCode 2 APK 설치 및 MainActivity 실행 확인
- 남은 일:
  - 같은 Wi-Fi 실기기 두 대에서 ready→start→양쪽 악보·메트로놈과 실제 오디오 동시성을 B-012로 수동 확인한다.

## 2026-08-26 16:34 KST — Jam 대기실·준비·시작 동기화 보강

- 작업자: Codex
- 목표: 합주 방 접속감을 만들고 곡/세트리스트 작업과 참가자 시작 흐름을 명확하게 정리
- 변경 파일:
  - `lib/core/session/jam_session.dart`
  - `lib/core/session/jam_session_store.dart`
  - `lib/core/session/lan_jam_session_store.dart`
  - `lib/features/jam/presentation/jam_controller.dart`
  - `lib/features/jam/presentation/jam_session_error_l10n.dart`
  - `lib/features/jam/presentation/jam_session_screen.dart`
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `lib/l10n/app_en.arb`, `lib/l10n/app_ko.arb`, `lib/l10n/app_localizations*.dart`
  - `test/features/jam/jam_session_store_test.dart`, `test/features/jam/jam_lan_session_test.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - 새 멤버를 `ready=false`로 입장시키고 준비 버튼과 참가자 준비 상태를 LAN/Memory 세션에 전달한다. 연결된 멤버가 모두 준비되지 않으면 호스트 Start를 거부한다.
  - 호스트 `playing/startAt` 전파를 참가자 Jam 화면의 악보 자동 진입과 연결하고, ScoreViewer가 멤버 권한으로 호스트 전용 `updatePlaying`을 재호출하지 않게 했다.
  - 방 상단에 대기실·방 코드·역할·인원을 표시하고, 준비/시작 버튼과 참가자 ready 칩을 추가했다.
  - 세트리스트·로컬 악보 선택 팝업에 충분한 여백과 큰 카드/타이틀을 적용했다. 세트리스트 편집 화면에서 곡 추가 후 돌아오면 공유 스냅샷을 다시 읽는다. 세트리스트 공유 시 Jam 화면이 악보를 자동으로 열지 않고 Start 때 연다.
- 검증:
  - `flutter analyze` 통과(기존 ScoreViewer 미사용 private method 경고 4개)
  - `flutter test -j 1` 통과 — 144개
  - `flutter build apk --release` 성공
  - 최종 APK를 `R3CX70AFANJ`(SM-F741N), `RFKL40AXPCP`(SM-F966N), `emulator-5554`에 설치하고 versionCode 2 및 MainActivity 실행을 확인했다. lastUpdateTime은 각각 16:34:07, 16:33:34, 16:33:23이다.
- 남은 일:
  - 두 실기기에서 같은 Wi-Fi 방 생성 → 코드 참가 → 멤버 준비 → 호스트 시작 → 양쪽 악보/메트로놈 자동 진입과 실제 오디오 동시성을 B-012에서 확인한다.

## 2026-08-26 16:06 KST — 두 실기기 연결 및 최종 APK 재설치

- 작업자: Codex
- 목표: 두 Android 실기기의 ADB 연결과 동일한 최종 APK 설치 상태 재확인
- 변경 파일:
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - `R3CX70AFANJ`(SM-F741N), `RFKL40AXPCP`(SM-F966N), `emulator-5554`가 모두 `device` 상태로 연결된 것을 확인했다.
  - 두 실기기에 `build/app/outputs/flutter-apk/app-release.apk` versionCode 2를 설치하고 MainActivity 실행을 전달했다.
- 검증:
  - `R3CX70AFANJ` lastUpdateTime `2026-08-26 16:00:09`
  - `RFKL40AXPCP` lastUpdateTime `2026-08-26 16:06:08`
  - 실제 두 기기 LAN Jam 세션 검증은 B-012로 남아 있다.

## 2026-08-26 15:56 KST — Jam 참가 파트 선택과 호스트 세트리스트 피드백

- 작업자: Codex
- 목표: 합주 생성·참가 시 각자의 음악 파트를 선택하고 호스트 세트리스트 추가 버튼의 무반응 상태를 분기
- 변경 파일:
  - `lib/core/session/jam_session.dart`
  - `lib/core/session/jam_session_store.dart`
  - `lib/core/session/lan_jam_session_store.dart`
  - `lib/features/jam/presentation/jam_controller.dart`
  - `lib/features/jam/presentation/jam_hub_screen.dart`
  - `lib/features/jam/presentation/jam_session_screen.dart`
  - `lib/features/jam/presentation/jam_instrument_ui.dart`
  - `lib/l10n/app_en.arb`, `lib/l10n/app_ko.arb`, `lib/l10n/app_localizations*.dart`
  - `test/features/jam/jam_session_store_test.dart`
  - `test/features/jam/jam_lan_session_test.dart`
  - `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - 생성·참가 다이얼로그에 보컬·기타·베이스·드럼·키보드·기타 직접 입력 선택을 추가하고 아이콘을 붙였다.
  - `instrument`/`customInstrument`를 Memory·LAN 세션 JSON에 전달하고, 이전 payload는 드럼 기본값으로 복원한다.
  - 참가자 카드에 파트 아이콘·파트명·Conductor/Member·연결 상태를 함께 표시한다.
  - 호스트 세트리스트 선택 버튼에 눌림 피드백, 로딩 아이콘, 중복 입력 차단, 4초 timeout, 예외 안내를 추가했다.
- 검증:
  - `flutter analyze` 통과(기존 ScoreViewer 미사용 private method 경고 4개)
  - `flutter test -j 1` 통과 — 144개; Jam 테스트 51개
  - `flutter build apk --release` 성공
  - 최종 release APK를 `R3CX70AFANJ`와 `emulator-5554`에 `adb install -r` 및 MainActivity 실행 확인. 설치 시각은 각각 16:00:09, 15:59:44이며 RFKL40AXPCP는 연결되지 않음
- 남은 일:
  - 두 실기기에서 역할 선택·참가자 표시·호스트 세트리스트 선택을 직접 확인하고 B-012 LAN Jam 실기기 검증을 마친다.

## 2026-08-26 15:24 KST — Jam 세트리스트 식별자와 기기별 악보 매핑

- 작업자: Codex
- 목표: 합주에서 세트리스트 순서·곡 정보만 공유하고, 드러머/기타리스트가 각자 파트 악보를 등록해 사용하도록 로컬 악보 ID와 공유 ID를 분리
- 변경 파일:
  - `lib/core/session/jam_session.dart`
  - `lib/core/session/jam_session_store.dart`
  - `lib/core/session/lan_jam_session_store.dart`
  - `lib/features/jam/domain/jam_shared_setlist_mapper.dart`
  - `lib/features/jam/domain/jam_local_song_match.dart`
  - `lib/features/jam/presentation/jam_controller.dart`
  - `lib/features/jam/presentation/jam_session_screen.dart`
  - `test/features/jam/jam_session_store_test.dart`
  - `test/features/jam/jam_lan_session_test.dart`
  - `test/features/jam/jam_local_song_match_test.dart`
  - `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - `JamSharedSong.songId`/`JamSession.currentSongId`를 `entryId`/`currentEntryId`로 정리하고, 이전 JSON 키는 읽기만 허용했다. 실제 전송 JSON에는 로컬 Song ID가 없다.
  - Library setlist mapper가 `SetlistEntry.id`를 공유 키로 사용하게 했다. 세트리스트 항목 순서와 제목·아티스트·BPM은 유지한다.
  - 각 기기는 `setlistId/entryId → local Song.id`를 SharedPreferences에 저장한다. 최초 곡 열기에서 제목·아티스트 후보(없으면 전체 로컬 악보)를 선택하고, 현재 곡 카드에서 다시 선택할 수 있다.
  - LAN discovery는 인터페이스 주소 직접 전송과 250ms 재시도를 추가해 제한 브로드캐스트 누락을 복구한다.
  - 향후 파트별 PDF의 페이지 차이를 해소하는 공통 Measure/Beat/Section Timeline 매핑은 F-01로 명시했다.
- 검증:
  - `flutter analyze` 통과(기존 ScoreViewer 미사용 private method 경고 4개)
  - `flutter test -j 1` 통과 — 143개(식별자 mapper·기기별 매핑 키 회귀 포함)
  - `flutter build apk --release` 성공 후 discovery 방어를 포함한 APK를 `R3CX70AFANJ`(SM-F741N)와 `emulator-5554`에 `adb install -r` 및 MainActivity 실행 확인. 설치 시각은 각각 15:40:51, 15:40:35이며 RFKL40AXPCP는 현재 연결되지 않음
- 남은 일:
  - 두 실기기에서 세트리스트 공유 후 각자 다른 로컬 악보를 선택하고, 곡 전환·메트로놈·위치 동기화가 실제 화면에서 의도대로 동작하는지 B-012 수동 검증

## 2026-08-26 15:11 KST — LAN Jam 연결·종료 방어와 참가 로딩

- 작업자: Codex
- 목표: Wi-Fi 미연결·UDP/소켓 오류·호스트 종료를 안전하게 분기하고, 참가 중 상태를 사용자에게 표시
- 변경 파일:
  - `lib/core/session/jam_session.dart`
  - `lib/core/session/lan_jam_session_store.dart`
  - `lib/features/jam/presentation/jam_controller.dart`
  - `lib/features/jam/presentation/jam_hub_screen.dart`
  - `lib/features/jam/presentation/jam_session_screen.dart`
  - `lib/features/jam/presentation/jam_session_error_l10n.dart`
  - `lib/l10n/app_*.arb`, `lib/l10n/app_localizations*.dart`
  - `test/features/jam/jam_lan_session_test.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - Android에서 usable IPv4 네트워크가 없으면 즉시 Wi-Fi 안내를 표시하고, discovery timeout·호스트 연결 실패·네트워크 오류를 서로 다른 문구로 분기했다.
  - UDP 비동기 오류·malformed packet·사라진 query source를 무시하고 discovery를 정리한다. `dispose()`가 재시도용 clock stream을 닫아버리던 문제도 session reset과 store dispose를 분리해 수정했다.
  - 호스트 종료 시 `closed`를 flush한 뒤 소켓을 닫고, 게스트는 종료 안내와 합주 목록 복귀 버튼을 표시한다.
  - 합주 만들기·코드 참가·QR 참가 버튼은 연결 완료 또는 실패까지 spinner와 중복 입력 차단을 표시한다.
- 검증:
  - `flutter analyze` 통과(기존 ScoreViewer 미사용 private method 경고 4개)
  - `flutter test` 통과 — 141 tests passed; Jam 테스트 48개
  - `flutter build apk --release` 성공
  - `RFKL40AXPCP` 설치 15:10:16, `R3CX70AFANJ` 설치 15:10:40
- 남은 일:
  - 두 실기기에서 Wi-Fi 끊김·호스트 종료·재참가를 직접 확인하고, 세트리스트의 기기별 악보 매핑 구조를 다음 결정으로 확정한다.

## 2026-08-26 14:58 KST — UDP discovery 전송 예외 격리 및 최종 APK 재설치

- 작업자: Codex
- 목표: directed broadcast 보강 뒤 특정 네트워크 인터페이스의 라우팅 실패가 LAN Jam 전체를 중단시키는 회귀 제거
- 변경 파일:
  - `lib/core/session/lan_jam_session_store.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - `_broadcastAnnounce`와 `_discover`에서 주소별 `udp.send` 예외를 격리해 다른 broadcast 대상 시도를 계속한다.
  - 최종 `flutter build apk --release` 성공 후 `RFKL40AXPCP`와 `R3CX70AFANJ`에 `adb install -r` 성공했다.
- 검증:
  - `flutter analyze` 통과(기존 ScoreViewer 미사용 private method 경고 4개)
  - `flutter test` 통과 — 140 tests passed
  - 설치 시각: RFKL40AXPCP 14:58:25, R3CX70AFANJ 14:58:45
- 남은 일:
  - 잠금 해제한 두 폰에서 호스트 세션 생성 → 게스트 코드 참가를 다시 눌러 실제 UDP discovery와 상태 동기화를 확인한다.

## 2026-08-26 14:53 KST — LAN Jam UDP discovery 경로 보강

- 작업자: Codex
- 목표: 같은 Wi-Fi의 두 실기기에서 게스트가 호스트 세션을 찾지 못하는 원인 진단 및 최소 수정
- 변경 파일:
  - `lib/core/session/lan_jam_session_store.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - `RFKL40AXPCP`(192.168.0.88/23)와 `R3CX70AFANJ`(192.168.1.161/23)가 같은 `CNX_CIXM` Wi-Fi임을 확인했다.
  - 게스트에서 호스트 TCP 47828은 연결됐지만 UDP discovery만 시간 초과해, `255.255.255.255`만 보내던 경로에 인터페이스 기반 directed broadcast(`192.168.1.255`)를 추가했다.
  - 수정본 `flutter build apk --release` 성공 후 두 실기기에 `adb install -r` 성공했다. 설치 시각은 RFKL40AXPCP 14:50:42, R3CX70AFANJ 14:51:02다.
- 검증:
  - `flutter analyze` 통과(기존 ScoreViewer 미사용 private method 경고 4개)
  - `flutter test test/features/jam` 통과 — 47 tests passed
- 남은 일:
  - 잠금 해제한 두 폰에서 호스트 세션 생성 → 게스트 코드 참가를 다시 눌러 UDP discovery가 통과하는지 확인한다. 실패하면 Android Wi-Fi multicast lock 또는 discovery 로그를 추가로 점검한다.

## 2026-08-26 14:26 KST — Individual Click 기본값 변경본 두 번째 실기기 설치

- 작업자: Codex
- 목표: 최신 합주 메트로놈 APK를 새로 연결된 Android 실기기에 설치
- 변경 파일:
  - `build/app/outputs/flutter-apk/app-release.apk` (기존 빌드 산출물)
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - `R3CX70AFANJ`(Samsung SM-F741N)에 `adb install -r` 성공
  - `com.hansookim.pageadiddle/.MainActivity` 실행 및 앱 프로세스(PID 22677) 확인
  - versionCode 2, `lastUpdateTime 2026-08-26 14:26:35` 확인
- 남은 일:
  - 같은 Wi-Fi의 실제 Android 두 대에서 각 이어폰의 메트로놈 동시성을 수동 검증한다.

## 2026-08-26 14:22 KST — Individual Click 기본값 변경본 실기기 설치

- 작업자: Codex
- 목표: 최신 합주 메트로놈 APK를 연결된 Android 실기기에 설치
- 변경 파일:
  - `build/app/outputs/flutter-apk/app-release.apk` (기존 빌드 산출물)
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - `RFKL40AXPCP`(Samsung SM-F966N)에 `adb install -r` 성공
  - `com.hansookim.pageadiddle/.MainActivity` 실행 및 앱 프로세스(PID 29628) 확인
  - versionCode 2, `lastUpdateTime 2026-08-26 14:22:39` 확인
- 남은 일:
  - 같은 Wi-Fi의 실제 Android 두 대에서 각 이어폰의 메트로놈 동시성을 수동 검증한다.

## 2026-08-26 14:20 KST — Individual Click 기본값 변경본 에뮬레이터 설치

- 작업자: Codex
- 목표: 각 기기가 같은 박자의 메트로놈을 로컬 재생하도록 변경한 최신 APK를 연결 기기에 설치
- 변경 파일:
  - `build/app/outputs/flutter-apk/app-release.apk` (빌드 산출물)
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - `flutter build apk --release` 성공
  - `emulator-5554`에 `adb install -r` 성공
  - `com.hansookim.pageadiddle/.MainActivity` 실행 및 앱 프로세스 실행 확인
  - 현재 ADB에는 에뮬레이터만 연결되어 있고 RFKL40AXPCP 실기기는 연결되지 않음
- 검증:
  - release APK 생성: `build/app/outputs/flutter-apk/app-release.apk` (116.0MB)
  - 설치 시각: `2026-08-26 14:20:20`, versionCode 2
- 남은 일:
  - 실제 Android 두 대를 같은 Wi-Fi에 연결해 각 이어폰의 클릭 동시성을 수동 검증한다.

## 2026-08-26 14:06 KST — 합주 클릭 기본값을 기기별 동시 재생으로 변경

- 작업자: Codex
- 목표: 참가자가 각자 이어폰으로 동일한 박자의 메트로놈을 듣도록 합주 기본 클릭 정책 수정
- 변경 파일:
  - `lib/core/session/jam_session.dart`
  - `test/features/jam/jam_lan_session_test.dart`
  - `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - 새 세션·누락된 설정의 `JamClickMode` 기본값을 `Individual Click`으로 변경했다.
  - 호스트가 공유한 `startAt`·BPM·박자표·음표 단위·악센트로 각 기기가 로컬 클릭을 재생한다.
  - `Host Click`은 Conductor만 소리 내는 선택 옵션으로 유지했다.
- 검증:
  - `flutter test test/features/jam` 통과 — 47 tests passed
  - `flutter test` 통과 — 140 tests passed
- 남은 일:
  - 같은 Wi-Fi의 실제 Android 두 대에서 두 기기 클릭이 실제 이어폰에서 동시에 들리는지 수동 검증한다.

## 2026-08-26 14:04 KST — Jam 메트로놈 적용 경로 최종 점검

- 작업자: Codex
- 목표: 호스트 설정을 멤버 메트로놈에 적용한 뒤 시작·재시작 경로의 중복 박자와 상태 문서 시점을 확인
- 변경 파일:
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - 멤버의 원격 BPM 적용 시 기존 메트로놈을 즉시 재시작하지 않고 박자표·음표 단위·악센트 적용 후 한 번만 재시작하도록 정리했다.
  - 상태 문서와 로드맵의 최종 검증 시각을 갱신했다.
- 검증:
  - `flutter test test/features/jam` 통과 — 47 tests passed
  - `flutter analyze` 통과 — 기존 ScoreViewer 미사용 private method 경고 4개만 남음
- 남은 일:
  - 같은 Wi-Fi의 실제 Android 두 대에서 LAN Jam 시작·오디오·Host/Individual Click을 수동 검증한다.

## 2026-08-26 14:00 KST — LAN Jam 시작 흐름·호스트 메트로놈 설정 동기화

- 작업자: Codex
- 목표: 합주 화면에서 시작을 명확히 하고 참가자·세트리스트를 읽기 쉽게 표시하며, 호스트의 박자표·음표 단위·악센트를 멤버 기본 설정으로 공유
- 변경 파일:
  - `lib/core/session/jam_session.dart`
  - `lib/core/session/jam_session_store.dart`
  - `lib/core/session/lan_jam_session_store.dart`
  - `lib/features/jam/presentation/jam_controller.dart`
  - `lib/features/jam/presentation/jam_session_screen.dart`
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `lib/app/router/app_router.dart`
  - `test/features/jam/jam_session_store_test.dart`
  - `test/features/jam/jam_lan_session_test.dart`
  - `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`, `docs/PROJECT_STATUS.yaml`, `docs/WORK_LOG.md`
- 완료 내용:
  - Conductor 전용 시작·정지 버튼을 추가하고 시작 시 현재 로컬 매칭 악보를 `startJam` 경로로 열도록 연결했다.
  - 세트리스트에 곡명·아티스트·BPM·현재 곡 표시를 정리하고 참가자 카드에 역할·연결 상태·본인 표시와 연결 수를 추가했다.
  - `JamMusicState`에 박자표·음표 단위·박별 악센트를 추가하고 LAN JSON, Memory/LAN store, Member Viewer 초기 snapshot·변경 적용까지 연결했다.
  - Jam 종료/정지 상태가 호스트의 열린 Viewer 메트로놈도 멈추도록 처리했다.
- 검증:
  - `flutter test` 통과 — 140 tests passed
  - `test/features/jam` 통과 — 47 tests passed
  - `flutter analyze` 통과 — 기존 ScoreViewer 미사용 private method 경고 4개만 남음
  - `flutter build apk --debug` 통과 — `build/app/outputs/flutter-apk/app-debug.apk`
- 남은 일:
  - 같은 Wi-Fi의 실제 Android 두 대에서 시작 버튼, 참가자/세트리스트, Host/Individual Click, 호스트 박자표·음표 단위·악센트와 실제 오디오를 수동 검증한다.

## 2026-08-26 13:12 KST — 도구 타일 제거본 Android 설치

- 작업자: Codex
- 목표: ToolsScreen 클라우드 악보 타일 제거를 반영한 APK를 연결된 Android 기기에 배포
- 변경 파일:
  - `docs/ROADMAP.md`
  - `docs/PROJECT_STATUS.yaml`
  - `docs/WORK_LOG.md`
- 완료 내용:
  - OAuth build define을 포함한 `flutter build apk --release`를 통과했다.
  - 최신 `app-release.apk`를 `RFKL40AXPCP` 실기기와 `emulator-5554`에 `adb install -r`로 설치했다.
  - 실기기 `lastUpdateTime 2026-08-26 13:12:01`, 에뮬레이터 `13:12:06`, 양쪽 `versionCode 2`를 확인했다.
  - 양쪽에 `MainActivity` 실행 Intent를 전달했다.
- 검증:
  - `flutter test` 통과 — 140 tests passed
  - `flutter analyze` 통과 — 기존 ScoreViewer 미사용 private method 경고 4개만 남음
- 남은 일:
  - 실기기 잠금 해제 후 Tools 화면에 클라우드 악보 타일이 사라지고 Library 추가 > WebDAV가 유지되는지 직접 확인한다.

## 2026-08-26 13:09 KST — 도구의 중복 클라우드 악보 진입점 제거

- 작업자: Codex
- 목표: WebDAV 연결이 이미 Library의 추가 버튼에 있으므로 ToolsScreen의 중복 클라우드 악보 타일 제거
- 변경 파일:
  - `lib/features/tools/presentation/tools_screen.dart`
  - `docs/ROADMAP.md`
  - `docs/PROJECT_STATUS.yaml`
  - `docs/WORK_LOG.md`
- 완료 내용:
  - ToolsScreen에서 `클라우드 악보` 타일을 제거했다.
  - WebDAV 연결·파일 탐색·악보 등록은 Library `추가 > WebDAV에서 가져오기` 흐름을 그대로 유지한다.
  - 도구 화면에는 메트로놈·탭 템포·템포 트레이너·Jam만 남겼다.
- 검증:
  - `flutter test` 통과 — 140 tests passed
  - `flutter analyze` 통과 — 기존 ScoreViewer 미사용 private method 경고 4개만 남음

## 2026-08-26 12:59 KST — 주석 아이콘 수정본 실기기 재설치

- 작업자: Codex
- 목표: 사용자가 연결한 Android 실기기에 주석 아이콘 대비 수정본을 설치
- 변경 파일:
  - `docs/ROADMAP.md`
  - `docs/PROJECT_STATUS.yaml`
  - `docs/WORK_LOG.md`
- 완료 내용:
  - `RFKL40AXPCP`(Samsung SM-F966N)에 `build/app/outputs/flutter-apk/app-release.apk`를 `adb install -r`로 재설치했다.
  - `versionCode 2`, `lastUpdateTime 2026-08-26 12:59:04`로 갱신된 것을 확인했다.
  - `MainActivity` 실행 Intent를 전달했고 Flutter/AndroidRuntime 치명 오류 로그는 없었다.
- 남은 일:
  - 실기기 잠금 해제 후 Viewer에서 주석 도크의 되돌리기·전체 지우기 아이콘을 직접 확인한다.

## 2026-08-26 11:28 KST — 주석 되돌리기·전체 지우기 아이콘 대비 보정

- 작업자: Codex
- 목표: Viewer 주석 도크에서 되돌리기와 전체 지우기 아이콘이 검은색으로 보여 식별되지 않는 문제 수정
- 변경 파일:
  - `lib/features/score_viewer/presentation/annotation_dock.dart`
  - `docs/ROADMAP.md`
  - `docs/PROJECT_STATUS.yaml`
  - `docs/WORK_LOG.md`
- 완료 내용:
  - `_TinyIcon`이 enabled/disabled 상태에 따라 흰색 또는 `AppColors.stageMuted`를 명시하도록 수정했다.
  - `Icon` 자체에도 전경색을 지정해 앱 셸의 light theme가 Viewer dark stage 아이콘을 검은색으로 덮지 못하게 했다.
  - 비활성 상태의 undo·clear도 구분 가능한 대비를 유지한다.
- 검증:
  - `flutter test` 통과 — 140 tests passed
  - `flutter analyze` 통과 — 기존 ScoreViewer 미사용 private method 경고 4개만 남음
  - OAuth build define 포함 `flutter build apk --release` 통과 — `build/app/outputs/flutter-apk/app-release.apk` 116.0MB
  - 최신 APK를 현재 연결된 `emulator-5554`에 재설치·실행했고 Activity 표시 및 치명 오류 없음 확인
- 남은 일:
  - `RFKL40AXPCP` 실기기는 현재 adb 연결이 없어 이번 변경본 설치를 보류했다. 재연결 시 동일 APK를 설치해 주석 도크를 직접 확인한다.

## 2026-08-26 11:03 KST — Android Google Drive·Dropbox OAuth 설정 및 파일 선택 fallback

- 작업자: Codex
- 목표: 모바일 설치본에서 Google Drive·Dropbox 가져오기가 동작하지 않는 원인을 수정하고 제공된 Android OAuth 설정으로 설치 가능한 APK를 생성
- 변경 파일:
  - `lib/features/storage/cloud/data/cloud_oauth_config.dart`
  - `lib/features/library/presentation/library_screen.dart`
  - `docs/ROADMAP.md`
  - `docs/PROJECT_STATUS.yaml`
  - `docs/WORK_LOG.md`
- 완료 내용:
  - Google Drive는 `GOOGLE_SERVER_CLIENT_ID`, Dropbox는 `DROPBOX_CLIENT_ID`가 없는 빌드에서 OAuth 화면을 강제로 열지 않고 Android 시스템 파일 선택기로 fallback하도록 수정했다.
  - 클라우드 OAuth가 설정된 경우에는 기존 앱 내부 Google Sign-In·Dropbox AppAuth 경로를 유지했다.
  - 제공된 클라이언트 설정을 build define으로 주입해 `build/app/outputs/flutter-apk/app-release.apk`를 생성했다.
  - MVP 4 Google Drive·Dropbox 항목을 설정 제공·실계정 검증 대기(`[~]`)로 갱신했다.
- 검증:
  - `flutter test` 통과 — 140 tests passed
  - `flutter analyze` 통과 — 기존 ScoreViewer 미사용 private method 경고 4개만 남음
  - `flutter build apk --release --dart-define=...` 통과 — release APK 116.0MB
  - 에뮬레이터 설치 후 Google Drive 선택에서 Google Sign-In 화면, Dropbox 선택에서 Dropbox OAuth Custom Tab 진입 확인
- 남은 일:
  - 실제 Google 계정 승인·Drive PDF 목록/다운로드와 Dropbox 로그인·redirect·목록/다운로드를 Android 실기기에서 확인한다.
  - Google Android OAuth 클라이언트에 `com.hansookim.pageadiddle`와 현재 release 서명 SHA-1이 등록됐는지 확인한다.

## 2026-08-26 10:03 KST — 제품 범위 변경: Native Digital Score 제거·iOS 배포 제외·LAN 검증 우선

- 작업자: Codex
- 목표: 사용자 결정으로 취소된 기능과 배포 플랫폼 범위를 현재 문서에 반영하고 LAN Jam 실기기 검증을 최우선으로 재정렬
- 변경 파일:
  - `docs/ROADMAP.md`
  - `docs/PROJECT_STATUS.yaml`
  - `docs/ARCHITECTURE.md`
  - `README.md`
  - `docs/WORK_LOG.md`
- 완료 내용:
  - Native Digital Score(MVP 8)를 활성 개발 범위와 진행률 집계에서 제외했다. 기존 M8 설계·작업 기록은 변경 이력으로 보존하고 복구 작업은 중단한다.
  - 활성 로드맵을 71/91(78%)로 정리했다.
  - iOS 배포·검증을 범위에서 제외하고 README·아키텍처·상태 문서의 현재 지원 기준을 Android-only로 맞췄다.
  - B-012를 현재 진행 작업으로 지정하고 실제 Android 두 대의 LAN Jam 생성·참가·상태 동기화 검증 순서를 기록했다.
- 검증:
  - 로드맵 활성 체크리스트 91개, 완료 71개로 집계했다.
  - `docs/PROJECT_STATUS.yaml` YAML 파싱과 문서 간 진행률 일치를 확인했다.
  - `flutter test test/features/jam` 통과 — 47 tests passed. 루프백·동기화 단위 검증만 통과했으며 실제 두 대 기기 검증은 남아 있다.
- 남은 일:
  - 같은 Wi-Fi의 실제 Android 두 대에서 B-012 전체 시나리오를 실행하고 결과를 기록한다.
  - Android release keystore 및 Stage/WebDAV 실기기 검증은 후속으로 진행한다.

## 2026-08-26 09:34 KST — 전체 기능 검수와 M8 상태 정정

- 작업자: Codex
- 목표: Library·Setlist 로딩 수정 이후 전체 기능 흐름, 데이터 경계, 플랫폼 위험과 문서 상태를 재검수
- 관련 로드맵: M8-01~M8-06 보류, AUDIT-BPM-001, AUDIT-UI-001
- 변경 파일:
  - `lib/core/storage/song_file_storage.dart`
  - `test/core/storage/song_file_storage_test.dart`
  - `lib/features/library/data/pdf_import_service.dart`
  - `test/features/library/pdf_import_service_test.dart`
  - `docs/ROADMAP.md`
  - `docs/PROJECT_STATUS.yaml`
  - `docs/WORK_LOG.md`
- 확인 및 수정:
  - PDF import 서비스가 20~400 BPM을 허용해 UI·기획의 40~240 기준과 달랐던 경계를 40~240으로 통일했다.
  - 39·241 BPM이 파일 저장 전에 거부되는 회귀 테스트를 추가했다.
  - `SongFileStorage.resolve`에서 절대 경로와 앱 저장소 밖으로 탈출하는 상대 경로를 거부하고 정상 상대 경로 회귀 테스트를 추가했다.
  - 현재 코드 검색에서 MusicXML parser/import, NativeScoreViewer, `scoreType='native_score'` Viewer 분기, PlaybackSequence 구현물이 없고 alphaTab bridge·asset·의존성만 존재하는 것을 확인했다.
  - 문서의 M8 완료 기록을 보류로 정정하고 진행률을 77/97(79%)에서 71/97(73%)로 수정했다.
  - Stage provider의 fullscreen 콜백 no-op, 33개 포맷 drift, ScoreViewer 미사용 private method 경고 4개, 실제 기기·클라우드·LAN 검증 공백을 남은 위험으로 기록했다.
  - Android release signing이 debug 키로 설정된 것을 확인해 Play Store 배포 차단 항목으로 기록했다. 키스토어 없이 임의 설정은 추가하지 않았다.
- 검증:
  - `flutter test test/features/library/pdf_import_service_test.dart` 통과 — 4 tests passed
  - `flutter test test/core/storage/song_file_storage_test.dart` 통과 — 2 tests passed
  - 전체 `flutter test` 통과 — 140 tests passed
  - `flutter build apk --debug` 통과 — `build/app/outputs/flutter-apk/app-debug.apk`
  - `flutter analyze`는 기존 ScoreViewer 미사용 private method 경고 4개로 종료했다.
  - 에뮬레이터 smoke에서 최신 APK 실행 후 SQLite/Flutter 예외 로그가 없었다.
  - `ruby -ryaml -e 'YAML.load_file("docs/PROJECT_STATUS.yaml")'` 통과
- 남은 일:
  - M8 Native Digital Score 구현 복구 전까지 완료로 표시하지 않는다.
  - 잠금 해제 후 실기기 Library·Setlist 직접 확인, 두 대 LAN Jam, WebDAV 실서버 검증이 필요하다.

## 2026-08-26 09:12 KST — Library·Setlist 무한 로딩 DB 복구

- 작업자: Codex
- 목표: 기존 설치에서 Library·Setlist 목록이 로딩에 남는 원인 분석 및 수정
- 관련 로드맵: 유지보수 (MVP 1~8·DS-01 완료 수 변경 없음)
- 변경 파일:
  - `lib/core/database/app_database.dart`
  - `test/core/database/app_database_migration_test.dart`
  - `docs/PROJECT_STATUS.yaml`
  - `docs/ROADMAP.md`
  - `docs/WORK_LOG.md`
- 원인:
  - 연결된 실기기 DB는 `PRAGMA user_version=13`인데 `songs.folder_id`, `folders.parent_id` 등 v15 스키마가 이미 존재했다. 기존 마이그레이션이 컬럼을 다시 추가하다 실패하면 같은 DB를 사용하는 Library·Setlist 스트림이 첫 값을 받지 못할 수 있다.
- 완료:
  - 모든 addColumn 마이그레이션을 `PRAGMA table_info` 확인 후 실행하도록 바꿔 기존 DB를 안전하게 복구한다.
  - schema version 불일치와 현재 컬럼이 함께 있는 경우를 재현하는 회귀 테스트를 추가했다.
- 검증:
  - `dart format` 통과
  - `flutter test` 138개 통과
  - `flutter build apk --debug` 통과
  - Pixel Fold 에뮬레이터에서 Library·Setlist 빈 상태 표시 및 앱 오류 없음 확인
  - `flutter analyze`: 기존 ScoreViewer 미사용 private method 경고 4개
- 남은 일:
  - 실기기 잠금 해제 후 Library·Setlist 화면을 직접 확인한다. 최신 APK 실행으로 DB `user_version`은 13에서 15로 복구됐다.

## 2026-08-21 16:40 KST — 주석 펜·색 확장

- 작업자: Auto
- 목표: 설정 중복 주석 쓰기 제거, 색·펜 다양화, 주석 툴바 추가
- 변경 파일:
  - `lib/features/score_viewer/domain/annotation_stroke.dart` (신규)
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `test/features/score_viewer/annotation_stroke_test.dart` (신규)
- 완료 내용:
  - 악보 설정의 「주석 쓰기」 토글 제거(하단 주석 버튼만 사용).
  - 색 8종, 펜 4종(가는/보통/굵은/형광), 실행 취소·전체 지우기 툴바.
  - 저장 포맷에 색·굵기·투명도 포함, 구 형식도 읽기 가능.
- 검증: annotation + widget 테스트 통과, `flutter test` 전체 확인

## 2026-08-21 16:30 KST — 맞춤 버그 수정과 UI 하이브리드 개편

- 작업자: Auto
- 목표: 세로·맞춤에서 다음 페이지 비침을 고치고, DESIGN 토큰 유지한 채 셸/스테이지 UI를 통일한다
- 관련 로드맵: DS-01 유지
- 변경 파일:
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `lib/app/theme/app_theme.dart`
  - `lib/app/widgets/app_layout.dart` (신규)
  - `lib/features/home|library|tools|jam` 주요 화면
  - 진행 상태 문서
- 완료 내용:
  - 맞춤(`fit`)용 `_layoutFitPages`: 페이지 간격을 뷰포트 이상으로 띄워 letterbox에 다음 장이 안 보이게 함. 페이지 이동은 `_matrixForPage`+`goTo`로 통일.
  - `AppColors.stage*` / `AppTheme.stage`, `AppScreen`·`AppNavRow`·`AppPlayButton` 추가.
  - 라이트 셸(홈·악보·도구)과 다크 스테이지(메트로놈·합주·Viewer) 하이브리드 적용.
- 검증:
  - `dart analyze` — No issues found
  - `flutter test` — 161 tests passed
- 남은 일:
  - B-012 실기기 LAN 검증
  - MVP 4 설정 대기
  - Future 15개

## 2026-08-21 15:50 KST — Future 제외 검수와 UI 압축

- 작업자: Auto
- 목표: Future 제외 완성도 검수 후, 텍스트 버튼·옵션 칩 나열을 아이콘·팝업·접기로 줄인다
- 관련 로드맵: DS-01 유지, Future 제외 범위
- 변경 파일:
  - `lib/app/widgets/compact_controls.dart` (신규)
  - `lib/features/jam/presentation/jam_session_screen.dart`
  - `lib/features/jam/presentation/jam_hub_screen.dart`
  - `lib/features/tools/presentation/metronome_screen.dart`
  - `lib/features/tools/presentation/tempo_trainer_screen.dart`
  - `lib/features/tools/presentation/tap_tempo_screen.dart`
  - `lib/features/tools/domain/metronome_sequence.dart`
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `lib/features/library/presentation/library_screen.dart`
  - `lib/features/home/presentation/home_screen.dart`
  - 진행 상태 문서
- 완료 내용:
  - 검수: MVP 1~8·DS 완료, 남은 것은 Future 15·MVP4 클라우드 설정 대기·B-012 실기기 LAN.
  - 공통 `CompactIconButton` / `CompactOptionTile` / `showOptionPickerSheet` / `SettingsExpansionGroup` 추가.
  - 합주: QR 접기, 클릭 모드 시트, 나가기·이전/다음/열기·세트리스트를 아이콘화. 허브는 원형 아이콘 액션.
  - 메트로놈·Viewer 메트로놈: 박자/Count-In을 칩 나열 대신 옵션 시트로. 재생은 원형 아이콘.
  - Viewer 설정: 재생/진행/연습·동기화/표시로 접기. 하단바·다음 곡 아이콘 압축.
  - 라이브러리 필터는 팝업, 홈·Tap Tempo·Trainer 보조 버튼 아이콘화.
- 검증:
  - `dart analyze` 변경 파일 — No issues found
  - `flutter test` — 161 tests passed
- 남은 일:
  - B-012 실기기 LAN 검증
  - MVP 4 설정 대기 (WebDAV/Google Drive/Dropbox/OneDrive)
  - Future 15개

## 2026-08-21 22:00 KST — 외부 음악 Sync와 Practice/Stage 통합

- 작업자: Qwen
- 목표: Native Score에서 오디오 재생, 로컬 메트로놈, 하단 툴바를 제공한다
- 관련 로드맵: M8-06 `[x]`
- 변경 파일:
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - 진행 상태 문서 3종
- 완료 내용:
  - `_NativeScoreViewerWidget`에 오디오 재생 추가: SoLoud `loadFile`/`play`/`setPause`/`getPosition` 타이머로 재생/일시정지/진행바 갱신.
  - 로컬 메트로놈 추가: `startAt` + `jamMetronomeStepIndex` 절대 step으로 커서 동기화. `ScoreLoadedEvent.tempo`를 BPM 기본값으로 사용.
  - `_NativeScoreToolbar` 위젯 추가: 오디오 진행바(Slider), BPM 표시, 현재 마디·박 표시를 하단에 통합.
  - Jam Session과 로컬 메트로놈 커서 동기화 우선순위: Jam playing > 로컬 메트로놈.
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 161 tests passed
- 남은 일:
  - B-012 실기기 LAN 검증
  - MVP 4 설정 대기 (WebDAV/Google Drive/Dropbox/OneDrive)

## 2026-08-21 20:00 KST — 반복기호와 Playback Sequence

- 작업자: Qwen
- 목표: MusicXML 반복기호(Repeat/Volta/D.C./D.S./Fine/Coda)를 파싱해 실제 연주 순서를 계산한다
- 관련 로드맵: M8-05 `[x]`
- 변경 파일:
  - `lib/features/library/domain/playback_sequence.dart` (신규)
  - `lib/features/library/domain/music_xml_parser.dart`
  - `test/features/library/playback_sequence_test.dart` (신규)
  - 진행 상태 문서 3종
- 완료 내용:
  - `NativeRepeat` 확장: volta(endingNumber/endingType), segno, coda, fine, toCoda, direction(dc/dcAlFine/dcAlCoda/ds/dsAlFine/dsAlCoda) 필드 + copyWith.
  - `_parseRepeat` 확장: `<ending>` 요소에서 volta 번호/타입 파싱.
  - `_parseDirection` (신규): `<direction>`/`<sound>` 요소에서 segno/coda/D.C./D.S./Fine/To-Coda 파싱.
  - `_mergeRepeat` (신규): barline repeat과 direction repeat을 하나의 NativeRepeat으로 병합.
  - `PlaybackSequence` 도메인 모델: pass 기반 반복 계산. repeatCountMap으로 반복별 독립 카운터. D.C./D.S.는 1회만 실행. Fine/To-Coda는 pass > 1에서만 활성. Ending은 pass 번호 매칭.
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 161 tests passed (PlaybackSequence 13개 포함)
- 남은 일:
  - M8-06 외부 음악 Sync와 Practice/Stage 통합
  - B-012 실기기 LAN 검증

## 2026-08-21 18:00 KST — Bar/Beat Cursor

- 작업자: Qwen
- 목표: 현재 재생 위치를 마디·박 단위의 커서로 시각 표시하고 메트로놈과 연동한다
- 관련 로드맵: M8-04 `[x]`
- 변경 파일:
  - `assets/alphatab/index.html`
  - `lib/core/score_engine/alphatab_bridge.dart`
  - `lib/features/score_viewer/presentation/native_score_viewer.dart`
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `test/features/score_viewer/alphatab_bridge_test.dart`
  - 진행 상태 문서 3종
- 완료 내용:
  - `index.html`: cursorBarEl 오버레이 추가. `bridgeSetCursor`에서 `updateCursorOverlay`로 마디 위치에 반투명 파란 하이라이트 표시, `currentBarChanged`/`currentBeatChanged` 이벤트 발송. `bridgeClearCursor`로 제거.
  - `alphatab_bridge.dart`: `ClearCursorCommand` sealed class 추가. 총 8개 Command, 7개 Event.
  - `native_score_viewer.dart`: `updateCursor(measureNumber, beatIndex)`와 `clearCursor()` public 메서드 추가. `ClearCursorCommand` sendCommand 스위치에 연결.
  - `score_viewer_screen.dart`: `_NativeScoreViewerWidget`(ConsumerStatefulWidget) 추가. Jam Session playing 감지 시 100ms 타이머로 `startAt+BPM` 기반 절대 step→measure/beat 계산→`updateCursor` 호출. playing 종료 시 `clearCursor`. 하단에 현재 마디·박 표시 바.
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 148 tests passed (ClearCursorCommand 포함)
- 남은 일:
  - M8-05 반복기호와 Playback Sequence
  - B-012 실기기 LAN 검증

## 2026-08-21 16:00 KST — 드럼/퍼커션 Native Score 렌더링

- 작업자: Qwen
- 목표: alphaTab이 드럼/퍼커션 파트만 필터링해 렌더링하고 화면 크기에 맞춰 스케일한다
- 관련 로드맵: M8-03 `[x]`
- 변경 파일:
  - `assets/alphatab/index.html`
  - `lib/core/score_engine/alphatab_bridge.dart`
  - `lib/features/score_viewer/presentation/native_score_viewer.dart`
  - `test/features/score_viewer/alphatab_bridge_test.dart`
  - 진행 상태 문서 3종
- 완료 내용:
  - `index.html`: `filterDrumTracks()` 함수로 scoreLoaded에서 드럼/퍼커션 파트만 필터링(이름 키워드·isPercussion). `bridgeLoadScoreWithFilter`와 `bridgeAutoScale` JS 함수 추가. responsive 초기 스케일(너비/800, 최대 1.0).
  - `alphatab_bridge.dart`: `LoadScoreWithFilterCommand`(xmlContent + drumOnly)와 `AutoScaleCommand`(containerWidth) sealed class 추가. 총 7개 Command, 7개 Event.
  - `native_score_viewer.dart`: `initState`에서 MusicXML 파일을 비동기 읽어 pending 저장. ready 이벤트 시 `LoadScoreWithFilterCommand`로 자동 로드. `LayoutBuilder`로 `AutoScaleCommand` 적용. `ScoreLoadedEvent` 수신 시 `_ScoreInfoBar`(곡명·아티스트·마디 수·BPM) 하단 표시.
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 147 tests passed (alphaTab Bridge 16개 포함)
- 남은 일:
  - M8-04 Bar/Beat Cursor
  - B-012 실기기 LAN 검증

## 2026-08-21 14:00 KST — alphaTab 연동과 WebView 격리

- 작업자: Qwen
- 목표: alphaTab을 WebView에 격리 호스팅하고 Flutter↔alphaTab Bridge를 구현한다
- 관련 로드맵: M8-02 `[x]`
- 변경 파일:
  - `pubspec.yaml` (webview_flutter ^4.10.0 추가, assets/alphatab/ 등록)
  - `assets/alphatab/index.html` (신규)
  - `lib/core/score_engine/alphatab_bridge.dart` (신규)
  - `lib/features/score_viewer/presentation/native_score_viewer.dart` (신규)
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `test/features/score_viewer/alphatab_bridge_test.dart` (신규)
  - 진행 상태 문서 3종
- 완료 내용:
  - `pubspec.yaml`: webview_flutter ^4.10.0 추가, assets/alphatab/ 경로 등록.
  - `assets/alphatab/index.html`: alphaTab CDN 로드, SVG 엔진 설정, 어두운 테마(#1A1A2E), Bridge 함수 5개(loadScore/goToMeasure/setCursor/setZoom/setLoopRange), FlutterBridge postMessage 채널.
  - `alphatab_bridge.dart`: sealed class 기반 Flutter→alphaTab 5개 Command(LoadScore/GoToMeasure/SetCursor/SetZoom/SetLoopRange)와 alphaTab→Flutter 7개 Event(ready/scoreLoaded/currentBarChanged/currentBeatChanged/scoreTapped/loopRangeSet/error). 각 Command에 toJsCall() 메서드.
  - `native_score_viewer.dart`: WebView 격리 위젯. loadFlutterAsset으로 HTML 로드, JavaScriptChannel('FlutterBridge')로 이벤트 수신, ready 후 pending MusicXML 자동 로드.
  - `score_viewer_screen.dart`: scoreType='native_score' 분기 추가, NativeScoreViewer로 연결.
- 검증:
  - `flutter pub get` 통과
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 145 tests passed (alphaTab Bridge 14개 포함)
- 남은 일:
  - M8-03 드럼/퍼커션 Native Score 렌더링
  - B-012 실기기 LAN 검증

## 2026-08-21 12:00 KST — MusicXML Import

- 작업자: Qwen
- 목표: MusicXML 파일을 읽어 드럼/퍼커션 파트를 파싱하고 곡으로 등록한다
- 관련 로드맵: M8-01 `[x]`
- 변경 파일:
  - `lib/features/library/domain/music_xml_parser.dart` (신규)
  - `lib/features/library/data/music_xml_import_service.dart` (신규)
  - `lib/features/library/data/music_xml_picker.dart` (신규)
  - `lib/core/storage/song_file_storage.dart`
  - `lib/features/library/data/song_repository.dart`
  - `lib/features/library/domain/library_filter.dart`
  - `lib/features/library/presentation/library_screen.dart`
  - `test/features/library/music_xml_parser_test.dart` (신규)
  - 진행 상태 문서 3종
- 완료 내용:
  - `music_xml_parser.dart`: `xml` 패키지로 score-partwise/score-timewise를 파싱. NativeScore/NativePart/NativeMeasure/NativeNote 도메인 모델. 드럼 파트 판정은 MIDI Channel 10과 이름 키워드 기반. unpitched/pitch/notehead/repeat/time 파싱. 14개 공통 드럼 라벨 매핑.
  - `music_xml_import_service.dart`: MusicXmlPreview(드럼 파트 유무·마디 수)와 importMusicXml(파일 복사 + scoreType='native_score' DB 저장) 제공.
  - `SongFileStorage`: storeMusicXml 추가, scores/<songId>.musicxml 경로, MusicXML 헤더 검증.
  - `LibraryFilter`: nativeScore('MusicXML') 필터 추가. SongRepository 필터 스위치 확장.
  - `library_screen.dart`: FAB를 PopupMenuButton으로 변경해 PDF/MusicXML 선택. _ImportMusicXmlSheet로 곡명/아티스트/BPM 입력. scoreType 라벨에 'MusicXML' 추가.
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 131 tests passed (MusicXML 파서 20개 포함)
- 남은 일:
  - M8-02 alphaTab 연동과 WebView 격리
  - B-012 실기기 LAN 검증

## 2026-08-21 10:00 KST — Clock 오차 보정

- 작업자: Qwen
- 목표: 합주 메트로놈의 기기 간 시계 drift를 측정하고 마디 경계에서 보정한다
- 관련 로드맵: M7-07 `[x]`
- 변경 파일:
  - `lib/core/session/jam_clock_sync.dart` (신규)
  - `lib/core/session/jam_session_store.dart`
  - `lib/core/session/lan_jam_session_store.dart`
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `test/features/jam/jam_clock_sync_test.dart` (신규)
  - 진행 상태 문서 3종
- 완료 내용:
  - `jam_clock_sync.dart`: NTP 스타일 RTT offset 추정, 중앙값 필터(3~9 샘플), drift 감지, 마디 경계 보정 startAt 계산 순수 함수.
  - `JamSessionStore` 인터페이스에 `clockOffset`/`clockOffsetStream` 추가. `MemoryJamSessionStore`는 항상 `Duration.zero`.
  - `LanJamSessionStore`: TCP `clock-ping`/`clock-pong` 프로토콜로 Member가 매 3 heartbeat마다 시각 교환. `_handleClockPong`에서 offset 샘플을 수집하고 중앙값을 스트림으로 발행.
  - `score_viewer_screen.dart`: `_subscribeClockOffset()`으로 offset 구독. `_tickJamSyncedMetronome`에서 `startAt + offset`으로 step 계산. offset 갱신 시 drift ≥ 50ms이면 `_pendingClockStartAt`을 예약하고 다음 마디 첫 박(step % stepsPerBar == 0)에서 적용. `_stopMetronome`과 `dispose`에서 정리.
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 111 tests passed
- 남은 일:
  - B-012 실기기 LAN 검증 (Clock 보정 포함)
  - M8-01 MusicXML Import

## 2026-08-20 17:01 KST — Loop 공유

- 작업자: Composer
- 목표: Conductor 구간 반복을 참가자 Viewer에 공유한다
- 관련 로드맵: M7-06 `[x]`
- 변경 파일:
  - `lib/core/session/jam_session.dart`
  - `lib/core/session/jam_session_store.dart`
  - `lib/core/session/lan_jam_session_store.dart`
  - `lib/features/jam/presentation/jam_controller.dart`
  - `lib/features/jam/presentation/jam_session_screen.dart`
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `test/features/jam/jam_session_store_test.dart`
  - `test/features/jam/jam_lan_session_test.dart`
  - 진행 상태 문서 3종 · `docs/ARCHITECTURE.md`
- 완료 내용:
  - `JamLoopState`로 시작·끝 마디·Section·ON/OFF를 공유한다.
  - Conductor Viewer에서 반복 시작/해제·페달이 세션에 반영된다.
  - Member Follow 시 같은 Loop를 켜고, 곡 변경 시 Loop를 지운다.
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 89 tests passed
- 남은 일:
  - M7-07 Clock 오차 보정
  - B-012 실기기 LAN 검증

## 2026-08-20 16:57 KST — Individual Click

- 작업자: Composer
- 목표: Conductor가 각자 로컬 클릭 모드로 전환할 수 있게 한다
- 관련 로드맵: M7-05 `[x]`
- 변경 파일:
  - `lib/core/session/jam_session_store.dart`
  - `lib/core/session/lan_jam_session_store.dart`
  - `lib/features/jam/presentation/jam_controller.dart`
  - `lib/features/jam/presentation/jam_session_screen.dart`
  - `test/features/jam/jam_session_store_test.dart`
  - `test/features/jam/jam_lan_session_test.dart`
  - 진행 상태 문서 3종 · `docs/ARCHITECTURE.md`
- 완료 내용:
  - `updateClickMode`로 Host/Individual을 Conductor만 바꾼다.
  - Individual이면 Member도 로컬 클릭을 재생한다.
  - 세션 화면에서 칩으로 전환한다.
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 88 tests passed
- 남은 일:
  - M7-06 Loop 공유
  - B-012 실기기 LAN 검증

## 2026-08-20 16:52 KST — Host Click

- 작업자: Composer
- 목표: 합주 기본 클릭을 Conductor 기기만 내게 한다
- 관련 로드맵: M7-04 `[x]`
- 변경 파일:
  - `lib/core/session/jam_session.dart`
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `lib/features/jam/presentation/jam_session_screen.dart`
  - `test/features/jam/jam_lan_session_test.dart`
  - 진행 상태 문서 3종 · `docs/ARCHITECTURE.md`
- 완료 내용:
  - `JamClickMode.host`를 기본으로 두고 Member는 클릭 사운드를 막는다.
  - Member도 박자 표시·Follow는 유지한다.
  - 세션 화면에 Host Click을 표시한다. Individual 전환은 M7-05.
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 88 tests passed
- 남은 일:
  - M7-05 Individual Click
  - B-012 실기기 LAN 검증

## 2026-08-20 16:47 KST — Metronome Sync

- 작업자: Composer
- 목표: startAt·BPM으로 합주 박자를 맞춘다
- 관련 로드맵: M7-03 `[x]`
- 변경 파일:
  - `lib/core/session/jam_metronome_sync.dart`
  - `lib/features/tools/domain/metronome_sequence.dart`
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `test/features/jam/jam_metronome_sync_test.dart`
  - 진행 상태 문서 3종 · `docs/ARCHITECTURE.md`
- 완료 내용:
  - `startAt`+BPM으로 절대 step을 계산하고 다음 step 시각에 재예약한다.
  - 놓친 step은 건너뛰고 현재 박만 표시·재생한다.
  - 합주가 아닐 때는 기존 `Timer.periodic`를 유지한다.
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 87 tests passed
- 남은 일:
  - M7-04 Host Click
  - B-012 실기기 LAN 검증

## 2026-08-20 16:39 KST — 공통 시작 시각 합의

- 작업자: Composer
- 목표: Start 시 모든 기기가 같은 시각에 Count-In을 시작한다
- 관련 로드맵: M7-02 `[x]`
- 변경 파일:
  - `lib/core/session/jam_session.dart`
  - `lib/core/session/jam_session_store.dart`
  - `lib/core/session/lan_jam_session_store.dart`
  - `lib/features/jam/presentation/jam_controller.dart`
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `test/features/jam/jam_session_store_test.dart`
  - `test/features/jam/jam_lan_session_test.dart`
  - 진행 상태 문서 3종 · `docs/ARCHITECTURE.md`
- 완료 내용:
  - `updatePlaying(true)` 시 UTC `startAt`(lead 750ms)을 세션에 기록한다.
  - Conductor·Member Viewer는 `startAt`까지 기다린 뒤 로컬 메트로놈을 시작한다.
  - Stop·곡 변경 시 `startAt`을 지운다.
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 84 tests passed
- 남은 일:
  - M7-03 Metronome Sync
  - B-012 실기기 LAN 검증

## 2026-08-20 16:34 KST — Count-In Sync

- 작업자: Composer
- 목표: 합주 Count-In 마디 수를 공유한다
- 관련 로드맵: M7-01 `[x]`
- 변경 파일:
  - `lib/features/tools/domain/metronome_sequence.dart`
  - `lib/features/tools/presentation/metronome_screen.dart`
  - `lib/core/session/jam_session.dart`
  - `lib/core/session/jam_session_store.dart`
  - `lib/core/session/lan_jam_session_store.dart`
  - `lib/features/jam/presentation/jam_controller.dart`
  - `lib/features/jam/presentation/jam_session_screen.dart`
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `test/features/tools/metronome_sequence_test.dart`
  - `test/features/jam/jam_session_store_test.dart`
  - `test/features/jam/jam_lan_session_test.dart`
  - 진행 상태 문서 3종 · `docs/ARCHITECTURE.md`
- 완료 내용:
  - Count-In을 없음/1/2/4마디로 확장하고 `MetronomeSequence`가 여러 마디를 지원한다.
  - 세션 `countInBars`를 Conductor만 갱신·LAN 전파한다.
  - Member Follow 시 같은 Count-In으로 시작하고, 세션 화면에 길이를 표시한다.
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 83 tests passed
- 남은 일:
  - M7-02 공통 시작 시각 합의
  - B-012 실기기 LAN 검증

## 2026-08-20 16:26 KST — Follow Conductor / Return to Live

- 작업자: Composer
- 목표: Member가 Conductor 따라가기와 합주 위치 복귀를 쓴다
- 관련 로드맵: M6-10 `[x]`
- 변경 파일:
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - 진행 상태 문서 3종 · `docs/ARCHITECTURE.md`
- 완료 내용:
  - Member 기본 Follow ON. 수동 페이지·마디 이동 시 FOLLOW OFF.
  - Return to Live로 세션 위치·BPM/Section·재생 상태를 다시 맞춘다.
  - Viewer AppBar·하단·설정에 Follow / Return to Live 진입점을 둔다.
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 81 tests passed
- 남은 일:
  - M7-01 Count-In Sync
  - B-012 실기기 LAN 검증

## 2026-08-20 16:23 KST — Start/Stop 공유

- 작업자: Composer
- 목표: Conductor 메트로놈 Start/Stop을 참가자와 공유한다
- 관련 로드맵: M6-09 `[x]`
- 변경 파일:
  - `lib/core/session/jam_session.dart`
  - `lib/core/session/jam_session_store.dart`
  - `lib/core/session/lan_jam_session_store.dart`
  - `lib/features/jam/presentation/jam_controller.dart`
  - `lib/features/jam/presentation/jam_session_screen.dart`
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `test/features/jam/jam_session_store_test.dart`
  - `test/features/jam/jam_lan_session_test.dart`
  - 진행 상태 문서 3종 · `docs/ARCHITECTURE.md`
- 완료 내용:
  - 세션 `playing`을 Conductor만 갱신하고 LAN으로 전파한다.
  - Conductor Viewer 메트로놈 Start/Stop이 `updatePlaying`을 보낸다.
  - Member Viewer는 Follow 중일 때 재생 상태를 맞춘다. 곡/세트리스트 변경 시 정지.
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 81 tests passed
- 남은 일:
  - M6-10 Follow Conductor/Return to Live

## 2026-08-20 16:20 KST — BPM/Section 공유

- 작업자: Composer
- 목표: Conductor BPM·Section을 참가자 Viewer에 공유한다
- 관련 로드맵: M6-08 `[x]`
- 변경 파일:
  - `lib/core/session/jam_session.dart`
  - `lib/core/session/jam_session_store.dart`
  - `lib/core/session/lan_jam_session_store.dart`
  - `lib/features/jam/presentation/jam_controller.dart`
  - `lib/features/jam/presentation/jam_session_screen.dart`
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `test/features/jam/jam_session_store_test.dart`
  - `test/features/jam/jam_lan_session_test.dart`
  - 진행 상태 문서 3종 · `docs/ARCHITECTURE.md`
- 완료 내용:
  - `JamMusicState`(BPM·Section)를 Conductor만 갱신한다.
  - Member Viewer는 메트로놈 BPM을 맞추고 Section 표식 마디로 이동한다.
  - 세션 화면에 음악 라벨을 표시한다.
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 81 tests passed
- 남은 일:
  - M6-09 Start/Stop 공유

## 2026-08-20 16:14 KST — 페이지/Measure 위치 공유

- 작업자: Composer
- 목표: Conductor 악보 위치를 참가자 Viewer에 공유한다
- 관련 로드맵: M6-07 `[x]`
- 변경 파일:
  - `lib/core/session/jam_session.dart`
  - `lib/core/session/jam_session_store.dart`
  - `lib/core/session/lan_jam_session_store.dart`
  - `lib/features/jam/presentation/jam_controller.dart`
  - `lib/features/jam/presentation/jam_session_screen.dart`
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `test/features/jam/jam_session_store_test.dart`
  - `test/features/jam/jam_lan_session_test.dart`
  - 진행 상태 문서 3종
- 완료 내용:
  - `JamScorePosition`(페이지·마디)을 Conductor만 갱신한다.
  - Conductor Viewer 페이지/마디 변경을 디바운스해 세션에 실어 보낸다.
  - Member Viewer는 같은 곡을 볼 때 위치를 따라가고, 세션 화면에 현재 위치를 표시한다.
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 81 tests passed
- 남은 일:
  - M6-08 BPM/Section 공유

## 2026-08-20 16:07 KST — Conductor 곡 변경

- 작업자: Composer
- 목표: Conductor가 곡을 바꾸면 참가자도 같은 곡을 연다
- 관련 로드맵: M6-06 `[x]`
- 변경 파일:
  - `lib/core/session/jam_session.dart`
  - `lib/core/session/jam_session_store.dart`
  - `lib/core/session/lan_jam_session_store.dart`
  - `lib/features/jam/domain/jam_local_song_match.dart`
  - `lib/features/jam/presentation/jam_controller.dart`
  - `lib/features/jam/presentation/jam_session_screen.dart`
  - `test/features/jam/jam_session_store_test.dart`
  - `test/features/jam/jam_lan_session_test.dart`
  - `test/features/jam/jam_local_song_match_test.dart`
  - 진행 상태 문서 3종
- 완료 내용:
  - 세션에 `currentSongId`를 두고 Conductor만 선택·이전·다음으로 바꾼다.
  - 곡이 바뀌면 참가자가 제목·아티스트로 로컬 악보를 찾아 연다.
  - 세션 화면에 현재 곡과 열기 버튼을 표시한다.
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 81 tests passed
- 남은 일:
  - M6-07 페이지/Measure 위치 공유

## 2026-08-20 15:51 KST — Setlist 공유

- 작업자: Composer
- 목표: 합주 세션에 세트리스트 스냅샷을 공유한다
- 관련 로드맵: M6-05 `[x]`
- 변경 파일:
  - `lib/core/session/jam_session.dart`
  - `lib/core/session/jam_session_store.dart`
  - `lib/core/session/lan_jam_session_store.dart`
  - `lib/features/jam/domain/jam_shared_setlist_mapper.dart`
  - `lib/features/jam/presentation/jam_controller.dart`
  - `lib/features/jam/presentation/jam_session_screen.dart`
  - `test/features/jam/jam_session_store_test.dart`
  - `test/features/jam/jam_lan_session_test.dart`
  - 진행 상태 문서 3종
- 완료 내용:
  - `JamSharedSetlist` 스냅샷을 세션 상태에 실어 Conductor만 공유·변경한다.
  - 세트리스트에서 합주를 만들면 곡 목록이 함께 실리고, 세션 화면에서 선택/바꾸기가 된다.
  - Member는 공유된 목록을 보고, PDF 원본은 각자 로컬에 둔다.
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 79 tests passed
- 남은 일:
  - M6-06 Conductor 곡 변경
  - 실제 두 대 폰에서 세트리스트 공유 확인

## 2026-08-20 15:48 KST — Conductor/Member 역할

- 작업자: Composer
- 목표: Conductor와 Member 권한을 구분한다
- 관련 로드맵: M6-04 `[x]`
- 변경 파일:
  - `lib/core/session/jam_session.dart`
  - `lib/features/jam/presentation/jam_session_screen.dart`
  - `test/features/jam/jam_session_store_test.dart`
  - 진행 상태 문서 3종
- 완료 내용:
  - `JamPermissions`로 초대·리드·Follow 권한을 나눈다.
  - Conductor만 코드/QR을 보고, 끝내는 버튼은 Conductor/Member에 따라 다르다.
  - 내 역할을 세션 화면에 표시한다.
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 76 tests passed
- 남은 일:
  - M6-05 Setlist 공유
  - 실제 두 대 폰에서 역할별 화면 확인

## 2026-08-20 15:42 KST — Participant Presence

- 작업자: Composer
- 목표: 합주 참가자가 들어와 있는지 바로 보이게 한다
- 관련 로드맵: M6-03 `[x]`
- 변경 파일:
  - `lib/core/session/jam_session.dart`
  - `lib/core/session/lan_jam_session_store.dart`
  - `lib/features/jam/presentation/jam_session_screen.dart`
  - `test/features/jam/jam_session_store_test.dart`
  - `test/features/jam/jam_lan_session_test.dart`
  - 진행 상태 문서 3종
- 완료 내용:
  - 세션 화면에 인원 수, 연결 상태, 나를 표시한다.
  - 게스트 ping과 호스트 타임아웃으로 끊긴 멤버를 목록에서 뺀다.
  - 소켓이 닫히면 즉시 Presence를 갱신한다.
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 75 tests passed
- 남은 일:
  - M6-04 Conductor/Member 역할
  - 실제 두 대 폰에서 참가/퇴장 확인

## 2026-08-20 15:35 KST — QR/Code 초대

- 작업자: GPT-5.6 Sol
- 목표: 합주 코드를 QR로 보여주고 스캔해 참가
- 관련 로드맵: M6-02 `[x]`
- 변경 파일:
  - `pubspec.yaml`, `pubspec.lock`
  - `lib/core/session/jam_session.dart`
  - `lib/features/jam/presentation/jam_session_screen.dart`
  - `lib/features/jam/presentation/jam_hub_screen.dart`
  - `lib/features/jam/presentation/jam_qr_scan_screen.dart`
  - `android/app/src/main/AndroidManifest.xml`
  - `ios/Runner/Info.plist`
  - `test/features/jam/jam_session_store_test.dart`
  - 진행 상태 문서 3종
- 완료 내용:
  - 세션 화면에 코드와 초대 QR을 함께 표시하고 복사를 유지한다.
  - 합주 허브에서 코드 입력 또는 QR 스캔으로 참가한다.
  - QR 값은 `pageadiddle:jam:` 접두사와 4자리 코드다.
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 71 tests passed
- 남은 일:
  - M6-03 Participant Presence
  - 실제 두 대 폰에서 QR 스캔 확인

## 2026-08-20 15:25 KST — 같은 Wi-Fi Jam Session

- 작업자: GPT-5.6 Sol
- 목표: 클라우드 없이 같은 Wi-Fi에서 합주 참가
- 관련 로드맵: M6-01 `[x]` (LAN 전송)
- 변경 파일:
  - `lib/core/session/lan_jam_session_store.dart`
  - `lib/core/session/jam_lan_codec.dart`
  - `lib/core/session/jam_session.dart`
  - `lib/features/jam/presentation/jam_controller.dart`
  - `lib/features/jam/presentation/jam_hub_screen.dart`
  - `android/app/src/main/AndroidManifest.xml`
  - `ios/Runner/Info.plist`
  - `test/features/jam/jam_lan_session_test.dart`
  - `docs/ARCHITECTURE.md`
  - 진행 상태 문서 3종
- 완료 내용:
  - 만들기 한 기기가 로컬에서 세션을 열고 UDP로 코드를 알린다.
  - 같은 Wi-Fi의 다른 기기는 코드로 찾아 TCP로 참가한다.
  - 클라우드 서버는 쓰지 않는다.
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 70 tests passed
- 남은 일:
  - M6-02 QR/Code 초대
  - 실제 두 대 폰에서 같은 Wi-Fi 참가 확인 (B-012)

## 2026-08-20 15:15 KST — Jam Session 생성/참가

- 작업자: GPT-5.6 Sol
- 목표: 합주 세션을 만들고 코드로 참가
- 관련 로드맵: M6-01 `[x]`
- 변경 파일:
  - `lib/core/session/jam_session.dart`
  - `lib/core/session/jam_session_store.dart`
  - `lib/features/jam/presentation/jam_controller.dart`
  - `lib/features/jam/presentation/jam_hub_screen.dart`
  - `lib/features/jam/presentation/jam_session_screen.dart`
  - `lib/app/router/app_router.dart`
  - `lib/features/home/presentation/home_screen.dart`
  - `lib/features/tools/presentation/tools_screen.dart`
  - `lib/features/setlists/presentation/setlist_detail_screen.dart`
  - `test/features/jam/jam_session_store_test.dart`
  - `docs/ARCHITECTURE.md`
  - 진행 상태 문서 3종
- 완료 내용:
  - 홈·도구·세트리스트에서 합주를 열고 이름과 4자리 코드로 만들거나 참가한다.
  - 세션 화면에 코드·Conductor·Members를 표시하고 Conductor가 나가면 세션이 끝난다.
  - realtime 백엔드가 없어 같은 앱 프로세스의 Memory store만 사용한다.
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 67 tests passed
- 남은 일:
  - M6-02 QR/Code 초대
  - 기기 간 합주용 Firebase/Supabase 설정 (B-011)

## 2026-08-20 14:55 KST — Setlist 공연 진행

- 작업자: GPT-5.6 Sol
- 목표: Stage에서 세트리스트 곡을 순서대로 진행
- 관련 로드맵: M5-05 `[x]`
- 변경 파일:
  - `lib/features/stage/domain/stage_setlist_progress.dart`
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `lib/features/setlists/presentation/setlist_detail_screen.dart`
  - `test/features/stage/stage_setlist_progress_test.dart`
  - 진행 상태 문서 3종
- 완료 내용:
  - 세트리스트 상단과 곡 행에서 저장 곡부터 Stage를 시작한다.
  - 오프라인 곡만 세어 이전·다음 곡을 고르고, Stage 첫·마지막 페이지에서 곡을 넘긴다.
  - Stage HUD에 곡명, 순서, BPM, 다음 곡, Section Preview를 표시한다.
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 62 tests passed
- 남은 일:
  - M6-01 Jam Session 생성/참가
  - WebDAV 실서버 확인 (B-009)

## 2026-08-20 14:50 KST — Bluetooth Pedal/Keyboard 매핑

- 작업자: GPT-5.6 Sol
- 목표: 공연 중 페달·키보드로 페이지·재생·반복을 제어
- 관련 로드맵: M5-04 `[x]`
- 변경 파일:
  - `lib/features/stage/domain/performance_action.dart`
  - `lib/features/stage/domain/pedal_gesture_interpreter.dart`
  - `lib/features/stage/domain/performance_key_map.dart`
  - `lib/features/stage/data/performance_key_map_store.dart`
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `test/features/stage/pedal_gesture_interpreter_test.dart`
  - `test/features/stage/performance_key_map_test.dart`
  - `test/features/stage/performance_key_map_store_test.dart`
  - 진행 상태 문서 3종
- 완료 내용:
  - 왼쪽/오른쪽 짧은 입력은 이전·다음 페이지, 길게 누르면 재생/일시정지, 두 번은 반복이다.
  - 키보드 `P`/`L`과 화살표·Page·Space 기본 키를 같은 Action에 연결한다.
  - Viewer 설정 페달 시트에서 키를 바꾸고 앱 문서 JSON에 저장한다. Stage에서도 페달은 동작한다.
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 58 tests passed
- 남은 일:
  - M5-05 Setlist 공연 진행
  - 물리 페달 HID 입력 확인

## 2026-08-20 14:38 KST — Performance Lock

- 작업자: GPT-5.6 Sol
- 목표: Stage Viewer에서 편집과 실수 터치를 차단
- 관련 로드맵: M5-03 `[x]`
- 변경 파일:
  - `lib/features/stage/domain/stage_performance_lock.dart`
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `test/features/stage/stage_performance_lock_test.dart`
  - 진행 상태 문서 3종
- 완료 내용:
  - Stage에서는 메뉴·Measure/주석 편집·BPM·Sync·Cue 편집 UI를 차단한다.
  - 좌우 가장자리 탭과 스와이프 페이지 이동, 두 손가락 Zoom만 허용한다.
  - 가운데 터치와 상·하단 크롬은 무시하며, Stage 진입 시 편집 상태를 초기다.
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 48 tests passed
- 남은 일:
  - M5-04 Bluetooth Pedal/Keyboard 매핑
  - M5-05 Setlist 공연 진행

## 2026-08-20 14:29 KST — 다음 Section Preview

- 작업자: GPT-5.6 Sol
- 목표: Stage Viewer에서 현재 구간과 다음 Section 전환 시점 표시
- 관련 로드맵: M5-02 `[x]`
- 변경 파일:
  - `lib/features/stage/domain/stage_section_preview.dart`
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `test/features/stage/stage_section_preview_test.dart`
  - 진행 상태 문서 3종
- 완료 내용:
  - 현재 마디 이하의 마지막 Section 표식을 현재 구간으로 해석한다.
  - 이후 처음 등장하는 다른 Section과 남은 마디 수를 계산한다.
  - Stage Viewer 상단에 현재 마디와 `다음 CHORUS · 8마디 후` 형식의 Preview를 표시한다.
  - 현재 마디가 아직 없으면 첫 마디를 기준으로 하며, Measure 또는 다음 Section이 없어도 안전하게 처리한다.
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 46 tests passed
  - `flutter build apk --debug` 통과
- 남은 일:
  - M5-03 Performance Lock
  - 물리 기기에서 Stage Preview 가독성과 장시간 화면 유지 확인

## 2026-08-20 14:22 KST — Stage Mode와 화면 유지

- 작업자: GPT-5.6 Sol
- 목표: 세트리스트 공연 Viewer와 화면 자동 꺼짐 방지
- 관련 로드맵: M5-01 `[x]`
- 변경 파일:
  - `pubspec.yaml`, `pubspec.lock`
  - `lib/features/stage/data/stage_mode_controller.dart`
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `lib/features/setlists/presentation/setlist_detail_screen.dart`
  - `lib/app/router/app_router.dart`
  - `test/features/stage/stage_mode_controller_test.dart`
  - 진행 상태 문서 3종
- 완료 내용:
  - 세트리스트에서 첫 오프라인 곡으로 Stage Mode를 시작한다.
  - Stage Viewer는 메뉴와 시스템 UI를 숨기고 `wakelock_plus`로 화면 꺼짐을 막는다.
  - 다음 곡 이동에도 `stage=true`를 유지하고 Viewer 간 화면 잠금을 공유한다.
  - 마지막 Stage Viewer 종료 시 edge-to-edge UI와 기본 화면 잠금 상태로 복구한다.
  - 진입 실패 후에도 종료 정리가 실행되고 플러그인 오류를 사용자와 Flutter 오류 채널에 노출한다.
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 41 tests passed
  - `flutter build apk --debug` 통과
- 남은 일:
  - M5-02 다음 Section Preview
  - 물리 기기에서 장시간 화면 유지 확인

## 2026-08-20 14:18 KST — 세트리스트 오프라인 다운로드

- 작업자: GPT-5.6 Sol
- 목표: WebDAV 세트리스트를 공연 전에 한 번에 오프라인 저장
- 관련 로드맵: M4-07 `[x]`
- 변경 파일:
  - `lib/core/storage/song_file_storage.dart`
  - `lib/features/storage/data/webdav_connection.dart`
  - `lib/features/storage/data/remote_score_service.dart`
  - `lib/features/storage/presentation/webdav_browser_screen.dart`
  - `lib/features/library/data/song_repository.dart`
  - `lib/features/library/presentation/library_screen.dart`
  - `lib/features/setlists/data/setlist_offline_service.dart`
  - `lib/features/setlists/presentation/setlist_detail_screen.dart`
  - `test/features/storage/remote_score_service_test.dart`
  - `test/features/storage/webdav_connection_test.dart`
  - 진행 상태 문서 3종
- 완료 내용:
  - WebDAV PDF를 Library에 Cloud Only 곡으로 등록한다.
  - 세트리스트의 미저장·업데이트 WebDAV 곡을 순차 다운로드하고 실패 곡 수를 표시한다.
  - PDF 헤더 검증 후 앱 저장소에 보관하고 원격 수정 시각·크기와 Synced 상태를 갱신한다.
  - 동일 HTTPS origin의 PDF만 허용하고 리디렉션과 100MB 초과 파일을 차단한다.
  - 오프라인 파일이 없는 Library·세트리스트 곡은 Viewer를 열지 않는다.
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 39 tests passed
  - `flutter build apk --debug` 통과
- 남은 일:
  - 실제 WebDAV 서버에서 등록·다운로드 검증
  - M5-01 Stage Mode와 화면 꺼짐 방지

## 2026-08-20 14:10 KST — 외부 파일 동기화 상태

- 작업자: GPT-5.6 Sol
- 목표: 원격 파일과 오프라인 복사본의 상태 계산 및 표시
- 관련 로드맵: M4-06 `[x]`
- 변경 파일:
  - `lib/core/database/app_database.dart`, `app_database.g.dart`
  - `lib/core/storage/storage_provider.dart`
  - `lib/features/storage/domain/sync_status.dart`
  - `lib/features/storage/presentation/webdav_browser_screen.dart`
  - `lib/features/library/data/song_repository.dart`
  - `lib/features/library/presentation/library_screen.dart`
  - `test/features/storage/sync_status_test.dart`
  - `test/features/library/song_repository_test.dart`
  - 진행 상태 문서 3종
- 완료 내용:
  - DB v13에 원격 URI·수정 시각·크기·동기화 상태를 추가했다.
  - Cloud Only·Offline Available·Synced·Updated·Missing 상태를 원격 스냅샷으로 계산한다.
  - WebDAV 폴더 조회 시 같은 폴더의 연결 곡을 대조해 변경·누락 상태를 저장한다.
  - WebDAV 목록과 Library 곡 정보에 현재 상태를 표시한다.
- 검증:
  - `dart run build_runner build --delete-conflicting-outputs` 통과
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 36 tests passed
  - `flutter build apk --debug` 통과
- 남은 일:
  - M4-07 세트리스트 단위 오프라인 다운로드
  - 실제 WebDAV 서버에서 상태 변화 검증

## 2026-08-20 14:03 KST — WebDAV 폴더 탐색

- 작업자: GPT-5.6 Sol
- 목표: 연결한 WebDAV 서버의 폴더와 PDF 탐색
- 관련 로드맵: M4-05 `[~]`
- 변경 파일:
  - `pubspec.yaml`, `pubspec.lock`
  - `lib/features/storage/data/webdav_connection.dart`
  - `lib/features/storage/presentation/webdav_screen.dart`
  - `lib/features/storage/presentation/webdav_browser_screen.dart`
  - `lib/app/router/app_router.dart`
  - `test/features/storage/webdav_connection_test.dart`
  - 진행 상태 문서 3종
- 완료 내용:
  - `PROPFIND Depth: 1` XML에서 폴더와 PDF 이름·URI·크기·수정 시각을 읽는다.
  - DAV XML 접두사 유무와 관계없이 파싱하고 다른 서버 origin과 PDF 외 파일을 제외한다.
  - 폴더 우선 정렬, 하위·상위 폴더 이동, 빈 목록과 재시도 화면을 추가했다.
  - 상대 URL 해석을 위해 WebDAV 루트를 디렉터리 URI로 정규화한다.
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 34 tests passed
  - `flutter build apk --debug` 통과
- 남은 일:
  - 실제 WebDAV 서버 호환성 확인
  - M4-06 동기화 상태

## 2026-08-20 13:55 KST — WebDAV 보안 연결

- 작업자: GPT-5.6 Sol
- 목표: 외부 앱 등록 없이 진행 가능한 WebDAV/NAS 연결 구현
- 관련 로드맵: M4-01~M4-03 `[-]`, M4-04 `[~]`
- 변경 파일:
  - `pubspec.yaml`, `pubspec.lock`
  - `lib/features/storage/**`
  - `lib/features/tools/presentation/tools_screen.dart`
  - `lib/app/router/app_router.dart`
  - `android/app/src/main/AndroidManifest.xml`
  - `ios/Runner/*.entitlements`
  - `ios/Runner.xcodeproj/project.pbxproj`
  - `test/features/storage/webdav_connection_test.dart`
  - 진행 상태 문서 3종
- 완료 내용:
  - 도구에 WebDAV 설정 화면을 추가하고 HTTPS 서버에 `PROPFIND Depth: 0`으로 연결·인증을 확인한다.
  - 서버 주소와 계정은 Drift에 저장하지 않고 Android Keystore/iOS Keychain 기반 `flutter_secure_storage`에 저장한다.
  - Android INTERNET 권한·백업 제외와 iOS Keychain entitlement를 구성했다.
  - Google Drive·Dropbox·OneDrive 앱 내부 연결에 필요한 외부 설정은 `PROJECT_STATUS.yaml/setup_required`에 모았다.
- 검증:
  - `dart format` 통과
  - entitlement plist 문법 검사 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 32 tests passed
  - `flutter build apk --debug` 통과
- 남은 일:
  - 실제 HTTPS WebDAV 서버에서 연결·저장·해제 확인
  - M4-05 WebDAV 폴더/PDF 탐색

## 2026-08-20 13:40 KST — OS 파일 제공자 기록 정정

- 작업자: GPT-5.6 Sol
- 목표: OS 파일 선택기가 노출하지 않는 Google Drive 원본을 추정해 기록하지 않도록 가져오기 경로 정정
- 관련 로드맵: M4-01 `[~]`
- 변경 파일:
  - `lib/core/storage/storage_provider.dart`
  - `lib/features/library/presentation/library_screen.dart`
  - `test/features/library/pdf_import_service_test.dart`
  - `docs/PROJECT_STATUS.yaml`
  - `docs/ROADMAP.md`
  - `docs/WORK_LOG.md`
- 완료 내용:
  - 기기·Google Drive를 미리 고르는 중복 선택 화면을 제거하고 OS 파일 선택기를 바로 연다.
  - 선택기가 실제 원본 서비스를 알려주지 않으므로 `google_drive` 대신 확인 가능한 `os_file_provider`를 저장한다.
  - Google Drive 서비스명과 원격 파일 ID는 OAuth/API 연결 전까지 기록하지 않는다.
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 29 tests passed
- 남은 일:
  - Google Cloud OAuth 설정을 받은 뒤 로그인·Drive 파일 목록·원격 파일 ID를 연결한다.

## 2026-08-20 13:29 KST — Google Drive 가져오기 경로

- 작업자: Codex
- 목표: 외부 저장소 MVP의 첫 단계로 Library에서 Google Drive 원본을 구분해 가져오기
- 관련 로드맵: M4-01 `[~]`
- 변경 파일:
  - `lib/core/storage/storage_provider.dart`
  - `lib/features/library/data/pdf_import_service.dart`
  - `lib/features/library/presentation/import_score_sheet.dart`
  - `lib/features/library/presentation/library_screen.dart`
  - `test/features/library/pdf_import_service_test.dart`
  - `docs/PROJECT_STATUS.yaml`
  - `docs/ROADMAP.md`
  - `docs/WORK_LOG.md`
- 완료 내용:
  - 가져오기 버튼에서 기기 또는 Google Drive를 선택한다.
  - Google Drive 선택은 기기·Drive를 함께 제공하는 기존 OS 파일 선택기를 재사용한다.
  - 앱 저장소로 복사한 곡에 `Songs.sourceProvider = google_drive`를 기록하고 Library에 표시한다.
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 29 tests passed
  - `flutter build apk --debug` 통과
  - Pixel Fold API 35에 APK 재설치·앱 실행, 신규 Flutter/FATAL/SQLite/Drift 앱 예외 없음 확인
- 남은 일:
  - Google Cloud OAuth 클라이언트와 동의 화면 설정 후 앱 내부 로그인·Drive 파일 목록을 연결한다.

## 2026-08-20 13:19 KST — 연습 통계

- 작업자: Codex
- 목표: 저장된 연습 세션에서 곡별 진행 상황을 바로 확인하기
- 관련 로드맵: M3-06
- 변경 파일:
  - `lib/features/practice/domain/practice_stats.dart`
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `test/features/practice/practice_stats_test.dart`
  - `docs/PROJECT_STATUS.yaml`
  - `docs/ROADMAP.md`
  - `docs/WORK_LOG.md`
- 완료 내용:
  - 연습 기록 시트에 횟수·총 시간·평균 BPM·최고 BPM을 표시한다.
  - 목표 BPM이 있으면 목표 달성 또는 남은 BPM을 표시한다.
  - 기록이 없는 상태를 0으로 계산하고 표시하는 순수 통계 로직과 테스트를 추가했다.
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 28 tests passed
  - `flutter build apk --debug` 통과
  - Pixel Fold API 35에 APK 재설치·앱 실행, Flutter/FATAL/SQLite/Drift 앱 예외 없음 확인
- 남은 일:
  - 날짜별 차트와 Measure/Section별 통계는 후속 범위로 둔다.

## 2026-08-20 13:01 KST — Measure/Section 구간 반복 연습

- 작업자: Codex
- 목표: 기존 구간 반복에서 Measure 또는 Section을 골라 연습하기
- 관련 로드맵: M3-05
- 변경 파일:
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `docs/PROJECT_STATUS.yaml`
  - `docs/ROADMAP.md`
  - `docs/WORK_LOG.md`
- 완료 내용:
  - M2-09의 AudioAnchor 반복 흐름을 재사용해 반복 범위를 `마디 범위` 또는 Section으로 선택한다.
  - Section 선택 시 해당 Section의 첫·끝 Anchor를 자동 채우고, Anchor가 2개 미만이면 반복 시작을 막는다.
  - 설정 팝업의 구간 반복 항목에 현재 Section과 마디 범위를 표시한다.
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 26 tests passed
  - `flutter build apk --debug` 통과
  - Pixel Fold API 35에 APK 재설치·앱 실행, Flutter/FATAL/SQLite/Drift 앱 예외 없음 확인
- 남은 일:
  - Anchor 없는 PDF의 시간 기반 자동 반복은 후속 범위로 둔다.

## 2026-08-20 11:23 KST — 곡별 목표 BPM과 Tempo Trainer 연결

- 작업자: Codex
- 목표: 곡마다 목표 BPM을 저장하고 악보 연습에서 Tempo Trainer로 이어지게 하기
- 관련 로드맵: M3-04
- 변경 파일:
  - `lib/core/database/app_database.dart`
  - `lib/core/database/app_database.g.dart`
  - `lib/features/library/data/song_repository.dart`
  - `lib/features/library/presentation/library_screen.dart`
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `lib/features/tools/presentation/tempo_trainer_screen.dart`
  - `lib/app/router/app_router.dart`
  - `test/features/library/song_repository_test.dart`
  - `docs/PROJECT_STATUS.yaml`
  - `docs/ROADMAP.md`
  - `docs/WORK_LOG.md`
- 완료 내용:
  - `Songs.targetBpm`과 DB v12 마이그레이션, 40~240 BPM 저장 검증을 추가했다.
  - Viewer 연습 기록에서 목표 BPM을 저장·해제하고 Library 곡 정보에 표시한다.
  - 시작·목표 BPM을 유지한 채 Viewer에서 Tempo Trainer를 바로 연다. Trainer에서 바꾼 목표 BPM도 곡에 저장한다.
- 검증:
  - `dart run build_runner build --delete-conflicting-outputs` 통과
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 26 tests passed
  - `flutter build apk --debug` 통과
  - Pixel Fold API 35에 APK 재설치·앱 실행, Flutter/FATAL/SQLite/Drift 앱 예외 없음 확인
- 남은 일:
  - Measure/Section별 목표 BPM과 구간 반복은 M3-05 이후 범위로 둔다.

## 2026-08-20 11:12 KST — 연습 세션 기록

- 작업자: Codex
- 목표: 악보를 보며 시작·종료한 연습을 곡별로 저장하고 최근 기록을 확인하기
- 관련 로드맵: M3-03
- 변경 파일:
  - `lib/core/database/app_database.dart`
  - `lib/core/database/app_database.g.dart`
  - `lib/features/practice/data/practice_session_repository.dart`
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `test/features/practice/practice_session_repository_test.dart`
  - `docs/PROJECT_STATUS.yaml`
  - `docs/ROADMAP.md`
  - `docs/WORK_LOG.md`
- 완료 내용:
  - `PracticeSessions` 테이블과 DB v11 마이그레이션을 추가했다.
  - Viewer 설정의 연습 기록에서 BPM을 입력해 연습을 시작하고, 기록 종료 시 시작·종료 시각과 재생 시간을 저장한다.
  - 곡별 누적 횟수·시간·최고 BPM과 최근 5회 기록을 같은 시트에서 확인한다.
  - 종료 시각과 BPM 범위를 저장소에서 검증한다.
- 검증:
  - `dart run build_runner build --delete-conflicting-outputs` 통과
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 25 tests passed
  - `flutter build apk --debug` 통과
  - Pixel Fold API 35에 APK 재설치·앱 실행, Flutter/FATAL/SQLite 앱 예외 없음 확인
- 남은 일:
  - 앱 종료·중단 자동 복구와 목표 BPM은 각각 후속 범위(M3-04 이후)로 둔다.

## 2026-08-20 11:01 KST — 어려운 Measure 태그와 Library 필터

- 작업자: Codex
- 목표: 어려운 마디를 표시하고 Library에서 해당 곡을 빠르게 찾기
- 관련 로드맵: M3-02
- 변경 파일:
  - `lib/core/database/app_database.dart`
  - `lib/core/database/app_database.g.dart`
  - `lib/features/smart_score/data/measure_repository.dart`
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `lib/features/library/domain/library_filter.dart`
  - `lib/features/library/data/song_repository.dart`
  - `test/features/smart_score/measure_repository_test.dart`
  - `test/features/library/song_repository_test.dart`
  - `docs/PROJECT_STATUS.yaml`
  - `docs/ROADMAP.md`
  - `docs/WORK_LOG.md`
- 완료 내용:
  - Measures에 `isDifficult`와 DB v10 마이그레이션을 추가했다.
  - Viewer 설정에서 마디를 선택해 Difficult를 켜고 끌 수 있으며 악보 위에 배지를 표시한다.
  - Library 필터에 `어려운`을 추가하고 Difficult 마디가 있는 곡만 조회한다.
  - 태그 변경·삭제 시 곡 메타데이터를 갱신해 필터 스트림이 다시 조회되게 했다.
- 검증:
  - `dart run build_runner build --delete-conflicting-outputs` 통과
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 23 tests passed
  - `flutter build apk --debug` 통과
  - Pixel Fold API 35 APK 재설치·앱 실행 및 Flutter/FATAL/SQLite 앱 예외 없음 확인
- 남은 일:
  - Fill·Practice·Mistake·Important 등 추가 태그는 연습 기록 범위에서 확장한다.

## 2026-08-20 10:52 KST — Tempo Trainer

- 작업자: Codex
- 목표: 반복 완료에 따라 BPM을 단계적으로 올리는 최소 연습 도구 제공
- 관련 로드맵: M3-01
- 변경 파일:
  - `lib/features/tools/domain/tempo_trainer.dart`
  - `lib/features/tools/presentation/tempo_trainer_screen.dart`
  - `lib/features/tools/presentation/tools_screen.dart`
  - `lib/app/router/app_router.dart`
  - `test/features/tools/tempo_trainer_test.dart`
  - `docs/PROJECT_STATUS.yaml`
  - `docs/ROADMAP.md`
  - `docs/WORK_LOG.md`
- 완료 내용:
  - 시작 BPM·목표 BPM·증가량·반복 횟수를 입력하고 40~240 BPM/유효 범위를 검증한다.
  - `반복 완료`를 누르면 설정한 반복 횟수마다 증가량만큼 BPM을 올리고 목표 BPM에서 세션을 끝낸다.
  - 기존 `MetronomeSequence`와 SoLoud 클릭을 재사용해 4/4 메트로놈을 같은 화면에서 실행한다.
  - 도구 목록과 `/tools/tempo-trainer` 라우트를 추가했다.
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 22 tests passed
  - `flutter build apk --debug` 통과
  - Pixel Fold API 35 APK 재설치·앱 실행 및 Flutter/FATAL/SQLite 앱 예외 없음 확인
- 남은 일:
  - 곡·Measure 연결, 자동 반복 측정, 연습 기록은 M3-02 이후 범위로 둔다.

## 2026-08-20 10:42 KST — Cue 등록과 표시

- 작업자: Codex
- 목표: 악보 마디에 짧은 Cue를 저장하고 Viewer에서 바로 확인
- 관련 로드맵: M2-11
- 변경 파일:
  - `lib/core/database/app_database.dart`
  - `lib/core/database/app_database.g.dart`
  - `lib/features/smart_score/data/cue_repository.dart`
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `test/features/smart_score/measure_repository_test.dart`
  - `docs/PROJECT_STATUS.yaml`
  - `docs/ROADMAP.md`
  - `docs/WORK_LOG.md`
- 완료 내용:
  - Cues 테이블과 DB v9 마이그레이션을 추가했다.
  - Viewer 설정에서 마디를 선택해 Cue를 등록·수정·삭제한다.
  - 같은 곡·마디 저장은 기존 Cue를 덮어쓰고, 최대 40자의 짧은 표시만 저장한다.
  - Cue를 악보 마디 하단에 표시하고, 일반 Measure 테두리는 표시하지 않는다.
- 검증:
  - `dart run build_runner build --delete-conflicting-outputs` 통과
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 20 tests passed
  - `flutter build apk --debug` 통과
  - Pixel Fold API 35 APK 재설치·앱 실행 및 Flutter/FATAL/SQLite 예외 없음 확인
- 남은 일:
  - Cue Sound와 복합 Playback Sequence는 후속 범위로 둔다.

## 2026-08-20 10:30 KST — Viewer 재생 속도

- 작업자: Codex
- 목표: 연결된 음악을 느리게·빠르게 들으며 악보를 연습할 수 있는 최소 속도 조절 제공
- 관련 로드맵: M2-10
- 변경 파일:
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `docs/PROJECT_STATUS.yaml`
  - `docs/ROADMAP.md`
  - `docs/WORK_LOG.md`
- 완료 내용:
  - Viewer 설정에 `0.5x~1.5x` 재생 속도 시트를 추가했다.
  - 새 재생 핸들과 현재 재생 핸들 모두 SoLoud 상대 재생 속도를 적용한다.
  - 속도는 DB에 저장하지 않고 Viewer 세션에서만 유지한다.
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 20 tests passed
  - `flutter build apk --debug` 통과
  - Pixel Fold API 35 APK 재설치·앱 실행 및 Flutter/FATAL/SQLite 예외 없음 확인

## 2026-08-20 10:27 KST — 오디오 출력 보강과 Sync Anchor·구간 반복

- 작업자: Codex
- 목표: 무음으로 보이는 메트로놈 출력 경로를 보강하고 M2-08~M2-09를 진행
- 관련 로드맵: M2-08, M2-09
- 변경 파일:
  - `lib/core/audio/audio_engine_provider.dart`
  - `lib/core/database/app_database.dart`
  - `lib/core/database/app_database.g.dart`
  - `lib/features/tools/presentation/metronome_screen.dart`
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `lib/features/smart_score/data/audio_anchor_repository.dart`
  - `test/features/smart_score/measure_repository_test.dart`
  - `docs/PROJECT_STATUS.yaml`
  - `docs/ROADMAP.md`
  - `docs/WORK_LOG.md`
- 완료 내용:
  - SoLoud 오디오 버퍼를 512로 줄이고 waveform 클릭을 140ms 유지해 출력 버퍼 지연으로 짧게 끊기는 경로를 보강했다.
  - AudioAnchors 테이블과 DB v8 마이그레이션, 마디별 오디오 초 저장·수정·삭제 UI를 추가했다.
  - 음악 재생 중 100ms 위치 추적, Anchor 사이 선형 보간, 현재 마디 Highlight/Page 자동 이동을 연결했다.
  - Anchor 두 개를 시작·끝으로 선택하는 A-B 구간 반복과 반복 해제를 추가했다.
  - Pixel Fold API 35에서는 앱의 재생 호출 이후 Ranchu `pcmWrite` I/O 오류가 발생해 실제 청취는 검증하지 못한 사실을 상태 blocker로 기록했다.
- 검증:
  - `dart run build_runner build --delete-conflicting-outputs` 통과
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 20 tests passed
  - `flutter build apk --debug` 통과
  - Pixel Fold API 35 APK 재설치·앱 실행 및 Flutter/FATAL/SQLite 예외 없음 확인

## 2026-08-20 10:11 KST — 음표 아이콘과 박자표 확장

- 작업자: Codex
- 목표: 메트로놈의 음표 단위를 실제 음표 아이콘으로 표시하고 다양한 박자표를 두 화면에 공통 제공
- 관련 로드맵: M1-12 보강
- 변경 파일:
  - `lib/features/tools/domain/metronome_sequence.dart`
  - `lib/features/tools/presentation/metronome_subdivision_icon.dart`
  - `lib/features/tools/presentation/metronome_screen.dart`
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `test/features/tools/metronome_sequence_test.dart`
  - `docs/PROJECT_STATUS.yaml`
  - `docs/ROADMAP.md`
  - `docs/WORK_LOG.md`
- 완료 내용:
  - 4분음표, 8분음표, 16분음표 4연/6연, 셋잇단을 외부 이미지 의존성 없이 CustomPainter 음표 아이콘으로 표시했다.
  - 1/4·2/4·3/4·4/4·5/4·6/4·3/8·5/8·6/8·7/8·9/8·12/8 박자표를 독립 메트로놈과 Viewer에 공통 반영했다.
  - 박자표 목록과 연음 단위 목록 회귀 테스트를 추가했다.
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 20 tests passed
  - `flutter build apk --debug` 통과
  - Pixel Fold API 35에 APK 재설치·앱 실행 및 Flutter/FATAL 예외 없음 확인

## 2026-08-20 10:03 KST — 박별 악센트 막대 조작

- 작업자: Codex
- 목표: 악센트 셀렉트박스를 제거하고 Count-In 위에서 박별 강박/기본/뮤트를 직접 조절
- 변경 파일:
  - `lib/features/tools/domain/metronome_sequence.dart`
  - `lib/features/tools/presentation/metronome_screen.dart`
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `docs/PROJECT_STATUS.yaml`
  - `docs/WORK_LOG.md`
- 완료 내용:
  - 4박 막대를 세로로 길게 표시하고 탭할 때 강박(꽉 참) → 기본(반 참) → 뮤트(비어 있음)으로 순환한다.
  - 독립/Viewer 메트로놈에 Count-In 설명을 추가했다. Count-In은 시작 전 한 마디를 미리 들려준다.
  - BPM 입력창 배경을 투명하게 고정했다.
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 19 tests passed
  - `flutter build apk --debug` 통과
  - Pixel Fold API 35에 APK 재설치·앱 실행 및 Flutter 예외 없음 확인

## 2026-08-20 09:54 KST — 독립/Viewer 메트로놈 기능 통합

- 작업자: Codex
- 목표: 두 메트로놈의 설정과 조작을 동일하게 맞추고 BPM 입력·박별 악센트를 추가
- 관련 로드맵: M1-12 보강
- 변경 파일:
  - `lib/features/tools/domain/metronome_sequence.dart`
  - `lib/features/tools/presentation/metronome_screen.dart`
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `test/features/tools/metronome_sequence_test.dart`
  - `docs/PROJECT_STATUS.yaml`
  - `docs/WORK_LOG.md`
- 완료 내용:
  - 두 화면이 공통 `MetronomeSequence`와 공통 박자/음표 단위/악센트 레벨을 사용하도록 정리했다.
  - BPM `-`/`+` 1단위 조절과 숫자 직접 입력(40~240)을 추가했다.
  - 각 박에 기본·약·중·강을 지정하는 악센트 선택을 추가했다.
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 19 tests passed
  - `flutter build apk --debug` 통과
  - Pixel Fold API 35에 APK 재설치·앱 실행 및 Flutter 예외 없음 확인
- 남은 일:
  - 주석 영속 저장과 M2-08 Sync Anchor는 후속 범위

## 2026-08-20 09:29 KST — 메트로놈 박자·연음 기호 정리

- 작업자: Codex
- 목표: 요청한 1/4 박자와 음표 중심 단위 표시 반영
- 변경 파일:
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `lib/features/tools/domain/metronome_sequence.dart`
  - `docs/PROJECT_STATUS.yaml`
  - `docs/WORK_LOG.md`
- 완료 내용:
  - 박자 선택에 `1/4`를 추가했다.
  - 단위 선택을 `♩`, `♪`, `♬`, `♪♪♪`, `♪♪♪♪♪♪` 기호로 바꾸고 설명 텍스트를 제거했다.
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과
  - `flutter test` 19개 통과
  - `flutter build apk --debug` 통과

## 2026-08-20 09:20 KST — Viewer 터치·메트로놈·주석 정리

- 작업자: Codex
- 목표: Viewer 메뉴 터치 반응을 단순화하고 악보를 보며 쓰는 주석과 세분화된 메트로놈을 제공
- 관련 로드맵: M1-12 보강
- 변경 파일:
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `lib/features/tools/domain/metronome_sequence.dart`
  - `test/features/tools/metronome_sequence_test.dart`
  - `docs/PROJECT_STATUS.yaml`
  - `docs/ROADMAP.md`
  - `docs/WORK_LOG.md`
- 완료 내용:
  - 상단 오버레이를 최상단·상태바 배경까지 고정하고 뒤로가기 버튼을 흰색으로 표시했다.
  - 메뉴가 보일 때 PDF 중앙 탭은 메뉴를 숨기고, 가장자리 탭·가로 스와이프는 페이지 이동으로 유지했다.
  - 하단 검은 제어바의 아이콘과 슬라이더 대비를 고정했다.
  - Viewer 메트로놈에 2/4·3/4·4/4·5/4·6/8 박자, 4분음표·8분음표·16분음표·3연음·6연음과 박별 악센트 선택을 추가했다.
  - 혼란을 주는 마디 쓰기/페이지 제스처 설정을 제거하고, 세션 내 자유선 주석 쓰기·표시·지우기를 추가했다.
- 검증:
  - `dart format lib/features/score_viewer/presentation/score_viewer_screen.dart lib/features/tools/domain/metronome_sequence.dart test/features/tools/metronome_sequence_test.dart` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 19 tests passed
  - `flutter build apk --debug` 통과
  - Pixel Fold API 35 최신 APK 설치·앱 실행 및 Flutter 예외 없음 확인
- 남은 일:
  - 주석 영속 저장과 M2-08 Sync Anchor는 후속 범위

## 2026-08-20 09:07 KST — 메트로놈 팝업 수명 정리

- 작업자: Codex
- 목표: Viewer 설정 팝업에서 메트로놈 설정 팝업으로 넘어가는 비동기 수명을 명확하게 유지
- 변경 파일:
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `docs/PROJECT_STATUS.yaml`
  - `docs/WORK_LOG.md`
- 완료 내용:
  - 설정 팝업이 닫힌 뒤 Viewer 메트로놈 팝업이 완료될 때까지 await하도록 정리했다.
- 검증:
  - `dart format lib/features/score_viewer/presentation/score_viewer_screen.dart` 통과
  - `flutter analyze` 통과 — No issues found
- 남은 일:
  - M2-08 Sync Anchor와 음악 Timeline 연결

## 2026-08-20 09:06 KST — Viewer 내 메트로놈

- 작업자: Codex
- 목표: 악보를 보면서 Viewer를 벗어나지 않고 메트로놈을 실행·조절하기
- 관련 로드맵: M1-12 보강
- 변경 파일:
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `docs/PROJECT_STATUS.yaml`
  - `docs/ROADMAP.md`
  - `docs/WORK_LOG.md`
- 완료 내용:
  - 기존 독립 메트로놈의 `MetronomeSequence`와 flutter_soloud waveform click을 Viewer 상태로 재사용했다.
  - 설정 팝업에서 BPM 40~240, Count-In, 시작·정지를 조절한다.
  - 시작하면 팝업을 닫고 악보 위에 BPM과 현재 박자 상태 칩을 표시한다.
  - 기존 `/tools/metronome` 이동 동작을 제거해 악보 화면을 유지한다.
- 검증:
  - `dart format lib/features/score_viewer/presentation/score_viewer_screen.dart` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 17 tests passed
  - `flutter build apk --debug` 통과
  - Pixel Fold API 35에서 설정 팝업의 메트로놈 설정, 시작 후 악보 위 `120 · C2` 상태 칩, Flutter 예외 없는 실행을 확인
- 남은 일:
  - M2-08 Sync Anchor와 음악 Timeline 연결

## 2026-08-20 09:00 KST — Viewer 설정 이동 라우팅 안정화

- 작업자: Codex
- 목표: 설정 팝업에서 메트로놈으로 이동할 때 모달 Navigator와 Shell Navigator가 충돌하지 않게 처리
- 관련 로드맵: M1-12 보강
- 변경 파일:
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `docs/PROJECT_STATUS.yaml`
  - `docs/WORK_LOG.md`
- 완료 내용:
  - 설정 팝업을 먼저 완전히 닫은 뒤 메트로놈으로 이동하도록 순서를 분리했다.
  - StatefulShellRoute의 다른 브랜치로 이동할 때 `go('/tools/metronome')`를 사용해 중복 Navigator key 예약 오류를 제거했다.
- 검증:
  - `dart format lib/features/score_viewer/presentation/score_viewer_screen.dart` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter build apk --debug` 통과
  - Pixel Fold API 35에서 설정 팝업 → 메트로놈 화면 전환을 캡처로 확인
- 남은 일:
  - M2-08 Sync Anchor와 음악 Timeline 연결

## 2026-08-20 08:47 KST — Viewer 상·하단 제어바와 설정 팝업

- 작업자: Codex
- 목표: 악보를 가리지 않는 상단 메타데이터 바와 하단 페이지·Viewer 제어를 한 구조로 묶기
- 관련 로드맵: M1-12 보강
- 변경 파일:
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `docs/PROJECT_STATUS.yaml`
  - `docs/ROADMAP.md`
  - `docs/WORK_LOG.md`
- 완료 내용:
  - 상단 오버레이 배경을 상태바 영역까지 확장하고 제목 중심으로 축소했다.
  - 하단 제어바에 페이지 번호/슬라이더, 이전·다음, 마디 쓰기, 설정을 배치했다.
  - 설정 팝업에 음악 연결·재생, 메트로놈 진입, 마디 쓰기, 현재 마디, 다음 곡, 레이아웃(자동/맞춤/2장/스크롤), 자동 진행, 주석 표시, 페이지 제스처, 상태표시줄을 모았다.
  - 자동 레이아웃은 가로에서 2장, 세로에서 스크롤을 사용하며, 주석·제스처·시스템 바 표시를 즉시 토글한다.
- 검증:
  - `dart format lib/features/score_viewer/presentation/score_viewer_screen.dart` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 17 tests passed
  - `flutter build apk --debug` 통과
  - Pixel Fold API 35에서 하단바 접근성 노드와 설정 팝업 항목, 상단 메뉴바 호출 영역을 UI dump로 확인
- 남은 일:
  - M2-08 Sync Anchor와 음악 Timeline 연결

## 2026-08-20 08:24 KST — Viewer 페이지 제스처 정리

- 작업자: Codex
- 목표: 메뉴바가 숨겨진 상태에서도 다음·이전 페이지를 빠르게 이동할 수 있게 구성
- 관련 로드맵: M1-12 보강
- 변경 파일:
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `docs/PROJECT_STATUS.yaml`
  - `docs/ROADMAP.md`
  - `docs/WORK_LOG.md`
- 완료 내용:
  - 숨겨진 상태의 상단 72px만 메뉴바 표시 영역으로 유지했다.
  - 나머지 악보 본문 탭은 다음 페이지로 넘긴다.
  - 한 손가락 오른쪽 스와이프는 이전 페이지, 왼쪽 스와이프는 다음 페이지로 연결했다.
  - 스크롤 보기의 세로 드래그와 두 손가락 확대/이동은 유지했다.
- 검증:
  - `dart format lib/features/score_viewer/presentation/score_viewer_screen.dart` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 17 tests passed
  - `flutter build apk --debug` 통과
  - Pixel Fold API 35에서 본문 탭 `1 / 2 → 2 / 2`, 오른쪽 스와이프 `2 / 2 → 1 / 2`, 상단 터치 메뉴바 표시 확인
- 남은 일:
  - M2-08 Sync Anchor와 음악 Timeline 연결

## 2026-08-20 08:17 KST — Viewer 메뉴바 터치 반응 개선

- 작업자: Codex
- 목표: 상단 메뉴바 숨김·재표시의 지연과 끊기는 터치감 제거
- 관련 로드맵: M1-12 보강
- 변경 파일:
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `docs/PROJECT_STATUS.yaml`
  - `docs/ROADMAP.md`
  - `docs/WORK_LOG.md`
- 완료 내용:
  - Scaffold `appBar`를 제거하고 PDF 위 `Stack` 오버레이로 메뉴바를 렌더링했다.
  - 메뉴바 토글 때 PDF 레이아웃 재계산과 `_fitCurrentPage()` 호출을 제거했다.
  - `onViewerReady`가 반복 호출되어 자동 숨김 타이머가 계속 초기화되던 문제를 한 번 예약 방식으로 고쳤다.
- 검증:
  - `dart format lib/features/score_viewer/presentation/score_viewer_screen.dart` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 17 tests passed
  - `flutter build apk --debug` 통과
  - Pixel Fold API 35에서 3초 자동 숨김 후 상단 탭 즉시 재표시를 UI dump로 확인
- 남은 일:
  - M2-08 Sync Anchor와 음악 Timeline 연결

## 2026-08-19 17:47 KST — Viewer 상단 헤더 자동 숨김

- 작업자: Codex
- 목표: 파일명 헤더가 악보 영역을 덜 차지하고 필요할 때만 메뉴바를 보이게 구성
- 관련 로드맵: M1-12 보강
- 변경 파일:
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `docs/PROJECT_STATUS.yaml`
  - `docs/ROADMAP.md`
  - `docs/WORK_LOG.md`
- 완료 내용:
  - 파일명·BPM·상태를 한 줄 메타데이터로 합치고 툴바 높이를 52px로 줄였다.
  - Viewer 진입 후 3초가 지나면 메뉴바를 숨긴다.
  - 보이는 헤더의 제목을 누르면 숨기고, 숨겨진 상태에서 화면 상단을 누르면 다시 표시한다.
  - 마디 편집 중에는 헤더 자동 숨김을 중지한다.
- 검증:
  - `dart format lib/features/score_viewer/presentation/score_viewer_screen.dart` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 17 tests passed
  - `flutter build apk --debug` 통과
  - Pixel Fold API 35에서 3초 후 헤더 숨김과 상단 터치 재표시를 UI dump로 확인
- 남은 일:
  - M2-08 Sync Anchor와 음악 Timeline 연결

## 2026-08-19 17:30 KST — 2장 보기 전체 맞춤

- 작업자: Codex
- 목표: 2장 보기에서 인접한 두 페이지가 한 화면에 모두 들어오도록 배율 수정
- 관련 로드맵: M1-12 보강
- 변경 파일:
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `docs/PROJECT_STATUS.yaml`
  - `docs/ROADMAP.md`
  - `docs/WORK_LOG.md`
- 완료 내용:
  - `pdfrx` 영역 맞춤 앵커를 `center`에서 `all`로 바꿔 한 페이지가 아닌 두 페이지 전체 영역을 기준으로 배율을 계산한다.
- 검증:
  - `dart format lib test` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 17 tests passed
  - `flutter build apk --debug` 통과
  - Pixel Fold API 35에서 2장 선택 후 인접한 두 페이지가 한 화면에 모두 표시됨을 캡처로 확인
- 남은 일:
  - M2-08 Sync Anchor와 음악 Timeline 연결

## 2026-08-19 17:20 KST — PDF 보기 아이콘 정리

- 작업자: Codex
- 목표: 보기 모드별로 아이콘이 바뀌거나 추가되어 생기는 혼란 제거
- 관련 로드맵: M1-12 보강
- 변경 파일:
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `docs/PROJECT_STATUS.yaml`
  - `docs/ROADMAP.md`
  - `docs/WORK_LOG.md`
- 완료 내용:
  - 2장 보기와 역할이 겹치는 태블릿 전용 반쪽 넘김 상태·페이지 분기·버튼을 삭제했다.
  - AppBar의 보기 아이콘과 접근성 문구를 항상 `보기`로 고정했다.
  - `보기` 시트에서 `맞춤`·`2장`·`스크롤`을 고르는 흐름은 유지했다.
- 검증:
  - `dart format lib test` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 17 tests passed
  - `flutter build apk --debug` 통과
  - Pixel Fold API 35에서 `보기` 아이콘만 표시되고 `반쪽 넘김`이 없으며, 보기 시트 3개 옵션을 확인
- 남은 일:
  - M2-08 Sync Anchor와 음악 Timeline 연결

## 2026-08-19 17:12 KST — PDF 보기 모드

- 작업자: Codex
- 목표: PDF 악보가 기본적으로 화면에 들어오고 2장·스크롤 보기를 선택할 수 있게 구성
- 관련 로드맵: M1-12 보강
- 변경 파일:
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - 진행 상태 문서 3종
- 완료 내용:
  - 기본 `맞춤` 모드에서 현재 악보 한 장 전체를 화면에 맞춘다.
  - `2장` 모드는 인접 페이지를 한 행에 배치하고 좌우 탭을 두 페이지 단위로 넘긴다.
  - `스크롤` 모드는 세로 연속 레이아웃과 가로 맞춤, 세로 드래그를 사용한다.
  - 보기 시트는 `맞춤`·`2장`·`스크롤` 세 선택지만 제공하고 기존 반쪽 넘김은 맞춤 모드에서만 표시한다.
- 검증:
  - `dart format lib test` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 17 tests passed
  - `flutter build apk --debug` 통과
  - Pixel Fold API 35에서 기본 `맞춤`, 보기 시트 3개 옵션, `2장`·`스크롤` 전환과 AppBar 모드 라벨 확인
- 남은 일:
  - 스크롤 모드에서 긴 악보의 실제 연속 이동을 다양한 문서 비율로 추가 확인
  - M2-08 Sync Anchor와 음악 Timeline 연결

## 2026-08-19 16:58 KST — Viewer 음악 연결 진입점

- 작업자: Codex
- 목표: Smart Score Viewer에서 오디오가 없는 곡의 음악 연결 흐름 보강
- 관련 로드맵: M2-07
- 변경 파일:
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - 진행 상태 문서 3종
- 완료 내용:
  - 기존 M1-18 오디오 저장·DB 연결·Viewer 재생 흐름은 재사용했다.
  - 오디오가 없는 Viewer AppBar에 `오디오 연결` 액션을 추가했다.
  - 기존 곡 정보 시트를 열고, 시트 종료 후 `scoreViewerDataProvider`를 갱신해 연결된 파일을 다시 반영한다.
  - 별도 저장 모델·중복 파일 선택 UI는 만들지 않았다.
- 검증:
  - `dart format lib test` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 17 tests passed
  - `flutter build apk --debug` 통과
  - Pixel Fold API 35에서 오디오 없는 PDF Viewer의 `오디오 연결` 버튼과 기존 곡 정보 시트, 오디오 연결 곡의 `재생` 버튼 확인
- 남은 일:
  - M2-08 Sync Anchor와 음악 Timeline 연결
  - 실제 자동 currentMeasure·페이지 이동은 Timeline 이후 구현

## 2026-08-19 16:41 KST — Follow/Page Mode와 Manual Override

- 작업자: Codex
- 목표: 음악 Timeline 연결 전 Viewer의 진행 방식 선택과 수동 페이지 이동 일시정지 흐름 연결
- 관련 로드맵: M2-06
- 변경 파일:
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - 진행 상태 문서 3종
- 완료 내용:
  - 일반 Viewer AppBar에서 Follow/Page 선택 시트를 열고 현재 모드를 아이콘으로 표시한다.
  - 오디오 재생 중 악보 탭, 페이지 선택, 현재 마디 선택을 수동 override로 감지해 `AUTO PAUSED`를 표시한다.
  - `Resume Live`를 누르면 현재 Highlight Measure 페이지로 이동하고 override 상태를 해제한다.
  - 실제 음악 Timeline 기반 자동 currentMeasure·페이지 이동은 M2-08 Sync Anchor까지 만들지 않는다.
- 검증:
  - `dart format lib/features/score_viewer/presentation/score_viewer_screen.dart` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 17 tests passed
  - `flutter build apk --debug` 통과
  - Pixel Fold API 35에서 Page 버튼, Follow/Page 시트, 재생 중 악보 탭의 `AUTO PAUSED`/`Resume Live` 접근성 노출 확인
- 남은 일:
  - M2-07 음악 파일 연결
  - M2-08 Sync Anchor와 음악 Timeline 동기화 후 Follow/Page 실제 자동 이동

## 2026-08-19 16:14 KST — 현재 Measure Highlight

- 작업자: Codex
- 목표: Smart Score Viewer에서 현재 마디를 선택하고 강조 표시
- 관련 로드맵: M2-05
- 변경 파일:
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - 진행 상태 문서 3종
- 완료 내용:
  - 일반 Viewer AppBar에 `현재 마디` 액션과 마디 번호 선택 시트를 추가했다.
  - 선택한 Measure가 다른 페이지에 있으면 해당 페이지로 이동하고 파란 테두리·배경으로 강조한다.
  - Highlight 오버레이는 `IgnorePointer`로 감싸 기존 PDF 페이지 넘김 제스처를 가로채지 않는다.
  - 현재 마디는 동기화 전 단계라 DB에 저장하지 않고 Viewer 세션에서만 유지한다.
- 검증:
  - `dart format lib test` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 17 tests passed
  - `flutter build apk --debug` 통과
  - Pixel Fold API 35에서 현재 마디 버튼, 선택 시트, Highlight 오버레이와 페이지 입력 비차단 확인
- 남은 일:
  - M2-06 Follow/Page Mode와 Manual Override
  - 음악 Timeline에 따른 자동 currentMeasure 갱신은 Sync Anchor 이후 구현

## 2026-08-19 15:57 KST — Time Signature Map 편집

- 작업자: Codex
- 목표: Smart Score Measure 구간에 박자표 변경을 저장하고 표시
- 관련 로드맵: M2-04
- 변경 파일:
  - `lib/core/database/app_database.dart`, `app_database.g.dart`
  - `lib/features/smart_score/data/time_signature_map_repository.dart`
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `test/features/smart_score/measure_repository_test.dart`
  - 진행 상태 문서 3종
- 완료 내용:
  - TimeSignatureMaps 테이블과 DB v7 마이그레이션을 추가했다.
  - 시작·끝 마디, 분자 1~32, 분모 1·2·4·8·16·32를 검증하고 저장·삭제한다.
  - Viewer 편집 모드의 선택 Measure에서 박자표 시트를 열어 `4/4` 같은 라벨을 표시한다.
- 검증:
  - `dart format lib test` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 17 tests passed
  - `flutter build apk --debug` 통과
  - Pixel Fold API 35에서 DB v6→v7 마이그레이션, 박자표 시트, 4/4 저장·라벨 표시와 SQLite 영속화 확인
- 남은 일:
  - M2-05 현재 Measure Highlight
  - 박자표 기반 실제 Beat 계산과 재생 반영은 Timeline 동기화 범위에서 검토

## 2026-08-19 15:47 KST — Tempo Map STEP/GRADUAL 편집

- 작업자: Codex
- 목표: Smart Score Measure 구간에 STEP/GRADUAL BPM을 저장하고 표시
- 관련 로드맵: M2-03
- 변경 파일:
  - `lib/core/database/app_database.dart`, `app_database.g.dart`
  - `lib/features/smart_score/data/tempo_map_repository.dart`
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `test/features/smart_score/measure_repository_test.dart`
  - 진행 상태 문서 3종
- 완료 내용:
  - TempoMaps 테이블과 DB v6 마이그레이션을 추가했다.
  - STEP은 시작 BPM, GRADUAL은 시작·끝 BPM을 저장하고 40~240 범위와 모드별 필드를 검증한다.
  - Viewer 편집 모드의 선택 Measure에서 Tempo 시트를 열어 마디 범위와 BPM을 저장·삭제한다.
  - 저장된 시작 마디에 `120 BPM`, `128→110` 형식의 최소 라벨을 표시한다.
- 검증:
  - `dart format lib test` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 17 tests passed
  - `flutter build apk --debug` 통과
  - Pixel Fold API 35에서 Tempo 버튼, STEP/GRADUAL 입력 시트, STEP 저장·라벨 표시와 SQLite 영속화 확인
- 남은 일:
  - M2-04 Time Signature Map
  - 시작 마디 외 구간 Measure 라벨 표시와 BPM 재생 반영은 후속 동기화 작업에서 검토

## 2026-08-19 15:30 KST — Measure Section 편집과 표시

- 작업자: Codex
- 목표: Measure에 Section을 붙이고 Viewer에서 변경·확인
- 관련 로드맵: M2-02
- 변경 파일:
  - `lib/core/database/app_database.dart`, `app_database.g.dart`
  - `lib/features/smart_score/data/measure_repository.dart`
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `test/features/smart_score/measure_repository_test.dart`
  - 진행 상태 문서 3종
- 완료 내용:
  - Measure에 nullable Section 필드와 DB v5 마이그레이션을 추가했다.
  - 편집 모드에서 Section 버튼을 누르면 INTRO, VERSE, PRE, CHORUS, BRIDGE, OUTRO와 없음 선택지가 열린다.
  - 선택한 Section은 대문자로 저장하고 주황색 Measure 라벨로 표시한다.
  - 현재 범위는 표준 Section만 두고 사용자 정의 입력은 추가하지 않았다.
- 검증:
  - `dart format lib test` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 17 tests passed
  - `flutter build apk --debug` 통과
  - Pixel Fold API 35에서 DB v4→v5, CHORUS 선택·화면 표시·SQLite 영속화, Flutter/Drift 오류 없음 확인
- 남은 일:
  - M2-03 Tempo Map STEP/GRADUAL
  - 사용자 정의 Section은 실제 요구가 생길 때 검토

## 2026-08-19 15:22 KST — PDF Measure 영역 편집

- 작업자: Codex
- 목표: PDF 위에 Smart Score Measure 영역을 만들고 수정·저장
- 관련 로드맵: M2-01
- 변경 파일:
  - `lib/core/database/app_database.dart`, `app_database.g.dart`
  - `lib/features/smart_score/data/measure_repository.dart`
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `test/features/smart_score/measure_repository_test.dart`
  - 진행 상태 문서 3종
- 완료 내용:
  - Measure 번호, 페이지와 0~1 정규화 사각형을 저장하는 Drift 테이블과 DB v4 마이그레이션을 추가했다.
  - Viewer의 마디 편집 모드에서 드래그 생성, 선택, 이동, 우하단 핸들 크기 조정과 삭제를 구현했다.
  - 첫 Measure 생성 시 곡 유형을 `smart_score`, 마지막 Measure 삭제 시 `pdf`로 전환한다.
  - 편집 중 영역만 주황색 프레임으로 표시하고 카피는 `드래그해 추가`와 행동명만 남겼다.
  - 어두운 Viewer에서 검게 표시되던 곡 제목을 흰색으로 수정했다.
- 검증:
  - `dart format lib test` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 17 tests passed
  - `flutter build apk --debug` 통과
  - Pixel Fold API 35에서 DB v3→v4, Measure 생성·선택·이동·크기 조정·삭제와 좌표 영속화 확인
  - 최종 화면에서 제목 대비, 영역 프레임, 하단 안내의 안전 여백 확인
- 남은 일:
  - M2-02 Section 편집과 표시
  - Measure 번호 재정렬과 자동 감지는 세부 개선 또는 Future 범위에서 검토

## 2026-08-19 14:57 KST — 일반 오디오 연결과 Viewer 재생

- 작업자: Codex
- 목표: 곡에 일반 오디오 파일을 연결하고 악보를 보며 재생·일시정지
- 관련 로드맵: M1-18
- 변경 파일:
  - `lib/core/storage/song_file_storage.dart`
  - `lib/features/library/data/audio_picker.dart`, `audio_attachment_service.dart`, `pdf_picker.dart`, `pdf_import_service.dart`
  - `lib/features/library/domain/picked_local_file.dart`
  - `lib/features/library/presentation/edit_song_sheet.dart`
  - `lib/features/library/repository/song_repository.dart`
  - `lib/features/score_viewer/data/score_viewer_data.dart`
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `lib/core/database/app_database.dart`, `app_database.g.dart`
  - `test/features/library/audio_attachment_service_test.dart`와 기존 PDF 테스트
  - 진행 상태 문서 3종
- 완료 내용:
  - OS 오디오 선택기에서 고른 파일을 앱 문서 디렉터리 `audio/`로 복사하고 곡 DB에 이름과 상대 경로를 저장한다.
  - 곡 정보 시트에 여백을 유지한 `연결`/`변경` 액션을 추가하고 문구는 파일명과 행동만 남겼다.
  - PDF Viewer AppBar에 오디오가 있는 곡만 재생·일시정지 버튼을 표시한다.
  - 재생이 끝나 무효가 된 SoLoud 핸들은 다음 탭에서 새 재생으로 복구한다.
- 검증:
  - `dart format lib test` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 16 tests passed
  - `flutter build apk --debug` 통과
  - Pixel Fold API 35에서 DB v2→v3 마이그레이션, WAV 연결, 재생·일시정지, 종료 핸들 재재생과 앱/SoLoud 오류 없음 확인
- 남은 일:
  - M2-01 Measure 영역과 Smart Score 메타데이터
  - Playback Speed, Loop, Sync Anchor는 M2-08~M2-10에서 구현

## 2026-08-19 14:30 KST — 홈 악보 열기 CTA와 안전 여백 정리

- 작업자: Codex
- 목표: 홈의 이중 카피를 하나의 큰 악보 열기 액션으로 합치고 장식 요소 여백 확보
- 관련 로드맵: DS-01
- 변경 파일:
  - `lib/features/home/presentation/home_screen.dart`
  - `test/widget_test.dart`
  - `AGENTS.md`, `.cursor/rules/layout-spacing.mdc`
  - 진행 상태 문서 3종
- 완료 내용:
  - `연습 시작` 제목과 별도 버튼을 없애고 검은 카드 전체를 큰 `악보 열기` 액션으로 변경했다.
  - 리듬 마크에 16px 자체 여백을 두고 작은 화면에서는 텍스트만 축소되도록 했다.
  - 공간이 부족해도 안전 여백부터 제거하지 않는 규칙을 프로젝트에 추가했다.
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 15 tests passed, 홈 CTA Library 이동 포함
  - `flutter build apk --debug` 통과
  - Pixel Fold API 35에서 큰 CTA와 리듬 마크 여백을 스크린샷으로 확인
- 남은 일:
  - M1-18 일반 오디오 파일 연결 및 재생

## 2026-08-19 14:26 KST — 전체 제품 카피 간소화

- 작업자: Codex
- 목표: 화면과 아이콘으로 알 수 있는 설명을 없애고 사용자 노출 문구를 최소화
- 관련 로드맵: DS-01
- 변경 파일:
  - `AGENTS.md`, `.cursor/rules/product-copy.mdc`
  - `lib/features/home/presentation/home_screen.dart`
  - `lib/features/library/**`
  - `lib/features/setlists/presentation/**`
  - `lib/features/tools/presentation/**`
  - `lib/features/score_viewer/**`
  - `test/widget_test.dart`, `test/features/library/pdf_import_service_test.dart`
  - 진행 상태 문서 3종
- 완료 내용:
  - 제목과 아이콘이 반복하는 부제, 안내 문장, 즉시 반영되는 성공 메시지를 제거했다.
  - 빈 상태와 오류를 `악보 없음`, `불러오기 실패`, `저장 실패`처럼 한 줄로 줄였다.
  - 폼 라벨과 검증 문구를 줄이고 Tap Tempo의 `½`, `2×`에는 별도 접근성 라벨을 유지했다.
  - 최소 카피 원칙을 항상 적용되는 프로젝트 규칙과 AGENTS.md에 기록했다.
- 검증:
  - `dart format lib test` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 15 tests passed
  - `flutter build apk --debug` 통과
  - Pixel Fold API 35 접힌 세로 화면에서 홈 축약 카피와 레이아웃 확인
- 남은 일:
  - 새 화면도 동일한 최소 카피 원칙을 적용한다.
  - M1-18 일반 오디오 파일 연결 및 재생

## 2026-08-19 14:19 KST — PDF 가져오기와 Viewer 오류 분기 보강

- 작업자: Codex
- 목표: 0바이트 PDF 저장을 막고 손상된 악보를 열 때 복구 행동을 안내
- 관련 로드맵: M1-05, M1-09
- 변경 파일:
  - `lib/core/storage/score_file_storage.dart`
  - `lib/features/library/presentation/import_score_sheet.dart`
  - `lib/features/score_viewer/data/score_viewer_data.dart`
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `test/features/library/pdf_import_service_test.dart`
  - 진행 상태 문서 3종
- 완료 내용:
  - 복사된 파일의 첫 1KB에서 PDF 헤더를 확인하고, 빈 파일이나 PDF가 아닌 파일은 DB 저장 전에 삭제한다.
  - 가져오기 검증 오류는 `올바른 PDF 파일이 아닙니다. 다른 파일을 선택해 주세요.`로 안내한다.
  - 기존 0바이트 파일과 pdfrx 렌더링 오류를 사용자용 문구로 분기하고 내부 스택 트레이스와 잘못된 로딩 표시를 숨긴다.
- 검증:
  - `dart format` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 15 tests passed
  - `flutter build apk --debug` 통과
  - Pixel Fold API 35에서 기존 0바이트 악보를 열어 `PDF 파일이 비어 있습니다. 다시 가져와 주세요.` 문구 확인
- 남은 일:
  - 손상된 기존 Library 항목은 사용자가 정상 PDF로 다시 가져와야 한다.
  - M1-18 일반 오디오 파일 연결 및 재생

## 2026-08-19 14:07 KST — 메트로놈과 4박 Count-In 구현

- 작업자: Codex
- 목표: BPM을 지정하고 Count-In 뒤 클릭에 맞춰 연습
- 관련 로드맵: M1-17
- 변경 파일:
  - `lib/features/tools/domain/metronome_sequence.dart`
  - `lib/features/tools/presentation/metronome_screen.dart`, `tools_screen.dart`
  - `lib/features/home/presentation/home_screen.dart`
  - `lib/app/router/app_router.dart`
  - `test/features/tools/metronome_sequence_test.dart`
  - 진행 상태 문서 3종
- 완료 내용:
  - 40~240 BPM 슬라이더, 4박 Count-In, 첫 박 강조, 현재 박 표시와 시작/정지를 구현했다.
  - flutter_soloud의 Fourier square waveform 한 개를 무음 loop로 유지하고 박자마다 35ms만 볼륨을 올려 클릭음을 만든다.
  - 홈과 도구 목록에서 메트로놈 화면으로 바로 진입한다.
  - flutter_soloud 4.x 예약 재생 전환 지점을 `ponytail:` 주석으로 남겼다.
- 검증:
  - `dart format lib test` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 14 tests passed
  - `flutter build apk --debug` 통과
  - Pixel Fold API 35 콜드 부팅 후 4박 Count-In, 연속 박자 표시 `3 / 4`, 정지와 오디오 오류 없음 확인
- 남은 일:
  - M1-18 일반 오디오 파일 연결 및 재생
  - SDK 업그레이드 후 `playScheduled` 기반 정밀 clock 검토

## 2026-08-19 13:44 KST — flutter_soloud 오디오 기반 구성

- 작업자: Codex
- 목표: 메트로놈, Count-In, 일반 오디오가 공유할 네이티브 오디오 엔진 준비
- 관련 로드맵: M1-16
- 변경 파일:
  - `pubspec.yaml`, `pubspec.lock`
  - `lib/core/audio/audio_engine_provider.dart`
  - `lib/app/app.dart`
  - `test/widget_test.dart`
  - 진행 상태 문서 3종
- 완료 내용:
  - 현재 Dart 3.9.2와 호환되는 `flutter_soloud 3.5.4`를 고정했다.
  - Riverpod `FutureProvider`에서 `SoLoud.instance` 초기화와 종료를 관리한다.
  - 위젯 테스트는 네이티브 FFI를 호출하지 않도록 오디오 provider를 격리했다.
- 검증:
  - `dart format lib test` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 13 tests passed
  - `flutter build apk --debug`에서 flutter_soloud C++ 라이브러리 포함 빌드 통과
  - Pixel Fold API 35에 재설치 후 앱 시작 및 Flutter/SoLoud 오류 로그 없음
- 남은 일:
  - M1-17 메트로놈과 Count-In
  - Flutter/Dart 업그레이드 시 flutter_soloud 4.x 전환 검토

## 2026-08-19 13:26 KST — 독립 Tap Tempo 구현

- 작업자: Codex
- 목표: 악보를 열지 않고 BPM을 측정하고 반값/두 배로 확인
- 관련 로드맵: M1-15
- 변경 파일:
  - `lib/features/tools/domain/tap_tempo.dart`
  - `lib/features/tools/presentation/tap_tempo_screen.dart`, `tools_screen.dart`
  - `lib/features/home/presentation/home_screen.dart`
  - `lib/app/router/app_router.dart`
  - `test/features/tools/tap_tempo_test.dart`, `test/widget_test.dart`
  - 진행 상태 문서 3종
- 완료 내용:
  - 최근 최대 6개 탭 간격 평균으로 BPM을 안정화하고 2초 넘게 쉬면 새 측정을 시작한다.
  - 큰 TAP 버튼, 반값, 두 배, 초기화 동작을 한 화면에 구현했다.
  - 홈 빠른 실행과 도구 목록에서 Tap Tempo 전용 화면으로 바로 진입한다.
  - 측정값은 기획대로 악보 BPM이나 Tempo Map에 자동 저장하지 않는다.
- 검증:
  - `dart format lib test` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 13 tests passed
  - `flutter build apk --debug` 통과
  - Pixel Fold API 35에서 홈 진입, BPM 측정, 반값 96→48과 태블릿 레이아웃 확인
- 남은 일:
  - M1-16 `flutter_soloud` 오디오 기반 구성
  - M1-17 메트로놈과 Count-In

## 2026-08-19 13:07 KST — DESIGN.md 토큰을 Flutter 테마에 적용

- 작업자: Codex
- 목표: 검증된 디자인 토큰을 일반 앱 화면에 적용하고 어두운 악보 Viewer 유지
- 관련 로드맵: DS-01
- 변경 파일:
  - `assets/fonts/**`, `pubspec.yaml`
  - `lib/app/app.dart`, `lib/app/theme/app_theme.dart`, `lib/app/widgets/app_shell.dart`
  - `lib/features/home/presentation/home_screen.dart`
  - `lib/features/library/presentation/library_screen.dart`
  - `lib/features/setlists/presentation/setlists_screen.dart`, `setlist_detail_screen.dart`
  - `lib/features/tools/presentation/tools_screen.dart`
  - `test/widget_test.dart`
  - 진행 상태 문서 3종
- 완료 내용:
  - 흰 캔버스, 검정 구조색, `#ff4800` 포인트, `#dddddd` 테두리와 평면 컴포넌트 테마를 적용했다.
  - Pretendard 400/500/600/700 OTF와 OFL 라이선스를 앱 자산으로 포함했다.
  - 일반 화면의 간격을 8/16/24/28px, 카드와 주요 컨테이너 라운드를 4px 중심으로 정리했다.
  - 검증되지 않은 시스템 다크 테마는 제거하고 악보 Viewer의 기존 어두운 연주 화면은 유지했다.
- 검증:
  - `dart format lib test` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 12 tests passed
  - `flutter build apk --debug` 통과
  - ADB 연결 기기가 없어 이번 테마의 실제 화면 스모크 테스트는 미실행
- 남은 일:
  - M1-15 독립 Tap Tempo
  - Android 기기 연결 후 테마와 Viewer 시각 확인

## 2026-08-19 11:18 KST — DESIGN.md를 시각 기준으로 등록

- 작업자: GPT-5.6 Sol
- 목표: 새로 추가된 DESIGN.md를 AI 작업 규칙과 다음 작업에 반영
- 관련 로드맵: DS-01
- 변경 파일:
  - `AGENTS.md`
  - `.cursor/rules/project-workflow.mdc`
  - `docs/PROJECT_STATUS.yaml`, `docs/ROADMAP.md`, `docs/WORK_LOG.md`
- 완료 내용:
  - UI 작업 전 `DESIGN.md` 토큰을 확인하도록 공통 규칙을 추가했다.
  - 웹 쇼핑몰 레이아웃/로고는 복사하지 않고 악보 앱 테마로만 옮기기로 결정했다.
  - 다음 구현 순서를 DS-01 테마 적용 → M1-15 Tap Tempo로 바꿨다.
- 검증:
  - 로드맵 집계 25/97 확인
- 남은 일:
  - DS-01 Flutter 테마 적용
  - M1-15 Tap Tempo

## 2026-08-19 11:10 KST — 세트리스트 저장소와 순차 열기

- 작업자: GPT-5.6 Sol
- 목표: 세트리스트를 만들고 곡 순서를 연 뒤 다음 곡으로 바로 이동
- 관련 로드맵: M1-13, M1-14
- 변경 파일:
  - `lib/core/database/app_database.dart`, `lib/core/database/app_database.g.dart`
  - `lib/features/setlists/**`
  - `lib/app/router/app_router.dart`
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `test/features/setlists/setlist_repository_test.dart`
  - `test/widget_test.dart`
  - 진행 상태 문서 3종
- 완료 내용:
  - Setlists/SetlistEntries 테이블과 스키마 버전 2 마이그레이션을 추가했다.
  - 생성, 이름 변경, 곡 추가/제거, 순서 변경, 삭제를 저장소와 화면으로 연결했다.
  - 세트리스트에서 연 악보는 Viewer의 `다음 곡`으로 바로 이어서 열 수 있다.
- 검증:
  - `dart format .` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 11 tests passed
- 남은 일:
  - M1-15 Tap Tempo
  - 실제 기기에서 세트리스트 순차 열기 확인

## 2026-08-19 10:59 KST — 제품 카피 원칙과 Viewer 탐색 완성

- 작업자: GPT-5.6 Sol
- 목표: 사용자 문구를 간결하게 통일하고 Viewer의 페이지 탐색과 Half Page Turn 완성
- 관련 로드맵: M1-12
- 변경 파일:
  - `AGENTS.md`, `.cursor/rules/product-copy.mdc`
  - `lib/features/home/presentation/home_screen.dart`
  - `lib/features/library/presentation/**`
  - `lib/features/setlists/presentation/setlists_screen.dart`
  - `lib/features/tools/presentation/tools_screen.dart`
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - `test/widget_test.dart`
  - 진행 상태 문서 3종
- 완료 내용:
  - 모든 AI가 사용자 문구를 짧고 명확하게 쓰도록 공통 규칙을 추가했다.
  - 기능 나열, 홍보성 수식어, 불필요한 영어, 기술 오류 노출을 제거했다.
  - 페이지 선택 화면에 실제 PDF 썸네일과 현재 페이지 표시를 추가했다.
  - 태블릿에서 선택할 수 있는 Half Page Turn을 구현했다.
- 검증:
  - `dart format .` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 7 tests passed
  - `flutter build apk --debug` 통과
- 남은 일:
  - M1-13 Setlist 데이터 모델과 저장소
  - 실제 기기에서 두 손가락 조작과 Half Page Turn 감각 검증
  - 일부 Android SDK 라이선스 승인

## 2026-08-19 10:48 KST — 연주용 Viewer 제스처와 Android UX 검증

- 작업자: GPT-5.6 Sol
- 목표: 연주 중 오조작을 줄이는 손가락별 Viewer 조작과 빠른 페이지 이동 구현
- 관련 로드맵: M1-10, M1-11, M1-12 일부
- 변경 파일:
  - `lib/features/score_viewer/presentation/score_viewer_screen.dart`
  - 진행 상태 문서 3종
- 완료 내용:
  - 한 손가락 Drag를 차단하고 좌측 25%/우측 75% Tap으로 이전/다음 페이지를 즉시 이동하도록 했다.
  - 두 손가락 Pinch/Pan을 원시 Pointer 기반으로 분리하고 두 손가락 Double Tap 화면 맞춤을 구현했다.
  - 하단 페이지 표시를 누르면 번호 그리드에서 원하는 페이지로 바로 이동할 수 있게 했다.
  - Pixel Fold 에뮬레이터에 2페이지 PDF를 넣어 OS File Picker부터 Library 등록과 Viewer 열기까지 실제 흐름을 확인했다.
- 검증:
  - `dart format .` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 7 tests passed
  - `flutter build apk --debug` 통과 후 Pixel Fold API 35 설치 성공
  - Android에서 1/2→2/2 오른쪽 Tap 이동과 한 손가락 Drag 후 2/2 페이지 유지를 확인했다.
  - Android 오류 로그 없음
- 남은 일:
  - M1-12 방향 전환 검증, 썸네일 탐색, Half Page Turn
  - 실제 멀티터치 기기에서 두 손가락 Pinch/Pan/Double Tap 감각 검증
  - 일부 Android SDK 라이선스 승인

## 2026-08-19 10:31 KST — pdfrx Viewer와 Android 빌드 검증

- 작업자: GPT-5.6 Sol
- 목표: Library의 오프라인 PDF를 실제 Viewer로 열고 Android 네이티브 빌드 검증
- 관련 로드맵: M1-09
- 변경 파일:
  - `pubspec.yaml`, `pubspec.lock`
  - `lib/app/router/app_router.dart`
  - `lib/features/library/**`
  - `lib/features/score_viewer/**`
  - `test/features/library/song_repository_test.dart`
  - 진행 상태 문서 3종
- 완료 내용:
  - pdfrx 2.2.24를 추가하고 전체 화면 PDF Viewer를 구현했다.
  - Library 악보 선택, 파일 존재 검증, Viewer 이동, 최근 열람 시각 기록을 연결했다.
  - 현재/전체 페이지 표시, 좌 25%·우 75% 탭 이동, 화면 맞춤 동작을 추가했다.
  - Flutter가 Android Studio JDK 25 대신 시스템 JDK 17을 사용하도록 설정했다.
  - 필요한 NDK, Android Platform 36, CMake를 설치하고 Android debug APK를 생성했다.
- 검증:
  - `dart format .` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 7 tests passed
  - `flutter build apk --debug` 통과
  - 결과: `build/app/outputs/flutter-apk/app-debug.apk`
- 남은 일:
  - M1-10 한 손가락 Drag 차단과 페이지 이동 Gesture Layer 완성
  - M1-11 두 손가락 Zoom/Pan 분리
  - M1-12 썸네일, Half Page Turn
  - 일부 Android SDK 라이선스 승인

## 2026-08-19 09:59 KST — v4 전환과 PDF 가져오기 완성

- 작업자: GPT-5.6 Sol
- 목표: v4 Jam Session 기획을 개발 계획에 반영하고 MVP 1의 PDF 등록 흐름 구현
- 관련 로드맵: M1-04~M1-08, M2~M8/Future 재구성
- 변경 파일:
  - `드럼 악보 앱 기획서 v4.md`
  - `AGENTS.md`, `.cursor/rules/project-workflow.mdc`
  - `docs/ARCHITECTURE.md`
  - `docs/PROJECT_STATUS.yaml`, `docs/ROADMAP.md`, `docs/WORK_LOG.md`
  - `pubspec.yaml`, `pubspec.lock`
  - `lib/core/storage/**`, `lib/features/library/**`
  - `test/features/library/**`
- 완료 내용:
  - v4 문서 제목을 수정하고 모든 AI의 기준 기획서를 v4로 전환했다.
  - Jam Session v1/v2를 MVP 6/7, Native Digital Score를 MVP 8로 반영해 96개 로드맵을 구성했다.
  - OS File Picker PDF 선택과 앱 문서 디렉터리 오프라인 복사를 구현했다.
  - PDF 등록 시 곡명/아티스트/BPM 입력, Library 메타데이터/메모 수정, 즐겨찾기를 구현했다.
  - 파일 저장 실패와 DB 저장 실패 시 불완전 파일이 남지 않도록 처리했다.
- 검증:
  - `dart format .` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 6 tests passed
  - 로드맵 집계 19/96과 프로젝트 상태 YAML 문법을 확인했다.
- 남은 일:
  - M1-09 `pdfrx` PDF Viewer
  - M1-10~M1-12 연주용 페이지 이동, Zoom/Pan, Half Page Turn
  - Android/iOS 네이티브 환경에서 실제 File Picker 수동 검증

## 2026-08-19 09:46 KST — v3 기준 전환과 합주 시스템 계획 추가

- 작업자: GPT-5.6 Sol
- 목표: 최신 기획서를 기준으로 전환하고 합주 시스템을 향후 계획에 반영
- 관련 로드맵: F-12~F-18
- 변경 파일:
  - `AGENTS.md`
  - `.cursor/rules/project-workflow.mdc`
  - `docs/PROJECT_STATUS.yaml`
  - `docs/ROADMAP.md`
  - `docs/WORK_LOG.md`
- 완료 내용:
  - 모든 AI의 기준 기획서를 v3로 변경했다.
  - 밴드/팀, 악보·세트리스트 공유, 합주 세션, 리더 동기화, 공용 Cue/BPM, 피드백, 재연결/보안을 Future 합주 시스템으로 추가했다.
  - 전체 체크리스트를 94개 항목으로 갱신했다.
- 검증:
  - SHA-256과 `diff --brief`로 현재 v2와 v3 파일이 완전히 동일함을 확인했다.
  - 로드맵 집계가 14/94인지 확인했다.
- 남은 일:
  - 실제 v3 추가 내용이 별도로 있다면 현재 v3 파일에 반영 필요
  - 합주 시스템은 MVP 1~7 이후 Future 단계에서 상세 설계

## 2026-08-19 09:45 KST — Library 검색과 Drift 저장소 구현

- 작업자: GPT-5.6 Sol
- 목표: 실제 악보 데이터를 받을 수 있도록 Library와 로컬 데이터 기반 구성
- 관련 로드맵: M1-02, M1-03
- 변경 파일:
  - `pubspec.yaml`, `pubspec.lock`
  - `lib/core/database/**`
  - `lib/features/library/**`
  - `test/features/library/song_repository_test.dart`
  - `test/widget_test.dart`
  - 진행 상태 문서 3종
- 완료 내용:
  - 곡, 아티스트, BPM, 악보 유형, 원본 경로, 오프라인 상태, 즐겨찾기, 메모, 최근 열람 시각을 저장하는 Drift 스키마를 구현했다.
  - 검색어와 전체/PDF/전자악보/즐겨찾기/최근 필터가 반영되는 반응형 Library 목록을 구현했다.
  - 곡 저장과 즐겨찾기 변경이 가능한 저장소와 Riverpod 상태 연결을 구현했다.
  - 현재 Dart SDK와 호환되는 Drift 2.29 계열로 의존성을 고정했다.
- 검증:
  - `dart format .` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 3 tests passed
  - 곡 저장/검색과 즐겨찾기 필터 단위 테스트를 추가했다.
- 남은 일:
  - M1-04 OS File Picker PDF 선택
  - M1-05 앱 문서 디렉터리 오프라인 복사
  - M1-06 곡 메타데이터 등록/수정 UI

## 2026-08-19 09:27 KST — Flutter 기반 설계와 앱 셸 구현

- 작업자: GPT-5.6 Sol
- 목표: P0 기반 설계를 끝내고 MVP 1의 주요 화면 내비게이션을 실행 가능한 상태로 구성
- 관련 로드맵: P0-05~P0-11, M1-01
- 변경 파일:
  - Flutter 생성 파일과 iOS/Android 프로젝트 설정
  - `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`
  - `lib/main.dart`, `lib/app/**`, `lib/features/**`
  - `test/widget_test.dart`
  - `docs/ARCHITECTURE.md`
  - `.github/workflows/flutter_ci.yml`
  - `README.md`
  - 진행 상태 문서 3종
- 완료 내용:
  - 앱 이름을 Page-a-Diddle로 확정하고 `com.hansookim.pageadiddle` 식별자를 적용했다.
  - iOS 15와 Android API 26 최소 지원 버전을 적용했다.
  - Flutter iOS/Android 프로젝트를 초기화했다.
  - 기능 중심 구조, Riverpod, go_router, Drift/SQLite 저장 전략을 확정했다.
  - 모바일 NavigationBar와 태블릿 NavigationRail 기반 반응형 앱 셸을 구현했다.
  - Home, Library, Setlist, Tools 초기 화면과 Page-a-Diddle 테마를 구현했다.
  - 엄격한 analyzer 설정과 GitHub Actions 품질 검사를 구성했다.
- 검증:
  - `dart format .` 통과
  - `flutter analyze` 통과 — No issues found
  - `flutter test` 통과 — 1 test passed
  - `flutter doctor -v`로 로컬 플랫폼 환경 장애물을 확인했다.
- 남은 일:
  - M1-02 Library 목록/검색/분류
  - M1-03 Drift 곡/악보 모델과 저장소
  - Android 빌드용 JDK 17~23, cmdline-tools, 라이선스 설정
  - iOS 빌드용 전체 Xcode와 CocoaPods 설치

## 2026-08-19 09:09 KST — 협업 및 진행 추적 체계 설정

- 작업자: GPT-5.6 Sol
- 목표: 여러 AI가 이전 진행 상황과 다음 작업을 일관되게 파악하도록 공통 규칙과 상태 문서를 구성
- 관련 로드맵: P0-01, P0-02, P0-03, P0-04
- 변경 파일:
  - `AGENTS.md`
  - `.cursor/rules/project-workflow.mdc`
  - `CLAUDE.md`
  - `GEMINI.md`
  - `.github/copilot-instructions.md`
  - `docs/PROJECT_STATUS.yaml`
  - `docs/ROADMAP.md`
  - `docs/WORK_LOG.md`
- 완료 내용:
  - 기획서 v2의 전체 기능과 MVP 개발 순서를 검토했다.
  - 모든 AI가 따라야 할 작업 전 확인 및 작업 후 기록 규칙을 만들었다.
  - Cursor, Claude, Gemini, Copilot이 공통 규칙을 찾도록 도구별 진입 파일을 연결했다.
  - 현재 상태를 기계 판독 가능한 YAML로 기록했다.
  - 기반 설계부터 Future까지 87개 체크 항목으로 세분화했다.
  - 작업 이력을 누적할 append-only 로그를 만들었다.
- 검증:
  - 각 로드맵 단계의 항목 수와 진행률 요약을 대조했다.
  - 상태 문서의 완료 항목, 다음 작업, 장애물이 현재 폴더 상태와 일치함을 확인했다.
  - Ruby YAML 파서로 `PROJECT_STATUS.yaml` 문법이 유효함을 확인했다.
  - 스크립트로 로드맵이 실제 `4/87` 완료 상태임을 확인했다.
- 남은 일:
  - P0-05 앱 식별자와 최소 지원 OS 확정
  - P0-06 Flutter 프로젝트 초기화
