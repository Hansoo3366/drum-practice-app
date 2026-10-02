// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Latin (`la`).
class AppLocalizationsLa extends AppLocalizations {
  AppLocalizationsLa([String locale = 'la']) : super(locale);

  @override
  String get appName => 'Page-a-Diddle';

  @override
  String get tagline => 'Exercitatio tympanorum';

  @override
  String get tabHome => 'Domus';

  @override
  String get tabLibrary => 'Bibliotheca';

  @override
  String get tabSetlists => 'Indices';

  @override
  String get tabTools => 'Instrumenta';

  @override
  String get tabJam => 'Concentus';

  @override
  String get settings => 'Optiones';

  @override
  String get language => 'Lingua';

  @override
  String get theme => 'Thema';

  @override
  String get themeSystem => 'Systema';

  @override
  String get themeLight => 'Lucidum';

  @override
  String get themeDark => 'Obscurum';

  @override
  String get languageSystem => 'Systema';

  @override
  String get languageKorean => 'Coreana';

  @override
  String get languageEnglish => 'Anglica';

  @override
  String get languageJapanese => 'Iaponica';

  @override
  String get languageChinese => 'Sinica';

  @override
  String get languageLatin => 'Latina';

  @override
  String get version => 'Versio';

  @override
  String get sectionPractice => 'Exercitatio';

  @override
  String get sectionLibraryStage => 'Bibliotheca et scaena';

  @override
  String get sectionApp => 'Applicatio';

  @override
  String get tapTempo => 'Tempus tactu';

  @override
  String get tempoTrainer => 'Magister temporis';

  @override
  String get cloudScores => 'Chartae nubis';

  @override
  String get webDavTechnical => 'WebDAV';

  @override
  String get countIn => 'Praecursus';

  @override
  String get syncAnchor => 'Ancora soni';

  @override
  String get followConductor => 'Ducem sequere';

  @override
  String get returnToLive => 'Ad vivum redire';

  @override
  String get autoPaused => 'Sponte pausatum';

  @override
  String get followOff => 'Sequi clausum';

  @override
  String get followOn => 'Sequitur';

  @override
  String get progressFollow => 'Sequi';

  @override
  String get progressPage => 'Pagina';

  @override
  String get resumeLive => 'Vivum resumere';

  @override
  String get progressFollowHint => 'Mensuras cum sono et concentu sequitur';

  @override
  String get progressPageHint => 'Paginas tantum vertit';

  @override
  String get autoPausedHint => 'Manu motum · tange ad vivum';

  @override
  String get roleConductor => 'Dux';

  @override
  String get roleMembers => 'Socii';

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
  String get emptyLibraryTitle => 'Nondum chartae';

  @override
  String get emptyLibraryBody => 'PDF importa\nut exerceas';

  @override
  String get emptyRecentTitle => 'Nullae chartae recentes';

  @override
  String get emptySetlistsTitle => 'Nulli indices';

  @override
  String get emptySetlistsBody =>
      'Ordinem exercitationis vel scaenae fac\nut in scaena vertas';

  @override
  String get emptyJamSongs => 'Nondum carmina';

  @override
  String get emptyJamMembers => 'Nondum socii';

  @override
  String get loadFailed => 'Onerare non potui. Iterum conare.';

  @override
  String get pickFailed => 'Fasciculum eligere non potui';

  @override
  String get saveFailed => 'Servare non potui';

  @override
  String get downloadNeeded => 'Prius chartam deprime';

  @override
  String get offlineMissing => 'Extra rete non est';

  @override
  String get metronome => 'Metronomum';

  @override
  String get metronomeSubtitle => 'Metrum · accentus';

  @override
  String get metronomeSubtitleFull => 'Metrum · accentus · praecursus';

  @override
  String get openScore => 'Chartam aperire';

  @override
  String get practiceDeck => 'Instrumenta exercitationis';

  @override
  String get recentScores => 'Chartae recentes';

  @override
  String get seeAll => 'Omnia';

  @override
  String get weekPractice => 'Exercitatio huius hebdomadis';

  @override
  String get weekPracticeHint =>
      'Chartam aperiendo tempus exercitationis accumulatur';

  @override
  String get statSessions => 'Sessiones';

  @override
  String get statTime => 'Tempus';

  @override
  String get statAverage => 'Medium';

