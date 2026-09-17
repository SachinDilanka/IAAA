import '../models/alert_level.dart';
import '../models/detection_event.dart';

class PriorityEngine {
  final Map<String, DateTime> _lastAlertTimes = {};

  /// Rule-based mapping of raw model predictions to Priority Level and Guidance Text
  DetectionEvent? processPrediction({
    required String rawClass,
    required double confidence,
    double minThreshold = 0.20,
    bool bypassCooldown = false,
  }) {
    if (confidence < minThreshold || rawClass == 'background_other' || rawClass == 'background_traffic') {
      return null;
    }

    final AlertLevel priority = _determinePriority(rawClass);
    if (priority == AlertLevel.none) return null;

    final now = DateTime.now();
    final lastTime = _lastAlertTimes[rawClass];
    if (!bypassCooldown && lastTime != null) {
      final elapsed = now.difference(lastTime).inMilliseconds;
      // 8-second per-class cooldown — prevents spammy re-detection
      if (elapsed < 8000) {
        return null;
      }
    }

    _lastAlertTimes[rawClass] = now;

    final info = _getEventDetails(rawClass);

    return DetectionEvent(
      id: '${rawClass}_${now.millisecondsSinceEpoch}',
      rawClass: rawClass,
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
    switch (rawClass.toLowerCase().trim()) {
      // 🔴 HIGH PRIORITY (Critical Emergencies)
      case 'udaw':
      case 'udaw_karanna':
      case 'udau':
      case 'beeraganna':
      case 'beraganna':
      case 'ginnak':
      case 'ginna':
      case 'anathurak':
      case 'anaturak':
      case 'nawaththanna':
      case 'ambulance':
      case 'ambulance_siren':
      case 'ambulans':
      case 'firetruck':
      case 'fire_alarm':
      case 'fire_engine':
      case 'vehicle horns':
      case 'vehicle_horn':
      case 'car_horn':
      case 'screaming':
        return AlertLevel.high;

      // 🟡 MEDIUM PRIORITY (Caution & Warnings)
      case 'karadarayak':
      case 'karadare':
      case 'balagena':
      case 'balaagena':
      case 'parissamin':
      case 'parissamen':
      case 'ehata_wenna':
      case 'ehaata_wenna':
      case 'baby crying':
      case 'baby_crying':
      case 'baby':
        return AlertLevel.medium;

      // 🟢 LOW PRIORITY (Notices / Informational)
      case 'dog_bark':
      case 'dog_bark_':
      case 'dog_bark_dataset':
      case 'dog_barking':
      case 'bark':
      case 'road':
      case 'road_noise':
      case 'traffic':
      case 'traffic_noise':
        return AlertLevel.low;

      default:
        return AlertLevel.none;
    }
  }

  Map<String, String> _getEventDetails(String rawClass) {
    switch (rawClass.toLowerCase().trim()) {
      // 1. Core Sinhala Emergency Keyword Dataset (High Priority)
      case 'udaw':
      case 'udaw_karanna':
      case 'udau':
        return {
          'titleEnglish': '🆘 Keyword: HELP! ("udaw")',
          'titleSinhala': '🆘 හදිසි වචනය: "උදව් කරන්න!"',
          'guidanceEnglish': 'HELP CALL DETECTED! Someone near you is crying out for help.',
          'guidanceSinhala': '"උදව්" ඉල්ලීමේ හඬක් හඳුනාගන්නා ලදී! වහාම උපකාර කිරීමට පියවර ගන්න.',
        };
      case 'beeraganna':
      case 'beraganna':
        return {
          'titleEnglish': '🆘 Keyword: RESCUE ME! ("beeraganna")',
          'titleSinhala': '🆘 හදිසි වචනය: "බේරගන්න!"',
          'guidanceEnglish': 'RESCUE CALL DETECTED! "Save Me / Rescue Me" spoken urgently nearby.',
          'guidanceSinhala': '"බේරගන්න" යන හදිසි විපතක් පිළිබඳ වචනය හඳුනාගන්නා ලදී! වහාම පරීක්ෂා කරන්න.',
        };
      case 'ginnak':
      case 'ginna':
        return {
          'titleEnglish': '🔥 Keyword: FIRE! ("ginnak")',
          'titleSinhala': '🔥 හදිසි වචනය: "ගින්නක්!"',
          'guidanceEnglish': 'FIRE SPEECH DETECTED! Spoken warning for fire detected nearby.',
          'guidanceSinhala': '"ගින්නක්" යන හදිසි අනතුරු ඇඟවීම හඳුනාගන්නා ලදී! වහාම අවට ගින්නක් ඇත්දැයි බලන්න.',
        };
      case 'anathurak':
      case 'anaturak':
        return {
          'titleEnglish': '⚠️ Keyword: DANGER! ("anathurak")',
          'titleSinhala': '⚠️ හදිසි වචනය: "අනතුරක්!"',
          'guidanceEnglish': 'DANGER WARNING DETECTED! Danger/Hazard keyword spoken nearby.',
          'guidanceSinhala': '"අනතුරක්" යන හදිසි අනතුරු ඇඟවීමේ වචනය හඳුනාගන්නා ලදී! ප්‍රවේශම් වන්න.',
        };
      case 'nawaththanna':
        return {
          'titleEnglish': '🛑 Command: STOP! ("nawaththanna")',
          'titleSinhala': '🛑 හදිසි නියෝගය: "නවත්තන්න!"',
          'guidanceEnglish': 'STOP COMMAND DETECTED! Urgent halt command spoken.',
          'guidanceSinhala': '"නවත්තන්න" යන හදිසි නියෝගය හඳුනාගන්නා ලදී! වහාම නවතින්න.',
        };

      // 2. Sinhala Keyword Dataset (Medium Priority - Caution)
      case 'karadarayak':
      case 'karadare':
        return {
          'titleEnglish': '⚠️ Keyword: TROUBLE ("karadarayak")',
          'titleSinhala': '⚠️ අනතුරු ඇඟවීම: "කරදරයක්"',
          'guidanceEnglish': 'TROUBLE WARNING! Word indicating distress or trouble detected.',
          'guidanceSinhala': '"කරදරයක්" යන විපත් වචනය හඳුනාගන්නා ලදී. අවධානයෙන් සිටින්න.',
        };
      case 'balagena':
      case 'balaagena':
        return {
          'titleEnglish': '⚠️ Keyword: WATCH OUT ("balagena")',
          'titleSinhala': '⚠️ ප්‍රවේශම් වන්න: "බලාගෙන"',
          'guidanceEnglish': 'WATCH OUT WARNING! Caution spoken nearby. Check surroundings.',
          'guidanceSinhala': '"බලාගෙන" යන ප්‍රවේශම් වීමේ වචනය හඳුනාගන්නා ලදී. අවට බලන්න.',
        };
      case 'parissamin':
      case 'parissamen':
        return {
          'titleEnglish': '⚠️ Keyword: BE CAREFUL ("parissamin")',
          'titleSinhala': '⚠️ ප්‍රවේශම් වන්න: "පරිස්සමින්"',
          'guidanceEnglish': 'CAUTION DETECTED! "Be careful" spoken in immediate area.',
          'guidanceSinhala': '"පරිස්සමින්" යන අවවාදාත්මක වචනය හඳුනාගන්නා ලදී.',
        };
      case 'ehata_wenna':
      case 'ehaata_wenna':
        return {
          'titleEnglish': '⚠️ Command: MOVE AWAY ("ehata_wenna")',
          'titleSinhala': '⚠️ නියෝගය: "එහාට වෙන්න"',
          'guidanceEnglish': 'MOVE AWAY COMMAND! Command instructing to step aside detected.',
          'guidanceSinhala': '"එහාට වෙන්න" යන නියෝගය හඳුනාගන්නා ලදී. ඉඩ ලබා දෙන්න.',
        };

      // 3. Acoustic Emergency Dataset Sounds (High Priority)
      case 'ambulance':
      case 'ambulance_siren':
      case 'ambulans':
        return {
          'titleEnglish': '🚑 Ambulance Siren ("ambulance")',
          'titleSinhala': '🚑 ගිලන් රථ අනතුරු සංඥාව',
          'guidanceEnglish': 'AMBULANCE APPROACHING! Yield way for emergency vehicle.',
          'guidanceSinhala': 'ගිලන් රථයක් ළඟා වේ! හදිසි රථයට ඉඩ ලබා දෙන්න.',
        };
      case 'firetruck':
      case 'fire_alarm':
      case 'fire_engine':
        return {
          'titleEnglish': '🔥 Fire Truck Siren ("firetruck")',
          'titleSinhala': '🔥 ගිනි නිවන රථ අනතුරු සංඥාව',
          'guidanceEnglish': 'FIRE TRUCK / ALARM DETECTED! Evacuate immediately.',
          'guidanceSinhala': 'ගිනි නිවන රථ සංඥාවක් හඳුනාගන්නා ලදී! වහාම ආරක්ෂිත වන්න.',
        };
      case 'vehicle horns':
      case 'vehicle_horn':
      case 'car_horn':
        return {
          'titleEnglish': '🚗 Vehicle Horn ("vehicle horns")',
          'titleSinhala': '🚗 රථවාහන හෝන් ශබ්දය',
          'guidanceEnglish': 'VEHICLE HORN DETECTED! Watch out for oncoming vehicles.',
          'guidanceSinhala': 'වාහන හෝන් ශබ්දයක් හඳුනාගන්නා ලදී! වාහන පිළිබඳ පරිස්සම් වන්න.',
        };
      case 'screaming':
        return {
          'titleEnglish': '🆘 Distress Scream ("screaming")',
          'titleSinhala': '🆘 පුද්ගලයෙකුගේ කෑගැසීමක්',
          'guidanceEnglish': 'HUMAN DISTRESS SCREAM DETECTED! Look around carefully.',
          'guidanceSinhala': 'කෑගැසීමේ ශබ්දයක් හඳුනාගන්නා ලදී! අවධානයෙන් වටපිට බලන්න.',
        };

      // 4. Acoustic Dataset Sounds (Medium / Low Priority)
      case 'baby crying':
      case 'baby_crying':
      case 'baby':
        return {
          'titleEnglish': '👶 Baby Crying ("baby crying")',
          'titleSinhala': '👶 ළදරුවෙකු හඬන ශබ්දය',
          'guidanceEnglish': 'Baby crying sound detected in vicinity.',
          'guidanceSinhala': 'ළදරුවෙකු හඬන ශබ්දයක් හඳුනාගන්නා ලදී.',
        };
      case 'dog_bark':
      case 'dog_bark_':
      case 'dog_bark_dataset':
      case 'dog_barking':
      case 'bark':
        return {
          'titleEnglish': '🐕 Dog Barking ("dog_bark")',
          'titleSinhala': '🐕 බල්ලෙකු බුරන ශබ්දය',
          'guidanceEnglish': 'Dog barking sound detected in vicinity.',
          'guidanceSinhala': 'බල්ලෙකු බුරන ශබ්දයක් හඳුනාගන්නා ලදී.',
        };
      case 'road':
      case 'road_noise':
        return {
          'titleEnglish': '🛣️ Road Noise ("road")',
          'titleSinhala': '🛣️ මාර්ග ඝෝෂාව',
          'guidanceEnglish': 'Road ambient sound detected.',
          'guidanceSinhala': 'මාර්ග ශබ්ද හඳුනාගන්නා ලදී.',
        };
      case 'traffic':
      case 'traffic_noise':
        return {
          'titleEnglish': '🚦 Traffic Movement ("traffic")',
          'titleSinhala': '🚦 රථවාහන ගමනාගමනය',
          'guidanceEnglish': 'Traffic movement sound detected in background.',
          'guidanceSinhala': 'රථවාහන ගමනාගමන ශබ්ද හඳුනාගන්නා ලදී.',
        };

      default:
        return {
          'titleEnglish': 'Sound Detected ($rawClass)',
          'titleSinhala': 'ශබ්දයක් හඳුනාගන්නා ලදී ($rawClass)',
          'guidanceEnglish': 'Emergency sound or keyword detected.',
          'guidanceSinhala': 'හදිසි ශබ්දයක් හෝ වචනයක් හඳුනාගන්නා ලදී.',
        };
    }
  }
}
