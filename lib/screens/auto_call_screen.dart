// lib/screens/auto_call_screen.dart
import 'package:flutter/material.dart';
import '../services/twilio_service.dart';

class AutoCallScreen extends StatefulWidget {
  const AutoCallScreen({super.key});

  @override
  State<AutoCallScreen> createState() => _AutoCallScreenState();
}

class _AutoCallScreenState extends State<AutoCallScreen> {
  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _messageCtrl = TextEditingController(
    text:
        'This is a reminder to take your medicine. Please take it as soon as possible.',
  );
  bool _isLoading = false;
  String _status = '';
  bool _statusSuccess = false;
  final List<Map<String, String>> _callLog = [];

  Future<void> _makeCall() async {
    if (_phoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a phone number'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _status = '';
    });

    final success = await TwilioService.makeAutoCall(
      toNumber: _phoneCtrl.text.trim(),
      message: _messageCtrl.text.trim(),
    );

    final logEntry = {
      'name': _nameCtrl.text.trim().isEmpty ? 'Patient' : _nameCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'time': TimeOfDay.now().format(context),
      'status': success ? 'Success' : 'Failed',
    };

    setState(() {
      _isLoading = false;
      _statusSuccess = success;
      _status = success
          ? '✅ Call initiated to ${_phoneCtrl.text.trim()}'
          : '❌ Call failed. Check your Twilio credentials.';
      _callLog.insert(0, logEntry);
    });
  }

  Future<void> _sendSms() async {
    if (_phoneCtrl.text.trim().isEmpty) return;
    setState(() => _isLoading = true);

    final success = await TwilioService.sendSmsReminder(
      toNumber: _phoneCtrl.text.trim(),
      message: '💊 Medicine Reminder: ${_messageCtrl.text.trim()}',
    );

    setState(() {
      _isLoading = false;
      _statusSuccess = success;
      _status = success ? '✅ SMS sent successfully!' : '❌ SMS failed.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '📞 Auto Call System',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.phone_callback_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Auto Call System',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Calls any phone — even non-smartphones!',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Input form
            _buildLabel('👤 Patient Name (optional)'),
            const SizedBox(height: 8),
            _buildTextField(
              _nameCtrl,
              'e.g. John Doe',
              Icons.person_outline,
              TextInputType.text,
            ),

            const SizedBox(height: 16),
            _buildLabel('📞 Phone Number (with country code)'),
            const SizedBox(height: 8),
            _buildTextField(
              _phoneCtrl,
              'e.g. +91 9876543210',
              Icons.phone,
              TextInputType.phone,
            ),

            const SizedBox(height: 16),
            _buildLabel('💬 Voice Message to Speak'),
            const SizedBox(height: 8),
            TextField(
              controller: _messageCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter the message to be spoken...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Status message
            if (_status.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _statusSuccess
                      ? const Color(0xFF10B981).withOpacity(0.15)
                      : const Color(0xFFEF4444).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _statusSuccess
                        ? const Color(0xFF10B981).withOpacity(0.4)
                        : const Color(0xFFEF4444).withOpacity(0.4),
                  ),
                ),
                child: Text(
                  _status,
                  style: TextStyle(
                    color: _statusSuccess
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                  ),
                ),
              ),

            // Action Buttons
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _makeCall,
                      icon: const Icon(Icons.call_rounded, color: Colors.white),
                      label: const Text(
                        'Make Call',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _sendSms,
                      icon: const Icon(
                        Icons.sms_rounded,
                        color: Color(0xFF8B5CF6),
                      ),
                      label: const Text(
                        'Send SMS',
                        style: TextStyle(
                          color: Color(0xFF8B5CF6),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF8B5CF6)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 28),

            // Call Log
            if (_callLog.isNotEmpty) ...[
              const Text(
                '📋 Call Log',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ..._callLog.map(
                (log) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: log['status'] == 'Success'
                          ? const Color(0xFF10B981).withOpacity(0.3)
                          : const Color(0xFFEF4444).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        log['status'] == 'Success'
                            ? Icons.check_circle
                            : Icons.cancel,
                        color: log['status'] == 'Success'
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              log['name']!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              log['phone']!,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        log['time']!,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Setup guide
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white10),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🔧 Setup Guide',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '1. Go to twilio.com and create a free account',
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '2. Get your Account SID + Auth Token from dashboard',
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '3. Get a free Twilio phone number',
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '4. Paste credentials in lib/services/twilio_service.dart',
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '5. That\'s it! You can now call any phone number 🎉',
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(
    text,
    style: const TextStyle(
      color: Colors.white70,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
  );

  Widget _buildTextField(
    TextEditingController ctrl,
    String hint,
    IconData icon,
    TextInputType type,
  ) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: const Color(0xFF8B5CF6), size: 20),
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
        ),
      ),
    );
  }
}
