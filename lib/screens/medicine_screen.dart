// lib/screens/medicine_screen.dart
// ✅ Voice alarm in English + Tamil when medicine time hits
// ✅ Auto health log when user marks medicine as "Taken"
// ✅ No manual BP/sugar input — auto logged from medicine tracking

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../services/alarm_service.dart';
import '../services/voice_alarm_service.dart';

// ─── Medicine Model ───────────────────────────────────────────────
class Medicine {
  final int id;
  final String name;
  final String dosage;
  final int hour;
  final int minute;
  bool isTaken;
  DateTime? takenAt;

  Medicine({
    required this.id,
    required this.name,
    required this.dosage,
    required this.hour,
    required this.minute,
    this.isTaken = false,
    this.takenAt,
  });

  String get timeString {
    final displayH = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final m = minute.toString().padLeft(2, '0');
    final period = hour < 12 ? 'AM' : 'PM';
    return '$displayH:$m $period';
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'dosage': dosage,
    'hour': hour, 'minute': minute,
    'isTaken': isTaken,
    'takenAt': takenAt?.toIso8601String(),
  };

  factory Medicine.fromJson(Map<String, dynamic> j) => Medicine(
    id: j['id'], name: j['name'], dosage: j['dosage'],
    hour: j['hour'], minute: j['minute'],
    isTaken: j['isTaken'] ?? false,
    takenAt: j['takenAt'] != null ? DateTime.parse(j['takenAt']) : null,
  );
}

// ─── Health Log Entry (auto-created when medicine taken) ─────────
class HealthLogEntry {
  final DateTime time;
  final String medicineName;
  final String note;

  HealthLogEntry({required this.time, required this.medicineName, required this.note});

  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    'medicineName': medicineName,
    'note': note,
  };

  factory HealthLogEntry.fromJson(Map<String, dynamic> j) => HealthLogEntry(
    time: DateTime.parse(j['time']),
    medicineName: j['medicineName'],
    note: j['note'],
  );
}

// ─── Medicine Screen ──────────────────────────────────────────────
class MedicineScreen extends StatefulWidget {
  const MedicineScreen({super.key});
  @override
  State<MedicineScreen> createState() => _MedicineScreenState();
}

