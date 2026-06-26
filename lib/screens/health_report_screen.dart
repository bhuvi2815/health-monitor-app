// lib/screens/health_report_screen.dart
// Patient uploads text notes, images, or files as health reports
// System stores them and uses for hospital recommendations

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../services/health_alert_service.dart';

// ─── Report Model ─────────────────────────────────────────────────
class HealthReport {
  final String id;
  final DateTime date;
  final String type; // 'text', 'image', 'file', 'vitals'
  final String title;
  final String content;
  final String? imagePath;
  final String? fileName;
  DangerLevel? alertLevel;

  HealthReport({
    required this.id,
    required this.date,
    required this.type,
    required this.title,
    required this.content,
    this.imagePath,
    this.fileName,
    this.alertLevel,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'date': date.toIso8601String(), 'type': type,
    'title': title, 'content': content,
    'imagePath': imagePath, 'fileName': fileName,
    'alertLevel': alertLevel?.index,
  };

  factory HealthReport.fromJson(Map<String, dynamic> j) => HealthReport(
    id: j['id'], date: DateTime.parse(j['date']),
    type: j['type'], title: j['title'], content: j['content'],
    imagePath: j['imagePath'], fileName: j['fileName'],
    alertLevel: j['alertLevel'] != null ? DangerLevel.values[j['alertLevel']] : null,
  );
}

// ─── Screen ───────────────────────────────────────────────────────
class HealthReportScreen extends StatefulWidget {
  const HealthReportScreen({super.key});
  @override
  State<HealthReportScreen> createState() => _HealthReportScreenState();
}

class _HealthReportScreenState extends State<HealthReportScreen> {
  List<HealthReport> _reports = [];
  final _titleCtrl   = TextEditingController();
  final _contentCtrl = TextEditingController();
  bool _isLoading = false;

  // Vitals fields
  final _hrCtrl   = TextEditingController();
  final _sysCtrl  = TextEditingController();
  final _diaCtrl  = TextEditingController();
  final _bsCtrl   = TextEditingController();
  final _tempCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('health_reports');
    if (data != null) {
      final list = jsonDecode(data) as List;
      setState(() => _reports = list.map((e) => HealthReport.fromJson(e)).toList());
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('health_reports',
        jsonEncode(_reports.map((r) => r.toJson()).toList()));
  }

  // ── Save vitals report + compute alert ────────────────────────
  Future<void> _saveVitalsReport() async {
    final hr   = double.tryParse(_hrCtrl.text);
    final sys  = double.tryParse(_sysCtrl.text);
    final dia  = double.tryParse(_diaCtrl.text);
    final bs   = double.tryParse(_bsCtrl.text);
    final temp = double.tryParse(_tempCtrl.text);

    if (hr == null && sys == null && bs == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter at least one vital reading'), backgroundColor: Colors.orange));
      return;
    }

    final alert = HealthAlertService.analyseVitals(
      heartRate: hr, systolic: sys, diastolic: dia,
      bloodSugar: bs, temperature: temp,
    );

    // Save latest vitals for hospital screen
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('latest_vitals', jsonEncode({
      'heartRate': hr, 'systolic': sys, 'diastolic': dia,
      'bloodSugar': bs, 'temperature': temp,
    }));

    final report = HealthReport(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now(),
      type: 'vitals',
      title: 'Vitals Check — ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
      content: [
        if (hr != null) 'Heart Rate: ${hr.toInt()} BPM',
        if (sys != null && dia != null) 'BP: ${sys.toInt()}/${dia.toInt()} mmHg',
        if (bs != null) 'Blood Sugar: ${bs.toInt()} mg/dL',
        if (temp != null) 'Temperature: $temp°F',
      ].join(' | '),
      alertLevel: alert.level,
    );

    setState(() => _reports.insert(0, report));
    await _save();

    _hrCtrl.clear(); _sysCtrl.clear(); _diaCtrl.clear();
    _bsCtrl.clear(); _tempCtrl.clear();

    if (mounted) {
      Navigator.pop(context);
      _showAlertResult(alert);
    }
  }

