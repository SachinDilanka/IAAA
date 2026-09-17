import 'dart:typed_data';
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

      String channelId = 'sound_alert_high_v6';
      String channelName = '🚨 High Urgency Emergency Alerts';
      Importance importance = Importance.max;
      Priority priority = Priority.max;

      Int64List? vibrationPattern;
      if (event.priority == AlertLevel.high) {
        channelId = 'sound_alert_high_v6';
        channelName = '🚨 High Urgency Emergency Alerts';
        importance = Importance.max;
        priority = Priority.max;
        // Heavy, continuous incoming-call style vibration pattern for Yesido IO39 watch
        vibrationPattern = Int64List.fromList([0, 1500, 150, 1500, 150, 1500, 150, 1500, 150, 2000]);
      } else if (event.priority == AlertLevel.medium) {
        channelId = 'sound_alert_medium_v6';
        channelName = '⚠️ Medium Urgency Alerts';
        importance = Importance.high;
        priority = Priority.high;
        vibrationPattern = Int64List.fromList([0, 800, 150, 800, 150, 800, 150, 800]);
      } else {
        channelId = 'sound_alert_low_v6';
        channelName = '🟢 Low Urgency Alerts';
        importance = Importance.defaultImportance;
        priority = Priority.defaultPriority;
        vibrationPattern = Int64List.fromList([0, 400, 150, 400]);
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
        fullScreenIntent: true,
        playSound: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        category: AndroidNotificationCategory.alarm,
        ticker: '🚨 [EMERGENCY] ${event.titleSinhala} (${event.titleEnglish})',
        visibility: NotificationVisibility.public,
      );

      final NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      // YESIDO IO39 / SMARTWATCH COMPATIBLE FORMAT:
      // Basic smartwatches lack Sinhala Unicode fonts in their ROM.
      // Putting clear Latin/English text first guarantees the watch displays the alert clearly.
      final String priorityLabel = event.priority.name.toUpperCase();
      final String notificationTitle =
          '🚨 [$priorityLabel] ${event.titleEnglish} (${event.titleSinhala})';
      final String notificationBody =
          '🚨 ${event.titleEnglish.toUpperCase()}\nSinhala: ${event.titleSinhala}\n⚡ ${event.avatarGuidanceEnglish}\n${event.avatarGuidanceSinhala}';

      await _flutterLocalNotificationsPlugin.show(
        event.timestamp.millisecondsSinceEpoch ~/ 1000,
        notificationTitle,
        notificationBody,
        platformChannelSpecifics,
      );
    } catch (e) {}
  }
}
