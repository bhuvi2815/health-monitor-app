// lib/services/voice_alarm_service.dart
// Speaks medicine reminder in BOTH English and Tamil when alarm fires

import 'package:flutter_tts/flutter_tts.dart';

class VoiceAlarmService {
  static final FlutterTts _tts = FlutterTts();
  static bool _isInitialized = false;

  static Future<void> _init() async {
    if (_isInitialized) return;
    await _tts.setVolume(1.0);
    await _tts.setSpeechRate(0.45); // slightly slow for clarity
    await _tts.setPitch(1.0);
    _isInitialized = true;
  }

  // ── Speak alarm in English then Tamil ─────────────────────────
  static Future<void> speakMedicineReminder(String medicineName) async {
    await _init();

    // --- English ---
    await _tts.setLanguage('en-US');
    await _tts.speak(
      'Medicine reminder. Time to take your medicine: $medicineName. '
      'Please take it now.',
    );

    // Wait for English to finish before Tamil
    await Future.delayed(const Duration(seconds: 5));

    // --- Tamil ---
    await _tts.setLanguage('ta-IN');
    await _tts.speak(
      'மருந்து நினைவூட்டல். உங்கள் மருந்தை எடுத்துக்கொள்ளும் நேரம் வந்தது. '
      '$medicineName மருந்தை இப்போதே எடுத்துக்கொள்ளுங்கள். '
      'நன்றி.',
    );
  }

  // ── Speak a custom health tip ──────────────────────────────────
  static Future<void> speakHealthTip(String tip) async {
    await _init();
    await _tts.setLanguage('en-US');
    await _tts.speak(tip);
  }

  // ── Stop speaking ──────────────────────────────────────────────
  static Future<void> stop() async {
    await _tts.stop();
  }
}
