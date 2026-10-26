import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';

final sessionServiceProvider = Provider<SessionService>((ref) {
  return SessionService(FirebaseAuth.instance);
});

/// Login sessions.
///
/// Members stay signed in until they sign out themselves — they will not
/// remember a password at the venue. (Until 1.3.0 the app signed itself out
/// after `autoLogoutHours`.) Whether someone is "online now" or "present today"
/// is reported by [PresenceService] and worked out on the server.
class SessionService {
  static const String _loginAtKey = 'session_login_at';

  final FirebaseAuth _auth;

  SessionService(this._auth);

  /// Records the login time LOCALLY only — no server call.
  ///
  /// Used the instant a phone user authenticates via OTP, partway through
  /// registration: they are signed in but their profile does not exist yet, so
  /// we must NOT create their profile yet (that would leave a half-built
  /// profile). [recordLogin] runs for real once the profile is saved.
  Future<void> markLocalLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_loginAtKey, DateTime.now().toIso8601String());
  }

  /// Call on every successful login (and after registration, which logs in).
  ///
  /// Tells the server (GET /me records the login time, which the admin uses to
  /// compute the active set) and records it locally so expiry still works with
  /// no network.
  Future<void> recordLogin() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await markLocalLogin();

    try {
      await ApiClient.instance.getJson('/me');
    } catch (e) {
      // Offline is fine: the local timestamp still drives auto-logout, and the
      // next successful call records the login on the server.
      debugPrint('Could not record login time remotely: $e');
    }
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_loginAtKey);
  }

  Future<DateTime?> loginAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_loginAtKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> signOut() async {
    await clearSession();
    await _auth.signOut();
  }
}
