// lib/main.dart
// ✅ ALL-IN-ONE FILE: AuthService + AuthGate + App entry point
// No separate auth_service.dart needed!

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'services/alarm_service.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';

// ═══════════════════════════════════════════════════════════════
// AUTH SERVICE — lives here, no separate file needed
// ═══════════════════════════════════════════════════════════════
class AuthService {
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_logged_in') ?? false;
  }

  static Future<Map<String, String>> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString('user_name') ?? 'User',
      'email': prefs.getString('user_email') ?? '',
    };
  }

  static Future<AuthResult> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    if (name.isEmpty || email.isEmpty || password.isEmpty)
      return AuthResult(success: false, error: 'Please fill in all fields.');
    if (!email.contains('@'))
      return AuthResult(success: false, error: 'Please enter a valid email.');
    if (password.length < 6)
      return AuthResult(
          success: false, error: 'Password must be at least 6 characters.');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);
    await prefs.setString('user_name', name.trim());
    await prefs.setString('user_email', email.trim());
    return AuthResult(success: true);
  }

  static Future<AuthResult> loginWithEmail({
    required String email,
    required String password,
  }) async {
    if (email.isEmpty || password.isEmpty)
      return AuthResult(success: false, error: 'Please fill in all fields.');
    if (!email.contains('@'))
      return AuthResult(success: false, error: 'Please enter a valid email.');
    if (password.length < 6)
      return AuthResult(
          success: false, error: 'Incorrect password. Min 6 characters.');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);
    await prefs.setString('user_email', email.trim());
    return AuthResult(success: true);
  }

  static Future<AuthResult> signInWithGoogle() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);
    await prefs.setString('user_name', 'Google User');
    await prefs.setString('user_email', 'user@gmail.com');
    return AuthResult(success: true);
  }

  static Future<AuthResult> sendPasswordReset(String email) async {
    if (email.isEmpty || !email.contains('@'))
      return AuthResult(success: false, error: 'Please enter a valid email.');
    return AuthResult(success: true);
  }

  static Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
  }
}

class AuthResult {
  final bool success;
  final String? error;
  AuthResult({required this.success, this.error});
}

// ═══════════════════════════════════════════════════════════════
// MAIN ENTRY POINT
// ═══════════════════════════════════════════════════════════════
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  await AlarmService.initialize();
  runApp(const HealthMonitorApp());
}

class HealthMonitorApp extends StatelessWidget {
  const HealthMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Health Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0EA5E9),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardColor: const Color(0xFF1E293B),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

// ── Shows Login or Home based on saved login state ────────────────
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthService.isLoggedIn(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0F172A),
            body: Center(
                child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_rounded,
                    color: Color(0xFF0EA5E9), size: 56),
                SizedBox(height: 20),
                CircularProgressIndicator(color: Color(0xFF0EA5E9)),
                SizedBox(height: 16),
                Text('Loading...', style: TextStyle(color: Colors.white54)),
              ],
            )),
          );
        }
        if (snapshot.data == true) return const HomeScreen();
        return const AuthScreen();
      },
    );
  }
}
