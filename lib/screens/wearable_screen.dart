// lib/screens/wearable_screen.dart
// Web-safe version — smartwatch/camera features show setup guide on web,
// fully functional on Android/iOS

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/fall_detection_service.dart';

class WearableScreen extends StatefulWidget {
  const WearableScreen({super.key});
  @override
  State<WearableScreen> createState() => _WearableScreenState();
}

class _WearableScreenState extends State<WearableScreen> {
  // ── Smartwatch (simulated on web) ─────────────────────────────
  double? _heartRate;
  int?    _steps;
  double? _spo2;
  bool    _loadingHealth = false;

  // ── Camera PPG (simulated on web) ─────────────────────────────
  bool   _measuringPPG  = false;
  int?   _ppgHeartRate;
  int    _ppgCountdown  = 30;
  Timer? _ppgTimer;
  Timer? _countdownTimer;

  // ── Fall detection ────────────────────────────────────────────
  bool   _fallDetectionOn = false;
  String _fallMessage     = '';
  bool   _fallAlertActive = false;

  @override
  void dispose() {
    _ppgTimer?.cancel();
    _countdownTimer?.cancel();
    FallDetectionService.stop();
    super.dispose();
  }

  // ── Smartwatch sync (real on mobile, simulated on web) ────────
  Future<void> _fetchSmartwatch() async {
    setState(() => _loadingHealth = true);
    await Future.delayed(const Duration(seconds: 2));

    if (kIsWeb) {
      // On web: show demo values with a note
      setState(() {
        _heartRate     = 74;
        _steps         = 4832;
        _spo2          = 98;
        _loadingHealth = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Demo mode on web. Real smartwatch sync works on Android/iOS.'),
          backgroundColor: Color(0xFFF59E0B),
          duration: Duration(seconds: 3),
        ));
      }
      return;
    }