  @override
  String sessionCountLabel(int count) {
    return '$count×';
  }

  @override
  String get loadingEllipsis => 'Oneratur…';

  @override
  String get loading => 'Oneratur';

  @override
  String get importHintHome => 'PDF importa ut exerceas';

  @override
  String get continuePractice => 'Exercitationem continuare';

  @override
  String get greetingMorning => 'Bonum mane';

  @override
  String get greetingAfternoon => 'Bonum meridiem';

  @override
  String get greetingEvening => 'Bonam vesperam';

  @override
  String get relativeJustNow => 'Modo';

  @override
  String relativeMinutesAgo(int minutes) {
    return 'ante $minutes m';
  }

  @override
  String relativeHoursAgo(int hours) {
    return 'ante $hours h';
  }

  @override
  String relativeDaysAgo(int days) {
    return 'ante $days d';
  }

  @override
  String relativeMonthDay(int month, int day) {
    return '$day/$month';
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
  String get filterAll => 'Omnia';

  @override
  String get filterPdf => 'PDF';

  @override
  String get filterSmartScore => 'Charta digitalis';

  @override
  String get filterNativeScore => 'PDF';

  @override
  String get filterDifficult => 'Difficilia';

  @override
  String get filterFavorites => 'Grata';

  @override
  String get filterRecent => 'Recentia';

  @override
  String get library => 'Bibliotheca';

  @override
  String get folders => 'Capsae';

  @override
  String get allScores => 'Omnes chartae';

  @override
  String get folder => 'Capsa';

  @override
  String get unfiled => 'Sine capsa';

  @override
  String get manageFolders => 'Capsae administrare';

  @override
  String get newFolder => 'Capsa nova';

  @override
  String get newSubfolder => 'Subcapsa';

  @override
  String get folderParent => 'Capsa superior';

  @override
  String folderDepthLimit(int max) {
    return 'Subcapsae ad summum $max gradus';
  }

  @override
  String get editFolder => 'Capsam edere';

  @override
  String get folderName => 'Nomen capsae';

  @override
  String get folderNameRequired => 'Nomen capsae requiretur';

  @override
  String get folderColor => 'Color capsae';

  @override
  String get deleteFolder => 'Capsam delere';

  @override
  String get deleteFolderBody =>
      'Capsa sola deletur. Chartae sine capsa manent.';

  @override
  String get labels => 'Notae';

  @override
  String get addLabel => 'Notam addere';

  @override
  String get labelHint => '#nota';

  @override
  String get noFolder => 'Nulla capsa';

  @override
  String get import => 'Importare';

  @override
  String get importFrom => 'Unde importare';

  @override
  String get importFromDevice => 'Hoc instrumentum';

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
    return 'In electore fasciculorum $provider aperi et PDF elige.';
  }

  @override
  String importCloudHowTitle(String provider) {
    return 'Ex $provider eligere';
  }

  @override
  String importCloudHowBody(String provider) {
    return 'Haec applicatio in $provider nondum intrat.\n\n1. App $provider in instrumento installa et intra\n2. Perge ut elector fasciculorum aperiatur\n3. In menu (☰) $provider elige\n4. PDF selige\n\nIn aemulo saepe nullae apps nubis sunt — in telephono vero tempta.';
  }

  @override
  String get importCloudViaSystem => 'Per fasciculos systematis';

  @override
  String get importWebDavViaApp => 'In app intra';

  @override
  String get continueAction => 'Perge';

  @override
  String get importPdf => 'PDF importare';

  @override
  String get importMusicXml => 'PDF importare';

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
  String get importing => 'Importatur…';

  @override
  String get importFailed => 'Importatio defecit';

  @override
  String get searchHint => 'Carmen · artifex · BPM · nota';

  @override
  String get songTitle => 'Titulus';

  @override
  String get songTitleRequired => 'Titulus necessarius';

  @override
  String get artist => 'Artifex';

  @override
  String get more => 'Plura';

  @override
  String get favorite => 'Gratum';

  @override
  String get unfavorite => 'Gratum removere';

  @override
  String targetBpmShort(int target) {
    return 'Meta $target';
  }

  @override
  String libraryCountFilter(int count, String filter) {
    return '$count carmina · $filter';
  }

  @override
  String get smartThumb => 'Digitalis';

