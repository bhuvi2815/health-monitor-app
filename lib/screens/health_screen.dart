// lib/screens/health_screen.dart
// ✅ Health data is AUTOMATIC — populated from medicine intake log
// ✅ No manual input needed from user
// ✅ Shows medicine adherence timeline + streak

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

// ─── Health Log Entry (same model as medicine_screen) ─────────────
class HealthLogEntry {
  final DateTime time;
  final String medicineName;
  final String note;

  HealthLogEntry({required this.time, required this.medicineName, required this.note});

  factory HealthLogEntry.fromJson(Map<String, dynamic> j) => HealthLogEntry(
    time: DateTime.parse(j['time']),
    medicineName: j['medicineName'],
    note: j['note'],
  );
}

// ─── Screen ───────────────────────────────────────────────────────
class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});
  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  List<HealthLogEntry> _log = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('health_log');
    if (data != null) {
      final list = jsonDecode(data) as List;
      setState(() => _log = list.map((e) => HealthLogEntry.fromJson(e)).toList());
    }
  }

  // Calculate adherence % for last 7 days
  int get _adherencePercent {
    if (_log.isEmpty) return 0;
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final recent = _log.where((e) => e.time.isAfter(cutoff)).length;
    return ((recent / 7) * 100).clamp(0, 100).toInt();
  }

  // Medicine streak count
  int get _streak {
    if (_log.isEmpty) return 0;
    int streak = 0;
    DateTime checkDay = DateTime.now();
    for (int i = 0; i < 30; i++) {
      final day = DateTime(checkDay.year, checkDay.month, checkDay.day - i);
      final takenOnDay = _log.any((e) =>
        e.time.year == day.year && e.time.month == day.month && e.time.day == day.day);
      if (takenOnDay) { streak++; } else { break; }
    }
    return streak;
  }

  // Last 7 days activity data for bar chart
  List<int> get _weeklyActivity {
    return List.generate(7, (i) {
      final day = DateTime.now().subtract(Duration(days: 6 - i));
      return _log.where((e) =>
        e.time.year == day.year &&
        e.time.month == day.month &&
        e.time.day == day.day).length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final weekly = _weeklyActivity;

    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Health Monitor', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load, tooltip: 'Refresh'),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Auto-update banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0EA5E9).withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF0EA5E9).withOpacity(0.3)),
              ),
              child: const Row(children: [
                Icon(Icons.auto_awesome, color: Color(0xFF0EA5E9), size: 20),
                SizedBox(width: 10),
                Expanded(child: Text(
                  'Health log updates automatically when you take your medicine!',
                  style: TextStyle(color: Color(0xFF0EA5E9), fontSize: 13),
                )),
              ]),
            ),
            const SizedBox(height: 20),

            // Stats Row
            Row(children: [
              _StatBox(
                icon: Icons.local_fire_department_rounded,
                label: 'Day Streak',
                value: '$_streak days',
                color: const Color(0xFFF59E0B),
              ),
              const SizedBox(width: 12),
              _StatBox(
                icon: Icons.percent_rounded,
                label: 'Adherence',
                value: '$_adherencePercent%',
                color: const Color(0xFF10B981),
              ),
              const SizedBox(width: 12),
              _StatBox(
                icon: Icons.medication_rounded,
                label: 'Total Taken',
                value: '${_log.length}',
                color: const Color(0xFF8B5CF6),
              ),
            ]),
            const SizedBox(height: 24),

            // Weekly Bar Chart
            const Text('📈 Weekly Medicine Adherence',
                style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Container(
              height: 180,
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)),
              child: weekly.every((v) => v == 0)
                ? const Center(child: Text('Take medicines to see chart here',
                    style: TextStyle(color: Colors.white24)))
                : BarChart(BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: (weekly.reduce((a, b) => a > b ? a : b) + 1).toDouble(),
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
                          final idx = v.toInt();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(idx < days.length ? days[idx] : '',
                                style: const TextStyle(color: Colors.white38, fontSize: 10)),
                          );
                        },
                      )),
                      leftTitles: AxisTitles(sideTitles: SideTitles(
                        showTitles: true, reservedSize: 24,
                        getTitlesWidget: (v, _) => Text('${v.toInt()}',
                            style: const TextStyle(color: Colors.white38, fontSize: 10)),
                      )),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      getDrawingHorizontalLine: (_) => const FlLine(color: Colors.white10, strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: weekly.asMap().entries.map((e) => BarChartGroupData(
                      x: e.key,
                      barRods: [BarChartRodData(
                        toY: e.value.toDouble(),
                        color: e.value > 0 ? const Color(0xFF10B981) : const Color(0xFF1E293B),
                        width: 18,
                        borderRadius: BorderRadius.circular(6),
                      )],
                    )).toList(),
                  )),
            ),
            const SizedBox(height: 24),

            // Timeline
            const Text('🕒 Medicine Timeline',
                style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),

            if (_log.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)),
                child: const Center(child: Column(children: [
                  Icon(Icons.timeline_outlined, color: Colors.white24, size: 48),
                  SizedBox(height: 12),
                  Text('No medicine events yet',
                      style: TextStyle(color: Colors.white38, fontSize: 14)),
                  Text('Your timeline will appear here after you take medicines',
                      style: TextStyle(color: Colors.white24, fontSize: 12),
                      textAlign: TextAlign.center),
                ])),
              )
            else
              ..._log.take(20).map((entry) => _TimelineItem(entry: entry)),
          ]),
        ),
      ),
    );
  }
}

// ─── Stat Box ─────────────────────────────────────────────────────
class _StatBox extends StatelessWidget {
  final IconData icon; final String label, value; final Color color;
  const _StatBox({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11),
            textAlign: TextAlign.center),
      ]),
    ));
}

// ─── Timeline Item ────────────────────────────────────────────────
class _TimelineItem extends StatelessWidget {
  final HealthLogEntry entry;
  const _TimelineItem({required this.entry});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Column(children: [
        Container(width: 12, height: 12,
            decoration: const BoxDecoration(
              shape: BoxShape.circle, color: Color(0xFF10B981))),
        Container(width: 2, height: 50, color: Colors.white10),
      ]),
      const SizedBox(width: 12),
      Expanded(
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(entry.medicineName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              Text(DateFormat('hh:mm a').format(entry.time),
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ]),
            Text(entry.note, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            Text(DateFormat('dd MMM yyyy').format(entry.time),
                style: const TextStyle(color: Colors.white24, fontSize: 11)),
          ]),
        ),
      ),
    ],
  );
}
