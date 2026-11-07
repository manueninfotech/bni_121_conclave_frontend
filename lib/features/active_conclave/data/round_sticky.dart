import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/local_notifications.dart';
import '../../../core/time/server_clock.dart';
import '../../conclaves/data/conclave_repository.dart';
import '../../conclaves/domain/conclave_model.dart';
import '../domain/active_conclave_models.dart';
import 'active_conclave_repository.dart';

/// The conclave the signed-in member should have a live sticky for right now: a
/// conclave that is RUNNING and that they are registered in. Null when none.
final _liveStickyConclaveIdProvider = Provider<String?>((ref) {
  final all = ref.watch(conclavesStreamProvider).asData?.value ?? const [];
  final live = all.where(
    (c) => c.status == ConclaveStatus.running && c.isRegistered,
  );
  return live.isEmpty ? null : live.first.id;
});

/// Drives the ongoing Android "live round" notification from APP-LEVEL state, so
/// it persists and keeps updating while the member is on any screen or has the
/// phone pocketed — not only while the active-round screen happens to be on top.
/// (Owning it from the screen tore the sticky down the moment they navigated
/// away or backgrounded the app, which defeats the point of a sticky.)
///
/// Android only. iOS has no ongoing notification; a Live Activity is the iOS
/// answer and is deliberately out of scope here, so this is a no-op there.
///
/// Kept alive for the whole signed-in session by a single `ref.watch` in the
/// root app widget. Watching [activeRoundProvider] here also keeps that live
/// stream connected off-screen; it re-emits every second, and those emissions
/// are what advance the speaker/phase line below.
final roundStickyDriverProvider = Provider<void>((ref) {
  if (kIsWeb || !Platform.isAndroid) return;

  final conclaveId = ref.watch(_liveStickyConclaveIdProvider);
  if (conclaveId == null) {
    LocalNotifications.cancelRoundSticky();
    return;
  }

  final round = ref.watch(activeRoundProvider(conclaveId)).asData?.value.round;
  if (round == null) {
    LocalNotifications.cancelRoundSticky();
    return;
  }

  // While paused the clock is frozen: evaluate at the frozen instant and hold
  // the countdown steady (no chronometer) rather than letting it keep ticking.
  final paused = round.frozenAt != null;
  final now = round.frozenAt ?? ref.read(serverClockProvider).now();

  LocalNotifications.showRoundSticky(
    round: round.roundNumber,
    totalRounds: round.totalRounds,
    tableNumber: round.tableNumber,
    line: stickyLineFor(round, now),
    // remaining shrinks as `now` advances, so now+remaining is the FIXED
    // wall-clock end of this segment — a stable anchor the system counts down
    // to, and a stable signature so the notification isn't re-posted each tick.
    segmentEnd: now.add(round.remainingAt(now)),
    paused: paused,
  );
});

/// The one-line status shown on the sticky, mirroring the on-screen round
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
