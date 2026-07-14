import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  return ActiveConclaveRepository(FirebaseFirestore.instance, FirebaseAuth.instance);
});

/// Streams the live state of one conclave, resolved for the signed-in user.
///
/// Firestore's offline cache backs this stream, so once the conclave document
/// has been seen at least once the schedule keeps resolving with no network —
/// which is the whole point at a venue with 300+ people and no usable wifi.
final activeRoundProvider =
    StreamProvider.family<ActiveRoundState, String>((ref, conclaveId) {
  return ref.watch(activeConclaveRepositoryProvider).watchActiveRound(conclaveId);
});

class ActiveConclaveRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ActiveConclaveRepository(this._firestore, this._auth);

  Stream<ActiveRoundState> watchActiveRound(String conclaveId) {
    return _firestore
        .collection('conclaves')
        .doc(conclaveId)
        .snapshots()
        .map((doc) => _resolve(conclaveId, doc.data()));
  }

  ActiveRoundState _resolve(String conclaveId, Map<String, dynamic>? data) {
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

    final currentRound = (data['currentRound'] as num?)?.toInt() ?? 0;
    if (currentRound < 1) {
      return const ActiveRoundState.unavailable(ActiveRoundUnavailable.notStarted);
    }

    final startedAt = data['currentRoundStartedAt'];
    final startTime = startedAt is Timestamp
        ? startedAt.toDate()
        : (startedAt is String ? DateTime.tryParse(startedAt) : null);
    if (startTime == null) {
      return const ActiveRoundState.unavailable(ActiveRoundUnavailable.missingRoundStart);
    }

    final round = schedule.round(currentRound);
    final table = round?.tableFor(me.participantId);
    if (round == null || table == null) {
      return const ActiveRoundState.unavailable(ActiveRoundUnavailable.noTableThisRound);
    }

    final personsPerTable = (data['personsPerTable'] as num?)?.toInt() ?? 7;
    final totalRounds =
        (data['roundCount'] as num?)?.toInt() ?? schedule.rounds.length;

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
        startTime: startTime,
        timing: RoundTiming.forPersonsPerTable(personsPerTable),
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
