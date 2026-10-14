// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Little Voices';

  @override
  String get appSubtitle => 'Sinhala speech and sound practice';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get sinhala => 'සිංහල';

  @override
  String get home => 'Home';

  @override
  String get letters => 'Letters';

  @override
  String get words => 'Words';

  @override
  String get progress => 'Progress';

  @override
  String get guardian => 'Guardian';

  @override
  String get hello => 'Hello! Welcome!';

  @override
  String get welcomeMessage =>
      'Are you ready to practise speaking Sinhala today?';

  @override
  String get listen => 'Listen';

  @override
  String get speak => 'Speak';

  @override
  String get earnStars => 'Earn stars';

  @override
  String get stars => 'stars';

  @override
  String get letterPractice => 'Letter practice';

  @override
  String get letterPracticeDescription =>
      'Practise basic Sinhala letters and sounds at a comfortable pace.';

  @override
  String get wordPractice => 'Word practice';

  @override
  String get wordPracticeDescription =>
      'Build and say 20 familiar Sinhala words step by step.';

  @override
  String get cameraPractice => 'Camera and voice practice';

  @override
  String get cameraPracticeDescription =>
      'Watch, listen and say each target word with friendly feedback.';

  @override
  String get myProgress => 'My progress';

  @override
  String get progressDescription =>
      'Review completed activities, stars and recent practice.';

  @override
  String get start => 'Let\'s start';

  @override
  String get viewProgress => 'View progress';

  @override
  String get previous => 'Previous';

  @override
  String get next => 'Next';

  @override
  String get listenToSound => 'Listen to the sound';

  @override
  String get iSaidIt => 'I said it!';

  @override
  String get greatJob => 'Great job! You did it!';

  @override
  String get activityAdded => 'Added to progress!';

  @override
  String letterAddedMessage(String target) {
    return 'Letter practice for $target was recorded. You earned 3 stars!';
  }

  @override
  String wordAddedMessage(String target) {
    return 'Word practice for $target was recorded. You earned 3 stars!';
  }

  @override
  String sayTarget(String target) {
    return 'Say $target';
  }

  @override
  String get openMouth => 'Open your mouth clearly and say the sound slowly.';

  @override
  String buildWord(String target) {
    return 'Let\'s build $target step by step!';
  }

  @override
  String get addNextSound => 'Add the next sound';

  @override
  String get completeWord => 'Complete word';

  @override
  String get wordComplete => 'Great! You completed the word!';

  @override
  String get listenToWord => 'Listen to the word';

  @override
  String get cameraTitle => 'Camera mirror';

  @override
  String get cameraPrompt =>
      'Start the camera to practise in front of the mirror.';

  @override
  String get privacyNote =>
      'Photos are analyzed only for feedback and are not stored by the app.';

  @override
  String get startCamera => 'Start camera';

  @override
  String get stopCamera => 'Stop camera';

  @override
  String get analyzeExpression => 'Check expression';

  @override
  String get analyzing => 'Analyzing...';

  @override
  String get speechRecognition => 'Live speech recognition';

  @override
  String get speechReady => 'Ready to listen';

  @override
  String get startListening => 'Start listening';

  @override
  String get stopListening => 'Stop listening';

  @override
  String get listening => 'Listening...';

  @override
  String get recognizedSpeech => 'Recognized speech';

  @override
  String get speechPlaceholder => 'What your child says will appear here.';

  @override
  String get targetRecognized => 'Great! The target word was recognized!';

  @override
  String get tryTargetAgain => 'Please try saying the target word again.';

  @override
  String get speechUnavailable =>
      'Sinhala speech recognition is not available on this device.';

  @override
  String get happy => 'Happy';

  @override
  String get neutral => 'Focused';

  @override
  String get surprise => 'Surprised';

  @override
  String get sad => 'Let\'s try again';

  @override
  String get fear => 'You are safe';

  @override
  String get angry => 'Let\'s stay calm';

  @override
  String get disgust => 'Let\'s keep trying';

  @override
  String get emotionHappyFeedback =>
      'Wonderful! You are practising with a lovely smile!';

  @override
  String get emotionNeutralFeedback => 'Good effort! Let\'s keep practising.';

  @override
  String get emotionSurpriseFeedback =>
      'Great! You opened your mouth clearly for the sound.';

  @override
  String get emotionSupportFeedback =>
      'That\'s okay. Let\'s try again slowly together.';

  @override
  String get completedActivities => 'Completed activities';

  @override
  String get starsEarned => 'Stars earned';

  @override
  String get overallProgress => 'Overall progress';

  @override
  String get recentPractice => 'Recent practice';

  @override
  String get noPractice =>
      'No activities completed yet. Start with letter or word practice!';

  @override
  String get parentGuardianArea => 'Parent, guardian and speech therapist area';

  @override
  String get adultsOnly => 'For adults';

  @override
  String get guardianSetupTitle =>
      'A parent or guardian should complete this setup';

  @override
  String get guardianSetupDescription =>
      'Practice is designed for children aged 4–10. Review the information below before helping your child begin.';

  @override
  String get guidance => 'Guidance for parents and guardians';

  @override
  String get guidanceOne =>
      'Practise letters and words slowly for 10–15 minutes each day.';

  @override
  String get guidanceTwo =>
      'Begin with familiar words and separate each sound step by step.';

  @override
  String get guidanceThree =>
      'Praise your child generously when they produce a sound correctly.';

  @override
  String get guidanceFour => 'Keep sessions relaxed, positive and short.';

  @override
  String get childProfile => 'Child practice profile';

  @override
  String get profileDescription =>
      'Enter the name the app should use and your child\'s age. You may use a nickname for privacy.';

  @override
  String get childName => 'Name to use for your child';

  @override
  String get childNameHint => 'First name or family nickname';

  @override
  String get childAge => 'Child\'s age';

  @override
  String get ageRange => 'Ages 4–10';

  @override
  String get saveProfile => 'Save child profile';

  @override
  String get saving => 'Saving...';

  @override
  String get nameRequired => 'Enter the name you would like the app to use.';

  @override
  String get ageInvalid => 'Enter an age from 4 to 10.';

  @override
  String get profileUpdated => 'Profile updated!';

  @override
  String profileUpdatedMessage(String name) {
    return 'The profile for $name was saved successfully.';
  }

  @override
  String get confirmation => 'Confirmation';

  @override
  String get ok => 'OK';

  @override
  String get retry => 'Try again';

  @override
  String get loading => 'Loading...';

  @override
  String get cancel => 'Cancel';

  @override
  String get errorTitle => 'Something went wrong';

  @override
  String get loadError =>
      'The information could not be loaded. Check that the therapy server is running and try again.';

  @override
  String get saveError => 'Your changes could not be saved. Please try again.';

  @override
  String get cameraPermissionError =>
      'Camera access is required for mirror practice.';

  @override
  String get microphonePermissionError =>
      'Microphone access is required for speech practice.';

  @override
  String get audioUnavailableTitle => 'Sinhala voice unavailable';

  @override
  String get audioUnavailableMessage =>
      'Install or enable a Sinhala text-to-speech voice in your device settings, increase the media volume, and try again.';

  @override
  String get serverAddress => 'Therapy server';

  @override
  String get learningTargetNote =>
      'Sinhala letters and words remain in Sinhala because they are the learning targets.';
}
