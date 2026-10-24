import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The last server response for a key, kept on the device per signed-in user.
///
/// This is what lets the app open with no connectivity at the venue: every
/// screen shows the cached copy first, then refreshes when the network allows.
/// (Firestore's offline cache did this before.) Scoped by uid so an account
/// switch on the same phone never shows the previous member's data.
class JsonCache {
  JsonCache._();

  static String _key(String name) => 'apicache:${FirebaseAuth.instance.currentUser?.uid ?? '-'}:$name';

  static Future<dynamic> read(String name) async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key(name));
      return raw == null ? null : jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String name, Object? value) async {
    try {
      await (await SharedPreferences.getInstance()).setString(_key(name), jsonEncode(value));
    } catch (_) {
      // A full or unavailable cache must never break a screen.
    }
  }
}
