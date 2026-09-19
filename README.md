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
flutter run
```

## 품질 검사

```shell
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

구현 전후 작업 절차는 `AGENTS.md`, 현재 진행 상태는 `docs/PROJECT_STATUS.yaml`, 전체 순서는 `docs/ROADMAP.md`를 확인합니다.
