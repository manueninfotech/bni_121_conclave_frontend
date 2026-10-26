import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../api/api_client.dart';

/// Tells the backend whether the app is open on this phone, so the admin panel
/// can show a member as "Online now" or "Last seen …".
///
/// - While the app is in the foreground it checks in every 2 minutes.
/// - When it goes to the background it says so once.
/// - A phone that dies or loses signal simply stops checking in; the server
///   treats 5 minutes of silence as closed.
///
/// This replaces the old 5-hour auto-logout: members stay signed in (they
/// won't remember a password at the venue), and "present today" for seating
/// is worked out on the server from when the app was last open.
class PresenceService {
  PresenceService._();
  static final PresenceService instance = PresenceService._();

  static const Duration _interval = Duration(minutes: 2);
  Timer? _timer;

  bool get _signedIn => FirebaseAuth.instance.currentUser != null;

  /// App came to the foreground, or a member just signed in.
  void appOpened() {
    if (!_signedIn) return;
    _send('foreground');
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => _send('foreground'));
  }

  /// App went to the background or is closing.
  void appClosed() {
    _timer?.cancel();
    _timer = null;
    if (_signedIn) _send('background');
  }

  /// Signed out: stop checking in (nothing to report for nobody).
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _send(String state) async {
    try {
      await ApiClient.instance.send('POST', '/me/presence', {'state': state});
    } catch (e) {
      // Offline at the venue is normal; the next check-in catches up.
      debugPrint('Presence $state not sent: $e');
    }
  }
}
