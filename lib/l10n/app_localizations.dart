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
  /// **'Edit score'**
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