class _MedicineScreenState extends State<MedicineScreen> {
  List<Medicine> _medicines = [];
  List<HealthLogEntry> _healthLog = [];
  Timer? _alarmCheckTimer;
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _load();
    // Check every 30 seconds if any alarm should fire
    _alarmCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkAlarms());
  }

  @override
  void dispose() {
    _alarmCheckTimer?.cancel();
    VoiceAlarmService.stop();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    // Load medicines
    final medData = prefs.getString('medicines');
    if (medData != null) {
      final list = jsonDecode(medData) as List;
      setState(() => _medicines = list.map((e) => Medicine.fromJson(e)).toList());
    }

    // Load health log
    final logData = prefs.getString('health_log');
    if (logData != null) {
      final list = jsonDecode(logData) as List;
      setState(() => _healthLog = list.map((e) => HealthLogEntry.fromJson(e)).toList());
    }
  }

  Future<void> _saveMedicines() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('medicines', jsonEncode(_medicines.map((m) => m.toJson()).toList()));
  }

  Future<void> _saveHealthLog() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('health_log', jsonEncode(_healthLog.map((e) => e.toJson()).toList()));
  }

  // ── Check if any alarm should fire right now ──────────────────
  void _checkAlarms() {
    final now = TimeOfDay.now();
    for (final medicine in _medicines) {
      if (!medicine.isTaken &&
          medicine.hour == now.hour &&
          medicine.minute == now.minute) {
        _triggerAlarm(medicine);
      }
    }
  }

  // ── Fire alarm + voice reminder ───────────────────────────────
  Future<void> _triggerAlarm(Medicine medicine) async {
    if (_isSpeaking) return;
    setState(() => _isSpeaking = true);

    // Show alarm dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _AlarmDialog(
          medicine: medicine,
          onTaken: () {
            Navigator.pop(context);
            _markTaken(medicine);
          },
          onSnooze: () {
            Navigator.pop(context);
            VoiceAlarmService.stop();
            setState(() => _isSpeaking = false);
          },
        ),
      );
    }

    // Speak in English + Tamil
    await VoiceAlarmService.speakMedicineReminder(medicine.name);
    setState(() => _isSpeaking = false);
  }

  // ── Mark medicine as taken + auto-log health entry ────────────
  Future<void> _markTaken(Medicine medicine) async {
    setState(() {
      medicine.isTaken = true;
      medicine.takenAt = DateTime.now();
    });
    await _saveMedicines();

    // 🔑 Auto health log — no manual input needed!
    final entry = HealthLogEntry(
      time: DateTime.now(),
      medicineName: medicine.name,
      note: 'Medicine taken on time ✅',
    );
    setState(() => _healthLog.insert(0, entry));
    await _saveHealthLog();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${medicine.name} marked as taken — health log updated!'),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    // Speak confirmation
    await VoiceAlarmService.speakHealthTip(
      'Great job! You have taken ${medicine.name}. Keep it up!'
    );
  }

  // ── Manually test alarm voice (for demo) ──────────────────────
  Future<void> _testVoice(Medicine medicine) async {
    setState(() => _isSpeaking = true);
    await VoiceAlarmService.speakMedicineReminder(medicine.name);
    setState(() => _isSpeaking = false);
  }

  void _addMedicine() {
    showDialog(context: context, builder: (_) => _AddMedicineDialog(
      onAdd: (medicine) async {
        setState(() => _medicines.add(medicine));
        await _saveMedicines();
        await AlarmService.scheduleMedicineAlarm(
          id: medicine.id, medicineName: medicine.name,
          hour: medicine.hour, minute: medicine.minute,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('✅ Alarm set for ${medicine.name} at ${medicine.timeString}'),
            backgroundColor: const Color(0xFF10B981),
          ));
        }
      },
    ));
  }

  void _deleteMedicine(Medicine m) async {
    await AlarmService.cancelAlarm(m.id);
    setState(() => _medicines.remove(m));
    await _saveMedicines();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('💊 Medicine & Health', style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            tabs: [Tab(text: '💊 Alarms'), Tab(text: '📋 Health Log')],
            labelColor: Color(0xFF0EA5E9),
            unselectedLabelColor: Colors.white38,
            indicatorColor: Color(0xFF0EA5E9),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addMedicine,
          icon: const Icon(Icons.add),
          label: const Text('Add Medicine'),
          backgroundColor: const Color(0xFF0EA5E9),
        ),
        body: TabBarView(children: [
          _medicineTab(),
          _healthLogTab(),
        ]),
      ),
    );
  }

  // ── Medicine Alarms Tab ───────────────────────────────────────
  Widget _medicineTab() {
    if (_medicines.isEmpty) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.medication_outlined, size: 80, color: Colors.white24),
          SizedBox(height: 16),
          Text('No medicines added yet', style: TextStyle(color: Colors.white38, fontSize: 16)),
          Text('Tap + to add your first medicine', style: TextStyle(color: Colors.white24, fontSize: 13)),
        ],
      ));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: _medicines.length,
      itemBuilder: (ctx, i) => _MedicineCard(
        medicine: _medicines[i],
        onTaken: () => _markTaken(_medicines[i]),
        onDelete: () => _deleteMedicine(_medicines[i]),
        onTestVoice: () => _testVoice(_medicines[i]),
        isSpeaking: _isSpeaking,
      ),
    );
  }

  // ── Auto Health Log Tab ───────────────────────────────────────
  Widget _healthLogTab() {
    if (_healthLog.isEmpty) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.health_and_safety_outlined, size: 80, color: Colors.white24),
          SizedBox(height: 16),
          Text('No health events yet', style: TextStyle(color: Colors.white38, fontSize: 16)),
          Text('Health log auto-updates when you take medicine',
              style: TextStyle(color: Colors.white24, fontSize: 13), textAlign: TextAlign.center),
        ],
      ));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _healthLog.length,
      itemBuilder: (ctx, i) {
        final entry = _healthLog[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.medication_rounded, color: Color(0xFF10B981), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(entry.medicineName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              Text(entry.note, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ])),
            Text(
              DateFormat('hh:mm a\ndd MMM').format(entry.time),
              style: const TextStyle(color: Colors.white38, fontSize: 11),
              textAlign: TextAlign.right,
            ),
          ]),
        );
      },
    );
  }
}

// ─── Medicine Card ────────────────────────────────────────────────
class _MedicineCard extends StatelessWidget {
  final Medicine medicine;
  final VoidCallback onTaken, onDelete, onTestVoice;
  final bool isSpeaking;

  const _MedicineCard({
    required this.medicine, required this.onTaken,
    required this.onDelete, required this.onTestVoice,
    required this.isSpeaking,
  });

