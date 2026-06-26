// lib/screens/hospital_screen.dart
// Finds nearby hospitals using device GPS + opens Google Maps
// Shows critical alert if health is in danger

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/health_alert_service.dart';
import '../services/voice_alarm_service.dart';

class HospitalScreen extends StatefulWidget {
  const HospitalScreen({super.key});
  @override
  State<HospitalScreen> createState() => _HospitalScreenState();
}

class _HospitalScreenState extends State<HospitalScreen> {
  Position? _position;
  bool _loadingLocation = false;
  String _locationError = '';
  HealthAlert? _alert;

  // Hardcoded nearby hospital types for demo (real app uses Places API)
  final List<Map<String, String>> _hospitalTypes = [
    {'name': 'General Hospitals',    'query': 'hospital',          'icon': '🏥'},
    {'name': 'Emergency Services',   'query': 'emergency hospital', 'icon': '🚨'},
    {'name': 'Cardiac Care',         'query': 'cardiac hospital',   'icon': '❤️'},
    {'name': 'Diabetic Clinic',      'query': 'diabetes clinic',    'icon': '💉'},
    {'name': 'Blood Pressure Clinic','query': 'hypertension clinic','icon': '🩺'},
    {'name': 'Government Hospital',  'query': 'government hospital','icon': '🏛️'},
  ];

  @override
  void initState() {
    super.initState();
    _loadAlertFromData();
  }

  // ── Load saved health data and compute alert ───────────────────
  Future<void> _loadAlertFromData() async {
    final prefs = await SharedPreferences.getInstance();
    final vitalsStr = prefs.getString('latest_vitals');
    final logStr = prefs.getString('health_log');

    int missedCount = 0;
    if (logStr != null) {
      final log = jsonDecode(logStr) as List;
      // Count medicines NOT taken today
      final todayLogs = log.where((e) {
        final t = DateTime.parse(e['time']);
        final now = DateTime.now();
        return t.year == now.year && t.month == now.month && t.day == now.day;
      }).length;
      // If fewer than expected (assume 3 medicines), count missed
      missedCount = (3 - todayLogs).clamp(0, 10);
    }

    if (vitalsStr != null) {
      final v = jsonDecode(vitalsStr);
      final alert = HealthAlertService.analyseVitals(
        heartRate:   (v['heartRate']  as num?)?.toDouble(),
        systolic:    (v['systolic']   as num?)?.toDouble(),
        diastolic:   (v['diastolic']  as num?)?.toDouble(),
        bloodSugar:  (v['bloodSugar'] as num?)?.toDouble(),
        temperature: (v['temperature']as num?)?.toDouble(),
        missedMedicines: missedCount,
      );
      setState(() => _alert = alert);

      // Auto-speak if critical
      if (alert.level == DangerLevel.critical || alert.level == DangerLevel.danger) {
        await VoiceAlarmService.speakHealthTip(
          '${alert.title}. ${alert.message} '
          'Please find the nearest hospital immediately.'
        );
      }
    }
  }

