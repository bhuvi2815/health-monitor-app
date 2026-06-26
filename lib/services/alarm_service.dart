// lib/services/alarm_service.dart
// Conditional import: uses web stub on browser, real mobile code on Android/iOS
export 'alarm_service_stub.dart'
    if (dart.library.io) 'alarm_service_mobile.dart';