  @override
  String get newSetlist => 'Novus index';

  @override
  String get create => 'Creare';

  @override
  String get createScore => 'Partituram creare';

  @override
  String get createFailed => 'Creare non potui';

  @override
  String get createSetlist => 'Indicem creare';

  @override
  String get setlist => 'Index';

  @override
  String get name => 'Nomen';

  @override
  String get save => 'Servare';

  @override
  String get cancel => 'Cassare';

  @override
  String get delete => 'Delere';

  @override
  String get remove => 'Removere';

  @override
  String get rename => 'Nomen mutare';

  @override
  String get confirmDelete => 'Delere?';

  @override
  String get addSongs => 'Carmina addere';

  @override
  String get noSongs => 'Nulla carmina';

  @override
  String songAdded(String title) {
    return '$title additum';
  }

  @override
  String songCount(int count) {
    return '$count carmina';
  }

  @override
  String get stage => 'Scaena';

  @override
  String get startStage => 'Scaenam inire';

  @override
  String get saveOffline => 'Extra rete servare';

  @override
  String get downloadFailed => 'Depressio defecit';

  @override
  String get downloadRequired => 'Depressio necessaria';

  @override
  String savedSongs(int count) {
    return '$count carmina servata';
  }

  @override
  String savedSongsPartial(int saved, int failed) {
    return '$saved servata · $failed defecerunt';
  }

  @override
  String get changeFailed => 'Mutare non potui';

  @override
  String get fetchFailed => 'Onerare non potui';

  @override
  String get setlistPromptBody => 'Ordinem exercitationis vel spectaculi fac';

  @override
  String get jam => 'Concentus';

  @override
  String get jamTagline => 'Eadem charta, idem ictus — ut grex';

  @override
  String get jamHubHint =>
      'In eodem Wi-Fi sessionem crea et codice vel QR invita';

  @override
  String get activeJams => 'Concentus activi';

  @override
  String get nearbyJams => 'Concentus proximi';

  @override
  String get findNearbyJams => 'Proximum quaerere';

  @override
  String get noNearbyJams => 'Nullus concentus in hoc Wi-Fi';

  @override
  String get createJam => 'Concentum creare';

  @override
  String get jamName => 'Nomen concentus';

  @override
  String get join => 'Intrare';

  @override
  String get joinWithCode => 'Codice intrare';

  @override
  String get code => 'Codex';

  @override
  String get tapToGoBack => 'Tange ut redeas';

  @override
  String get inviteCode => 'Codex invitationis';

  @override
  String get copy => 'Copiare';

  @override
  String get move => 'Movere';

  @override
  String get moveToFolder => 'In capsam movere';

  @override
  String get copyToFolder => 'In capsam copiare';

  @override
  String selectedCount(int count) {
    return '$count selectae';
  }

  @override
  String get deleteSelectedBody =>
      'Chartas selectas delere? Non potest rescindi.';

  @override
  String get editSong => 'Chartam edere';

  @override
  String get codeCopied => 'Codex copiatus';

  @override
  String get jamCode => 'Codex concentus';

  @override
  String get showQr => 'QR ostendere';

  @override
  String get scanQr => 'QR scandere';

  @override
  String get clickTrack => 'Ictus';

  @override
  String get leave => 'Exire';

  @override
  String get none => 'Nihil';

  @override
  String get select => 'Eligere';

  @override
  String get change => 'Mutare';

  @override
  String get previous => 'Prius';

  @override
  String get next => 'Proximum';

  @override
  String get open => 'Aperire';

  @override
  String get play => 'Ludere';

  @override
  String get stop => 'Sistere';

  @override
  String get pause => 'Pausare';

  @override
  String get connected => 'Connexus';

  @override
  String get disconnected => 'Disiunctus';

  @override
  String get me => 'Ego';

  @override
  String get setlistNotFound => 'Index non inventus';

  @override
  String get noOpenableScore => 'Nulla charta aperienda';

  @override
  String get jamSessionNotFound => 'Sessio concentus non inventa';

  @override
  String get jamNetworkUnavailable => 'Wi-Fi mitte et iterum conare';

  @override
  String get jamJoinTimedOut => 'Sessio non inventa. Wi-Fi et codicem verifica';

  @override
  String get jamHostUnavailable =>
      'Ad hospitem coniungi non potuit. App et Wi-Fi verifica';

