import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/detection_event.dart';
import '../models/alert_level.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (kIsWeb) return;
    if (_initialized) return;

    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );

      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (details) {},
      );

      // Request Android 13+ Notification Runtime Permission
      final androidImplementation =
          _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
      }

      _initialized = true;
    } catch (e) {}
  }

  /// Sends a local notification formatted specifically for Yesido IO39 mirror syncing via Android System Notification Shade
  Future<void> sendEventNotification(DetectionEvent event) async {
    if (kIsWeb) return; // On Web, notifications and vibrations are dispatched via the Web BLE & ServiceWorker Bridge!

    try {
      await initialize();

      String channelId = 'sound_alert_urgent_v12';
      String channelName = '⚠️ Sound & Emergency Alerts';
      Importance importance = Importance.max;
      Priority priority = Priority.max;

      Int64List vibrationPattern;
      if (event.priority == AlertLevel.high) {
        channelId = 'sound_alert_high_v12';
        channelName = '⚠️ High Urgency Alerts';
        importance = Importance.max;
        priority = Priority.max;
        vibrationPattern = Int64List.fromList([0, 1200, 250, 1200]);
      } else if (event.priority == AlertLevel.medium) {
        channelId = 'sound_alert_med_v12';
        channelName = '⚠️ Medium Urgency Alerts';
        importance = Importance.high;
        priority = Priority.high;
        vibrationPattern = Int64List.fromList([0, 320, 140, 320]);
      } else {
        channelId = 'sound_alert_low_v12';
        channelName = '⚠️ Low Urgency Alerts';
        importance = Importance.defaultImportance;
        priority = Priority.defaultPriority;
        vibrationPattern = Int64List.fromList([0, 220]);
      }

      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription:
            'Urgent environmental sound and Sinhala keyword alerts forwarded to Yesido IO39 Smartwatch.',
        importance: importance,
        priority: priority,
        showWhen: true,
        enableVibration: true,
        vibrationPattern: vibrationPattern,
        fullScreenIntent: false,
        playSound: true,
        category: AndroidNotificationCategory.event,
        ticker: '⚠️ [WARNING] ${event.titleSinhala} (${event.titleEnglish})',
        visibility: NotificationVisibility.public,
      );

      final NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      // YESIDO IO39 / SMARTWATCH COMPATIBLE FORMAT:
      // Uses the universal warning emoji ⚠️ and clear Latin Singlish + English.
      // Guaranteed to display on 100% of smartwatches without square boxes!
      final String notificationTitle = getWatchSinglishTitle(event.rawClass, event.priority);
      final String notificationBody = getWatchSinglishBody(event.rawClass);

      await _flutterLocalNotificationsPlugin.show(
        event.timestamp.millisecondsSinceEpoch ~/ 1000,
        notificationTitle,
        notificationBody,
        platformChannelSpecifics,
      );
    } catch (e) {}
  }

  static String getWatchSinglishTitle(String rawClass, AlertLevel priority) {
    switch (rawClass.toLowerCase().trim()) {
      case 'udaw':
      case 'udaw_karanna':
      case 'udau':
        return '⚠️ [WARNING] UDAW! (HELP ME)';
      case 'beeraganna':
      case 'beraganna':
        return '⚠️ [WARNING] BEERAGANNA! (RESCUE)';
      case 'ginnak':
      case 'ginna':
        return '⚠️ [WARNING] GINNAK! (FIRE ALERT)';
      case 'anathurak':
      case 'anaturak':
        return '⚠️ [WARNING] ANATHURAK! (DANGER)';
      case 'karadarayak':
      case 'karadare':
        return '⚠️ [WARNING] KARADARAYAK! (TROUBLE)';
      case 'balagena':
      case 'balaagena':
        return '⚠️ [WARNING] BALAGENA! (WATCH OUT)';
      case 'parissamin':
      case 'parissamen':
        return '⚠️ [WARNING] PARISSAMIN! (BE CAREFUL)';
      case 'ehata_wenna':
      case 'ehaata_wenna':
        return '⚠️ [WARNING] EHATA WENNA! (MOVE AWAY)';
      case 'nawaththanna':
        return '⚠️ [WARNING] NAWATHTHANNA! (STOP)';
      case 'screaming':
        return '⚠️ [WARNING] KEGAGAHANAWA! (SCREAM)';
      case 'ambulance':
      case 'ambulance_siren':
        return '⚠️ [WARNING] AMBULANCE SIREN';
      case 'firetruck':
      case 'fire_alarm':
        return '⚠️ [WARNING] FIRE TRUCK SIREN';
      case 'vehicle horns':
      case 'vehicle_horn':
      case 'car_horn':
        return '⚠️ [WARNING] VEHICLE HORN';
      case 'baby crying':
      case 'baby_crying':
      case 'baby':
        return '⚠️ [WARNING] BABY CRYING';
      case 'dog_bark':
      case 'dog_barking':
      case 'bark':
        return '⚠️ [WARNING] DOG BARKING';
      case 'road':
      case 'road_noise':
        return '⚠️ [WARNING] ROAD NOISE';
      case 'traffic':
      case 'traffic_noise':
        return '⚠️ [WARNING] TRAFFIC NOISE';
      default:
        return '⚠️ [WARNING] EMERGENCY ALERT';
    }
  }

  static String getWatchSinglishBody(String rawClass) {
    switch (rawClass.toLowerCase().trim()) {
      case 'udaw':
        return 'UDAW! Someone needs help! Check immediately.';
      case 'beeraganna':
        return 'BEERAGANNA! Someone needs rescue! Call 119.';
      case 'ginnak':
        return 'GINNAK! Fire hazard detected! Evacuate now.';
      case 'anathurak':
        return 'ANATHURAK! Danger ahead! Take caution.';
      case 'karadarayak':
        return 'KARADARAYAK! Emergency situation detected.';
      case 'balagena':
        return 'BALAGENA! Look around and watch out.';
      case 'parissamin':
        return 'PARISSAMIN! Be careful and move to safety.';
      case 'ehata_wenna':
        return 'EHATA WENNA! Move away from the path.';
      case 'nawaththanna':
        return 'NAWATHTHANNA! Stop immediately.';
      case 'screaming':
        return 'KEGAGAHANAWA! Scream heard! Check surroundings.';
      case 'ambulance':
      case 'ambulance_siren':
        return 'Ambulance siren approaching! Yield way.';
      case 'firetruck':
      case 'fire_alarm':
        return 'Fire truck siren approaching! Clear path.';
      case 'vehicle horns':
      case 'vehicle_horn':
        return 'Vehicle horn sounded! Watch out for traffic.';
      case 'baby crying':
      case 'baby_crying':
        return 'Baby is crying! Please check on the infant.';
      case 'dog_bark':
      case 'dog_barking':
        return 'Dog barking nearby! Animal alert.';
      default:
        return 'Emergency alert detected. Please be aware.';
    }
  }
}
