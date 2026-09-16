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

      String channelId = 'sound_alert_high_v3';
      String channelName = '🚨 High Urgency Emergency Alerts';
      Importance importance = Importance.max;
      Priority priority = Priority.max;

      Int64List? vibrationPattern;
      if (event.priority == AlertLevel.high) {
        channelId = 'sound_alert_high_v3';
        channelName = '🚨 High Urgency Emergency Alerts';
        importance = Importance.max;
        priority = Priority.max;
        // Strong incoming-call style vibration pattern: 1500ms ON / 100ms OFF
        vibrationPattern = Int64List.fromList([0, 1500, 100, 1500, 100, 1500, 100, 1500]);
      } else if (event.priority == AlertLevel.medium) {
        channelId = 'sound_alert_medium_v3';
        channelName = '⚠️ Medium Urgency Alerts';
        importance = Importance.high;
        priority = Priority.high;
        vibrationPattern = Int64List.fromList([0, 800, 150, 800, 150, 800]);
      } else {
        channelId = 'sound_alert_low_v3';
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
        category: AndroidNotificationCategory.alarm,
        ticker: '🚨 EMERGENCY ALERT DETECTED!',
        visibility: NotificationVisibility.public,
      );

      final NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      // Prominent Sinhala Letters in the Title and Body for Yesido IO39 watch display
      final String notificationTitle =
          '🚨 [${event.priority.name}] ${event.titleSinhala} (${event.titleEnglish})';
      final String notificationBody =
          '${event.titleSinhala}\n⚡ ${event.avatarGuidanceSinhala}\n(${event.avatarGuidanceEnglish})';

      await _flutterLocalNotificationsPlugin.show(
        event.timestamp.millisecondsSinceEpoch ~/ 1000,
        notificationTitle,
        notificationBody,
        platformChannelSpecifics,
      );
    } catch (e) {}
  }
}
