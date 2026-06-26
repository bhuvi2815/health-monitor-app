// lib/screens/sleep_tracker_screen.dart
// Daily sleep logging + correlation with health readings

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class SleepEntry {
  final DateTime date;
  final double hours;
  final String quality; // good / okay / poor
  final String? note;

  SleepEntry({required this.date, required this.hours,
      required this.quality, this.note});

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(), 'hours': hours,
    'quality': quality, 'note': note,
  };
  factory SleepEntry.fromJson(Map<String, dynamic> j) => SleepEntry(
    date: DateTime.parse(j['date']), hours: (j['hours'] as num).toDouble(),
    quality: j['quality'], note: j['note'],
  );
}

class SleepTrackerScreen extends StatefulWidget {
  const SleepTrackerScreen({super.key});
  @override
  State<SleepTrackerScreen> createState() => _SleepTrackerScreenState();
}

class _SleepTrackerScreenState extends State<SleepTrackerScreen> {
  List<SleepEntry> _entries = [];
  double _sleepHours = 7;
  String _quality = 'good';

  double get _avgHours => _entries.isEmpty ? 0 :
      _entries.map((e) => e.hours).reduce((a, b) => a + b) / _entries.length;

  String get _insight {
    if (_entries.isEmpty) return 'Log your first sleep entry to get insights.';
    final avg = _avgHours;
    if (avg >= 7 && avg <= 9) return 'Great sleep pattern! Keep it up. Your health should stay stable.';
    if (avg >= 6) return 'Slightly low sleep. Try to get 7–9 hours for better health readings.';
    return 'Poor sleep detected. This can affect BP, sugar, and immunity. Prioritise rest!';
  }

  Color get _insightColor {
    if (_avgHours >= 7) return const Color(0xFF10B981);
    if (_avgHours >= 6) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('sleep_entries');
    if (data != null) {
      final list = jsonDecode(data) as List;
      setState(() => _entries = list.map((e) => SleepEntry.fromJson(e)).toList());
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sleep_entries',
        jsonEncode(_entries.map((e) => e.toJson()).toList()));
  }

  void _logSleep() {
    showDialog(context: context, builder: (_) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("Log Last Night's Sleep",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${_sleepHours.toStringAsFixed(1)} hours',
              style: const TextStyle(color: Color(0xFF0EA5E9),
                  fontSize: 32, fontWeight: FontWeight.bold)),
          Slider(
            value: _sleepHours,
            min: 1, max: 12, divisions: 22,
            activeColor: const Color(0xFF0EA5E9),
            onChanged: (v) => setS(() => _sleepHours = v),
          ),
          const SizedBox(height: 10),
          const Text('Sleep quality:',
              style: TextStyle(color: Colors.white60, fontSize: 13)),
          const SizedBox(height: 8),
          Row(children: ['good','okay','poor'].map((q) {
            final color = q == 'good'
                ? const Color(0xFF10B981)
                : q == 'okay' ? const Color(0xFFF59E0B)
                : const Color(0xFFEF4444);
            return Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => setS(() => _quality = q),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _quality == q
                        ? color.withOpacity(0.2) : Colors.transparent,
                    border: Border.all(
                      color: _quality == q ? color : Colors.white24),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(q[0].toUpperCase() + q.substring(1),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _quality == q ? color : Colors.white54,
                      fontWeight: FontWeight.bold, fontSize: 13,
                    )),
                ),
              ),
            ));
          }).toList()),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9)),
            onPressed: () async {
              final entry = SleepEntry(
                date: DateTime.now(),
                hours: double.parse(_sleepHours.toStringAsFixed(1)),
                quality: _quality,
              );
              setState(() => _entries.insert(0, entry));
              await _save();
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final recent = _entries.take(7).toList().reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sleep Tracker',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _logSleep,
        icon: const Icon(Icons.bedtime_rounded),
        label: const Text('Log Sleep'),
        backgroundColor: const Color(0xFF0EA5E9),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Insight banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _insightColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _insightColor.withOpacity(0.4)),
            ),
            child: Row(children: [
              Icon(Icons.lightbulb_rounded, color: _insightColor, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Text(_insight,
                  style: TextStyle(color: _insightColor, fontSize: 13,
                      fontWeight: FontWeight.w500))),
            ]),
          ),

          const SizedBox(height: 20),

          // Stats row
          Row(children: [
            _SleepStat('Avg Sleep',
                '${_avgHours.toStringAsFixed(1)}h', const Color(0xFF0EA5E9)),
            const SizedBox(width: 10),
            _SleepStat('Total Logs',
                '${_entries.length}', const Color(0xFF8B5CF6)),
            const SizedBox(width: 10),
            _SleepStat('Best Night',
                _entries.isEmpty ? '--'
                    : '${_entries.map((e) => e.hours).reduce((a,b)=>a>b?a:b).toStringAsFixed(1)}h',
                const Color(0xFF10B981)),
          ]),

          const SizedBox(height: 24),

          // Sleep chart
          if (recent.isNotEmpty) ...[
            const Text('Last 7 nights',
                style: TextStyle(color: Colors.white70, fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Container(
              height: 180,
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
              ),
              child: LineChart(LineChartData(
                minY: 0, maxY: 12,
                gridData: FlGridData(
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: Colors.white10, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true, reservedSize: 28,
                    getTitlesWidget: (v, _) => Text('${v.toInt()}h',
                        style: const TextStyle(
                            color: Colors.white24, fontSize: 10)),
                  )),
                  bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: recent.asMap().entries
                        .map((e) => FlSpot(
                            e.key.toDouble(), e.value.hours))
                        .toList(),
                    isCurved: true,
                    color: const Color(0xFF0EA5E9),
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFF0EA5E9).withOpacity(0.1)),
                  ),
                  // Recommended 8h line
                  LineChartBarData(
                    spots: [FlSpot(0, 8), FlSpot(recent.length - 1.0, 8)],
                    color: const Color(0xFF10B981).withOpacity(0.5),
                    barWidth: 1,
                    dashArray: [5, 5],
                    dotData: const FlDotData(show: false),
                  ),
                ],
              )),
            ),
            const SizedBox(height: 8),
            const Text('  — — Recommended 8h',
                style: TextStyle(color: Color(0xFF10B981),
                    fontSize: 11)),
            const SizedBox(height: 20),
          ],

          // Sleep log list
          const Text('Sleep Log',
              style: TextStyle(color: Colors.white70, fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (_entries.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.only(top: 40),
              child: Column(children: [
                Icon(Icons.bedtime_outlined, size: 60, color: Colors.white24),
                SizedBox(height: 12),
                Text('No sleep logs yet',
                    style: TextStyle(color: Colors.white38)),
                Text('Tap + to log last night\'s sleep',
                    style: TextStyle(color: Colors.white24, fontSize: 13)),
              ]),
            ))
          else
            ..._entries.take(10).map((e) {
              final color = e.quality == 'good'
                  ? const Color(0xFF10B981)
                  : e.quality == 'okay'
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFFEF4444);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Row(children: [
                  Icon(Icons.bedtime_rounded, color: color, size: 24),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Text('${e.hours}h sleep',
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(DateFormat('dd MMM yyyy').format(e.date),
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12)),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      e.quality[0].toUpperCase() + e.quality.substring(1),
                      style: TextStyle(color: color,
                          fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ]),
              );
            }),
        ]),
      ),
    );
  }
}

class _SleepStat extends StatelessWidget {
  final String label, value; final Color color;
  const _SleepStat(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(color: color,
            fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(
            color: Colors.white38, fontSize: 11),
            textAlign: TextAlign.center),
      ]),
    ),
  );
}
