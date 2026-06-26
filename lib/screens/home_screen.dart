// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import '../main.dart'; // AuthService lives in main.dart
import 'auth_screen.dart';
import 'medicine_screen.dart';
import 'health_screen.dart';
import 'voice_screen.dart';
import 'auto_call_screen.dart';
import 'hospital_screen.dart';
import 'health_report_screen.dart';
import 'step_counter_screen.dart';
import 'sleep_tracker_screen.dart';
import 'sos_screen.dart';
import 'wearable_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    _DashboardTab(), MedicineScreen(), HealthScreen(), VoiceScreen(), AutoCallScreen(),
    HospitalScreen(), HealthReportScreen(),
    StepCounterScreen(), SleepTrackerScreen(), SosScreen(), WearableScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF1E293B),
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.medication_rounded), label: 'Medicine'),
          NavigationDestination(icon: Icon(Icons.monitor_heart_rounded), label: 'Health'),
          NavigationDestination(icon: Icon(Icons.mic_rounded), label: 'Voice AI'),
          NavigationDestination(icon: Icon(Icons.phone_rounded), label: 'Auto Call'),
          NavigationDestination(icon: Icon(Icons.local_hospital_rounded), label: 'Hospitals'),
          NavigationDestination(icon: Icon(Icons.folder_rounded), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.directions_walk_rounded), label: 'Steps'),
          NavigationDestination(icon: Icon(Icons.bedtime_rounded), label: 'Sleep'),
          NavigationDestination(icon: Icon(Icons.sos_rounded), label: 'SOS'),
          NavigationDestination(icon: Icon(Icons.watch_rounded), label: 'Wearable'),
        ],
      ),
    );
  }
}

class _DashboardTab extends StatefulWidget {
  const _DashboardTab();
  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  String _userName  = 'User';
  String _userEmail = '';

  @override
  void initState() { super.initState(); _loadUser(); }

  Future<void> _loadUser() async {
    final user = await AuthService.getCurrentUser();
    if (mounted) setState(() { _userName = user['name']!; _userEmail = user['email']!; });
  }

  Future<void> _logout() async {
    await AuthService.signOut();
    if (mounted) Navigator.pushReplacement(
      context, MaterialPageRoute(builder: (_) => const AuthScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🏥 Health Monitor', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          PopupMenuButton<String>(
            icon: CircleAvatar(
              backgroundColor: const Color(0xFF0EA5E9),
              child: Text(_userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            color: const Color(0xFF1E293B),
            itemBuilder: (_) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                enabled: false,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_userName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text(_userEmail,
                      style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ]),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(children: [
                  Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 18),
                  SizedBox(width: 10),
                  Text('Logout', style: TextStyle(color: Color(0xFFEF4444))),
                ]),
              ),
            ],
            onSelected: (v) async { if (v == 'logout') await _logout(); },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(children: [
              const Icon(Icons.favorite_rounded, color: Colors.white, size: 40),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Hello, $_userName! 👋',
                    style: const TextStyle(color: Colors.white70, fontSize: 14)),
                const Text('Stay Healthy Today',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ]),
            ]),
          ),
          const SizedBox(height: 24),
          const Text('📊 Today\'s Overview',
              style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(children: [
            _StatCard(icon: Icons.medication,  label: 'Medicines',   value: '3 Today',   color: const Color(0xFF10B981)),
            const SizedBox(width: 12),
            _StatCard(icon: Icons.favorite,    label: 'Heart Rate',  value: '72 BPM',    color: const Color(0xFFEC4899)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _StatCard(icon: Icons.water_drop,  label: 'Blood Sugar', value: '90 mg/dL',  color: const Color(0xFFF59E0B)),
            const SizedBox(width: 12),
            _StatCard(icon: Icons.thermostat,  label: 'Temperature', value: '98.6°F',    color: const Color(0xFF8B5CF6)),
          ]),
          const SizedBox(height: 24),
          const Text('⚡ Quick Access',
              style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _FeatureCard(icon: Icons.alarm_rounded,  title: '💊 Medicine Alarm',
              subtitle: 'Set and manage your medicine reminders', color: const Color(0xFF0EA5E9), onTap: () {}),
          const SizedBox(height: 10),
          _FeatureCard(icon: Icons.mic_rounded,    title: '🎙️ Voice Assistant',
              subtitle: 'Ask health questions using your voice',  color: const Color(0xFF10B981), onTap: () {}),
          const SizedBox(height: 10),
          _FeatureCard(icon: Icons.phone_rounded,  title: '📞 Auto Call System',
              subtitle: 'Calls patient if medicine is missed',    color: const Color(0xFF8B5CF6), onTap: () {}),
        ]),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon; final String label, value; final Color color;
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 28), const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      ]),
    ));
}

class _FeatureCard extends StatelessWidget {
  final IconData icon; final String title, subtitle; final Color color; final VoidCallback onTap;
  const _FeatureCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2))),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 24)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ])),
        Icon(Icons.arrow_forward_ios_rounded, color: color, size: 16),
      ]),
    ));
}
