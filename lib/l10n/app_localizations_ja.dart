// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appName => 'Page-a-Diddle';

  @override
  String get tagline => 'ドラム譜面練習';

  @override
  String get tabHome => 'ホーム';

  @override
  String get tabLibrary => 'ライブラリ';

  @override
  String get tabSetlists => 'セットリスト';

  @override
  String get tabTools => 'ツール';

  @override
  String get tabJam => '合奏';

  @override
  String get settings => '設定';

  @override
  String get language => '言語';

  @override
  String get theme => 'テーマ';

  @override
  String get themeSystem => 'システム';

  @override
  String get themeLight => 'ライト';

  @override
  String get themeDark => 'ダーク';

  @override
  String get languageSystem => 'システム';

  @override
  String get languageKorean => '한국어';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageChinese => '中文';

  @override
  String get languageLatin => 'ラテン語';

  @override
  String get version => 'バージョン';

  @override
  String get sectionPractice => '練習';

  @override
  String get sectionLibraryStage => 'ライブラリ・演奏';

  @override
  String get sectionApp => 'アプリ';

  @override
  String get tapTempo => 'タップテンポ';

  @override
  String get tempoTrainer => 'テンポトレーナー';

  @override
  String get cloudScores => 'クラウド譜面';

  @override
  String get webDavTechnical => 'WebDAV';

  @override
  String get countIn => 'カウントイン';

  @override
  String get syncAnchor => 'オーディオアンカー';

  @override
  String get followConductor => '指揮者に従う';

  @override
  String get returnToLive => 'ライブに戻る';

  @override
  String get autoPaused => '自動一時停止';

  @override
  String get followOff => '追従オフ';

  @override
  String get followOn => '追従オン';

  @override
  String get progressFollow => '追従';

  @override
  String get progressPage => 'ページ';

  @override
  String get resumeLive => 'ライブ再開';

  @override
  String get progressFollowHint => '音声・合奏に合わせて小節を追います';

  @override
  String get progressPageHint => 'ページ単位のみめくります';

  @override
  String get autoPausedHint => '手動移動 · タップでライブへ';

  @override
  String get roleConductor => '指揮者';

  @override
  String get roleMembers => 'メンバー';

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
  String get emptyLibraryTitle => 'まだ譜面がありません';

  @override
  String get emptyLibraryBody => 'PDFを取り込めば\nすぐ練習できます';

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
  String get emptyRecentTitle => '最近開いた譜面はありません';

  @override
  String get emptySetlistsTitle => 'セットリストがありません';

  @override
  String get emptySetlistsBody => '演奏・練習の順番を作れば\nステージで即めくれます';

  @override
  String get emptyJamSongs => 'まだ曲がありません';

  @override
  String get emptyJamMembers => 'まだメンバーがいません';

  @override
  String get loadFailed => '読み込めませんでした。もう一度お試しください。';

  @override
  String get pickFailed => 'ファイルを選べませんでした';

  @override
  String get saveFailed => '保存できませんでした';

  @override
  String get downloadNeeded => '先に譜面をダウンロードしてください';

  @override
  String get offlineMissing => 'オフラインなし';

  @override
  String get metronome => 'メトロノーム';

  @override
  String get metronomeSubtitle => '拍子・アクセント';

  @override
  String get metronomeSubtitleFull => '拍子・アクセント・カウントイン';

  @override
  String get openScore => '譜面を開く';

  @override
  String get practiceDeck => 'すぐ練習';

  @override
  String get recentScores => '最近の譜面';

  @override
  String get seeAll => 'すべて';

  @override
  String get weekPractice => '今週の練習';

  @override
  String get weekPracticeHint => '譜面を開くと練習時間が自動で積み上がります';

  @override
  String get statSessions => 'セッション';

  @override
  String get statTime => '時間';

  @override
  String get statAverage => '平均';

  @override
  String sessionCountLabel(int count) {
    return '$count回';
  }

  @override
  String get loadingEllipsis => '読み込み中…';

  @override
  String get loading => '読み込み中';

  @override
  String get importHintHome => 'PDFを取り込んで練習を始めましょう';

  @override
  String get continuePractice => '練習を続ける';

  @override
  String get greetingMorning => 'おはようございます';

  @override
  String get greetingAfternoon => 'こんにちは';

  @override
  String get greetingEvening => 'こんばんは';

  @override
  String get relativeJustNow => 'たった今';

  @override
  String relativeMinutesAgo(int minutes) {
    return '$minutes分前';
  }

  @override
  String relativeHoursAgo(int hours) {
    return '$hours時間前';
  }

  @override
  String relativeDaysAgo(int days) {
    return '$days日前';
  }

  @override
  String relativeMonthDay(int month, int day) {
    return '$month月$day日';
  }

  @override
  String durationSeconds(int seconds) {
    return '$seconds秒';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes分';
  }

  @override
  String durationHours(int hours) {
    return '$hours時間';
  }

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours時間 $minutes分';
  }

  @override
  String get filterAll => 'すべて';

  @override
  String get filterPdf => 'PDF';

  @override
  String get filterSmartScore => '電子譜面';

  @override
  String get filterNativeScore => 'PDF';

  @override
  String get filterDifficult => '難しい';

  @override
  String get filterFavorites => 'お気に入り';

  @override
  String get filterRecent => '最近';

  @override
  String get library => 'ライブラリ';

  @override
  String get folders => 'フォルダ';

  @override
  String get allScores => 'すべての譜面';

  @override
  String get folder => 'フォルダ';

  @override
  String get unfiled => '未分類';

  @override
  String get manageFolders => 'フォルダ管理';

  @override
  String get newFolder => '新しいフォルダ';

  @override
  String get newSubfolder => 'サブフォルダ';

  @override
  String get folderParent => '親フォルダ';

  @override
  String folderDepthLimit(int max) {
    return 'サブフォルダは最大$max階層までです';
  }

  @override
  String get editFolder => 'フォルダを編集';

  @override
  String get folderName => 'フォルダ名';

  @override
  String get folderNameRequired => 'フォルダ名を入力してください';

  @override
  String get folderColor => 'フォルダの色';

  @override
  String get deleteFolder => 'フォルダを削除';

  @override
  String get deleteFolderBody => 'フォルダだけ削除されます。譜面は未分類のまま残ります。';

  @override
  String get labels => 'ラベル';

  @override
  String get addLabel => 'ラベルを追加';

  @override
  String get labelHint => '#タグ';

  @override
  String get noFolder => 'フォルダなし';

  @override
  String get import => '取り込み';

  @override
  String get importFrom => '取り込み元';

  @override
  String get importFromDevice => 'この端末';

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
    return 'ファイル選択で$providerを開き、PDFを選んでください。';
  }

  @override
  String importCloudHowTitle(String provider) {
    return '$providerから選ぶ';
  }

  @override
  String importCloudHowBody(String provider) {
    return 'このアプリ内の$providerログインはまだありません。\n\n1. 端末に$providerアプリを入れてログイン\n2. 続行でシステムファイル選択を開く\n3. サイドメニュー(☰)から$providerを選ぶ\n4. PDFを選択\n\nエミュレータにはクラウドアプリがないことが多いです。実機で試してください。';
  }

  @override
  String get importCloudViaSystem => 'システムファイルから';

  @override
  String get importWebDavViaApp => 'アプリ内でログイン';

  @override
  String get continueAction => '続行';

  @override
  String get importPdf => 'PDFを取り込む';

  @override
  String get importMusicXml => 'PDFを取り込む';

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
  String get importing => '取り込み中…';

  @override
  String get importFailed => '取り込み失敗';

  @override
  String get searchHint => '曲 · アーティスト · BPM · ラベル';

  @override
  String get songTitle => '曲名';

  @override
  String get songTitleRequired => '曲名が必要です';

  @override
  String get artist => 'アーティスト';

  @override
  String get more => 'その他';

  @override
  String get favorite => 'お気に入り';

  @override
  String get unfavorite => 'お気に入り解除';

  @override
  String targetBpmShort(int target) {
    return '目標 $target';
  }

  @override
  String libraryCountFilter(int count, String filter) {
    return '$count曲 · $filter';
  }

  @override
  String get smartThumb => '電子';

  @override
  String get newSetlist => '新しいセットリスト';

  @override
  String get create => '作成';

  @override
  String get createScore => '楽譜を作る';

  @override
  String get createFailed => '作成失敗';

  @override
  String get createSetlist => 'セットリストを作成';

  @override
  String get setlist => 'セットリスト';

  @override
  String get name => '名前';

  @override
  String get save => '保存';

  @override
  String get cancel => 'キャンセル';

  @override
  String get delete => '削除';

  @override
  String get remove => '削除';

  @override
  String get rename => '名前を変更';

  @override
  String get confirmDelete => '削除しますか？';

  @override
  String get addSongs => '曲を追加';

  @override
  String get noSongs => '曲なし';

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
  String get playBar => 'Play this bar';

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
    return '$title を追加しました';
  }

  @override
  String songCount(int count) {
    return '$count曲';
  }

  @override
  String get stage => 'ステージ';

  @override
  String get startStage => 'ステージ開始';

  @override
  String get saveOffline => 'オフライン保存';

  @override
  String get downloadFailed => 'ダウンロード失敗';

  @override
  String get downloadRequired => 'ダウンロードが必要';

  @override
  String savedSongs(int count) {
    return '$count曲保存';
  }

  @override
  String savedSongsPartial(int saved, int failed) {
    return '$saved曲保存 · $failed曲失敗';
  }

  @override
  String get changeFailed => '変更失敗';

  @override
  String get fetchFailed => '読み込み失敗';

  @override
  String get setlistPromptBody => '練習・演奏の順番を作ってください';

  @override
  String get jam => '合奏';

  @override
  String get jamTagline => 'バンドのように、同じ譜面・同じ拍子';

  @override
  String get jamHubHint => '同じWi-Fiでセッションを作り、コードやQRで招待';

  @override
  String get activeJams => '進行中の合奏';

  @override
  String get nearbyJams => '近くの部屋';

  @override
  String get findNearbyJams => '近くを検索';

  @override
  String get noNearbyJams => '同じWi-Fiに部屋がありません';

  @override
  String get createJam => '合奏を作成';

  @override
  String get jamName => '合奏名';

  @override
  String get join => '参加';

  @override
  String get joinWithCode => 'コードで参加';

  @override
  String get code => 'コード';

  @override
  String get tapToGoBack => 'タップして戻る';

  @override
  String get inviteCode => '招待コード';

  @override
  String get copy => 'コピー';

  @override
  String get move => '移動';

  @override
  String get moveToFolder => 'フォルダへ移動';

  @override
  String get copyToFolder => 'フォルダへコピー';

  @override
  String selectedCount(int count) {
    return '$count件選択';
  }

  @override
  String get deleteSelectedBody => '選択した譜面を削除しますか？元に戻せません。';

  @override
  String get editSong => '譜面を編集';

  @override
  String get codeCopied => 'コードをコピーしました';

  @override
  String get jamCode => '合奏コード';

  @override
  String get showQr => 'QRコードを表示';

  @override
  String get scanQr => 'QRスキャン';

  @override
  String get clickTrack => 'クリック音';

  @override
  String get leave => '退出';

  @override
  String get none => 'なし';

  @override
  String get select => '選択';

  @override
  String get change => '変更';

  @override
  String get previous => '前へ';

  @override
  String get next => '次へ';

  @override
  String get open => '開く';

  @override
  String get play => '再生';

  @override
  String get stop => '停止';

  @override
  String get pause => '一時停止';

  @override
  String get connected => '接続';

  @override
  String get disconnected => '切断';

  @override
  String get me => '自分';

  @override
  String get setlistNotFound => 'セットリストが見つかりません';

  @override
  String get noOpenableScore => '開ける譜面がありません';

  @override
  String get jamSessionNotFound => '合奏セッションが見つかりません';

  @override
  String get jamNetworkUnavailable => 'Wi-Fiをオンにして、もう一度お試しください';

  @override
  String get jamJoinTimedOut => 'セッションが見つかりません。Wi-Fiとコードを確認してください';

  @override
  String get jamHostUnavailable => 'ホストに接続できません。ホストのアプリとWi-Fiを確認してください';

  @override
  String get jamHostDisconnected => 'ホストがセッションを終了したか、接続が切れました';

  @override
  String get jamBackToHub => '合奏一覧へ';

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
  String get toolsWifiSync => '同じWi-Fiで合奏';

  @override
  String get toolsGraduallyFaster => '徐々に速く';

  @override
  String get toolsTapForBpm => 'タップでBPM計測';

  @override
  String get start => '開始';

  @override
  String get preparing => '準備中';

  @override
  String get tapToStart => 'タップして開始';

  @override
  String get audioError => 'オーディオエラー';

  @override
  String get bpmUp => 'BPMを上げる';

  @override
  String get bpmDown => 'BPMを下げる';

  @override
  String get meter => '拍子記号';

  @override
  String get beatUnit => '分割';

  @override
  String get accent => 'アクセント';

  @override
  String get double => '2倍';

  @override
  String get halve => '半分';

  @override
  String get reset => 'リセット';

  @override
  String get tapInput => '拍を入力';

  @override
  String get target => '目標';

  @override
  String get targetReached => '目標到達';

  @override
  String get repetitions => '小節/段階';

  @override
  String get repsDone => '繰り返し完了';

  @override
  String get checkSettings => '設定を確認してください';

  @override
  String get increase => '増加';

  @override
  String trainerProgress(int current, int total, int beat) {
    return '$current/$total 小節 · $beat拍';
  }

  @override
  String get trainerHint => '開始テンポから目標まで、設定した小節ごとに自動で上がります。';

  @override
  String trainerPlan(int start, int step, int bars, int target) {
    return '$startから $bars小節ごとに +$step、$targetまで';
  }

  @override
  String trainerNext(int bpm) {
    return '次は $bpm BPM';
  }

  @override
  String trainerStageBars(int current, int total) {
    return 'この段階 $current/$total 小節';
  }

  @override
  String get trainerIdleTitle => 'テンポを上げて身につける';

  @override
  String get close => '閉じる';

  @override
  String get back => '戻る';

  @override
  String get done => '完了';

  @override
  String get score => '譜面';

  @override
  String get openFailed => '開けませんでした';

  @override
  String get scoreSettings => '譜面設定';

  @override
  String get music => '音楽';

  @override
  String get metroShort => 'メトロ';

  @override
  String get view => '表示';

  @override
  String get annotations => '注釈';

  @override
  String get playback => '再生';

  @override
  String get attachMusic => '音楽を接続';

  @override
  String get playing => '再生中';

  @override
  String get pickFile => 'ファイルを選択';

  @override
  String get playbackSpeed => '再生速度';

  @override
  String get loopSection => '区間リピート';

  @override
  String get progress => '進行';

  @override
  String get pageLayout => 'ページレイアウト';

  @override
  String get autoAdvance => '自動進行';

  @override
  String get returnToCurrent => '現在位置に戻る';

  @override
  String get currentMeasure => '現在の小節';

  @override
  String get notSelected => '未選択';

  @override
  String get nextSong => '次の曲';

  @override
  String get practiceSync => '練習・同期';

  @override
  String anchorsCount(int count) {
    return '$count個';
  }

  @override
  String get pedal => 'ペダル';

  @override
  String get practiceLog => '練習記録';

  @override
  String get hardMeasures => '難しい小節';

  @override
  String get display => '表示';

  @override
  String get showAnnotations => '注釈を表示';

  @override
  String get clearAnnotations => '注釈を消去';

  @override
  String get statusBar => 'ステータスバー';

  @override
  String get layoutAuto => '自動 · 横2ページ / 縦スクロール';

  @override
  String get layoutFit => 'フィット';

  @override
  String get layoutTwoUp => '2ページ';

  @override
  String get layoutScroll => 'スクロール';

  @override
  String get off => 'オフ';

  @override
  String get wakeLockFailed => '画面維持に失敗';

  @override
  String get metronomeError => 'メトロノームエラー';

  @override
  String get haptics => '触覚';

  @override
  String get openInMetronome => 'メトロノームで開く';

  @override
  String get metronomeStop => 'メトロノーム停止';

  @override
  String get audioConnect => 'オーディオ接続';

  @override
  String get anchorLinkHint => '音楽位置と小節開始を接続します。';

  @override
  String get measure => '小節';

  @override
  String get audioSeconds => 'オーディオ秒';

  @override
  String get currentPosition => '現在位置';

  @override
  String get checkTime => '時間を確認してください';

  @override
  String get deleteAnchorHere => 'この小節のアンカーを削除';

  @override
  String get needTwoAnchors => '先にアンカーを2つ以上保存してください';

  @override
  String get needTwoSectionAnchors => 'セクションアンカーが2つ必要';

  @override
  String get loopRangeHint => '小節/セクションアンカー間を繰り返します。';

  @override
  String get loopRange => 'リピート範囲';

  @override
  String get measureRange => '小節範囲';

  @override
  String get startMeasure => '開始小節';

  @override
  String get endMeasure => '終了小節';

  @override
  String get startLoop => 'リピート開始';

  @override
  String get clearLoop => 'リピート解除';

  @override
  String get label => '表示';

  @override
  String get enterLabel => '表示を入力してください';

  @override
  String get endRecording => '記録終了';

  @override
  String get startPractice => '練習開始';

  @override
  String get targetBpm => '目標BPM';

  @override
  String get optional => '任意';

  @override
  String get targetBpmAboveCurrent => '目標BPMは現在以上';

  @override
  String get checkStartTargetBpm => '開始・目標BPMを確認';

  @override
  String get recent => '最近';

  @override
  String get targetAchieved => '目標達成';

  @override
  String targetBpmValue(int target) {
    return '目標 $target BPM';
  }

  @override
  String targetRemaining(int delta) {
    return '目標まで $delta BPM';
  }

  @override
  String maxBpmLabel(int bpm, String target) {
    return '最高 $bpm BPM$target';
  }

  @override
  String practiceInProgress(int bpm, String date) {
    return '進行中 · $bpm BPM · $date';
  }

  @override
  String inProgressLabel(String target) {
    return '進行中$target';
  }

  @override
  String noneWithTarget(String target) {
    return 'なし$target';
  }

  @override
  String sessionsWithTarget(int count, String target) {
    return '$count回$target';
  }

  @override
  String targetSuffix(int bpm) {
    return ' · 目標 $bpm BPM';
  }

  @override
  String get progressMode => '進行方式';

  @override
  String get pressKey => 'キーを押してください';

  @override
  String get defaults => 'デフォルト';

  @override
  String get left => '左';

  @override
  String get right => '右';

  @override
  String get loop => 'リピート';

  @override
  String meterConfigured(String label) {
    return '$label · 設定';
  }

  @override
  String get timeSignature => '拍子記号';

  @override
  String get timeSignatureNotation => 'Notation';

  @override
  String get timeSignatureNumbers => 'Numbers';

  @override
  String get commonTime => 'Common time (C)';

  @override
  String get allaBreve => 'Alla breve (¢)';

  @override
  String get numerator => '分子';

  @override
  String get denominator => '分母';

  @override
  String get startBpm => '開始BPM';

  @override
  String get endBpm => '終了BPM';

  @override
  String get checkInput => '入力を確認';

  @override
  String get bpmRangeError => 'BPMは40〜240である必要があります';

  @override
  String get reimportPdf => 'PDFを再取り込みしてください。';

  @override
  String get editMeasures => '小節を編集';

  @override
  String get dragAddMeasure => 'ドラッグして小節を追加';

  @override
  String get deleteMeasure => '小節を削除';

  @override
  String get pageNav => 'ページ移動';

  @override
  String get prevPage => '前のページ';

  @override
  String get nextPage => '次のページ';

  @override
  String loopMeasures(int start, int end) {
    return '$start–$end 小節';
  }

  @override
  String measureBeat(int measure, int beat) {
    return '$measure小節 $beat拍';
  }

  @override
  String practiceStatsLine(int count, String duration, int bpm) {
    return '$count回 · 合計 $duration · 平均 $bpm BPM';
  }

  @override
  String minutesSeconds(int minutes, int seconds) {
    return '$minutes分 $seconds秒';
  }

  @override
  String get songInfo => '曲情報';

  @override
  String get memo => 'メモ';

  @override
  String get audio => 'オーディオ';

  @override
  String get connect => '接続';

  @override
  String get saving => '保存中…';

  @override
  String get audioAttachFailed => 'オーディオ接続失敗';

  @override
  String get importPdfScore => 'PDF譜面を取り込む';

  @override
  String get cloudSyncHint => 'クラウド譜面を同期できます';

  @override
  String get serverAddress => 'サーバーURL';

  @override
  String get username => 'ユーザー名';

  @override
  String get password => 'パスワード';

  @override
  String get enterServerInfo => 'サーバー情報を入力して接続';

  @override
  String get reconnect => '再接続';

  @override
  String get disconnect => '切断';

  @override
  String get notConnected => '未接続';

  @override
  String get connectedStatus => '接続済み';

  @override
  String get checking => '確認中…';

  @override
  String get browseFiles => 'ファイルを見る';

  @override
  String get checkUrl => 'URLを確認してください。';

  @override
  String get cantSaveSettings => '設定を保存できません。';

  @override
  String get cantDisconnect => '切断できません。';

  @override
  String get cantReadSettings => '保存された設定を読めません。';

  @override
  String get webdavFiles => 'WebDAVファイル';

  @override
  String get webdavNeeded => 'WebDAV接続が必要です。';

  @override
  String get cloudOAuthSetupTitle => 'クラウドログイン未設定';

  @override
  String get cloudOAuthNotConfigured =>
      'DROPBOX_CLIENT_ID を --dart-define で指定して再ビルドしてください。Google Drive はアプリの Google ログイン設定を使います。';

  @override
  String get cloudDisconnect => '切断';

  @override
  String get retry => '再試行';

  @override
  String get root => 'ルート';

  @override
  String get parentFolder => '上のフォルダ';

  @override
  String get emptyFolder => 'このフォルダにファイルがありません';

  @override
  String get addFailed => '追加失敗';

  @override
  String get cantSaveSync => '同期状態を保存できません。';

  @override
  String get accentStrong => '強';

  @override
  String get accentNormal => '標準';

  @override
  String get accentMute => 'ミュート';

  @override
  String barsLabel(int count) {
    return '$count小節';
  }

  @override
  String get strokeThin => '細';

  @override
  String get strokeMedium => '中';

  @override
  String get strokeThick => '太';

  @override
  String get strokeHighlight => 'ハイライト';

  @override
  String get strokeEraser => '消しゴム';

  @override
  String get color => '色';

  @override
  String get undo => '元に戻す';

  @override
  String get clearAll => 'すべて消去';

  @override
  String get syncSynced => '同期済み';

  @override
  String get syncCloud => 'クラウド';

  @override
  String get syncOffline => 'オフライン';

  @override
  String get syncUpdate => '更新';

  @override
  String get syncMissing => '欠落';

  @override
  String get cameraMissing => 'カメラなし';

  @override
  String get key => 'キー';

  @override
  String get device => '端末';

  @override
  String get filePicker => 'ファイル選択';

  @override
  String get noPdf => 'PDFなし';

  @override
  String get emptyPdf => '空のPDFです。再取り込みしてください。';

  @override
  String get noScore => '譜面なし';

  @override
  String stageMeasure(int measure) {
    return '$measure小節';
  }

  @override
  String stageNextSection(String section, int count) {
    return '次 $section · $count小節後';
  }

  @override
  String stageNextSong(String title) {
    return '次 · $title';
  }

  @override
  String get nameRequired => '名前が必要です';

  @override
  String get enterName => '名前を入力してください。';

  @override
  String get endSession => '終了';

  @override
  String get session => 'セッション';

  @override
  String get participants => '参加者';

  @override
  String get song => '曲';

  @override
  String get notify => 'お知らせ';

  @override
  String get onboardingSkip => 'スキップ';

  @override
  String get onboardingNext => '次へ';

  @override
  String get onboardingStart => '練習を始める';

  @override
  String get onboardTitle1 => '譜面は手元に。';

  @override
  String get onboardBody1 => 'PDFを取り込み、ステージでも使えるビューアで練習。';

  @override
  String get onboardTitle2 => '拍に合わせて';

  @override
  String get onboardBody2 => 'メトロノーム・タップ・トレーナー・追従でポケットを締める。';

  @override
  String get onboardTitle3 => '一緒に叩く';

  @override
  String get onboardBody3 => 'セットリストを作り、同じWi-Fiで合奏 — 同じ譜面、同じ拍子。';

  @override
  String get sectionLegal => '規約・サポート';

  @override
  String get privacyPolicy => 'プライバシーポリシー';

  @override
  String get termsOfUse => '利用規約';

  @override
  String get contactSupport => 'サポートに連絡';

  @override
  String get openSourceLicenses => 'オープンソースライセンス';

  @override
  String get replayOnboarding => 'ようこそ画面を再表示';

  @override
  String get couldNotOpenMail => 'メールアプリを開けません';

  @override
  String get privacyBody =>
      'Page-a-Diddleは譜面・セットリスト・練習記録・設定をこの端末に保存します。\n\n任意機能（WebDAV同期・同一Wi-Fi合奏）は、あなたが選んだサーバー／端末にのみデータを送ります。譜面を収集する公式アカウントサーバーは運営しません。\n\nカメラは合奏QRの読み取りのみ、ローカルネットワークは合奏のみに使います。\n\n取り込んだファイルとアプリデータは、アプリ削除またはストレージ消去で削除できます。\n\n問い合わせ: support@page-a-diddle.app\n\n本文は製品向け要約です。ストア公開前に必要なら法務確認を行ってください。';

  @override
  String get termsBody =>
      'Page-a-Diddleの利用により、合法的な個人／業務の音楽練習目的で使うことに同意します。\n\n取り込む譜面・音声・ファイルの権利は利用者の責任です。権限のない素材を取り込まないでください。\n\nアプリは現状有姿で提供され、中断のない動作を保証しません。練習・ステージ利用の責任は利用者にあります。\n\n合奏・WebDAVは利用者のネットワークと設定した外部サーバーに依存します。\n\n規約はアップデートで変わることがあり、更新後の継続利用は改定への同意とみなします。\n\n連絡: support@page-a-diddle.app';

  @override
  String get homeTipTitle => '今日の練習';

  @override
  String get homeTipBody => '譜面を開き、テンポを取り、難しい小節を繰り返そう。';

  @override
  String get retryAction => '再試行';

  @override
  String get hardBadge => '難';

  @override
  String get viewerControlsHint => '上をタップで操作';

  @override
  String get cue => 'キュー';

  @override
  String get sectionLabel => 'セクション';

  @override
  String get tempoMap => 'テンポマップ';

  @override
  String get tempoStep => 'ステップ';

  @override
  String get tempoGradual => '徐々に';

  @override
  String get tempo => 'テンポ';

  @override
  String get bpmHintRange => '40〜240';

  @override
  String get nowLabel => 'いま';

  @override
  String get sectionIntro => 'イントロ';

  @override
  String get sectionVerse => 'ヴァース';

  @override
  String get sectionPre => 'プレコーラス';

  @override
  String get sectionChorus => 'コーラス';

  @override
  String get sectionBridge => 'ブリッジ';

  @override
  String get sectionOutro => 'アウトロ';

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
  String get penHint => 'Tap a line or space to put the note there';

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
  String get barRangeDelete => 'Delete';

  @override
  String get barRangeTranspose => 'Transpose';

  @override
  String semitoneCount(String n) {
    return '$n semitones';
  }

  @override
  String pasteBars(int n) {
    return 'Paste $n copied bars';
  }

  @override
  String barsCopied(int n) {
    return '$n bars copied';
  }

  @override
  String get barRangeInvalid => 'Check the bar numbers';

  @override
  String get pasteBarsNone => 'Paste (no bars copied)';

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
}
