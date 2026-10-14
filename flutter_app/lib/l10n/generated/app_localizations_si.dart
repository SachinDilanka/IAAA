// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Sinhala Sinhalese (`si`).
class AppLocalizationsSi extends AppLocalizations {
  AppLocalizationsSi([String locale = 'si']) : super(locale);

  @override
  String get appTitle => 'සිඟිති කතා';

  @override
  String get appSubtitle => 'සිංහල කථන හා ශබ්ද පුහුණුව';

  @override
  String get language => 'භාෂාව';

  @override
  String get english => 'English';

  @override
  String get sinhala => 'සිංහල';

  @override
  String get home => 'මුල් පිටුව';

  @override
  String get letters => 'අකුරු';

  @override
  String get words => 'වචන';

  @override
  String get progress => 'ප්‍රගතිය';

  @override
  String get guardian => 'භාරකරු';

  @override
  String get hello => 'හායි! ආයුබෝවන්!';

  @override
  String get welcomeMessage => 'අද අපි ලස්සනට සිංහල කතා කරන්න පුහුණු වෙමුද?';

  @override
  String get listen => 'අහමු';

  @override
  String get speak => 'කියමු';

  @override
  String get earnStars => 'තරු දිනාගමු';

  @override
  String get stars => 'තරු';

  @override
  String get letterPractice => 'අකුරු පුහුණුව';

  @override
  String get letterPracticeDescription =>
      'මූලික සිංහල අකුරු සහ ශබ්ද සෙමින් පුහුණු වෙමු.';

  @override
  String get wordPractice => 'වචන පුහුණුව';

  @override
  String get wordPracticeDescription =>
      'හුරුපුරුදු සිංහල වචන 20ක් පියවරෙන් පියවර හදා කියමු.';

  @override
  String get cameraPractice => 'කැමරා හා හඬ පුහුණුව';

  @override
  String get cameraPracticeDescription =>
      'බලාගෙන, අසාගෙන, ඉලක්ක වචනය කියා සුහද ප්‍රතිචාර ලබාගමු.';

  @override
  String get myProgress => 'මගේ ප්‍රගතිය';

  @override
  String get progressDescription =>
      'සම්පූර්ණ කළ පුහුණු, තරු සහ මෑත ප්‍රගතිය බලමු.';

  @override
  String get start => 'පටන් ගමු';

  @override
  String get viewProgress => 'ප්‍රගතිය බලන්න';

  @override
  String get previous => 'පෙර';

  @override
  String get next => 'ඊළඟ';

  @override
  String get listenToSound => 'ශබ්දයට සවන් දෙන්න';

  @override
  String get iSaidIt => 'මම කිව්වා!';

  @override
  String get greatJob => 'සුපිරි! ඔයා හොඳට කළා!';

  @override
  String get activityAdded => 'ප්‍රගතියට එක් කළා!';

  @override
  String letterAddedMessage(String target) {
    return '$target අකුරු පුහුණුව සම්පූර්ණ කළ බව සටහන් කළා. තරු 3ක් ලැබුණා!';
  }

  @override
  String wordAddedMessage(String target) {
    return '$target වචන පුහුණුව සම්පූර්ණ කළ බව සටහන් කළා. තරු 3ක් ලැබුණා!';
  }

  @override
  String sayTarget(String target) {
    return '$target කියන්න';
  }

  @override
  String get openMouth => 'හොඳින් කට ඇරලා ශබ්දය සෙමින් කියන්න.';

  @override
  String buildWord(String target) {
    return '$target වචනය පියවරෙන් පියවර හදමු!';
  }

  @override
  String get addNextSound => 'ඊළඟ ශබ්දය එකතු කරන්න';

  @override
  String get completeWord => 'සම්පූර්ණ වචනය';

  @override
  String get wordComplete => 'සුපිරි! ඔබ වචනය සම්පූර්ණ කළා!';

  @override
  String get listenToWord => 'වචනය අහන්න';

  @override
  String get cameraTitle => 'කැමරා කැඩපත';

