import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sheets_service.dart';

/// Silent analytics service.
/// Queues events locally and syncs to Firestore whenever internet is available.
/// Never blocks the UI — all operations are fire-and-forget.
class AnalyticsService {
  static const String _queueKey = 'analytics_queue';

  // ── Public API ───────────────────────────────────────────────────────────

  /// Call when a response is generated. Records model usage.
  static Future<void> logModelUsed(String modelFilename) async {
    await _incrementTotal('total_usage');
    await _queue({
      'type': 'model_used',
      'model': modelFilename,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
    _trySyncInBackground();
  }

  /// Call when user taps 👍
  static Future<void> logLike(String modelFilename) async {
    await _incrementTotal('total_likes');
    await _queue({
      'type': 'like',
      'model': modelFilename,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
    _trySyncInBackground();
  }

  /// Call when user taps 👎
  static Future<void> logDislike(String modelFilename) async {
    await _incrementTotal('total_dislikes');
    await _queue({
      'type': 'dislike',
      'model': modelFilename,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
    _trySyncInBackground();
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  static Future<void> _incrementTotal(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt(key) ?? 0;
      await prefs.setInt(key, current + 1);
    } catch (_) {}
  }

  static Future<void> _queue(Map<String, dynamic> event) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_queueKey);
      final List<dynamic> queue = raw != null ? jsonDecode(raw) : [];
      queue.add(event);
      await prefs.setString(_queueKey, jsonEncode(queue));
    } catch (_) {}
  }

  /// Fire-and-forget background sync — never throws, never blocks.
  static void _trySyncInBackground() {
    _sync().catchError((_) {});
  }

  static Future<void> _sync() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queueKey);
    if (raw == null) return;

    final List<dynamic> queue = jsonDecode(raw);
    if (queue.isEmpty) return;

    // Aggregate locally before writing (reduces Firestore writes)
    final Map<String, int> modelUsage = {};
    final Map<String, int> likes = {};
    final Map<String, int> dislikes = {};

    for (final event in queue) {
      final type = event['type'] as String;
      final model = (event['model'] as String?) ?? 'unknown';

      if (type == 'model_used') {
        modelUsage[model] = (modelUsage[model] ?? 0) + 1;
      } else if (type == 'like') {
        likes[model] = (likes[model] ?? 0) + 1;
      } else if (type == 'dislike') {
        dislikes[model] = (dislikes[model] ?? 0) + 1;
      }
    }

    // Build Firestore increments
    final Map<String, dynamic> updates = {};
    modelUsage.forEach((model, count) {
      updates['usage.$model'] = FieldValue.increment(count);
    });
    likes.forEach((model, count) {
      updates['likes.$model'] = FieldValue.increment(count);
    });
    dislikes.forEach((model, count) {
      updates['dislikes.$model'] = FieldValue.increment(count);
    });

    if (updates.isEmpty) return;

    // Write to Firestore — if this throws (no internet) the queue stays intact
    await FirebaseFirestore.instance
        .collection('analytics')
        .doc(user.uid)
        .set(updates, SetOptions(merge: true));

    // Sync to Google Sheets as well
    final totalUsage = prefs.getInt('total_usage') ?? 0;
    final totalLikes = prefs.getInt('total_likes') ?? 0;
    final totalDislikes = prefs.getInt('total_dislikes') ?? 0;
    
    // We don't have survey answers here, but syncUser will use the last known ones from its own SharedPreferences
    await SheetsService.syncUser(
      modelUsageCount: totalUsage,
      likes: totalLikes,
      dislikes: totalDislikes,
    );

    // Clear the queue only after a successful write
    await prefs.remove(_queueKey);
  }
}
