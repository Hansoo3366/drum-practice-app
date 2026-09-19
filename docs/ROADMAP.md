# 개발 로드맵

기준 기획서: `드럼 악보 앱 기획서 v4.md`

상태 표기: `[x]` 완료 · `[~]` 진행 중 · `[ ]` 미착수 · `[-]` 보류

## 진행률 요약

| 단계 | 완료/전체 | 진행률 | 상태 |
|---|---:|---:|---|
| P0 기반 설계 | 11/11 | 100% | 완료 |
| MVP 1 악보 앱 | 18/18 | 100% | 완료 |
| MVP 2 PDF Smart Score | 11/11 | 100% | 완료 |
| MVP 3 Practice | 6/6 | 100% | 완료 |
| MVP 4 External Storage | 2/7 | 29% | 설정 대기 |
| MVP 5 Stage | 5/5 | 100% | 완료 |
| MVP 6 Jam Session v1 | 10/10 | 100% | 완료 |
| MVP 7 Jam Session v2 | 7/7 | 100% | 완료 |
| MVP 8 로컬 피아노 전자악보 | 9/9 | 100% | 완료, Android smoke 대기 |
| Future | 0/16 | 0% | 서버 기능 후순위 |
| 디자인 토큰 적용 | 1/1 | 100% | 완료 |
| **전체** | **80/101** | **79%** | 진행 중 |

