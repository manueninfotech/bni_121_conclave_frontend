import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/local_notifications.dart';
import '../../../core/time/server_clock.dart';
import '../domain/active_conclave_models.dart';
import 'active_conclave_repository.dart';
import 'live_activity.dart';
import 'live_lock.dart';

/// Drives the ongoing "live round" surface from APP-LEVEL state, so it persists
/// and keeps updating while the member is on any screen or has the phone
/// pocketed — not only while the active-round screen happens to be on top.
///
/// One driver, both platforms:
///   • Android → an ongoing notification (LocalNotifications.showRoundSticky)
///   • iOS     → a Live Activity, lock screen + Dynamic Island (LiveActivity)
/// Both show the same thing: round · table · live countdown, the current speaker
/// during the round and the move instruction ("Move to Table N") between rounds.
///
/// Kept alive for the whole signed-in session by a single `ref.watch` in the
/// root app widget. Watching [activeRoundProvider] also keeps that live stream
/// connected off-screen; it re-emits every second, which advances the line here.
final roundStickyDriverProvider = Provider<void>((ref) {
  if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

  // The conclave the member has a live round in right now (shared with the
  // Rapido lock). Null when there's nothing live — clear the surface.
  final live = ref.watch(liveConclaveProvider);
  if (live == null) {
    _clear();
    return;
  }

  final round = ref.watch(activeRoundProvider(live.id)).value?.round;
  if (round == null) {
    _clear();
    return;
  }

  // While paused the clock is frozen: evaluate at the frozen instant and hold
  // the countdown steady rather than letting it keep ticking.
  final paused = round.frozenAt != null;
  final now = round.frozenAt ?? ref.read(serverClockProvider).now();
  final line = stickyLineFor(round, now);
  // remaining shrinks as `now` advances, so now+remaining is the FIXED
  // wall-clock end of this segment — a stable anchor both platforms count down
  // to, and a stable signature so the surface isn't re-pushed each tick.
  final segmentEnd = now.add(round.remainingAt(now));

  if (Platform.isAndroid) {
    LocalNotifications.showRoundSticky(
      round: round.roundNumber,
      totalRounds: round.totalRounds,
      tableNumber: round.tableNumber,
      line: line,
      segmentEnd: segmentEnd,
      paused: paused,
    );
  } else {
    LiveActivity.sync(
      conclaveName: live.name,
      round: round.roundNumber,
      totalRounds: round.totalRounds,
      tableNumber: round.tableNumber,
      line: line,
      segmentEnd: segmentEnd,
      paused: paused,
    );
  }
});

void _clear() {
  if (Platform.isAndroid) {
    LocalNotifications.cancelRoundSticky();
  } else if (Platform.isIOS) {
    LiveActivity.end();
  }
}

/// The one-line status shown on the live surface, mirroring the on-screen round
/// header: who's speaking during the round, and the move instruction (next
/// table) during the transition between rounds.
String stickyLineFor(ActiveRound round, DateTime now) {
  final phase = round.phaseAt(now);

  if (phase == RoundPhase.active) {
    final turn = round.currentTurnAt(now);
    if (turn != null) {
      final who = turn.speaker.isSelf
          ? (turn.kind == TurnKind.bio
              ? 'Your turn to speak'
              : 'Your turn to give a referral')
          : 'Now: ${turn.speaker.name}';
      return '$who · ${turn.kind == TurnKind.bio ? 'Bio' : 'Referrals'}';
    }
    if (now.isBefore(round.referralOpensAt)) return 'Referrals start soon';
    return 'Extra time · one-to-ones';
  }

  if (phase == RoundPhase.transition) {
    final next = round.nextTableNumber;
    if (next == null) return 'Round over';
    if (round.isCaptain || next == round.tableNumber) {
      return 'Stay at Table $next · your next group is arriving';
    }
    return 'Move to Table $next';
  }

  return 'Round ended';
}
