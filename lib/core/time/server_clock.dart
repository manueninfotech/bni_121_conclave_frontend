import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final serverClockProvider = Provider<ServerClock>((ref) => ServerClock());

/// A clock corrected against the server.
///
/// Round boundaries are set by the SERVER (`currentRoundStartedAt`), but every
/// countdown and every gate was being evaluated against the DEVICE's clock. Any
/// drift between the two skews the timer — and, far worse, skews the gate: a
/// phone running slow would keep accepting attendance and referrals after the
/// round had actually closed, and a fast one would cut people off early.
///
/// So we measure the offset between server time and device time, and evaluate
/// everything against `now()` instead of `DateTime.now()`.
///
/// The offset is persisted, because the venue has no connectivity: a phone that
/// syncs once in the morning keeps using that correction all day, even if it
/// never reaches the server again.
class ServerClock {
  static const String _offsetKey = 'server_clock_offset_ms';

  Duration _offset = Duration.zero;
  bool _loaded = false;
  // Whether a real NTP correction (not just a restored persisted offset) has
  // happened this session. The first one snaps; later ones slew (see syncWith).
  bool _everCorrected = false;

  /// Server time minus device time. Zero until we've heard from the server.
  Duration get offset => _offset;

  /// Whether we've ever managed to correct against the server. When false the
  /// device clock is all we have.
  bool get isCorrected => _offset != Duration.zero || _loaded;

  /// The current time, corrected to the server's clock.
  DateTime now() => DateTime.now().add(_offset);

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_offsetKey);
    if (ms != null) _offset = Duration(milliseconds: ms);
    _loaded = true;
  }

  /// Corrects the offset using the NTP four-timestamp exchange.
  ///
  ///   offset = ((t1 - t0) + (t2 - t3)) / 2
  ///
  /// - [sentAt]      t0: device time when the request went out
  /// - [serverReceivedAt] t1: server time when it received the request
  /// - [serverSentAt]     t2: server time when it sent the response
  /// - [receivedAt]  t3: device time when the response arrived
  ///
  /// Why all four: with only one server timestamp you cannot tell network
  /// latency apart from server processing time. Our sync does real Firestore
  /// work — reads, a batch commit — which routinely takes seconds. Assuming the
  /// server stamped its clock at the midpoint of the round trip (as a naive
  /// implementation does) then overshoots by roughly half the processing time,
  /// which pushed the phone's clock SECONDS ahead of the server and made the
  /// countdown run fast.
  ///
  /// The (t2 - t3) term cancels the processing time out exactly, leaving only
  /// the (symmetric) network latency, which halves away.
  Future<void> syncWith({
    required DateTime sentAt,
    required DateTime serverReceivedAt,
    required DateTime serverSentAt,
    required DateTime receivedAt,
  }) async {
    final forward = serverReceivedAt.difference(sentAt); // t1 - t0
    final backward = serverSentAt.difference(receivedAt); // t2 - t3
    final newOffset = (forward + backward) ~/ 2;

    // Smooth the correction so a routine re-sync never makes the on-screen
    // countdown visibly jump or stall (#15). The RAW offset wobbles by a few
    // hundred ms each sync from network jitter; snapping to it every time (and,
    // now, on every sync-on-write) made the timer skip seconds. So we snap only
    // on the FIRST correction or on a genuinely large shift (device clock
    // actually changed), and otherwise ease toward the new offset in small
    // steps. The residual error stays well inside the server's clock slack, so
    // round gates are unaffected.
    const maxStepMs = 250;
    const snapThresholdMs = 5000;
    final deltaMs = (newOffset - _offset).inMilliseconds;
    if (!_everCorrected || deltaMs.abs() > snapThresholdMs) {
      _offset = newOffset;
    } else {
      _offset += Duration(milliseconds: deltaMs.clamp(-maxStepMs, maxStepMs));
    }
    _everCorrected = true;
    _loaded = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_offsetKey, _offset.inMilliseconds);

    final roundTrip = receivedAt.difference(sentAt) - serverSentAt.difference(serverReceivedAt);
    debugPrint(
      'Clock offset vs server: ${newOffset.inMilliseconds}ms '
      '(network round-trip ${roundTrip.inMilliseconds}ms)',
    );
  }
}