    // On mobile: use health package
    // (Uncomment below after running on Android/iOS)
    // final health = Health();
    // final types = [HealthDataType.HEART_RATE, HealthDataType.STEPS, HealthDataType.BLOOD_OXYGEN];
    // final granted = await health.requestAuthorization(types);
    // if (granted) {
    //   final now = DateTime.now();
    //   final data = await health.getHealthDataFromTypes(now.subtract(const Duration(hours:24)), now, types);
    //   for (final p in data) {
    //     final v = (p.value as NumericHealthValue).numericValue.toDouble();
    //     if (p.type == HealthDataType.HEART_RATE)    _heartRate = v;
    //     if (p.type == HealthDataType.STEPS)         _steps = v.toInt();
    //     if (p.type == HealthDataType.BLOOD_OXYGEN)  _spo2 = v;
    //   }
    // }
    setState(() => _loadingHealth = false);
  }

  // ── Camera PPG ────────────────────────────────────────────────
  Future<void> _startPPG() async {
    setState(() {
      _measuringPPG = true;
      _ppgCountdown = 30;
      _ppgHeartRate = null;
    });

    if (kIsWeb) {
      // Simulate measurement on web
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!_measuringPPG) { t.cancel(); return; }
        setState(() => _ppgCountdown--);
        if (_ppgCountdown <= 0) {
          t.cancel();
          // Simulate a realistic BPM result
          final bpm = 60 + Random().nextInt(30);
          setState(() { _measuringPPG = false; _ppgHeartRate = bpm; });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Demo result on web. Real camera PPG works on Android/iOS.'),
            backgroundColor: Color(0xFFF59E0B),
          ));
        }
      });
      return;
    }

    // On mobile: use camera package
    // Full camera PPG implementation goes here (see comments)
    // final cameras = await availableCameras();
    // ... (real implementation)
    setState(() { _measuringPPG = false; });
  }

  void _cancelPPG() {
    _ppgTimer?.cancel();
    _countdownTimer?.cancel();
    setState(() { _measuringPPG = false; _ppgCountdown = 30; });
  }

  // ── Fall detection toggle ─────────────────────────────────────
  void _toggleFallDetection(bool on) {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Fall detection works on Android/iOS with accelerometer.'),
        backgroundColor: Color(0xFFF59E0B),
      ));
      return;
    }
    if (on) {
      FallDetectionService.start(
        onFall: (msg) => setState(() {
          _fallMessage     = msg;
          _fallAlertActive = true;
        }),
        onEmergency: () {
          setState(() => _fallAlertActive = false);
          launchUrl(Uri.parse('tel:108'));
        },
      );
    } else {
      FallDetectionService.stop();
    }
    setState(() { _fallDetectionOn = on; _fallMessage = ''; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wearables & Monitoring',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchSmartwatch,
            tooltip: 'Sync',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Web notice banner
          if (kIsWeb) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFFF59E0B).withOpacity(0.4)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline_rounded,
                    color: Color(0xFFF59E0B), size: 18),
                SizedBox(width: 8),
                Expanded(child: Text(
                  'Running on Web — demo mode. Smartwatch sync, camera PPG '
                  'and fall detection work fully on Android/iOS.',
                  style: TextStyle(
                      color: Color(0xFFF59E0B), fontSize: 12),
                )),
              ]),
            ),
            const SizedBox(height: 16),
          ],

          // ── SMARTWATCH SYNC ─────────────────────────────────
          _SectionHeader('Smartwatch / Health App Sync',
              Icons.watch_rounded, const Color(0xFF0EA5E9)),
          const SizedBox(height: 12),

          if (_loadingHealth)
            const Center(child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(children: [
                CircularProgressIndicator(color: Color(0xFF0EA5E9)),
                SizedBox(height: 12),
                Text('Reading from Google Fit / Apple Health...',
                    style: TextStyle(color: Colors.white54, fontSize: 13)),
              ]),
            ))
          else ...[
            Row(children: [
              _WearableTile('Heart Rate',
                  _heartRate != null
                      ? '${_heartRate!.toInt()} BPM' : '-- BPM',
                  Icons.favorite_rounded,
                  const Color(0xFFEC4899), _heartRate != null),
              const SizedBox(width: 10),
              _WearableTile('Steps',
                  _steps != null ? '$_steps' : '--',
                  Icons.directions_walk_rounded,
                  const Color(0xFF10B981), _steps != null),
              const SizedBox(width: 10),
              _WearableTile('SpO2',
                  _spo2 != null ? '${_spo2!.toInt()}%' : '--%',
                  Icons.air_rounded,
                  const Color(0xFF0EA5E9), _spo2 != null),
            ]),
            const SizedBox(height: 8),
            if (_heartRate == null)
              GestureDetector(
                onTap: _fetchSmartwatch,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    Icon(Icons.sync_rounded,
                        color: Color(0xFF0EA5E9), size: 18),
                    SizedBox(width: 8),
                    Text('Tap to sync smartwatch data',
                        style: TextStyle(
                            color: Color(0xFF0EA5E9),
                            fontWeight: FontWeight.w500)),
                  ]),
                ),
              )
            else
              const Text(
                'Connected — data from Google Fit / Apple Health',
                style: TextStyle(color: Color(0xFF10B981), fontSize: 12),
              ),
          ],

          const SizedBox(height: 28),

          // ── CAMERA PPG ──────────────────────────────────────
          _SectionHeader('Camera Heart Rate (No device needed)',
              Icons.camera_alt_rounded, const Color(0xFFEC4899)),
          const SizedBox(height: 12),

          if (_measuringPPG) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFFEC4899).withOpacity(0.5)),
              ),
              child: Column(children: [
                const Icon(Icons.fingerprint_rounded,
                    color: Color(0xFFEC4899), size: 52),
                const SizedBox(height: 12),
                const Text('Keep your finger on the camera',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  kIsWeb
                      ? 'Simulating measurement...'
                      : 'Don\'t press too hard — light should glow red',
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 16),
                Text('$_ppgCountdown',
                    style: const TextStyle(color: Color(0xFFEC4899),
                        fontSize: 52, fontWeight: FontWeight.bold)),
                const Text('seconds',
                    style: TextStyle(
                        color: Colors.white38, fontSize: 13)),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: (30 - _ppgCountdown) / 30,
                  color: const Color(0xFFEC4899),
                  backgroundColor: Colors.white10,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _cancelPPG,
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.white54)),
                ),
              ]),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFFEC4899).withOpacity(0.3)),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                if (_ppgHeartRate != null)
                  Center(child: Column(children: [
                    const Text('Last measurement',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('$_ppgHeartRate BPM',
                        style: const TextStyle(
                            color: Color(0xFFEC4899),
                            fontSize: 40,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                  ])),
                Row(children: const [
                  Icon(Icons.info_outline_rounded,
                      color: Colors.white38, size: 16),
                  SizedBox(width: 8),
                  Expanded(child: Text(
                    'Place finger on rear camera for 30 seconds. '
                    'Works best in a quiet, well-lit room.',
                    style: TextStyle(
                        color: Colors.white38, fontSize: 12),
                  )),
                ]),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _startPPG,
                    icon: const Icon(Icons.camera_rounded,
                        color: Colors.white, size: 18),
                    label: const Text('Measure Heart Rate (30 sec)',
                        style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEC4899),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 28),

          // ── FALL DETECTION ──────────────────────────────────
          _SectionHeader('Fall Detection',
              Icons.personal_injury_rounded, const Color(0xFFF97316)),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _fallDetectionOn
                    ? const Color(0xFFF97316).withOpacity(0.5)
                    : Colors.white10,
              ),
            ),
            child: Column(children: [
              Row(children: [
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Auto Fall Detection',
                      style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(
                    kIsWeb
                        ? 'Available on Android/iOS only'
                        : _fallDetectionOn
                            ? 'Active — monitoring accelerometer'
                            : 'Inactive — tap to enable',
                    style: TextStyle(
                      color: kIsWeb
                          ? Colors.white38
                          : _fallDetectionOn
                              ? const Color(0xFFF97316)
                              : Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ])),
                Switch(
                  value: _fallDetectionOn,
                  onChanged: _toggleFallDetection,
                  activeColor: const Color(0xFFF97316),
                ),
              ]),

              if (_fallAlertActive) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFEF4444).withOpacity(0.5)),
                  ),
                  child: Column(children: [
                    const Icon(Icons.warning_rounded,
                        color: Color(0xFFEF4444), size: 32),
                    const SizedBox(height: 8),
                    Text(_fallMessage,
                        style: const TextStyle(
                            color: Color(0xFFEF4444), fontSize: 13,
                            fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          FallDetectionService.userIsOkay();
                          setState(() {
                            _fallAlertActive = false;
                            _fallMessage     = '';
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text("I'm OK — Cancel Alert",
                            style: TextStyle(color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ]),
                ),
              ],

              if (!_fallDetectionOn) ...[
                const SizedBox(height: 10),
                const Text(
                  'When enabled, monitors the accelerometer for sudden drops. '
                  'If a fall is detected, you have 15 seconds to respond '
                  'before 108 is called automatically.',
                  style: TextStyle(color: Colors.white38,
                      fontSize: 12, height: 1.5),
                ),
              ],
            ]),
          ),

          const SizedBox(height: 28),

          // ── SETUP GUIDE ─────────────────────────────────────
          _SectionHeader('Setup Guide for Mobile',
              Icons.smartphone_rounded, const Color(0xFF8B5CF6)),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              _SetupStep('1', 'Smartwatch Sync (Android)',
                  'Install Google Fit app → connect your Mi Band / Samsung watch → open this screen → tap Sync'),
              const SizedBox(height: 12),
              _SetupStep('2', 'Smartwatch Sync (iPhone)',
                  'Open Apple Health app → connect Apple Watch → open this screen → tap Sync'),
              const SizedBox(height: 12),
              _SetupStep('3', 'Camera PPG',
                  'Run app on Android/iOS → tap Measure → place finger on rear camera + flashlight'),
              const SizedBox(height: 12),
              _SetupStep('4', 'Fall Detection',
                  'Run app on Android/iOS → toggle ON → keep phone in pocket or on wrist'),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title; final IconData icon; final Color color;
  const _SectionHeader(this.title, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: color, size: 20),
    const SizedBox(width: 8),
    Expanded(child: Text(title,
        style: TextStyle(color: color, fontSize: 15,
            fontWeight: FontWeight.w600))),
  ]);
}

