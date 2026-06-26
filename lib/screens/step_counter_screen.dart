// lib/screens/step_counter_screen.dart
// Auto step counting using phone accelerometer — no device needed!

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class StepCounterScreen extends StatefulWidget {
  const StepCounterScreen({super.key});
  @override
  State<StepCounterScreen> createState() => _StepCounterScreenState();
}

class _StepCounterScreenState extends State<StepCounterScreen> {
  StreamSubscription<StepCount>? _stepSub;
  StreamSubscription<PedestrianStatus>? _statusSub;

  int _todaySteps    = 0;
  int _goalSteps     = 8000;
  String _status     = 'stopped';
  bool _isTracking   = false;

  // Weekly data — list of 7 day step counts
  List<int> _weeklySteps = List.filled(7, 0);

  // Derived stats
  double get _km       => (_todaySteps * 0.762) / 1000;
  int    get _calories => (_todaySteps * 0.04).toInt();
  double get _progress => (_todaySteps / _goalSteps).clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    _load();
    _requestAndStart();
  }

  @override
  void dispose() {
    _stepSub?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    setState(() {
      _todaySteps = prefs.getInt('steps_$today') ?? 0;
      _goalSteps  = prefs.getInt('step_goal') ?? 8000;
    });
    await _loadWeekly();
  }

  Future<void> _loadWeekly() async {
    final prefs = await SharedPreferences.getInstance();
    final weekly = <int>[];
    for (int i = 6; i >= 0; i--) {
      final day = DateFormat('yyyy-MM-dd')
          .format(DateTime.now().subtract(Duration(days: i)));
      weekly.add(prefs.getInt('steps_$day') ?? 0);
    }
    setState(() => _weeklySteps = weekly);
  }

  Future<void> _requestAndStart() async {
    if (kIsWeb) {
      // Simulate steps on web for demo
      setState(() { _todaySteps = 3247; _isTracking = true; _status = 'walking'; });
      await _loadWeekly();
      return;
    }
    final status = await Permission.activityRecognition.request();
    if (status.isGranted) _startTracking();
  }

  void _startTracking() {
    setState(() => _isTracking = true);

    _statusSub = Pedometer.pedestrianStatusStream.listen(
      (event) => setState(() => _status = event.status),
      onError: (_) => setState(() => _status = 'unavailable'),
    );

    _stepSub = Pedometer.stepCountStream.listen(
      (event) async {
        final prefs = await SharedPreferences.getInstance();
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        // We store daily count (not total from reboot)
        final saved = prefs.getInt('step_base_$today');
        if (saved == null) {
          await prefs.setInt('step_base_$today', event.steps);
        }
        final base = prefs.getInt('step_base_$today') ?? event.steps;
        final todayCount = event.steps - base;
        await prefs.setInt('steps_$today', todayCount);
        setState(() => _todaySteps = todayCount);
        await _loadWeekly();
      },
      onError: (_) => setState(() => _isTracking = false),
    );
  }

  Future<void> _setGoal() async {
    int tempGoal = _goalSteps;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Set Daily Goal',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Choose your daily step goal:',
              style: TextStyle(color: Colors.white60, fontSize: 13)),
          const SizedBox(height: 14),
          ...[5000, 8000, 10000, 12000, 15000].map((g) => RadioListTile<int>(
            value: g,
            groupValue: tempGoal,
            onChanged: (v) => setState(() => tempGoal = v!),
            title: Text('$g steps',
                style: const TextStyle(color: Colors.white, fontSize: 14)),
            activeColor: const Color(0xFF10B981),
          )),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setInt('step_goal', tempGoal);
              setState(() => _goalSteps = tempGoal);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxW = _weeklySteps.isEmpty ? 1 : _weeklySteps.reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Steps & Activity',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_rounded),
            onPressed: _setGoal,
            tooltip: 'Set goal',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Status banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _isTracking
                  ? const Color(0xFF10B981).withOpacity(0.12)
                  : const Color(0xFFEF4444).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isTracking
                    ? const Color(0xFF10B981).withOpacity(0.4)
                    : const Color(0xFFEF4444).withOpacity(0.4),
              ),
            ),
            child: Row(children: [
              Icon(
                _status == 'walking' ? Icons.directions_walk_rounded
                    : _status == 'stopped' ? Icons.accessibility_new_rounded
                    : Icons.sensors_rounded,
                color: _isTracking ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _isTracking
                    ? 'Tracking active — Status: $_status'
                    : 'Tracking inactive — Enable Activity permission',
                style: TextStyle(
                  color: _isTracking ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  fontSize: 13, fontWeight: FontWeight.w500,
                ),
              ),
            ]),
          ),

          const SizedBox(height: 20),

          // Big step ring
          Center(
            child: SizedBox(
              width: 200, height: 200,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox(
                  width: 200, height: 200,
                  child: CircularProgressIndicator(
                    value: _progress,
                    strokeWidth: 14,
                    backgroundColor: Colors.white10,
                    color: _progress >= 1.0
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF10B981),
                  ),
                ),
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(
                    '$_todaySteps',
                    style: const TextStyle(
                      color: Colors.white, fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text('steps today',
                      style: TextStyle(color: Colors.white54, fontSize: 13)),
                  Text(
                    'Goal: $_goalSteps',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ]),
              ]),
            ),
          ),

          const SizedBox(height: 24),

          // Stats row
          Row(children: [
            _StatTile('Distance', '${_km.toStringAsFixed(2)} km',
                Icons.route_rounded, const Color(0xFF0EA5E9)),
            const SizedBox(width: 10),
            _StatTile('Calories', '$_calories kcal',
                Icons.local_fire_department_rounded, const Color(0xFFF97316)),
            const SizedBox(width: 10),
            _StatTile('Goal', '${(_progress * 100).toInt()}%',
                Icons.flag_rounded,
                _progress >= 1.0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
          ]),

          const SizedBox(height: 24),

          // Weekly chart
          const Text('Weekly Steps',
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
            child: BarChart(BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: (maxW * 1.2).toDouble().clamp(1000, double.infinity),
              barTouchData: BarTouchData(enabled: false),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) {
                    const days = ['M','T','W','T','F','S','S'];
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(days[v.toInt() % 7],
                          style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    );
                  },
                )),
                leftTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true, reservedSize: 36,
                  getTitlesWidget: (v, _) => Text(
                    v >= 1000 ? '${(v/1000).toInt()}k' : '${v.toInt()}',
                    style: const TextStyle(color: Colors.white24, fontSize: 10),
                  ),
                )),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                getDrawingHorizontalLine: (_) =>
                    const FlLine(color: Colors.white10, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              barGroups: _weeklySteps.asMap().entries.map((e) {
                final isToday = e.key == 6;
                return BarChartGroupData(x: e.key, barRods: [
                  BarChartRodData(
                    toY: e.value.toDouble(),
                    color: isToday
                        ? const Color(0xFF10B981)
                        : const Color(0xFF10B981).withOpacity(0.4),
                    width: 20,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ]);
              }).toList(),
            )),
          ),

          const SizedBox(height: 16),
          Center(
            child: Text(
              _progress >= 1.0
                  ? '🎉 Goal achieved! Great job today!'
                  : '${(_goalSteps - _todaySteps).clamp(0, _goalSteps)} more steps to reach your goal',
              style: TextStyle(
                color: _progress >= 1.0
                    ? const Color(0xFFF59E0B)
                    : Colors.white54,
                fontSize: 13,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatTile(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(
            color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        Text(label, style: const TextStyle(
            color: Colors.white38, fontSize: 11)),
      ]),
    ),
  );
}
