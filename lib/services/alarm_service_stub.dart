// lib/services/alarm_service_stub.dart
// Used on WEB — all methods are empty stubs (web has no notifications)

class AlarmService {
  static Future<void> initialize() async {}

  static Future<void> scheduleMedicineAlarm({
    required int id,
    required String medicineName,
    required int hour,
    required int minute,
  }) async {}

  static Future<void> cancelAlarm(int id) async {}

  static Future<void> cancelAllAlarms() async {}

  static Future<void> showInstantNotification({
    required String title,
    required String body,
  }) async {}
}