> 2026-09-20 00:45 너비 맞춤·핀치 줌·줄 앞 구간 표기가 들어간 debug arm64 APK(239MB, SHA-256 `92ee122effabf2e1fbde32c51ecf2bfed97bca6dd334542c0b52aee91a1647c6`)를 SM-S937N(R5CY43JMZ7N)에 넣고 MainActivity PID 14015를 확인했다.
> 2026-09-20 00:44 구간 이름은 붙인 줄 앞에만 네모로 두고, 높은음자리표에 빨간 한글로 반복하지 않는다.
> 2026-09-20 00:42 전자악보를 화면 너비에 맞춰 줄이고, 배경을 흰색으로 두며, 핀치로 확대·이동한다.
> 2026-09-20 00:36 조옮김·A4 조판이 들어간 debug arm64 APK(239MB, SHA-256 `cdfe10fe8130faba89664266b28387804f03c6979c62dc263444b18f775c095d`)를 SM-S937N(R5CY43JMZ7N)에 넣고 MainActivity PID 9209를 확인했다.
> 2026-09-20 00:34 화면 용어를 이조에서 조옮김으로 바꿨다.
> 2026-09-20 00:32 4마디 고정을 빼고 A4 폭으로 조판한 뒤 폰에 맞춘다. 구간은 렌더된 한 줄에 붙인다. 전체 273개 테스트가 통과했다.
> 2026-09-20 00:28 한 줄을 4마디로 고정하고, 구간은 그 줄에 붙이며, 연주 순서에서 탭을 Flutter가 받아 줄 전체에 주황 박스를 그린다. 전체 273개 테스트가 통과했다.
> 2026-09-20 00:23 마디 전체 주황 박스가 들어간 debug arm64 APK(239MB, SHA-256 `4c6237574c05f6b5c776e655adf50c9c071e2d2296e026933ea1fd0854befcdd`)를 SM-S937N(R5CY43JMZ7N)에 넣고 MainActivity PID 30126을 확인했다.
> 2026-09-20 00:22 오선을 누르면 그 마디 전체를 주황 박스가 바로 감싸게 고쳤다. 박스는 높은·낮은음자리표를 한 칸으로 묶는다.
> 2026-09-20 00:20 구간 이름(벌스·코러스)을 오선 위에 올리고, 연주 순서와 쓰기에서 `다음 마디 추가`를 다시 넣었다. 전체 271개 테스트가 통과했다.
> 2026-09-20 00:12 마디별 조 표시가 들어간 debug arm64 APK(239MB, SHA-256 `1174219853a7f5c9423ab8dd60dbe1ca29ade75838fe2297353e7a389e4ba946`)를 SM-S937N(R5CY43JMZ7N)에 넣고 MainActivity PID 26411을 확인했다.
> 2026-09-20 00:50 각 마디 위에 현재 조 이름(C, G, B♭)을 악보에 올린다. 저장된 MusicXML은 바꾸지 않는다. 전체 271개 테스트가 통과했다.
> 2026-09-20 00:35 연주 순서 옵션 색칠을 빼고, 오선을 누르면 그 마디가 악보에서 활성화되게 고쳤다. 전체 270개 테스트가 통과했다.
> 2026-09-20 00:30 원곡 조·선택 마디 강조가 들어간 debug arm64 APK(239MB, SHA-256 `c03b0e161bc1d7fbefcb5d0202827649c0d8a48491d97b5cdf040964d34c5428`)를 SM-S937N(R5CY43JMZ7N)에 넣고 MainActivity PID 22424를 확인했다.
> 2026-09-20 00:25 이조 시트에 원곡 조를 고정하고, 연주 순서는 고른 마디 번호와 그 구간 행을 주황으로 구분한다. 악보 위 선택 마디에도 번호를 붙인다. 전체 271개 테스트가 통과했다.
> 2026-09-20 00:15 YDP 그랜드 피아노가 들어간 debug arm64 APK(239MB, SHA-256 `fa101a472f46dbe7fb5501993f33abcc615a6dd2ecf2a9ad19bedd9f4b2c0bb5`)를 SM-S937N(R5CY43JMZ7N)에 넣고 MainActivity PID 18564를 확인했다. 음색 청취는 B-017이다.
> 2026-09-20 00:10 재생 음색을 휴대전화용 SONiVOX 합성음에서 FreePats YDP 그랜드 피아노 샘플로 바꿨다. 전체 267개 테스트가 통과했다.
> 2026-09-19 23:59 연주 순서는 선택한 마디의 역할(벌스·코러스)과 그 역할 반복 횟수만 남긴다. 마디 번호·추가·순서·조표·박자는 뺀다. 이조는 앱바 단독 버튼이고 반주 메뉴는 숨긴다. 악보를 나가면 재생을 멈춘다. 전체 267개 테스트가 통과했다.
> 2026-09-19 23:55 재생 버튼만 되고 소리는 안 나던 문제를, alphaTab 자산·SoundFont·워커를 127.0.0.1 로컬 서버로 받게 바꿔 고친다. 탐색은 엔진이 받은 위치로 유지한다. 전체 266개 테스트가 통과했다.
> 2026-09-19 23:50 재생이 0초에 멈추던 원인을 WebView 워커가 alphaTab 스크립트를 다시 받지 못하는 문제로 보고, 합성 워커를 인라인 소스로 만들며 길이는 악보 템포·박자로 먼저 채운다. 전체 264개 테스트가 통과했다. 폰 재설치 후 청취는 B-017이다.
> 2026-09-19 23:45 마디 개수·순서·조표·박자·구간은 연주 순서 패널로 모았다. 쓰기 팔레트는 음가·쉼표·임시표만 남긴다. 바꿀 마디는 번호 칩과 악보 주황 강조로 보여 준다. 전체 263개 테스트가 통과했다.
> 2026-09-19 23:25 재생 길이가 0초로 고정되던 문제를 고쳤다. SoundFont 준비 직후가 아니라 악보 MIDI가 생긴 뒤 길이를 다시 읽고, 0초 갱신으로 이미 아는 길이를 덮지 않는다. 전체 263개 테스트가 통과했다.
> 2026-09-19 23:20 벌스·코러스 구간은 쓰기 팔레트에서 마디에 붙이고, 반복 횟수·순서는 연주 순서 버튼에서만 바꾼다. 재생은 기본 꺼짐이며 켜야 재생 막대·커서가 나오고 펼친 악보를 보여 준다. 이조·코드·마디는 쓰기 도구, 반주는 연주 도구로 나눴다. 전체 262개 테스트가 통과했고 release APK(SHA-256 `92290649ef20a4183fb6315b88bb9350827d5f2335fa6e333418f5ed96bbfc10`)를 SM-S937N에 넣었다.
> 2026-09-19 23:10 전자악보를 재생/쓰기/도구로 나눴다. 재생 막대는 재생·정지·탐색만 두고, 쓰기는 음가 칩과 오선 터치·드래그, 이조·연주 순서·반주·코드·마디는 도구 메뉴로 옮겼다. Android WebView는 AudioWorklet 대신 ScriptProcessor로 합성한다. 전체 261개 테스트가 통과했고 release APK(SHA-256 `77473528902a136855669f075ffdbaf7f4877a9e9b36ba8533d3c854a03f77d5`)를 SM-S937N에 넣었다.
> 2026-09-19 22:53 오선 입력·재생 잠금·출처 선택·완료 여백이 들어간 release arm64 APK(SHA-256 `6fa2daaf6a18c0c480e1dddc5136fd34bcb6dafb253636fc510285879b532571`)를 SM-S937N(R5CY43JMZ7N)에 `adb install -r`로 넣고 MainActivity PID 26424를 확인했다. 가져오기·재생·내보내기·재열기 smoke는 B-017이다.
> 2026-09-20 00:30 MusicXML/MXL 가져오기도 PDF와 같이 기기·Google Drive·Dropbox·WebDAV를 고른다. 드라이브/드롭박스/WebDAV 목록은 `.musicxml`·`.mxl`·`.xml`만 보여 준다.
> 2026-09-20 00:10 전자악보 실사용 4건을 고쳤다. 편집은 음가·쉼표·임시표를 고른 뒤 오선을 눌러 바로 넣고 드래그로 높이를 바꾸며, 재생은 WebView 오디오 잠금과 SoundFont 준비 전에 누른 재생을 이어 받는다. 연주 순서·반주는 구간/코드가 없을 때 다음 행동만 보여주고, 완료 버튼은 시스템 조작키 위에 뜬다. 전체 259개 테스트가 통과했다. 폰 재설치 smoke는 B-017이다.
> 2026-09-19 23:55 Library에서 빈 피아노 Grand Staff를 직접 만들 수 있다. 곡명만 있으면 한 마디 쉼표 악보를 저장하고 편집 화면으로 연다. 전체 254개 테스트가 통과했다.
> 2026-09-19 23:45 OpenLyrics 가사 XML(`<song>`)을 악보로 열지 않고 `가사 파일입니다`로 안내하도록 고쳤다. 갓피플 새찬송가 XML은 음표가 없다.
> 2026-09-19 23:35 Windows에서 pdfium 심볼릭 링크 대신 junction/복사를 쓰도록 고친 뒤 release arm64 APK를 SM-S937N(R5CY43JMZ7N)에 설치하고 MainActivity를 실행했다. 서명 불일치로 기존 앱은 지운 뒤 다시 넣었다. MVP 8 실기기 smoke는 아직이다.
> 2026-09-19 23:15 Google Drive·Dropbox 클라이언트 ID를 제품 기본값으로 고정했다. 빈 `--dart-define`이 있어도 OAuth를 끄지 않고, `dart_defines.json`을 IDE 실행과 CI 테스트에 넣는다. 전체 251개 테스트가 통과했다.
> 2026-09-19 22:50 내려받기에 구형 `.xml`을 추가했다. 내용은 `.musicxml`과 같은 MusicXML 4.0이며 확장자만 다르다. 내보내기 테스트 250개가 통과했다.
> 2026-09-19 22:40 M8-09를 완료했다. 내려받기 메뉴에서 화면과 같은 펼친·반주 결과를 MusicXML/MXL·MIDI·Grand Staff PDF로 새 파일로 저장하고, 편집용 프로젝트 zip은 원본 악보와 Sequence·반주 프로필을 담는다. 원본 MusicXML은 덮어쓰지 않는다. 전체 249개 테스트가 통과했다. Android에서 PDF 재열기는 B-017로 남아 있다.
> 2026-09-19 22:25 M8-08을 완료했다. 코드 진행에서 규칙형 피아노 반주를 만들고 끔/블록/박/분산 프로필만 별도 JSON으로 저장한다. 원본 음표는 덮어쓰지 않고, 편집이 꺼져 있을 때 펼친 Sequence 위에 반주를 올려 Grand Staff와 재생 타임라인에 연결한다. 전체 244개 테스트가 통과했다.
> 2026-09-19 22:10 M8-07을 완료했다. 반음 수 또는 목표 조를 고르면 음표·코드 심벌·조표를 같은 간격으로 옮기고, 임시표 표기는 도착 조의 조표를 따른다. 이조는 undo 가능한 편집 명령이며 Grand Staff와 재생 타임라인에 바로 다시 올린다. 전체 234개 테스트가 통과했다.
> 2026-09-19 21:55 M8-06을 완료했다. Playback Sequence는 원본 마디를 복제하지 않고 Section 순서와 반복 횟수만 저장한다. `INTRO × 4 → VERSE × 2 → CHORUS × 1`을 실제 연주 순서로 펼쳐 alphaTab 재생과 Bar/Beat Cursor에 연결했다. 전체 223개 테스트가 통과했다.
> 2026-09-19 21:45 M8-05를 완료했다. 별도 Dart 타이머로 음을 흉내 내지 않고 alphaTab 1.8.4 MIDI 합성기와 공식 SONiVOX SoundFont(`sonivox.sf2`)를 로컬 자산으로 고정했다. 재생·일시정지·정지·탐색은 같은 엔진 타임라인을 쓰고, Bar/Beat Cursor는 alphaTab 렌더 위치에 맞춰 표시된다. 전체 215개 테스트가 통과했다.
> 2026-09-19 20:07 M8-04를 완료했다. 내부 Score Document를 불변 스냅샷으로 편집하는 최대 100단계 undo/redo 명령, 음표·쉼표·코드 심벌 입력·수정·삭제, 조표·박자표 변경, 모든 파트에 정렬된 마디 추가·삭제를 구현했다. alphaTab 음표를 직접 누르거나 하단 이벤트 목록에서 선택하고 변경 즉시 Grand Staff를 다시 조판한다. 수정본은 가져온 앱 내부 `.musicxml`/`.mxl` 형식을 유지해 검증 후 원자적으로 저장하고, MusicXML/MXL 내보내기는 현재 편집본을 사용한다. 전체 207개 테스트가 통과했고 정적 분석에는 기존 경고 5건만 남았다.

