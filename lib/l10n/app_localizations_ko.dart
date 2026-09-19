// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appName => 'Page-a-Diddle';

  @override
  String get tagline => '드럼 악보 연습';

  @override
  String get tabHome => '홈';

  @override
  String get tabLibrary => '라이브러리';

  @override
  String get tabSetlists => '세트리스트';

  @override
  String get tabTools => '도구';

  @override
  String get tabJam => '합주';

  @override
  String get settings => '설정';

  @override
  String get language => '언어';

  @override
  String get theme => '테마';

  @override
  String get themeSystem => '시스템';

  @override
  String get themeLight => '라이트';

  @override
  String get themeDark => '다크';

  @override
  String get languageSystem => '시스템';

  @override
  String get languageKorean => '한국어';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageChinese => '中文';

  @override
  String get languageLatin => '라틴어';

  @override
  String get version => '버전';

  @override
  String get sectionPractice => '연습';

  @override
  String get sectionLibraryStage => '라이브러리 · 공연';

  @override
  String get sectionApp => '앱';

  @override
  String get tapTempo => '탭 템포';

  @override
  String get tempoTrainer => '템포 트레이너';

  @override
  String get cloudScores => '클라우드 악보';

  @override
  String get webDavTechnical => 'WebDAV';

  @override
  String get countIn => '카운트인';

  @override
  String get syncAnchor => '오디오 앵커';

  @override
  String get followConductor => '지휘자 따라가기';

  @override
  String get returnToLive => '실시간으로 돌아가기';

  @override
  String get autoPaused => '자동 일시정지';

  @override
  String get followOff => '따라가기 끔';

  @override
  String get followOn => '따라가기 켜짐';

  @override
  String get progressFollow => '따라가기';

  @override
  String get progressPage => '페이지';

  @override
  String get resumeLive => '실시간 재생';

  @override
  String get progressFollowHint => '오디오·합주에 맞춰 마디를 따라갑니다';

  @override
  String get progressPageHint => '페이지 단위로만 넘깁니다';

  @override
  String get autoPausedHint => '수동으로 이동함 · 탭하면 실시간으로 돌아갑니다';

  @override
  String get roleConductor => '지휘자';

  @override
  String get roleMembers => '멤버';

  @override
  String get jamPart => '파트';

  @override
  String get jamPartVocal => '보컬';

  @override
  String get jamPartGuitar => '기타';

  @override
  String get jamPartBass => '베이스';

  @override
  String get jamPartDrums => '드럼';

  @override
  String get jamPartKeyboard => '키보드';

  @override
  String get jamPartOther => '그 외';

  @override
  String get jamPartOtherHint => '파트를 직접 입력';

  @override
  String get enterOtherPart => '파트를 입력하세요';

  @override
  String get emptyLibraryTitle => '아직 악보가 없어요';

  @override
  String get emptyLibraryBody => 'PDF를 가져오면\n바로 연습할 수 있어요';

  @override
  String get emptyRecentTitle => '최근 연 악보가 없어요';

  @override
  String get emptySetlistsTitle => '세트리스트가 없어요';

  @override
  String get emptySetlistsBody => '공연·연습 순서를 만들어 두면\n무대에서 바로 넘길 수 있어요';

  @override
  String get emptyJamSongs => '아직 곡이 없어요';

  @override
  String get emptyJamMembers => '아직 멤버가 없어요';

  @override
  String get loadFailed => '불러오지 못했어요. 다시 시도해 주세요.';

  @override
  String get pickFailed => '파일을 선택하지 못했어요';

  @override
  String get saveFailed => '저장하지 못했어요';

  @override
  String get downloadNeeded => '먼저 악보를 다운로드해 주세요';

  @override
  String get offlineMissing => '오프라인 파일 없음';

  @override
  String get metronome => '메트로놈';

  @override
  String get metronomeSubtitle => '박자표 · 악센트';

  @override
  String get metronomeSubtitleFull => '박자표 · 악센트 · 카운트인';

  @override
  String get openScore => '악보 열기';

  @override
  String get practiceDeck => '빠른 연습';

  @override
  String get recentScores => '최근 악보';

  @override
  String get seeAll => '모두 보기';

  @override
  String get weekPractice => '이번 주 연습';

  @override
  String get weekPracticeHint => '악보를 열면 연습 시간이 자동으로 쌓여요';

  @override
  String get statSessions => '세션';

  @override
  String get statTime => '시간';

  @override
  String get statAverage => '평균';

  @override
  String sessionCountLabel(int count) {
    return '$count회';
  }

  @override
  String get loadingEllipsis => '불러오는 중…';

  @override
  String get loading => '불러오는 중';

  @override
  String get importHintHome => 'PDF를 가져와 연습을 시작하세요';

  @override
  String get continuePractice => '이어서 연습';

  @override
  String get greetingMorning => '좋은 아침';

  @override
  String get greetingAfternoon => '좋은 오후';

  @override
  String get greetingEvening => '좋은 저녁';

  @override
  String get relativeJustNow => '방금';

  @override
  String relativeMinutesAgo(int minutes) {
    return '$minutes분 전';
  }

  @override
  String relativeHoursAgo(int hours) {
    return '$hours시간 전';
  }

  @override
  String relativeDaysAgo(int days) {
    return '$days일 전';
  }

  @override
  String relativeMonthDay(int month, int day) {
    return '$month월 $day일';
  }

  @override
  String durationSeconds(int seconds) {
    return '$seconds초';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes분';
  }

  @override
  String durationHours(int hours) {
    return '$hours시간';
  }

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours시간 $minutes분';
  }

  @override
  String get filterAll => '전체';

  @override
  String get filterPdf => 'PDF';

  @override
  String get filterSmartScore => '전자악보';

  @override
  String get filterNativeScore => 'MusicXML';

  @override
  String get filterDifficult => '어려운';

  @override
  String get filterFavorites => '즐겨찾기';

  @override
  String get filterRecent => '최근';

  @override
  String get library => '라이브러리';

  @override
  String get folders => '폴더';

  @override
  String get allScores => '모든 악보';

  @override
  String get folder => '폴더';

  @override
  String get unfiled => '미분류';

  @override
  String get manageFolders => '폴더 관리';

  @override
  String get newFolder => '새 폴더';

  @override
  String get newSubfolder => '하위 폴더';

  @override
  String get folderParent => '상위 폴더';

  @override
  String folderDepthLimit(int max) {
    return '하위 폴더는 최대 $max단계까지예요';
  }

  @override
  String get editFolder => '폴더 편집';

  @override
  String get folderName => '폴더 이름';

  @override
  String get folderNameRequired => '폴더 이름을 입력하세요';

  @override
  String get folderColor => '폴더 색';

  @override
  String get deleteFolder => '폴더 삭제';

  @override
  String get deleteFolderBody =>
      '폴더만 삭제됩니다. 하위 폴더는 한 단계 위로 올라가고, 안의 악보는 미분류로 남아요.';

  @override
  String get labels => '라벨';

  @override
  String get addLabel => '라벨 추가';

  @override
  String get labelHint => '#태그';

  @override
  String get noFolder => '폴더 없음';

  @override
  String get import => '가져오기';

  @override
  String get importFrom => '가져올 위치';

  @override
  String get importFromDevice => '내 기기';

  @override
  String get importFromGoogleDrive => 'Google Drive';

  @override
  String get importFromOneDrive => 'OneDrive';

  @override
  String get importFromDropbox => 'Dropbox';

  @override
  String get importFromWebDav => 'WebDAV';

  @override
  String importCloudPickerHint(String provider) {
    return '파일 선택기에서 $provider를 연 뒤 PDF를 고르세요.';
  }

  @override
  String importCloudHowTitle(String provider) {
    return '$provider에서 고르기';
  }

  @override
  String importCloudHowBody(String provider) {
    return '이 앱 안에서 $provider 로그인은 아직 없어요.\n\n1. 기기에 $provider 앱을 설치하고 로그인\n2. 계속을 눌러 시스템 파일 선택기 열기\n3. 왼쪽 메뉴(☰)에서 $provider 선택\n4. PDF 고르기\n\n에뮬레이터에는 클라우드 앱이 없는 경우가 많아요. 실제 폰에서 해보세요.';
  }

  @override
  String get importCloudViaSystem => '시스템 파일에서 선택';

  @override
  String get importWebDavViaApp => '앱에서 로그인';

  @override
  String get continueAction => '계속';

  @override
  String get importPdf => 'PDF 가져오기';

  @override
  String get importMusicXml => 'MusicXML 가져오기';

  @override
  String get importing => '가져오는 중…';

  @override
  String get importFailed => '가져오기 실패';

  @override
  String get searchHint => '곡 · 아티스트 · BPM · 라벨';

  @override
  String get songTitle => '곡명';

  @override
  String get songTitleRequired => '곡명을 입력하세요';

  @override
  String get artist => '아티스트';

  @override
  String get more => '더보기';

  @override
  String get favorite => '즐겨찾기';

  @override
  String get unfavorite => '즐겨찾기 해제';

  @override
  String targetBpmShort(int target) {
    return '목표 $target';
  }

  @override
  String libraryCountFilter(int count, String filter) {
    return '$count곡 · $filter';
  }

  @override
  String get smartThumb => '전자';

  @override
  String get newSetlist => '새 세트리스트';

  @override
  String get create => '만들기';

  @override
  String get createScore => '악보 만들기';

  @override
  String get createFailed => '만들지 못했어요';

  @override
  String get createSetlist => '세트리스트 만들기';

  @override
  String get setlist => '세트리스트';

  @override
  String get name => '이름';

  @override
  String get save => '저장';

  @override
  String get cancel => '취소';

  @override
  String get delete => '삭제';

  @override
  String get remove => '제거';

  @override
  String get rename => '이름 바꾸기';

  @override
  String get confirmDelete => '삭제할까요?';

  @override
  String get addSongs => '곡 추가';

  @override
  String get noSongs => '곡이 없어요';

  @override
  String songAdded(String title) {
    return '$title을(를) 추가했어요';
  }

  @override
  String songCount(int count) {
    return '$count곡';
  }

  @override
  String get stage => '무대';

  @override
  String get startStage => '무대 시작';

  @override
  String get saveOffline => '오프라인 저장';

  @override
  String get downloadFailed => '다운로드에 실패했어요';

  @override
  String get downloadRequired => '다운로드가 필요해요';

  @override
  String savedSongs(int count) {
    return '$count곡 저장';
  }

  @override
  String savedSongsPartial(int saved, int failed) {
    return '$saved곡 저장 · $failed곡 실패';
  }

  @override
  String get changeFailed => '변경하지 못했어요';

  @override
  String get fetchFailed => '불러오지 못했어요';

  @override
  String get setlistPromptBody => '연습·공연 순서를 만들어 주세요';

  @override
  String get jam => '합주';

  @override
  String get jamTagline => '밴드처럼, 같은 악보 · 같은 박자';

  @override
  String get jamHubHint => '같은 Wi-Fi에서 세션을 만들고 코드나 QR로 초대하세요';

  @override
  String get activeJams => '진행 중인 합주';

  @override
  String get nearbyJams => '주변 방';

  @override
  String get findNearbyJams => '주변 방 찾기';

  @override
  String get noNearbyJams => '같은 Wi-Fi에서 방을 찾지 못했어요';

  @override
  String get createJam => '합주 만들기';

  @override
  String get jamName => '합주 이름';

  @override
  String get join => '참가';

  @override
  String get joinWithCode => '코드로 참가';

  @override
  String get code => '코드';

  @override
  String get tapToGoBack => '탭해서 돌아가기';

  @override
  String get inviteCode => '초대 코드';

  @override
  String get copy => '복사';

  @override
  String get move => '이동';

  @override
  String get moveToFolder => '폴더로 이동';

  @override
  String get copyToFolder => '폴더로 복사';

  @override
  String selectedCount(int count) {
    return '$count개 선택';
  }

  @override
  String get deleteSelectedBody => '선택한 악보를 삭제할까요? 이 작업은 되돌릴 수 없어요.';

  @override
  String get editSong => '악보 편집';

  @override
  String get codeCopied => '코드를 복사했어요';

  @override
  String get jamCode => '합주 코드';

  @override
  String get showQr => 'QR 코드 보기';

  @override
  String get scanQr => 'QR 스캔';

  @override
  String get clickTrack => '클릭 사운드';

  @override
  String get leave => '나가기';

  @override
  String get none => '없음';

  @override
  String get select => '선택';

  @override
  String get change => '바꾸기';

  @override
  String get previous => '이전';

  @override
  String get next => '다음';

  @override
  String get open => '열기';

  @override
  String get play => '재생';

  @override
  String get stop => '정지';

  @override
  String get pause => '일시정지';

  @override
  String get connected => '연결됨';

  @override
  String get disconnected => '연결 끊김';

  @override
  String get me => '나';

  @override
  String get setlistNotFound => '세트리스트를 찾을 수 없어요';

  @override
  String get noOpenableScore => '열 수 있는 악보가 없어요';

  @override
  String get jamSessionNotFound => '합주 세션을 찾을 수 없어요';

  @override
  String get jamNetworkUnavailable => 'Wi-Fi를 켠 뒤 다시 시도해 주세요';

  @override
  String get jamJoinTimedOut => '세션을 찾지 못했어요. 같은 Wi-Fi와 코드를 확인해 주세요';

  @override
  String get jamHostUnavailable => '호스트에 연결하지 못했어요. 호스트 앱과 Wi-Fi를 확인해 주세요';

  @override
  String get jamHostDisconnected => '호스트가 세션을 닫았거나 연결이 끊겼어요';

  @override
  String get jamBackToHub => '합주 목록으로';

  @override
  String get jamLobby => '합주 대기실';

  @override
  String get ready => '준비';

  @override
  String get readyDone => '준비 완료';

  @override
  String get waitingForReady => '참가자 준비 중…';

  @override
  String jamReadyCount(int ready, int total) {
    return '$ready/$total명 준비';
  }

  @override
  String get jamNotReady => '참가자가 준비될 때까지 기다려 주세요';

  @override
  String get toolsWifiSync => '같은 Wi-Fi 합주';

  @override
  String get toolsGraduallyFaster => '점점 빠르게';

  @override
  String get toolsTapForBpm => '탭으로 BPM 측정';

  @override
  String get start => '시작';

  @override
  String get preparing => '준비 중…';

  @override
  String get tapToStart => '탭해서 시작';

  @override
  String get audioError => '오디오 오류';

  @override
  String get bpmUp => 'BPM 올리기';

  @override
  String get bpmDown => 'BPM 낮추기';

  @override
  String get meter => '박자표';

  @override
  String get beatUnit => '박자 분할';

  @override
  String get accent => '악센트';

  @override
  String get double => '두 배';

  @override
  String get halve => '반 템포';

  @override
  String get reset => '초기화';

  @override
  String get tapInput => '박을 탭하세요';

  @override
  String get target => '목표';

  @override
  String get targetReached => '목표 도달';

  @override
  String get repetitions => '단계당 마디';

  @override
  String get repsDone => '반복 완료';

  @override
  String get checkSettings => '설정을 확인하세요';

  @override
  String get increase => '증가량';

  @override
  String trainerProgress(int current, int total, int beat) {
    return '$current/$total 마디 · $beat박';
  }

  @override
  String get trainerHint => '시작 템포에서 목표까지, 설정한 마디마다 자동으로 올라갑니다.';

  @override
  String trainerPlan(int start, int step, int bars, int target) {
    return '$start에서 시작해 $bars마디마다 +$step, $target까지';
  }

  @override
  String trainerNext(int bpm) {
    return '다음 $bpm BPM';
  }

  @override
  String trainerStageBars(int current, int total) {
    return '이번 단계 $current/$total 마디';
  }

  @override
  String get trainerIdleTitle => '템포를 올려 가며 익히기';

  @override
  String get close => '닫기';

  @override
  String get back => '뒤로';

  @override
  String get done => '완료';

  @override
  String get score => '악보';

  @override
  String get openFailed => '열지 못했어요';

  @override
  String get scoreSettings => '악보 설정';

  @override
  String get music => '음악';

  @override
  String get metroShort => '메트로';

  @override
  String get view => '보기';

  @override
  String get annotations => '주석';

  @override
  String get playback => '재생';

  @override
  String get attachMusic => '음악 연결';

  @override
  String get playing => '재생 중';

  @override
  String get pickFile => '파일 선택';

  @override
  String get playbackSpeed => '재생 속도';

  @override
  String get loopSection => '구간 반복';

  @override
  String get progress => '진행';

  @override
  String get pageLayout => '페이지 레이아웃';

  @override
  String get autoAdvance => '자동 진행';

  @override
  String get returnToCurrent => '현재 위치로 복귀';

  @override
  String get currentMeasure => '현재 마디';

  @override
  String get notSelected => '선택 안 함';

  @override
  String get nextSong => '다음 곡';

  @override
  String get practiceSync => '연습 · 동기화';

  @override
  String anchorsCount(int count) {
    return '$count개';
  }

  @override
  String get pedal => '페달';

  @override
  String get practiceLog => '연습 기록';

  @override
  String get hardMeasures => '어려운 마디';

  @override
  String get display => '표시';

  @override
  String get showAnnotations => '주석 표시';

  @override
  String get clearAnnotations => '주석 지우기';

  @override
  String get statusBar => '상태 표시줄';

  @override
  String get layoutAuto => '자동 · 가로 2쪽 / 세로 스크롤';

  @override
  String get layoutFit => '맞춤';

  @override
  String get layoutTwoUp => '2쪽';

  @override
  String get layoutScroll => '스크롤';

  @override
  String get off => '꺼짐';

  @override
  String get wakeLockFailed => '화면 유지에 실패했어요';

  @override
  String get metronomeError => '메트로놈 오류';

  @override
  String get haptics => '진동';

  @override
  String get openInMetronome => '메트로놈에서 열기';

  @override
  String get metronomeStop => '메트로놈 정지';

  @override
  String get audioConnect => '오디오 연결';

  @override
  String get anchorLinkHint => '음악 위치와 마디 시작을 연결합니다.';

  @override
  String get measure => '마디';

  @override
  String get audioSeconds => '오디오(초)';

  @override
  String get currentPosition => '현재 위치';

  @override
  String get checkTime => '시간을 확인하세요';

  @override
  String get deleteAnchorHere => '이 마디 앵커 삭제';

  @override
  String get needTwoAnchors => '먼저 앵커를 두 개 이상 저장하세요';

  @override
  String get needTwoSectionAnchors => '섹션 앵커가 2개 필요해요';

  @override
  String get loopRangeHint => '마디·섹션 앵커 사이를 반복합니다.';

  @override
  String get loopRange => '반복 범위';

  @override
  String get measureRange => '마디 범위';

  @override
  String get startMeasure => '시작 마디';

  @override
  String get endMeasure => '끝 마디';

  @override
  String get startLoop => '반복 시작';

  @override
  String get clearLoop => '반복 해제';

  @override
  String get label => '표시';

  @override
  String get enterLabel => '표시를 입력하세요';

  @override
  String get endRecording => '기록 종료';

  @override
  String get startPractice => '연습 시작';

  @override
  String get targetBpm => '목표 BPM';

  @override
  String get optional => '선택';

  @override
  String get targetBpmAboveCurrent => '목표 BPM은 현재 BPM 이상이어야 해요';

  @override
  String get checkStartTargetBpm => '시작·목표 BPM을 확인하세요';

  @override
  String get recent => '최근';

  @override
  String get targetAchieved => '목표 달성';

  @override
  String targetBpmValue(int target) {
    return '목표 $target BPM';
  }

  @override
  String targetRemaining(int delta) {
    return '목표까지 $delta BPM';
  }

  @override
  String maxBpmLabel(int bpm, String target) {
    return '최고 $bpm BPM$target';
  }

  @override
  String practiceInProgress(int bpm, String date) {
    return '진행 중 · $bpm BPM · $date';
  }

  @override
  String inProgressLabel(String target) {
    return '진행 중$target';
  }

  @override
  String noneWithTarget(String target) {
    return '없음$target';
  }

  @override
  String sessionsWithTarget(int count, String target) {
    return '$count회$target';
  }

  @override
  String targetSuffix(int bpm) {
    return ' · 목표 $bpm BPM';
  }

  @override
  String get progressMode => '진행 방식';

  @override
  String get pressKey => '키를 누르세요';

  @override
  String get defaults => '기본값';

  @override
  String get left => '왼쪽';

  @override
  String get right => '오른쪽';

  @override
  String get loop => '반복';

  @override
  String meterConfigured(String label) {
    return '$label · 설정';
  }

  @override
  String get timeSignature => '박자표';

  @override
  String get numerator => '분자';

  @override
  String get denominator => '분모';

  @override
  String get startBpm => '시작 BPM';

  @override
  String get endBpm => '끝 BPM';

  @override
  String get checkInput => '입력을 확인하세요';

  @override
  String get bpmRangeError => 'BPM은 40~240이어야 합니다';

  @override
  String get reimportPdf => 'PDF를 다시 가져오세요.';

  @override
  String get editMeasures => '마디 편집';

  @override
  String get dragAddMeasure => '드래그해서 마디 추가';

  @override
  String get deleteMeasure => '마디 삭제';

  @override
  String get pageNav => '페이지 이동';

  @override
  String get prevPage => '이전 페이지';

  @override
  String get nextPage => '다음 페이지';

  @override
  String loopMeasures(int start, int end) {
    return '$start–$end 마디';
  }

  @override
  String measureBeat(int measure, int beat) {
    return '$measure마디 $beat박';
  }

  @override
  String practiceStatsLine(int count, String duration, int bpm) {
    return '$count회 · 총 $duration · 평균 $bpm BPM';
  }

  @override
  String minutesSeconds(int minutes, int seconds) {
    return '$minutes분 $seconds초';
  }

  @override
  String get songInfo => '곡 정보';

  @override
  String get memo => '메모';

  @override
  String get audio => '오디오';

  @override
  String get connect => '연결';

  @override
  String get saving => '저장 중…';

  @override
  String get audioAttachFailed => '오디오를 연결하지 못했어요';

  @override
  String get importPdfScore => 'PDF 악보 가져오기';

  @override
  String get cloudSyncHint => '클라우드 악보를 동기화할 수 있어요';

  @override
  String get serverAddress => '서버 주소';

  @override
  String get username => '사용자 이름';

  @override
  String get password => '비밀번호';

  @override
  String get enterServerInfo => '서버 정보를 입력하고 연결하세요';

  @override
  String get reconnect => '다시 연결';

  @override
  String get disconnect => '연결 해제';

  @override
  String get notConnected => '연결 안 됨';

  @override
  String get connectedStatus => '연결됨';

  @override
  String get checking => '확인 중…';

  @override
  String get browseFiles => '파일 보기';

  @override
  String get checkUrl => '주소를 확인하세요.';

  @override
  String get cantSaveSettings => '설정을 저장할 수 없어요.';

  @override
  String get cantDisconnect => '연결을 해제할 수 없어요.';

  @override
  String get cantReadSettings => '저장된 설정을 읽을 수 없어요.';

  @override
  String get webdavFiles => 'WebDAV 파일';

  @override
  String get webdavNeeded => 'WebDAV 연결이 필요해요.';

  @override
  String get cloudOAuthSetupTitle => '클라우드 로그인 미설정';

  @override
  String get cloudOAuthNotConfigured =>
      'DROPBOX_CLIENT_ID를 --dart-define으로 넣고 다시 빌드하세요. Google Drive는 앱의 Google 로그인 설정을 사용합니다.';

  @override
  String get cloudDisconnect => '연결 해제';

  @override
  String get retry => '다시 시도';

  @override
  String get root => '루트';

  @override
  String get parentFolder => '상위 폴더';

  @override
  String get emptyFolder => '이 폴더에 파일이 없어요';

  @override
  String get addFailed => '추가하지 못했어요';

  @override
  String get cantSaveSync => '동기화 상태를 저장할 수 없어요.';

  @override
  String get accentStrong => '강박';

  @override
  String get accentNormal => '보통';

  @override
  String get accentMute => '묵음';

  @override
  String barsLabel(int count) {
    return '$count마디';
  }

  @override
  String get strokeThin => '가늘게';

  @override
  String get strokeMedium => '보통';

  @override
  String get strokeThick => '굵게';

  @override
  String get strokeHighlight => '형광펜';

  @override
  String get strokeEraser => '지우개';

  @override
  String get color => '색';

  @override
  String get undo => '실행 취소';

  @override
  String get clearAll => '전체 지우기';

  @override
  String get syncSynced => '동기화됨';

  @override
  String get syncCloud => '클라우드';

  @override
  String get syncOffline => '오프라인';

  @override
  String get syncUpdate => '업데이트';

  @override
  String get syncMissing => '서버에 없음';

  @override
  String get cameraMissing => '카메라 없음';

  @override
  String get key => '키';

  @override
  String get device => '기기';

  @override
  String get filePicker => '파일 선택기';

  @override
  String get noPdf => 'PDF 없음';

  @override
  String get emptyPdf => '빈 PDF예요. 다시 가져오세요.';

  @override
  String get noScore => '악보 없음';

  @override
  String stageMeasure(int measure) {
    return '$measure마디';
  }

  @override
  String stageNextSection(String section, int count) {
    return '다음 $section · $count마디 후';
  }

  @override
  String stageNextSong(String title) {
    return '다음 · $title';
  }

  @override
  String get nameRequired => '이름이 필요해요';

  @override
  String get enterName => '이름을 입력하세요.';

  @override
  String get endSession => '끝내기';

  @override
  String get session => '세션';

  @override
  String get participants => '참가자';

  @override
  String get song => '곡';

  @override
  String get notify => '알림';

  @override
  String get onboardingSkip => '건너뛰기';

  @override
  String get onboardingNext => '다음';

  @override
  String get onboardingStart => '연습 시작';

  @override
  String get onboardTitle1 => '악보는 손안에';

  @override
  String get onboardBody1 => 'PDF를 가져와 무대에서도 쓸 수 있는 뷰어로 연습하세요.';

  @override
  String get onboardTitle2 => '박에 맞춰';

  @override
  String get onboardBody2 => '메트로놈·탭 템포·트레이너·오디오 따라가기로 템포감을 잡으세요.';

  @override
  String get onboardTitle3 => '같이 치기';

  @override
  String get onboardBody3 => '세트리스트를 만들고 같은 Wi-Fi에서 합주 — 같은 악보, 같은 박자.';

  @override
  String get sectionLegal => '약관 · 지원';

  @override
  String get privacyPolicy => '개인정보 처리방침';

  @override
  String get termsOfUse => '이용약관';

  @override
  String get contactSupport => '문의하기';

  @override
  String get openSourceLicenses => '오픈소스 라이선스';

  @override
  String get replayOnboarding => '환영 화면 다시 보기';

  @override
  String get couldNotOpenMail => '메일 앱을 열 수 없어요';

  @override
  String get privacyBody =>
      'Page-a-Diddle은 악보, 세트리스트, 연습 기록, 설정을 이 기기에 저장합니다.\n\n선택 기능(클라우드 WebDAV 동기화, 같은 Wi-Fi 합주)은 사용자가 지정한 서버·기기로만 데이터를 보냅니다. 악보를 수집하는 Page-a-Diddle 계정 서버는 운영하지 않습니다.\n\n카메라는 합주 QR 스캔에만, 로컬 네트워크는 합주에만 사용합니다.\n\n가져온 파일과 앱 데이터는 앱 삭제 또는 저장공간 삭제로 제거할 수 있습니다.\n\n문의: support@page-a-diddle.app\n\n본문은 제품 안내용 요약입니다. 스토어 출시 전 필요 시 법률 검토를 받으세요.';

  @override
  String get termsBody =>
      'Page-a-Diddle을 사용하면 합법적 개인·전문 음악 연습 목적에 앱을 쓰는 데 동의합니다.\n\n가져온 악보·오디오·파일의 권리는 사용자 책임입니다. 사용 권한이 없는 자료를 가져오지 마세요.\n\n앱은 중단 없는 동작을 보장하지 않으며 있는 그대로 제공됩니다. 연습·무대 사용의 책임은 사용자에게 있습니다.\n\n합주·WebDAV는 사용자 네트워크와 직접 설정한 외부 서버에 의존합니다.\n\n약관은 앱 업데이트와 함께 변경될 수 있으며, 업데이트 후 계속 사용하면 변경에 동의한 것으로 봅니다.\n\n문의: support@page-a-diddle.app';

  @override
  String get homeTipTitle => '오늘의 연습';

  @override
  String get homeTipBody => '악보를 열고, 템포를 잡고, 어려운 마디를 반복하세요.';

  @override
  String get retryAction => '다시 시도';

  @override
  String get hardBadge => '어려움';

  @override
  String get viewerControlsHint => '위를 탭하면 컨트롤이 나타나요';

  @override
  String get cue => '큐';

  @override
  String get sectionLabel => '섹션';

  @override
  String get tempoMap => '템포 맵';

  @override
  String get tempoStep => '스텝';

  @override
  String get tempoGradual => '점진';

  @override
  String get tempo => '템포';

  @override
  String get bpmHintRange => '40~240';

  @override
  String get nowLabel => '지금';

  @override
  String get sectionIntro => '인트로';

  @override
  String get sectionVerse => '벌스';

  @override
  String get sectionPre => '프리코러스';

  @override
  String get sectionChorus => '코러스';

  @override
  String get sectionBridge => '브리지';

  @override
  String get sectionOutro => '아웃트로';

  @override
  String get exportAnnotatedPdf => '주석 포함 PDF 내보내기';

  @override
  String get exportAnnotatedPdfSubtitle => '원본은 그대로 두고 새 PDF로 저장';

  @override
  String get exportingAnnotatedPdf => '주석을 PDF에 합치는 중…';

  @override
  String get annotatedPdfExported => '주석 포함 PDF를 저장했어요';

  @override
  String get annotatedPdfExportFailed => 'PDF를 내보내지 못했어요';

  @override
  String get scoreEdit => '악보 편집';

  @override
  String get note => '음표';

  @override
  String get rest => '쉼표';

  @override
  String get chordSymbol => '코드';

  @override
  String get addNote => '음표 추가';

  @override
  String get addRest => '쉼표 추가';

  @override
  String get addChordSymbol => '코드 추가';

  @override
  String get editSelected => '선택 항목 수정';

  @override
  String get deleteSelectedEvent => '선택 항목 삭제';

  @override
  String get measureSettings => '마디 설정';

  @override
  String get insertMeasureAfter => '다음 마디 추가';

  @override
  String get redo => '다시 실행';

  @override
  String get pitch => '음높이';

  @override
  String get octave => '옥타브';

  @override
  String get noteValue => '음가';

  @override
  String get staff => '보표';

  @override
  String get voice => '성부';

  @override
  String get position => '위치';

  @override
  String get keySignature => '조표';

  @override
  String get sourceKey => '원곡';

  @override
  String get part => '파트';

  @override
  String get selectScoreEvent => '오선을 누르세요';

  @override
  String get unsavedChangesTitle => '저장하지 않은 악보';

  @override
  String get unsavedChangesBody => '나가기 전에 수정한 악보를 저장할까요?';

  @override
  String get discardChanges => '버리기';

  @override
  String get scoreSaved => '악보를 저장했어요';

  @override
  String get scoreSection => '구간';

  @override
  String get playbackSequence => '연주 순서';

  @override
  String get playbackSequenceHelp =>
      '오선에서 마디를 누르고 벌스·코러스를 붙입니다. 아래에서 그 구간을 몇 번 반복할지 정합니다.';

  @override
  String get moveMeasureEarlier => '마디 앞으로';

  @override
  String get moveMeasureLater => '마디 뒤로';

  @override
  String get noSections => '먼저 이 마디에 구간을 붙이세요';

  @override
  String get noHarmony => '코드 없음';

  @override
  String get repeatDown => '횟수 줄이기';

  @override
  String get repeatUp => '횟수 늘리기';

  @override
  String get scoreTranspose => '조옮김';

  @override
  String get semitone => '반음';

  @override
  String get semitoneDown => '반음 내리기';

  @override
  String get semitoneUp => '반음 올리기';

  @override
  String get scoreArrangement => '반주';

  @override
  String get arrangementOff => '끔';

  @override
  String get arrangementBlock => '코드';

  @override
  String get arrangementPulse => '박마다';

  @override
  String get arrangementBroken => '하나씩';

  @override
  String get scoreProject => '프로젝트';

  @override
  String get scoreTools => '도구';

  @override
  String get playFailed => '재생할 수 없습니다';
}
