// lib/services/health_alert_service.dart
// Detects critical health conditions from vitals + reports
// Returns danger level and recommended action

class HealthAlert {
  final DangerLevel level;
  final String title;
  final String message;
  final String tamiltitle;
  final String tamilMessage;
  final List<String> symptoms;
  final bool requiresHospital;

  const HealthAlert({
    required this.level,
    required this.title,
    required this.message,
    required this.tamiltitle,
    required this.tamilMessage,
    required this.symptoms,
    required this.requiresHospital,
  });
}

enum DangerLevel { safe, warning, danger, critical }

class HealthAlertService {
  // ── Analyse vitals and return alert ──────────────────────────────
  static HealthAlert analyseVitals({
    double? heartRate,
    double? systolic,
    double? diastolic,
    double? bloodSugar,
    double? temperature,
    int missedMedicines = 0,
  }) {
    final List<String> issues = [];
    DangerLevel level = DangerLevel.safe;

    // ── Heart Rate checks ─────────────────────────────────────────
    if (heartRate != null) {
      if (heartRate < 40 || heartRate > 150) {
        issues.add('Extreme heart rate: ${heartRate.toInt()} BPM');
        level = DangerLevel.critical;
      } else if (heartRate < 50 || heartRate > 120) {
        issues.add('Abnormal heart rate: ${heartRate.toInt()} BPM');
        if (level.index < DangerLevel.danger.index) level = DangerLevel.danger;
      } else if (heartRate < 60 || heartRate > 100) {
        issues.add('Heart rate slightly off: ${heartRate.toInt()} BPM');
        if (level.index < DangerLevel.warning.index) level = DangerLevel.warning;
      }
    }

    // ── Blood Pressure checks ─────────────────────────────────────
    if (systolic != null && diastolic != null) {
      if (systolic > 180 || diastolic > 120) {
        issues.add('Hypertensive crisis! BP: ${systolic.toInt()}/${diastolic.toInt()}');
        level = DangerLevel.critical;
      } else if (systolic > 140 || diastolic > 90) {
        issues.add('High blood pressure: ${systolic.toInt()}/${diastolic.toInt()}');
        if (level.index < DangerLevel.danger.index) level = DangerLevel.danger;
      } else if (systolic < 90 || diastolic < 60) {
        issues.add('Low blood pressure: ${systolic.toInt()}/${diastolic.toInt()}');
        if (level.index < DangerLevel.danger.index) level = DangerLevel.danger;
      }
    }

    // ── Blood Sugar checks ────────────────────────────────────────
    if (bloodSugar != null) {
      if (bloodSugar < 54 || bloodSugar > 400) {
        issues.add('Critical blood sugar: ${bloodSugar.toInt()} mg/dL');
        level = DangerLevel.critical;
      } else if (bloodSugar < 70 || bloodSugar > 250) {
        issues.add('Abnormal blood sugar: ${bloodSugar.toInt()} mg/dL');
        if (level.index < DangerLevel.danger.index) level = DangerLevel.danger;
      } else if (bloodSugar > 180) {
        issues.add('Elevated blood sugar: ${bloodSugar.toInt()} mg/dL');
        if (level.index < DangerLevel.warning.index) level = DangerLevel.warning;
      }
    }

    // ── Temperature checks ────────────────────────────────────────
    if (temperature != null) {
      if (temperature > 104 || temperature < 95) {
        issues.add('Dangerous temperature: $temperature°F');
        level = DangerLevel.critical;
      } else if (temperature > 101 || temperature < 96) {
        issues.add('Fever / hypothermia: $temperature°F');
        if (level.index < DangerLevel.danger.index) level = DangerLevel.danger;
      }
    }

    // ── Missed medicines ──────────────────────────────────────────
    if (missedMedicines >= 3) {
      issues.add('$missedMedicines medicines missed today');
      if (level.index < DangerLevel.warning.index) level = DangerLevel.warning;
    }

    return _buildAlert(level, issues);
  }

  // ── Build the alert object based on level ──────────────────────
  static HealthAlert _buildAlert(DangerLevel level, List<String> issues) {
    switch (level) {
      case DangerLevel.critical:
        return HealthAlert(
          level: level,
          title: '🚨 CRITICAL — Go to Hospital NOW',
          message: 'Your vitals are at a dangerous level. Please call emergency services or go to the nearest hospital immediately.',
          tamiltitle: '🚨 அவசரம் — உடனே மருத்துவமனை செல்லுங்கள்',
          tamilMessage: 'உங்கள் உடல் நிலை மிகவும் ஆபத்தான நிலையில் உள்ளது. உடனே அருகில் உள்ள மருத்துவமனைக்கு செல்லுங்கள்.',
          symptoms: issues,
          requiresHospital: true,
        );
      case DangerLevel.danger:
        return HealthAlert(
          level: level,
          title: '⚠️ DANGER — Visit Doctor Soon',
          message: 'Some of your health readings are concerning. Please consult a doctor as soon as possible.',
          tamiltitle: '⚠️ ஆபத்து — விரைவில் மருத்துவரை சந்தியுங்கள்',
          tamilMessage: 'உங்கள் சில உடல் அளவீடுகள் கவலைக்குரியதாக உள்ளன. விரைவில் மருத்துவரை சந்தியுங்கள்.',
          symptoms: issues,
          requiresHospital: true,
        );
      case DangerLevel.warning:
        return HealthAlert(
          level: level,
          title: '💛 WARNING — Monitor Closely',
          message: 'Some readings are slightly off. Monitor your health and take your medicines regularly.',
          tamiltitle: '💛 எச்சரிக்கை — கவனமாக கண்காணியுங்கள்',
          tamilMessage: 'சில அளவீடுகள் சற்று அதிகமாக உள்ளன. உங்கள் மருந்துகளை தவறாமல் எடுத்துக்கொள்ளுங்கள்.',
          symptoms: issues,
          requiresHospital: false,
        );
      default:
        return HealthAlert(
          level: DangerLevel.safe,
          title: '✅ All Good!',
          message: 'Your health readings are within normal range. Keep taking your medicines!',
          tamiltitle: '✅ நலமாக இருக்கிறீர்கள்!',
          tamilMessage: 'உங்கள் உடல் நிலை சாதாரண வரம்பில் உள்ளது. மருந்துகளை தொடர்ந்து எடுத்துக்கொள்ளுங்கள்!',
          symptoms: [],
          requiresHospital: false,
        );
    }
  }

  // ── Quick color for UI ─────────────────────────────────────────
  static int alertColor(DangerLevel level) {
    switch (level) {
      case DangerLevel.critical: return 0xFFEF4444;
      case DangerLevel.danger:   return 0xFFF97316;
      case DangerLevel.warning:  return 0xFFF59E0B;
      default:                   return 0xFF10B981;
    }
  }
}
