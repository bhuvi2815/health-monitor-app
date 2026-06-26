// lib/services/alarm_service_mobile.dart
// Used on ANDROID / iOS — real notification logic lives here

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class AlarmService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        print('Notification tapped: ${details.payload}');
      },
    );
  }

  static Future<void> scheduleMedicineAlarm({
    required int id,
    required String medicineName,
    required int hour,
    required int minute,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'medicine_channel',
      'Medicine Reminders',
      channelDescription: 'Reminders to take your medicine',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      fullScreenIntent: true,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.zonedSchedule(
      id,
      '💊 Medicine Reminder',
      'Time to take: $medicineName',
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: medicineName,
    );
  }

  static Future<void> cancelAlarm(int id) async {
    await _plugin.cancel(id);
  }

  static Future<void> cancelAllAlarms() async {
    await _plugin.cancelAll();
  }

  static Future<void> showInstantNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'instant_channel',
      'Instant Alerts',
      importance: Importance.max,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(0, title, body, details);
  }
}
