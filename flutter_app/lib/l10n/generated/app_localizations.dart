import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_si.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
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
    Locale('si'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Little Voices'**
  String get appTitle;

  /// No description provided for @appSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sinhala speech and sound practice'**
  String get appSubtitle;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @sinhala.
  ///
  /// In en, this message translates to:
  /// **'සිංහල'**
  String get sinhala;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @letters.
  ///
  /// In en, this message translates to:
  /// **'Letters'**
  String get letters;

  /// No description provided for @words.
  ///
  /// In en, this message translates to:
  /// **'Words'**
  String get words;

  /// No description provided for @progress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// No description provided for @guardian.
  ///
  /// In en, this message translates to:
  /// **'Guardian'**
  String get guardian;

  /// No description provided for @hello.
  ///
  /// In en, this message translates to:
  /// **'Hello! Welcome!'**
  String get hello;

  /// No description provided for @welcomeMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you ready to practise speaking Sinhala today?'**
  String get welcomeMessage;

  /// No description provided for @listen.
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get listen;

  /// No description provided for @speak.
  ///
  /// In en, this message translates to:
  /// **'Speak'**
  String get speak;

  /// No description provided for @earnStars.
  ///
  /// In en, this message translates to:
  /// **'Earn stars'**
  String get earnStars;

  /// No description provided for @stars.
  ///
  /// In en, this message translates to:
  /// **'stars'**
  String get stars;

  /// No description provided for @letterPractice.
  ///
  /// In en, this message translates to:
  /// **'Letter practice'**
  String get letterPractice;

  /// No description provided for @letterPracticeDescription.
  ///
  /// In en, this message translates to:
  /// **'Practise basic Sinhala letters and sounds at a comfortable pace.'**
  String get letterPracticeDescription;

  /// No description provided for @wordPractice.
  ///
  /// In en, this message translates to:
  /// **'Word practice'**
  String get wordPractice;

  /// No description provided for @wordPracticeDescription.
  ///
  /// In en, this message translates to:
  /// **'Build and say 20 familiar Sinhala words step by step.'**
  String get wordPracticeDescription;

  /// No description provided for @cameraPractice.
  ///
  /// In en, this message translates to:
  /// **'Camera and voice practice'**
  String get cameraPractice;

  /// No description provided for @cameraPracticeDescription.
  ///
  /// In en, this message translates to:
  /// **'Watch, listen and say each target word with friendly feedback.'**
  String get cameraPracticeDescription;

  /// No description provided for @myProgress.
  ///
  /// In en, this message translates to:
  /// **'My progress'**
  String get myProgress;

  /// No description provided for @progressDescription.
  ///
  /// In en, this message translates to:
  /// **'Review completed activities, stars and recent practice.'**
  String get progressDescription;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Let\'s start'**
  String get start;

  /// No description provided for @viewProgress.
  ///
  /// In en, this message translates to:
  /// **'View progress'**
  String get viewProgress;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @listenToSound.
  ///
  /// In en, this message translates to:
  /// **'Listen to the sound'**
  String get listenToSound;

  /// No description provided for @iSaidIt.
  ///
  /// In en, this message translates to:
  /// **'I said it!'**
  String get iSaidIt;

  /// No description provided for @greatJob.
  ///
  /// In en, this message translates to:
  /// **'Great job! You did it!'**
  String get greatJob;

  /// No description provided for @activityAdded.
  ///
  /// In en, this message translates to:
  /// **'Added to progress!'**
  String get activityAdded;

  /// No description provided for @letterAddedMessage.
  ///
  /// In en, this message translates to:
  /// **'Letter practice for {target} was recorded. You earned 3 stars!'**
  String letterAddedMessage(String target);

  /// No description provided for @wordAddedMessage.
  ///
  /// In en, this message translates to:
  /// **'Word practice for {target} was recorded. You earned 3 stars!'**
  String wordAddedMessage(String target);

  /// No description provided for @sayTarget.
  ///
  /// In en, this message translates to:
  /// **'Say {target}'**
  String sayTarget(String target);

  /// No description provided for @openMouth.
  ///
  /// In en, this message translates to:
  /// **'Open your mouth clearly and say the sound slowly.'**
  String get openMouth;

  /// No description provided for @buildWord.
  ///
  /// In en, this message translates to:
  /// **'Let\'s build {target} step by step!'**
  String buildWord(String target);

  /// No description provided for @addNextSound.
  ///
  /// In en, this message translates to:
  /// **'Add the next sound'**
  String get addNextSound;

  /// No description provided for @completeWord.
  ///
  /// In en, this message translates to:
  /// **'Complete word'**
  String get completeWord;

  /// No description provided for @wordComplete.
  ///
  /// In en, this message translates to:
  /// **'Great! You completed the word!'**
  String get wordComplete;

  /// No description provided for @listenToWord.
  ///
  /// In en, this message translates to:
  /// **'Listen to the word'**
  String get listenToWord;

  /// No description provided for @cameraTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera mirror'**
  String get cameraTitle;

  /// No description provided for @cameraPrompt.
  ///
  /// In en, this message translates to:
  /// **'Start the camera to practise in front of the mirror.'**
  String get cameraPrompt;

  /// No description provided for @privacyNote.
  ///
  /// In en, this message translates to:
  /// **'Photos are analyzed only for feedback and are not stored by the app.'**
  String get privacyNote;

  /// No description provided for @startCamera.
  ///
  /// In en, this message translates to:
  /// **'Start camera'**
  String get startCamera;

  /// No description provided for @stopCamera.
  ///
  /// In en, this message translates to:
  /// **'Stop camera'**
  String get stopCamera;

  /// No description provided for @analyzeExpression.
  ///
  /// In en, this message translates to:
  /// **'Check expression'**
  String get analyzeExpression;

  /// No description provided for @analyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing...'**
  String get analyzing;

  /// No description provided for @speechRecognition.
  ///
  /// In en, this message translates to:
  /// **'Live speech recognition'**
  String get speechRecognition;

  /// No description provided for @speechReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to listen'**
  String get speechReady;

  /// No description provided for @startListening.
  ///
  /// In en, this message translates to:
  /// **'Start listening'**
  String get startListening;

  /// No description provided for @stopListening.
  ///
  /// In en, this message translates to:
  /// **'Stop listening'**
  String get stopListening;

  /// No description provided for @listening.
  ///
  /// In en, this message translates to:
  /// **'Listening...'**
  String get listening;

  /// No description provided for @recognizedSpeech.
  ///
  /// In en, this message translates to:
  /// **'Recognized speech'**
  String get recognizedSpeech;

  /// No description provided for @speechPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'What your child says will appear here.'**
  String get speechPlaceholder;

  /// No description provided for @targetRecognized.
  ///
  /// In en, this message translates to:
  /// **'Great! The target word was recognized!'**
  String get targetRecognized;

  /// No description provided for @tryTargetAgain.
  ///
  /// In en, this message translates to:
  /// **'Please try saying the target word again.'**
  String get tryTargetAgain;

  /// No description provided for @speechUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Sinhala speech recognition is not available on this device.'**
  String get speechUnavailable;

  /// No description provided for @happy.
  ///
  /// In en, this message translates to:
  /// **'Happy'**
  String get happy;

  /// No description provided for @neutral.
  ///
  /// In en, this message translates to:
  /// **'Focused'**
  String get neutral;

  /// No description provided for @surprise.
  ///
  /// In en, this message translates to:
  /// **'Surprised'**
  String get surprise;

  /// No description provided for @sad.
  ///
  /// In en, this message translates to:
  /// **'Let\'s try again'**
  String get sad;

  /// No description provided for @fear.
  ///
  /// In en, this message translates to:
  /// **'You are safe'**
  String get fear;

  /// No description provided for @angry.
  ///
  /// In en, this message translates to:
  /// **'Let\'s stay calm'**
  String get angry;

  /// No description provided for @disgust.
  ///
  /// In en, this message translates to:
  /// **'Let\'s keep trying'**
  String get disgust;

  /// No description provided for @emotionHappyFeedback.
  ///
  /// In en, this message translates to:
  /// **'Wonderful! You are practising with a lovely smile!'**
  String get emotionHappyFeedback;

  /// No description provided for @emotionNeutralFeedback.
  ///
  /// In en, this message translates to:
  /// **'Good effort! Let\'s keep practising.'**
  String get emotionNeutralFeedback;

  /// No description provided for @emotionSurpriseFeedback.
  ///
  /// In en, this message translates to:
  /// **'Great! You opened your mouth clearly for the sound.'**
  String get emotionSurpriseFeedback;

  /// No description provided for @emotionSupportFeedback.
  ///
  /// In en, this message translates to:
  /// **'That\'s okay. Let\'s try again slowly together.'**
  String get emotionSupportFeedback;

  /// No description provided for @completedActivities.
  ///
  /// In en, this message translates to:
  /// **'Completed activities'**
  String get completedActivities;

  /// No description provided for @starsEarned.
  ///
  /// In en, this message translates to:
  /// **'Stars earned'**
  String get starsEarned;

  /// No description provided for @overallProgress.
  ///
  /// In en, this message translates to:
  /// **'Overall progress'**
  String get overallProgress;

  /// No description provided for @recentPractice.
  ///
  /// In en, this message translates to:
  /// **'Recent practice'**
  String get recentPractice;

  /// No description provided for @noPractice.
  ///
  /// In en, this message translates to:
  /// **'No activities completed yet. Start with letter or word practice!'**
  String get noPractice;

  /// No description provided for @parentGuardianArea.
  ///
  /// In en, this message translates to:
  /// **'Parent, guardian and speech therapist area'**
  String get parentGuardianArea;

  /// No description provided for @adultsOnly.
  ///
  /// In en, this message translates to:
  /// **'For adults'**
  String get adultsOnly;

  /// No description provided for @guardianSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'A parent or guardian should complete this setup'**
  String get guardianSetupTitle;

  /// No description provided for @guardianSetupDescription.
  ///
  /// In en, this message translates to:
  /// **'Practice is designed for children aged 4–10. Review the information below before helping your child begin.'**
  String get guardianSetupDescription;

  /// No description provided for @guidance.
  ///
  /// In en, this message translates to:
  /// **'Guidance for parents and guardians'**
  String get guidance;

  /// No description provided for @guidanceOne.
  ///
  /// In en, this message translates to:
  /// **'Practise letters and words slowly for 10–15 minutes each day.'**
  String get guidanceOne;

  /// No description provided for @guidanceTwo.
  ///
  /// In en, this message translates to:
  /// **'Begin with familiar words and separate each sound step by step.'**
  String get guidanceTwo;

  /// No description provided for @guidanceThree.
  ///
  /// In en, this message translates to:
  /// **'Praise your child generously when they produce a sound correctly.'**
  String get guidanceThree;

  /// No description provided for @guidanceFour.
  ///
  /// In en, this message translates to:
  /// **'Keep sessions relaxed, positive and short.'**
  String get guidanceFour;

  /// No description provided for @childProfile.
  ///
  /// In en, this message translates to:
  /// **'Child practice profile'**
  String get childProfile;

  /// No description provided for @profileDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter the name the app should use and your child\'s age. You may use a nickname for privacy.'**
  String get profileDescription;

  /// No description provided for @childName.
  ///
  /// In en, this message translates to:
  /// **'Name to use for your child'**
  String get childName;

  /// No description provided for @childNameHint.
  ///
  /// In en, this message translates to:
  /// **'First name or family nickname'**
  String get childNameHint;

  /// No description provided for @childAge.
  ///
  /// In en, this message translates to:
  /// **'Child\'s age'**
  String get childAge;

  /// No description provided for @ageRange.
  ///
  /// In en, this message translates to:
  /// **'Ages 4–10'**
  String get ageRange;

  /// No description provided for @saveProfile.
  ///
  /// In en, this message translates to:
  /// **'Save child profile'**
  String get saveProfile;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get saving;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the name you would like the app to use.'**
  String get nameRequired;

  /// No description provided for @ageInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter an age from 4 to 10.'**
  String get ageInvalid;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated!'**
  String get profileUpdated;

  /// No description provided for @profileUpdatedMessage.
  ///
  /// In en, this message translates to:
  /// **'The profile for {name} was saved successfully.'**
  String profileUpdatedMessage(String name);

  /// No description provided for @confirmation.
  ///
  /// In en, this message translates to:
  /// **'Confirmation'**
  String get confirmation;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @errorTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorTitle;

  /// No description provided for @loadError.
  ///
  /// In en, this message translates to:
  /// **'The information could not be loaded. Check that the therapy server is running and try again.'**
  String get loadError;

  /// No description provided for @saveError.
  ///
  /// In en, this message translates to:
  /// **'Your changes could not be saved. Please try again.'**
  String get saveError;

  /// No description provided for @cameraPermissionError.
  ///
  /// In en, this message translates to:
  /// **'Camera access is required for mirror practice.'**
  String get cameraPermissionError;

  /// No description provided for @microphonePermissionError.
  ///
  /// In en, this message translates to:
  /// **'Microphone access is required for speech practice.'**
  String get microphonePermissionError;

  /// No description provided for @audioUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Sinhala voice unavailable'**
  String get audioUnavailableTitle;

  /// No description provided for @audioUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Install or enable a Sinhala text-to-speech voice in your device settings, increase the media volume, and try again.'**
  String get audioUnavailableMessage;

  /// No description provided for @serverAddress.
  ///
  /// In en, this message translates to:
  /// **'Therapy server'**
  String get serverAddress;

  /// No description provided for @learningTargetNote.
  ///
  /// In en, this message translates to:
  /// **'Sinhala letters and words remain in Sinhala because they are the learning targets.'**
  String get learningTargetNote;
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
      <String>['en', 'si'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'si':
      return AppLocalizationsSi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
