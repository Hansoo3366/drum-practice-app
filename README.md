# Page-a-Diddle

드러머가 PDF 악보를 보관하고 연습과 공연에 사용하는 Flutter 기반 전자악보 앱입니다.

## 개발 환경

- Flutter 3.35.7 이상
- Dart 3.9.2 이상
- Android 8.0 / API 26 이상
- iOS 배포 없음
- Android 빌드용 JDK 17 이상, 24 미만

## 시작하기

```shell
flutter pub get
flutter run --flavor drum -t lib/main.dart

# Piano Score
flutter run --flavor piano -t lib/piano_main.dart
```

Android 제품 셸은 두 flavor로 분리합니다.

- `drum` / `com.hansookim.pageadiddle`: PDF 뷰어, 메트로놈 및 드럼 연습 기능
- `piano` / `com.hansookim.pianoscore`: PDF 뷰어, MusicXML 라이브러리, PDF·사진 → 전자악보 변환, Verovio 조판·교정

피아노 셸에는 탭 템포, 템포 트레이너, 세트리스트, 합주 라우트를 넣지 않습니다.

## 품질 검사

```shell
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

구현 전후 작업 절차는 `AGENTS.md`, 현재 진행 상태는 `docs/PROJECT_STATUS.yaml`, 전체 순서는 `docs/ROADMAP.md`를 확인합니다.
