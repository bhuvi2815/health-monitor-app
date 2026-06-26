// lib/screens/voice_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────
// ⚠️  REPLACE THIS WITH YOUR OPENAI API KEY
const String _openAiApiKey = 'YOUR_OPENAI_API_KEY_HERE';
// ─────────────────────────────────────────────────────────────────

class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen>
    with TickerProviderStateMixin {
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _isListening = false;
  bool _isLoading = false;
  String _spokenText = '';
  String _response = '';
  final List<Map<String, String>> _chatHistory = [];
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  Future<void> _initSpeech() async {
    await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
          if (_spokenText.isNotEmpty) _askAI(_spokenText);
        }
      },
    );
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
  }

  Future<void> _startListening() async {
    if (!_speech.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() {
      _isListening = true;
      _spokenText = '';
    });
    await _speech.listen(
      onResult: (result) =>
          setState(() => _spokenText = result.recognizedWords),
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: 'en_US',
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
    if (_spokenText.isNotEmpty) _askAI(_spokenText);
  }

  Future<void> _askAI(String question) async {
    setState(() {
      _isLoading = true;
      _response = '';
    });

    _chatHistory.add({'role': 'user', 'content': question});

    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_openAiApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are a helpful health assistant. Give short, clear, and accurate health advice. '
                  'Always remind users to consult a doctor for serious concerns. Keep responses under 100 words.',
            },
            ..._chatHistory
                .map((m) => {'role': m['role']!, 'content': m['content']!})
                .toList(),
          ],
          'max_tokens': 200,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final answer = data['choices'][0]['message']['content']
            .toString()
            .trim();
        _chatHistory.add({'role': 'assistant', 'content': answer});
        setState(() {
          _response = answer;
          _isLoading = false;
        });
        await _tts.speak(answer);
      } else {
        setState(() {
          _response = 'Error: Could not connect to AI. Check your API key.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _response = 'Connection error. Please check your internet.';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '🎙️ Voice Assistant',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => setState(() {
              _chatHistory.clear();
              _response = '';
              _spokenText = '';
            }),
            tooltip: 'Clear chat',
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat history
          Expanded(
            child: _chatHistory.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.health_and_safety_outlined,
                          size: 80,
                          color: Colors.white24,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Ask me anything about your health',
                          style: TextStyle(color: Colors.white38, fontSize: 15),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap the mic button and speak',
                          style: TextStyle(color: Colors.white24, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _chatHistory.length,
                    itemBuilder: (ctx, i) {
                      final msg = _chatHistory[i];
                      final isUser = msg['role'] == 'user';
                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          decoration: BoxDecoration(
                            color: isUser
                                ? const Color(0xFF0EA5E9)
                                : const Color(0xFF1E293B),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(isUser ? 16 : 4),
                              bottomRight: Radius.circular(isUser ? 4 : 16),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isUser ? '🧑 You' : '🤖 AI',
                                style: TextStyle(
                                  color: isUser
                                      ? Colors.white70
                                      : const Color(0xFF10B981),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                msg['content']!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Listening indicator
          if (_isListening || _spokenText.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF0EA5E9).withOpacity(0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mic, color: Color(0xFF0EA5E9), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isListening
                          ? (_spokenText.isEmpty ? 'Listening...' : _spokenText)
                          : _spokenText,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'AI is thinking...',
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            ),

          // Mic Button
          Padding(
            padding: const EdgeInsets.all(24),
            child: GestureDetector(
              onTapDown: (_) => _startListening(),
              onTapUp: (_) => _stopListening(),
              onTapCancel: () => _stopListening(),
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (_, child) => Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF0EA5E9),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (_isListening
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF0EA5E9))
                                .withOpacity(
                                  _isListening
                                      ? _pulseController.value * 0.6
                                      : 0.3,
                                ),
                        blurRadius: _isListening ? 30 : 15,
                        spreadRadius: _isListening ? 10 : 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Hold to speak • Release to send',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
