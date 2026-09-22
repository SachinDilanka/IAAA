import '../models/alert_level.dart';
import '../models/detection_event.dart';

/// Clean, high-performance Priority Engine for Sound & Sinhala Voice Alerts
class PriorityEngine {
  final Map<String, DateTime> _lastAlertTimes = {};

  /// Rule-based mapping of raw predictions to Priority Level and Guidance Text
  DetectionEvent? processPrediction({
    required String rawClass,
    required double confidence,
    double minThreshold = 0.20,
    bool bypassCooldown = false,
  }) {
    final cleanClass = rawClass.toLowerCase().trim();
    if (confidence < minThreshold || cleanClass == 'background_traffic' || cleanClass == 'background_other') {
      return null;
    }

    final AlertLevel priority = _determinePriority(cleanClass);
    if (priority == AlertLevel.none) return null;

    final now = DateTime.now();
    final lastTime = _lastAlertTimes[cleanClass];
    if (!bypassCooldown && lastTime != null) {
      final elapsed = now.difference(lastTime).inMilliseconds;
      if (elapsed < 1500) {
        return null;
      }
    }

    _lastAlertTimes[cleanClass] = now;
    final info = _getEventDetails(cleanClass);

    return DetectionEvent(
      id: '${cleanClass}_${now.millisecondsSinceEpoch}',
      rawClass: cleanClass,
      titleEnglish: info['titleEnglish']!,
      titleSinhala: info['titleSinhala']!,
      priority: priority,
      confidence: confidence,
      timestamp: now,
      avatarGuidanceEnglish: info['guidanceEnglish']!,
      avatarGuidanceSinhala: info['guidanceSinhala']!,
    );
  }

  AlertLevel _determinePriority(String rawClass) {
    switch (rawClass) {
      // 🔴 HIGH PRIORITY (Critical Emergencies)
      case 'udaw':
      case 'beeraganna':
      case 'ginnak':
      case 'fire_alarm':
      case 'anathurak':
      case 'ambulance':
      case 'ambulance_siren':
      case 'vehicle_horn':
      case 'vehicle horns':
        return AlertLevel.high;

      // 🟡 MEDIUM PRIORITY (Caution & Warnings)
      case 'karadarayak':
      case 'balagena':
      case 'parissamin':
      case 'ehata_wenna':
      case 'baby_crying':
      case 'baby crying':
        return AlertLevel.medium;

      // 🟢 LOW PRIORITY (Notices / Informational)
      case 'dog_barking':
      case 'dog_bark':
        return AlertLevel.low;

      default:
        return AlertLevel.none;
    }
  }

