// lib/screens/auth_screen.dart
import 'package:flutter/material.dart';
import '../main.dart'; // AuthService lives in main.dart now
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  String _errorMessage = '';

  final _loginEmailCtrl = TextEditingController();
  final _loginPasswordCtrl = TextEditingController();
  bool _loginPassVisible = false;

  final _regNameCtrl = TextEditingController();
  final _regEmailCtrl = TextEditingController();
  final _regPasswordCtrl = TextEditingController();
  final _regConfirmCtrl = TextEditingController();
  bool _regPassVisible = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() => _errorMessage = ''));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _setError(String msg) => setState(() {
        _errorMessage = msg;
        _isLoading = false;
      });
  void _setLoading(bool v) => setState(() {
        _isLoading = v;
        _errorMessage = '';
      });

  void _goHome() => Navigator.pushReplacement(
      context, MaterialPageRoute(builder: (_) => const HomeScreen()));

  Future<void> _googleSignIn() async {
    _setLoading(true);
    final result = await AuthService.signInWithGoogle();
    if (result.success) {
      _goHome();
    } else {
      _setError(result.error!);
    }
  }

  Future<void> _emailLogin() async {
    _setLoading(true);
    final result = await AuthService.loginWithEmail(
        email: _loginEmailCtrl.text, password: _loginPasswordCtrl.text);
    if (result.success) {
      _goHome();
    } else {
      _setError(result.error!);
    }
  }

  Future<void> _emailRegister() async {
    if (_regPasswordCtrl.text != _regConfirmCtrl.text) {
      _setError('Passwords do not match.');
      return;
    }
    _setLoading(true);
    final result = await AuthService.registerWithEmail(
        name: _regNameCtrl.text,
        email: _regEmailCtrl.text,
        password: _regPasswordCtrl.text);
    if (result.success) {
      _goHome();
    } else {
      _setError(result.error!);
    }
  }

  void _forgotPassword() {
    final ctrl = TextEditingController(text: _loginEmailCtrl.text);
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: const Text('Reset Password',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Enter your email to receive a reset link.',
                    style: TextStyle(color: Colors.white60, fontSize: 13)),
                const SizedBox(height: 14),
                _field(ctrl, 'Email', Icons.email_outlined, false,
                    TextInputType.emailAddress),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel',
                        style: TextStyle(color: Colors.white54))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0EA5E9)),
                  onPressed: () async {
                    Navigator.pop(context);
                    final result =
                        await AuthService.sendPasswordReset(ctrl.text);
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(result.success
                            ? '✅ Reset link sent!'
                            : result.error ?? 'Failed'),
                        backgroundColor: result.success
                            ? const Color(0xFF10B981)
                            : Colors.red,
                      ));
                  },
                  child: const Text('Send Link',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
          child: SingleChildScrollView(
              child: Column(children: [
        // Hero Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 44, 24, 36),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(36),
                bottomRight: Radius.circular(36)),
          ),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle),
              child: const Icon(Icons.favorite_rounded,
                  color: Colors.white, size: 48),
            ),
            const SizedBox(height: 16),
            const Text('Health Monitor',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Your personal health companion',
                style: TextStyle(color: Colors.white70, fontSize: 14)),
          ]),
        ),
        const SizedBox(height: 28),

        // Tab Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14)),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                  color: const Color(0xFF0EA5E9),
                  borderRadius: BorderRadius.circular(12)),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white38,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              tabs: const [Tab(text: 'Login'), Tab(text: 'Register')],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Error Banner
        if (_errorMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.12),
                border:
                    Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded,
                    color: Color(0xFFEF4444), size: 20),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(_errorMessage,
                        style: const TextStyle(
                            color: Color(0xFFEF4444), fontSize: 13))),
              ]),
            ),
          ),

        // Tab Views
        SizedBox(
          height: 520,
          child: TabBarView(
              controller: _tabController,
              children: [_loginTab(), _registerTab()]),
        ),
      ]))),
    );
  }

  Widget _loginTab() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(children: [
          _field(_loginEmailCtrl, 'Email address', Icons.email_outlined, false,
              TextInputType.emailAddress),
          const SizedBox(height: 14),
          _field(_loginPasswordCtrl, 'Password', Icons.lock_outline_rounded,
              true, null,
              visible: _loginPassVisible,
              onToggle: () =>
                  setState(() => _loginPassVisible = !_loginPassVisible)),
          const SizedBox(height: 8),
          Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                  onTap: _forgotPassword,
                  child: const Text('Forgot Password?',
                      style: TextStyle(
                          color: Color(0xFF0EA5E9),
                          fontSize: 13,
                          fontWeight: FontWeight.w500)))),
          const SizedBox(height: 20),
          _isLoading
              ? const CircularProgressIndicator(color: Color(0xFF0EA5E9))
              : _primaryBtn('Login', Icons.login_rounded,
                  const Color(0xFF0EA5E9), _emailLogin),
          const SizedBox(height: 20),
          _divider(),
          const SizedBox(height: 20),
          _googleBtn(),
        ]),
      );

  Widget _registerTab() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(children: [
          _field(_regNameCtrl, 'Full Name', Icons.person_outline_rounded, false,
              TextInputType.name),
          const SizedBox(height: 14),
          _field(_regEmailCtrl, 'Email address', Icons.email_outlined, false,
              TextInputType.emailAddress),
          const SizedBox(height: 14),
          _field(_regPasswordCtrl, 'Password', Icons.lock_outline_rounded, true,
              null,
              visible: _regPassVisible,
              onToggle: () =>
                  setState(() => _regPassVisible = !_regPassVisible)),
          const SizedBox(height: 14),
          _field(_regConfirmCtrl, 'Confirm Password',
              Icons.lock_outline_rounded, true, null,
              visible: _regPassVisible,
              onToggle: () =>
                  setState(() => _regPassVisible = !_regPassVisible)),
          const SizedBox(height: 20),
          _isLoading
              ? const CircularProgressIndicator(color: Color(0xFF6366F1))
              : _primaryBtn('Create Account', Icons.person_add_rounded,
                  const Color(0xFF6366F1), _emailRegister),
          const SizedBox(height: 20),
          _divider(),
          const SizedBox(height: 20),
          _googleBtn(),
        ]),
      );

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      bool isPassword, TextInputType? keyboardType,
      {bool? visible, VoidCallback? onToggle}) {
    return TextField(
      controller: ctrl,
      obscureText: isPassword && !(visible ?? false),
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 14),
        prefixIcon: Icon(icon, color: const Color(0xFF0EA5E9), size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                    (visible ?? false)
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.white38,
                    size: 20),
                onPressed: onToggle)
            : null,
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _primaryBtn(
          String label, IconData icon, Color color, VoidCallback onTap) =>
      SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, color: Colors.white, size: 20),
            label: Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
                backgroundColor: color,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0),
          ));

  Widget _googleBtn() => SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _googleSignIn,
        style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.white12),
            backgroundColor: const Color(0xFF1E293B),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(4)),
            child: const Center(
                child: Text('G',
                    style: TextStyle(
                        color: Color(0xFF4285F4),
                        fontWeight: FontWeight.bold,
                        fontSize: 16))),
          ),
          const SizedBox(width: 12),
          const Text('Continue with Google',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500)),
        ]),
      ));

  Widget _divider() => const Row(children: [
        Expanded(child: Divider(color: Colors.white12)),
        Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('OR',
                style: TextStyle(
                    color: Colors.white24, fontSize: 12, letterSpacing: 1))),
        Expanded(child: Divider(color: Colors.white12)),
      ]);
}