> 2026-09-19 19:41 M8-03을 완료했다. alphaTab 1.8.4와 Bravura 폰트를 앱 자산으로 고정해 CDN 의존성을 제거하고, 내부 Score Document를 정규화 MusicXML로 전달해 피아노 Grand Staff를 오프라인 렌더링한다. 모바일·태블릿 폭에 따라 스케일과 마디 시스템을 다시 배치하며 모든 파트를 표시한다. headless Chrome에서 높은음자리표·낮은음자리표·피아노 중괄호가 포함된 실제 SVG 렌더를 확인했고 전체 193개 테스트가 통과했다.

> 2026-09-19 19:19 M8-02를 완료했다. MusicXML 4.0 `score-partwise` 기반 내부 Score Document와 피아노 Grand Staff의 staff·voice 타이밍, 음표·쉼표·코드·조표·박자표·clef·템포·구간 표식·코드 심벌을 구현했다. `.musicxml`·`.xml`·표준 `.mxl`을 가져오고 MusicXML/MXL로 다시 내보내며, Library 가져오기·메타데이터 자동 채움·전자악보 확인 화면·파일 저장까지 연결했다. MXL 경로 탈출·크기·엔트리 수를 제한했고 전체 191개 테스트가 통과했다.
> 2026-09-19 18:45 재구성한 전자악보의 PDF 내보내기를 M8-09 필수 완료 조건으로 명시했다. 작성·수정, 이조, 반주·편곡과 Playback Sequence를 반영하고 `INTRO × 4 → VERSE × 2 → CHORUS × 1`처럼 반복 마디를 실제 펼친 선형 악보를 Android 앱 내부에서 새 PDF로 생성한다. 이는 기존 PDF 위에 펜을 합성하는 M8-01과 별도 기능이며 iOS는 계속 범위에서 제외한다.
> 2026-09-19 18:37 피아노 지원을 로컬 우선 MVP 8로 재개했다. MusicXML/MXL을 상호운용 기준으로 삼고 작성·수정·재생·Section 반복 순서·이조·기본 반주 프로필·MusicXML/MIDI/PDF 내보내기를 앱 내부 우선으로 계획했으며, PDF OMR·고급 AI 편곡·레퍼런스 영상 음색 추천은 서버 Future로 분리했다. 첫 개발 항목으로 기존 PDF 펜 주석을 원본과 별도 JSON은 보존한 채 새 평면화 PDF에 합쳐 내보내는 기능을 구현했다. 전체 `flutter test --no-pub -j 1` 181개 통과, `flutter analyze --no-pub`는 기존 미사용 private method 4건과 Flutter 3.44 비관련 deprecation 1건이 남았다. Android APK 재빌드는 로컬 Windows가 `pdfium_flutter` 심볼릭 링크 생성 권한을 갖지 못해 B-017로 기록했다.
> 2026-08-31 11:01 메트로놈·주석 회귀 검수: BPM/연음/박자표/Count-In/악센트/JSON 경계, stale 재생 요청·중복 시작·정지·Count-In 자산 선행 로딩, Jam clock timeline을 테스트로 확장했다. malformed 주석 좌표·색·선·투명도 입력도 안전하게 무시·보정한다. 전체 `flutter test -j 1` 177개 통과, `flutter analyze --no-pub`는 기존 ScoreViewer 미사용 private method 경고 4개만 남았고 release APK(SHA-256 `90ef58d3d521a65afccf10764fdb960f184a47cc36abcce1b8f52f83c5104c06`)를 `emulator-5554`에 versionCode 2로 재설치했다. 에뮬레이터에서 메트로놈 Start→박자 표시→Stop smoke와 치명 예외 없는 로그를 확인했다. 실기기 실제 청취·두 기기 Jam 동시성은 B-005/B-012로 남아 있다. `metronome`·`pdf_annotations` 신규 의존성은 현재 요구와 renderer 호환성에 맞지 않아 추가하지 않았다.
> 2026-08-27 17:13 Jam 참가자별 보기 모드가 달라도 호스트의 논리 페이지를 각 기기의 표시 스프레드로 정규화하도록 수정했다. 2쪽 보기에서 호스트가 2페이지로 이동할 때 같은 1–2 스프레드를 다시 여는 문제를 제거했으며, 게스트 메트로놈은 시작 시각 전에 클릭 자산을 준비하고 로컬 clock offset을 반영해 시작하도록 보강했다. 다음 clock 보정은 실제 다음 마디부터 적용한다. 전체 테스트 154개·analyze(기존 경고 4개)·release build를 통과했고 최신 APK(SHA-256 `6b9b5358a50a8eaef5f89022ff5438a4c6e584a92bc7155ada5c87002ecec756`)를 `emulator-5554`에 versionCode 2로 재설치·실행했다. 새 실기기는 빌드 완료 시 ADB에서 빠져 실제 다중 기기 청취 검증은 B-012/B-005로 남아 있다.
> 2026-08-27 16:21 합주 Follow에서도 다음 곡 전환이 막히지 않도록 참가자 자동 진입 조건을 보강했다. 현재 세션 entry가 이전에 열었던 entry와 다를 때만 새 악보를 열어 같은 곡 재시작 중복은 막고 곡 교체는 허용한다. 전체 테스트 154개·analyze·release build를 통과했으며 최종 APK(SHA-256 `9862af2986df1378a04fda4d67867c4f871dd8382f982fc3060200df3b95a61f`)를 `SM-X620`, `emulator-5554`에 versionCode 2로 재설치·실행했다. 실제 두 Android 기기 Jam 곡 전환·오디오 동시성은 B-012/B-005로 남아 있다.
> 2026-08-27 16:11 Viewer 세트리스트 다음 악보 전환을 수정했다. `/score/:songId` 라우트 키를 실제 URI로 바꿔 곡 교체 시 기존 PDF 뷰어 State를 재사용하지 않도록 했고, 끝 페이지·오디오 종료에서 최신 세트리스트 snapshot을 확인해 다음/이전 곡을 연다. `flutter test -j 1` 154개·analyze(기존 경고 4개)·release build를 통과했으며 APK(SHA-256 `aec70656ded600c16d6dc5b9d39992f83242475bf6fa0bc9b113045e7ba5041f`)를 `SM-X620`과 `emulator-5554`에 versionCode 2로 재설치·실행했다. 실제 세트리스트 오디오 자동 전환과 두 Android 기기 Jam 검증은 B-012/B-005로 남아 있다.
> 2026-08-27 14:51 Jam 화면의 현재 곡과 역할별 핵심 동작을 하단 플로팅 컨트롤 하나로 통합했다. 곡 제목을 누르면 악보를 열고, 호스트는 이전·다음·시작/정지, 참가자는 준비 토글을 같은 위치에서 처리한다. 목록이 플로팅 바에 가려지지 않도록 하단 여백을 확보했다. 전체 테스트 154개·analyze(기존 경고 4개)·release build를 통과하고 APK(SHA-256 `1143faebd8417ed18902b68187997522943788b18d0a2927541d84ba60364a0d`)를 `SM-X620`, `SM-F966N`, `emulator-5554`에 versionCode 2로 재설치·실행했다. 실제 두 Android 기기 Jam 보기 모드·오디오 동시성은 B-012/B-005로 남아 있다.
> 2026-08-26 전체 검수: 기존 설치에서 실제 테이블보다 뒤처진 Drift schema version 때문에 목록 스트림이 시작되지 않을 수 있어, 컬럼 존재를 확인하는 복구형 마이그레이션과 회귀 테스트를 추가했다. 사용자 결정으로 Native Digital Score(M8)는 개발 범위에서 제외하고 활성 집계에서도 제외했다. Android 실기기 두 대의 LAN Jam 검증은 남아 있다. 주석 도크의 되돌리기·전체 지우기 아이콘 대비를 보정했고, 도구의 중복 클라우드 악보 타일을 제거해 WebDAV 진입을 Library 추가 흐름으로 통일했다. 이 변경을 반영한 최신 release APK를 에뮬레이터와 연결된 실기기에 설치했다.
> 2026-08-26 Jam 개선: 합주 화면에 별도 시작·정지 버튼과 읽기 쉬운 세트리스트·참가자 카드를 추가했다. `JamMusicState`가 호스트의 박자표·음표 단위·박별 악센트를 전달하고 멤버가 기본으로 적용하며, 시작 시 점수 화면을 열고 공통 `startAt`으로 각 기기의 메트로놈을 동시에 시작한다. 각 기기는 공통 설정의 로컬 클릭을 재생하고 별도 Individual/Host 선택은 제공하지 않는다. 최종 변경 후 Jam 테스트 47개와 analyze를 다시 확인했다.
> 2026-08-26 14:20 설치: Individual Click 기본값 변경 release APK를 연결된 `emulator-5554`에 재설치하고 `MainActivity` 실행 및 프로세스 실행을 확인했다. 실기기 `RFKL40AXPCP`는 현재 연결되어 있지 않다.
> 2026-08-26 14:22 설치: 동일 release APK를 실기기 `RFKL40AXPCP`(SM-F966N)에 재설치하고 `MainActivity` 실행 및 프로세스 실행을 확인했다.
> 2026-08-26 14:26 설치: 동일 release APK를 실기기 `R3CX70AFANJ`(SM-F741N)에 재설치하고 `MainActivity` 실행 및 프로세스 실행을 확인했다.
> 2026-08-26 14:53 LAN 진단: 두 실기기가 같은 `192.168.0.0/23` Wi-Fi에 있고 게스트에서 호스트 TCP `47828`까지 연결되지만 UDP discovery만 시간 초과하는 경로를 확인했다. `LanJamSessionStore`가 global broadcast만 보내지 않고 인터페이스의 directed broadcast(`192.168.1.255`)도 전송하도록 보강하고, Jam 테스트 47개·analyze 통과 release APK를 두 실기기에 재설치했다. 실제 세션 참가 재검증은 B-012로 남아 있다.
> 2026-08-26 14:58 보강: 일부 인터페이스의 broadcast 주소가 라우팅되지 않아 `udp.send`가 예외를 내는 회귀를 주소별 예외 처리로 격리했다. 전체 테스트 140개와 analyze를 통과한 최종 release APK를 두 실기기에 재설치했다. 실제 세션 참가 재검증은 B-012로 남아 있다.
> 2026-08-26 15:11 방어: 네트워크 미연결·UDP 비동기 오류·malformed packet·호스트 TCP/세션 종료를 처리하고, 합주 생성·참가·QR 참가 버튼에 연결 중 로딩과 중복 입력 차단을 추가했다. 호스트 종료 시 게스트는 안내와 합주 목록 복귀를 본다. 전체 테스트 141개와 analyze 통과 release APK를 두 실기기에 재설치했다.
> 2026-08-26 15:24 세트리스트 식별자: Jam 공유 payload에서 로컬 `Song.id`를 제거하고 `Setlist.id`+`SetlistEntry.id`와 순서·제목·아티스트·BPM만 전송하도록 정리했다. 기기별 파트 악보 `Song.id`는 로컬에 저장해 최초 선택·재선택 후 자동으로 연다. M6 완료 수와 전체 진행률은 변경하지 않으며, 공통 Measure/Beat/Section 매핑은 Future F-01로 남긴다.
> 2026-08-26 15:54 Jam 참가 파트: 세션 생성·참가 시 보컬·기타·베이스·드럼·키보드·기타(직접 입력)를 고르게 하고, 선택한 악기 아이콘과 Conductor/Member 권한을 참가자 목록에 함께 표시한다. 호스트 세트리스트 선택 버튼은 로딩·중복 입력 차단·오류 안내를 추가했다. M6 완료 수와 전체 진행률은 변경하지 않는다.
> 2026-08-26 16:06 설치 재확인: 두 실기기 `R3CX70AFANJ`·`RFKL40AXPCP`와 `emulator-5554`가 ADB에 연결됐다. 최종 release APK(versionCode 2)를 두 실기기에 설치·실행했으며 실제 LAN Jam 세션 검증만 B-012로 남아 있다.
> 2026-08-26 16:34 Jam 대기실 보강: 새 멤버 ready 상태와 LAN ready 메시지를 추가하고, 연결된 멤버가 모두 준비되어야 호스트가 시작하도록 방어했다. 호스트의 playing/startAt 전파 시 참가자 화면이 현재 로컬 악보로 자동 진입하고 중복 라우팅 없이 같은 메트로놈을 시작한다. 방 헤더·코드·참가자 준비 칩·큰 준비/시작 버튼을 추가하고 세트리스트/악보 선택 팝업에 제목·패딩·카드 여백을 적용했다. 호스트가 세트리스트 편집 화면에서 곡을 추가하면 돌아와 공유 스냅샷을 갱신한다. 전체 144개 테스트·analyze·release build를 통과했고 APK를 두 실기기와 에뮬레이터에 재설치했다. 실제 LAN Jam ready→start 검증은 B-012로 남아 있다.
> 2026-08-26 16:49 LAN 탐색 안정화: 호스트 UDP listener 준비 지연, 루프백 우선 질의, 20ms 초기 질의와 120ms 재시도를 적용해 전체 Jam 테스트 51개와 전체 테스트 144개를 통과했다. 변경 release APK를 `R3CX70AFANJ`, `RFKL40AXPCP`, `emulator-5554`에 재설치·실행했으며 실제 두 기기 ready→start·오디오 동시성은 B-012로 남아 있다.
> 2026-08-26 17:05 최종 보강: discovery 소켓을 재생성하지 않고 단일 소켓에서 재시도하며, 호스트 UDP 구독·종료 순서를 명시했다. 세트리스트가 없을 때 새로 만든 목록을 Jam으로 돌아오며 즉시 공유하도록 연결했다. 전체 테스트 144개와 Jam 51개를 통과하고 release APK를 세 기기에 재설치·실행했다. 실제 두 기기 ready→start·오디오 동시성은 B-012로 남아 있다.
> 2026-08-26 17:11 최종 APK 재설치: any IPv4 바인딩을 유지한 최종 코드를 release build하고 `R3CX70AFANJ`·`RFKL40AXPCP`·`emulator-5554`에 versionCode 2로 재설치·실행했다. 실제 두 기기 ready→start·오디오 동시성은 B-012로 남아 있다.
> 2026-08-26 17:30 기존 세트리스트 등록 보강: Jam 공유 로더가 화면 전환 중 live `watchItems().first`를 기다리지 않고 일회성 `getItems()` snapshot을 읽도록 변경했다. 전체 테스트 144개·Jam 51개·analyze(기존 경고 4개)를 확인하고 release APK를 `R3CX70AFANJ`와 `emulator-5554`에 재설치했다. `RFKL40AXPCP`는 현재 연결되지 않았다.
> 2026-08-26 17:41 참가자 악보 등록: Jam 참가자 곡 목록의 오른쪽 연결 아이콘으로 곡마다 자기 기기 Library 악보를 선택·저장하게 했다. 매핑은 `Setlist.id`+`SetlistEntry.id`에 로컬 저장하고 연결된 곡은 재선택할 수 있으며, 전체 테스트 144개·Jam 51개·analyze(기존 경고 4개)·release build를 통과했다. versionCode 2 APK를 `R3CX70AFANJ`·`RFKL40AXPCP`·`emulator-5554`에 재설치·실행했다. 실제 두 기기 LAN Jam ready→start·오디오 동시성은 B-012로 남아 있다.
> 2026-08-27 09:03 태블릿 설치: Android 태블릿 `SM-X620`(ADB `R54Y600GBKY`)에 versionCode 2 release APK를 설치하고 MainActivity·앱 프로세스 실행과 설치 APK SHA-256 일치를 확인했다. 실제 두 기기 LAN Jam ready→start·오디오 동시성은 B-012로 남아 있다.
> 2026-08-27 09:18 반응형 홈 헤더: 760dp 미만 모바일에서만 홈 제목 옆 AppBrandMark를 표시하고, 폴드 펼침·태블릿 wide layout에서는 NavigationRail 아이콘 하나만 남기도록 breakpoint를 공유했다. 관련 위젯 테스트를 포함한 전체 테스트 145개·analyze(기존 경고 4개)·release build를 통과했고 최신 APK를 `SM-X620`과 `emulator-5554`에 재설치·실행했다.
> 2026-08-27 09:30 클라우드·세트리스트 선택 보강: Google Drive·Dropbox 공개 클라이언트 값을 Android 기본 설정으로 포함해 일반 release 빌드에서도 앱 내부 OAuth를 시도하도록 바꿨다. Jam의 세트리스트 선택은 Riverpod stream의 오래된 첫 빈 값을 사용하지 않고 현재 Drift 목록 snapshot을 읽도록 수정했다. 관련 회귀 테스트와 전체 147개 테스트·analyze·release build를 통과했고 새 APK를 `SM-X620`과 `emulator-5554`에 재설치·실행했다. 앱 삭제·새 기기에서 이전 로컬 세트리스트를 자동 복원하는 기능은 아직 없다.
> 2026-08-27 09:53 Jam 세트리스트 내려받기·악보 연결 보강: 참가자가 호스트 공유 세트리스트를 자신의 Setlists에 자동 저장하도록 하고, 로컬 매칭 악보는 즉시 연결하며 없는 곡은 순서·제목·BPM을 유지한 대기 항목으로 저장한다. 곡별 연결 버튼에서 Library·기기·Google Drive·Dropbox·WebDAV를 선택할 수 있고, 가져온 PDF/원격 악보는 기존 Library 저장소에 등록한 뒤 해당 SetlistEntry에 연결한다. 세트리스트 저장소 회귀 테스트·analyze·release build를 통과하고 새 APK를 `SM-X620`과 `emulator-5554`에 설치·실행했다. 전체 테스트는 144개 통과, LAN discovery 4개는 현재 환경의 `jamJoinTimedOut`으로 남았다.
> 2026-08-27 10:03 WebDAV Jam 연결 보강: Jam에서 WebDAV 항목을 선택하면 원격 곡을 Library에 등록하는 데서 끝나지 않고 바로 PDF를 내려받아 오프라인 악보로 만든 뒤 연결하도록 정리했다. 이미 등록된 WebDAV 곡도 선택 시 필요한 경우 같은 다운로드 경로를 탄다. 새 release APK를 `SM-X620`과 `emulator-5554`에 재설치·실행했다.
> 2026-08-27 10:06 최종 검증: Jam 악보 연결 예외를 공통 안내로 처리하고, 최종 release APK(SHA-256 `784f21ec4b987ef29e20df47a86ac8effb269a834774c57c533717c8a328bddb`)를 `SM-X620`과 `emulator-5554`에 재설치·실행했다.
> 2026-08-27 10:30 Jam 방장 악보 fallback: 참가자는 오프라인 자기 악보를 우선 열고, 없을 때 필요한 entry의 PDF만 LAN 요청·응답으로 받아 `jam_host` 임시 캐시에 저장한다. 임시 악보는 Library에 노출하지 않고 Viewer 주석 편집을 잠그며 Jam 화면 종료·다음 진입 시 정리한다. 호스트 PDF 왕복·저장·헤더 검증 테스트와 전체 151개 테스트, analyze, release build를 통과했고 SHA-256 `6660579539f4a119610dc8dcbc06b59cad7f59e02b58f24c41e10109b9fbebd4` APK를 `SM-X620`과 `emulator-5554`에 설치·실행했다. 실제 두 Android 기기 Jam 흐름은 B-012로 남아 있다.
> 2026-08-27 10:37 최종 재검증: 방장 악보 요청 중 연결이 끊긴 소켓에 응답하지 않도록 보강하고 전체 151개 테스트·analyze·release build를 다시 통과했다. 최종 APK SHA-256은 `4e252ab3083af3874cb39e0be05416c7daa7963859b00a8b12c29d00adc4c858`이며 `SM-X620`과 `emulator-5554`에 재설치·실행했다.
> 2026-08-27 11:08 Jam 흐름 정리: 합주 화면에서 Individual Click 선택을 제거하고 호스트가 BPM·박자표·음표 단위·카운트인·박별 악센트를 메트로놈 시트에서 설정하도록 연결했다. 일반 세트리스트 Viewer는 마지막 페이지에서 다음/이전 곡으로 자동 전환하며, Jam 허브는 활성 방으로 돌아가기 카드와 같은 Wi-Fi 주변 방 검색·참가 목록을 제공한다. 전체 테스트 152개·analyze·release build를 통과했고 `SM-X620`(R54Y600GBKY)·`emulator-5554`에 설치·실행했다. 실제 두 Android 기기 Jam 오디오 동시성은 B-012로 남아 있다.
> 2026-08-27 11:37 LAN discovery 안정화: `/23` 환경에서 잘못된 directed broadcast를 추정하던 코드를 제거하고 limited broadcast·인터페이스 주소만 사용하도록 수정했다. 호스트·브라우저 UDP 수신기는 한 read 이벤트의 대기 datagram을 모두 처리한다. 주변 방 탐색 targeted test 12회와 전체 테스트 152개·analyze(기존 경고 4개)를 통과했으며 release APK(SHA-256 `7134aba53aa24a5ee9e737c02e7f6e9ae7541adc0e5762322920e983740b7a49`)를 `SM-X620`과 `emulator-5554`에 versionCode 2로 재설치·실행했다. 실제 두 Android 기기 Jam ready→start·오디오 동시성은 B-012로 남아 있다.
> 2026-08-27 11:43 LAN query-response 단순화: 호스트의 불필요한 주기 announce를 제거하고 탐색 query에만 방 정보를 응답하도록 정리했다. 전체 테스트 152개·Jam 54개·analyze(기존 경고 4개)를 재확인하고 release APK(SHA-256 `99603fab4d29f6726c0ce5ae704249b1fb616fa34ecbc472ab0e7b769c35b209`)를 `SM-X620`과 `emulator-5554`에 재설치·실행했다. 실제 두 Android 기기 Jam ready→start·오디오 동시성은 B-012로 남아 있다.
> 2026-08-27 13:41 세트리스트 곡별 메트로놈 프로필: `SetlistEntries.metronome_json`(DB v16)에 곡별 BPM·박자표·음표 단위·박별 악센트를 nullable JSON으로 저장하도록 추가했다. 기존 `tempoOverride`/BPM-only 항목과 구형 Jam payload는 그대로 읽고, Jam 곡 전환 시 해당 프로필을 적용하며 호스트 설정 변경은 현재 entry에 저장한다. 전체 테스트 154개·analyze(기존 경고 4개)·release build를 통과하고 APK(SHA-256 `4d702d869b1f98e8d8b85c5dd26ce1fd978e4c1bbf036371608f1840726e59da`)를 `SM-X620`, `SM-F966N`, `emulator-5554`에 versionCode 2로 재설치·실행했다. 실제 두 Android 기기 Jam 오디오 동시성은 B-012로 남아 있다.
> 2026-08-27 13:49 호스트 초기화 보강: 세트리스트 곡을 Viewer에서 처음 열 때 전역 메트로놈 기본값이 저장된 곡별 프로필을 덮어쓰지 않도록 현재 Jam 곡 프로필을 Viewer 초기 상태에 먼저 적용했다. 전체 테스트 154개·analyze(기존 경고 4개)·release build를 통과하고 APK(SHA-256 `d57f4a65443d41bd093a7f96a4928baa00a2ce773695791200a7dccc49e01074`)를 `SM-X620`, `SM-F966N`, `emulator-5554`에 versionCode 2로 재설치·실행했다. 실제 두 Android 기기 Jam 오디오 동시성은 B-012로 남아 있다.
> 2026-08-27 14:12 Jam 화면·무대 메트로놈 보강: 주변 방 카드에 안전 여백을 늘리고 검색 실패를 화면 내 Wi-Fi 안내로 표시했다. Jam은 세트리스트 곡 선택을 메트로놈 설정 위로 이동하고 곡별 설정 카드를 분리했다. 무대 시작은 오디오 클릭 자산을 먼저 준비하고 Count-In 음성은 지연 로딩해 시작 경로 실패를 줄였다. Wi-Fi 문구를 `Wi-Fi를 켠 뒤 다시 시도해 주세요`로 정리했다. 전체 테스트 154개·analyze(기존 경고 4개)·release build를 통과하고 APK(SHA-256 `43b429397d49427957aa3fa4f7c29307dc1db8f95b1e3567961bc06d93f13288`)를 `SM-X620`, `SM-F966N`, `emulator-5554`에 versionCode 2로 재설치·실행했다. 실제 두 Android 기기 오디오 동시성과 Stage 청취는 B-012/B-005로 남아 있다.
> 2026-08-27 14:30 Viewer 페이지 경계·Jam 보기 정책 보강: `맞춤`·`2쪽` 보기에서 현재 페이지/스프레드 밖으로 매트릭스가 이동하지 않도록 정규화하고, 비스크롤 모드의 마우스 휠 연속 이동을 끈 뒤 페이지 이동 경로를 `_goToViewerPage`로 통일했다. `스크롤`만 세로 연속 이동하며, Jam에서는 각 기기의 `맞춤`·`2쪽`·`스크롤` 선택을 로컬로 유지하고 호스트의 논리 페이지·마디·메트로놈 상태만 적용한다. 전체 테스트 154개·analyze(기존 경고 4개)·release build를 통과하고 APK(SHA-256 `9c1e6cedfa1c3cd749540c54530737e62436f1d490f17ca9d9fc702d440326bd`)를 `SM-X620`, `SM-F966N`, `emulator-5554`에 versionCode 2로 재설치·실행했다. 실제 두 Android 기기에서 보기 모드별 동작·오디오 동시성은 B-012/B-005로 남아 있다.

