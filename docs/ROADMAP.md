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
| MVP 8 Native Digital Score | 제외 | — | 사용자 결정으로 개발 범위 제외 |
| Future | 0/15 | 0% | 미착수 |
| 디자인 토큰 적용 | 1/1 | 100% | 완료 |
| **전체** | **71/91** | **78%** | 진행 중 |

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

- [~] M4-01 Google Drive 앱 내부 연결 — Android OAuth 클라이언트 설정 제공, 실제 계정 로그인·파일 목록 검증 대기
- [~] M4-02 Dropbox 앱 내부 연결 — Android App Key·리디렉션 설정 제공, 실제 계정 로그인·파일 목록 검증 대기
- [-] M4-03 OneDrive 앱 내부 연결 — OS 파일 선택기로 접근 가능, Entra 앱 등록/OAuth 설정 대기
- [-] M4-04 WebDAV/NAS 연결 — HTTPS 연결 확인과 보안 저장 구현, 실제 서버 검증 대기
- [-] M4-05 저장소 폴더 탐색 — WebDAV 폴더/PDF 목록 구현, 실제 서버 검증 대기
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

## Future

- [ ] F-01 파트별 악보와 공통 Timeline 자동 매핑
- [ ] F-02 Jam Session Cue 전송
- [ ] F-03 합주 메모
- [ ] F-04 공연용 Live Session
- [ ] F-05 자동 PDF 마디 인식 개선
- [ ] F-06 OMR 기반 드럼 음표 인식
- [ ] F-07 실제 MusicXML 변환
- [ ] F-08 악보 편집기
- [ ] F-09 음악 자동 Beat 분석
- [ ] F-10 자동 BPM 변화 감지
- [ ] F-11 자동 Audio Sync
- [ ] F-12 SMB/SFTP NAS
- [ ] F-13 연주 녹음
- [ ] F-14 박자 정확도 분석
- [ ] F-15 macOS/Windows 버전

## 범위 제외

- MVP 8 Native Digital Score — 사용자 결정으로 개발 대상에서 제외. MusicXML, alphaTab, NativeScoreViewer, Playback Sequence 경로는 구현·검증하지 않는다.

## 단계 완료 기준

- 해당 단계 체크리스트가 모두 완료되었다.
- 지원 플랫폼에서 핵심 사용자 흐름을 수동 검증했다.
- 자동 검사와 관련 테스트가 통과했다.
- 알려진 결함과 후속 작업이 `PROJECT_STATUS.yaml`에 기록되었다.
- 기획 범위 변경이 있다면 결정과 근거가 기록되었다.
