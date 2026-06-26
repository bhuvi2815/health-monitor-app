// lib/services/twilio_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────
// ⚠️  FILL IN YOUR TWILIO CREDENTIALS
// Get them from: https://console.twilio.com
const String _twilioAccountSid = 'YOUR_TWILIO_ACCOUNT_SID';
const String _twilioAuthToken = 'YOUR_TWILIO_AUTH_TOKEN';
const String _twilioFromNumber = '+1XXXXXXXXXX'; // Your Twilio number
// ─────────────────────────────────────────────────────────────────

class TwilioService {
  /// Makes an automated phone call to [toNumber] with a spoken [message].
  /// The message is read using TwiML (Twilio Markup Language).
  static Future<bool> makeAutoCall({
    required String toNumber,
    required String message,
  }) async {
    final url = Uri.parse(
      'https://api.twilio.com/2010-04-01/Accounts/$_twilioAccountSid/Calls.json',
    );

    // TwiML: tells Twilio what to say when the call connects
    final twiml = '''
      <Response>
        <Say voice="Polly.Joanna" rate="90%">
          Hello. This is an automated health reminder from your Health Monitor app.
          $message
          Please take your medicine as prescribed.
          Thank you. Goodbye.
        </Say>
        <Pause length="1"/>
      </Response>
    ''';

    final credentials =
        base64Encode(utf8.encode('$_twilioAccountSid:$_twilioAuthToken'));

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'To': toNumber,
          'From': _twilioFromNumber,
          'Twiml': twiml,
        },
      );

      if (response.statusCode == 201) {
        print('✅ Call initiated successfully');
        return true;
      } else {
        print('❌ Twilio error: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Network error: $e');
      return false;
    }
  }

  /// Send an SMS reminder (bonus feature)
  static Future<bool> sendSmsReminder({
    required String toNumber,
    required String message,
  }) async {
    final url = Uri.parse(
      'https://api.twilio.com/2010-04-01/Accounts/$_twilioAccountSid/Messages.json',
    );

    final credentials =
        base64Encode(utf8.encode('$_twilioAccountSid:$_twilioAuthToken'));

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'To': toNumber,
          'From': _twilioFromNumber,
          'Body': message,
        },
      );
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }
}