  @override
  String get jamHostDisconnected =>
      'Hospes sessionem clausit aut connexio interrupta est';

  @override
  String get jamBackToHub => 'Ad concentuum indicem';

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
  String get toolsWifiSync => 'Concentus in Wi-Fi';

  @override
  String get toolsGraduallyFaster => 'Sensim celerius';

  @override
  String get toolsTapForBpm => 'Tange pro BPM';

  @override
  String get start => 'Incipere';

  @override
  String get preparing => 'Paratur';

  @override
  String get tapToStart => 'Tange ut incipias';

  @override
  String get audioError => 'Error soni';

  @override
  String get bpmUp => 'BPM augere';

  @override
  String get bpmDown => 'BPM minuere';

  @override
  String get meter => 'Metrum';

  @override
  String get beatUnit => 'Unitas ictus';

  @override
  String get accent => 'Accentus';

  @override
  String get double => 'Duplum';

  @override
  String get halve => 'Dimidium';

  @override
  String get reset => 'Restituere';

  @override
  String get tapInput => 'Ictum tange';

  @override
  String get target => 'Meta';

  @override
  String get targetReached => 'Meta attacta';

  @override
  String get repetitions => 'Mensurae / gradus';

  @override
  String get repsDone => 'Iterationes completae';

  @override
  String get checkSettings => 'Optiones inspice';

  @override
  String get increase => 'Augmentum';

  @override
  String trainerProgress(int current, int total, int beat) {
    return '$current/$total mens. · ictus $beat';
  }

  @override
  String get trainerHint =>
      'A tempo initio ad metam, post N mensuras automatice ascendit.';

  @override
  String trainerPlan(int start, int step, int bars, int target) {
    return 'Ab $start, +$step post $bars mens., usque ad $target';
  }

  @override
  String trainerNext(int bpm) {
    return 'Prox. $bpm BPM';
  }

  @override
  String trainerStageBars(int current, int total) {
    return 'Hoc gradu $current/$total mens.';
  }

  @override
  String get trainerIdleTitle => 'Tempus ascendere';

  @override
  String get close => 'Claudere';

  @override
  String get back => 'Retro';

  @override
  String get done => 'Factum';

  @override
  String get score => 'Charta';

  @override
  String get openFailed => 'Aperire non potui';

  @override
  String get scoreSettings => 'Optiones chartae';

  @override
  String get music => 'Musica';

  @override
  String get metroShort => 'Metro';

  @override
  String get view => 'Visus';

  @override
  String get annotations => 'Adnotationes';

  @override
  String get playback => 'Reproductio';

  @override
  String get attachMusic => 'Musicam annectere';

  @override
  String get playing => 'Luditur';

  @override
  String get pickFile => 'Fasciculum eligere';

  @override
  String get playbackSpeed => 'Celeritas';

  @override
  String get loopSection => 'Iteratio sectionis';

  @override
  String get progress => 'Progressus';

  @override
  String get pageLayout => 'Dispositio paginarum';

  @override
  String get autoAdvance => 'Progressus automaticus';

  @override
  String get returnToCurrent => 'Ad locum redire';

  @override
  String get currentMeasure => 'Mensura praesens';

  @override
  String get notSelected => 'Non electum';

  @override
  String get nextSong => 'Carmen proximum';

  @override
  String get practiceSync => 'Exercitatio · sync';

  @override
  String anchorsCount(int count) {
    return '$count';
  }

  @override
  String get pedal => 'Pedale';

  @override
  String get practiceLog => 'Diarium exercitationis';

  @override
  String get hardMeasures => 'Mensurae difficiles';

  @override
  String get display => 'Ostentatio';

  @override
  String get showAnnotations => 'Adnotationes ostendere';

  @override
  String get clearAnnotations => 'Adnotationes delere';

  @override
  String get statusBar => 'Barra status';

  @override
  String get layoutAuto => 'Auto · 2 paginae / volumen';

  @override
  String get layoutFit => 'Aptare';

  @override
  String get layoutTwoUp => 'Duae';

  @override
  String get layoutScroll => 'Volvere';

  @override
  String get off => 'Clausum';

  @override
  String get wakeLockFailed => 'Lucem servare non potui';

  @override
  String get metronomeError => 'Error metronomi';

  @override
  String get haptics => 'Tactus';

