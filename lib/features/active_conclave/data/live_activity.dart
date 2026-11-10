import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api_client.dart';

/// The iOS equivalent of the Android ongoing "sticky" notification: a live-round
/// Live Activity (lock screen + Dynamic Island). Driven from the same app-level
/// place (roundStickyDriverProvider) so one driver keeps both platforms in step.
///
/// All calls are best-effort and never throw — a Live Activity is a convenience,
/// and ActivityKit can refuse (disabled by the user, app not foregrounded). The
/// native side starts the activity on the first [sync] and updates it thereafter.
class LiveActivity {
  LiveActivity._();

  static const _channel = MethodChannel('conclave/live_activity');

  /// What is currently on the activity, so the per-second driver only crosses
  /// the platform channel when the visible content actually changes.
  static String? _sig;
  static bool _active = false;

  /// The conclave the card belongs to, for registering its push token.
  static String? _conclaveId;
  static String? _registeredToken;
  static bool _listening = false;

  /// v2: iOS issues the activity a push token; register it with the server so
  /// round changes are pushed to the card while the app is suspended.
  static void _listen() {
    if (_listening) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'pushToken' && call.arguments is String) {
        await _register(call.arguments as String);
      }
    });
  }

  static Future<void> _register(String pushToken) async {
    final id = _conclaveId;
    if (id == null || pushToken == _registeredToken) return;
    try {
      final fcm = await FirebaseMessaging.instance.getToken();
      if (fcm == null) return;
      await ApiClient.instance.send('PUT', '/conclaves/$id/live-activity', {
        'pushToken': pushToken,
        'fcmToken': fcm,
      });
      _registeredToken = pushToken;
    } catch (e) {
      // Offline or refused: the next token refresh (or relaunch) retries.
      debugPrint('Live Activity token registration failed: $e');
    }
  }

  /// Start the activity (first call) or update it (subsequent) with the current
  /// round state. [segmentEnd] is the wall-clock instant the countdown reaches
  /// zero; the widget runs a self-counting timer to it, so the countdown stays
  /// live even while the phone is pocketed.
  static Future<void> sync({
    required String conclaveId,
    required String conclaveName,
    required int round,
    required int totalRounds,
    required int tableNumber,
    required String line,
    required DateTime segmentEnd,
    required bool paused,
  }) async {
    if (kIsWeb || !Platform.isIOS) return;
    _listen();
    if (_conclaveId != conclaveId) {
      _conclaveId = conclaveId;
      _registeredToken = null;
    }

    final sig = '$round|$totalRounds|$tableNumber|$line|$paused|'
        '${segmentEnd.millisecondsSinceEpoch ~/ 1000}';
    if (sig == _sig) return;
    _sig = sig;

    try {
      await _channel.invokeMethod<void>('startOrUpdate', {
        'conclaveName': conclaveName,
        'round': round,
        'totalRounds': totalRounds,
        'tableNumber': tableNumber,
        'line': line,
        'segmentEndEpoch': segmentEnd.millisecondsSinceEpoch / 1000.0,
        'paused': paused,
      });
      _active = true;
    } catch (_) {
      // Refused or unavailable; a later sync retries.
    }
  }

  /// End the activity when the round is over. Cheap to call repeatedly — it
  /// no-ops once already ended, so the idle driver doesn't spam the channel.
  static Future<void> end() async {
    if (kIsWeb || !Platform.isIOS) return;
    if (!_active && _sig == null) return;
    _sig = null;
    _active = false;
    final id = _conclaveId;
    _registeredToken = null;
    try {
      await _channel.invokeMethod<void>('end');
    } catch (_) {}
    // Stop server pushes to a card that no longer exists (best-effort).
    if (id != null) {
      try {
        await ApiClient.instance.send('DELETE', '/conclaves/$id/live-activity');
      } catch (_) {}
    }
  }
}