  @override
  String get cameraPrompt => 'කැඩපත ඉදිරියේ පුහුණු වීමට කැමරාව අරඹන්න.';

  @override
  String get privacyNote =>
      'ඡායාරූප ප්‍රතිචාර සඳහා පමණක් පරීක්ෂා කරන අතර යෙදුම තුළ ගබඩා නොකෙරේ.';

  @override
  String get startCamera => 'කැමරාව අරඹන්න';

  @override
  String get stopCamera => 'කැමරාව නවත්වන්න';

  @override
  String get analyzeExpression => 'හැඟීම පරීක්ෂා කරන්න';

  @override
  String get analyzing => 'පරීක්ෂා කරමින්...';

  @override
  String get speechRecognition => 'සජීවී කථන හඳුනාගැනීම';

  @override
  String get speechReady => 'සවන් දීමට සූදානම්';

  @override
  String get startListening => 'සවන් දීම අරඹන්න';

  @override
  String get stopListening => 'සවන් දීම නවත්වන්න';

  @override
  String get listening => 'සවන් දෙමින්...';

  @override
  String get recognizedSpeech => 'හඳුනාගත් කථනය';

  @override
  String get speechPlaceholder => 'දරුවා කියන දේ මෙතැන දිස්වනු ඇත.';

  @override
  String get targetRecognized => 'සුපිරි! ඉලක්ක වචනය හඳුනාගත්තා!';

  @override
  String get tryTargetAgain => 'ඉලක්ක වචනය නැවත කියා බලන්න.';

  @override
  String get speechUnavailable => 'මෙම උපකරණයේ සිංහල කථන හඳුනාගැනීම නොමැත.';

  @override
  String get happy => 'සතුටුයි';

  @override
  String get neutral => 'අවධානයෙන්';

  @override
  String get surprise => 'පුදුමයි';

  @override
  String get sad => 'නැවත උත්සාහ කරමු';

  @override
  String get fear => 'බිය නොවන්න';

  @override
  String get angry => 'සන්සුන් වෙමු';

  @override
  String get disgust => 'උත්සාහ කරමු';

  @override
  String get emotionHappyFeedback =>
      'සුපිරි! ඔයා ලස්සන සිනහවකින් පුහුණු වෙනවා!';

  @override
  String get emotionNeutralFeedback => 'හොඳ උත්සාහයක්! දිගටම පුහුණු වෙමු.';

  @override
  String get emotionSurpriseFeedback => 'නියමයි! ඔයා හොඳට කට ඇරලා ශබ්ද කළා.';

  @override
  String get emotionSupportFeedback => 'කමක් නෑ. අපි ආයෙත් හිමින් උත්සාහ කරමු.';

  @override
  String get completedActivities => 'සම්පූර්ණ කළ පුහුණු';

  @override
  String get starsEarned => 'දිනාගත් තරු';

  @override
  String get overallProgress => 'සමස්ත ප්‍රගතිය';

  @override
  String get recentPractice => 'මෑතකදී කළ පුහුණු';

  @override
  String get noPractice =>
      'තවම පුහුණුවක් සම්පූර්ණ කර නැත. අකුරු හෝ වචන පුහුණුවෙන් පටන් ගනිමු!';

  @override
  String get parentGuardianArea => 'දෙමාපිය, භාරකරු හා කථන චිකිත්සක අංශය';

  @override
  String get adultsOnly => 'වැඩිහිටියන් සඳහා';

  @override
  String get guardianSetupTitle =>
      'මෙම සැකසුම දෙමාපියෙකු හෝ භාරකරුවෙකු සම්පූර්ණ කරන්න';

  @override
  String get guardianSetupDescription =>
      'පුහුණුව අවුරුදු 4–10 දරුවන් සඳහායි. දරුවා පුහුණුව ආරම්භ කිරීමට පෙර පහත තොරතුරු පරීක්ෂා කරන්න.';

  @override
  String get guidance => 'දෙමාපියන් සහ භාරකරුවන් සඳහා මඟපෙන්වීම';