  @override
  String get openInMetronome => 'In metronomo aperire';

  @override
  String get metronomeStop => 'Metronomum sistere';

  @override
  String get audioConnect => 'Sonum annectere';

  @override
  String get anchorLinkHint => 'Locum musicae initio mensurae coniunge.';

  @override
  String get measure => 'Mensura';

  @override
  String get audioSeconds => 'Secunda soni';

  @override
  String get currentPosition => 'Locus praesens';

  @override
  String get checkTime => 'Tempus inspice';

  @override
  String get deleteAnchorHere => 'Ancoram hic delere';

  @override
  String get needTwoAnchors => 'Prius duas ancoras serva';

  @override
  String get needTwoSectionAnchors => 'Duae ancorae sectionis necessariae';

  @override
  String get loopRangeHint => 'Inter ancoras mensurae/sectionis iterat.';

  @override
  String get loopRange => 'Ambitus iterationis';

  @override
  String get measureRange => 'Ambitus mensurarum';

  @override
  String get startMeasure => 'Mensura initii';

  @override
  String get endMeasure => 'Mensura finis';

  @override
  String get startLoop => 'Iterationem incipere';

  @override
  String get clearLoop => 'Iterationem delere';

  @override
  String get label => 'Titulus';

  @override
  String get enterLabel => 'Titulum inscribe';

  @override
  String get endRecording => 'Diarium finire';

  @override
  String get startPractice => 'Exercitationem incipere';

  @override
  String get targetBpm => 'Meta BPM';

  @override
  String get optional => 'Optio';

  @override
  String get targetBpmAboveCurrent => 'Meta BPM ≥ praesens';

  @override
  String get checkStartTargetBpm => 'BPM initii et metae inspice';

  @override
  String get recent => 'Recentia';

  @override
  String get targetAchieved => 'Meta perfecta';

  @override
  String targetBpmValue(int target) {
    return 'Meta $target BPM';
  }

  @override
  String targetRemaining(int delta) {
    return '$delta BPM ad metam';
  }

  @override
  String maxBpmLabel(int bpm, String target) {
    return 'Maximum $bpm BPM$target';
  }

  @override
  String practiceInProgress(int bpm, String date) {
    return 'In cursu · $bpm BPM · $date';
  }

  @override
  String inProgressLabel(String target) {
    return 'In cursu$target';
  }

  @override
  String noneWithTarget(String target) {
    return 'Nihil$target';
  }

  @override
  String sessionsWithTarget(int count, String target) {
    return '$count×$target';
  }

  @override
  String targetSuffix(int bpm) {
    return ' · meta $bpm BPM';
  }

  @override
  String get progressMode => 'Modus progressus';

  @override
  String get pressKey => 'Clavem preme';

  @override
  String get defaults => 'Default';

  @override
  String get left => 'Sinistra';

  @override
  String get right => 'Dextera';

  @override
  String get loop => 'Iteratio';

  @override
  String meterConfigured(String label) {
    return '$label · optiones';
  }

  @override
  String get timeSignature => 'Signum metri';

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
  String get startBpm => 'BPM initii';

  @override
  String get endBpm => 'BPM finis';

  @override
  String get checkInput => 'Input inspice';

  @override
  String get bpmRangeError => 'BPM 40–240 esto';

  @override
  String get reimportPdf => 'PDF denuo importa.';

  @override
  String get editMeasures => 'Mensuras edere';

  @override
  String get dragAddMeasure => 'Trahe ut mensuram addas';

  @override
  String get deleteMeasure => 'Mensuram delere';

  @override
  String get pageNav => 'Ad paginam';

  @override
  String get prevPage => 'Pagina prior';

  @override
  String get nextPage => 'Pagina proxima';

  @override
  String loopMeasures(int start, int end) {
    return 'mensurae $start–$end';
  }

  @override
  String measureBeat(int measure, int beat) {
    return 'm$measure ictus $beat';
  }

  @override
  String practiceStatsLine(int count, String duration, int bpm) {
    return '$count× · summa $duration · med. $bpm BPM';
  }

  @override
  String minutesSeconds(int minutes, int seconds) {
    return '${minutes}m ${seconds}s';
  }

  @override
  String get songInfo => 'De carmine';

  @override
  String get memo => 'Notae';

