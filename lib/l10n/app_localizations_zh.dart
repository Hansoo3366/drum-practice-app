// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'Page-a-Diddle';

  @override
  String get tagline => '鼓谱练习';

  @override
  String get tabHome => '首页';

  @override
  String get tabLibrary => '曲库';

  @override
  String get tabSetlists => '歌单';

  @override
  String get tabTools => '工具';

  @override
  String get tabJam => '合奏';

  @override
  String get settings => '设置';

  @override
  String get language => '语言';

  @override
  String get theme => '主题';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get languageKorean => '한국어';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageChinese => '中文';

  @override
  String get languageLatin => '拉丁语';

  @override
  String get version => '版本';

  @override
  String get sectionPractice => '练习';

  @override
  String get sectionLibraryStage => '曲库与演出';

  @override
  String get sectionApp => '应用';

  @override
  String get tapTempo => '点击测速';

  @override
  String get tempoTrainer => '速度训练';

  @override
  String get cloudScores => '云端乐谱';

  @override
  String get webDavTechnical => 'WebDAV';

  @override
  String get countIn => '预备拍';

  @override
  String get syncAnchor => '音频锚点';

  @override
  String get followConductor => '跟随指挥';

  @override
  String get returnToLive => '回到实时';

  @override
  String get autoPaused => '已自动暂停';

  @override
  String get followOff => '跟随已关';

  @override
  String get followOn => '跟随中';

  @override
  String get progressFollow => '跟随';

  @override
  String get progressPage => '页';

  @override
  String get resumeLive => '恢复实时';

  @override
  String get progressFollowHint => '随音频与合奏跟踪小节';

  @override
  String get progressPageHint => '仅按页翻动';

  @override
  String get autoPausedHint => '已手动移动 · 点按回到实时';

  @override
  String get roleConductor => '指挥';

  @override
  String get roleMembers => '成员';

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
  String get emptyLibraryTitle => '还没有乐谱';

  @override
  String get emptyLibraryBody => '导入 PDF\n即可开始练习';

  @override
  String get emptyRecentTitle => '没有最近打开的乐谱';

  @override
  String get emptySetlistsTitle => '还没有歌单';

  @override
  String get emptySetlistsBody => '排好练习或演出顺序\n台上即可翻页';

  @override
  String get emptyJamSongs => '还没有曲目';

  @override
  String get emptyJamMembers => '还没有成员';

  @override
  String get loadFailed => '加载失败，请重试。';

  @override
  String get pickFailed => '未能选择文件';

  @override
  String get saveFailed => '未能保存';

  @override
  String get downloadNeeded => '请先下载乐谱';

  @override
  String get offlineMissing => '无离线副本';

  @override
  String get metronome => '节拍器';

  @override
  String get metronomeSubtitle => '拍号 · 重音';

  @override
  String get metronomeSubtitleFull => '拍号 · 重音 · 预备拍';

  @override
  String get openScore => '打开乐谱';

  @override
  String get practiceDeck => '练习工具';

  @override
  String get recentScores => '最近乐谱';

  @override
  String get seeAll => '全部';

  @override
  String get weekPractice => '本周练习';

  @override
  String get weekPracticeHint => '打开乐谱会自动累计练习时间';

  @override
  String get statSessions => '次数';

  @override
  String get statTime => '时长';

  @override
  String get statAverage => '平均';

  @override
  String sessionCountLabel(int count) {
    return '$count次';
  }

  @override
  String get loadingEllipsis => '加载中…';

  @override
  String get loading => '加载中';

  @override
  String get importHintHome => '导入 PDF 开始练习';

  @override
  String get continuePractice => '继续练习';

  @override
  String get greetingMorning => '早上好';

  @override
  String get greetingAfternoon => '下午好';

  @override
  String get greetingEvening => '晚上好';

  @override
  String get relativeJustNow => '刚刚';

  @override
  String relativeMinutesAgo(int minutes) {
    return '$minutes分钟前';
  }

  @override
  String relativeHoursAgo(int hours) {
    return '$hours小时前';
  }

  @override
  String relativeDaysAgo(int days) {
    return '$days天前';
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
    return '$hours小时';
  }

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours小时 $minutes分';
  }

  @override
  String get filterAll => '全部';

  @override
  String get filterPdf => 'PDF';

  @override
  String get filterSmartScore => '电子乐谱';

  @override
  String get filterNativeScore => 'PDF';

  @override
  String get filterDifficult => '难点';

  @override
  String get filterFavorites => '收藏';

  @override
  String get filterRecent => '最近';

  @override
  String get library => '曲库';

  @override
  String get folders => '文件夹';

  @override
  String get allScores => '全部乐谱';

  @override
  String get folder => '文件夹';

  @override
  String get unfiled => '未分类';

  @override
  String get manageFolders => '管理文件夹';

  @override
  String get newFolder => '新建文件夹';

  @override
  String get newSubfolder => '子文件夹';

  @override
  String get folderParent => '上级文件夹';

  @override
  String folderDepthLimit(int max) {
    return '子文件夹最多 $max 层';
  }

  @override
  String get editFolder => '编辑文件夹';

  @override
  String get folderName => '文件夹名称';

  @override
  String get folderNameRequired => '请输入文件夹名称';

  @override
  String get folderColor => '文件夹颜色';

  @override
  String get deleteFolder => '删除文件夹';

  @override
  String get deleteFolderBody => '仅删除文件夹。乐谱会保留为未分类。';

  @override
  String get labels => '标签';

  @override
  String get addLabel => '添加标签';

  @override
  String get labelHint => '#标签';

  @override
  String get noFolder => '无文件夹';

  @override
  String get import => '导入';

  @override
  String get importFrom => '导入来源';

  @override
  String get importFromDevice => '本机';

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
    return '在文件选择器中打开 $provider，然后选择 PDF。';
  }

  @override
  String importCloudHowTitle(String provider) {
    return '从 $provider 选择';
  }

  @override
  String importCloudHowBody(String provider) {
    return '应用内尚未支持登录 $provider。\n\n1. 在本机安装并登录 $provider\n2. 点继续打开系统文件选择器\n3. 打开侧栏(☰)并选择 $provider\n4. 选择 PDF\n\n模拟器通常没有云盘应用，请在真机上试。';
  }

  @override
  String get importCloudViaSystem => '通过系统文件';

  @override
  String get importWebDavViaApp => '应用内登录';

  @override
  String get continueAction => '继续';

  @override
  String get importPdf => '导入 PDF';

  @override
  String get importMusicXml => '导入 PDF';

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
  String get importing => '导入中…';

  @override
  String get importFailed => '导入失败';

  @override
  String get searchHint => '曲目 · 艺人 · BPM · 标签';

  @override
  String get songTitle => '曲名';

  @override
  String get songTitleRequired => '需要曲名';

  @override
  String get artist => '艺人';

  @override
  String get more => '更多';

  @override
  String get favorite => '收藏';

  @override
  String get unfavorite => '取消收藏';

  @override
  String targetBpmShort(int target) {
    return '目标 $target';
  }

  @override
  String libraryCountFilter(int count, String filter) {
    return '$count 首 · $filter';
  }

  @override
  String get smartThumb => '电子';

  @override
  String get newSetlist => '新建歌单';

  @override
  String get create => '创建';

  @override
  String get createScore => '创建乐谱';

  @override
  String get createFailed => '创建失败';

  @override
  String get createSetlist => '创建歌单';

  @override
  String get setlist => '歌单';

  @override
  String get name => '名称';

  @override
  String get save => '保存';

  @override
  String get cancel => '取消';

  @override
  String get delete => '删除';

  @override
  String get remove => '移除';

  @override
  String get rename => '重命名';

  @override
  String get confirmDelete => '要删除吗？';

  @override
  String get addSongs => '添加曲目';

  @override
  String get noSongs => '无曲目';

  @override
  String songAdded(String title) {
    return '已添加 $title';
  }

  @override
  String songCount(int count) {
    return '$count 首';
  }

  @override
  String get stage => '舞台';

  @override
  String get startStage => '开始舞台';

  @override
  String get saveOffline => '离线保存';

  @override
  String get downloadFailed => '下载失败';

  @override
  String get downloadRequired => '需要下载';

  @override
  String savedSongs(int count) {
    return '已保存 $count 首';
  }

  @override
  String savedSongsPartial(int saved, int failed) {
    return '保存 $saved · 失败 $failed';
  }

  @override
  String get changeFailed => '更改失败';

  @override
  String get fetchFailed => '加载失败';

  @override
  String get setlistPromptBody => '请创建练习或演出顺序';

  @override
  String get jam => '合奏';

  @override
  String get jamTagline => '像乐队一样：同一乐谱 · 同一拍号';

  @override
  String get jamHubHint => '在同一 Wi-Fi 创建会话，用代码或二维码邀请';

  @override
  String get activeJams => '进行中的合奏';

  @override
  String get nearbyJams => '附近的房间';

  @override
  String get findNearbyJams => '查找附近';

  @override
  String get noNearbyJams => '在此 Wi-Fi 未找到房间';

  @override
  String get createJam => '创建合奏';

  @override
  String get jamName => '合奏名称';

  @override
  String get join => '加入';

  @override
  String get joinWithCode => '用代码加入';

  @override
  String get code => '代码';

  @override
  String get tapToGoBack => '点按返回';

  @override
  String get inviteCode => '邀请码';

  @override
  String get copy => '复制';

  @override
  String get move => '移动';

  @override
  String get moveToFolder => '移动到文件夹';

  @override
  String get copyToFolder => '复制到文件夹';

  @override
  String selectedCount(int count) {
    return '已选 $count 项';
  }

  @override
  String get deleteSelectedBody => '删除所选乐谱？此操作无法撤销。';

  @override
  String get editSong => '编辑乐谱';

  @override
  String get codeCopied => '已复制代码';

  @override
  String get jamCode => '合奏代码';

  @override
  String get showQr => '显示二维码';

  @override
  String get scanQr => '扫描二维码';

  @override
  String get clickTrack => '节拍音';

  @override
  String get leave => '离开';

  @override
  String get none => '无';

  @override
  String get select => '选择';

  @override
  String get change => '更换';

  @override
  String get previous => '上一首';

  @override
  String get next => '下一首';

  @override
  String get open => '打开';

  @override
  String get play => '播放';

  @override
  String get stop => '停止';

  @override
  String get pause => '暂停';

  @override
  String get connected => '已连接';

  @override
  String get disconnected => '已断开';

  @override
  String get me => '我';

  @override
  String get setlistNotFound => '找不到歌单';

  @override
  String get noOpenableScore => '没有可打开的乐谱';

  @override
  String get jamSessionNotFound => '找不到合奏会话';

  @override
  String get jamNetworkUnavailable => '请打开 Wi-Fi 后重试';

  @override
  String get jamJoinTimedOut => '找不到会话，请检查 Wi-Fi 和代码';

  @override
  String get jamHostUnavailable => '无法连接主机，请检查主机应用和 Wi-Fi';

  @override
  String get jamHostDisconnected => '主机已关闭会话或连接已断开';

  @override
  String get jamBackToHub => '返回合奏列表';

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
  String get toolsWifiSync => '同一 Wi-Fi 合奏';

  @override
  String get toolsGraduallyFaster => '逐渐加快';

  @override
  String get toolsTapForBpm => '点按测 BPM';

  @override
  String get start => '开始';

  @override
  String get preparing => '准备中';

  @override
  String get tapToStart => '点按开始';

  @override
  String get audioError => '音频错误';

  @override
  String get bpmUp => '提高 BPM';

  @override
  String get bpmDown => '降低 BPM';

  @override
  String get meter => '拍号';

  @override
  String get beatUnit => '拍单位';

  @override
  String get accent => '重音';

  @override
  String get double => '加倍';

  @override
  String get halve => '减半';

  @override
  String get reset => '重置';

  @override
  String get tapInput => '输入拍点';

  @override
  String get target => '目标';

  @override
  String get targetReached => '已达目标';

  @override
  String get repetitions => '每阶小节';

  @override
  String get repsDone => '重复完成';

  @override
  String get checkSettings => '请检查设置';

  @override
  String get increase => '递增';

  @override
  String trainerProgress(int current, int total, int beat) {
    return '$current/$total 小节 · $beat拍';
  }

  @override
  String get trainerHint => '从起始速度到目标，每过设定小节数会自动加快。';

  @override
  String trainerPlan(int start, int step, int bars, int target) {
    return '从 $start 开始，每 $bars 小节 +$step，到 $target';
  }

  @override
  String trainerNext(int bpm) {
    return '下一档 $bpm BPM';
  }

  @override
  String trainerStageBars(int current, int total) {
    return '本阶段 $current/$total 小节';
  }

  @override
  String get trainerIdleTitle => '逐步加快熟悉节奏';

  @override
  String get close => '关闭';

  @override
  String get back => '返回';

  @override
  String get done => '完成';

  @override
  String get score => '乐谱';

  @override
  String get openFailed => '打开失败';

  @override
  String get scoreSettings => '乐谱设置';

  @override
  String get music => '音乐';

  @override
  String get metroShort => '节拍';

  @override
  String get view => '视图';

  @override
  String get annotations => '批注';

  @override
  String get playback => '播放';

  @override
  String get attachMusic => '关联音乐';

  @override
  String get playing => '播放中';

  @override
  String get pickFile => '选择文件';

  @override
  String get playbackSpeed => '播放速度';

  @override
  String get loopSection => '区间循环';

  @override
  String get progress => '进度';

  @override
  String get pageLayout => '页面布局';

  @override
  String get autoAdvance => '自动推进';

  @override
  String get returnToCurrent => '回到当前位置';

  @override
  String get currentMeasure => '当前小节';

  @override
  String get notSelected => '未选择';

  @override
  String get nextSong => '下一曲';

  @override
  String get practiceSync => '练习 · 同步';

  @override
  String anchorsCount(int count) {
    return '$count 个';
  }

  @override
  String get pedal => '踏板';

  @override
  String get practiceLog => '练习记录';

  @override
  String get hardMeasures => '难点小节';

  @override
  String get display => '显示';

  @override
  String get showAnnotations => '显示批注';

  @override
  String get clearAnnotations => '清除批注';

  @override
  String get statusBar => '状态栏';

  @override
  String get layoutAuto => '自动 · 横屏双页 / 竖屏滚动';

  @override
  String get layoutFit => '适应';

  @override
  String get layoutTwoUp => '双页';

  @override
  String get layoutScroll => '滚动';

  @override
  String get off => '关';

  @override
  String get wakeLockFailed => '无法保持常亮';

  @override
  String get metronomeError => '节拍器错误';

  @override
  String get haptics => '触感';

  @override
  String get openInMetronome => '在节拍器中打开';

  @override
  String get metronomeStop => '停止节拍器';

  @override
  String get audioConnect => '连接音频';

  @override
  String get anchorLinkHint => '将音乐位置与小节起点对齐。';

  @override
  String get measure => '小节';

  @override
  String get audioSeconds => '音频秒数';

  @override
  String get currentPosition => '当前位置';

  @override
  String get checkTime => '请检查时间';

  @override
  String get deleteAnchorHere => '删除此小节锚点';

  @override
  String get needTwoAnchors => '请先至少保存两个锚点';

  @override
  String get needTwoSectionAnchors => '需要 2 个段落锚点';

  @override
  String get loopRangeHint => '在小节/段落锚点之间循环。';

  @override
  String get loopRange => '循环范围';

  @override
  String get measureRange => '小节范围';

  @override
  String get startMeasure => '起始小节';

  @override
  String get endMeasure => '结束小节';

  @override
  String get startLoop => '开始循环';

  @override
  String get clearLoop => '清除循环';

  @override
  String get label => '标签';

  @override
  String get enterLabel => '请输入标签';

  @override
  String get endRecording => '结束记录';

  @override
  String get startPractice => '开始练习';

  @override
  String get targetBpm => '目标 BPM';

  @override
  String get optional => '可选';

  @override
  String get targetBpmAboveCurrent => '目标 BPM 须不低于当前';

  @override
  String get checkStartTargetBpm => '请检查起始与目标 BPM';

  @override
  String get recent => '最近';

  @override
  String get targetAchieved => '已达成目标';

  @override
  String targetBpmValue(int target) {
    return '目标 $target BPM';
  }

  @override
  String targetRemaining(int delta) {
    return '距目标还差 $delta BPM';
  }

  @override
  String maxBpmLabel(int bpm, String target) {
    return '最高 $bpm BPM$target';
  }

  @override
  String practiceInProgress(int bpm, String date) {
    return '进行中 · $bpm BPM · $date';
  }

  @override
  String inProgressLabel(String target) {
    return '进行中$target';
  }

  @override
  String noneWithTarget(String target) {
    return '无$target';
  }

  @override
  String sessionsWithTarget(int count, String target) {
    return '$count次$target';
  }

  @override
  String targetSuffix(int bpm) {
    return ' · 目标 $bpm BPM';
  }

  @override
  String get progressMode => '推进方式';

  @override
  String get pressKey => '请按键';

  @override
  String get defaults => '默认';

  @override
  String get left => '左';

  @override
  String get right => '右';

  @override
  String get loop => '循环';

  @override
  String meterConfigured(String label) {
    return '$label · 设置';
  }

  @override
  String get timeSignature => '拍号';

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
  String get startBpm => '起始 BPM';

  @override
  String get endBpm => '结束 BPM';

  @override
  String get checkInput => '请检查输入';

  @override
  String get bpmRangeError => 'BPM 必须在 40–240';

  @override
  String get reimportPdf => '请重新导入 PDF。';

  @override
  String get editMeasures => '编辑小节';

  @override
  String get dragAddMeasure => '拖动添加小节';

  @override
  String get deleteMeasure => '删除小节';

  @override
  String get pageNav => '跳转页';

  @override
  String get prevPage => '上一页';

  @override
  String get nextPage => '下一页';

  @override
  String loopMeasures(int start, int end) {
    return '$start–$end 小节';
  }

  @override
  String measureBeat(int measure, int beat) {
    return '第$measure小节 第$beat拍';
  }

  @override
  String practiceStatsLine(int count, String duration, int bpm) {
    return '$count 次 · 共 $duration · 平均 $bpm BPM';
  }

  @override
  String minutesSeconds(int minutes, int seconds) {
    return '$minutes分 $seconds秒';
  }

  @override
  String get songInfo => '曲目信息';

  @override
  String get memo => '备注';

  @override
  String get audio => '音频';

  @override
  String get connect => '连接';

  @override
  String get saving => '保存中…';

  @override
  String get audioAttachFailed => '音频连接失败';

  @override
  String get importPdfScore => '导入 PDF 乐谱';

  @override
  String get cloudSyncHint => '可同步云端乐谱';

  @override
  String get serverAddress => '服务器地址';

  @override
  String get username => '用户名';

  @override
  String get password => '密码';

  @override
  String get enterServerInfo => '输入服务器信息并连接';

  @override
  String get reconnect => '重新连接';

  @override
  String get disconnect => '断开';

  @override
  String get notConnected => '未连接';

  @override
  String get connectedStatus => '已连接';

  @override
  String get checking => '检查中…';

  @override
  String get browseFiles => '浏览文件';

  @override
  String get checkUrl => '请检查地址。';

  @override
  String get cantSaveSettings => '无法保存设置。';

  @override
  String get cantDisconnect => '无法断开连接。';

  @override
  String get cantReadSettings => '无法读取已保存设置。';

  @override
  String get webdavFiles => 'WebDAV 文件';

  @override
  String get webdavNeeded => '需要 WebDAV 连接。';

  @override
  String get cloudOAuthSetupTitle => '未配置云登录';

  @override
  String get cloudOAuthNotConfigured =>
      '请用 --dart-define 添加 DROPBOX_CLIENT_ID 后重新构建。Google Drive 使用应用的 Google 登录配置。';

  @override
  String get cloudDisconnect => '断开连接';

  @override
  String get retry => '重试';

  @override
  String get root => '根目录';

  @override
  String get parentFolder => '上级文件夹';

  @override
  String get emptyFolder => '此文件夹中没有文件';

  @override
  String get addFailed => '添加失败';

  @override
  String get cantSaveSync => '无法保存同步状态。';

  @override
  String get accentStrong => '强';

  @override
  String get accentNormal => '普通';

  @override
  String get accentMute => '静音';

  @override
  String barsLabel(int count) {
    return '$count 小节';
  }

  @override
  String get strokeThin => '细';

  @override
  String get strokeMedium => '中';

  @override
  String get strokeThick => '粗';

  @override
  String get strokeHighlight => '高亮';

  @override
  String get strokeEraser => '橡皮';

  @override
  String get color => '颜色';

  @override
  String get undo => '撤销';

  @override
  String get clearAll => '全部清除';

  @override
  String get syncSynced => '已同步';

  @override
  String get syncCloud => '云端';

  @override
  String get syncOffline => '离线';

  @override
  String get syncUpdate => '更新';

  @override
  String get syncMissing => '缺失';

  @override
  String get cameraMissing => '无相机';

  @override
  String get key => '按键';

  @override
  String get device => '设备';

  @override
  String get filePicker => '文件选择器';

  @override
  String get noPdf => '无 PDF';

  @override
  String get emptyPdf => '空的 PDF，请重新导入。';

  @override
  String get noScore => '无乐谱';

  @override
  String stageMeasure(int measure) {
    return '第$measure小节';
  }

  @override
  String stageNextSection(String section, int count) {
    return '下一 $section · $count 小节后';
  }

  @override
  String stageNextSong(String title) {
    return '下一曲 · $title';
  }

  @override
  String get nameRequired => '需要名称';

  @override
  String get enterName => '请输入名称。';

  @override
  String get endSession => '结束';

  @override
  String get session => '会话';

  @override
  String get participants => '参与者';

  @override
  String get song => '曲目';

  @override
  String get notify => '通知';

  @override
  String get onboardingSkip => '跳过';

  @override
  String get onboardingNext => '下一步';

  @override
  String get onboardingStart => '开始练习';

  @override
  String get onboardTitle1 => '乐谱随身带。';

  @override
  String get onboardBody1 => '导入 PDF，用适合舞台的阅读器练习。';

  @override
  String get onboardTitle2 => '跟上节拍';

  @override
  String get onboardBody2 => '节拍器、点按测速、速度训练与音频跟随，稳住手感。';

  @override
  String get onboardTitle3 => '一起合奏';

  @override
  String get onboardBody3 => '编排歌单，同 Wi-Fi 合奏——同一乐谱、同一拍号。';

  @override
  String get sectionLegal => '条款与支持';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get termsOfUse => '使用条款';

  @override
  String get contactSupport => '联系支持';

  @override
  String get openSourceLicenses => '开源许可';

  @override
  String get replayOnboarding => '再次显示欢迎页';

  @override
  String get couldNotOpenMail => '无法打开邮件应用';

  @override
  String get privacyBody =>
      'Page-a-Diddle 将乐谱、歌单、练习记录与设置保存在本设备。\n\n可选功能（WebDAV 云同步、同一 Wi-Fi 合奏）仅向你指定的服务器或设备发送数据。我们不运营收集乐谱的官方账号服务器。\n\n相机仅用于扫描合奏二维码；本地网络仅用于合奏。\n\n可通过卸载应用或清除存储删除已导入文件与应用数据。\n\n联系：support@page-a-diddle.app\n\n本文为产品说明摘要。上架前如需，请由法律顾问审阅。';

  @override
  String get termsBody =>
      '使用 Page-a-Diddle 即表示你同意将本应用用于合法的个人或专业音乐练习。\n\n你导入的乐谱、音频或文件的权利由你负责。请勿导入无权使用的材料。\n\n应用按现状提供，不保证不间断运行。练习与舞台使用责任由你承担。\n\n合奏与 WebDAV 依赖你的网络及你配置的第三方服务器。\n\n条款可能随应用更新变更；更新后继续使用视为接受修订条款。\n\n联系：support@page-a-diddle.app';

  @override
  String get homeTipTitle => '今日练习';

  @override
  String get homeTipBody => '打开乐谱、定好速度，再循环难点小节。';

  @override
  String get retryAction => '重试';

  @override
  String get hardBadge => '难';

  @override
  String get viewerControlsHint => '点按顶部显示控件';

  @override
  String get cue => '提示点';

  @override
  String get sectionLabel => '段落';

  @override
  String get tempoMap => '速度图';

  @override
  String get tempoStep => '阶跃';

  @override
  String get tempoGradual => '渐变';

  @override
  String get tempo => '速度';

  @override
  String get bpmHintRange => '40–240';

  @override
  String get nowLabel => '当前';

  @override
  String get sectionIntro => '前奏';

  @override
  String get sectionVerse => '主歌';

  @override
  String get sectionPre => '预副歌';

  @override
  String get sectionChorus => '副歌';

  @override
  String get sectionBridge => '桥段';

  @override
  String get sectionOutro => '尾奏';

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