  @override
  Widget build(BuildContext context) {
    final color = medicine.isTaken ? const Color(0xFF10B981) : const Color(0xFF0EA5E9);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: Icon(
              medicine.isTaken ? Icons.check_circle_rounded : Icons.medication_rounded,
              color: color, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(medicine.name, style: TextStyle(
              color: medicine.isTaken ? Colors.white38 : Colors.white,
              fontWeight: FontWeight.bold, fontSize: 16,
              decoration: medicine.isTaken ? TextDecoration.lineThrough : null,
            )),
            Text(medicine.dosage, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.alarm, size: 14, color: Color(0xFF0EA5E9)),
              const SizedBox(width: 4),
              Text(medicine.timeString,
                  style: const TextStyle(color: Color(0xFF0EA5E9), fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ])),
          // Delete
          GestureDetector(
            onTap: onDelete,
            child: const Icon(Icons.delete_outline, color: Colors.red, size: 22)),
        ]),

        const SizedBox(height: 12),
        const Divider(color: Colors.white10, height: 1),
        const SizedBox(height: 12),

        // Action Buttons Row
        Row(children: [
          // Test Voice Button
          Expanded(
            child: OutlinedButton.icon(
              onPressed: isSpeaking ? null : onTestVoice,
              icon: Icon(
                isSpeaking ? Icons.volume_up : Icons.record_voice_over,
                size: 16,
                color: const Color(0xFF8B5CF6),
              ),
              label: Text(
                isSpeaking ? 'Speaking...' : '🔊 Test Voice',
                style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF8B5CF6)),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Mark Taken Button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: medicine.isTaken ? null : onTaken,
              icon: Icon(
                medicine.isTaken ? Icons.check_circle : Icons.medication_liquid,
                size: 16, color: Colors.white,
              ),
              label: Text(
                medicine.isTaken ? 'Taken ✅' : 'Mark Taken',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: medicine.isTaken ? Colors.white12 : const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ─── Alarm Popup Dialog ───────────────────────────────────────────
class _AlarmDialog extends StatefulWidget {
  final Medicine medicine;
  final VoidCallback onTaken, onSnooze;
  const _AlarmDialog({required this.medicine, required this.onTaken, required this.onSnooze});

  @override
  State<_AlarmDialog> createState() => _AlarmDialogState();
}

class _AlarmDialogState extends State<_AlarmDialog> with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() { _pulseCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        // Pulsing alarm icon
        AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, __) => Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0EA5E9).withOpacity(0.1 + _pulseCtrl.value * 0.2),
              boxShadow: [BoxShadow(
                color: const Color(0xFF0EA5E9).withOpacity(_pulseCtrl.value * 0.5),
                blurRadius: 30, spreadRadius: 5,
              )],
            ),
            child: const Icon(Icons.alarm_rounded, color: Color(0xFF0EA5E9), size: 52),
          ),
        ),
        const SizedBox(height: 20),
        const Text('💊 Medicine Time!',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(widget.medicine.name,
            style: const TextStyle(color: Color(0xFF0EA5E9), fontSize: 18, fontWeight: FontWeight.w600)),
        Text(widget.medicine.dosage,
            style: const TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 8),

        // Tamil + English reminder text
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            const Text('🔊 Take your medicine now!',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 4),
            const Text('🔊 உங்கள் மருந்தை இப்போதே எடுத்துக்கொள்ளுங்கள்!',
                style: TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center),
          ]),
        ),
        const SizedBox(height: 20),

        // Buttons
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: widget.onSnooze,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Snooze 10m', style: TextStyle(color: Colors.white54)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              onPressed: widget.onTaken,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Taken ✅', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ─── Add Medicine Dialog ──────────────────────────────────────────
class _AddMedicineDialog extends StatefulWidget {
  final Function(Medicine) onAdd;
  const _AddMedicineDialog({required this.onAdd});
  @override
  State<_AddMedicineDialog> createState() => _AddMedicineDialogState();
}

class _AddMedicineDialogState extends State<_AddMedicineDialog> {
  final _nameCtrl   = TextEditingController();
  final _dosageCtrl = TextEditingController();
  TimeOfDay _time   = TimeOfDay.now();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text('Add Medicine', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _inputField(_nameCtrl, 'Medicine Name', Icons.medication),
        const SizedBox(height: 12),
        _inputField(_dosageCtrl, 'Dosage (e.g. 500mg)', Icons.scale),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () async {
            final picked = await showTimePicker(context: context, initialTime: _time);
            if (picked != null) setState(() => _time = picked);
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Icon(Icons.alarm, color: Color(0xFF0EA5E9)),
              const SizedBox(width: 12),
              Text('Alarm Time: ${_time.format(context)}',
                  style: const TextStyle(color: Colors.white, fontSize: 15)),
            ]),
          ),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9)),
          onPressed: () {
            if (_nameCtrl.text.trim().isEmpty) return;
            widget.onAdd(Medicine(
              id: DateTime.now().millisecondsSinceEpoch % 100000,
              name: _nameCtrl.text.trim(),
              dosage: _dosageCtrl.text.trim().isEmpty ? 'As prescribed' : _dosageCtrl.text.trim(),
              hour: _time.hour, minute: _time.minute,
            ));
            Navigator.pop(context);
          },
          child: const Text('Set Alarm', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _inputField(TextEditingController ctrl, String label, IconData icon) =>
    TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: const Color(0xFF0EA5E9)),
        border: const OutlineInputBorder(),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
      ),
    );
}
