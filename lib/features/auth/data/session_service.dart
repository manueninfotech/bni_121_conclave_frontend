import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sessionServiceProvider = Provider<SessionService>((ref) {
  return SessionService(FirebaseAuth.instance, FirebaseFirestore.instance);
});

/// Login sessions and what "active" means.
///
/// Spec: a user is **active** if they are logged in, and login expires after
/// `autoLogoutHours` (default 5, configurable). The active set is what the admin
/// snapshots when generating the schedule — 250 registered, 200 actually in the
/// room.
///
/// The expiry is enforced on the device (it signs itself out) AND is derivable
/// on the server from `users/{uid}.lastLoginAt`, so the admin can count active
/// users without the phones having to report in. That matters at a venue where
/// the phones may not be able to reach anything.
class SessionService {
  static const String _loginAtKey = 'session_login_at';
  static const int defaultAutoLogoutHours = 5;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  int? _cachedAutoLogoutHours;

  SessionService(this._auth, this._firestore);

  /// Records the login time LOCALLY only — no Firestore write.
  ///
  /// Used the instant a phone user authenticates via OTP, partway through
  /// registration: they are signed in but their profile does not exist yet, so
  /// we must NOT create a `users/{uid}` doc (that would leave a half-built
  /// profile). Writing the local timestamp is what stops [isExpired] from
  /// treating this brand-new session as expired and signing them out before they
  /// finish. [recordLogin] runs for real once the profile is saved.
  Future<void> markLocalLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_loginAtKey, DateTime.now().toIso8601String());
  }

  /// Call on every successful login (and after registration, which logs in).
  ///
  /// Writes the login time to Firestore so the admin can compute the active set,
  /// and locally so expiry still works with no network.
  Future<void> recordLogin() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await markLocalLogin();

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'lastLoginAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Offline is fine: the local timestamp still drives auto-logout, and
      // Firestore will flush this write when a connection returns.
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

  /// How long a login stays active. Read from `settings/app.autoLogoutHours`,
  /// cached, falling back to the default when unset or unreachable.
  Future<int> autoLogoutHours() async {
    if (_cachedAutoLogoutHours != null) return _cachedAutoLogoutHours!;
    try {
      final doc = await _firestore.collection('settings').doc('app').get();
      final hours = (doc.data()?['autoLogoutHours'] as num?)?.toInt();
      if (hours != null && hours > 0) {
        _cachedAutoLogoutHours = hours;
        return hours;
      }
    } catch (e) {
      debugPrint('Could not read autoLogoutHours, using default: $e');
    }
    _cachedAutoLogoutHours = defaultAutoLogoutHours;
    return defaultAutoLogoutHours;
  }

  /// Whether the current session has outlived its window.
  ///
  /// A logged-in user with no recorded login time is treated as expired: we
  /// cannot prove they are inside the window, and silently treating them as
  /// active would corrupt the admin's active count.
  Future<bool> isExpired() async {
    if (_auth.currentUser == null) return false;

    final start = await loginAt();
    if (start == null) return true;

    final hours = await autoLogoutHours();
    return DateTime.now().isAfter(start.add(Duration(hours: hours)));
  }

  /// Signs the user out if their session has expired. Returns true if it did.
  Future<bool> enforceExpiry() async {
    if (!await isExpired()) return false;
    await signOut();
    return true;
  }

  Future<void> signOut() async {
    await clearSession();
    await _auth.signOut();
  }
}