  // ── Get GPS location ───────────────────────────────────────────
  Future<void> _getLocation() async {
    setState(() { _loadingLocation = true; _locationError = ''; });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() { _locationError = 'Location permission denied.'; _loadingLocation = false; });
          return;
        }
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
      setState(() { _position = pos; _loadingLocation = false; });
    } catch (e) {
      setState(() {
        _locationError = 'Could not get location. Please enable GPS.';
        _loadingLocation = false;
      });
    }
  }

  // ── Open Google Maps with hospital search ──────────────────────
  Future<void> _openGoogleMaps({String query = 'hospital'}) async {
    Uri url;
    if (_position != null) {
      // Search near current location
      url = Uri.parse(
        'https://www.google.com/maps/search/$query/@${_position!.latitude},${_position!.longitude},14z'
      );
    } else {
      // Fallback: search by current location (Google detects it)
      url = Uri.parse(
        'https://www.google.com/maps/search/$query+near+me'
      );
    }

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps'), backgroundColor: Colors.red),
      );
    }
  }

  // ── Call emergency ─────────────────────────────────────────────
  Future<void> _callEmergency() async {
    final url = Uri.parse('tel:108'); // India emergency
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final alertColor = _alert != null
        ? Color(HealthAlertService.alertColor(_alert!.level))
        : const Color(0xFF10B981);

    return Scaffold(
      appBar: AppBar(
        title: const Text('🏥 Nearby Hospitals', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          // Emergency call button
          IconButton(
            icon: const Icon(Icons.emergency_rounded, color: Color(0xFFEF4444)),
            onPressed: _callEmergency,
            tooltip: 'Call 108',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Health Alert Banner ──────────────────────────────
          if (_alert != null) ...[
            _AlertBanner(alert: _alert!, alertColor: alertColor),
            const SizedBox(height: 16),
          ],

          // ── Location Card ────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.location_on_rounded, color: Color(0xFF0EA5E9), size: 20),
                SizedBox(width: 8),
                Text('Your Location', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ]),
              const SizedBox(height: 12),
              if (_position != null) ...[
                Text(
                  '📍 Lat: ${_position!.latitude.toStringAsFixed(4)}, '
                  'Lng: ${_position!.longitude.toStringAsFixed(4)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 4),
                const Text('GPS location acquired ✅',
                    style: TextStyle(color: Color(0xFF10B981), fontSize: 12)),
              ] else ...[
                Text(
                  _locationError.isEmpty
                      ? 'Tap below to get your current location'
                      : _locationError,
                  style: TextStyle(
                    color: _locationError.isEmpty ? Colors.white38 : const Color(0xFFEF4444),
                    fontSize: 13),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loadingLocation ? null : _getLocation,
                  icon: _loadingLocation
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.gps_fixed_rounded, color: Colors.white, size: 18),
                  label: Text(
                    _loadingLocation ? 'Getting location...' : 'Get My Location',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0EA5E9),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // ── Open Full Map Button ─────────────────────────────
          GestureDetector(
            onTap: () => _openGoogleMaps(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1D4ED8), Color(0xFF0EA5E9)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_rounded, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Open Hospital Map',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('Shows all hospitals near you in Google Maps',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ]),
                  Spacer(),
                  Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Hospital Type Filters ────────────────────────────
          const Text('🔍 Search by Type',
              style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.2,
            ),
            itemCount: _hospitalTypes.length,
            itemBuilder: (ctx, i) {
              final type = _hospitalTypes[i];
              return GestureDetector(
                onTap: () => _openGoogleMaps(query: type['query']!),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(children: [
                    Text(type['icon']!, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(type['name']!,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                    ),
                  ]),
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // ── Emergency Numbers ────────────────────────────────
          const Text('📞 Emergency Numbers',
              style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _EmergencyTile(number: '108', label: 'Ambulance (India)', icon: Icons.local_hospital_rounded, color: const Color(0xFFEF4444)),
          const SizedBox(height: 8),
          _EmergencyTile(number: '102', label: 'Medical Emergency', icon: Icons.emergency_rounded, color: const Color(0xFFF97316)),
          const SizedBox(height: 8),
          _EmergencyTile(number: '112', label: 'National Emergency', icon: Icons.sos_rounded, color: const Color(0xFF8B5CF6)),
        ]),
      ),
    );
  }
}

// ─── Alert Banner ─────────────────────────────────────────────────
class _AlertBanner extends StatelessWidget {
  final HealthAlert alert;
  final Color alertColor;
  const _AlertBanner({required this.alert, required this.alertColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: alertColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: alertColor.withOpacity(0.5), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(alert.title,
            style: TextStyle(color: alertColor, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 6),
        Text(alert.message, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 4),
        Text(alert.tamilMessage,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        if (alert.symptoms.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...alert.symptoms.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              Icon(Icons.warning_amber_rounded, color: alertColor, size: 14),
              const SizedBox(width: 6),
              Expanded(child: Text(s,
                  style: TextStyle(color: alertColor.withOpacity(0.8), fontSize: 12))),
            ]),
          )),
        ],
        if (alert.requiresHospital) ...[
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.location_searching_rounded, color: Colors.white54, size: 14),
            const SizedBox(width: 6),
            const Text('Scroll down to find nearby hospitals →',
                style: TextStyle(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic)),
          ]),
        ],
      ]),
    );
  }
}

// ─── Emergency Call Tile ──────────────────────────────────────────
class _EmergencyTile extends StatelessWidget {
  final String number, label;
  final IconData icon;
  final Color color;
  const _EmergencyTile({required this.number, required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () async {
      final url = Uri.parse('tel:$number');
      if (await canLaunchUrl(url)) await launchUrl(url);
    },
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          Text('Tap to call $number', style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ])),
        Icon(Icons.call_rounded, color: color, size: 22),
      ]),
    ),
  );
}