## P0 — 기반 설계

- [x] P0-01 기획서 요구사항 및 개발 우선순위 검토
- [x] P0-02 다중 AI 공통 작업 규칙 작성
- [x] P0-03 기계 판독 가능한 프로젝트 상태 문서 작성
- [x] P0-04 단계별 로드맵과 작업 로그 작성
- [x] P0-05 앱 이름, Bundle ID, 최소 Android 버전 확정 및 iOS 배포 제외
- [x] P0-06 Flutter 프로젝트 초기화
- [x] P0-07 기능 중심 디렉터리 및 계층 구조 확정
- [x] P0-08 상태 관리와 의존성 주입 방식 확정
- [x] P0-09 로컬 데이터베이스 및 파일 저장 전략 확정
- [x] P0-10 분석, 린트, 단위/위젯 테스트 기준 설정
- [x] P0-11 CI 기본 검사 구성

## Design — `DESIGN.md` 토큰 적용

- [x] DS-01 색/타이포/간격 토큰, 최소 제품 카피와 안전 여백 원칙을 적용. 웹 쇼핑몰 레이아웃과 브랜드는 복사하지 않는다.

## MVP 1 — 실제로 연주에 쓸 수 있는 악보 앱

- [x] M1-01 앱 셸과 주요 화면 내비게이션
- [x] M1-02 Library 목록, 검색, 분류 UI
- [x] M1-03 곡/악보 로컬 데이터 모델과 저장소
- [x] M1-04 OS File Picker 기반 PDF 가져오기
- [x] M1-05 가져온 PDF 오프라인 보관, PDF 헤더 검증과 파일 상태 처리
- [x] M1-06 곡 정보와 기본 BPM 등록/수정
- [x] M1-07 즐겨찾기
- [x] M1-08 악보 메모
- [x] M1-09 `pdfrx` PDF Viewer와 손상 파일 오류 안내
- [x] M1-10 한 손가락 페이지 이동 Gesture Layer
- [x] M1-11 두 손가락 Zoom/Pan 및 화면 맞춤
- [x] M1-12 방향 전환, 페이지 이동, 본문 중앙 탭 메뉴 숨김/좌우 스와이프, 맞춤·두 장 전체 맞춤·스크롤 보기, 고정 보기 아이콘, 상·하단 오버레이 제어바, 독립/Viewer 공통 메트로놈(BPM 입력·12종 박자표·음표 아이콘 단위·박별 강박/기본/뮤트)과 자유선 주석
- [x] M1-13 Setlist 데이터 모델
- [x] M1-14 Setlist 생성/편집/순차 열기
- [x] M1-15 독립 Tap Tempo와 BPM 안정화/반값/두 배
- [x] M1-16 `flutter_soloud` 오디오 기반 구성
- [x] M1-17 메트로놈과 Count-In
- [x] M1-18 일반 오디오 파일 연결 및 재생

