import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SheetsService {
  // ← Paste your deployed Apps Script URL here after deploying
  static const String _scriptUrl = 'https://script.google.com/macros/s/AKfycbwhlm-vJL4KJHZDxUT0lADsajVY0D7K9oE3AXc8uV_apMyP3AweRip1QLP2kwKpwjr4/exec';

  static const String _pendingKey = 'sheets_pending_payload';

  /// Call this after survey completion or model change.
  /// Saves payload locally first, then tries to send.
  static Future<void> syncUser({
    Map<String, String>? surveyAnswers,
    String? selectedModel,
    int modelUsageCount = 0,
    int likes = 0,
    int dislikes = 0,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();

    // Load last known values if not provided
    final lastSurveyRaw = prefs.getString('last_survey');
    final Map<String, String> lastSurvey = lastSurveyRaw != null 
        ? Map<String, String>.from(jsonDecode(lastSurveyRaw)) 
        : {};
    
    final lastModel = prefs.getString('last_model') ?? '';

    final effectiveSurvey = surveyAnswers ?? lastSurvey;
    final effectiveModel = selectedModel ?? lastModel;

    // Save for next time
    if (surveyAnswers != null) {
      await prefs.setString('last_survey', jsonEncode(surveyAnswers));
    }
    if (selectedModel != null) {
      await prefs.setString('last_model', selectedModel);
    }

    final payload = {
      'name': user.displayName ?? '',
      'email': user.email ?? '',
      'survey': effectiveSurvey,
      'selectedModel': effectiveModel,
      'modelUsageCount': modelUsageCount,
      'likes': likes,
      'dislikes': dislikes,
    };

    // Save locally first (offline-safe)
    await prefs.setString(_pendingKey, jsonEncode(payload));

    // Try to send now (fire-and-forget)
    _trySend(prefs, payload);
  }

  static void _trySend(SharedPreferences prefs, Map<String, dynamic> payload) {
    _send(payload).then((_) {
      prefs.remove(_pendingKey); // Clear only on success
    }).catchError((_) {
      // Will retry next time syncUser() is called
    });
  }

  static Future<void> _send(Map<String, dynamic> payload) async {
    await http.post(
      Uri.parse(_scriptUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
  }

  /// Call on app start when internet comes back — retries any unsent payload.
  static Future<void> retryPending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingKey);
    if (raw == null) return;

    try {
      final payload = jsonDecode(raw) as Map<String, dynamic>;
      await _send(payload);
      await prefs.remove(_pendingKey);
    } catch (_) {}
  }
}
