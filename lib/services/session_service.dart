import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const int sessionDays = 15;
  static const String _sessionUserIdKey = 'session_user_id';
  static const String _sessionStartedAtKey = 'session_started_at_ms';

  Future<void> startSession(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionUserIdKey, userId);
    await prefs.setInt(
      _sessionStartedAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionUserIdKey);
    await prefs.remove(_sessionStartedAtKey);
  }

  Future<bool> isSessionValidFor(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final storedUserId = prefs.getString(_sessionUserIdKey);
    final startedAtMs = prefs.getInt(_sessionStartedAtKey);
    if (storedUserId == null || startedAtMs == null) return false;
    if (storedUserId != userId) return false;

    final startedAt = DateTime.fromMillisecondsSinceEpoch(startedAtMs);
    final expiresAt = startedAt.add(const Duration(days: sessionDays));
    return DateTime.now().isBefore(expiresAt);
  }
}