## MVP 2 — PDF Smart Score

- [x] M2-01 Measure 영역 생성/수정과 Smart Score 메타데이터
- [x] M2-02 Section 편집과 표시
- [x] M2-03 Tempo Map과 STEP/GRADUAL BPM
- [x] M2-04 Time Signature Map
- [x] M2-05 현재 Measure Highlight
- [x] M2-06 Follow/Page Mode와 Manual Override
- [x] M2-07 음악 파일 연결
- [x] M2-08 Sync Anchor와 음악 Timeline 동기화
- [x] M2-09 A-B/Measure Loop
- [x] M2-10 Playback Speed
- [x] M2-11 Cue 등록과 표시

## MVP 3 — Practice

- [x] M3-01 Tempo Trainer
- [x] M3-02 어려운 Measure 태그와 필터
- [x] M3-03 연습 세션 기록
- [x] M3-04 목표 BPM
- [x] M3-05 구간 반복 연습
- [x] M3-06 연습 통계

## MVP 4 — External Storage

- [~] M4-01 Google Drive 앱 내부 연결 — OAuth·파일 목록·가져오기 구현, 빌드 기본 키 고정. 사용자 보고로 다운로드 확인, 실기기 재검증은 AUDIT-CLOUD-001
- [~] M4-02 Dropbox 앱 내부 연결 — OAuth·파일 목록·가져오기 구현, 빌드 기본 키 고정. 사용자 보고로 다운로드 확인, 실기기 재검증은 AUDIT-CLOUD-001
- [-] M4-03 OneDrive 앱 내부 연결 — OS 파일 선택기로 접근 가능, Entra 앱 등록/OAuth 설정 대기
- [~] M4-04 WebDAV/NAS 연결 — HTTPS 연결·자격 증명 저장 구현됨, 실서버 검증 대기
- [~] M4-05 저장소 폴더 탐색 — WebDAV 폴더/PDF 목록 구현됨, 실서버 검증 대기
- [x] M4-06 Sync 상태 관리
- [x] M4-07 Setlist 단위 오프라인 다운로드