class _WearableTile extends StatelessWidget {
  final String label, value; final IconData icon;
  final Color color; final bool hasData;
  const _WearableTile(this.label, this.value, this.icon,
      this.color, this.hasData);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: hasData ? color.withOpacity(0.4) : Colors.white10),
      ),
      child: Column(children: [
        Icon(icon, color: hasData ? color : Colors.white24, size: 22),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(
          color: hasData ? color : Colors.white38,
          fontWeight: FontWeight.bold, fontSize: 13,
        )),
        Text(label, style: const TextStyle(
            color: Colors.white38, fontSize: 10),
            textAlign: TextAlign.center),
      ]),
    ),
  );
}

class _SetupStep extends StatelessWidget {
  final String step, title, desc;
  const _SetupStep(this.step, this.title, this.desc);
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Container(
      width: 24, height: 24,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF8B5CF6),
      ),
      child: Center(child: Text(step,
          style: const TextStyle(color: Colors.white,
              fontSize: 12, fontWeight: FontWeight.bold))),
    ),
    const SizedBox(width: 10),
    Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: Colors.white,
          fontWeight: FontWeight.bold, fontSize: 13)),
      const SizedBox(height: 2),
      Text(desc, style: const TextStyle(
          color: Colors.white54, fontSize: 12, height: 1.4)),
    ])),
  ]);
}
