// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Page-a-Diddle';

  @override
  String get tagline => 'Drum chart practice';

  @override
  String get tabHome => 'Home';

  @override
  String get tabLibrary => 'Library';

  @override
  String get tabSetlists => 'Setlists';

  @override
  String get tabTools => 'Tools';

  @override
  String get tabJam => 'Jam';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get languageSystem => 'System';

  @override
  String get languageKorean => '한국어';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageChinese => '中文';

  @override
  String get languageLatin => 'Latina';

  @override
  String get version => 'Version';

  @override
  String get sectionPractice => 'Practice';

  @override
  String get sectionLibraryStage => 'Library & stage';

  @override
  String get sectionApp => 'App';

  @override
  String get tapTempo => 'Tap tempo';

  @override
  String get tempoTrainer => 'Tempo trainer';

  @override
  String get cloudScores => 'Cloud scores';

  @override
  String get webDavTechnical => 'WebDAV';

  @override
  String get countIn => 'Count-in';

  @override
  String get syncAnchor => 'Audio anchor';

  @override
  String get followConductor => 'Follow conductor';

  @override
  String get returnToLive => 'Return to live';

  @override
  String get autoPaused => 'Auto-paused';

  @override
  String get followOff => 'Follow off';

  @override
  String get followOn => 'Following';

  @override
  String get progressFollow => 'Follow';

  @override
  String get progressPage => 'Page';

  @override
  String get resumeLive => 'Resume live';

  @override
  String get progressFollowHint => 'Follows measures with audio & jam';

  @override
  String get progressPageHint => 'Turns pages only';

  @override
  String get autoPausedHint => 'Moved manually · tap for live';

  @override
  String get roleConductor => 'Conductor';

  @override
  String get roleMembers => 'Members';

  @override
  String get jamPart => 'Your part';

  @override
  String get jamPartVocal => 'Vocals';

  @override
  String get jamPartGuitar => 'Guitar';

  @override
  String get jamPartBass => 'Bass';

  @override
  String get jamPartDrums => 'Drums';

  @override
  String get jamPartKeyboard => 'Keyboard';

  @override
  String get jamPartOther => 'Other';

  @override
  String get jamPartOtherHint => 'Enter your part';

  @override
  String get enterOtherPart => 'Enter a part';

  @override
  String get emptyLibraryTitle => 'No scores yet';

  @override
  String get emptyLibraryBody => 'Import a PDF\nto start practicing';

  @override
  String get noMatchingScoresTitle => 'No scores found';

  @override
  String get noMatchingScoresBody => 'Try another word\nor another filter';

  @override
  String get emptyLibraryBodyPiano =>
      'Bring in a photo or PDF\nand turn it into a score you can play';

  @override
  String copyTitle(String title) {
    return '$title copy';
  }

  @override
  String get renameScoreVersion => 'Rename version';

  @override
  String get arrangementHint =>
      'Heard only while playing. To keep it as notes, use \"Make an instrument score\".';

  @override
  String get emptyRecentTitle => 'No recent scores';

  @override
  String get emptySetlistsTitle => 'No setlists';

  @override
  String get emptySetlistsBody =>
      'Build a practice or stage order\nto flip through live';

  @override
  String get emptyJamSongs => 'No songs yet';

  @override
  String get emptyJamMembers => 'No members yet';

  @override
  String get loadFailed => 'Couldn\'t load. Please try again.';

  @override
  String get pickFailed => 'Couldn\'t pick a file';

  @override
  String get saveFailed => 'Couldn\'t save';

  @override
  String get downloadNeeded => 'Download the score first';

  @override
  String get offlineMissing => 'Not offline';

  @override
  String get metronome => 'Metronome';

  @override
  String get metronomeSubtitle => 'Time signature · accents';

  @override
  String get metronomeSubtitleFull => 'Time signature · accents · count-in';

  @override
  String get openScore => 'Open score';

  @override
  String get practiceDeck => 'Quick practice';

  @override
  String get recentScores => 'Recent scores';

  @override
  String get seeAll => 'All';

  @override
  String get weekPractice => 'This week\'s practice';

  @override
  String get weekPracticeHint => 'Opening a score tracks practice time';

  @override
  String get statSessions => 'Sessions';

  @override
  String get statTime => 'Time';

  @override
  String get statAverage => 'Avg';

  @override
  String sessionCountLabel(int count) {
    return '$count×';
  }

  @override
  String get loadingEllipsis => 'Loading…';

  @override
  String get loading => 'Loading';

  @override
  String get importHintHome => 'Import a PDF to start practicing';

  @override
  String get continuePractice => 'Continue practicing';

  @override
  String get greetingMorning => 'Good morning';

  @override
  String get greetingAfternoon => 'Good afternoon';

  @override
  String get greetingEvening => 'Good evening';

  @override
  String get relativeJustNow => 'Just now';

  @override
  String relativeMinutesAgo(int minutes) {
    return '${minutes}m ago';
  }

  @override
  String relativeHoursAgo(int hours) {
    return '${hours}h ago';
  }

  @override
  String relativeDaysAgo(int days) {
    return '${days}d ago';
  }

  @override
  String relativeMonthDay(int month, int day) {
    return '$month/$day';
  }

  @override
  String durationSeconds(int seconds) {
    return '${seconds}s';
  }

  @override
  String durationMinutes(int minutes) {
    return '${minutes}m';
  }

  @override
  String durationHours(int hours) {
    return '${hours}h';
  }

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String get filterAll => 'All';

  @override
  String get filterPdf => 'PDF';

  @override
  String get filterSmartScore => 'Smart score';

  @override
  String get filterNativeScore => 'MusicXML';

  @override
  String get filterDifficult => 'Hard';

  @override
  String get filterFavorites => 'Favorites';

  @override
  String get filterRecent => 'Recent';

  @override
  String get library => 'Library';

  @override
  String get folders => 'Folders';

  @override
  String get allScores => 'All scores';

  @override
  String get folder => 'Folder';

  @override
  String get unfiled => 'Unfiled';

  @override
  String get manageFolders => 'Manage folders';

  @override
  String get newFolder => 'New folder';

  @override
  String get newSubfolder => 'New subfolder';

  @override
  String get folderParent => 'Parent folder';

  @override
  String folderDepthLimit(int max) {
    return 'Subfolders can be nested up to $max levels';
  }

  @override
  String get editFolder => 'Edit folder';

  @override
  String get folderName => 'Folder name';

  @override
  String get folderNameRequired => 'Enter a folder name';

  @override
  String get folderColor => 'Folder color';

  @override
  String get deleteFolder => 'Delete folder';

  @override
  String get deleteFolderBody =>
      'Only this folder is removed. Subfolders move up one level, and scores become unfiled.';

  @override
  String get labels => 'Labels';

  @override
  String get addLabel => 'Add label';

  @override
  String get labelHint => '#tag';

  @override
  String get noFolder => 'No folder';

  @override
  String get import => 'Import';

  @override
  String get importFrom => 'Import from';

  @override
  String get importFromDevice => 'This device';

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
    return 'In the file picker, open $provider and choose a PDF.';
  }

  @override
  String importCloudHowTitle(String provider) {
    return 'Pick from $provider';
  }

  @override
  String importCloudHowBody(String provider) {
    return 'This app doesn’t sign into $provider itself.\n\n1. Install the $provider app and sign in on this device\n2. Tap Continue to open the system file picker\n3. Open the side menu (☰) and choose $provider\n4. Select a PDF\n\nEmulators often have no cloud apps — try a real phone.';
  }

  @override
  String get importCloudViaSystem => 'Via system files';

  @override
  String get importWebDavViaApp => 'Sign in in this app';

  @override
  String get continueAction => 'Continue';

  @override
  String get importPdf => 'Import PDF';

  @override
  String get importMusicXml => 'Import MusicXML';

  @override
  String get convertToDigitalScore => 'Convert to digital score';

  @override
  String get omrProfileStandard => 'Standard score';

  @override
  String get omrProfileChordsLyrics => 'Score with chords and lyrics';

  @override
  String get convertingScore => 'Converting…';

  @override
  String convertingScorePercent(int percent) {
    return 'Converting $percent%';
  }

  @override
  String get convertFailed => 'Couldn\'t convert. Start the VM and try again.';

  @override
  String get omrReview => 'Conversion review';

  @override
  String omrHealthScore(int score) {
    return 'Structure score $score';
  }

  @override
  String get omrReviewEmpty => 'No structural problems found.';

  @override
  String get omrAiRun => 'Run AI review';

  @override
  String get omrAiNeedKey =>
      'Paste an XAI_API_KEY to review suspicious measures.';

  @override
  String get omrAiSaveKey => 'Save key';

  @override
  String get importing => 'Importing…';

  @override
  String get importFailed => 'Import failed';

  @override
  String get searchHint => 'Song · artist · BPM · label';

  @override
  String get songTitle => 'Title';

  @override
  String get songTitleRequired => 'Title required';

  @override
  String get artist => 'Artist';

  @override
  String get more => 'More';

  @override
  String get favorite => 'Favorite';

  @override
  String get unfavorite => 'Remove favorite';

  @override
  String targetBpmShort(int target) {
    return 'Target $target';
  }

  @override
  String libraryCountFilter(int count, String filter) {
    return '$count songs · $filter';
  }

  @override
  String get smartThumb => 'Smart';

  @override
  String get newSetlist => 'New setlist';

  @override
  String get create => 'Create';

  @override
  String get createScore => 'Create score';

  @override
  String get createFailed => 'Couldn\'t create';

  @override
  String get createSetlist => 'Create setlist';

  @override
  String get setlist => 'Setlist';

  @override
  String get name => 'Name';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get remove => 'Remove';

  @override
  String get rename => 'Rename';

  @override
  String get confirmDelete => 'Delete?';

  @override
  String get addSongs => 'Add songs';

  @override
  String get noSongs => 'No songs';

  @override
  String convertDone(String title) {
    return '$title converted';
  }

  @override
  String get sortRecent => 'Recent';

  @override
  String get sortTitle => 'Title';

  @override
  String get playbackTempo => 'Playback speed';

  @override
  String get pianoTagline => 'Photos and PDFs to digital scores';

  @override
  String get privacyBodyPiano =>
      'Worship Easy Peasy keeps your scores, versions and settings on this device. There is no account, and no name or contact is collected.\n\nWhen you convert a score, the photo or PDF you pick is sent to the conversion server (HTTPS). To read and check the score, the server sends parts of the score image to an AI service (Google Gemini). Uploaded files and results are deleted from the server six hours after the conversion ends.\n\nWhen you ask for an AI suggestion, a summary of the chords and sections is sent to the same server and AI service.\n\nTo count daily use, a random identifier made when the app is installed is registered with the server. It is not used to identify a person.\n\nCloud storage (WebDAV, Google Drive, Dropbox) exchanges files only with the places you connect.\n\nNo advertising or analytics tools are used.\n\nContact: support@page-a-diddle.app';

  @override
  String get termsBodyPiano =>
      'By using Worship Easy Peasy you agree to use it for lawful personal or professional music practice.\n\nYou are responsible for the rights to the scores and files you import or convert. Do not import or convert material you may not use.\n\nConversion and AI corrections can be wrong. Check the result against the original before relying on it.\n\nThe app is provided as is, without a guarantee of uninterrupted operation.\n\nContact: support@page-a-diddle.app';

  @override
  String get convertHint => 'A photo or PDF of a score';

  @override
  String get scoreGuide => 'Screen guide';

  @override
  String get scoreGuideTitle => 'Screen guide';

  @override
  String get scoreGuideIntro =>
      'What the buttons above the score do. You can open this again from Screen guide in the tools menu.';

  @override
  String get scoreGuideVersionTitle => 'Version (the name beside the title)';

  @override
  String get scoreGuideVersionBody =>
      'Switch between the original and the scores you edited or transposed. The original always stays as it is.';

  @override
  String get scoreGuideOrderBody =>
      'Divide the score into sections such as Verse and Chorus and set the order to play them. You can make a new score in that order.';

  @override
  String get scoreGuideReviewBody =>
      'The number is how many bars the conversion was unsure of. Open it to compare with the original and take the suggestions you want.';

  @override
  String get scoreGuideProofreadBody =>
      'Fix wrong chords, lyrics and notes yourself. It is saved as a new version.';

  @override
  String get scoreGuidePlayBody =>
      'Listen to the score. Tap a bar to start there, and change the speed on the bar below.';

  @override
  String get scoreGuideToolsBody =>
      'Transpose, make instrument scores, export PDF or MusicXML, and song information are here.';

  @override
  String get scoreGuideDone => 'Got it';

  @override
  String get multiPhotoHint =>
      'For several pages, long-press the first photo and select them together. They become one score.';

  @override
  String get omrProfileTitle => 'What kind of score is it?';

  @override
  String get omrProfileStandardHint => 'Notes only (a piano score)';

  @override
  String get omrProfileChordsLyricsHint => 'With chord names and lyrics';

  @override
  String get omrPhotoTip => 'A straight, sharp page reads best.';

  @override
  String barNumbers(String bars) {
    return 'Bars $bars';
  }

  @override
  String get barMenu => 'Bar';

  @override
  String get barMenuTooltip => 'Edit bar';

  @override
  String get playBar => 'Play from here';

  @override
  String barTooShort(String beats) {
    return '$beats beats short of the time';
  }

  @override
  String barTooLong(String beats) {
    return '$beats beats over the time';
  }

  @override
  String get lyric => 'Lyric';

  @override
  String get lyricNextHint => 'Next key: on to the next note';

  @override
  String get barEdit => 'Edit';

  @override
  String get listen => 'Listen';

  @override
  String get erase => 'Erase';

  @override
  String get toolsNote => 'Note';

  @override
  String get toolsWords => 'Chord · Lyric';

  @override
  String get toolsLength => 'Length';

  @override
  String get toolsPitch => 'Pitch';

  @override
  String get proofreadNow => 'Now';

  @override
  String get proofreadPick => 'Tap a note to pick it';

  @override
  String songAdded(String title) {
    return '$title added';
  }

  @override
  String songCount(int count) {
    return '$count songs';
  }

  @override
  String get stage => 'Stage';

  @override
  String get startStage => 'Start stage';

  @override
  String get saveOffline => 'Save offline';

  @override
  String get downloadFailed => 'Download failed';

  @override
  String get downloadRequired => 'Download needed';

  @override
  String savedSongs(int count) {
    return '$count songs saved';
  }

  @override
  String savedSongsPartial(int saved, int failed) {
    return '$saved saved · $failed failed';
  }

  @override
  String get changeFailed => 'Couldn\'t update';

  @override
  String get fetchFailed => 'Couldn\'t load';

  @override
  String get setlistPromptBody => 'Build a practice or show order';

  @override
  String get jam => 'Jam';

  @override
  String get jamTagline => 'Same chart, same meter — like a band';

  @override
  String get jamHubHint =>
      'Create a session on the same Wi-Fi and invite with a code or QR';

  @override
  String get activeJams => 'Active jams';

  @override
  String get nearbyJams => 'Nearby rooms';

  @override
  String get findNearbyJams => 'Find nearby';

  @override
  String get noNearbyJams => 'No rooms found on this Wi-Fi';

  @override
  String get createJam => 'Create jam';

  @override
  String get jamName => 'Jam name';

  @override
  String get join => 'Join';

  @override
  String get joinWithCode => 'Join with code';

  @override
  String get code => 'Code';

  @override
  String get tapToGoBack => 'Tap to go back';

  @override
  String get inviteCode => 'Invite code';

  @override
  String get copy => 'Copy';

  @override
  String get move => 'Move';

  @override
  String get moveToFolder => 'Move to folder';

  @override
  String get copyToFolder => 'Copy to folder';

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String get deleteSelectedBody =>
      'Delete the selected scores? This can\'t be undone.';

  @override
  String get editSong => 'Edit song info';

  @override
  String get codeCopied => 'Code copied';

  @override
  String get jamCode => 'Jam code';

  @override
  String get showQr => 'Show QR';

  @override
  String get scanQr => 'Scan QR';

  @override
  String get clickTrack => 'Click sound';

  @override
  String get leave => 'Leave';

  @override
  String get none => 'None';

  @override
  String get select => 'Select';

  @override
  String get change => 'Change';

  @override
  String get previous => 'Previous';

  @override
  String get next => 'Next';

  @override
  String get open => 'Open';

  @override
  String get play => 'Play';

  @override
  String get stop => 'Stop';

  @override
  String get pause => 'Pause';

  @override
  String get connected => 'Connected';

  @override
  String get disconnected => 'Offline';

  @override
  String get me => 'Me';

  @override
  String get setlistNotFound => 'Setlist not found';

  @override
  String get noOpenableScore => 'No openable score';

  @override
  String get jamSessionNotFound => 'Jam session not found';

  @override
  String get jamNetworkUnavailable => 'Turn on Wi-Fi and try again';

  @override
  String get jamJoinTimedOut =>
      'Couldn\'t find the session. Check the Wi-Fi and code';

  @override
  String get jamHostUnavailable =>
      'Couldn\'t connect to the host. Check the host app and Wi-Fi';

  @override
  String get jamHostDisconnected =>
      'The host closed the session or the connection was lost';

  @override
  String get jamBackToHub => 'Back to Jam';

  @override
  String get jamLobby => 'Jam lobby';

  @override
  String get ready => 'Ready';

  @override
  String get readyDone => 'Ready';

  @override
  String get waitingForReady => 'Waiting for everyone…';

  @override
  String jamReadyCount(int ready, int total) {
    return '$ready/$total ready';
  }

  @override
  String get jamNotReady => 'Wait until everyone is ready';

  @override
  String get toolsWifiSync => 'Jam on Wi-Fi';

  @override
  String get toolsGraduallyFaster => 'Ramp up speed';

  @override
  String get toolsTapForBpm => 'Tap to find BPM';

  @override
  String get start => 'Start';

  @override
  String get preparing => 'Preparing';

  @override
  String get tapToStart => 'Tap to start';

  @override
  String get audioError => 'Audio error';

  @override
  String get bpmUp => 'Increase BPM';

  @override
  String get bpmDown => 'Decrease BPM';

  @override
  String get meter => 'Time signature';

  @override
  String get beatUnit => 'Subdivision';

  @override
  String get accent => 'Accent';

  @override
  String get double => 'Double';

  @override
  String get halve => 'Half tempo';

  @override
  String get reset => 'Reset';

  @override
  String get tapInput => 'Tap the beat';

  @override
  String get target => 'Target';

  @override
  String get targetReached => 'Target reached';

  @override
  String get repetitions => 'Bars / step';

  @override
  String get repsDone => 'Reps done';

  @override
  String get checkSettings => 'Check your settings';

  @override
  String get increase => 'Step';

  @override
  String trainerProgress(int current, int total, int beat) {
    return '$current/$total bars · beat $beat';
  }

  @override
  String get trainerHint =>
      'Tempo rises automatically every N bars until you hit the target.';

  @override
  String trainerPlan(int start, int step, int bars, int target) {
    return 'Start at $start, +$step every $bars bars, up to $target';
  }

  @override
  String trainerNext(int bpm) {
    return 'Next $bpm BPM';
  }

  @override
  String trainerStageBars(int current, int total) {
    return 'This stage $current/$total bars';
  }

  @override
  String get trainerIdleTitle => 'Climb the tempo';

  @override
  String get close => 'Close';

  @override
  String get back => 'Back';

  @override
  String get done => 'Done';

  @override
  String get score => 'Score';

  @override
  String get openFailed => 'Couldn\'t open';

  @override
  String get scoreSettings => 'Score settings';

  @override
  String get music => 'Music';

  @override
  String get metroShort => 'Metro';

  @override
  String get view => 'View';

  @override
  String get annotations => 'Notes';

  @override
  String get playback => 'Playback';

  @override
  String get attachMusic => 'Attach music';

  @override
  String get playing => 'Playing';

  @override
  String get pickFile => 'Choose file';

  @override
  String get playbackSpeed => 'Speed';

  @override
  String get loopSection => 'Loop';

  @override
  String get progress => 'Progress';

  @override
  String get pageLayout => 'Page layout';

  @override
  String get autoAdvance => 'Auto advance';

  @override
  String get returnToCurrent => 'Return to position';

  @override
  String get currentMeasure => 'Current measure';

  @override
  String get notSelected => 'Not selected';

  @override
  String get nextSong => 'Next song';

  @override
  String get practiceSync => 'Practice · sync';

  @override
  String anchorsCount(int count) {
    return '$count';
  }

  @override
  String get pedal => 'Pedal';

  @override
  String get practiceLog => 'Practice log';

  @override
  String get hardMeasures => 'Hard measures';

  @override
  String get display => 'Display';

  @override
  String get showAnnotations => 'Show notes';

  @override
  String get clearAnnotations => 'Clear notes';

  @override
  String get statusBar => 'Status bar';

  @override
  String get layoutAuto => 'Auto · 2-up landscape / scroll portrait';

  @override
  String get layoutFit => 'Fit';

  @override
  String get layoutTwoUp => '2-up';

  @override
  String get layoutScroll => 'Scroll';

  @override
  String get off => 'Off';

  @override
  String get wakeLockFailed => 'Couldn\'t keep screen on';

  @override
  String get metronomeError => 'Metronome error';

  @override
  String get haptics => 'Haptics';

  @override
  String get openInMetronome => 'Open in metronome';

  @override
  String get metronomeStop => 'Stop metronome';

  @override
  String get audioConnect => 'Attach audio';

  @override
  String get anchorLinkHint => 'Link music position to a measure start.';

  @override
  String get measure => 'Measure';

  @override
  String get audioSeconds => 'Audio seconds';

  @override
  String get currentPosition => 'Now';

  @override
  String get checkTime => 'Check the time';

  @override
  String get deleteAnchorHere => 'Delete anchor here';

  @override
  String get needTwoAnchors => 'Save at least two anchors first';

  @override
  String get needTwoSectionAnchors => 'Need 2 section anchors';

  @override
  String get loopRangeHint => 'Loops between measure/section anchors.';

  @override
  String get loopRange => 'Loop range';

  @override
  String get measureRange => 'Measure range';

  @override
  String get startMeasure => 'Start measure';

  @override
  String get endMeasure => 'End measure';

  @override
  String get startLoop => 'Start loop';

  @override
  String get clearLoop => 'Clear loop';

  @override
  String get label => 'Label';

  @override
  String get enterLabel => 'Enter a label';

  @override
  String get endRecording => 'End log';

  @override
  String get startPractice => 'Start practice';

  @override
  String get targetBpm => 'Target BPM';

  @override
  String get optional => 'Optional';

  @override
  String get targetBpmAboveCurrent => 'Target BPM must be ≥ current';

  @override
  String get checkStartTargetBpm => 'Check start & target BPM';

  @override
  String get recent => 'Recent';

  @override
  String get targetAchieved => 'Target hit';

  @override
  String targetBpmValue(int target) {
    return 'Target $target BPM';
  }

  @override
  String targetRemaining(int delta) {
    return '$delta BPM to target';
  }

  @override
  String maxBpmLabel(int bpm, String target) {
    return 'Best $bpm BPM$target';
  }

  @override
  String practiceInProgress(int bpm, String date) {
    return 'In progress · $bpm BPM · $date';
  }

  @override
  String inProgressLabel(String target) {
    return 'In progress$target';
  }

  @override
  String noneWithTarget(String target) {
    return 'None$target';
  }

  @override
  String sessionsWithTarget(int count, String target) {
    return '$count×$target';
  }

  @override
  String targetSuffix(int bpm) {
    return ' · target $bpm BPM';
  }

  @override
  String get progressMode => 'Advance mode';

  @override
  String get pressKey => 'Press a key';

  @override
  String get defaults => 'Defaults';

  @override
  String get left => 'Left';

  @override
  String get right => 'Right';

  @override
  String get loop => 'Loop';

  @override
  String meterConfigured(String label) {
    return '$label · settings';
  }

  @override
  String get timeSignature => 'Time signature';

  @override
  String get timeSignatureNotation => 'Notation';

  @override
  String get timeSignatureNumbers => 'Numbers';

  @override
  String get commonTime => 'Common time (C)';

  @override
  String get allaBreve => 'Alla breve (¢)';

  @override
  String get numerator => 'Numerator';

  @override
  String get denominator => 'Denominator';

  @override
  String get startBpm => 'Start BPM';

  @override
  String get endBpm => 'End BPM';

  @override
  String get checkInput => 'Check input';

  @override
  String get bpmRangeError => 'BPM must be 40–240';

  @override
  String get reimportPdf => 'Re-import the PDF.';

  @override
  String get editMeasures => 'Edit measures';

  @override
  String get dragAddMeasure => 'Drag to add a measure';

  @override
  String get deleteMeasure => 'Delete measure';

  @override
  String get pageNav => 'Go to page';

  @override
  String get prevPage => 'Previous page';

  @override
  String get nextPage => 'Next page';

  @override
  String loopMeasures(int start, int end) {
    return '$start–$end measures';
  }

  @override
  String measureBeat(int measure, int beat) {
    return 'm$measure beat $beat';
  }

  @override
  String practiceStatsLine(int count, String duration, int bpm) {
    return '$count× · total $duration · avg $bpm BPM';
  }

  @override
  String minutesSeconds(int minutes, int seconds) {
    return '${minutes}m ${seconds}s';
  }

  @override
  String get songInfo => 'Song info';

  @override
  String get memo => 'Notes';

  @override
  String get audio => 'Audio';

  @override
  String get connect => 'Connect';

  @override
  String get saving => 'Saving…';

  @override
  String get audioAttachFailed => 'Couldn\'t attach audio';

  @override
  String get importPdfScore => 'Import PDF score';

  @override
  String get cloudSyncHint => 'Sync cloud scores';

  @override
  String get serverAddress => 'Server URL';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get enterServerInfo => 'Enter server details and connect';

  @override
  String get reconnect => 'Reconnect';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get notConnected => 'Not connected';

  @override
  String get connectedStatus => 'Connected';

  @override
  String get checking => 'Checking…';

  @override
  String get browseFiles => 'Browse files';

  @override
  String get checkUrl => 'Check the URL';

  @override
  String get cantSaveSettings => 'Couldn\'t save settings.';

  @override
  String get cantDisconnect => 'Couldn\'t disconnect.';

  @override
  String get cantReadSettings => 'Couldn\'t read saved settings.';

  @override
  String get webdavFiles => 'WebDAV files';

  @override
  String get webdavNeeded => 'WebDAV connection required.';

  @override
  String get cloudOAuthSetupTitle => 'Cloud login not set up';

  @override
  String get cloudOAuthNotConfigured =>
      'Add DROPBOX_CLIENT_ID with --dart-define, then rebuild. Google Drive uses the app’s Google Sign-In setup.';

  @override
  String get cloudDisconnect => 'Disconnect';

  @override
  String get retry => 'Retry';

  @override
  String get root => 'Root';

  @override
  String get parentFolder => 'Up';

  @override
  String get emptyFolder => 'No files in this folder';

  @override
  String get addFailed => 'Couldn\'t add';

  @override
  String get cantSaveSync => 'Couldn\'t save sync status.';

  @override
  String get accentStrong => 'Strong';

  @override
  String get accentNormal => 'Normal';

  @override
  String get accentMute => 'Mute';

  @override
  String barsLabel(int count) {
    return '$count bars';
  }

  @override
  String get strokeThin => 'Thin';

  @override
  String get strokeMedium => 'Medium';

  @override
  String get strokeThick => 'Thick';

  @override
  String get strokeHighlight => 'Highlight';

  @override
  String get strokeEraser => 'Eraser';

  @override
  String get color => 'Color';

  @override
  String get undo => 'Undo';

  @override
  String get clearAll => 'Clear all';

  @override
  String get syncSynced => 'Synced';

  @override
  String get syncCloud => 'Cloud';

  @override
  String get syncOffline => 'Offline';

  @override
  String get syncUpdate => 'Update';

  @override
  String get syncMissing => 'Missing';

  @override
  String get cameraMissing => 'No camera';

  @override
  String get key => 'Key';

  @override
  String get device => 'Device';

  @override
  String get filePicker => 'File picker';

  @override
  String get noPdf => 'No PDF';

  @override
  String get emptyPdf => 'Empty PDF. Re-import it.';

  @override
  String get noScore => 'No score';

  @override
  String stageMeasure(int measure) {
    return 'm$measure';
  }

  @override
  String stageNextSection(String section, int count) {
    return 'Next $section · in $count measures';
  }

  @override
  String stageNextSong(String title) {
    return 'Next · $title';
  }

  @override
  String get nameRequired => 'Name required';

  @override
  String get enterName => 'Enter a name';

  @override
  String get endSession => 'End';

  @override
  String get session => 'Session';

  @override
  String get participants => 'Participants';

  @override
  String get song => 'Song';

  @override
  String get notify => 'Notice';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingStart => 'Start practicing';

  @override
  String get onboardTitle1 => 'Your charts. Your pocket.';

  @override
  String get onboardBody1 =>
      'Import a PDF and practice with a stage-ready viewer.';

  @override
  String get onboardTitle2 => 'Stay in time';

  @override
  String get onboardBody2 =>
      'Metronome, tap tempo, tempo trainer, and audio follow keep the pocket tight.';

  @override
  String get onboardTitle3 => 'Play together';

  @override
  String get onboardBody3 =>
      'Build setlists and jam on the same Wi-Fi — same chart, same meter.';

  @override
  String get sectionLegal => 'Legal & support';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsOfUse => 'Terms of Use';

  @override
  String get contactSupport => 'Contact support';

  @override
  String get openSourceLicenses => 'Open-source licenses';

  @override
  String get replayOnboarding => 'Show welcome again';

  @override
  String get couldNotOpenMail => 'Couldn\'t open mail app';

  @override
  String get privacyBody =>
      'Page-a-Diddle stores your scores, setlists, practice logs, and settings on this device.\n\nOptional features (cloud WebDAV sync and local-network jam) send data only to servers or devices you choose. We do not run a Page-a-Diddle account server that collects your charts.\n\nCamera access is used only to scan jam QR codes. Local network access is used only for jam sessions on your Wi-Fi.\n\nYou can delete imported files and app data by removing the app or clearing app storage.\n\nFor privacy questions: support@page-a-diddle.app\n\nThis summary is provided for product clarity. Have counsel review it before store publication if required in your region.';

  @override
  String get termsBody =>
      'By using Page-a-Diddle you agree to use the app for lawful personal or professional music practice.\n\nYou are responsible for the rights to any scores, audio, or files you import. Do not import material you are not allowed to use.\n\nThe app is provided as-is without warranties of uninterrupted performance. Practice and stage use remain your responsibility.\n\nJam and WebDAV features depend on your network and third-party servers you configure.\n\nWe may update these terms with app updates. Continued use after an update means you accept the revised terms.\n\nContact: support@page-a-diddle.app';

  @override
  String get homeTipTitle => 'Today\'s practice';

  @override
  String get homeTipBody =>
      'Open a chart, tap a tempo, then loop the hard bars.';

  @override
  String get retryAction => 'Try again';

  @override
  String get hardBadge => 'Hard';

  @override
  String get viewerControlsHint => 'Tap top for controls';

  @override
  String get cue => 'Cue';

  @override
  String get sectionLabel => 'Section';

  @override
  String get tempoMap => 'Tempo map';

  @override
  String get tempoStep => 'Step';

  @override
  String get tempoGradual => 'Gradual';

  @override
  String get tempo => 'Tempo';

  @override
  String get bpmHintRange => '40–240';

  @override
  String get nowLabel => 'Now';

  @override
  String get sectionIntro => 'Intro';

  @override
  String get sectionVerse => 'Verse';

  @override
  String get sectionPre => 'Pre-chorus';

  @override
  String get sectionChorus => 'Chorus';

  @override
  String get sectionBridge => 'Bridge';

  @override
  String get sectionOutro => 'Outro';

  @override
  String get exportAnnotatedPdf => 'Export annotated PDF';

  @override
  String get exportAnnotatedPdfSubtitle =>
      'Save a new PDF and keep the original unchanged';

  @override
  String get exportingAnnotatedPdf => 'Adding notes to the PDF…';

  @override
  String get annotatedPdfExported => 'Annotated PDF saved';

  @override
  String get annotatedPdfExportFailed => 'Couldn\'t export the PDF';

  @override
  String get scoreEdit => 'Edit score';

  @override
  String get scoreOriginal => 'Original';

  @override
  String get scorePerformance => 'Performance';

  @override
  String get addScoreVersion => 'Add version';

  @override
  String get scoreVersionName => 'Version name';

  @override
  String get deleteScoreVersion => 'Delete version';

  @override
  String scoreVersionN(int n) {
    return 'Version $n';
  }

  @override
  String get duplicateMeasure => 'Duplicate measure';

  @override
  String get dragMeasure => 'Move measure';

  @override
  String get note => 'Note';

  @override
  String get rest => 'Rest';

  @override
  String get chordSymbol => 'Chord';

  @override
  String get barTexts => 'Text in this bar';

  @override
  String get showOriginal => 'Show original';

  @override
  String get originalBar => 'Original of this bar';

  @override
  String get noOriginalBar => 'This bar is not on the original.';

  @override
  String get barTextsHint =>
      'Text read from the page that is not a chord, a lyric or a note. Correct or remove what was misread.';

  @override
  String get addNote => 'Add note';

  @override
  String get addRest => 'Add rest';

  @override
  String get addChordSymbol => 'Add chord';

  @override
  String get addChordTone => 'Chord tone';

  @override
  String get dottedDuration => 'Dotted';

  @override
  String get pitchUp => 'Semitone up';

  @override
  String get pitchDown => 'Semitone down';

  @override
  String get octaveUp => 'Octave up';

  @override
  String get octaveDown => 'Octave down';

  @override
  String get newPianoScore => 'New piano score';

  @override
  String get addMeasure => 'Add measure';

  @override
  String get zoomIn => 'Zoom in';

  @override
  String get zoomOut => 'Zoom out';

  @override
  String get editSelected => 'Edit selected';

  @override
  String get deleteSelectedEvent => 'Delete selected';

  @override
  String get measureSettings => 'Measure settings';

  @override
  String get insertMeasureAfter => 'Insert next measure';

  @override
  String get redo => 'Redo';

  @override
  String get pitch => 'Pitch';

  @override
  String get octave => 'Octave';

  @override
  String get noteValue => 'Note value';

  @override
  String get staff => 'Staff';

  @override
  String get voice => 'Voice';

  @override
  String get position => 'Position';

  @override
  String get keySignature => 'Key signature';

  @override
  String get sourceKey => 'Original';

  @override
  String get part => 'Part';

  @override
  String get selectScoreEvent => 'Tap the staff';

  @override
  String get unsavedChangesTitle => 'Unsaved score';

  @override
  String get unsavedChangesBody => 'Save your score edits before leaving?';

  @override
  String get discardChanges => 'Discard';

  @override
  String get scoreSaved => 'Score saved';

  @override
  String get scoreSection => 'Section';

  @override
  String get playbackSequence => 'Playback order';

  @override
  String get playbackSequenceHelp =>
      'Mark sections on measures, then set their order and repeats.';

  @override
  String get addToPlaybackSequence => 'Add to order';

  @override
  String get removeFromPlaybackSequence => 'Remove from playback order';

  @override
  String get moveMeasureEarlier => 'Move measure earlier';

  @override
  String get moveMeasureLater => 'Move measure later';

  @override
  String get moveSectionEarlier => 'Move section earlier';

  @override
  String get moveSectionLater => 'Move section later';

  @override
  String get noSections => 'Make sections first: tap a line under \"Sections\"';

  @override
  String get noHarmony => 'No chords';

  @override
  String get repeatDown => 'Fewer repeats';

  @override
  String get repeatUp => 'More repeats';

  @override
  String get scoreTranspose => 'Transpose';

  @override
  String get semitone => 'Semitone';

  @override
  String get semitoneDown => 'Down a semitone';

  @override
  String get semitoneUp => 'Up a semitone';

  @override
  String get scoreArrangement => 'Playback accompaniment';

  @override
  String get arrangementOff => 'Off';

  @override
  String get arrangementBlock => 'Held';

  @override
  String get arrangementPulse => 'Beat';

  @override
  String get arrangementBroken => 'Arpeggio';

  @override
  String get scoreProject => 'Project';

  @override
  String get scoreTools => 'Tools';

  @override
  String get playFailed => 'Can\'t play';

  @override
  String get proofread => 'Proofread';

  @override
  String proofreadBar(int number, int count) {
    return 'Bar $number of $count';
  }

  @override
  String get noteStepUp => 'Step up';

  @override
  String get noteStepDown => 'Step down';

  @override
  String get noteSharp => 'Sharp';

  @override
  String get noteFlat => 'Flat';

  @override
  String get noteNatural => 'Natural';

  @override
  String get deleteNote => 'Delete note';

  @override
  String get restToNote => 'Make note';

  @override
  String get previousNote => 'Previous note';

  @override
  String get nextNote => 'Next note';

  @override
  String get previousBar => 'Previous bar';

  @override
  String get nextBar => 'Next bar';

  @override
  String get chordSymbolHint => 'C, F#m7, B♭/D';

  @override
  String proofreadVersionName(int n) {
    return 'Proofread $n';
  }

  @override
  String get saveBeforeProofread => 'Save or discard your changes first';

  @override
  String get goToBar => 'Go to bar';

  @override
  String sectionBarRange(int start, int end) {
    return 'Bars $start–$end';
  }

  @override
  String get sectionOrder => 'Order';

  @override
  String get sectionSolo => 'Solo';

  @override
  String get sectionInterlude => 'Interlude';

  @override
  String sectionBarPickEnd(int number) {
    return 'Bar $number · tap the last bar too, or pick a name';
  }

  @override
  String sectionRange(int start, int end) {
    return 'Bars $start–$end · tap a later line to extend';
  }

  @override
  String get sectionStartHint => 'Tap a bar to start a new section there';

  @override
  String sectionInfo(String name, int start, int end) {
    return '$name · bars $start–$end';
  }

  @override
  String get sectionCustom => 'Custom…';

  @override
  String get sectionCancelPick => 'Clear selection';

  @override
  String get sectionRemoveBoundary => 'Merge with previous';

  @override
  String get sectionUnnamed => 'No name';

  @override
  String get sectionNameTitle => 'Section name';

  @override
  String get playbackAsWritten => 'Plays as written';

  @override
  String playbackSummary(int bars, String time) {
    return '$bars bars · $time';
  }

  @override
  String playbackSkipped(int count) {
    return '$count bars not played';
  }

  @override
  String get buildOrderFromSections => 'Start from the score\'s order';

  @override
  String get resetPlaybackOrder => 'Play as written';

  @override
  String performanceVersionName(int n) {
    return 'Performance $n';
  }

  @override
  String repeatTimes(int count) {
    return '×$count';
  }

  @override
  String get sequenceUnsavedBody => 'Save the playback order before leaving?';

  @override
  String get saveSequenceFirst => 'Save or discard the playback order first';

  @override
  String get fetchAiVersion => 'Get AI correction';

  @override
  String get aiFetching =>
      'Getting the AI correction… this can take a few minutes.';

  @override
  String get aiFetchUnchanged => 'The AI review found nothing to change.';

  @override
  String get aiFetchExpired =>
      'The server no longer has this conversion. Convert the score again to get an AI correction.';

  @override
  String get aiFetchUnavailable =>
      'AI review is not available on the server right now.';

  @override
  String get aiFetchFailed => 'Could not get the AI correction.';

  @override
  String endingPass(int pass) {
    return 'Pass $pass';
  }

  @override
  String get structureTabSections => 'Sections';

  @override
  String get structureTabOrder => 'Order';

  @override
  String get makeScoreFromOrder => 'Make a score in this order';

  @override
  String get openScoreFromOrder => 'Open the score in this order';

  @override
  String get scoreFromOrderKeepsThis => 'This score stays as it is.';

  @override
  String transposedVersionName(String key) {
    return 'Transposed to $key';
  }

  @override
  String get makeThreeStaff => 'Make an instrument score';

  @override
  String get threeStaffVersionName => 'With accompaniment';

  @override
  String get threeStaffNeedsChords =>
      'There are no chord symbols to make an accompaniment from';

  @override
  String get threeStaffNeedsMelody =>
      'Accompaniment parts can only be added to a one-staff melody';

  @override
  String get pianoPartName => 'Piano';

  @override
  String get pianoPattern => 'Right-hand pattern';

  @override
  String get pianoPatternHeld => 'Held';

  @override
  String get pianoPatternBeats => 'Every beat';

  @override
  String get pianoPatternBroken => 'Broken';

  @override
  String get pianoRegister => 'Accompaniment height';

  @override
  String get pianoRegisterMiddle => 'Middle';

  @override
  String get pianoRegisterLow => 'Low';

  @override
  String get pianoAskAdvice => 'AI suggestion';

  @override
  String get pianoAdviceFailed => 'No suggestion available right now';

  @override
  String get pianoSectionStyles => 'By section';

  @override
  String get pianoOneStyle => 'One style for all';

  @override
  String pianoSectionStyle(int bar, String pattern, String register) {
    return 'From bar $bar: $pattern · $register';
  }

  @override
  String get pianoChordFixes => 'Chords to check';

  @override
  String get pianoNoChordFixes => 'None';

  @override
  String pianoChordFix(int bar, String current, String suggested) {
    return 'Bar $bar: $current → $suggested';
  }

  @override
  String get pianoMake => 'Make';

  @override
  String get accompanimentInstruments => 'Instruments';

  @override
  String get organPartName => 'Organ';

  @override
  String get stringsPartName => 'Strings';

  @override
  String get padPartName => 'Pad';

  @override
  String get brassPartName => 'Brass';

  @override
  String get pianoPatternAuto => 'By section';

  @override
  String get accompanimentOutput => 'Result';

  @override
  String get accompanimentSeparateScores => 'One score per instrument';

  @override
  String get accompanimentOneScore => 'All in one score';

  @override
  String get accompanimentDensity => 'Chord thickness';

  @override
  String get accompanimentDensityLight => 'Light';

  @override
  String get accompanimentDensityNormal => 'Normal';

  @override
  String get accompanimentDensityFull => 'Full';

  @override
  String get pianoSplitPoint => 'Where the hands split';

  @override
  String get pianoSplitAuto => 'Auto';

  @override
  String get toolsMarks => 'Marks';

  @override
  String get toolsBarSigns => 'Bar signs';

  @override
  String get noteToRest => 'Make rest';

  @override
  String get removeNoteTool => 'Remove';

  @override
  String get splitNote => 'Split';

  @override
  String get insertTool => 'Insert';

  @override
  String get insertNoteBefore => 'Note before';

  @override
  String get insertNoteAfter => 'Note after';

  @override
  String get insertRestBefore => 'Rest before';

  @override
  String get insertRestAfter => 'Rest after';

  @override
  String get graceNote => 'Grace note';

  @override
  String get tieTool => 'Tie';

  @override
  String get tuplet => 'Tuplet';

  @override
  String tupletOf(int n) {
    return '$n-tuplet';
  }

  @override
  String get tupletRemove => 'Remove tuplet';

  @override
  String get doubleSharp => 'Double sharp';

  @override
  String get doubleFlat => 'Double flat';

  @override
  String get staccato => 'Staccato';

  @override
  String get staccatissimo => 'Staccatissimo';

  @override
  String get tenuto => 'Tenuto';

  @override
  String get marcato => 'Marcato';

  @override
  String get fermata => 'Fermata';

  @override
  String get dynamics => 'Dynamics';

  @override
  String get dynamicsNone => 'None';

  @override
  String get keyAndTime => 'Key · Time';

  @override
  String get clef => 'Clef';

  @override
  String get clefTreble => 'Treble';

  @override
  String get clefBass => 'Bass';

  @override
  String get clefAlto => 'Alto';

  @override
  String get clefTenor => 'Tenor';

  @override
  String get repeatStart => 'Repeat start';

  @override
  String get repeatEnd => 'Repeat end';

  @override
  String get barlineTool => 'Barline';

  @override
  String get barlineRegular => 'Single';

  @override
  String get barlineDouble => 'Double';

  @override
  String get barlineFinal => 'Final';

  @override
  String get endings => 'Endings';

  @override
  String endingStart(int n) {
    return 'Ending $n start';
  }

  @override
  String endingEnd(int n) {
    return 'Ending $n end';
  }

  @override
  String get navigationSigns => 'Jumps';

  @override
  String get tempoMark => 'Tempo';

  @override
  String get tempoBpmLabel => 'Beats per minute';

  @override
  String get tempoText => 'Tempo text (optional)';

  @override
  String get tempoRemove => 'Remove tempo';

  @override
  String get rehearsalMark => 'Section name';

  @override
  String get rehearsalHint => 'Verse, Chorus, A…';

  @override
  String get addText => 'Add text';

  @override
  String get addTextHint => 'rit., 2x…';

  @override
  String get slurTool => 'Slur';

  @override
  String get linesMenu => 'Lines';

  @override
  String get crescendo => 'Crescendo';

  @override
  String get diminuendo => 'Diminuendo';

  @override
  String get pedalLine => 'Pedal';

  @override
  String get glissando => 'Glissando';

  @override
  String get ornamentsMenu => 'Ornaments';

  @override
  String get trill => 'Trill';

  @override
  String get mordent => 'Mordent';

  @override
  String get invertedMordent => 'Inverted mordent';

  @override
  String get turnOrnament => 'Turn';

  @override
  String get tremolo => 'Tremolo';

  @override
  String get arpeggio => 'Arpeggio';

  @override
  String get breathMark => 'Breath mark';

  @override
  String spanPickEnd(String name) {
    return '$name: tap the note it ends on';
  }

  @override
  String get spanToSelected => 'To selected note';

  @override
  String get verseMenu => 'Verse';

  @override
  String verseOf(int n) {
    return 'Verse $n';
  }

  @override
  String get toolsKeys => 'Keys';

  @override
  String get keyboardLower => 'Keyboard octave down';

  @override
  String get keyboardHigher => 'Keyboard octave up';

  @override
  String get keyAdvance => 'Go to next note';

  @override
  String get penTool => 'Pen';

  @override
  String get penHint => 'Tap to place a note · hold to carry it to its line';

  @override
  String get rangeTool => 'Range';

  @override
  String get rangeHint => 'Tap the last note to pick several';

  @override
  String get voiceMenu => 'Voice';

  @override
  String get voiceAdd => 'Add a voice';

  @override
  String get voiceRemove => 'Remove this voice';

  @override
  String get lineBreakTool => 'Line break';

  @override
  String get pageBreakTool => 'Page break';

  @override
  String get toolsScore => 'Score';

  @override
  String get instrumentMenu => 'Instrument';

  @override
  String get staffMenu => 'Staff';

  @override
  String get staffAdd => 'Add a staff below';

  @override
  String get staffRemove => 'Remove the lower staff';

  @override
  String get barRange => 'Bar range…';

  @override
  String get barRangeTitle => 'Bar range';

  @override
  String get barRangeFrom => 'From bar';

  @override
  String get barRangeTo => 'To bar';

  @override
  String get barRangeCopy => 'Copy';

  @override
  String get barRangeCut => 'Cut';

  @override
  String get barRangeDelete => 'Clear';

  @override
  String get barRangeTranspose => 'Transpose';

  @override
  String semitoneCount(String n) {
    return '$n semitones';
  }

  @override
  String pasteBars(int n) {
    return 'Insert $n copied bars';
  }

  @override
  String barsCopied(int n) {
    return '$n bars copied';
  }

  @override
  String get barRangeInvalid => 'Check the bar numbers';

  @override
  String get pasteBarsNone => 'Insert (no bars copied)';

  @override
  String get breaksReflow =>
      'This score breaks its lines to fit the screen. Line breaks can be set in a score that has written lines.';

  @override
  String get toolSelect => 'Select';

  @override
  String get toolEraser => 'Eraser';

  @override
  String get toolNote => 'Write notes';

  @override
  String get toolRest => 'Write rests';

  @override
  String get toolAccidental => 'Accidental';

  @override
  String get paletteChooser => 'Palettes';

  @override
  String get toStart => 'To the start';

  @override
  String get eraserHint => 'Tap the note to erase';

  @override
  String get barEditPaste => 'Paste';

  @override
  String get barEditDuplicate => 'Duplicate';

  @override
  String barPicked(int n) {
    return 'Bar $n';
  }

  @override
  String barsPicked(int from, int to) {
    return 'Bars $from–$to';
  }

  @override
  String get keysAppendHint => 'The next key adds a new note after this one';

  @override
  String get lyricJoinHint =>
      'End with - to join the next syllable, with _ to hold it. Words with spaces go onto the notes that follow';

  @override
  String get respell => 'Respell (enharmonic)';

  @override
  String get fingeringMenu => 'Fingering';

  @override
  String get graceSlash => 'Grace slash';

  @override
  String get beamMenu => 'Beam';

  @override
  String get beamJoin => 'Join with a beam';

  @override
  String get beamBreak => 'Remove the beam';

  @override
  String get notesMenu => 'Copy · paste notes';

  @override
  String get notesCopy => 'Copy the picked notes';

  @override
  String notesPaste(int n) {
    return 'Paste from here ($n)';
  }

  @override
  String get notesPasteNone => 'Paste (nothing copied)';

  @override
  String get notesDuplicate => 'Duplicate right after';

  @override
  String notesCopied(int n) {
    return 'Copied $n';
  }

  @override
  String get pickupBar => 'Pickup bar';

  @override
  String get barsPerLine => 'Bars per line';

  @override
  String get barsPerLineAuto => 'Automatic (fit the page)';

  @override
  String barsPerLineOf(int n) {
    return '$n bars';
  }

  @override
  String get chordKeys => 'Build a chord';

  @override
  String get chordRepeat => 'Repeat the last chord';

  @override
  String get keyWidthTool => 'Key width';

  @override
  String get draftTitle => 'There are unsaved corrections';

  @override
  String get draftBody =>
      'What you were correcting last time was kept. Go on with it?';

  @override
  String get draftResume => 'Go on';

  @override
  String get soundNotes => 'Sound a note when it is written';

  @override
  String get toolsLooks => 'Looks';

  @override
  String get stemMenu => 'Stem';

  @override
  String get stemUp => 'Up';

  @override
  String get stemDown => 'Down';

  @override
  String get stemHide => 'Hide';

  @override
  String get automatic => 'Automatic';

  @override
  String get noteheadMenu => 'Notehead';

  @override
  String get noteheadNormal => 'Normal';

  @override
  String get noteheadSlash => 'Slash';

  @override
  String get noteheadGhost => 'Parentheses (ghost note)';

  @override
  String get otherStaff => 'To the other staff';

  @override
  String get markSideMenu => 'Side of marks';

  @override
  String get sideAbove => 'Above';

  @override
  String get sideBelow => 'Below';

  @override
  String get clearMarksTool => 'Remove all marks';

  @override
  String get clearAccidentalTool => 'Remove accidentals';

  @override
  String get doubleMenu => 'Double at an interval';

  @override
  String get doubleThirdUp => 'A third above';

  @override
  String get doubleSixthUp => 'A sixth above';

  @override
  String get doubleOctaveUp => 'An octave above';

  @override
  String get doubleThirdDown => 'A third below';

  @override
  String get doubleOctaveDown => 'An octave below';

  @override
  String get jazzMenu => 'Jazz articulations';

  @override
  String get selectMenu => 'Selection';

  @override
  String get selectAll => 'Select all';

  @override
  String get selectBar => 'Select this bar';

  @override
  String get onlyAll => 'All picked notes';

  @override
  String get onlyTop => 'Highest notes only';

  @override
  String get onlyBottom => 'Lowest notes only';

  @override
  String get clearLyrics => 'Remove the lyrics of the picked notes';

  @override
  String get clearChords => 'Remove the chord symbols of the picked notes';

  @override
  String get optRailRight => 'Tools on the right';

  @override
  String get optSmallTools => 'Small buttons';

  @override
  String get optDarkScore => 'Dark score';

  @override
  String get noteSizeMenu => 'Note size';

  @override
  String get noteSizeSmall => 'Small';

  @override
  String get noteSizeLarge => 'Large';

  @override
  String get noteSizeLarger => 'Larger';

  @override
  String get voiceSwap => 'Swap the two voices';

  @override
  String get barEditPasteInsert => 'Insert';

  @override
  String get tupletGroup => 'Make the picked notes a tuplet';

  @override
  String get tupletOneBar => 'Pick notes of one bar';

  @override
  String get keyRest => 'Write a rest and go on';

  @override
  String get favourFlats => 'Spell with flats';

  @override
  String get favourSharps => 'Spell with sharps';

  @override
  String get tempoChange => 'Tempo change';

  @override
  String get metronomeOption => 'Metronome while playing';

  @override
  String get hideTool => 'Hide';

  @override
  String get hideSignMenu => 'Hide signatures';

  @override
  String get hideTime => 'Time signature';

  @override
  String get hideKey => 'Key signature';

  @override
  String get insertMeasuresMany => 'Add several bars…';

  @override
  String get insertCount => 'How many bars';

  @override
  String get looseSelect => 'Pick notes one by one';

  @override
  String get looseHint => 'Tap notes to pick or drop them';

  @override
  String get onlyUpperVoice => 'Upper voice only';

  @override
  String get onlyLowerVoice => 'Lower voice only';

  @override
  String get rangeOption => 'Mark notes out of range';

  @override
  String get slashFill => 'Fill with slashes';

  @override
  String get fermataLength => 'Fermata length';

  @override
  String get fermataShort => 'Short';

  @override
  String get fermataLong => 'Long';

  @override
  String get repeatCount => 'Times played';

  @override
  String repeatCountOf(int n) {
    return '$n times';
  }

  @override
  String get revealHidden => 'Show what is hidden';

  @override
  String get chordDisplayMenu => 'Chord display';

  @override
  String get chordDisplayNashville => 'Nashville numbers';

  @override
  String get chordDisplayRoman => 'Roman numerals';

  @override
  String get wordSizeMenu => 'Text size';

  @override
  String get alignChordsOption => 'Chord symbols on one level';

  @override
  String get barNumbersMenu => 'Bar numbers';

  @override
  String get barNumbersLines => 'On every line';

  @override
  String get barNumbersEvery => 'On every bar';

  @override
  String get barNumbersNone => 'None';

  @override
  String get instrumentChange => 'Change instrument here';

  @override
  String get mixer => 'Mixer';

  @override
  String get mixerMute => 'Mute';

  @override
  String get mixerSolo => 'Solo';
}