## MVP 5 — Stage

- [x] M5-01 Stage Mode와 화면 꺼짐 방지
- [x] M5-02 다음 Section Preview
- [x] M5-03 Performance Lock
- [x] M5-04 Bluetooth Pedal/Keyboard 매핑
- [x] M5-05 Setlist 공연 진행

## MVP 6 — Jam Session v1

- [x] M6-01 Session 생성/참가
- [x] M6-02 QR/Code 초대
- [x] M6-03 Participant Presence
- [x] M6-04 Conductor/Member 역할
- [x] M6-05 Setlist 공유 — Setlist/SetlistEntry UUID와 순서·곡 메타데이터, 항목별 메트로놈 프로필을 공유하고 로컬 Song/PDF는 기기에 남긴다.
- [x] M6-06 Conductor 곡 변경 — currentEntryId로 항목을 바꾸고 기기별 로컬 악보 매핑을 연다.
- [x] M6-07 페이지/Measure 위치 공유
- [x] M6-08 BPM/Section 공유 — 곡별 BPM·박자표·음표 단위·박별 악센트는 SetlistEntry 프로필로 보존하고 Section은 세션 상태로 공유한다.
- [x] M6-09 Start/Stop 공유
- [x] M6-10 Follow Conductor/Return to Live

## MVP 7 — Jam Session v2