  @override
  String get audio => 'Sonus';

  @override
  String get connect => 'Coniungere';

  @override
  String get saving => 'Servatur…';

  @override
  String get audioAttachFailed => 'Sonum annectere non potui';

  @override
  String get importPdfScore => 'Chartam PDF importare';

  @override
  String get cloudSyncHint => 'Chartas nubis synchronizare potes';

  @override
  String get serverAddress => 'URL servi';

  @override
  String get username => 'Nomen usoris';

  @override
  String get password => 'Tessera';

  @override
  String get enterServerInfo => 'Notitias servi inscribe et coniunge';

  @override
  String get reconnect => 'Rursus coniungere';

  @override
  String get disconnect => 'Disiungere';

  @override
  String get notConnected => 'Non connexus';

  @override
  String get connectedStatus => 'Connexus';

  @override
  String get checking => 'Verificatur…';

  @override
  String get browseFiles => 'Fasciculos inspicere';

  @override
  String get checkUrl => 'URL inspice.';

  @override
  String get cantSaveSettings => 'Optiones servare non potui.';

  @override
  String get cantDisconnect => 'Disiungere non potui.';

  @override
  String get cantReadSettings => 'Optiones servatas legere non potui.';

  @override
  String get webdavFiles => 'Fasciculi WebDAV';

  @override
  String get webdavNeeded => 'Connexio WebDAV necessaria.';

  @override
  String get cloudOAuthSetupTitle => 'Nexus nubis non paratus';

  @override
  String get cloudOAuthNotConfigured =>
      'DROPBOX_CLIENT_ID --dart-define addito aedifica denuo. Google Drive Google Sign-In usus est.';

  @override
  String get cloudDisconnect => 'Disiunge';

  @override
  String get retry => 'Iterum';

  @override
  String get root => 'Radix';

  @override
  String get parentFolder => 'Superior';

  @override
  String get emptyFolder => 'In hoc directorio nulla fasciculi';

  @override
  String get addFailed => 'Addere non potui';

  @override
  String get cantSaveSync => 'Statum sync servare non potui.';

  @override
  String get accentStrong => 'Fortis';

  @override
  String get accentNormal => 'Normalis';

  @override
  String get accentMute => 'Mutum';

  @override
  String barsLabel(int count) {
    return '$count mensurae';
  }

  @override
  String get strokeThin => 'Tenue';

  @override
  String get strokeMedium => 'Medium';

  @override
  String get strokeThick => 'Crassum';

  @override
  String get strokeHighlight => 'Illuminatio';

  @override
  String get strokeEraser => 'Delere';

  @override
  String get color => 'Color';

  @override
  String get undo => 'Retractare';

  @override
  String get clearAll => 'Omnia delere';

  @override
  String get syncSynced => 'Synchronizatum';

  @override
  String get syncCloud => 'Nubes';

  @override
  String get syncOffline => 'Extra rete';

  @override
  String get syncUpdate => 'Renovare';

  @override
  String get syncMissing => 'Deest';

  @override
  String get cameraMissing => 'Nulla camera';

  @override
  String get key => 'Clavis';

  @override
  String get device => 'Apparatus';

  @override
  String get filePicker => 'Selector fasciculorum';

  @override
  String get noPdf => 'Nullum PDF';

  @override
  String get emptyPdf => 'PDF vacuum. Denuo importa.';

  @override
  String get noScore => 'Nulla charta';

  @override
  String stageMeasure(int measure) {
    return 'm$measure';
  }

  @override
  String stageNextSection(String section, int count) {
    return 'Prox. $section · post $count mensuras';
  }

  @override
  String stageNextSong(String title) {
    return 'Prox. · $title';
  }

  @override
  String get nameRequired => 'Nomen necessarium';

  @override
  String get enterName => 'Nomen inscribe.';

  @override
  String get endSession => 'Finire';

  @override
  String get session => 'Sessio';

  @override
  String get participants => 'Participes';

  @override
  String get song => 'Carmen';

  @override
  String get notify => 'Nuntius';

  @override
  String get onboardingSkip => 'Omittere';

  @override
  String get onboardingNext => 'Proximum';

  @override
  String get onboardingStart => 'Exercitationem inire';

  @override
  String get onboardTitle1 => 'Chartae in manu.';

  @override
  String get onboardBody1 => 'PDF importa et in spectatore scaenae exerce.';