  @override
  String get guidanceOne =>
      'දිනකට විනාඩි 10–15ක් අකුරු සහ වචන සෙමින් පුහුණු වන්න.';

  @override
  String get guidanceTwo =>
      'හුරුපුරුදු වචනවලින් පටන් ගෙන ශබ්ද පියවරෙන් පියවර වෙන්කර කියන්න.';

  @override
  String get guidanceThree =>
      'දරුවා ශබ්දයක් නිවැරදිව පවසන විට නොමසුරුව ප්‍රශංසා කරන්න.';

  @override
  String get guidanceFour =>
      'පුහුණු කාලය සැහැල්ලු, සතුටුදායක සහ කෙටිව තබාගන්න.';

  @override
  String get childProfile => 'දරුවාගේ පුහුණු පැතිකඩ';

  @override
  String get profileDescription =>
      'යෙදුම දරුවා ඇමතිය යුතු නම සහ වයස ඇතුළත් කරන්න. පෞද්ගලිකත්වය සඳහා සුරතල් නමක් භාවිත කළ හැක.';

  @override
  String get childName => 'දරුවා ඇමතිය යුතු නම';

  @override
  String get childNameHint => 'මුල් නම හෝ පවුලේ සුරතල් නම';

  @override
  String get childAge => 'දරුවාගේ වයස';

  @override
  String get ageRange => 'වයස 4–10';

  @override
  String get saveProfile => 'දරුවාගේ පැතිකඩ සුරකින්න';

  @override
  String get saving => 'සුරකිමින්...';

  @override
  String get nameRequired => 'දරුවා ඇමතිය යුතු නමක් ඇතුළත් කරන්න.';

  @override
  String get ageInvalid => 'වයස අවුරුදු 4 සිට 10 දක්වා අගයක් ඇතුළත් කරන්න.';

  @override
  String get profileUpdated => 'පැතිකඩ යාවත්කාලීන කළා!';

  @override
  String profileUpdatedMessage(String name) {
    return '$nameගේ පැතිකඩ සාර්ථකව සුරැකිණි.';
  }

  @override
  String get confirmation => 'තහවුරු කිරීම';

  @override
  String get ok => 'හරි';

  @override
  String get retry => 'නැවත උත්සාහ කරන්න';

  @override
  String get loading => 'පූරණය වෙමින්...';

  @override
  String get cancel => 'අවලංගු කරන්න';

  @override
  String get errorTitle => 'දෝෂයක් ඇති විය';

  @override
  String get loadError =>
      'තොරතුරු පූරණය කළ නොහැකි විය. පුහුණු සේවාදායකය ක්‍රියාත්මකදැයි පරීක්ෂා කර නැවත උත්සාහ කරන්න.';

  @override
  String get saveError => 'වෙනස්කම් සුරැකීමට නොහැකි විය. නැවත උත්සාහ කරන්න.';

  @override
  String get cameraPermissionError =>
      'කැමරා කැඩපත් පුහුණුව සඳහා කැමරා අවසරය අවශ්‍යයි.';

  @override
  String get microphonePermissionError =>
      'කථන පුහුණුව සඳහා මයික්‍රෆෝන අවසරය අවශ්‍යයි.';

  @override
  String get audioUnavailableTitle => 'සිංහල හඬ ලබාගත නොහැක';

  @override
  String get audioUnavailableMessage =>
      'උපකරණයේ සැකසුම් තුළ සිංහල පෙළ-හඬ සේවාවක් ස්ථාපනය හෝ සක්‍රිය කර, මාධ්‍ය ශබ්දය වැඩි කර නැවත උත්සාහ කරන්න.';

  @override
  String get serverAddress => 'පුහුණු සේවාදායකය';

  @override
  String get learningTargetNote =>
      'සිංහල අකුරු සහ වචන ඉගෙනුම් ඉලක්ක බැවින් ඒවා සිංහලෙන්ම පෙන්වයි.';
}