- [x] M7-01 Count-In Sync
- [x] M7-02 공통 시작 시각 합의
- [x] M7-03 Metronome Sync
- [x] M7-04 공통 로컬 클릭 — 각 기기가 공통 `startAt`·설정으로 클릭을 재생하며 별도 Host/Individual 선택은 제거
- [x] M7-05 Jam 메트로놈 설정·방 탐색 — 곡별 프로필을 적용하는 BPM·박자표·음표 단위·카운트인·박별 악센트와 같은 Wi-Fi 주변 방 목록을 제공
- [x] M7-06 Loop 공유
- [x] M7-07 Clock 오차 보정

## MVP 8 — 로컬 피아노 전자악보

- [x] M8-01 원본을 보존하는 주석 포함 평면화 PDF 내보내기
- [x] M8-02 MusicXML/MXL Import·Export와 내부 Score Document 모델
  - MusicXML 4.0 `score-partwise`, `.musicxml`·`.xml`·`.mxl`, 피아노 다중 staff·voice·chord 타이밍 지원
  - Library 가져오기, 곡명·작곡가·템포 자동 채움, MusicXML/MXL 재내보내기 연결
  - PDF와 같은 출처(기기·Google Drive·Dropbox·WebDAV)에서 `.musicxml`·`.mxl`·`.xml`을 고른다