  @override
  String get onboardTitle2 => 'In tempore mane';

  @override
  String get onboardBody2 =>
      'Metronomum, tempus tactu, magister et sequela soni ictum firmant.';

  @override
  String get onboardTitle3 => 'Una ludere';

  @override
  String get onboardBody3 =>
      'Indices fac et in eodem Wi-Fi concine — eadem pagina, idem ictus.';

  @override
  String get sectionLegal => 'Ius et auxilium';

  @override
  String get privacyPolicy => 'Consilium secretorum';

  @override
  String get termsOfUse => 'Conditiones usus';

  @override
  String get contactSupport => 'Auxilium petere';

  @override
  String get openSourceLicenses => 'Licentiae apertae';

  @override
  String get replayOnboarding => 'Salutationem rursus ostendere';

  @override
  String get couldNotOpenMail => 'Tabellam aperire non potui';

  @override
  String get privacyBody =>
      'Page-a-Diddle chartas, indices, diaria exercitationis et optiones in hoc apparatu servat.\n\nFacultates optivae (sync WebDAV et concentus in Wi-Fi) data solum ad servos vel apparatus a te electos mittunt. Servum rationum officialem chartas colligentem non gerimus.\n\nCamera solum ad QR concentus; rete locale solum ad concentum.\n\nFasciculi et data applicationis deleri possunt applicatione remota vel memoria empta.\n\nContactus: support@page-a-diddle.app\n\nHaec summa producti causa est; ante publicationem iuris consultum adhibe si opus est.';

  @override
  String get termsBody =>
      'Page-a-Diddle utendo consentis eam ad legitimam exercitationem musicam personalem vel professionalem adhibere.\n\nIura chartarum, sonorum fasciculorumque a te importatorum tua sunt. Materiam non licitam noli importare.\n\nApplicatio ut est praebetur sine cautione perpetuae operationis. Usus exercitationis et scaenae tuus est.\n\nConcentus et WebDAV rete tuo et servis a te constitutis nituntur.\n\nConditiones cum renovationibus mutari possunt; usu continuo post renovationem novas accipis.\n\nContactus: support@page-a-diddle.app';

  @override
  String get homeTipTitle => 'Exercitatio hodierna';

  @override
  String get homeTipBody =>
      'Chartam aperi, tempus tange, mensuras difficiles itera.';

  @override
  String get retryAction => 'Iterum conare';

  @override
  String get hardBadge => 'Diff.';

  @override
  String get viewerControlsHint => 'Tange summam ad regimen';

  @override
  String get cue => 'Signum';

  @override
  String get sectionLabel => 'Sectio';

  @override
  String get tempoMap => 'Tabula temporis';

  @override
  String get tempoStep => 'Gradus';

  @override
  String get tempoGradual => 'Paulatim';

  @override
  String get tempo => 'Tempus';

  @override
  String get bpmHintRange => '40–240';

  @override
  String get nowLabel => 'Nunc';

  @override
  String get sectionIntro => 'Introitus';

  @override
  String get sectionVerse => 'Versus';

  @override
  String get sectionPre => 'Prae-chorus';

  @override
  String get sectionChorus => 'Chorus';

  @override
  String get sectionBridge => 'Pons';

  @override
  String get sectionOutro => 'Exitus';

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
  String get barTextsHint =>
      'Text read from the page that is not a chord, a lyric or a note. Remove what was misread.';

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
  String get noSections => 'Tap a bar to start a section';

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
  String get scoreArrangement => 'Accompaniment';

  @override
  String get arrangementOff => 'Off';

  @override
  String get arrangementBlock => 'Chord';

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
  String get pianoPattern => 'Right hand';

  @override
  String get pianoPatternHeld => 'Held';

  @override
  String get pianoPatternBeats => 'Every beat';

  @override
  String get pianoPatternBroken => 'Broken';

  @override
  String get pianoRegister => 'Register';

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
  String get accompanimentDensity => 'Density';

  @override
  String get accompanimentDensityLight => 'Light';

  @override
  String get accompanimentDensityNormal => 'Normal';

  @override
  String get accompanimentDensityFull => 'Full';

  @override
  String get pianoSplitPoint => 'Right hand lowest note';

  @override
  String get pianoSplitAuto => 'Auto';
}
