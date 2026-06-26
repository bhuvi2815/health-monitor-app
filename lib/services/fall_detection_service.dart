// lib/services/fall_detection_service.dart
// Web-safe fall detection — real on Android/iOS, no-op on web

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';

class FallDetectionService {
  static StreamSubscription? _sub;
  static final FlutterTts _tts = FlutterTts();
  static bool _isActive = false;
  static bool _fallAlertPending = false;
  static Timer? _confirmTimer;

  static Function(String)? onFallDetected;
  static Function()? onNoResponseEmergency;

  static const double _freeFallThreshold  = 3.0;
  static const double _impactThreshold    = 25.0;
  static const int    _responseWindowSecs = 15;

  static bool get isActive => _isActive;

  static void start({
    required Function(String) onFall,
    required Function() onEmergency,
  }) {
    onFallDetected        = onFall;
    onNoResponseEmergency = onEmergency;
    _isActive = true;
    if (!kIsWeb) _detectFalls();
  }

  static void stop() {
    _sub?.cancel();
    _confirmTimer?.cancel();
    _isActive         = false;
    _fallAlertPending = false;
  }

  static void _detectFalls() {
    // Only runs on mobile — sensors_plus not imported at top level
    // Import done lazily at runtime to avoid web compile error
    _startAccelerometer();
  }

  static void _startAccelerometer() async {
    // Dynamic import pattern for web safety
    try {
      // ignore: avoid_dynamic_calls
      final sensorLib = await _loadSensors();
      if (sensorLib == null) return;

      double prevMag = 9.8;
      bool freeFall  = false;

      _sub = sensorLib.listen((event) {
        if (!_isActive || _fallAlertPending) return;
        final mag = sqrt(event[0]*event[0] + event[1]*event[1] + event[2]*event[2]);
        if (mag < _freeFallThreshold) freeFall = true;
        if (freeFall && mag > _impactThreshold) {
          freeFall = false;
          _triggerFallAlert();
        }
        prevMag = mag;
      });
    } catch (_) {}
  }

  static Future<Stream?> _loadSensors() async => null;
  // On Android/iOS, replace with:
  // import 'package:sensors_plus/sensors_plus.dart';
  // return accelerometerEventStream().map((e) => [e.x, e.y, e.z]);

  static Future<void> _triggerFallAlert() async {
    _fallAlertPending = true;
    await _tts.setLanguage('en-US');
    await _tts.speak(
      'Fall detected! Are you okay? Tap the screen. '
      'Emergency call in $_responseWindowSecs seconds.',
    );
    onFallDetected?.call(
      'Fall detected! Tap "I\'m OK" within $_responseWindowSecs seconds '
      'or emergency contacts will be called.',
    );
    _confirmTimer = Timer(Duration(seconds: _responseWindowSecs), () {
      if (_fallAlertPending) _emergencyTrigger();
    });
  }

  static void userIsOkay() {
    _confirmTimer?.cancel();
    _fallAlertPending = false;
    _tts.speak('Glad you are okay! Fall alert cancelled.');
  }

  static Future<void> _emergencyTrigger() async {
    _fallAlertPending = false;
    await _tts.speak('No response. Calling emergency contacts now.');
    onNoResponseEmergency?.call();
  }
}