- [x] M8-03 피아노 Grand Staff 렌더링과 화면 크기별 재배치
  - alphaTab 1.8.4·Bravura를 로컬 자산으로 포함하고 CDN·워커·사운드폰트 없이 SVG 렌더링
  - MusicXML 전체 파트, 피아노 Grand Staff, 모바일·태블릿 폭별 자동 system wrap과 스케일 적용
- [x] M8-04 음표·쉼표·마디·조표·박자표·코드 작성 및 수정
  - 렌더링된 음표 직접 선택과 마디별 음표·쉼표·코드 심벌 이벤트 선택·입력·수정·삭제
  - 조표·박자표, 전체 파트 정렬 마디 추가·삭제, 최대 100단계 undo/redo와 저장 전 이탈 확인
  - 편집 즉시 Grand Staff 재조판, 원본 형식 유지 검증·원자 저장, 현재 편집본 MusicXML/MXL 내보내기
  - Library `악보 만들기`로 빈 피아노 한 마디를 만들어 바로 편집한다
  - 음가·쉼표·임시표를 고른 뒤 오선을 눌러 바로 넣고, 음표를 끌어 높이를 바꾼다
- [x] M8-05 MIDI/샘플 기반 로컬 재생과 Bar/Beat Cursor
  - alphaTab MIDI 합성기 + FreePats YDP 그랜드 피아노 SoundFont를 오프라인 자산으로 사용
  - 재생·일시정지·정지·탐색과 실제 렌더 Bar/Beat Cursor를 하나의 타임라인으로 연결
  - 악보를 먼저 누르면 Web Audio를 열고, SoundFont가 늦어도 재생을 이어 받는다
- [x] M8-06 Section 반복 횟수와 순서를 저장하는 Playback Sequence
  - 원본 Score Document는 유지하고 Section 순서·반복만 별도 메타데이터로 저장
  - 재생 시 펼친 선형 타임라인을 alphaTab 재생과 Bar/Beat Cursor에 연결
  - 연주 순서 패널에서 선택한 마디에 벌스·코러스 역할을 붙이고, 그 역할의 반복 횟수만 정한다
  - 붙은 구간 이름은 그 줄 앞에만 네모로 보인다. 이후 마디에는 반복하지 않는다
  - 조판은 A4 폭으로 하고 화면 너비에 비율을 맞춰 줄인다. 흰 배경에서 핀치로 확대·이동한다. 구간은 그려진 한 줄에 붙인다
  - `다음 마디 추가`로 빈 마디를 늘릴 수 있다. 마디 번호·순서·조표·박자는 연주 순서에 두지 않는다
  - 오선을 누르면 그 줄 전체를 주황 박스가 감싼다
  - 구간이 없으면 이 마디에 먼저 붙이라고만 안내한다
- [x] M8-07 목표 조성·반음 단위 이조와 코드·조표 재구성
  - 반음 또는 목표 조로 음표·harmony·keyFifths를 한 명령으로 옮긴다
  - 도착 조의 음이름 표기를 쓰고, 변경은 즉시 Grand Staff·재생 타임라인에 반영한다
  - 조옮김은 도구·재생 막대에 합치지 않고 앱바 단독 버튼으로 연다
  - 조옮김 시트는 가져온·만든 원곡 조를 따로 보여 준다
  - 각 마디 위에 현재 조 이름(C, G, B♭)을 악보에 표시한다
- [x] M8-08 코드 기반 기본 피아노 반주와 로컬 편곡 프로필
  - 코드 심벌에서 코드/박마다/하나씩 반주를 만들고 프로필만 별도 파일로 저장한다
  - 코드 심벌이 없으면 `코드 없음`만 보여 반주를 적용하지 않는다
  - 원본 Score Document는 유지하고, 보기·재생 때 생성한 반주를 Grand Staff와 타임라인에 올린다
- [x] M8-09 재구성 결과를 반영한 MusicXML·MIDI·PDF와 편집 가능한 앱 프로젝트 내보내기
  - PDF 완료 기준: 작성·수정, 현재 조·이조, 반주·편곡 프로필과 Playback Sequence 순서·반복을 실제 펼친 선형 Grand Staff로 조판
  - Android 로컬에서 새 PDF로 저장하고 앱·일반 PDF Viewer에서 재열기 검증, 원본 Score Document는 보존
  - 구현: 성능 파일은 `.musicxml`·`.xml`·`.mxl`·MIDI·PDF로 펼친·반주 점수, 프로젝트 zip은 원본+sidecar. Android 재열기는 B-017

## Future

- [ ] F-01 파트별 악보와 공통 Timeline 자동 매핑
- [ ] F-02 Jam Session Cue 전송
- [ ] F-03 합주 메모
- [ ] F-04 공연용 Live Session
- [ ] F-05 자동 PDF 마디 인식 개선
- [ ] F-06 서버 OMR 기반 드럼·피아노 음표 인식
- [ ] F-07 서버 PDF → MusicXML 자동 변환과 사용자 검수
- [ ] F-08 스트링·오르간·브라스 고급 AI 편곡
- [ ] F-09 음악 자동 Beat 분석
- [ ] F-10 자동 BPM 변화 감지
- [ ] F-11 자동 Audio Sync
- [ ] F-12 SMB/SFTP NAS
- [ ] F-13 연주 녹음
- [ ] F-14 박자 정확도 분석
- [ ] F-15 macOS/Windows 버전
- [ ] F-16 레퍼런스 영상 분석과 음색 조합 추천

## 범위 제외

- iOS 배포·검증 — Android를 우선 배포 플랫폼으로 유지한다.
- 서버 기반 OMR·AI 편곡·영상 분석 — 로컬 전자악보 MVP가 완료되기 전에는 구현하지 않는다.

## 단계 완료 기준

- 해당 단계 체크리스트가 모두 완료되었다.
- 지원 플랫폼에서 핵심 사용자 흐름을 수동 검증했다.
- 자동 검사와 관련 테스트가 통과했다.
- 알려진 결함과 후속 작업이 `PROJECT_STATUS.yaml`에 기록되었다.
- 기획 범위 변경이 있다면 결정과 근거가 기록되었다.