  Map<String, String> _getEventDetails(String rawClass) {
    switch (rawClass) {
      // 8 Sinhala Emergency Keywords
      case 'udaw':
        return {
          'titleEnglish': '🆘 Keyword: HELP! ("udaw")',
          'titleSinhala': '🆘 හදිසි වචනය: "උදව් කරන්න!"',
          'guidanceEnglish': 'HELP CALL DETECTED! Someone is asking for help.',
          'guidanceSinhala': '"උදව්" ඉල්ලීමේ හඬක් හඳුනාගන්නා ලදී! වහාම උපකාර කරන්න.',
        };
      case 'beeraganna':
      case 'beraganna':
        return {
          'titleEnglish': '🆘 Keyword: RESCUE ME! ("beeraganna")',
          'titleSinhala': '🆘 හදිසි වචනය: "බේරගන්න!"',
          'guidanceEnglish': 'RESCUE CALL DETECTED! Urgent rescue keyword spoken.',
          'guidanceSinhala': '"බේරගන්න" යන හදිසි විපතක් පිළිබඳ වචනය හඳුනාගන්නා ලදී!',
        };
      case 'ginnak':
      case 'ginna':
        return {
          'titleEnglish': '🔥 Keyword: FIRE! ("ginnak")',
          'titleSinhala': '🔥 හදිසි වචනය: "ගින්නක්!"',
          'guidanceEnglish': 'FIRE WARNING DETECTED! Spoken warning for fire.',
          'guidanceSinhala': '"ගින්නක්" යන හදිසි අනතුරු ඇඟවීම හඳුනාගන්නා ලදී!',
        };
      case 'anathurak':
      case 'anaturak':
        return {
          'titleEnglish': '⚠️ Keyword: DANGER! ("anathurak")',
          'titleSinhala': '⚠️ හදිසි වචනය: "අනතුරක්!"',
          'guidanceEnglish': 'DANGER WARNING DETECTED! Danger keyword spoken.',
          'guidanceSinhala': '"අනතුරක්" යන හදිසි අනතුරු ඇඟවීමේ වචනය හඳුනාගන්නා ලදී!',
        };
      case 'karadarayak':
      case 'karadare':
        return {
          'titleEnglish': '⚠️ Keyword: TROUBLE ("karadarayak")',
          'titleSinhala': '⚠️ අනතුරු ඇඟවීම: "කරදරයක්"',
          'guidanceEnglish': 'TROUBLE WARNING! Word indicating distress detected.',
          'guidanceSinhala': '"කරදරයක්" යන විපත් වචනය හඳුනාගන්නා ලදී.',
        };
      case 'balagena':
      case 'balaagena':
        return {
          'titleEnglish': '⚠️ Keyword: WATCH OUT ("balagena")',
          'titleSinhala': '⚠️ ප්‍රවේශම් වන්න: "බලාගෙන"',
          'guidanceEnglish': 'WATCH OUT WARNING! Caution spoken nearby.',
          'guidanceSinhala': '"බලාගෙන" යන ප්‍රවේශම් වීමේ වචනය හඳුනාගන්නා ලදී.',
        };
      case 'parissamin':
      case 'parissamen':
        return {
          'titleEnglish': '⚠️ Keyword: BE CAREFUL ("parissamin")',
          'titleSinhala': '⚠️ ප්‍රවේශම් වන්න: "පරිස්සමින්"',
          'guidanceEnglish': 'CAUTION DETECTED! "Be careful" spoken nearby.',
          'guidanceSinhala': '"පරිස්සමින්" යන අවවාදාත්මක වචනය හඳුනාගන්නා ලදී.',
        };
      case 'ehata_wenna':
      case 'ehaata_wenna':
        return {
          'titleEnglish': '⚠️ Command: MOVE AWAY ("ehata_wenna")',
          'titleSinhala': '⚠️ නියෝගය: "එහාට වෙන්න"',
          'guidanceEnglish': 'MOVE AWAY COMMAND! Command to step aside detected.',
          'guidanceSinhala': '"එහාට වෙන්න" යන නියෝගය හඳුනාගන්නා ලදී.',
        };

      // 4 Environmental Emergency Sounds
      case 'ambulance':
      case 'ambulance_siren':
        return {
          'titleEnglish': '🚑 Ambulance Siren ("ambulance")',
          'titleSinhala': '🚑 ගිලන් රථ අනතුරු සංඥාව',
          'guidanceEnglish': 'AMBULANCE APPROACHING! Yield way for emergency vehicle.',
          'guidanceSinhala': 'ගිලන් රථයක් ළඟා වේ! හදිසි රථයට ඉඩ ලබා දෙන්න.',
        };
      case 'vehicle_horn':
      case 'vehicle horns':
        return {
          'titleEnglish': '🚗 Vehicle Horn ("vehicle_horn")',
          'titleSinhala': '🚗 වාහන හෝන් ශබ්දය',
          'guidanceEnglish': 'VEHICLE HORN BLARING! Watch for approaching vehicle.',
          'guidanceSinhala': 'වාහන හෝන් ශබ්දයක් හඳුනාගන්නා ලදී! පරිස්සම් වන්න.',
        };
      case 'baby_crying':
      case 'baby crying':
        return {
          'titleEnglish': '👶 Baby Crying ("baby_crying")',
          'titleSinhala': '👶 ළදරු හැඬීමේ ශබ්දය',
          'guidanceEnglish': 'BABY CRYING SOUND! Infant needs attention.',
          'guidanceSinhala': 'ළදරුවෙකුගේ හැඬීමේ ශබ්දයක් හඳුනාගන්නා ලදී.',
        };
      case 'dog_barking':
      case 'dog_bark':
        return {
          'titleEnglish': '🐕 Dog Barking ("dog_barking")',
          'titleSinhala': '🐕 බල්ලා බිරීමේ ශබ්දය',
          'guidanceEnglish': 'DOG BARKING DETECTED! Dog barking nearby.',
          'guidanceSinhala': 'බල්ලා බිරීමේ ශබ්දයක් හඳුනාගන්නා ලදී.',
        };

      default:
        return {
          'titleEnglish': '🔔 Sound Detected: $rawClass',
          'titleSinhala': '🔔 ශබ්දයක් හඳුනාගන්නා ලදී: $rawClass',
          'guidanceEnglish': 'Acoustic event detected nearby.',
          'guidanceSinhala': 'අවට ශබ්දයක් හඳුනාගන්නා ලදී.',
        };
    }
  }
}
