import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:smartspoon/core/config/app_config.dart';

class EmailService {
  EmailService._();

  /// Send welcome email to newly verified user
  /// This calls the backend endpoint which uses Resend to send the email
  static Future<bool> sendWelcomeEmail({
    required String email,
    required String name,
  }) async {
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/email/welcome');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'name': name,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('✅ Welcome email sent to $email');
        return true;
      } else {
        print('❌ Failed to send welcome email: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Welcome email error: $e');
      return false; // Don't block login if email fails
    }
  }
}