  void _showAlertResult(HealthAlert alert) {
    final color = Color(HealthAlertService.alertColor(alert.level));
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(alert.title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(alert.message, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 8),
        Text(alert.tamilMessage, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        if (alert.symptoms.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...alert.symptoms.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              Icon(Icons.circle, color: color, size: 8),
              const SizedBox(width: 8),
              Expanded(child: Text(s, style: TextStyle(color: color.withOpacity(0.8), fontSize: 12))),
            ]),
          )),
        ],
        if (alert.requiresHospital) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Row(children: [
              Icon(Icons.local_hospital_rounded, color: Colors.white54, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text('Go to Hospital tab to find nearest hospital!',
                  style: TextStyle(color: Colors.white70, fontSize: 12))),
            ]),
          ),
        ],
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
          child: Text('OK', style: TextStyle(color: color, fontWeight: FontWeight.bold))),
      ],
    ));
  }

  // ── Add text note report ──────────────────────────────────────
  Future<void> _addTextReport() async {
    if (_titleCtrl.text.trim().isEmpty || _contentCtrl.text.trim().isEmpty) return;
    final report = HealthReport(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now(), type: 'text',
      title: _titleCtrl.text.trim(), content: _contentCtrl.text.trim(),
    );
    setState(() => _reports.insert(0, report));
    await _save();
    _titleCtrl.clear(); _contentCtrl.clear();
    if (mounted) Navigator.pop(context);
  }

  // ── Pick image ────────────────────────────────────────────────
  Future<void> _pickImage() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image upload works on Android/iOS. Use text note on web.'),
            backgroundColor: Colors.orange));
      return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final report = HealthReport(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now(), type: 'image',
      title: 'Medical Image — ${DateFormat('dd MMM').format(DateTime.now())}',
      content: 'Image report uploaded',
      imagePath: picked.path,
    );
    setState(() => _reports.insert(0, report));
    await _save();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Image report saved!'), backgroundColor: Color(0xFF10B981)));
  }

  // ── Pick file ─────────────────────────────────────────────────
  Future<void> _pickFile() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File upload works on Android/iOS. Use text note on web.'),
            backgroundColor: Colors.orange));
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'png', 'doc', 'docx']);
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final report = HealthReport(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now(), type: 'file',
      title: 'Medical Report — ${file.name}',
      content: 'File: ${file.name} (${(file.size / 1024).toStringAsFixed(1)} KB)',
      fileName: file.name,
    );
    setState(() => _reports.insert(0, report));
    await _save();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ File report saved!'), backgroundColor: Color(0xFF10B981)));
  }

  // ── Show add report bottom sheet ──────────────────────────────
  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Add Health Report',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 20),
          Row(children: [
            _AddOptionTile('📊 Vitals\nCheck', const Color(0xFFEF4444), () {
              Navigator.pop(context);
              _showVitalsDialog();
            }),
            const SizedBox(width: 10),
            _AddOptionTile('📝 Text\nNote', const Color(0xFF0EA5E9), () {
              Navigator.pop(context);
              _showTextDialog();
            }),
            const SizedBox(width: 10),
            _AddOptionTile('🖼️ Upload\nImage', const Color(0xFF10B981), () {
              Navigator.pop(context);
              _pickImage();
            }),
            const SizedBox(width: 10),
            _AddOptionTile('📄 Upload\nFile', const Color(0xFF8B5CF6), () {
              Navigator.pop(context);
              _pickFile();
            }),
          ]),
          const SizedBox(height: 10),
        ]),
      ),
    );
  }

  Widget _AddOptionTile(String label, Color color, VoidCallback onTap) =>
    Expanded(child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    ));

  void _showVitalsDialog() {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text('Enter Vitals', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _vitalField(_hrCtrl,   'Heart Rate (BPM)',        Icons.favorite),
        const SizedBox(height: 10),
        _vitalField(_sysCtrl,  'Systolic BP (mmHg)',      Icons.bloodtype),
        const SizedBox(height: 10),
        _vitalField(_diaCtrl,  'Diastolic BP (mmHg)',     Icons.bloodtype_outlined),
        const SizedBox(height: 10),
        _vitalField(_bsCtrl,   'Blood Sugar (mg/dL)',     Icons.water_drop),
        const SizedBox(height: 10),
        _vitalField(_tempCtrl, 'Temperature (°F)',        Icons.thermostat),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
          onPressed: _saveVitalsReport,
          child: const Text('Check & Save', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  Widget _vitalField(TextEditingController ctrl, String label, IconData icon) =>
    TextField(controller: ctrl, keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label, labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFFEF4444), size: 18),
        border: const OutlineInputBorder(),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );

  void _showTextDialog() {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text('Add Text Note', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _titleCtrl, style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Title', labelStyle: TextStyle(color: Colors.white54),
            border: OutlineInputBorder(),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
          )),
        const SizedBox(height: 10),
        TextField(controller: _contentCtrl, maxLines: 4, style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Describe your symptoms or condition',
            labelStyle: TextStyle(color: Colors.white54),
            border: OutlineInputBorder(),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
          )),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9)),
          onPressed: _addTextReport,
          child: const Text('Save', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  Color _reportColor(HealthReport r) {
    if (r.alertLevel != null) return Color(HealthAlertService.alertColor(r.alertLevel!));
    switch (r.type) {
      case 'image': return const Color(0xFF10B981);
      case 'file':  return const Color(0xFF8B5CF6);
      default:      return const Color(0xFF0EA5E9);
    }
  }

  IconData _reportIcon(HealthReport r) {
    switch (r.type) {
      case 'vitals': return Icons.monitor_heart_rounded;
      case 'image':  return Icons.image_rounded;
      case 'file':   return Icons.description_rounded;
      default:       return Icons.note_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📋 Health Reports', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddOptions,
        icon: const Icon(Icons.add),
        label: const Text('Add Report'),
        backgroundColor: const Color(0xFFEF4444),
      ),
      body: _reports.isEmpty
          ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.folder_open_rounded, size: 80, color: Colors.white24),
              SizedBox(height: 16),
              Text('No health reports yet', style: TextStyle(color: Colors.white38, fontSize: 16)),
              SizedBox(height: 8),
              Text('Tap + to add vitals, text notes, images or files',
                  style: TextStyle(color: Colors.white24, fontSize: 13), textAlign: TextAlign.center),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: _reports.length,
              itemBuilder: (ctx, i) {
                final r = _reports[i];
                final color = _reportColor(r);
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                      child: Icon(_reportIcon(r), color: color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Expanded(child: Text(r.title,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
                        if (r.alertLevel != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                            child: Text(
                              r.alertLevel == DangerLevel.critical ? 'CRITICAL'
                                : r.alertLevel == DangerLevel.danger ? 'DANGER'
                                : r.alertLevel == DangerLevel.warning ? 'WARNING' : 'SAFE',
                              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ]),
                      const SizedBox(height: 4),
                      Text(r.content, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(DateFormat('dd MMM yyyy • hh:mm a').format(r.date),
                          style: const TextStyle(color: Colors.white24, fontSize: 11)),
                    ])),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                      onPressed: () async {
                        setState(() => _reports.removeAt(i));
                        await _save();
                      },
                    ),
                  ]),
                );
              },
            ),
    );
  }
}
