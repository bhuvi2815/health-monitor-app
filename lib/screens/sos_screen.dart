// lib/screens/sos_screen.dart
// One-tap SOS — calls 108 + sends GPS location SMS to 3 family contacts

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmergencyContact {
  final String name, phone;
  EmergencyContact({required this.name, required this.phone});
  Map<String, dynamic> toJson() => {'name': name, 'phone': phone};
  factory EmergencyContact.fromJson(Map<String, dynamic> j) =>
      EmergencyContact(name: j['name'], phone: j['phone']);
}

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});
  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen>
    with SingleTickerProviderStateMixin {
  List<EmergencyContact> _contacts = [];
  bool _sending = false;
  String _status = '';
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _load();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
  }

  @override
  void dispose() { _pulseCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('emergency_contacts');
    if (data != null) {
      final list = jsonDecode(data) as List;
      setState(() => _contacts =
          list.map((e) => EmergencyContact.fromJson(e)).toList());
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('emergency_contacts',
        jsonEncode(_contacts.map((c) => c.toJson()).toList()));
  }

  // ── Main SOS action ───────────────────────────────────────────
  Future<void> _triggerSOS() async {
    setState(() { _sending = true; _status = 'Getting your location...'; });

    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
    } catch (_) {}

    final locationText = pos != null
        ? 'https://maps.google.com/?q=${pos.latitude},${pos.longitude}'
        : 'Location unavailable';

    final message =
        'EMERGENCY ALERT! I need help immediately. My location: $locationText';

    // Step 1: Call 108
    setState(() => _status = 'Calling 108 ambulance...');
    await _call('108');
    await Future.delayed(const Duration(seconds: 1));

    // Step 2: SMS all contacts
    for (final contact in _contacts) {
      setState(() => _status = 'Sending SMS to ${contact.name}...');
      await _sendSms(contact.phone, message);
      await Future.delayed(const Duration(milliseconds: 500));
    }

    setState(() {
      _sending = false;
      _status = _contacts.isEmpty
          ? 'Called 108. Add family contacts for SMS alerts!'
          : 'Done! Called 108 + SMS sent to ${_contacts.length} contact(s).';
    });
  }

  Future<void> _call(String number) async {
    final url = Uri.parse('tel:$number');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  Future<void> _sendSms(String phone, String message) async {
    final url = Uri.parse(
        'sms:$phone?body=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  void _addContact() {
    if (_contacts.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 3 emergency contacts allowed'),
            backgroundColor: Colors.orange));
      return;
    }
    final nameCtrl  = TextEditingController();
    final phoneCtrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text('Add Emergency Contact',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _field(nameCtrl,  'Full Name', Icons.person_rounded,
            TextInputType.name),
        const SizedBox(height: 12),
        _field(phoneCtrl, 'Phone (with +91)', Icons.phone_rounded,
            TextInputType.phone),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444)),
          onPressed: () async {
            if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) return;
            setState(() => _contacts.add(EmergencyContact(
                name: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim())));
            await _save();
            if (mounted) Navigator.pop(context);
          },
          child: const Text('Add', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  Widget _field(TextEditingController c, String label,
      IconData icon, TextInputType type) =>
      TextField(
        controller: c, keyboardType: type,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          prefixIcon: Icon(icon, color: const Color(0xFFEF4444), size: 20),
          border: const OutlineInputBorder(),
          enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white24)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS Emergency',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Instructions
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFFEF4444).withOpacity(0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline_rounded,
                  color: Color(0xFFEF4444), size: 20),
              SizedBox(width: 10),
              Expanded(child: Text(
                'Tap the SOS button to call 108 and send your GPS location to all emergency contacts instantly.',
                style: TextStyle(color: Color(0xFFEF4444), fontSize: 13),
              )),
            ]),
          ),

          const SizedBox(height: 32),

          // Big SOS Button
          Center(
            child: GestureDetector(
              onTap: _sending ? null : _triggerSOS,
              child: AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, __) => Container(
                  width: 180, height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFEF4444),
                    boxShadow: [BoxShadow(
                      color: const Color(0xFFEF4444)
                          .withOpacity(_pulseCtrl.value * 0.5),
                      blurRadius: 40, spreadRadius: 15,
                    )],
                  ),
                  child: _sending
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Colors.white,
                                strokeWidth: 3),
                            SizedBox(height: 10),
                            Text('Sending...', style: TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold)),
                          ])
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.sos_rounded, color: Colors.white, size: 56),
                            Text('EMERGENCY', style: TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold,
                                fontSize: 13)),
                          ]),
                ),
              ),
            ),
          ),

          if (_status.isNotEmpty) ...[
            const SizedBox(height: 16),
            Center(child: Text(_status,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center)),
          ],

          const SizedBox(height: 32),

          // Emergency numbers
          const Text('Emergency Numbers',
              style: TextStyle(color: Colors.white70, fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ...[
            ['108', 'Ambulance', Icons.local_hospital_rounded],
            ['102', 'Medical Emergency', Icons.emergency_rounded],
            ['112', 'National Emergency', Icons.sos_rounded],
          ].map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () => _call(e[0] as String),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFEF4444).withOpacity(0.3)),
                ),
                child: Row(children: [
                  Icon(e[2] as IconData,
                      color: const Color(0xFFEF4444), size: 22),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Text(e[1] as String, style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                    Text('Tap to call ${e[0]}',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12)),
                  ])),
                  const Icon(Icons.call_rounded,
                      color: Color(0xFF10B981), size: 22),
                ]),
              ),
            ),
          )),

          const SizedBox(height: 24),

          // Emergency contacts
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Family Contacts (${0})',
                style: TextStyle(color: Colors.white70, fontSize: 16,
                    fontWeight: FontWeight.w600)),
            GestureDetector(
              onTap: _addContact,
              child: const Row(children: [
                Icon(Icons.add_circle_rounded,
                    color: Color(0xFF0EA5E9), size: 20),
                SizedBox(width: 4),
                Text('Add', style: TextStyle(
                    color: Color(0xFF0EA5E9), fontWeight: FontWeight.w500)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),

          if (_contacts.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white10),
              ),
              child: const Center(child: Column(children: [
                Icon(Icons.group_add_rounded,
                    size: 44, color: Colors.white24),
                SizedBox(height: 8),
                Text('No contacts added yet',
                    style: TextStyle(color: Colors.white38)),
                Text('Add up to 3 family members',
                    style: TextStyle(color: Colors.white24, fontSize: 12)),
              ])),
            )
          else
            ..._contacts.asMap().entries.map((entry) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF0EA5E9).withOpacity(0.3)),
              ),
              child: Row(children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF0EA5E9).withOpacity(0.15),
                  child: Text(
                    entry.value.name[0].toUpperCase(),
                    style: const TextStyle(
                        color: Color(0xFF0EA5E9), fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Text(entry.value.name, style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
                  Text(entry.value.phone,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12)),
                ])),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () async {
                    setState(() => _contacts.removeAt(entry.key));
                    await _save();
                  },
                ),
              ]),
            )),
        ]),
      ),
    );
  }
}
