import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_la.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('ko'),
    Locale('la'),
    Locale('zh'),
  ];

  /// appName
  ///
  /// In en, this message translates to:
  /// **'Page-a-Diddle'**
  String get appName;

  /// tagline
  ///
  /// In en, this message translates to:
  /// **'Drum chart practice'**
  String get tagline;

  /// tabHome
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// tabLibrary
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get tabLibrary;

  /// tabSetlists
  ///
  /// In en, this message translates to:
  /// **'Setlists'**
  String get tabSetlists;

  /// tabTools
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get tabTools;

  /// tabJam
  ///
  /// In en, this message translates to:
  /// **'Jam'**
  String get tabJam;

  /// settings
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// language
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// theme
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// themeSystem
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// themeLight
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// themeDark
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// languageSystem
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// languageKorean
  ///
  /// In en, this message translates to:
  /// **'한국어'**
  String get languageKorean;

  /// languageEnglish
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// languageJapanese
  ///
  /// In en, this message translates to:
  /// **'日本語'**
  String get languageJapanese;

  /// languageChinese
  ///
  /// In en, this message translates to:
  /// **'中文'**
  String get languageChinese;

  /// languageLatin
  ///
  /// In en, this message translates to:
  /// **'Latina'**
  String get languageLatin;

  /// version
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// sectionPractice
  ///
  /// In en, this message translates to:
  /// **'Practice'**
  String get sectionPractice;

  /// sectionLibraryStage
  ///
  /// In en, this message translates to:
  /// **'Library & stage'**
  String get sectionLibraryStage;

  /// sectionApp
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get sectionApp;

  /// tapTempo
  ///
  /// In en, this message translates to:
  /// **'Tap tempo'**
  String get tapTempo;

  /// tempoTrainer
  ///
  /// In en, this message translates to:
  /// **'Tempo trainer'**
  String get tempoTrainer;

  /// cloudScores
  ///
  /// In en, this message translates to:
  /// **'Cloud scores'**
  String get cloudScores;

  /// webDavTechnical
  ///
  /// In en, this message translates to:
  /// **'WebDAV'**
  String get webDavTechnical;

  /// countIn
  ///
  /// In en, this message translates to:
  /// **'Count-in'**
  String get countIn;

  /// syncAnchor
  ///
  /// In en, this message translates to:
  /// **'Audio anchor'**
  String get syncAnchor;

  /// followConductor
  ///
  /// In en, this message translates to:
  /// **'Follow conductor'**
  String get followConductor;

  /// returnToLive
  ///
  /// In en, this message translates to:
  /// **'Return to live'**
  String get returnToLive;

  /// autoPaused
  ///
  /// In en, this message translates to:
  /// **'Auto-paused'**
  String get autoPaused;

  /// followOff
  ///
  /// In en, this message translates to:
  /// **'Follow off'**
  String get followOff;

  /// followOn
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get followOn;

  /// progressFollow
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get progressFollow;

  /// progressPage
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get progressPage;

  /// resumeLive
  ///
  /// In en, this message translates to:
  /// **'Resume live'**
  String get resumeLive;

  /// progressFollowHint
  ///
  /// In en, this message translates to:
  /// **'Follows measures with audio & jam'**
  String get progressFollowHint;

  /// progressPageHint
  ///
  /// In en, this message translates to:
  /// **'Turns pages only'**
  String get progressPageHint;

  /// autoPausedHint
  ///
  /// In en, this message translates to:
  /// **'Moved manually · tap for live'**
  String get autoPausedHint;

  /// roleConductor
  ///
  /// In en, this message translates to:
  /// **'Conductor'**
  String get roleConductor;

  /// roleMembers
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get roleMembers;

  /// jamPart
  ///
  /// In en, this message translates to:
  /// **'Your part'**
  String get jamPart;

  /// jamPartVocal
  ///
  /// In en, this message translates to:
  /// **'Vocals'**
  String get jamPartVocal;

  /// jamPartGuitar
  ///
  /// In en, this message translates to:
  /// **'Guitar'**
  String get jamPartGuitar;

  /// jamPartBass
  ///
  /// In en, this message translates to:
  /// **'Bass'**
  String get jamPartBass;

  /// jamPartDrums
  ///
  /// In en, this message translates to:
  /// **'Drums'**
  String get jamPartDrums;

  /// jamPartKeyboard
  ///
  /// In en, this message translates to:
  /// **'Keyboard'**
  String get jamPartKeyboard;

  /// jamPartOther
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get jamPartOther;

  /// jamPartOtherHint
  ///
  /// In en, this message translates to:
  /// **'Enter your part'**
  String get jamPartOtherHint;

  /// enterOtherPart
  ///
  /// In en, this message translates to:
  /// **'Enter a part'**
  String get enterOtherPart;

  /// emptyLibraryTitle
  ///
  /// In en, this message translates to:
  /// **'No scores yet'**
  String get emptyLibraryTitle;

  /// emptyLibraryBody
  ///
  /// In en, this message translates to:
  /// **'Import a PDF\nto start practicing'**
  String get emptyLibraryBody;

  /// noMatchingScoresTitle
  ///
  /// In en, this message translates to:
  /// **'No scores found'**
  String get noMatchingScoresTitle;

  /// noMatchingScoresBody
  ///
  /// In en, this message translates to:
  /// **'Try another word\nor another filter'**
  String get noMatchingScoresBody;

  /// emptyLibraryBodyPiano
  ///
  /// In en, this message translates to:
  /// **'Bring in a photo or PDF\nand turn it into a score you can play'**
  String get emptyLibraryBodyPiano;

  /// Title of a copied score
  ///
  /// In en, this message translates to:
  /// **'{title} copy'**
  String copyTitle(String title);

  /// renameScoreVersion
  ///
  /// In en, this message translates to:
  /// **'Rename version'**
  String get renameScoreVersion;

  /// arrangementHint
  ///
  /// In en, this message translates to:
  /// **'Heard only while playing. To keep it as notes, use \"Make an instrument score\".'**
  String get arrangementHint;

  /// emptyRecentTitle
  ///
  /// In en, this message translates to:
  /// **'No recent scores'**
  String get emptyRecentTitle;

  /// emptySetlistsTitle
  ///
  /// In en, this message translates to:
  /// **'No setlists'**
  String get emptySetlistsTitle;

  /// emptySetlistsBody
  ///
  /// In en, this message translates to:
  /// **'Build a practice or stage order\nto flip through live'**
  String get emptySetlistsBody;

  /// emptyJamSongs
  ///
  /// In en, this message translates to:
  /// **'No songs yet'**
  String get emptyJamSongs;

  /// emptyJamMembers
  ///
  /// In en, this message translates to:
  /// **'No members yet'**
  String get emptyJamMembers;

  /// loadFailed
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load. Please try again.'**
  String get loadFailed;

  /// pickFailed
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t pick a file'**
  String get pickFailed;

  /// saveFailed
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save'**
  String get saveFailed;

  /// downloadNeeded
  ///
  /// In en, this message translates to:
  /// **'Download the score first'**
  String get downloadNeeded;

  /// offlineMissing
  ///
  /// In en, this message translates to:
  /// **'Not offline'**
  String get offlineMissing;

  /// metronome
  ///
  /// In en, this message translates to:
  /// **'Metronome'**
  String get metronome;

  /// metronomeSubtitle
  ///
  /// In en, this message translates to:
  /// **'Time signature · accents'**
  String get metronomeSubtitle;

  /// metronomeSubtitleFull
  ///
  /// In en, this message translates to:
  /// **'Time signature · accents · count-in'**
  String get metronomeSubtitleFull;

  /// openScore
  ///
  /// In en, this message translates to:
  /// **'Open score'**
  String get openScore;

  /// practiceDeck
  ///
  /// In en, this message translates to:
  /// **'Quick practice'**
  String get practiceDeck;

  /// recentScores
  ///
  /// In en, this message translates to:
  /// **'Recent scores'**
  String get recentScores;

  /// seeAll
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get seeAll;

  /// weekPractice
  ///
  /// In en, this message translates to:
  /// **'This week\'s practice'**
  String get weekPractice;

  /// weekPracticeHint
  ///
  /// In en, this message translates to:
  /// **'Opening a score tracks practice time'**
  String get weekPracticeHint;

  /// statSessions
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get statSessions;

  /// statTime
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get statTime;

  /// statAverage
  ///
  /// In en, this message translates to:
  /// **'Avg'**
  String get statAverage;

  /// sessionCountLabel
  ///
  /// In en, this message translates to:
  /// **'{count}×'**
  String sessionCountLabel(int count);

  /// loadingEllipsis
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loadingEllipsis;

  /// loading
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// importHintHome
  ///
  /// In en, this message translates to:
  /// **'Import a PDF to start practicing'**
  String get importHintHome;

  /// continuePractice
  ///
  /// In en, this message translates to:
  /// **'Continue practicing'**
  String get continuePractice;

  /// greetingMorning
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get greetingMorning;

  /// greetingAfternoon
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get greetingAfternoon;

  /// greetingEvening
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get greetingEvening;

  /// relativeJustNow
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get relativeJustNow;

  /// relativeMinutesAgo
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String relativeMinutesAgo(int minutes);

  /// relativeHoursAgo
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String relativeHoursAgo(int hours);

  /// relativeDaysAgo
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String relativeDaysAgo(int days);

  /// relativeMonthDay
  ///
  /// In en, this message translates to:
  /// **'{month}/{day}'**
  String relativeMonthDay(int month, int day);

  /// durationSeconds
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String durationSeconds(int seconds);

  /// durationMinutes
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String durationMinutes(int minutes);

  /// durationHours
  ///
  /// In en, this message translates to:
  /// **'{hours}h'**
  String durationHours(int hours);

  /// durationHoursMinutes
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String durationHoursMinutes(int hours, int minutes);

  /// filterAll
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// filterPdf
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get filterPdf;

  /// filterSmartScore
  ///
  /// In en, this message translates to:
  /// **'Smart score'**
  String get filterSmartScore;

  /// filterNativeScore
  ///
  /// In en, this message translates to:
  /// **'MusicXML'**
  String get filterNativeScore;

  /// filterDifficult
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get filterDifficult;

  /// filterFavorites
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get filterFavorites;

  /// filterRecent
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get filterRecent;

  /// library
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// folders
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get folders;

  /// allScores
  ///
  /// In en, this message translates to:
  /// **'All scores'**
  String get allScores;

  /// folder
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get folder;

  /// unfiled
  ///
  /// In en, this message translates to:
  /// **'Unfiled'**
  String get unfiled;

  /// manageFolders
  ///
  /// In en, this message translates to:
  /// **'Manage folders'**
  String get manageFolders;

  /// newFolder
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get newFolder;

  /// newSubfolder
  ///
  /// In en, this message translates to:
  /// **'New subfolder'**
  String get newSubfolder;

  /// folderParent
  ///
  /// In en, this message translates to:
  /// **'Parent folder'**
  String get folderParent;

  /// folderDepthLimit
  ///
  /// In en, this message translates to:
  /// **'Subfolders can be nested up to {max} levels'**
  String folderDepthLimit(int max);

  /// editFolder
  ///
  /// In en, this message translates to:
  /// **'Edit folder'**
  String get editFolder;

  /// folderName
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get folderName;

  /// folderNameRequired
  ///
  /// In en, this message translates to:
  /// **'Enter a folder name'**
  String get folderNameRequired;

  /// folderColor
  ///
  /// In en, this message translates to:
  /// **'Folder color'**
  String get folderColor;

  /// deleteFolder
  ///
  /// In en, this message translates to:
  /// **'Delete folder'**
  String get deleteFolder;

  /// deleteFolderBody
  ///
  /// In en, this message translates to:
  /// **'Only this folder is removed. Subfolders move up one level, and scores become unfiled.'**
  String get deleteFolderBody;

  /// labels
  ///
  /// In en, this message translates to:
  /// **'Labels'**
  String get labels;

  /// addLabel
  ///
  /// In en, this message translates to:
  /// **'Add label'**
  String get addLabel;

  /// labelHint
  ///
  /// In en, this message translates to:
  /// **'#tag'**
  String get labelHint;

  /// noFolder
  ///
  /// In en, this message translates to:
  /// **'No folder'**
  String get noFolder;

  /// import
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get import;

  /// importFrom
  ///
  /// In en, this message translates to:
  /// **'Import from'**
  String get importFrom;

  /// importFromDevice
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get importFromDevice;

  /// importFromGoogleDrive
  ///
  /// In en, this message translates to:
  /// **'Google Drive'**
  String get importFromGoogleDrive;

  /// importFromOneDrive
  ///
  /// In en, this message translates to:
  /// **'OneDrive'**
  String get importFromOneDrive;

  /// importFromDropbox
  ///
  /// In en, this message translates to:
  /// **'Dropbox'**
  String get importFromDropbox;

  /// importFromWebDav
  ///
  /// In en, this message translates to:
  /// **'WebDAV'**
  String get importFromWebDav;

  /// importCloudPickerHint
  ///
  /// In en, this message translates to:
  /// **'In the file picker, open {provider} and choose a PDF.'**
  String importCloudPickerHint(String provider);

  /// importCloudHowTitle
  ///
  /// In en, this message translates to:
  /// **'Pick from {provider}'**
  String importCloudHowTitle(String provider);

  /// importCloudHowBody
  ///
  /// In en, this message translates to:
  /// **'This app doesn’t sign into {provider} itself.\n\n1. Install the {provider} app and sign in on this device\n2. Tap Continue to open the system file picker\n3. Open the side menu (☰) and choose {provider}\n4. Select a PDF\n\nEmulators often have no cloud apps — try a real phone.'**
  String importCloudHowBody(String provider);

  /// importCloudViaSystem
  ///
  /// In en, this message translates to:
  /// **'Via system files'**
  String get importCloudViaSystem;

  /// importWebDavViaApp
  ///
  /// In en, this message translates to:
  /// **'Sign in in this app'**
  String get importWebDavViaApp;

  /// continueAction
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// importPdf
  ///
  /// In en, this message translates to:
  /// **'Import PDF'**
  String get importPdf;

  /// importMusicXml
  ///
  /// In en, this message translates to:
  /// **'Import MusicXML'**
  String get importMusicXml;

  /// convertToDigitalScore
  ///
  /// In en, this message translates to:
  /// **'Convert to digital score'**
  String get convertToDigitalScore;

  /// OMR profile for printed scores without chord symbols
  ///
  /// In en, this message translates to:
  /// **'Standard score'**
  String get omrProfileStandard;

  /// OMR profile that recognizes chord symbols and lyrics
  ///
  /// In en, this message translates to:
  /// **'Score with chords and lyrics'**
  String get omrProfileChordsLyrics;

  /// convertingScore
  ///
  /// In en, this message translates to:
  /// **'Converting…'**
  String get convertingScore;

  /// convertingScorePercent
  ///
  /// In en, this message translates to:
  /// **'Converting {percent}%'**
  String convertingScorePercent(int percent);

  /// convertFailed
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t convert. Start the VM and try again.'**
  String get convertFailed;

  /// omrReview
  ///
  /// In en, this message translates to:
  /// **'Conversion review'**
  String get omrReview;

  /// omrHealthScore
  ///
  /// In en, this message translates to:
  /// **'Structure score {score}'**
  String omrHealthScore(int score);

  /// omrReviewEmpty
  ///
  /// In en, this message translates to:
  /// **'No structural problems found.'**
  String get omrReviewEmpty;

  /// omrAiRun
  ///
  /// In en, this message translates to:
  /// **'Run AI review'**
  String get omrAiRun;

  /// omrAiNeedKey
  ///
  /// In en, this message translates to:
  /// **'Paste an XAI_API_KEY to review suspicious measures.'**
  String get omrAiNeedKey;

  /// omrAiSaveKey
  ///
  /// In en, this message translates to:
  /// **'Save key'**
  String get omrAiSaveKey;

  /// importing
  ///
  /// In en, this message translates to:
  /// **'Importing…'**
  String get importing;

  /// importFailed
  ///
  /// In en, this message translates to:
  /// **'Import failed'**
  String get importFailed;

  /// searchHint
  ///
  /// In en, this message translates to:
  /// **'Song · artist · BPM · label'**
  String get searchHint;

  /// songTitle
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get songTitle;

  /// songTitleRequired
  ///
  /// In en, this message translates to:
  /// **'Title required'**
  String get songTitleRequired;

  /// artist
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get artist;

  /// more
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// favorite
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get favorite;

  /// unfavorite
  ///
  /// In en, this message translates to:
  /// **'Remove favorite'**
  String get unfavorite;

  /// targetBpmShort
  ///
  /// In en, this message translates to:
  /// **'Target {target}'**
  String targetBpmShort(int target);

  /// libraryCountFilter
  ///
  /// In en, this message translates to:
  /// **'{count} songs · {filter}'**
  String libraryCountFilter(int count, String filter);

  /// smartThumb
  ///
  /// In en, this message translates to:
  /// **'Smart'**
  String get smartThumb;

  /// newSetlist
  ///
  /// In en, this message translates to:
  /// **'New setlist'**
  String get newSetlist;

  /// create
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// Dialog title when saving a new piano score
  ///
  /// In en, this message translates to:
  /// **'Create score'**
  String get createScore;

  /// createFailed
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create'**
  String get createFailed;

  /// createSetlist
  ///
  /// In en, this message translates to:
  /// **'Create setlist'**
  String get createSetlist;

  /// setlist
  ///
  /// In en, this message translates to:
  /// **'Setlist'**
  String get setlist;

  /// name
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// save
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// cancel
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// delete
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// remove
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// rename
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// confirmDelete
  ///
  /// In en, this message translates to:
  /// **'Delete?'**
  String get confirmDelete;

  /// addSongs
  ///
  /// In en, this message translates to:
  /// **'Add songs'**
  String get addSongs;

  /// noSongs
  ///
  /// In en, this message translates to:
  /// **'No songs'**
  String get noSongs;

  /// convertDone
  ///
  /// In en, this message translates to:
  /// **'{title} converted'**
  String convertDone(String title);

  /// sortRecent
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get sortRecent;

  /// sortTitle
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get sortTitle;

  /// playbackTempo
  ///
  /// In en, this message translates to:
  /// **'Playback speed'**
  String get playbackTempo;

  /// pianoTagline
  ///
  /// In en, this message translates to:
  /// **'Photos and PDFs to digital scores'**
  String get pianoTagline;

  /// privacyBodyPiano
  ///
  /// In en, this message translates to:
  /// **'Worship Easy Peasy keeps your scores, versions and settings on this device. There is no account, and no name or contact is collected.\n\nWhen you convert a score, the photo or PDF you pick is sent to the conversion server (HTTPS). To read and check the score, the server sends parts of the score image to an AI service (Google Gemini). Uploaded files and results are deleted from the server six hours after the conversion ends.\n\nWhen you ask for an AI suggestion, a summary of the chords and sections is sent to the same server and AI service.\n\nTo count daily use, a random identifier made when the app is installed is registered with the server. It is not used to identify a person.\n\nCloud storage (WebDAV, Google Drive, Dropbox) exchanges files only with the places you connect.\n\nNo advertising or analytics tools are used.\n\nContact: support@page-a-diddle.app'**
  String get privacyBodyPiano;

  /// termsBodyPiano
  ///
  /// In en, this message translates to:
  /// **'By using Worship Easy Peasy you agree to use it for lawful personal or professional music practice.\n\nYou are responsible for the rights to the scores and files you import or convert. Do not import or convert material you may not use.\n\nConversion and AI corrections can be wrong. Check the result against the original before relying on it.\n\nThe app is provided as is, without a guarantee of uninterrupted operation.\n\nContact: support@page-a-diddle.app'**
  String get termsBodyPiano;

  /// convertHint
  ///
  /// In en, this message translates to:
  /// **'A photo or PDF of a score'**
  String get convertHint;

  /// scoreGuide
  ///
  /// In en, this message translates to:
  /// **'Screen guide'**
  String get scoreGuide;

  /// scoreGuideTitle
  ///
  /// In en, this message translates to:
  /// **'Screen guide'**
  String get scoreGuideTitle;

  /// scoreGuideIntro
  ///
  /// In en, this message translates to:
  /// **'What the buttons above the score do. You can open this again from Screen guide in the tools menu.'**
  String get scoreGuideIntro;

  /// scoreGuideVersionTitle
  ///
  /// In en, this message translates to:
  /// **'Version (the name beside the title)'**
  String get scoreGuideVersionTitle;

  /// scoreGuideVersionBody
  ///
  /// In en, this message translates to:
  /// **'Switch between the original and the scores you edited or transposed. The original always stays as it is.'**
  String get scoreGuideVersionBody;

  /// scoreGuideOrderBody
  ///
  /// In en, this message translates to:
  /// **'Divide the score into sections such as Verse and Chorus and set the order to play them. You can make a new score in that order.'**
  String get scoreGuideOrderBody;

  /// scoreGuideReviewBody
  ///
  /// In en, this message translates to:
  /// **'The number is how many bars the conversion was unsure of. Open it to compare with the original and take the suggestions you want.'**
  String get scoreGuideReviewBody;

  /// scoreGuideProofreadBody
  ///
  /// In en, this message translates to:
  /// **'Fix wrong chords, lyrics and notes yourself. It is saved as a new version.'**
  String get scoreGuideProofreadBody;

  /// scoreGuidePlayBody
  ///
  /// In en, this message translates to:
  /// **'Listen to the score. Tap a bar to start there, and change the speed on the bar below.'**
  String get scoreGuidePlayBody;

  /// scoreGuideToolsBody
  ///
  /// In en, this message translates to:
  /// **'Transpose, make instrument scores, export PDF or MusicXML, and song information are here.'**
  String get scoreGuideToolsBody;

  /// scoreGuideDone
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get scoreGuideDone;

  /// How to pick several page photos in the system file picker
  ///
  /// In en, this message translates to:
  /// **'For several pages, long-press the first photo and select them together. They become one score.'**
  String get multiPhotoHint;

  /// omrProfileTitle
  ///
  /// In en, this message translates to:
  /// **'What kind of score is it?'**
  String get omrProfileTitle;

  /// omrProfileStandardHint
  ///
  /// In en, this message translates to:
  /// **'Notes only (a piano score)'**
  String get omrProfileStandardHint;

  /// omrProfileChordsLyricsHint
  ///
  /// In en, this message translates to:
  /// **'With chord names and lyrics'**
  String get omrProfileChordsLyricsHint;

  /// omrPhotoTip
  ///
  /// In en, this message translates to:
  /// **'A straight, sharp page reads best.'**
  String get omrPhotoTip;

  /// Bars by their printed numbers, as runs: 5–7, 10
  ///
  /// In en, this message translates to:
  /// **'Bars {bars}'**
  String barNumbers(String bars);

  /// barMenu
  ///
  /// In en, this message translates to:
  /// **'Bar'**
  String get barMenu;

  /// barMenuTooltip
  ///
  /// In en, this message translates to:
  /// **'Edit bar'**
  String get barMenuTooltip;

  /// playBar
  ///
  /// In en, this message translates to:
  /// **'Play from here'**
  String get playBar;

  /// barTooShort
  ///
  /// In en, this message translates to:
  /// **'{beats} beats short of the time'**
  String barTooShort(String beats);

  /// barTooLong
  ///
  /// In en, this message translates to:
  /// **'{beats} beats over the time'**
  String barTooLong(String beats);

  /// lyric
  ///
  /// In en, this message translates to:
  /// **'Lyric'**
  String get lyric;

  /// lyricNextHint
  ///
  /// In en, this message translates to:
  /// **'Next key: on to the next note'**
  String get lyricNextHint;

  /// barEdit
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get barEdit;

  /// listen
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get listen;

  /// erase
  ///
  /// In en, this message translates to:
  /// **'Erase'**
  String get erase;

  /// toolsNote
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get toolsNote;

  /// toolsWords
  ///
  /// In en, this message translates to:
  /// **'Chord · Lyric'**
  String get toolsWords;

  /// toolsLength
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get toolsLength;

  /// toolsPitch
  ///
  /// In en, this message translates to:
  /// **'Pitch'**
  String get toolsPitch;

  /// The bar as the score has it now, beside the original
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get proofreadNow;

  /// How a note is selected in the proofreading editor
  ///
  /// In en, this message translates to:
  /// **'Tap a note to pick it'**
  String get proofreadPick;

  /// songAdded
  ///
  /// In en, this message translates to:
  /// **'{title} added'**
  String songAdded(String title);

  /// songCount
  ///
  /// In en, this message translates to:
  /// **'{count} songs'**
  String songCount(int count);

  /// stage
  ///
  /// In en, this message translates to:
  /// **'Stage'**
  String get stage;

  /// startStage
  ///
  /// In en, this message translates to:
  /// **'Start stage'**
  String get startStage;

  /// saveOffline
  ///
  /// In en, this message translates to:
  /// **'Save offline'**
  String get saveOffline;

  /// downloadFailed
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get downloadFailed;

  /// downloadRequired
  ///
  /// In en, this message translates to:
  /// **'Download needed'**
  String get downloadRequired;

  /// savedSongs
  ///
  /// In en, this message translates to:
  /// **'{count} songs saved'**
  String savedSongs(int count);

  /// savedSongsPartial
  ///
  /// In en, this message translates to:
  /// **'{saved} saved · {failed} failed'**
  String savedSongsPartial(int saved, int failed);

  /// changeFailed
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update'**
  String get changeFailed;

  /// fetchFailed
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load'**
  String get fetchFailed;

  /// setlistPromptBody
  ///
  /// In en, this message translates to:
  /// **'Build a practice or show order'**
  String get setlistPromptBody;

  /// jam
  ///
  /// In en, this message translates to:
  /// **'Jam'**
  String get jam;

  /// jamTagline
  ///
  /// In en, this message translates to:
  /// **'Same chart, same meter — like a band'**
  String get jamTagline;

  /// jamHubHint
  ///
  /// In en, this message translates to:
  /// **'Create a session on the same Wi-Fi and invite with a code or QR'**
  String get jamHubHint;

  /// activeJams
  ///
  /// In en, this message translates to:
  /// **'Active jams'**
  String get activeJams;

  /// nearbyJams
  ///
  /// In en, this message translates to:
  /// **'Nearby rooms'**
  String get nearbyJams;

  /// findNearbyJams
  ///
  /// In en, this message translates to:
  /// **'Find nearby'**
  String get findNearbyJams;

  /// noNearbyJams
  ///
  /// In en, this message translates to:
  /// **'No rooms found on this Wi-Fi'**
  String get noNearbyJams;

  /// createJam
  ///
  /// In en, this message translates to:
  /// **'Create jam'**
  String get createJam;

  /// jamName
  ///
  /// In en, this message translates to:
  /// **'Jam name'**
  String get jamName;

  /// join
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// joinWithCode
  ///
  /// In en, this message translates to:
  /// **'Join with code'**
  String get joinWithCode;

  /// code
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get code;

  /// tapToGoBack
  ///
  /// In en, this message translates to:
  /// **'Tap to go back'**
  String get tapToGoBack;

  /// inviteCode
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get inviteCode;

  /// copy
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// move
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get move;

  /// moveToFolder
  ///
  /// In en, this message translates to:
  /// **'Move to folder'**
  String get moveToFolder;

  /// copyToFolder
  ///
  /// In en, this message translates to:
  /// **'Copy to folder'**
  String get copyToFolder;

  /// selectedCount
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedCount(int count);

  /// deleteSelectedBody
  ///
  /// In en, this message translates to:
  /// **'Delete the selected scores? This can\'t be undone.'**
  String get deleteSelectedBody;

  /// editSong
  ///
  /// In en, this message translates to:
  /// **'Edit song info'**
  String get editSong;

  /// codeCopied
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get codeCopied;

  /// jamCode
  ///
  /// In en, this message translates to:
  /// **'Jam code'**
  String get jamCode;

  /// showQr
  ///
  /// In en, this message translates to:
  /// **'Show QR'**
  String get showQr;

  /// scanQr
  ///
  /// In en, this message translates to:
  /// **'Scan QR'**
  String get scanQr;

  /// clickTrack
  ///
  /// In en, this message translates to:
  /// **'Click sound'**
  String get clickTrack;

  /// leave
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// none
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// select
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// change
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// previous
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// next
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// open
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// play
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// stop
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// pause
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// connected
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// disconnected
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get disconnected;

  /// me
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get me;

  /// setlistNotFound
  ///
  /// In en, this message translates to:
  /// **'Setlist not found'**
  String get setlistNotFound;

  /// noOpenableScore
  ///
  /// In en, this message translates to:
  /// **'No openable score'**
  String get noOpenableScore;

  /// jamSessionNotFound
  ///
  /// In en, this message translates to:
  /// **'Jam session not found'**
  String get jamSessionNotFound;

  /// jamNetworkUnavailable
  ///
  /// In en, this message translates to:
  /// **'Turn on Wi-Fi and try again'**
  String get jamNetworkUnavailable;

  /// jamJoinTimedOut
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t find the session. Check the Wi-Fi and code'**
  String get jamJoinTimedOut;

  /// jamHostUnavailable
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t connect to the host. Check the host app and Wi-Fi'**
  String get jamHostUnavailable;

  /// jamHostDisconnected
  ///
  /// In en, this message translates to:
  /// **'The host closed the session or the connection was lost'**
  String get jamHostDisconnected;

  /// jamBackToHub
  ///
  /// In en, this message translates to:
  /// **'Back to Jam'**
  String get jamBackToHub;

  /// jamLobby
  ///
  /// In en, this message translates to:
  /// **'Jam lobby'**
  String get jamLobby;

  /// ready
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get ready;

  /// readyDone
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get readyDone;

  /// waitingForReady
  ///
  /// In en, this message translates to:
  /// **'Waiting for everyone…'**
  String get waitingForReady;

  /// jamReadyCount
  ///
  /// In en, this message translates to:
  /// **'{ready}/{total} ready'**
  String jamReadyCount(int ready, int total);

  /// jamNotReady
  ///
  /// In en, this message translates to:
  /// **'Wait until everyone is ready'**
  String get jamNotReady;

  /// toolsWifiSync
  ///
  /// In en, this message translates to:
  /// **'Jam on Wi-Fi'**
  String get toolsWifiSync;

  /// toolsGraduallyFaster
  ///
  /// In en, this message translates to:
  /// **'Ramp up speed'**
  String get toolsGraduallyFaster;

  /// toolsTapForBpm
  ///
  /// In en, this message translates to:
  /// **'Tap to find BPM'**
  String get toolsTapForBpm;

  /// start
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// preparing
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get preparing;

  /// tapToStart
  ///
  /// In en, this message translates to:
  /// **'Tap to start'**
  String get tapToStart;

  /// audioError
  ///
  /// In en, this message translates to:
  /// **'Audio error'**
  String get audioError;

  /// bpmUp
  ///
  /// In en, this message translates to:
  /// **'Increase BPM'**
  String get bpmUp;

  /// bpmDown
  ///
  /// In en, this message translates to:
  /// **'Decrease BPM'**
  String get bpmDown;

  /// meter
  ///
  /// In en, this message translates to:
  /// **'Time signature'**
  String get meter;

  /// beatUnit
  ///
  /// In en, this message translates to:
  /// **'Subdivision'**
  String get beatUnit;

  /// accent
  ///
  /// In en, this message translates to:
  /// **'Accent'**
  String get accent;

  /// double
  ///
  /// In en, this message translates to:
  /// **'Double'**
  String get double;

  /// halve
  ///
  /// In en, this message translates to:
  /// **'Half tempo'**
  String get halve;

  /// reset
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// tapInput
  ///
  /// In en, this message translates to:
  /// **'Tap the beat'**
  String get tapInput;

  /// target
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get target;

  /// targetReached
  ///
  /// In en, this message translates to:
  /// **'Target reached'**
  String get targetReached;

  /// repetitions
  ///
  /// In en, this message translates to:
  /// **'Bars / step'**
  String get repetitions;

  /// repsDone
  ///
  /// In en, this message translates to:
  /// **'Reps done'**
  String get repsDone;

  /// checkSettings
  ///
  /// In en, this message translates to:
  /// **'Check your settings'**
  String get checkSettings;

  /// increase
  ///
  /// In en, this message translates to:
  /// **'Step'**
  String get increase;

  /// trainerProgress
  ///
  /// In en, this message translates to:
  /// **'{current}/{total} bars · beat {beat}'**
  String trainerProgress(int current, int total, int beat);

  /// trainerHint
  ///
  /// In en, this message translates to:
  /// **'Tempo rises automatically every N bars until you hit the target.'**
  String get trainerHint;

  /// trainerPlan
  ///
  /// In en, this message translates to:
  /// **'Start at {start}, +{step} every {bars} bars, up to {target}'**
  String trainerPlan(int start, int step, int bars, int target);

  /// trainerNext
  ///
  /// In en, this message translates to:
  /// **'Next {bpm} BPM'**
  String trainerNext(int bpm);

  /// trainerStageBars
  ///
  /// In en, this message translates to:
  /// **'This stage {current}/{total} bars'**
  String trainerStageBars(int current, int total);

  /// trainerIdleTitle
  ///
  /// In en, this message translates to:
  /// **'Climb the tempo'**
  String get trainerIdleTitle;

  /// close
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// back
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// done
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// score
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get score;

  /// openFailed
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open'**
  String get openFailed;

  /// scoreSettings
  ///
  /// In en, this message translates to:
  /// **'Score settings'**
  String get scoreSettings;

  /// music
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get music;

  /// metroShort
  ///
  /// In en, this message translates to:
  /// **'Metro'**
  String get metroShort;

  /// view
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// annotations
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get annotations;

  /// playback
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get playback;

  /// attachMusic
  ///
  /// In en, this message translates to:
  /// **'Attach music'**
  String get attachMusic;

  /// playing
  ///
  /// In en, this message translates to:
  /// **'Playing'**
  String get playing;

  /// pickFile
  ///
  /// In en, this message translates to:
  /// **'Choose file'**
  String get pickFile;

  /// playbackSpeed
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get playbackSpeed;

  /// loopSection
  ///
  /// In en, this message translates to:
  /// **'Loop'**
  String get loopSection;

  /// progress
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// pageLayout
  ///
  /// In en, this message translates to:
  /// **'Page layout'**
  String get pageLayout;

  /// autoAdvance
  ///
  /// In en, this message translates to:
  /// **'Auto advance'**
  String get autoAdvance;

  /// returnToCurrent
  ///
  /// In en, this message translates to:
  /// **'Return to position'**
  String get returnToCurrent;

  /// currentMeasure
  ///
  /// In en, this message translates to:
  /// **'Current measure'**
  String get currentMeasure;

  /// notSelected
  ///
  /// In en, this message translates to:
  /// **'Not selected'**
  String get notSelected;

  /// nextSong
  ///
  /// In en, this message translates to:
  /// **'Next song'**
  String get nextSong;

  /// practiceSync
  ///
  /// In en, this message translates to:
  /// **'Practice · sync'**
  String get practiceSync;

  /// anchorsCount
  ///
  /// In en, this message translates to:
  /// **'{count}'**
  String anchorsCount(int count);

  /// pedal
  ///
  /// In en, this message translates to:
  /// **'Pedal'**
  String get pedal;

  /// practiceLog
  ///
  /// In en, this message translates to:
  /// **'Practice log'**
  String get practiceLog;

  /// hardMeasures
  ///
  /// In en, this message translates to:
  /// **'Hard measures'**
  String get hardMeasures;

  /// display
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get display;

  /// showAnnotations
  ///
  /// In en, this message translates to:
  /// **'Show notes'**
  String get showAnnotations;

  /// clearAnnotations
  ///
  /// In en, this message translates to:
  /// **'Clear notes'**
  String get clearAnnotations;

  /// statusBar
  ///
  /// In en, this message translates to:
  /// **'Status bar'**
  String get statusBar;

  /// layoutAuto
  ///
  /// In en, this message translates to:
  /// **'Auto · 2-up landscape / scroll portrait'**
  String get layoutAuto;

  /// layoutFit
  ///
  /// In en, this message translates to:
  /// **'Fit'**
  String get layoutFit;

  /// layoutTwoUp
  ///
  /// In en, this message translates to:
  /// **'2-up'**
  String get layoutTwoUp;

  /// layoutScroll
  ///
  /// In en, this message translates to:
  /// **'Scroll'**
  String get layoutScroll;

  /// off
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// wakeLockFailed
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t keep screen on'**
  String get wakeLockFailed;

  /// metronomeError
  ///
  /// In en, this message translates to:
  /// **'Metronome error'**
  String get metronomeError;

  /// haptics
  ///
  /// In en, this message translates to:
  /// **'Haptics'**
  String get haptics;

  /// openInMetronome
  ///
  /// In en, this message translates to:
  /// **'Open in metronome'**
  String get openInMetronome;

  /// metronomeStop
  ///
  /// In en, this message translates to:
  /// **'Stop metronome'**
  String get metronomeStop;

  /// audioConnect
  ///
  /// In en, this message translates to:
  /// **'Attach audio'**
  String get audioConnect;

  /// anchorLinkHint
  ///
  /// In en, this message translates to:
  /// **'Link music position to a measure start.'**
  String get anchorLinkHint;

  /// measure
  ///
  /// In en, this message translates to:
  /// **'Measure'**
  String get measure;

  /// audioSeconds
  ///
  /// In en, this message translates to:
  /// **'Audio seconds'**
  String get audioSeconds;

  /// currentPosition
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get currentPosition;

  /// checkTime
  ///
  /// In en, this message translates to:
  /// **'Check the time'**
  String get checkTime;

  /// deleteAnchorHere
  ///
  /// In en, this message translates to:
  /// **'Delete anchor here'**
  String get deleteAnchorHere;

  /// needTwoAnchors
  ///
  /// In en, this message translates to:
  /// **'Save at least two anchors first'**
  String get needTwoAnchors;

  /// needTwoSectionAnchors
  ///
  /// In en, this message translates to:
  /// **'Need 2 section anchors'**
  String get needTwoSectionAnchors;

  /// loopRangeHint
  ///
  /// In en, this message translates to:
  /// **'Loops between measure/section anchors.'**
  String get loopRangeHint;

  /// loopRange
  ///
  /// In en, this message translates to:
  /// **'Loop range'**
  String get loopRange;

  /// measureRange
  ///
  /// In en, this message translates to:
  /// **'Measure range'**
  String get measureRange;

  /// startMeasure
  ///
  /// In en, this message translates to:
  /// **'Start measure'**
  String get startMeasure;

  /// endMeasure
  ///
  /// In en, this message translates to:
  /// **'End measure'**
  String get endMeasure;

  /// startLoop
  ///
  /// In en, this message translates to:
  /// **'Start loop'**
  String get startLoop;

  /// clearLoop
  ///
  /// In en, this message translates to:
  /// **'Clear loop'**
  String get clearLoop;

  /// label
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get label;

  /// enterLabel
  ///
  /// In en, this message translates to:
  /// **'Enter a label'**
  String get enterLabel;

  /// endRecording
  ///
  /// In en, this message translates to:
  /// **'End log'**
  String get endRecording;

  /// startPractice
  ///
  /// In en, this message translates to:
  /// **'Start practice'**
  String get startPractice;

  /// targetBpm
  ///
  /// In en, this message translates to:
  /// **'Target BPM'**
  String get targetBpm;

  /// optional
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// targetBpmAboveCurrent
  ///
  /// In en, this message translates to:
  /// **'Target BPM must be ≥ current'**
  String get targetBpmAboveCurrent;

  /// checkStartTargetBpm
  ///
  /// In en, this message translates to:
  /// **'Check start & target BPM'**
  String get checkStartTargetBpm;

  /// recent
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recent;

  /// targetAchieved
  ///
  /// In en, this message translates to:
  /// **'Target hit'**
  String get targetAchieved;

  /// targetBpmValue
  ///
  /// In en, this message translates to:
  /// **'Target {target} BPM'**
  String targetBpmValue(int target);

  /// targetRemaining
  ///
  /// In en, this message translates to:
  /// **'{delta} BPM to target'**
  String targetRemaining(int delta);

  /// maxBpmLabel
  ///
  /// In en, this message translates to:
  /// **'Best {bpm} BPM{target}'**
  String maxBpmLabel(int bpm, String target);

  /// practiceInProgress
  ///
  /// In en, this message translates to:
  /// **'In progress · {bpm} BPM · {date}'**
  String practiceInProgress(int bpm, String date);

  /// inProgressLabel
  ///
  /// In en, this message translates to:
  /// **'In progress{target}'**
  String inProgressLabel(String target);

  /// noneWithTarget
  ///
  /// In en, this message translates to:
  /// **'None{target}'**
  String noneWithTarget(String target);

  /// sessionsWithTarget
  ///
  /// In en, this message translates to:
  /// **'{count}×{target}'**
  String sessionsWithTarget(int count, String target);

  /// targetSuffix
  ///
  /// In en, this message translates to:
  /// **' · target {bpm} BPM'**
  String targetSuffix(int bpm);

  /// progressMode
  ///
  /// In en, this message translates to:
  /// **'Advance mode'**
  String get progressMode;

  /// pressKey
  ///
  /// In en, this message translates to:
  /// **'Press a key'**
  String get pressKey;

  /// defaults
  ///
  /// In en, this message translates to:
  /// **'Defaults'**
  String get defaults;

  /// left
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get left;

  /// right
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get right;

  /// loop
  ///
  /// In en, this message translates to:
  /// **'Loop'**
  String get loop;

  /// meterConfigured
  ///
  /// In en, this message translates to:
  /// **'{label} · settings'**
  String meterConfigured(String label);

  /// timeSignature
  ///
  /// In en, this message translates to:
  /// **'Time signature'**
  String get timeSignature;

  /// Time signature notation
  ///
  /// In en, this message translates to:
  /// **'Notation'**
  String get timeSignatureNotation;

  /// Numeric time signature notation
  ///
  /// In en, this message translates to:
  /// **'Numbers'**
  String get timeSignatureNumbers;

  /// Common time symbol
  ///
  /// In en, this message translates to:
  /// **'Common time (C)'**
  String get commonTime;

  /// Cut time symbol
  ///
  /// In en, this message translates to:
  /// **'Alla breve (¢)'**
  String get allaBreve;

  /// numerator
  ///
  /// In en, this message translates to:
  /// **'Numerator'**
  String get numerator;

  /// denominator
  ///
  /// In en, this message translates to:
  /// **'Denominator'**
  String get denominator;

  /// startBpm
  ///
  /// In en, this message translates to:
  /// **'Start BPM'**
  String get startBpm;

  /// endBpm
  ///
  /// In en, this message translates to:
  /// **'End BPM'**
  String get endBpm;

  /// checkInput
  ///
  /// In en, this message translates to:
  /// **'Check input'**
  String get checkInput;

  /// bpmRangeError
  ///
  /// In en, this message translates to:
  /// **'BPM must be 40–240'**
  String get bpmRangeError;

  /// reimportPdf
  ///
  /// In en, this message translates to:
  /// **'Re-import the PDF.'**
  String get reimportPdf;

  /// editMeasures
  ///
  /// In en, this message translates to:
  /// **'Edit measures'**
  String get editMeasures;

  /// dragAddMeasure
  ///
  /// In en, this message translates to:
  /// **'Drag to add a measure'**
  String get dragAddMeasure;

  /// deleteMeasure
  ///
  /// In en, this message translates to:
  /// **'Delete measure'**
  String get deleteMeasure;

  /// pageNav
  ///
  /// In en, this message translates to:
  /// **'Go to page'**
  String get pageNav;

  /// prevPage
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get prevPage;

  /// nextPage
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get nextPage;

  /// loopMeasures
  ///
  /// In en, this message translates to:
  /// **'{start}–{end} measures'**
  String loopMeasures(int start, int end);

  /// measureBeat
  ///
  /// In en, this message translates to:
  /// **'m{measure} beat {beat}'**
  String measureBeat(int measure, int beat);

  /// practiceStatsLine
  ///
  /// In en, this message translates to:
  /// **'{count}× · total {duration} · avg {bpm} BPM'**
  String practiceStatsLine(int count, String duration, int bpm);

  /// minutesSeconds
  ///
  /// In en, this message translates to:
  /// **'{minutes}m {seconds}s'**
  String minutesSeconds(int minutes, int seconds);

  /// songInfo
  ///
  /// In en, this message translates to:
  /// **'Song info'**
  String get songInfo;

  /// memo
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get memo;

  /// audio
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get audio;

  /// connect
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// saving
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// audioAttachFailed
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t attach audio'**
  String get audioAttachFailed;

  /// importPdfScore
  ///
  /// In en, this message translates to:
  /// **'Import PDF score'**
  String get importPdfScore;

  /// cloudSyncHint
  ///
  /// In en, this message translates to:
  /// **'Sync cloud scores'**
  String get cloudSyncHint;

  /// serverAddress
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get serverAddress;

  /// username
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// password
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// enterServerInfo
  ///
  /// In en, this message translates to:
  /// **'Enter server details and connect'**
  String get enterServerInfo;

  /// reconnect
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get reconnect;

  /// disconnect
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// notConnected
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get notConnected;

  /// connectedStatus
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connectedStatus;

  /// checking
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get checking;

  /// browseFiles
  ///
  /// In en, this message translates to:
  /// **'Browse files'**
  String get browseFiles;

  /// checkUrl
  ///
  /// In en, this message translates to:
  /// **'Check the URL'**
  String get checkUrl;

  /// cantSaveSettings
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save settings.'**
  String get cantSaveSettings;

  /// cantDisconnect
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t disconnect.'**
  String get cantDisconnect;

  /// cantReadSettings
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read saved settings.'**
  String get cantReadSettings;

  /// webdavFiles
  ///
  /// In en, this message translates to:
  /// **'WebDAV files'**
  String get webdavFiles;

  /// webdavNeeded
  ///
  /// In en, this message translates to:
  /// **'WebDAV connection required.'**
  String get webdavNeeded;

  /// cloudOAuthSetupTitle
  ///
  /// In en, this message translates to:
  /// **'Cloud login not set up'**
  String get cloudOAuthSetupTitle;

  /// cloudOAuthNotConfigured
  ///
  /// In en, this message translates to:
  /// **'Add DROPBOX_CLIENT_ID with --dart-define, then rebuild. Google Drive uses the app’s Google Sign-In setup.'**
  String get cloudOAuthNotConfigured;

  /// cloudDisconnect
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get cloudDisconnect;

  /// retry
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// root
  ///
  /// In en, this message translates to:
  /// **'Root'**
  String get root;

  /// parentFolder
  ///
  /// In en, this message translates to:
  /// **'Up'**
  String get parentFolder;

  /// emptyFolder
  ///
  /// In en, this message translates to:
  /// **'No files in this folder'**
  String get emptyFolder;

  /// addFailed
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add'**
  String get addFailed;

  /// cantSaveSync
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save sync status.'**
  String get cantSaveSync;

  /// accentStrong
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get accentStrong;

  /// accentNormal
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get accentNormal;

  /// accentMute
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get accentMute;

  /// barsLabel
  ///
  /// In en, this message translates to:
  /// **'{count} bars'**
  String barsLabel(int count);

  /// strokeThin
  ///
  /// In en, this message translates to:
  /// **'Thin'**
  String get strokeThin;

  /// strokeMedium
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get strokeMedium;

  /// strokeThick
  ///
  /// In en, this message translates to:
  /// **'Thick'**
  String get strokeThick;

  /// strokeHighlight
  ///
  /// In en, this message translates to:
  /// **'Highlight'**
  String get strokeHighlight;

  /// strokeEraser
  ///
  /// In en, this message translates to:
  /// **'Eraser'**
  String get strokeEraser;

  /// color
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get color;

  /// undo
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// clearAll
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get clearAll;

  /// syncSynced
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get syncSynced;

  /// syncCloud
  ///
  /// In en, this message translates to:
  /// **'Cloud'**
  String get syncCloud;

  /// syncOffline
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get syncOffline;

  /// syncUpdate
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get syncUpdate;

  /// syncMissing
  ///
  /// In en, this message translates to:
  /// **'Missing'**
  String get syncMissing;

  /// cameraMissing
  ///
  /// In en, this message translates to:
  /// **'No camera'**
  String get cameraMissing;

  /// key
  ///
  /// In en, this message translates to:
  /// **'Key'**
  String get key;

  /// device
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get device;

  /// filePicker
  ///
  /// In en, this message translates to:
  /// **'File picker'**
  String get filePicker;

  /// noPdf
  ///
  /// In en, this message translates to:
  /// **'No PDF'**
  String get noPdf;

  /// emptyPdf
  ///
  /// In en, this message translates to:
  /// **'Empty PDF. Re-import it.'**
  String get emptyPdf;

  /// noScore
  ///
  /// In en, this message translates to:
  /// **'No score'**
  String get noScore;

  /// stageMeasure
  ///
  /// In en, this message translates to:
  /// **'m{measure}'**
  String stageMeasure(int measure);

  /// stageNextSection
  ///
  /// In en, this message translates to:
  /// **'Next {section} · in {count} measures'**
  String stageNextSection(String section, int count);

  /// stageNextSong
  ///
  /// In en, this message translates to:
  /// **'Next · {title}'**
  String stageNextSong(String title);

  /// nameRequired
  ///
  /// In en, this message translates to:
  /// **'Name required'**
  String get nameRequired;

  /// enterName
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get enterName;

  /// endSession
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get endSession;

  /// session
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get session;

  /// participants
  ///
  /// In en, this message translates to:
  /// **'Participants'**
  String get participants;

  /// song
  ///
  /// In en, this message translates to:
  /// **'Song'**
  String get song;

  /// notify
  ///
  /// In en, this message translates to:
  /// **'Notice'**
  String get notify;

  /// onboardingSkip
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// onboardingNext
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// onboardingStart
  ///
  /// In en, this message translates to:
  /// **'Start practicing'**
  String get onboardingStart;

  /// onboardTitle1
  ///
  /// In en, this message translates to:
  /// **'Your charts. Your pocket.'**
  String get onboardTitle1;

  /// onboardBody1
  ///
  /// In en, this message translates to:
  /// **'Import a PDF and practice with a stage-ready viewer.'**
  String get onboardBody1;

  /// onboardTitle2
  ///
  /// In en, this message translates to:
  /// **'Stay in time'**
  String get onboardTitle2;

  /// onboardBody2
  ///
  /// In en, this message translates to:
  /// **'Metronome, tap tempo, tempo trainer, and audio follow keep the pocket tight.'**
  String get onboardBody2;

  /// onboardTitle3
  ///
  /// In en, this message translates to:
  /// **'Play together'**
  String get onboardTitle3;

  /// onboardBody3
  ///
  /// In en, this message translates to:
  /// **'Build setlists and jam on the same Wi-Fi — same chart, same meter.'**
  String get onboardBody3;

  /// sectionLegal
  ///
  /// In en, this message translates to:
  /// **'Legal & support'**
  String get sectionLegal;

  /// privacyPolicy
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// termsOfUse
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get termsOfUse;

  /// contactSupport
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get contactSupport;

  /// openSourceLicenses
  ///
  /// In en, this message translates to:
  /// **'Open-source licenses'**
  String get openSourceLicenses;

  /// replayOnboarding
  ///
  /// In en, this message translates to:
  /// **'Show welcome again'**
  String get replayOnboarding;

  /// couldNotOpenMail
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open mail app'**
  String get couldNotOpenMail;

  /// privacyBody
  ///
  /// In en, this message translates to:
  /// **'Page-a-Diddle stores your scores, setlists, practice logs, and settings on this device.\n\nOptional features (cloud WebDAV sync and local-network jam) send data only to servers or devices you choose. We do not run a Page-a-Diddle account server that collects your charts.\n\nCamera access is used only to scan jam QR codes. Local network access is used only for jam sessions on your Wi-Fi.\n\nYou can delete imported files and app data by removing the app or clearing app storage.\n\nFor privacy questions: support@page-a-diddle.app\n\nThis summary is provided for product clarity. Have counsel review it before store publication if required in your region.'**
  String get privacyBody;

  /// termsBody
  ///
  /// In en, this message translates to:
  /// **'By using Page-a-Diddle you agree to use the app for lawful personal or professional music practice.\n\nYou are responsible for the rights to any scores, audio, or files you import. Do not import material you are not allowed to use.\n\nThe app is provided as-is without warranties of uninterrupted performance. Practice and stage use remain your responsibility.\n\nJam and WebDAV features depend on your network and third-party servers you configure.\n\nWe may update these terms with app updates. Continued use after an update means you accept the revised terms.\n\nContact: support@page-a-diddle.app'**
  String get termsBody;

  /// homeTipTitle
  ///
  /// In en, this message translates to:
  /// **'Today\'s practice'**
  String get homeTipTitle;

  /// homeTipBody
  ///
  /// In en, this message translates to:
  /// **'Open a chart, tap a tempo, then loop the hard bars.'**
  String get homeTipBody;

  /// retryAction
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retryAction;

  /// hardBadge
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get hardBadge;

  /// viewerControlsHint
  ///
  /// In en, this message translates to:
  /// **'Tap top for controls'**
  String get viewerControlsHint;

  /// cue
  ///
  /// In en, this message translates to:
  /// **'Cue'**
  String get cue;

  /// sectionLabel
  ///
  /// In en, this message translates to:
  /// **'Section'**
  String get sectionLabel;

  /// tempoMap
  ///
  /// In en, this message translates to:
  /// **'Tempo map'**
  String get tempoMap;

  /// tempoStep
  ///
  /// In en, this message translates to:
  /// **'Step'**
  String get tempoStep;

  /// tempoGradual
  ///
  /// In en, this message translates to:
  /// **'Gradual'**
  String get tempoGradual;

  /// tempo
  ///
  /// In en, this message translates to:
  /// **'Tempo'**
  String get tempo;

  /// bpmHintRange
  ///
  /// In en, this message translates to:
  /// **'40–240'**
  String get bpmHintRange;

  /// nowLabel
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get nowLabel;

  /// sectionIntro
  ///
  /// In en, this message translates to:
  /// **'Intro'**
  String get sectionIntro;

  /// sectionVerse
  ///
  /// In en, this message translates to:
  /// **'Verse'**
  String get sectionVerse;

  /// sectionPre
  ///
  /// In en, this message translates to:
  /// **'Pre-chorus'**
  String get sectionPre;

  /// sectionChorus
  ///
  /// In en, this message translates to:
  /// **'Chorus'**
  String get sectionChorus;

  /// sectionBridge
  ///
  /// In en, this message translates to:
  /// **'Bridge'**
  String get sectionBridge;

  /// sectionOutro
  ///
  /// In en, this message translates to:
  /// **'Outro'**
  String get sectionOutro;

  /// Export a flattened PDF containing pen annotations
  ///
  /// In en, this message translates to:
  /// **'Export annotated PDF'**
  String get exportAnnotatedPdf;

  /// Annotated PDF export explanation
  ///
  /// In en, this message translates to:
  /// **'Save a new PDF and keep the original unchanged'**
  String get exportAnnotatedPdfSubtitle;

  /// Annotated PDF export progress
  ///
  /// In en, this message translates to:
  /// **'Adding notes to the PDF…'**
  String get exportingAnnotatedPdf;

  /// Annotated PDF export success
  ///
  /// In en, this message translates to:
  /// **'Annotated PDF saved'**
  String get annotatedPdfExported;

  /// Annotated PDF export failure
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t export the PDF'**
  String get annotatedPdfExportFailed;

  /// Open or close MusicXML score editing controls
  ///
  /// In en, this message translates to:
  /// **'Edit score'**
  String get scoreEdit;

  /// Edit the original score file
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get scoreOriginal;

  /// Legacy performance copy label
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get scorePerformance;

  /// Create a new editable score version from the current score
  ///
  /// In en, this message translates to:
  /// **'Add version'**
  String get addScoreVersion;

  /// Hint for naming a score version
  ///
  /// In en, this message translates to:
  /// **'Version name'**
  String get scoreVersionName;

  /// Delete the selected score version
  ///
  /// In en, this message translates to:
  /// **'Delete version'**
  String get deleteScoreVersion;

  /// Default name for a newly created score version
  ///
  /// In en, this message translates to:
  /// **'Version {n}'**
  String scoreVersionN(int n);

  /// Copy the selected measure after itself
  ///
  /// In en, this message translates to:
  /// **'Duplicate measure'**
  String get duplicateMeasure;

  /// Drag the selected measure to a new place
  ///
  /// In en, this message translates to:
  /// **'Move measure'**
  String get dragMeasure;

  /// Musical note
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// Musical rest
  ///
  /// In en, this message translates to:
  /// **'Rest'**
  String get rest;

  /// Harmony chord symbol
  ///
  /// In en, this message translates to:
  /// **'Chord'**
  String get chordSymbol;

  /// No description provided for @barTexts.
  ///
  /// In en, this message translates to:
  /// **'Text in this bar'**
  String get barTexts;

  /// No description provided for @showOriginal.
  ///
  /// In en, this message translates to:
  /// **'Show original'**
  String get showOriginal;

  /// No description provided for @originalBar.
  ///
  /// In en, this message translates to:
  /// **'Original of this bar'**
  String get originalBar;

  /// No description provided for @noOriginalBar.
  ///
  /// In en, this message translates to:
  /// **'This bar is not on the original.'**
  String get noOriginalBar;

  /// No description provided for @barTextsHint.
  ///
  /// In en, this message translates to:
  /// **'Text read from the page that is not a chord, a lyric or a note. Correct or remove what was misread.'**
  String get barTextsHint;

  /// Add a musical note
  ///
  /// In en, this message translates to:
  /// **'Add note'**
  String get addNote;

  /// Add a musical rest
  ///
  /// In en, this message translates to:
  /// **'Add rest'**
  String get addRest;

  /// Add a harmony chord symbol
  ///
  /// In en, this message translates to:
  /// **'Add chord'**
  String get addChordSymbol;

  /// Add another pitch at the current beat
  ///
  /// In en, this message translates to:
  /// **'Chord tone'**
  String get addChordTone;

  /// Lengthen the selected duration with an augmentation dot
  ///
  /// In en, this message translates to:
  /// **'Dotted'**
  String get dottedDuration;

  /// Raise the selected note by a semitone
  ///
  /// In en, this message translates to:
  /// **'Semitone up'**
  String get pitchUp;

  /// Lower the selected note by a semitone
  ///
  /// In en, this message translates to:
  /// **'Semitone down'**
  String get pitchDown;

  /// Raise the selected note by an octave
  ///
  /// In en, this message translates to:
  /// **'Octave up'**
  String get octaveUp;

  /// Lower the selected note by an octave
  ///
  /// In en, this message translates to:
  /// **'Octave down'**
  String get octaveDown;

  /// Default title for a newly created piano score
  ///
  /// In en, this message translates to:
  /// **'New piano score'**
  String get newPianoScore;

  /// Short visible label for inserting a measure
  ///
  /// In en, this message translates to:
  /// **'Add measure'**
  String get addMeasure;

  /// Increase score page zoom
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get zoomIn;

  /// Decrease score page zoom
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get zoomOut;

  /// Edit the selected score event
  ///
  /// In en, this message translates to:
  /// **'Edit selected'**
  String get editSelected;

  /// Delete the selected score event
  ///
  /// In en, this message translates to:
  /// **'Delete selected'**
  String get deleteSelectedEvent;

  /// Edit key and time signature
  ///
  /// In en, this message translates to:
  /// **'Measure settings'**
  String get measureSettings;

  /// Insert a measure after the current measure
  ///
  /// In en, this message translates to:
  /// **'Insert next measure'**
  String get insertMeasureAfter;

  /// Redo the last score edit
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get redo;

  /// Note pitch
  ///
  /// In en, this message translates to:
  /// **'Pitch'**
  String get pitch;

  /// Note octave
  ///
  /// In en, this message translates to:
  /// **'Octave'**
  String get octave;

  /// Musical note duration
  ///
  /// In en, this message translates to:
  /// **'Note value'**
  String get noteValue;

  /// Score staff
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get staff;

  /// MusicXML voice
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get voice;

  /// Position within a measure
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get position;

  /// Music key signature
  ///
  /// In en, this message translates to:
  /// **'Key signature'**
  String get keySignature;

  /// Concert key of the imported or created score
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get sourceKey;

  /// Instrument part
  ///
  /// In en, this message translates to:
  /// **'Part'**
  String get part;

  /// Empty score editor selection hint
  ///
  /// In en, this message translates to:
  /// **'Tap the staff'**
  String get selectScoreEvent;

  /// Unsaved score confirmation title
  ///
  /// In en, this message translates to:
  /// **'Unsaved score'**
  String get unsavedChangesTitle;

  /// Unsaved score confirmation message
  ///
  /// In en, this message translates to:
  /// **'Save your score edits before leaving?'**
  String get unsavedChangesBody;

  /// Discard unsaved changes
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discardChanges;

  /// Score save success
  ///
  /// In en, this message translates to:
  /// **'Score saved'**
  String get scoreSaved;

  /// Section mark on a digital score measure
  ///
  /// In en, this message translates to:
  /// **'Section'**
  String get scoreSection;

  /// Section repeat order for digital score playback
  ///
  /// In en, this message translates to:
  /// **'Playback order'**
  String get playbackSequence;

  /// How to mark sections and set playback order
  ///
  /// In en, this message translates to:
  /// **'Mark sections on measures, then set their order and repeats.'**
  String get playbackSequenceHelp;

  /// Append the selected measure section to playback order
  ///
  /// In en, this message translates to:
  /// **'Add to order'**
  String get addToPlaybackSequence;

  /// Remove one item from playback order
  ///
  /// In en, this message translates to:
  /// **'Remove from playback order'**
  String get removeFromPlaybackSequence;

  /// Swap the selected measure with the previous one
  ///
  /// In en, this message translates to:
  /// **'Move measure earlier'**
  String get moveMeasureEarlier;

  /// Swap the selected measure with the next one
  ///
  /// In en, this message translates to:
  /// **'Move measure later'**
  String get moveMeasureLater;

  /// Move this playback section one position earlier
  ///
  /// In en, this message translates to:
  /// **'Move section earlier'**
  String get moveSectionEarlier;

  /// Move this playback section one position later
  ///
  /// In en, this message translates to:
  /// **'Move section later'**
  String get moveSectionLater;

  /// Empty playback sequence when the score has no section marks
  ///
  /// In en, this message translates to:
  /// **'Make sections first: tap a line under \"Sections\"'**
  String get noSections;

  /// Arrangement sheet when the score has no chord symbols
  ///
  /// In en, this message translates to:
  /// **'No chords'**
  String get noHarmony;

  /// Decrease a playback section repeat count
  ///
  /// In en, this message translates to:
  /// **'Fewer repeats'**
  String get repeatDown;

  /// Increase a playback section repeat count
  ///
  /// In en, this message translates to:
  /// **'More repeats'**
  String get repeatUp;

  /// Transpose digital score pitch, chords, and key
  ///
  /// In en, this message translates to:
  /// **'Transpose'**
  String get scoreTranspose;

  /// Semitone interval for score transpose
  ///
  /// In en, this message translates to:
  /// **'Semitone'**
  String get semitone;

  /// Decrease transpose by one semitone
  ///
  /// In en, this message translates to:
  /// **'Down a semitone'**
  String get semitoneDown;

  /// Increase transpose by one semitone
  ///
  /// In en, this message translates to:
  /// **'Up a semitone'**
  String get semitoneUp;

  /// Chord-based piano accompaniment profile
  ///
  /// In en, this message translates to:
  /// **'Playback accompaniment'**
  String get scoreArrangement;

  /// Disable generated piano accompaniment
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get arrangementOff;

  /// Held block-chord accompaniment
  ///
  /// In en, this message translates to:
  /// **'Held'**
  String get arrangementBlock;

  /// Per-beat repeated chord accompaniment
  ///
  /// In en, this message translates to:
  /// **'Beat'**
  String get arrangementPulse;

  /// Arpeggiated accompaniment
  ///
  /// In en, this message translates to:
  /// **'Arpeggio'**
  String get arrangementBroken;

  /// Editable digital score project export
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get scoreProject;

  /// Digital score tools menu for transpose, playback order, and accompaniment
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get scoreTools;

  /// Digital score playback could not start
  ///
  /// In en, this message translates to:
  /// **'Can\'t play'**
  String get playFailed;

  /// Open the one-bar score proofreading editor
  ///
  /// In en, this message translates to:
  /// **'Proofread'**
  String get proofread;

  /// Current bar in the proofreading editor
  ///
  /// In en, this message translates to:
  /// **'Bar {number} of {count}'**
  String proofreadBar(int number, int count);

  /// Move the selected note up one staff position
  ///
  /// In en, this message translates to:
  /// **'Step up'**
  String get noteStepUp;

  /// Move the selected note down one staff position
  ///
  /// In en, this message translates to:
  /// **'Step down'**
  String get noteStepDown;

  /// Make the selected note sharp
  ///
  /// In en, this message translates to:
  /// **'Sharp'**
  String get noteSharp;

  /// Make the selected note flat
  ///
  /// In en, this message translates to:
  /// **'Flat'**
  String get noteFlat;

  /// Make the selected note natural
  ///
  /// In en, this message translates to:
  /// **'Natural'**
  String get noteNatural;

  /// Delete the selected note; a lone note becomes a rest
  ///
  /// In en, this message translates to:
  /// **'Delete note'**
  String get deleteNote;

  /// Turn the selected rest into a note
  ///
  /// In en, this message translates to:
  /// **'Make note'**
  String get restToNote;

  /// Select the previous note in the bar
  ///
  /// In en, this message translates to:
  /// **'Previous note'**
  String get previousNote;

  /// Select the next note in the bar
  ///
  /// In en, this message translates to:
  /// **'Next note'**
  String get nextNote;

  /// Go to the previous bar
  ///
  /// In en, this message translates to:
  /// **'Previous bar'**
  String get previousBar;

  /// Go to the next bar
  ///
  /// In en, this message translates to:
  /// **'Next bar'**
  String get nextBar;

  /// Example chord symbols in the chord input
  ///
  /// In en, this message translates to:
  /// **'C, F#m7, B♭/D'**
  String get chordSymbolHint;

  /// Default name for a saved proofreading version
  ///
  /// In en, this message translates to:
  /// **'Proofread {n}'**
  String proofreadVersionName(int n);

  /// Shown when proofreading is opened with unsaved score changes
  ///
  /// In en, this message translates to:
  /// **'Save or discard your changes first'**
  String get saveBeforeProofread;

  /// Jump to a bar number in the proofreading editor
  ///
  /// In en, this message translates to:
  /// **'Go to bar'**
  String get goToBar;

  /// Selected bar range for a playback section
  ///
  /// In en, this message translates to:
  /// **'Bars {start}–{end}'**
  String sectionBarRange(int start, int end);

  /// Heading of the playback order list
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get sectionOrder;

  /// Solo section name
  ///
  /// In en, this message translates to:
  /// **'Solo'**
  String get sectionSolo;

  /// Interlude section name
  ///
  /// In en, this message translates to:
  /// **'Interlude'**
  String get sectionInterlude;

  /// First bar of a new section; a second tap picks its last bar
  ///
  /// In en, this message translates to:
  /// **'Bar {number} · tap the last bar too, or pick a name'**
  String sectionBarPickEnd(int number);

  /// Bars picked for a new section
  ///
  /// In en, this message translates to:
  /// **'Bars {start}–{end} · tap a later line to extend'**
  String sectionRange(int start, int end);

  /// How to divide the score into sections
  ///
  /// In en, this message translates to:
  /// **'Tap a bar to start a new section there'**
  String get sectionStartHint;

  /// Section containing the selected bar
  ///
  /// In en, this message translates to:
  /// **'{name} · bars {start}–{end}'**
  String sectionInfo(String name, int start, int end);

  /// Enter a custom section name
  ///
  /// In en, this message translates to:
  /// **'Custom…'**
  String get sectionCustom;

  /// No description provided for @sectionCancelPick.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get sectionCancelPick;

  /// Remove the section boundary at the selected bar
  ///
  /// In en, this message translates to:
  /// **'Merge with previous'**
  String get sectionRemoveBoundary;

  /// Bars before the first named section
  ///
  /// In en, this message translates to:
  /// **'No name'**
  String get sectionUnnamed;

  /// Custom section name dialog title
  ///
  /// In en, this message translates to:
  /// **'Section name'**
  String get sectionNameTitle;

  /// Playback order is the written order
  ///
  /// In en, this message translates to:
  /// **'Plays as written'**
  String get playbackAsWritten;

  /// Length of the playback order
  ///
  /// In en, this message translates to:
  /// **'{bars} bars · {time}'**
  String playbackSummary(int bars, String time);

  /// Bars the playback order leaves out
  ///
  /// In en, this message translates to:
  /// **'{count} bars not played'**
  String playbackSkipped(int count);

  /// Fill the order with every section once
  ///
  /// In en, this message translates to:
  /// **'Start from the score\'s order'**
  String get buildOrderFromSections;

  /// Clear the custom playback order
  ///
  /// In en, this message translates to:
  /// **'Play as written'**
  String get resetPlaybackOrder;

  /// Default name of a performance version
  ///
  /// In en, this message translates to:
  /// **'Performance {n}'**
  String performanceVersionName(int n);

  /// How many times a section plays
  ///
  /// In en, this message translates to:
  /// **'×{count}'**
  String repeatTimes(int count);

  /// Leave dialog when only the playback order changed
  ///
  /// In en, this message translates to:
  /// **'Save the playback order before leaving?'**
  String get sequenceUnsavedBody;

  /// Blocked action while the playback order is unsaved
  ///
  /// In en, this message translates to:
  /// **'Save or discard the playback order first'**
  String get saveSequenceFirst;

  /// Fetch the server AI review of a converted score as a version
  ///
  /// In en, this message translates to:
  /// **'Get AI correction'**
  String get fetchAiVersion;

  /// Result of fetching the AI correction
  ///
  /// In en, this message translates to:
  /// **'Getting the AI correction… this can take a few minutes.'**
  String get aiFetching;

  /// Result of fetching the AI correction
  ///
  /// In en, this message translates to:
  /// **'The AI review found nothing to change.'**
  String get aiFetchUnchanged;

  /// Result of fetching the AI correction
  ///
  /// In en, this message translates to:
  /// **'The server no longer has this conversion. Convert the score again to get an AI correction.'**
  String get aiFetchExpired;

  /// Result of fetching the AI correction
  ///
  /// In en, this message translates to:
  /// **'AI review is not available on the server right now.'**
  String get aiFetchUnavailable;

  /// Result of fetching the AI correction
  ///
  /// In en, this message translates to:
  /// **'Could not get the AI correction.'**
  String get aiFetchFailed;

  /// Which pass of a written repeat a playback step plays
  ///
  /// In en, this message translates to:
  /// **'Pass {pass}'**
  String endingPass(int pass);

  /// Structure panel tab: divide the score into sections
  ///
  /// In en, this message translates to:
  /// **'Sections'**
  String get structureTabSections;

  /// Structure panel tab: set the playback order
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get structureTabOrder;

  /// Create a new score version laid out in the playback order
  ///
  /// In en, this message translates to:
  /// **'Make a score in this order'**
  String get makeScoreFromOrder;

  /// Open the version made earlier from this order
  ///
  /// In en, this message translates to:
  /// **'Open the score in this order'**
  String get openScoreFromOrder;

  /// The current version is not changed
  ///
  /// In en, this message translates to:
  /// **'This score stays as it is.'**
  String get scoreFromOrderKeepsThis;

  /// Name of the version made by transposing, with the new key
  ///
  /// In en, this message translates to:
  /// **'Transposed to {key}'**
  String transposedVersionName(String key);

  /// Menu action that makes a new version with a piano part (right-hand chords, left-hand bass) under the melody
  ///
  /// In en, this message translates to:
  /// **'Make an instrument score'**
  String get makeThreeStaff;

  /// Name of the version made by adding a piano part under the melody
  ///
  /// In en, this message translates to:
  /// **'With accompaniment'**
  String get threeStaffVersionName;

  /// Shown when a piano part is asked for a score without chord symbols
  ///
  /// In en, this message translates to:
  /// **'There are no chord symbols to make an accompaniment from'**
  String get threeStaffNeedsChords;

  /// Shown when a piano part is asked for a score that has several staves or parts
  ///
  /// In en, this message translates to:
  /// **'Accompaniment parts can only be added to a one-staff melody'**
  String get threeStaffNeedsMelody;

  /// Name of the generated piano part in the score
  ///
  /// In en, this message translates to:
  /// **'Piano'**
  String get pianoPartName;

  /// Heading for how the right hand of the generated piano part plays
  ///
  /// In en, this message translates to:
  /// **'Right-hand pattern'**
  String get pianoPattern;

  /// Accompaniment pattern: chord struck once and held
  ///
  /// In en, this message translates to:
  /// **'Held'**
  String get pianoPatternHeld;

  /// Accompaniment pattern: chord struck on every beat
  ///
  /// In en, this message translates to:
  /// **'Every beat'**
  String get pianoPatternBeats;

  /// Accompaniment pattern: broken chord in eighth notes
  ///
  /// In en, this message translates to:
  /// **'Broken'**
  String get pianoPatternBroken;

  /// Heading for where the right hand of the generated piano part lies
  ///
  /// In en, this message translates to:
  /// **'Accompaniment height'**
  String get pianoRegister;

  /// Right-hand register around middle C
  ///
  /// In en, this message translates to:
  /// **'Middle'**
  String get pianoRegisterMiddle;

  /// Right-hand register about a fourth below the middle one
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get pianoRegisterLow;

  /// Button that asks the server for an accompaniment style per section and chord symbols to check
  ///
  /// In en, this message translates to:
  /// **'AI suggestion'**
  String get pianoAskAdvice;

  /// Shown when the AI accompaniment suggestion could not be fetched
  ///
  /// In en, this message translates to:
  /// **'No suggestion available right now'**
  String get pianoAdviceFailed;

  /// Heading for the suggested accompaniment styles of sections
  ///
  /// In en, this message translates to:
  /// **'By section'**
  String get pianoSectionStyles;

  /// Button that drops the per-section styles so the chosen style applies to the whole score
  ///
  /// In en, this message translates to:
  /// **'One style for all'**
  String get pianoOneStyle;

  /// One suggested section style
  ///
  /// In en, this message translates to:
  /// **'From bar {bar}: {pattern} · {register}'**
  String pianoSectionStyle(int bar, String pattern, String register);

  /// Heading for chord symbols the AI suggests changing
  ///
  /// In en, this message translates to:
  /// **'Chords to check'**
  String get pianoChordFixes;

  /// Shown when the AI suggests no chord changes
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get pianoNoChordFixes;

  /// One suggested chord change
  ///
  /// In en, this message translates to:
  /// **'Bar {bar}: {current} → {suggested}'**
  String pianoChordFix(int bar, String current, String suggested);

  /// Button that makes the version with the piano part
  ///
  /// In en, this message translates to:
  /// **'Make'**
  String get pianoMake;

  /// Heading for the instruments accompaniment parts are made for
  ///
  /// In en, this message translates to:
  /// **'Instruments'**
  String get accompanimentInstruments;

  /// Name of the generated organ part
  ///
  /// In en, this message translates to:
  /// **'Organ'**
  String get organPartName;

  /// Name of the generated strings part
  ///
  /// In en, this message translates to:
  /// **'Strings'**
  String get stringsPartName;

  /// Name of the generated synth pad part
  ///
  /// In en, this message translates to:
  /// **'Pad'**
  String get padPartName;

  /// Name of the generated brass part
  ///
  /// In en, this message translates to:
  /// **'Brass'**
  String get brassPartName;

  /// Accompaniment pattern chosen per section (verse, chorus...) by the app
  ///
  /// In en, this message translates to:
  /// **'By section'**
  String get pianoPatternAuto;

  /// Heading for the form of the generated scores
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get accompanimentOutput;

  /// Each chosen instrument gets its own version with the melody on top
  ///
  /// In en, this message translates to:
  /// **'One score per instrument'**
  String get accompanimentSeparateScores;

  /// All chosen instruments under the melody in one version
  ///
  /// In en, this message translates to:
  /// **'All in one score'**
  String get accompanimentOneScore;

  /// Heading for how many notes the generated parts play at once
  ///
  /// In en, this message translates to:
  /// **'Chord thickness'**
  String get accompanimentDensity;

  /// Thin accompaniment: at most three notes, nothing doubled
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get accompanimentDensityLight;

  /// Accompaniment density as each section asks
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get accompanimentDensityNormal;

  /// Thick accompaniment: full chords with octave doubling
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get accompanimentDensityFull;

  /// Heading for the split point between the piano's hands
  ///
  /// In en, this message translates to:
  /// **'Where the hands split'**
  String get pianoSplitPoint;

  /// Split point left to the chosen register
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get pianoSplitAuto;

  /// toolsMarks
  ///
  /// In en, this message translates to:
  /// **'Marks'**
  String get toolsMarks;

  /// toolsBarSigns
  ///
  /// In en, this message translates to:
  /// **'Bar signs'**
  String get toolsBarSigns;

  /// noteToRest
  ///
  /// In en, this message translates to:
  /// **'Make rest'**
  String get noteToRest;

  /// removeNoteTool
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeNoteTool;

  /// splitNote
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get splitNote;

  /// insertTool
  ///
  /// In en, this message translates to:
  /// **'Insert'**
  String get insertTool;

  /// insertNoteBefore
  ///
  /// In en, this message translates to:
  /// **'Note before'**
  String get insertNoteBefore;

  /// insertNoteAfter
  ///
  /// In en, this message translates to:
  /// **'Note after'**
  String get insertNoteAfter;

  /// insertRestBefore
  ///
  /// In en, this message translates to:
  /// **'Rest before'**
  String get insertRestBefore;

  /// insertRestAfter
  ///
  /// In en, this message translates to:
  /// **'Rest after'**
  String get insertRestAfter;

  /// graceNote
  ///
  /// In en, this message translates to:
  /// **'Grace note'**
  String get graceNote;

  /// tieTool
  ///
  /// In en, this message translates to:
  /// **'Tie'**
  String get tieTool;

  /// tuplet
  ///
  /// In en, this message translates to:
  /// **'Tuplet'**
  String get tuplet;

  /// Tuplet of n notes
  ///
  /// In en, this message translates to:
  /// **'{n}-tuplet'**
  String tupletOf(int n);

  /// tupletRemove
  ///
  /// In en, this message translates to:
  /// **'Remove tuplet'**
  String get tupletRemove;

  /// doubleSharp
  ///
  /// In en, this message translates to:
  /// **'Double sharp'**
  String get doubleSharp;

  /// doubleFlat
  ///
  /// In en, this message translates to:
  /// **'Double flat'**
  String get doubleFlat;

  /// staccato
  ///
  /// In en, this message translates to:
  /// **'Staccato'**
  String get staccato;

  /// staccatissimo
  ///
  /// In en, this message translates to:
  /// **'Staccatissimo'**
  String get staccatissimo;

  /// tenuto
  ///
  /// In en, this message translates to:
  /// **'Tenuto'**
  String get tenuto;

  /// marcato
  ///
  /// In en, this message translates to:
  /// **'Marcato'**
  String get marcato;

  /// fermata
  ///
  /// In en, this message translates to:
  /// **'Fermata'**
  String get fermata;

  /// dynamics
  ///
  /// In en, this message translates to:
  /// **'Dynamics'**
  String get dynamics;

  /// dynamicsNone
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get dynamicsNone;

  /// keyAndTime
  ///
  /// In en, this message translates to:
  /// **'Key · Time'**
  String get keyAndTime;

  /// clef
  ///
  /// In en, this message translates to:
  /// **'Clef'**
  String get clef;

  /// clefTreble
  ///
  /// In en, this message translates to:
  /// **'Treble'**
  String get clefTreble;

  /// clefBass
  ///
  /// In en, this message translates to:
  /// **'Bass'**
  String get clefBass;

  /// clefAlto
  ///
  /// In en, this message translates to:
  /// **'Alto'**
  String get clefAlto;

  /// clefTenor
  ///
  /// In en, this message translates to:
  /// **'Tenor'**
  String get clefTenor;

  /// repeatStart
  ///
  /// In en, this message translates to:
  /// **'Repeat start'**
  String get repeatStart;

  /// repeatEnd
  ///
  /// In en, this message translates to:
  /// **'Repeat end'**
  String get repeatEnd;

  /// barlineTool
  ///
  /// In en, this message translates to:
  /// **'Barline'**
  String get barlineTool;

  /// barlineRegular
  ///
  /// In en, this message translates to:
  /// **'Single'**
  String get barlineRegular;

  /// barlineDouble
  ///
  /// In en, this message translates to:
  /// **'Double'**
  String get barlineDouble;

  /// barlineFinal
  ///
  /// In en, this message translates to:
  /// **'Final'**
  String get barlineFinal;

  /// endings
  ///
  /// In en, this message translates to:
  /// **'Endings'**
  String get endings;

  /// Start of the n-th ending bracket
  ///
  /// In en, this message translates to:
  /// **'Ending {n} start'**
  String endingStart(int n);

  /// End of the n-th ending bracket
  ///
  /// In en, this message translates to:
  /// **'Ending {n} end'**
  String endingEnd(int n);

  /// navigationSigns
  ///
  /// In en, this message translates to:
  /// **'Jumps'**
  String get navigationSigns;

  /// tempoMark
  ///
  /// In en, this message translates to:
  /// **'Tempo'**
  String get tempoMark;

  /// tempoBpmLabel
  ///
  /// In en, this message translates to:
  /// **'Beats per minute'**
  String get tempoBpmLabel;

  /// tempoText
  ///
  /// In en, this message translates to:
  /// **'Tempo text (optional)'**
  String get tempoText;

  /// tempoRemove
  ///
  /// In en, this message translates to:
  /// **'Remove tempo'**
  String get tempoRemove;

  /// rehearsalMark
  ///
  /// In en, this message translates to:
  /// **'Section name'**
  String get rehearsalMark;

  /// rehearsalHint
  ///
  /// In en, this message translates to:
  /// **'Verse, Chorus, A…'**
  String get rehearsalHint;

  /// addText
  ///
  /// In en, this message translates to:
  /// **'Add text'**
  String get addText;

  /// addTextHint
  ///
  /// In en, this message translates to:
  /// **'rit., 2x…'**
  String get addTextHint;

  /// slurTool
  ///
  /// In en, this message translates to:
  /// **'Slur'**
  String get slurTool;

  /// linesMenu
  ///
  /// In en, this message translates to:
  /// **'Lines'**
  String get linesMenu;

  /// crescendo
  ///
  /// In en, this message translates to:
  /// **'Crescendo'**
  String get crescendo;

  /// diminuendo
  ///
  /// In en, this message translates to:
  /// **'Diminuendo'**
  String get diminuendo;

  /// pedalLine
  ///
  /// In en, this message translates to:
  /// **'Pedal'**
  String get pedalLine;

  /// glissando
  ///
  /// In en, this message translates to:
  /// **'Glissando'**
  String get glissando;

  /// ornamentsMenu
  ///
  /// In en, this message translates to:
  /// **'Ornaments'**
  String get ornamentsMenu;

  /// trill
  ///
  /// In en, this message translates to:
  /// **'Trill'**
  String get trill;

  /// mordent
  ///
  /// In en, this message translates to:
  /// **'Mordent'**
  String get mordent;

  /// invertedMordent
  ///
  /// In en, this message translates to:
  /// **'Inverted mordent'**
  String get invertedMordent;

  /// turnOrnament
  ///
  /// In en, this message translates to:
  /// **'Turn'**
  String get turnOrnament;

  /// tremolo
  ///
  /// In en, this message translates to:
  /// **'Tremolo'**
  String get tremolo;

  /// arpeggio
  ///
  /// In en, this message translates to:
  /// **'Arpeggio'**
  String get arpeggio;

  /// breathMark
  ///
  /// In en, this message translates to:
  /// **'Breath mark'**
  String get breathMark;

  /// spanPickEnd
  ///
  /// In en, this message translates to:
  /// **'{name}: tap the note it ends on'**
  String spanPickEnd(String name);

  /// spanToSelected
  ///
  /// In en, this message translates to:
  /// **'To selected note'**
  String get spanToSelected;

  /// verseMenu
  ///
  /// In en, this message translates to:
  /// **'Verse'**
  String get verseMenu;

  /// verseOf
  ///
  /// In en, this message translates to:
  /// **'Verse {n}'**
  String verseOf(int n);

  /// toolsKeys
  ///
  /// In en, this message translates to:
  /// **'Keys'**
  String get toolsKeys;

  /// keyboardLower
  ///
  /// In en, this message translates to:
  /// **'Keyboard octave down'**
  String get keyboardLower;

  /// keyboardHigher
  ///
  /// In en, this message translates to:
  /// **'Keyboard octave up'**
  String get keyboardHigher;

  /// keyAdvance
  ///
  /// In en, this message translates to:
  /// **'Go to next note'**
  String get keyAdvance;

  /// penTool
  ///
  /// In en, this message translates to:
  /// **'Pen'**
  String get penTool;

  /// penHint
  ///
  /// In en, this message translates to:
  /// **'Tap to place a note · hold to carry it to its line'**
  String get penHint;

  /// rangeTool
  ///
  /// In en, this message translates to:
  /// **'Range'**
  String get rangeTool;

  /// rangeHint
  ///
  /// In en, this message translates to:
  /// **'Tap the last note to pick several'**
  String get rangeHint;

  /// voiceMenu
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get voiceMenu;

  /// voiceAdd
  ///
  /// In en, this message translates to:
  /// **'Add a voice'**
  String get voiceAdd;

  /// voiceRemove
  ///
  /// In en, this message translates to:
  /// **'Remove this voice'**
  String get voiceRemove;

  /// lineBreakTool
  ///
  /// In en, this message translates to:
  /// **'Line break'**
  String get lineBreakTool;

  /// pageBreakTool
  ///
  /// In en, this message translates to:
  /// **'Page break'**
  String get pageBreakTool;

  /// toolsScore
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get toolsScore;

  /// instrumentMenu
  ///
  /// In en, this message translates to:
  /// **'Instrument'**
  String get instrumentMenu;

  /// staffMenu
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get staffMenu;

  /// staffAdd
  ///
  /// In en, this message translates to:
  /// **'Add a staff below'**
  String get staffAdd;

  /// staffRemove
  ///
  /// In en, this message translates to:
  /// **'Remove the lower staff'**
  String get staffRemove;

  /// barRange
  ///
  /// In en, this message translates to:
  /// **'Bar range…'**
  String get barRange;

  /// barRangeTitle
  ///
  /// In en, this message translates to:
  /// **'Bar range'**
  String get barRangeTitle;

  /// barRangeFrom
  ///
  /// In en, this message translates to:
  /// **'From bar'**
  String get barRangeFrom;

  /// barRangeTo
  ///
  /// In en, this message translates to:
  /// **'To bar'**
  String get barRangeTo;

  /// barRangeCopy
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get barRangeCopy;

  /// barRangeCut
  ///
  /// In en, this message translates to:
  /// **'Cut'**
  String get barRangeCut;

  /// barRangeDelete
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get barRangeDelete;

  /// barRangeTranspose
  ///
  /// In en, this message translates to:
  /// **'Transpose'**
  String get barRangeTranspose;

  /// semitoneCount
  ///
  /// In en, this message translates to:
  /// **'{n} semitones'**
  String semitoneCount(String n);

  /// pasteBars
  ///
  /// In en, this message translates to:
  /// **'Insert {n} copied bars'**
  String pasteBars(int n);

  /// barsCopied
  ///
  /// In en, this message translates to:
  /// **'{n} bars copied'**
  String barsCopied(int n);

  /// barRangeInvalid
  ///
  /// In en, this message translates to:
  /// **'Check the bar numbers'**
  String get barRangeInvalid;

  /// pasteBarsNone
  ///
  /// In en, this message translates to:
  /// **'Insert (no bars copied)'**
  String get pasteBarsNone;

  /// breaksReflow
  ///
  /// In en, this message translates to:
  /// **'This score breaks its lines to fit the screen. Line breaks can be set in a score that has written lines.'**
  String get breaksReflow;

  /// toolSelect
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get toolSelect;

  /// toolEraser
  ///
  /// In en, this message translates to:
  /// **'Eraser'**
  String get toolEraser;

  /// toolNote
  ///
  /// In en, this message translates to:
  /// **'Write notes'**
  String get toolNote;

  /// toolRest
  ///
  /// In en, this message translates to:
  /// **'Write rests'**
  String get toolRest;

  /// toolAccidental
  ///
  /// In en, this message translates to:
  /// **'Accidental'**
  String get toolAccidental;

  /// paletteChooser
  ///
  /// In en, this message translates to:
  /// **'Palettes'**
  String get paletteChooser;

  /// toStart
  ///
  /// In en, this message translates to:
  /// **'To the start'**
  String get toStart;

  /// eraserHint
  ///
  /// In en, this message translates to:
  /// **'Tap the note to erase'**
  String get eraserHint;

  /// barEditPaste
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get barEditPaste;

  /// barEditDuplicate
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get barEditDuplicate;

  /// barPicked
  ///
  /// In en, this message translates to:
  /// **'Bar {n}'**
  String barPicked(int n);

  /// barsPicked
  ///
  /// In en, this message translates to:
  /// **'Bars {from}–{to}'**
  String barsPicked(int from, int to);

  /// keysAppendHint
  ///
  /// In en, this message translates to:
  /// **'The next key adds a new note after this one'**
  String get keysAppendHint;

  /// lyricJoinHint
  ///
  /// In en, this message translates to:
  /// **'End with - to join the next syllable, with _ to hold it. Words with spaces go onto the notes that follow'**
  String get lyricJoinHint;

  /// respell
  ///
  /// In en, this message translates to:
  /// **'Respell (enharmonic)'**
  String get respell;

  /// fingeringMenu
  ///
  /// In en, this message translates to:
  /// **'Fingering'**
  String get fingeringMenu;

  /// graceSlash
  ///
  /// In en, this message translates to:
  /// **'Grace slash'**
  String get graceSlash;

  /// beamMenu
  ///
  /// In en, this message translates to:
  /// **'Beam'**
  String get beamMenu;

  /// beamJoin
  ///
  /// In en, this message translates to:
  /// **'Join with a beam'**
  String get beamJoin;

  /// beamBreak
  ///
  /// In en, this message translates to:
  /// **'Remove the beam'**
  String get beamBreak;

  /// notesMenu
  ///
  /// In en, this message translates to:
  /// **'Copy · paste notes'**
  String get notesMenu;

  /// notesCopy
  ///
  /// In en, this message translates to:
  /// **'Copy the picked notes'**
  String get notesCopy;

  /// notesPaste
  ///
  /// In en, this message translates to:
  /// **'Paste from here ({n})'**
  String notesPaste(int n);

  /// notesPasteNone
  ///
  /// In en, this message translates to:
  /// **'Paste (nothing copied)'**
  String get notesPasteNone;

  /// notesDuplicate
  ///
  /// In en, this message translates to:
  /// **'Duplicate right after'**
  String get notesDuplicate;

  /// notesCopied
  ///
  /// In en, this message translates to:
  /// **'Copied {n}'**
  String notesCopied(int n);

  /// pickupBar
  ///
  /// In en, this message translates to:
  /// **'Pickup bar'**
  String get pickupBar;

  /// barsPerLine
  ///
  /// In en, this message translates to:
  /// **'Bars per line'**
  String get barsPerLine;

  /// barsPerLineAuto
  ///
  /// In en, this message translates to:
  /// **'Automatic (fit the page)'**
  String get barsPerLineAuto;

  /// barsPerLineOf
  ///
  /// In en, this message translates to:
  /// **'{n} bars'**
  String barsPerLineOf(int n);

  /// chordKeys
  ///
  /// In en, this message translates to:
  /// **'Build a chord'**
  String get chordKeys;

  /// chordRepeat
  ///
  /// In en, this message translates to:
  /// **'Repeat the last chord'**
  String get chordRepeat;

  /// keyWidthTool
  ///
  /// In en, this message translates to:
  /// **'Key width'**
  String get keyWidthTool;

  /// draftTitle
  ///
  /// In en, this message translates to:
  /// **'There are unsaved corrections'**
  String get draftTitle;

  /// draftBody
  ///
  /// In en, this message translates to:
  /// **'What you were correcting last time was kept. Go on with it?'**
  String get draftBody;

  /// draftResume
  ///
  /// In en, this message translates to:
  /// **'Go on'**
  String get draftResume;

  /// soundNotes
  ///
  /// In en, this message translates to:
  /// **'Sound a note when it is written'**
  String get soundNotes;

  /// toolsLooks
  ///
  /// In en, this message translates to:
  /// **'Looks'**
  String get toolsLooks;

  /// stemMenu
  ///
  /// In en, this message translates to:
  /// **'Stem'**
  String get stemMenu;

  /// stemUp
  ///
  /// In en, this message translates to:
  /// **'Up'**
  String get stemUp;

  /// stemDown
  ///
  /// In en, this message translates to:
  /// **'Down'**
  String get stemDown;

  /// stemHide
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get stemHide;

  /// automatic
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get automatic;

  /// noteheadMenu
  ///
  /// In en, this message translates to:
  /// **'Notehead'**
  String get noteheadMenu;

  /// noteheadNormal
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get noteheadNormal;

  /// noteheadSlash
  ///
  /// In en, this message translates to:
  /// **'Slash'**
  String get noteheadSlash;

  /// noteheadGhost
  ///
  /// In en, this message translates to:
  /// **'Parentheses (ghost note)'**
  String get noteheadGhost;

  /// otherStaff
  ///
  /// In en, this message translates to:
  /// **'To the other staff'**
  String get otherStaff;

  /// markSideMenu
  ///
  /// In en, this message translates to:
  /// **'Side of marks'**
  String get markSideMenu;

  /// sideAbove
  ///
  /// In en, this message translates to:
  /// **'Above'**
  String get sideAbove;

  /// sideBelow
  ///
  /// In en, this message translates to:
  /// **'Below'**
  String get sideBelow;

  /// clearMarksTool
  ///
  /// In en, this message translates to:
  /// **'Remove all marks'**
  String get clearMarksTool;

  /// clearAccidentalTool
  ///
  /// In en, this message translates to:
  /// **'Remove accidentals'**
  String get clearAccidentalTool;

  /// doubleMenu
  ///
  /// In en, this message translates to:
  /// **'Double at an interval'**
  String get doubleMenu;

  /// doubleThirdUp
  ///
  /// In en, this message translates to:
  /// **'A third above'**
  String get doubleThirdUp;

  /// doubleSixthUp
  ///
  /// In en, this message translates to:
  /// **'A sixth above'**
  String get doubleSixthUp;

  /// doubleOctaveUp
  ///
  /// In en, this message translates to:
  /// **'An octave above'**
  String get doubleOctaveUp;

  /// doubleThirdDown
  ///
  /// In en, this message translates to:
  /// **'A third below'**
  String get doubleThirdDown;

  /// doubleOctaveDown
  ///
  /// In en, this message translates to:
  /// **'An octave below'**
  String get doubleOctaveDown;

  /// jazzMenu
  ///
  /// In en, this message translates to:
  /// **'Jazz articulations'**
  String get jazzMenu;

  /// selectMenu
  ///
  /// In en, this message translates to:
  /// **'Selection'**
  String get selectMenu;

  /// selectAll
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// selectBar
  ///
  /// In en, this message translates to:
  /// **'Select this bar'**
  String get selectBar;

  /// onlyAll
  ///
  /// In en, this message translates to:
  /// **'All picked notes'**
  String get onlyAll;

  /// onlyTop
  ///
  /// In en, this message translates to:
  /// **'Highest notes only'**
  String get onlyTop;

  /// onlyBottom
  ///
  /// In en, this message translates to:
  /// **'Lowest notes only'**
  String get onlyBottom;

  /// clearLyrics
  ///
  /// In en, this message translates to:
  /// **'Remove the lyrics of the picked notes'**
  String get clearLyrics;

  /// clearChords
  ///
  /// In en, this message translates to:
  /// **'Remove the chord symbols of the picked notes'**
  String get clearChords;

  /// optRailRight
  ///
  /// In en, this message translates to:
  /// **'Tools on the right'**
  String get optRailRight;

  /// optSmallTools
  ///
  /// In en, this message translates to:
  /// **'Small buttons'**
  String get optSmallTools;

  /// optDarkScore
  ///
  /// In en, this message translates to:
  /// **'Dark score'**
  String get optDarkScore;

  /// noteSizeMenu
  ///
  /// In en, this message translates to:
  /// **'Note size'**
  String get noteSizeMenu;

  /// noteSizeSmall
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get noteSizeSmall;

  /// noteSizeLarge
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get noteSizeLarge;

  /// noteSizeLarger
  ///
  /// In en, this message translates to:
  /// **'Larger'**
  String get noteSizeLarger;

  /// voiceSwap
  ///
  /// In en, this message translates to:
  /// **'Swap the two voices'**
  String get voiceSwap;

  /// barEditPasteInsert
  ///
  /// In en, this message translates to:
  /// **'Insert'**
  String get barEditPasteInsert;

  /// tupletGroup
  ///
  /// In en, this message translates to:
  /// **'Make the picked notes a tuplet'**
  String get tupletGroup;

  /// tupletOneBar
  ///
  /// In en, this message translates to:
  /// **'Pick notes of one bar'**
  String get tupletOneBar;

  /// keyRest
  ///
  /// In en, this message translates to:
  /// **'Write a rest and go on'**
  String get keyRest;

  /// favourFlats
  ///
  /// In en, this message translates to:
  /// **'Spell with flats'**
  String get favourFlats;

  /// favourSharps
  ///
  /// In en, this message translates to:
  /// **'Spell with sharps'**
  String get favourSharps;

  /// tempoChange
  ///
  /// In en, this message translates to:
  /// **'Tempo change'**
  String get tempoChange;

  /// metronomeOption
  ///
  /// In en, this message translates to:
  /// **'Metronome while playing'**
  String get metronomeOption;

  /// hideTool
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hideTool;

  /// hideSignMenu
  ///
  /// In en, this message translates to:
  /// **'Hide signatures'**
  String get hideSignMenu;

  /// hideTime
  ///
  /// In en, this message translates to:
  /// **'Time signature'**
  String get hideTime;

  /// hideKey
  ///
  /// In en, this message translates to:
  /// **'Key signature'**
  String get hideKey;

  /// insertMeasuresMany
  ///
  /// In en, this message translates to:
  /// **'Add several bars…'**
  String get insertMeasuresMany;

  /// insertCount
  ///
  /// In en, this message translates to:
  /// **'How many bars'**
  String get insertCount;

  /// looseSelect
  ///
  /// In en, this message translates to:
  /// **'Pick notes one by one'**
  String get looseSelect;

  /// looseHint
  ///
  /// In en, this message translates to:
  /// **'Tap notes to pick or drop them'**
  String get looseHint;

  /// onlyUpperVoice
  ///
  /// In en, this message translates to:
  /// **'Upper voice only'**
  String get onlyUpperVoice;

  /// onlyLowerVoice
  ///
  /// In en, this message translates to:
  /// **'Lower voice only'**
  String get onlyLowerVoice;

  /// rangeOption
  ///
  /// In en, this message translates to:
  /// **'Mark notes out of range'**
  String get rangeOption;

  /// slashFill
  ///
  /// In en, this message translates to:
  /// **'Fill with slashes'**
  String get slashFill;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'ko', 'la', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'la':
      return AppLocalizationsLa();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
