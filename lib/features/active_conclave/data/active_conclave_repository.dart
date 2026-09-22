import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/server_clock.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/active_conclave_models.dart';

/// Why the active round could not be resolved. The screen renders each of these
/// differently, so they are modelled rather than collapsed into a null.
enum ActiveRoundUnavailable {
  /// Admin has not generated the schedule yet.
  scheduleNotReady,

  /// Admin has generated a schedule but has not started round 1.
  notStarted,

  /// The signed-in user is not in this conclave's participant snapshot — they
  /// registered after the schedule was generated, or were never registered.
  notInSnapshot,

  /// The schedule exists but seats nobody with this participant id this round.
  /// Indicates a corrupt schedule; surfaced rather than silently swallowed.
  noTableThisRound,

  /// Round is running but the backend never recorded a start time, so the
  /// countdown has no origin.
  missingRoundStart,

  /// Conclave has finished all rounds.
  completed,

  /// The admin called it off. Distinct from [completed]: nothing was finished,
  /// and there is no summary to look at.
  cancelled,
}

/// Either a resolved [ActiveRound] or the reason there isn't one.
class ActiveRoundState {
  final ActiveRound? round;
  final ActiveRoundUnavailable? unavailable;

  const ActiveRoundState.ready(this.round) : unavailable = null;
  const ActiveRoundState.unavailable(this.unavailable) : round = null;

  bool get isReady => round != null;
}

final activeConclaveRepositoryProvider = Provider<ActiveConclaveRepository>((ref) {
  // Rounds now advance on the clock, so resolving the live round needs a
  // server-corrected 'now' — never the raw device clock, which can be minutes
  // off and would put two phones on different rounds.
  return ActiveConclaveRepository(
    FirebaseFirestore.instance,
    FirebaseAuth.instance,
    () => ref.read(serverClockProvider).now(),
  );
});

/// Streams the live state of one conclave, resolved for the signed-in user.
///
/// Firestore's offline cache backs this stream, so once the conclave document
/// has been seen at least once the schedule keeps resolving with no network —
/// which is the whole point at a venue with 300+ people and no usable wifi.
final activeRoundProvider =
    StreamProvider.family<ActiveRoundState, String>((ref, conclaveId) {
  // Re-resolve when the signed-in user changes: the round is resolved FOR a
  // specific uid (their table, seat, captain role), so an account switch with
  // no app restart must not keep showing the previous member's seat.
  ref.watch(authStateProvider.select((a) => a.asData?.value?.uid));
  return ref.watch(activeConclaveRepositoryProvider).watchActiveRound(conclaveId);
});

class ActiveConclaveRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final DateTime Function() _now;

  ActiveConclaveRepository(this._firestore, this._auth, this._now);

  Stream<ActiveRoundState> watchActiveRound(String conclaveId) {
    // Two things move the live round: the conclave document changing (schedule
    // generated, round 1 started, cancelled) AND the clock crossing a round
    // boundary. The document does NOT change when a round auto-advances, so a
    // snapshot-only stream would freeze on a finished round — merge in a ticker
    // that re-resolves against the current time.
    final controller = StreamController<ActiveRoundState>();
    Map<String, dynamic>? latest;
    var seenDoc = false;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? sub;
    Timer? ticker;

    void emit() {
      if (!seenDoc || controller.isClosed) return;
      controller.add(_resolve(conclaveId, latest, _now()));
    }

    controller.onListen = () {
      sub = _firestore
          .collection('conclaves')
          .doc(conclaveId)
          .snapshots()
          .listen((doc) {
        latest = doc.data();
        seenDoc = true;
        emit();
      }, onError: controller.addError);
      ticker = Timer.periodic(const Duration(seconds: 1), (_) => emit());
    };
    controller.onCancel = () async {
      ticker?.cancel();
      await sub?.cancel();
    };

    return controller.stream;
  }

  ActiveRoundState _resolve(
      String conclaveId, Map<String, dynamic>? data, DateTime now) {
    if (data == null) {
      return const ActiveRoundState.unavailable(ActiveRoundUnavailable.scheduleNotReady);
    }

    final schedule = ConclaveSchedule.fromConclaveDoc(data);
    if (schedule == null) {
      return const ActiveRoundState.unavailable(ActiveRoundUnavailable.scheduleNotReady);
    }

    final uid = _auth.currentUser?.uid;
    final me = uid == null ? null : schedule.participantForUid(uid);
    if (me == null) {
      return const ActiveRoundState.unavailable(ActiveRoundUnavailable.notInSnapshot);
    }

    final status = (data['status'] ?? '') as String;
    if (status == 'completed') {
      return const ActiveRoundState.unavailable(ActiveRoundUnavailable.completed);
    }

    // A cancelled conclave was falling straight through this check: its
    // currentRound is still 1, so the round screen kept running and members
    // carried on marking attendance and giving referrals at an event that no
    // longer exists. The screen has to stop the moment the admin pulls the plug.
    if (status == 'cancelled') {
      return const ActiveRoundState.unavailable(ActiveRoundUnavailable.cancelled);
    }

    // Anything that is not actively running has no round to show. Listing the
    // states we accept, rather than the ones we reject, means a status added
    // later fails closed instead of silently rendering a stale round.
    if (status != 'running') {
      return const ActiveRoundState.unavailable(ActiveRoundUnavailable.notStarted);
    }

    // The anchor is when the admin started the conclave (round 1). Rounds then
    // auto-advance from here by the clock — no per-round admin action — so we
    // DERIVE the live round rather than trust a stored counter that stops moving
    // after round 1.
    final storedRound = (data['currentRound'] as num?)?.toInt() ?? 0;
    if (storedRound < 1) {
      return const ActiveRoundState.unavailable(ActiveRoundUnavailable.notStarted);
    }
    final startedAt = data['currentRoundStartedAt'];
    final anchor = startedAt is Timestamp
        ? startedAt.toDate()
        : (startedAt is String ? DateTime.tryParse(startedAt) : null);
    if (anchor == null) {
      return const ActiveRoundState.unavailable(ActiveRoundUnavailable.missingRoundStart);
    }

    final personsPerTable = (data['personsPerTable'] as num?)?.toInt() ?? 7;
    final totalRounds =
        (data['roundCount'] as num?)?.toInt() ?? schedule.rounds.length;
    // Optional per-conclave override: when the admin pins a fixed round length,
    // honour it; otherwise the round auto-scales with the table size.
    final fixedBlockMinutes = (data['roundBlockMinutes'] as num?)?.toInt();
    final timing = RoundTiming.forPersonsPerTable(
      personsPerTable,
      fixedBlockMinutes: fixedBlockMinutes,
    );

    // Auto-advance from whatever round was last STARTED (its start time is the
    // anchor): the current round is that round plus however many whole
    // round-lengths have since elapsed. Basing it on storedRound rather than
    // assuming round 1 keeps the app correct even if an admin starts a later
    // round by hand. Once we're past the last round, the conclave is over.
    final roundMs = timing.total.inMilliseconds;
    final elapsedMs = now.difference(anchor).inMilliseconds;
    var currentRound =
        roundMs <= 0 ? storedRound : storedRound + (elapsedMs ~/ roundMs);
    if (currentRound < storedRound) currentRound = storedRound;
    if (currentRound > totalRounds) {
      return const ActiveRoundState.unavailable(ActiveRoundUnavailable.completed);
    }
    final roundStart = anchor
        .add(Duration(milliseconds: roundMs * (currentRound - storedRound)));

    final round = schedule.round(currentRound);
    final table = round?.tableFor(me.participantId);
    if (round == null || table == null) {
      return const ActiveRoundState.unavailable(ActiveRoundUnavailable.noTableThisRound);
    }

    // Occupants come back captain-first, which is the order we want on screen.
    final seats = <TableSeat>[];
    for (final pid in table.occupantIds) {
      final p = schedule.byParticipantId[pid];
      if (p == null) continue; // schedule references someone not in the snapshot
      seats.add(
        TableSeat(
          userId: p.uid,
          participantId: p.participantId,
          name: p.name,
          businessName: p.businessName,
          category: p.businessCategory,
          isCaptain: pid == table.captainId,
          isSelf: pid == me.participantId,
        ),
      );
    }

    return ActiveRoundState.ready(
      ActiveRound(
        conclaveId: conclaveId,
        roundNumber: currentRound,
        totalRounds: totalRounds,
        tableNumber: table.tableNumber,
        startTime: roundStart,
        timing: timing,
        seats: seats,
        // Role comes from the schedule itself, not from a hardcoded flag: the
        // user is a captain exactly when they anchor this table.
        isCaptain: table.captainId == me.participantId,
        currentUserId: me.uid,
        currentParticipantId: me.participantId,
      ),
    );
  }
}
