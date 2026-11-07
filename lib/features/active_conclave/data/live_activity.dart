import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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

  /// Start the activity (first call) or update it (subsequent) with the current
  /// round state. [segmentEnd] is the wall-clock instant the countdown reaches
  /// zero; the widget runs a self-counting timer to it, so the countdown stays
  /// live even while the phone is pocketed.
  static Future<void> sync({
    required String conclaveName,
    required int round,
    required int totalRounds,
    required int tableNumber,
    required String line,
    required DateTime segmentEnd,
    required bool paused,
  }) async {
    if (kIsWeb || !Platform.isIOS) return;

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
    try {
      await _channel.invokeMethod<void>('end');
    } catch (_) {}
  }
}
