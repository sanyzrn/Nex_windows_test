import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fa.dart';

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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('fa'),
  ];

  /// No description provided for @capture.
  ///
  /// In en, this message translates to:
  /// **'Quick capture'**
  String get capture;

  /// No description provided for @captureHint.
  ///
  /// In en, this message translates to:
  /// **'Write anything…'**
  String get captureHint;

  /// No description provided for @newNote.
  ///
  /// In en, this message translates to:
  /// **'New note'**
  String get newNote;

  /// No description provided for @checklist.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get checklist;

  /// No description provided for @clipboard.
  ///
  /// In en, this message translates to:
  /// **'Clipboard text → note'**
  String get clipboard;

  /// No description provided for @pasteImage.
  ///
  /// In en, this message translates to:
  /// **'Clipboard image → photo note'**
  String get pasteImage;

  /// No description provided for @attach.
  ///
  /// In en, this message translates to:
  /// **'Attach files'**
  String get attach;

  /// No description provided for @record.
  ///
  /// In en, this message translates to:
  /// **'Record voice'**
  String get record;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop recording'**
  String get stop;

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'Operation failed'**
  String get failed;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search notes'**
  String get search;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tags;

  /// No description provided for @threads.
  ///
  /// In en, this message translates to:
  /// **'Threads'**
  String get threads;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clear;

  /// No description provided for @trash.
  ///
  /// In en, this message translates to:
  /// **'Recently deleted'**
  String get trash;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @empty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get empty;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// No description provided for @accent.
  ///
  /// In en, this message translates to:
  /// **'Accent colour'**
  String get accent;

  /// No description provided for @text.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get text;

  /// No description provided for @voice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get voice;

  /// No description provided for @photo.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get photo;

  /// No description provided for @file.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get file;

  /// No description provided for @link.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get link;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open attachment'**
  String get open;

  /// No description provided for @pin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get pin;

  /// No description provided for @unpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get unpin;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleted.
  ///
  /// In en, this message translates to:
  /// **'Note deleted'**
  String get deleted;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @addTag.
  ///
  /// In en, this message translates to:
  /// **'Add tag · Enter'**
  String get addTag;

  /// No description provided for @addThread.
  ///
  /// In en, this message translates to:
  /// **'New thread · Enter'**
  String get addThread;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @edge.
  ///
  /// In en, this message translates to:
  /// **'Physical edge'**
  String get edge;

  /// No description provided for @left.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get left;

  /// No description provided for @right.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get right;

  /// No description provided for @monitor.
  ///
  /// In en, this message translates to:
  /// **'Monitor'**
  String get monitor;

  /// No description provided for @startup.
  ///
  /// In en, this message translates to:
  /// **'Start with Windows'**
  String get startup;

  /// No description provided for @hotkey.
  ///
  /// In en, this message translates to:
  /// **'Capture shortcut: Ctrl + Alt + selected key'**
  String get hotkey;

  /// No description provided for @backup.
  ///
  /// In en, this message translates to:
  /// **'Complete backup'**
  String get backup;

  /// No description provided for @backupInfo.
  ///
  /// In en, this message translates to:
  /// **'Nex format: library is readable; settings are encrypted. Keep the recovery key.'**
  String get backupInfo;

  /// No description provided for @recoveryKey.
  ///
  /// In en, this message translates to:
  /// **'Recovery key'**
  String get recoveryKey;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About / licences'**
  String get about;

  /// No description provided for @tools.
  ///
  /// In en, this message translates to:
  /// **'Dock tools'**
  String get tools;

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @remind.
  ///
  /// In en, this message translates to:
  /// **'Remind me'**
  String get remind;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @joinThread.
  ///
  /// In en, this message translates to:
  /// **'Add to thread'**
  String get joinThread;

  /// No description provided for @utility0.
  ///
  /// In en, this message translates to:
  /// **'Copy something and it shows up here'**
  String get utility0;

  /// No description provided for @utility1.
  ///
  /// In en, this message translates to:
  /// **'Clipboard'**
  String get utility1;

  /// No description provided for @utility2.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get utility2;

  /// No description provided for @utility3.
  ///
  /// In en, this message translates to:
  /// **'Search history…'**
  String get utility3;

  /// No description provided for @utility4.
  ///
  /// In en, this message translates to:
  /// **'Picked colors appear here'**
  String get utility4;

  /// No description provided for @utility5.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get utility5;

  /// No description provided for @utility6.
  ///
  /// In en, this message translates to:
  /// **'◎ Pick from screen'**
  String get utility6;

  /// No description provided for @utility7.
  ///
  /// In en, this message translates to:
  /// **'HEX'**
  String get utility7;

  /// No description provided for @utility8.
  ///
  /// In en, this message translates to:
  /// **'RGB'**
  String get utility8;

  /// No description provided for @utility9.
  ///
  /// In en, this message translates to:
  /// **'HSL'**
  String get utility9;

  /// No description provided for @utility10.
  ///
  /// In en, this message translates to:
  /// **'Palette'**
  String get utility10;

  /// No description provided for @utility11.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get utility11;

  /// No description provided for @utility12.
  ///
  /// In en, this message translates to:
  /// **'Search emoji…'**
  String get utility12;

  /// No description provided for @utility13.
  ///
  /// In en, this message translates to:
  /// **'drag a tile onto the dock'**
  String get utility13;

  /// No description provided for @utility14.
  ///
  /// In en, this message translates to:
  /// **'Drag tools here from the dock'**
  String get utility14;

  /// No description provided for @utility15.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get utility15;

  /// No description provided for @utility16.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get utility16;

  /// No description provided for @utility17.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get utility17;

  /// No description provided for @utility18.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get utility18;

  /// No description provided for @utility19.
  ///
  /// In en, this message translates to:
  /// **'Calculator'**
  String get utility19;

  /// No description provided for @utility20.
  ///
  /// In en, this message translates to:
  /// **'e.g. (12.5 * 4) / 3 + 2^3'**
  String get utility20;

  /// No description provided for @utility21.
  ///
  /// In en, this message translates to:
  /// **'Timer'**
  String get utility21;

  /// No description provided for @utility22.
  ///
  /// In en, this message translates to:
  /// **'Stopwatch'**
  String get utility22;

  /// No description provided for @utility24.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get utility24;

  /// No description provided for @utility25.
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get utility25;

  /// No description provided for @utility26.
  ///
  /// In en, this message translates to:
  /// **'e.g. 12 in, 5 km, 70 kg, 30 c'**
  String get utility26;

  /// No description provided for @utility27.
  ///
  /// In en, this message translates to:
  /// **'click to paste'**
  String get utility27;

  /// No description provided for @utility28.
  ///
  /// In en, this message translates to:
  /// **'Save text you type often: addresses, replies, signatures…'**
  String get utility28;

  /// No description provided for @utility29.
  ///
  /// In en, this message translates to:
  /// **'Add a city below'**
  String get utility29;

  /// No description provided for @utility30.
  ///
  /// In en, this message translates to:
  /// **'＋ Add a city…'**
  String get utility30;

  /// No description provided for @utility31.
  ///
  /// In en, this message translates to:
  /// **'Media & volume'**
  String get utility31;

  /// No description provided for @utility32.
  ///
  /// In en, this message translates to:
  /// **'Generate & paste'**
  String get utility32;

  /// No description provided for @utility33.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get utility33;

  /// No description provided for @utility34.
  ///
  /// In en, this message translates to:
  /// **'Snippets'**
  String get utility34;

  /// No description provided for @utility35.
  ///
  /// In en, this message translates to:
  /// **'Type a snippet and press Enter…'**
  String get utility35;

  /// No description provided for @utility36.
  ///
  /// In en, this message translates to:
  /// **'Web search'**
  String get utility36;

  /// No description provided for @utility37.
  ///
  /// In en, this message translates to:
  /// **'Search or type a URL, then Enter'**
  String get utility37;

  /// No description provided for @utility38.
  ///
  /// In en, this message translates to:
  /// **'World clock'**
  String get utility38;

  /// No description provided for @utility39.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get utility39;

  /// No description provided for @utility40.
  ///
  /// In en, this message translates to:
  /// **'Emoji'**
  String get utility40;

  /// No description provided for @utility41.
  ///
  /// In en, this message translates to:
  /// **'Screenshot'**
  String get utility41;

  /// No description provided for @utility42.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get utility42;

  /// No description provided for @utility43.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get utility43;

  /// No description provided for @utility44.
  ///
  /// In en, this message translates to:
  /// **'Text tools'**
  String get utility44;

  /// No description provided for @utility45.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get utility45;

  /// No description provided for @utility46.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get utility46;

  /// No description provided for @utility47.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get utility47;

  /// No description provided for @utility48.
  ///
  /// In en, this message translates to:
  /// **'Keep awake'**
  String get utility48;

  /// No description provided for @utility49.
  ///
  /// In en, this message translates to:
  /// **'Pin window'**
  String get utility49;

  /// No description provided for @utility50.
  ///
  /// In en, this message translates to:
  /// **'Desktop'**
  String get utility50;

  /// No description provided for @utility51.
  ///
  /// In en, this message translates to:
  /// **'Screen off'**
  String get utility51;

  /// No description provided for @utility52.
  ///
  /// In en, this message translates to:
  /// **'Lock PC'**
  String get utility52;

  /// No description provided for @utility53.
  ///
  /// In en, this message translates to:
  /// **'Task Mgr'**
  String get utility53;

  /// No description provided for @utility54.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get utility54;

  /// No description provided for @utility55.
  ///
  /// In en, this message translates to:
  /// **'Win Settings'**
  String get utility55;

  /// No description provided for @caption.
  ///
  /// In en, this message translates to:
  /// **'Caption'**
  String get caption;

  /// No description provided for @persian.
  ///
  /// In en, this message translates to:
  /// **'Persian'**
  String get persian;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @trayOpen.
  ///
  /// In en, this message translates to:
  /// **'Open Nex'**
  String get trayOpen;

  /// No description provided for @trayQuit.
  ///
  /// In en, this message translates to:
  /// **'Quit Nex'**
  String get trayQuit;

  /// No description provided for @addApp.
  ///
  /// In en, this message translates to:
  /// **'Add app…'**
  String get addApp;

  /// No description provided for @quit.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get quit;

  /// No description provided for @pasteOnClick.
  ///
  /// In en, this message translates to:
  /// **'Paste on click'**
  String get pasteOnClick;

  /// No description provided for @magnify.
  ///
  /// In en, this message translates to:
  /// **'Magnify icons on hover'**
  String get magnify;

  /// No description provided for @utility56.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get utility56;

  /// No description provided for @utility57.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get utility57;

  /// No description provided for @utility58.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get utility58;

  /// No description provided for @utility59.
  ///
  /// In en, this message translates to:
  /// **'Lap'**
  String get utility59;

  /// No description provided for @utility60.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get utility60;

  /// No description provided for @utility61.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get utility61;

  /// No description provided for @utility62.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get utility62;

  /// No description provided for @utility63.
  ///
  /// In en, this message translates to:
  /// **'same time'**
  String get utility63;

  /// No description provided for @utility64.
  ///
  /// In en, this message translates to:
  /// **'UPPER'**
  String get utility64;

  /// No description provided for @utility65.
  ///
  /// In en, this message translates to:
  /// **'lower'**
  String get utility65;

  /// No description provided for @utility66.
  ///
  /// In en, this message translates to:
  /// **'Title Case'**
  String get utility66;

  /// No description provided for @utility67.
  ///
  /// In en, this message translates to:
  /// **'Sentence'**
  String get utility67;

  /// No description provided for @utility68.
  ///
  /// In en, this message translates to:
  /// **'Trim spaces'**
  String get utility68;

  /// No description provided for @utility69.
  ///
  /// In en, this message translates to:
  /// **'One line'**
  String get utility69;

  /// No description provided for @utility70.
  ///
  /// In en, this message translates to:
  /// **'Reverse'**
  String get utility70;

  /// No description provided for @utility71.
  ///
  /// In en, this message translates to:
  /// **'Slug'**
  String get utility71;

  /// No description provided for @utility72.
  ///
  /// In en, this message translates to:
  /// **'Base64 enc'**
  String get utility72;

  /// No description provided for @utility73.
  ///
  /// In en, this message translates to:
  /// **'Base64 dec'**
  String get utility73;

  /// No description provided for @utility74.
  ///
  /// In en, this message translates to:
  /// **'URL encode'**
  String get utility74;

  /// No description provided for @utility75.
  ///
  /// In en, this message translates to:
  /// **'URL decode'**
  String get utility75;

  /// No description provided for @utility76.
  ///
  /// In en, this message translates to:
  /// **'Count'**
  String get utility76;

  /// No description provided for @utility77.
  ///
  /// In en, this message translates to:
  /// **'UUID'**
  String get utility77;

  /// No description provided for @utility78.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get utility78;

  /// No description provided for @utility79.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get utility79;

  /// No description provided for @utility80.
  ///
  /// In en, this message translates to:
  /// **'ISO timestamp'**
  String get utility80;

  /// No description provided for @utility81.
  ///
  /// In en, this message translates to:
  /// **'Unix time'**
  String get utility81;

  /// No description provided for @utility82.
  ///
  /// In en, this message translates to:
  /// **'Random 1-100'**
  String get utility82;

  /// No description provided for @utility83.
  ///
  /// In en, this message translates to:
  /// **'Coin flip'**
  String get utility83;

  /// No description provided for @utility84.
  ///
  /// In en, this message translates to:
  /// **'Lorem sentence'**
  String get utility84;

  /// No description provided for @utility85.
  ///
  /// In en, this message translates to:
  /// **'Lorem paragraph'**
  String get utility85;

  /// No description provided for @utility86.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get utility86;

  /// No description provided for @utility87.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get utility87;

  /// No description provided for @utility88.
  ///
  /// In en, this message translates to:
  /// **'Pictures'**
  String get utility88;

  /// No description provided for @utility89.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get utility89;

  /// No description provided for @utility90.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get utility90;

  /// No description provided for @utility91.
  ///
  /// In en, this message translates to:
  /// **'This PC'**
  String get utility91;

  /// No description provided for @utility92.
  ///
  /// In en, this message translates to:
  /// **'Recycle Bin'**
  String get utility92;

  /// No description provided for @utility93.
  ///
  /// In en, this message translates to:
  /// **'Startup'**
  String get utility93;

  /// No description provided for @utility94.
  ///
  /// In en, this message translates to:
  /// **'Copy some text first'**
  String get utility94;

  /// No description provided for @utility95.
  ///
  /// In en, this message translates to:
  /// **'That text can’t be decoded'**
  String get utility95;

  /// No description provided for @utility96.
  ///
  /// In en, this message translates to:
  /// **'Clipboard updated'**
  String get utility96;

  /// No description provided for @utility97.
  ///
  /// In en, this message translates to:
  /// **'Password copied'**
  String get utility97;

  /// No description provided for @utility98.
  ///
  /// In en, this message translates to:
  /// **'⏰ Time is up!'**
  String get utility98;

  /// No description provided for @utility99.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get utility99;

  /// No description provided for @utility100.
  ///
  /// In en, this message translates to:
  /// **'Image copied'**
  String get utility100;

  /// No description provided for @utility101.
  ///
  /// In en, this message translates to:
  /// **'☀ PC stays awake'**
  String get utility101;

  /// No description provided for @utility102.
  ///
  /// In en, this message translates to:
  /// **'Sleep allowed again'**
  String get utility102;

  /// No description provided for @utility103.
  ///
  /// In en, this message translates to:
  /// **'No window to pin'**
  String get utility103;

  /// No description provided for @utility104.
  ///
  /// In en, this message translates to:
  /// **'Added {value}'**
  String utility104(Object value);

  /// No description provided for @utility105.
  ///
  /// In en, this message translates to:
  /// **'Picked {value}'**
  String utility105(Object value);

  /// No description provided for @utility106.
  ///
  /// In en, this message translates to:
  /// **'Panel moved to the {value}'**
  String utility106(Object value);

  /// No description provided for @utility107.
  ///
  /// In en, this message translates to:
  /// **'{value} → dock'**
  String utility107(Object value);

  /// No description provided for @utility108.
  ///
  /// In en, this message translates to:
  /// **'{words} words · {chars} chars · {lines} lines'**
  String utility108(Object chars, Object lines, Object words);

  /// No description provided for @utility109.
  ///
  /// In en, this message translates to:
  /// **'minute'**
  String get utility109;

  /// No description provided for @utility110.
  ///
  /// In en, this message translates to:
  /// **'Space'**
  String get utility110;

  /// No description provided for @utility111.
  ///
  /// In en, this message translates to:
  /// **'Heads'**
  String get utility111;

  /// No description provided for @utility112.
  ///
  /// In en, this message translates to:
  /// **'Tails'**
  String get utility112;

  /// No description provided for @addFolder.
  ///
  /// In en, this message translates to:
  /// **'Add folder…'**
  String get addFolder;

  /// No description provided for @appsAndShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Apps and shortcuts'**
  String get appsAndShortcuts;

  /// No description provided for @allFiles.
  ///
  /// In en, this message translates to:
  /// **'All files'**
  String get allFiles;

  /// No description provided for @utility113.
  ///
  /// In en, this message translates to:
  /// **'Pinned {value}'**
  String utility113(Object value);

  /// No description provided for @utility114.
  ///
  /// In en, this message translates to:
  /// **'Unpinned {value}'**
  String utility114(Object value);

  /// No description provided for @pinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get pinned;

  /// No description provided for @characters.
  ///
  /// In en, this message translates to:
  /// **'{count} characters'**
  String characters(Object count);

  /// No description provided for @image.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get image;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String minutesAgo(Object count);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} h ago'**
  String hoursAgo(Object count);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} d ago'**
  String daysAgo(Object count);

  /// No description provided for @weeksAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} wk ago'**
  String weeksAgo(Object count);

  /// No description provided for @monthsAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} mo ago'**
  String monthsAgo(Object count);

  /// No description provided for @yearsAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} yr ago'**
  String yearsAgo(Object count);

  /// No description provided for @utility115.
  ///
  /// In en, this message translates to:
  /// **'UTC'**
  String get utility115;

  /// No description provided for @utility116.
  ///
  /// In en, this message translates to:
  /// **'London'**
  String get utility116;

  /// No description provided for @utility117.
  ///
  /// In en, this message translates to:
  /// **'Paris'**
  String get utility117;

  /// No description provided for @utility118.
  ///
  /// In en, this message translates to:
  /// **'Berlin'**
  String get utility118;

  /// No description provided for @utility119.
  ///
  /// In en, this message translates to:
  /// **'Istanbul'**
  String get utility119;

  /// No description provided for @utility120.
  ///
  /// In en, this message translates to:
  /// **'Moscow'**
  String get utility120;

  /// No description provided for @utility121.
  ///
  /// In en, this message translates to:
  /// **'Tehran'**
  String get utility121;

  /// No description provided for @utility122.
  ///
  /// In en, this message translates to:
  /// **'Dubai'**
  String get utility122;

  /// No description provided for @utility123.
  ///
  /// In en, this message translates to:
  /// **'Karachi'**
  String get utility123;

  /// No description provided for @utility124.
  ///
  /// In en, this message translates to:
  /// **'Kolkata'**
  String get utility124;

  /// No description provided for @utility125.
  ///
  /// In en, this message translates to:
  /// **'Bangkok'**
  String get utility125;

  /// No description provided for @utility126.
  ///
  /// In en, this message translates to:
  /// **'Shanghai'**
  String get utility126;

  /// No description provided for @utility127.
  ///
  /// In en, this message translates to:
  /// **'Tokyo'**
  String get utility127;

  /// No description provided for @utility128.
  ///
  /// In en, this message translates to:
  /// **'Seoul'**
  String get utility128;

  /// No description provided for @utility129.
  ///
  /// In en, this message translates to:
  /// **'Sydney'**
  String get utility129;

  /// No description provided for @utility130.
  ///
  /// In en, this message translates to:
  /// **'Auckland'**
  String get utility130;

  /// No description provided for @utility131.
  ///
  /// In en, this message translates to:
  /// **'New York'**
  String get utility131;

  /// No description provided for @utility132.
  ///
  /// In en, this message translates to:
  /// **'Chicago'**
  String get utility132;

  /// No description provided for @utility133.
  ///
  /// In en, this message translates to:
  /// **'Denver'**
  String get utility133;

  /// No description provided for @utility134.
  ///
  /// In en, this message translates to:
  /// **'Los Angeles'**
  String get utility134;

  /// No description provided for @utility135.
  ///
  /// In en, this message translates to:
  /// **'Toronto'**
  String get utility135;

  /// No description provided for @utility136.
  ///
  /// In en, this message translates to:
  /// **'Sao Paulo'**
  String get utility136;

  /// No description provided for @utility137.
  ///
  /// In en, this message translates to:
  /// **'Mexico City'**
  String get utility137;

  /// No description provided for @utility138.
  ///
  /// In en, this message translates to:
  /// **'Cairo'**
  String get utility138;

  /// No description provided for @utility139.
  ///
  /// In en, this message translates to:
  /// **'Lagos'**
  String get utility139;

  /// No description provided for @utility140.
  ///
  /// In en, this message translates to:
  /// **'Could not change keep awake'**
  String get utility140;

  /// No description provided for @dropFiles.
  ///
  /// In en, this message translates to:
  /// **'Drop files or images to capture'**
  String get dropFiles;

  /// No description provided for @pinPanel.
  ///
  /// In en, this message translates to:
  /// **'Keep panel open'**
  String get pinPanel;

  /// No description provided for @unpinPanel.
  ///
  /// In en, this message translates to:
  /// **'Unpin panel'**
  String get unpinPanel;

  /// No description provided for @addImage.
  ///
  /// In en, this message translates to:
  /// **'Add image'**
  String get addImage;

  /// No description provided for @addAudio.
  ///
  /// In en, this message translates to:
  /// **'Add audio'**
  String get addAudio;

  /// No description provided for @noClipboardImage.
  ///
  /// In en, this message translates to:
  /// **'Copy an image first, or choose Add image.'**
  String get noClipboardImage;

  /// No description provided for @recording.
  ///
  /// In en, this message translates to:
  /// **'Recording… Press Stop to save.'**
  String get recording;

  /// No description provided for @backToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Back to library'**
  String get backToLibrary;

  /// No description provided for @editNote.
  ///
  /// In en, this message translates to:
  /// **'Edit note'**
  String get editNote;

  /// No description provided for @readNote.
  ///
  /// In en, this message translates to:
  /// **'Read note'**
  String get readNote;

  /// No description provided for @mediaUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This attachment could not be loaded.'**
  String get mediaUnavailable;

  /// No description provided for @tagsAndThreads.
  ///
  /// In en, this message translates to:
  /// **'Tags and threads'**
  String get tagsAndThreads;

  /// No description provided for @mediaAdded.
  ///
  /// In en, this message translates to:
  /// **'{count} attachment(s) saved · Open library'**
  String mediaAdded(int count);

  /// No description provided for @savedLocally.
  ///
  /// In en, this message translates to:
  /// **'Saved automatically on this device'**
  String get savedLocally;

  /// No description provided for @pasteText.
  ///
  /// In en, this message translates to:
  /// **'Paste text'**
  String get pasteText;

  /// No description provided for @pastePhoto.
  ///
  /// In en, this message translates to:
  /// **'Paste image'**
  String get pastePhoto;

  /// No description provided for @navCapture.
  ///
  /// In en, this message translates to:
  /// **'Capture'**
  String get navCapture;

  /// No description provided for @navTools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get navTools;

  /// No description provided for @interfaceMode.
  ///
  /// In en, this message translates to:
  /// **'Interface mode'**
  String get interfaceMode;

  /// No description provided for @windowMode.
  ///
  /// In en, this message translates to:
  /// **'Window'**
  String get windowMode;

  /// No description provided for @panelMode.
  ///
  /// In en, this message translates to:
  /// **'Edge panel'**
  String get panelMode;

  /// No description provided for @windowRemember.
  ///
  /// In en, this message translates to:
  /// **'Remember window size and position'**
  String get windowRemember;

  /// No description provided for @windowRememberHint.
  ///
  /// In en, this message translates to:
  /// **'Off: Nex opens as a compact card in the bottom-right corner, always at the same size.'**
  String get windowRememberHint;

  /// No description provided for @modeDescription.
  ///
  /// In en, this message translates to:
  /// **'The desktop window is the main experience; the edge panel stays available for quick capture. Both share the same notes, media and settings.'**
  String get modeDescription;

  /// No description provided for @edgePanelOnly.
  ///
  /// In en, this message translates to:
  /// **'Applies to the edge panel — switch the interface mode to use it.'**
  String get edgePanelOnly;

  /// No description provided for @switchToPanel.
  ///
  /// In en, this message translates to:
  /// **'Switch to edge panel'**
  String get switchToPanel;

  /// No description provided for @backToTools.
  ///
  /// In en, this message translates to:
  /// **'Back to tools'**
  String get backToTools;

  /// No description provided for @toolsHint.
  ///
  /// In en, this message translates to:
  /// **'Pick a tool to open it'**
  String get toolsHint;

  /// No description provided for @noEmojiFound.
  ///
  /// In en, this message translates to:
  /// **'No emoji found'**
  String get noEmojiFound;

  /// No description provided for @nothingYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing yet'**
  String get nothingYet;

  /// No description provided for @unknownUnit.
  ///
  /// In en, this message translates to:
  /// **'Unknown unit'**
  String get unknownUnit;

  /// No description provided for @hotkeyInUse.
  ///
  /// In en, this message translates to:
  /// **'That shortcut is already used by another app'**
  String get hotkeyInUse;

  /// No description provided for @laterToday.
  ///
  /// In en, this message translates to:
  /// **'Later today'**
  String get laterToday;

  /// No description provided for @tomorrowMorning.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow morning'**
  String get tomorrowMorning;

  /// No description provided for @customDateTime.
  ///
  /// In en, this message translates to:
  /// **'Date & time…'**
  String get customDateTime;

  /// No description provided for @repeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeat;

  /// No description provided for @noRepeat.
  ///
  /// In en, this message translates to:
  /// **'Does not repeat'**
  String get noRepeat;

  /// No description provided for @repeatDaily.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get repeatDaily;

  /// No description provided for @repeatWeekly.
  ///
  /// In en, this message translates to:
  /// **'Every week'**
  String get repeatWeekly;

  /// No description provided for @clearReminder.
  ///
  /// In en, this message translates to:
  /// **'Clear reminder'**
  String get clearReminder;

  /// No description provided for @reminderSet.
  ///
  /// In en, this message translates to:
  /// **'Reminder set'**
  String get reminderSet;

  /// No description provided for @overdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get overdue;

  /// No description provided for @shortcuts.
  ///
  /// In en, this message translates to:
  /// **'Shortcuts'**
  String get shortcuts;

  /// No description provided for @keyboardShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts'**
  String get keyboardShortcuts;

  /// No description provided for @actionNewNote.
  ///
  /// In en, this message translates to:
  /// **'New note'**
  String get actionNewNote;

  /// No description provided for @actionNewChecklist.
  ///
  /// In en, this message translates to:
  /// **'New checklist'**
  String get actionNewChecklist;

  /// No description provided for @actionSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get actionSearch;

  /// No description provided for @actionLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get actionLibrary;

  /// No description provided for @actionSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get actionSettings;

  /// No description provided for @actionMoveSelection.
  ///
  /// In en, this message translates to:
  /// **'Move selection'**
  String get actionMoveSelection;

  /// No description provided for @actionOpenNote.
  ///
  /// In en, this message translates to:
  /// **'Open note'**
  String get actionOpenNote;

  /// No description provided for @actionCloseOrClear.
  ///
  /// In en, this message translates to:
  /// **'Close reader / Clear search'**
  String get actionCloseOrClear;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionPin.
  ///
  /// In en, this message translates to:
  /// **'Pin / Unpin'**
  String get actionPin;

  /// No description provided for @actionCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get actionCopy;

  /// No description provided for @noNoteSelected.
  ///
  /// In en, this message translates to:
  /// **'No note selected'**
  String get noNoteSelected;

  /// No description provided for @todayTitle.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayTitle;

  /// No description provided for @dueCount.
  ///
  /// In en, this message translates to:
  /// **'{count} due'**
  String dueCount(int count);

  /// No description provided for @overdueCount.
  ///
  /// In en, this message translates to:
  /// **'{count} overdue'**
  String overdueCount(int count);

  /// No description provided for @emptyLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Your library is empty'**
  String get emptyLibraryTitle;

  /// No description provided for @emptyLibraryHint.
  ///
  /// In en, this message translates to:
  /// **'Capture first, think later. Everything stays on this PC.'**
  String get emptyLibraryHint;

  /// No description provided for @emptyLibraryWrite.
  ///
  /// In en, this message translates to:
  /// **'Write the first note'**
  String get emptyLibraryWrite;

  /// No description provided for @emptyLibraryTools.
  ///
  /// In en, this message translates to:
  /// **'Browse the tools'**
  String get emptyLibraryTools;

  /// No description provided for @emptyLibraryShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Learn the shortcuts'**
  String get emptyLibraryShortcuts;

  /// No description provided for @settingsDensity.
  ///
  /// In en, this message translates to:
  /// **'Card density'**
  String get settingsDensity;

  /// No description provided for @densityCompact.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get densityCompact;

  /// No description provided for @densityStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get densityStandard;

  /// No description provided for @densityReadable.
  ///
  /// In en, this message translates to:
  /// **'Readable'**
  String get densityReadable;

  /// No description provided for @paletteOpen.
  ///
  /// In en, this message translates to:
  /// **'Command palette'**
  String get paletteOpen;

  /// No description provided for @paletteSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search notes, screens and actions…'**
  String get paletteSearchHint;

  /// No description provided for @paletteNoResults.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches'**
  String get paletteNoResults;

  /// No description provided for @paletteSectionNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get paletteSectionNotes;

  /// No description provided for @paletteSectionActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get paletteSectionActions;

  /// No description provided for @paletteActionNewNote.
  ///
  /// In en, this message translates to:
  /// **'New note'**
  String get paletteActionNewNote;

  /// No description provided for @paletteActionToggleTheme.
  ///
  /// In en, this message translates to:
  /// **'Toggle light / dark theme'**
  String get paletteActionToggleTheme;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterAllTypes.
  ///
  /// In en, this message translates to:
  /// **'All types'**
  String get filterAllTypes;

  /// No description provided for @filterAllTags.
  ///
  /// In en, this message translates to:
  /// **'All tags'**
  String get filterAllTags;

  /// No description provided for @filterAllThreads.
  ///
  /// In en, this message translates to:
  /// **'All threads'**
  String get filterAllThreads;

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedCount(int count);

  /// No description provided for @clearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get clearSelection;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @restored.
  ///
  /// In en, this message translates to:
  /// **'Restored successfully'**
  String get restored;

  /// No description provided for @detailEmpty.
  ///
  /// In en, this message translates to:
  /// **'This note has no content yet.'**
  String get detailEmpty;

  /// No description provided for @wordCount.
  ///
  /// In en, this message translates to:
  /// **'{count} words'**
  String wordCount(int count);

  /// No description provided for @editorCount.
  ///
  /// In en, this message translates to:
  /// **'{words} words · {chars} characters'**
  String editorCount(int words, int chars);

  /// No description provided for @restoreConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Restoring replaces all current notes, tags and media with this backup. This cannot be undone.'**
  String get restoreConfirmBody;

  /// No description provided for @copyKey.
  ///
  /// In en, this message translates to:
  /// **'Copy key'**
  String get copyKey;

  /// No description provided for @settingsDisplay.
  ///
  /// In en, this message translates to:
  /// **'Display & interface'**
  String get settingsDisplay;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Shortcuts & input'**
  String get settingsShortcuts;

  /// No description provided for @settingsBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup & data safety'**
  String get settingsBackup;

  /// No description provided for @settingsTools.
  ///
  /// In en, this message translates to:
  /// **'Docked tools & apps'**
  String get settingsTools;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About Nex'**
  String get settingsAbout;

  /// No description provided for @colorMode.
  ///
  /// In en, this message translates to:
  /// **'Colour mode'**
  String get colorMode;

  /// No description provided for @appLanguage.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get appLanguage;

  /// No description provided for @libraryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The note library is not available on this device yet.'**
  String get libraryUnavailable;

  /// No description provided for @workspaceLocal.
  ///
  /// In en, this message translates to:
  /// **'Private. On this device.'**
  String get workspaceLocal;

  /// No description provided for @workspaceSearch.
  ///
  /// In en, this message translates to:
  /// **'Find or jump to…'**
  String get workspaceSearch;

  /// No description provided for @workspaceCaptureTitle.
  ///
  /// In en, this message translates to:
  /// **'Room for your\nnext thought.'**
  String get workspaceCaptureTitle;

  /// No description provided for @workspaceCaptureDescription.
  ///
  /// In en, this message translates to:
  /// **'A thought, a list, a little reminder. Start typing; Nex keeps it.'**
  String get workspaceCaptureDescription;

  /// No description provided for @workspaceCaptureFooter.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device. Always within reach.'**
  String get workspaceCaptureFooter;

  /// No description provided for @workspaceToolsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your everyday toolkit'**
  String get workspaceToolsTitle;

  /// No description provided for @workspaceToolsDescription.
  ///
  /// In en, this message translates to:
  /// **'Useful desktop tools, all in one place.'**
  String get workspaceToolsDescription;

  /// No description provided for @workspaceEssentials.
  ///
  /// In en, this message translates to:
  /// **'Within reach'**
  String get workspaceEssentials;

  /// No description provided for @workspaceUtilityHint.
  ///
  /// In en, this message translates to:
  /// **'Open this tool'**
  String get workspaceUtilityHint;

  /// No description provided for @workspaceClipboardHint.
  ///
  /// In en, this message translates to:
  /// **'What you copied, ready to use.'**
  String get workspaceClipboardHint;

  /// No description provided for @workspaceAwakeHint.
  ///
  /// In en, this message translates to:
  /// **'Keep your screen with you.'**
  String get workspaceAwakeHint;

  /// No description provided for @workspaceTimerHint.
  ///
  /// In en, this message translates to:
  /// **'A little time to focus.'**
  String get workspaceTimerHint;

  /// No description provided for @workspaceCalculatorHint.
  ///
  /// In en, this message translates to:
  /// **'Work out the little things.'**
  String get workspaceCalculatorHint;

  /// No description provided for @workspaceColorHint.
  ///
  /// In en, this message translates to:
  /// **'Pick a colour from anywhere.'**
  String get workspaceColorHint;

  /// No description provided for @workspaceReaderTitle.
  ///
  /// In en, this message translates to:
  /// **'A place to return to.'**
  String get workspaceReaderTitle;

  /// No description provided for @workspaceReaderHint.
  ///
  /// In en, this message translates to:
  /// **'Pick a note on the side. Your words get the whole page.'**
  String get workspaceReaderHint;

  /// No description provided for @workspaceToolsSearch.
  ///
  /// In en, this message translates to:
  /// **'Find a tool…'**
  String get workspaceToolsSearch;

  /// No description provided for @workspaceBrand.
  ///
  /// In en, this message translates to:
  /// **'Nex'**
  String get workspaceBrand;

  /// No description provided for @reminderFutureRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose a time in the future.'**
  String get reminderFutureRequired;

  /// No description provided for @notificationSettings.
  ///
  /// In en, this message translates to:
  /// **'Notification settings'**
  String get notificationSettings;

  /// No description provided for @testNotification.
  ///
  /// In en, this message translates to:
  /// **'Test notifications'**
  String get testNotification;

  /// No description provided for @testNotificationHint.
  ///
  /// In en, this message translates to:
  /// **'Shows one notification now and a second one 15 seconds later, so you can check both ways Nex delivers reminders.'**
  String get testNotificationHint;

  /// No description provided for @testNotificationRun.
  ///
  /// In en, this message translates to:
  /// **'Send test'**
  String get testNotificationRun;

  /// No description provided for @testNotificationSent.
  ///
  /// In en, this message translates to:
  /// **'Test sent. You should see one notification now and another in 15 seconds.'**
  String get testNotificationSent;

  /// No description provided for @testNotificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Windows did not accept the notification{detail}. Check Settings > System > Notifications and Focus assist.'**
  String testNotificationFailed(String detail);

  /// No description provided for @testNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'This is a test notification from Nex.'**
  String get testNotificationBody;

  /// No description provided for @testNotificationLater.
  ///
  /// In en, this message translates to:
  /// **'The scheduled test notification arrived.'**
  String get testNotificationLater;

  /// No description provided for @reminderDeliveryFailed.
  ///
  /// In en, this message translates to:
  /// **'The time was saved, but Windows could not schedule the notification. Check Windows notification settings and try again.'**
  String get reminderDeliveryFailed;

  /// No description provided for @reminderSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'The reminder could not be saved. Please try again.'**
  String get reminderSaveFailed;

  /// No description provided for @workspaceNotebook.
  ///
  /// In en, this message translates to:
  /// **'Your notebook'**
  String get workspaceNotebook;

  /// No description provided for @workspaceRecent.
  ///
  /// In en, this message translates to:
  /// **'Recently updated'**
  String get workspaceRecent;

  /// No description provided for @workspacePinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get workspacePinned;

  /// No description provided for @workspaceViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get workspaceViewAll;

  /// No description provided for @workspaceStartHint.
  ///
  /// In en, this message translates to:
  /// **'Your next note starts here. Recent notes stay within reach.'**
  String get workspaceStartHint;

  /// No description provided for @workspaceNoRecent.
  ///
  /// In en, this message translates to:
  /// **'Notes you capture will appear here.'**
  String get workspaceNoRecent;

  /// No description provided for @workspaceNoPinned.
  ///
  /// In en, this message translates to:
  /// **'Pin a note to keep it close.'**
  String get workspaceNoPinned;

  /// No description provided for @workspaceTotal.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get workspaceTotal;

  /// No description provided for @workspaceMedia.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get workspaceMedia;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// No description provided for @clipboardSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Clipboard history could not be saved. These changes are not yet safe after restart.'**
  String get clipboardSaveFailed;

  /// No description provided for @clipboardRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry saving'**
  String get clipboardRetry;

  /// No description provided for @applicationName.
  ///
  /// In en, this message translates to:
  /// **'Nex'**
  String get applicationName;

  /// No description provided for @manageTags.
  ///
  /// In en, this message translates to:
  /// **'Manage tags'**
  String get manageTags;

  /// No description provided for @tagDeleteHint.
  ///
  /// In en, this message translates to:
  /// **'Remove this tag from all notes? Your notes will be kept.'**
  String get tagDeleteHint;

  /// No description provided for @tagNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a unique tag name.'**
  String get tagNameRequired;

  /// No description provided for @toolDock.
  ///
  /// In en, this message translates to:
  /// **'Dock'**
  String get toolDock;

  /// No description provided for @toolMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get toolMore;

  /// No description provided for @toolHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get toolHidden;

  /// No description provided for @toolSearch.
  ///
  /// In en, this message translates to:
  /// **'Find a tool or shortcut'**
  String get toolSearch;

  /// No description provided for @minimizeWindow.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get minimizeWindow;

  /// No description provided for @maximizeWindow.
  ///
  /// In en, this message translates to:
  /// **'Maximize / Restore'**
  String get maximizeWindow;

  /// No description provided for @closeWindow.
  ///
  /// In en, this message translates to:
  /// **'Close window'**
  String get closeWindow;

  /// No description provided for @workspaceFocus.
  ///
  /// In en, this message translates to:
  /// **'Focus timer'**
  String get workspaceFocus;

  /// No description provided for @workspaceCalculate.
  ///
  /// In en, this message translates to:
  /// **'Calculator'**
  String get workspaceCalculate;

  /// No description provided for @workspaceCreate.
  ///
  /// In en, this message translates to:
  /// **'New note'**
  String get workspaceCreate;

  /// No description provided for @workspaceToolsWork.
  ///
  /// In en, this message translates to:
  /// **'Write & create'**
  String get workspaceToolsWork;

  /// No description provided for @workspaceToolsTime.
  ///
  /// In en, this message translates to:
  /// **'Time & focus'**
  String get workspaceToolsTime;

  /// No description provided for @workspaceToolsSystem.
  ///
  /// In en, this message translates to:
  /// **'Desktop & utilities'**
  String get workspaceToolsSystem;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @workspaceLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading your notes…'**
  String get workspaceLoading;

  /// No description provided for @workspaceClipboard.
  ///
  /// In en, this message translates to:
  /// **'Clipboard'**
  String get workspaceClipboard;

  /// No description provided for @followSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get followSystem;

  /// No description provided for @followTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme default'**
  String get followTheme;

  /// No description provided for @customAccent.
  ///
  /// In en, this message translates to:
  /// **'Accent color'**
  String get customAccent;

  /// No description provided for @textScale.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get textScale;

  /// No description provided for @solarCalendar.
  ///
  /// In en, this message translates to:
  /// **'Solar calendar'**
  String get solarCalendar;

  /// No description provided for @noteAttachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get noteAttachments;

  /// No description provided for @backupCompatibility.
  ///
  /// In en, this message translates to:
  /// **'Transfer notes, attachments and appearance between Nex apps. Clipboard, device settings, mobile vault and AI credentials stay on their own device.'**
  String get backupCompatibility;

  /// No description provided for @scheduledNotes.
  ///
  /// In en, this message translates to:
  /// **'Scheduled notes'**
  String get scheduledNotes;

  /// No description provided for @releaseNow.
  ///
  /// In en, this message translates to:
  /// **'Deliver now'**
  String get releaseNow;

  /// No description provided for @portableLibraryBackup.
  ///
  /// In en, this message translates to:
  /// **'Portable library backup · all Nex apps'**
  String get portableLibraryBackup;

  /// No description provided for @importBackupConfirm.
  ///
  /// In en, this message translates to:
  /// **'This is a Nex export. Its notes and attachments will be added to your library. Existing notes remain unchanged.'**
  String get importBackupConfirm;

  /// No description provided for @importNotes.
  ///
  /// In en, this message translates to:
  /// **'Import notes'**
  String get importNotes;

  /// No description provided for @importNotesDone.
  ///
  /// In en, this message translates to:
  /// **'Notes and attachments imported'**
  String get importNotesDone;

  /// No description provided for @themePalette.
  ///
  /// In en, this message translates to:
  /// **'App theme'**
  String get themePalette;

  /// No description provided for @hexColor.
  ///
  /// In en, this message translates to:
  /// **'HEX color'**
  String get hexColor;

  /// No description provided for @backupSaved.
  ///
  /// In en, this message translates to:
  /// **'Backup saved'**
  String get backupSaved;

  /// No description provided for @commitmentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Commitments & cadences'**
  String get commitmentsTitle;

  /// No description provided for @commitmentNew.
  ///
  /// In en, this message translates to:
  /// **'New commitment'**
  String get commitmentNew;

  /// No description provided for @commitmentEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit commitment'**
  String get commitmentEdit;

  /// No description provided for @commitmentEmpty.
  ///
  /// In en, this message translates to:
  /// **'No commitments recorded yet.'**
  String get commitmentEmpty;

  /// No description provided for @commitmentFirst.
  ///
  /// In en, this message translates to:
  /// **'Add first commitment'**
  String get commitmentFirst;

  /// No description provided for @commitmentCompleted.
  ///
  /// In en, this message translates to:
  /// **'Mark completed'**
  String get commitmentCompleted;

  /// No description provided for @commitmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get commitmentTitle;

  /// No description provided for @commitmentTitleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Pay rent, take medicine…'**
  String get commitmentTitleHint;

  /// No description provided for @commitmentCadence.
  ///
  /// In en, this message translates to:
  /// **'Cadence'**
  String get commitmentCadence;

  /// No description provided for @commitmentEvery.
  ///
  /// In en, this message translates to:
  /// **'Every'**
  String get commitmentEvery;

  /// No description provided for @commitmentWeekdays.
  ///
  /// In en, this message translates to:
  /// **'Weekdays:'**
  String get commitmentWeekdays;

  /// No description provided for @commitmentNotification.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get commitmentNotification;

  /// No description provided for @cadenceHourly.
  ///
  /// In en, this message translates to:
  /// **'Hourly'**
  String get cadenceHourly;

  /// No description provided for @cadenceDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get cadenceDaily;

  /// No description provided for @cadenceWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get cadenceWeekly;

  /// No description provided for @cadenceMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get cadenceMonthly;

  /// No description provided for @cadenceYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get cadenceYearly;

  /// No description provided for @cadenceEveryHours.
  ///
  /// In en, this message translates to:
  /// **'Every {count} hours'**
  String cadenceEveryHours(int count);

  /// No description provided for @cadenceEveryDays.
  ///
  /// In en, this message translates to:
  /// **'Every {count} days'**
  String cadenceEveryDays(int count);

  /// No description provided for @cadenceEveryWeeks.
  ///
  /// In en, this message translates to:
  /// **'Every {count} weeks'**
  String cadenceEveryWeeks(int count);

  /// No description provided for @cadenceEveryMonths.
  ///
  /// In en, this message translates to:
  /// **'Every {count} months'**
  String cadenceEveryMonths(int count);

  /// No description provided for @cadenceEveryYears.
  ///
  /// In en, this message translates to:
  /// **'Every {count} years'**
  String cadenceEveryYears(int count);

  /// No description provided for @backupFileType.
  ///
  /// In en, this message translates to:
  /// **'Nex backup'**
  String get backupFileType;

  /// No description provided for @hexColorHint.
  ///
  /// In en, this message translates to:
  /// **'#RRGGBB'**
  String get hexColorHint;

  /// No description provided for @utility141.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get utility141;

  /// No description provided for @utility142.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get utility142;

  /// No description provided for @weekdayMonday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get weekdayMonday;

  /// No description provided for @weekdayMondayShort.
  ///
  /// In en, this message translates to:
  /// **'M'**
  String get weekdayMondayShort;

  /// No description provided for @weekdayTuesday.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get weekdayTuesday;

  /// No description provided for @weekdayTuesdayShort.
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get weekdayTuesdayShort;

  /// No description provided for @weekdayWednesday.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get weekdayWednesday;

  /// No description provided for @weekdayWednesdayShort.
  ///
  /// In en, this message translates to:
  /// **'W'**
  String get weekdayWednesdayShort;

  /// No description provided for @weekdayThursday.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get weekdayThursday;

  /// No description provided for @weekdayThursdayShort.
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get weekdayThursdayShort;

  /// No description provided for @weekdayFriday.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get weekdayFriday;

  /// No description provided for @weekdayFridayShort.
  ///
  /// In en, this message translates to:
  /// **'F'**
  String get weekdayFridayShort;

  /// No description provided for @weekdaySaturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get weekdaySaturday;

  /// No description provided for @weekdaySaturdayShort.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get weekdaySaturdayShort;

  /// No description provided for @weekdaySunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get weekdaySunday;

  /// No description provided for @weekdaySundayShort.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get weekdaySundayShort;

  /// No description provided for @previousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get previousPage;

  /// No description provided for @nextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get nextPage;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @mediaPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous track'**
  String get mediaPrevious;

  /// No description provided for @mediaNext.
  ///
  /// In en, this message translates to:
  /// **'Next track'**
  String get mediaNext;

  /// No description provided for @mediaPlayPause.
  ///
  /// In en, this message translates to:
  /// **'Play or pause media'**
  String get mediaPlayPause;

  /// No description provided for @volumeDown.
  ///
  /// In en, this message translates to:
  /// **'Decrease volume'**
  String get volumeDown;

  /// No description provided for @volumeUp.
  ///
  /// In en, this message translates to:
  /// **'Increase volume'**
  String get volumeUp;

  /// No description provided for @volumeMute.
  ///
  /// In en, this message translates to:
  /// **'Mute or unmute'**
  String get volumeMute;

  /// No description provided for @chooseColor.
  ///
  /// In en, this message translates to:
  /// **'Choose color'**
  String get chooseColor;

  /// No description provided for @copyColor.
  ///
  /// In en, this message translates to:
  /// **'Copy color code'**
  String get copyColor;

  /// No description provided for @emojiCategory.
  ///
  /// In en, this message translates to:
  /// **'Emoji category'**
  String get emojiCategory;
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
      <String>['en', 'fa'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fa':
      return AppLocalizationsFa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
