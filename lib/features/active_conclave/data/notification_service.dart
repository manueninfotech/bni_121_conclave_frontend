import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(FirebaseMessaging.instance);
});

/// Round alerts.
///
/// The app subscribes to a per-conclave FCM topic, so the admin can tell the
/// whole room "round 3 has started" with one push.
///
/// This is deliberately only a NUDGE. The round state the app acts on comes from
/// the conclave document (and its offline cache) — never from a notification. A
/// phone that was in a pocket, out of signal, or had notifications denied still
/// shows the correct round the moment it is opened. Treating a push as the
/// source of truth would be exactly the wrong bet at a venue with no signal.
class NotificationService {
  final FirebaseMessaging _messaging;

  String? _subscribedConclaveId;

  NotificationService(this._messaging);

  static String topicFor(String conclaveId) => 'conclave_$conclaveId';

  /// Ask for permission and subscribe to this conclave's round alerts.
  Future<void> subscribe(String conclaveId) async {
    if (_subscribedConclaveId == conclaveId) return;

    try {
      await _messaging.requestPermission();

      // Leaving the previous conclave's topic stops stale alerts from an event
      // the user has finished with.
      final previous = _subscribedConclaveId;
      if (previous != null) {
        await _messaging.unsubscribeFromTopic(topicFor(previous));
      }

      await _messaging.subscribeToTopic(topicFor(conclaveId));
      _subscribedConclaveId = conclaveId;
      debugPrint('Subscribed to round alerts for $conclaveId');
    } catch (e) {
      // Denied permission, no Play Services, or offline. None of these should
      // stop the user taking part.
      debugPrint('Could not subscribe to round alerts: $e');
    }
  }

  Future<void> unsubscribe() async {
    final current = _subscribedConclaveId;
    if (current == null) return;
    try {
      await _messaging.unsubscribeFromTopic(topicFor(current));
    } catch (e) {
      debugPrint('Could not unsubscribe: $e');
    }
    _subscribedConclaveId = null;
  }

  /// Foreground messages. FCM does not show a system notification while the app
  /// is open, so the caller surfaces these in-app.
  Stream<RemoteMessage> get foregroundMessages => FirebaseMessaging.onMessage;
}
