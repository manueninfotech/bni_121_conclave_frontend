/// Domain models for a running conclave.
///
/// These mirror exactly what the backend writes to the conclave document:
///   schedule.rounds[].tables[] -> { tableNumber, captainId, memberIds[] }
///   participants[]             -> engine Participant + _originalUid
///
/// The engine works in dense integer ids (`participantId`); Firestore and
/// Firebase Auth work in string uids. Every crossing between those two worlds
/// goes through [ConclaveSchedule].
library;

/// A person in the conclave snapshot, as stored in `conclaves/{id}.participants`.
class ScheduleParticipant {
  /// Dense engine id (1..A). Used inside the schedule.
  final int participantId;

  /// Firestore/Auth uid. Used for attendance, referrals and identity.
  final String uid;

  final String name;
  final String phone;
  final String businessName;
  final String businessCategory;

  const ScheduleParticipant({
    required this.participantId,
    required this.uid,
    required this.name,
    required this.phone,
    required this.businessName,
    required this.businessCategory,
  });

  factory ScheduleParticipant.fromMap(Map<String, dynamic> m) {
    return ScheduleParticipant(
      participantId: (m['id'] as num).toInt(),
      uid: (m['_originalUid'] ?? '') as String,
      name: (m['name'] ?? '') as String,
      phone: (m['phone'] ?? '') as String,
      businessName: (m['businessName'] ?? '') as String,
      businessCategory: (m['businessCategory'] ?? '') as String,
    );
  }
}

/// One table in one round.
class ScheduleTable {
  final int tableNumber;
  final int captainId;
  final List<int> memberIds;

  const ScheduleTable({
    required this.tableNumber,
    required this.captainId,
    required this.memberIds,
  });

  /// Captain first, then rotating members — matches the engine's `occupantsOf`.
  List<int> get occupantIds => [captainId, ...memberIds];

  bool seats(int participantId) =>
      captainId == participantId || memberIds.contains(participantId);

  factory ScheduleTable.fromMap(Map<String, dynamic> m) {
    return ScheduleTable(
      tableNumber: (m['tableNumber'] as num).toInt(),
      captainId: (m['captainId'] as num).toInt(),
      memberIds: ((m['memberIds'] as List?) ?? const [])
          .map((e) => (e as num).toInt())
          .toList(),
    );
  }
}

/// One round: every participant seated at exactly one table.
class ScheduleRound {
  final int roundNumber;
  final List<ScheduleTable> tables;

  const ScheduleRound({required this.roundNumber, required this.tables});

  /// The table seating [participantId], or null if they aren't in this round.
  ScheduleTable? tableFor(int participantId) {
    for (final t in tables) {
      if (t.seats(participantId)) return t;
    }
    return null;
  }

  factory ScheduleRound.fromMap(Map<String, dynamic> m) {
    return ScheduleRound(
      roundNumber: (m['roundNumber'] as num).toInt(),
      tables: ((m['tables'] as List?) ?? const [])
          .map((e) => ScheduleTable.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

/// The full precomputed schedule plus the participant snapshot it refers to.
class ConclaveSchedule {
  final int tableCount;
  final List<ScheduleRound> rounds;
  final Map<int, ScheduleParticipant> byParticipantId;
  final Map<String, int> participantIdByUid;

  const ConclaveSchedule({
    required this.tableCount,
    required this.rounds,
    required this.byParticipantId,
    required this.participantIdByUid,
  });

  ScheduleRound? round(int roundNumber) {
    for (final r in rounds) {
      if (r.roundNumber == roundNumber) return r;
    }
    return null;
  }

  ScheduleParticipant? participantForUid(String uid) {
    final pid = participantIdByUid[uid];
    return pid == null ? null : byParticipantId[pid];
  }

  /// Builds from the raw `conclaves/{id}` document. Returns null when the admin
  /// has not generated a schedule yet, so callers can tell "not ready" apart
  /// from a parse failure.
  static ConclaveSchedule? fromConclaveDoc(Map<String, dynamic> data) {
    final rawSchedule = data['schedule'];
    final rawParticipants = data['participants'];
    if (rawSchedule is! Map || rawParticipants is! List) return null;

    final byParticipantId = <int, ScheduleParticipant>{};
    final participantIdByUid = <String, int>{};
    for (final p in rawParticipants) {
      final parsed = ScheduleParticipant.fromMap(Map<String, dynamic>.from(p as Map));
      byParticipantId[parsed.participantId] = parsed;
      if (parsed.uid.isNotEmpty) {
        participantIdByUid[parsed.uid] = parsed.participantId;
      }
    }

    final rounds = ((rawSchedule['rounds'] as List?) ?? const [])
        .map((e) => ScheduleRound.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    return ConclaveSchedule(
      tableCount: (rawSchedule['tableCount'] as num?)?.toInt() ?? 0,
      rounds: rounds,
      byParticipantId: byParticipantId,
      participantIdByUid: participantIdByUid,
    );
  }
}

/// How long a round runs, derived from the table size.
///
/// Spec: a round occupies a fixed 15-minute block. The active (talking) portion
/// is 1.5 minutes per person at the table; whatever is left of the block is the
/// transition window for members to walk to their next table.
///   P = 8 -> 12 min active + 3 min transition
///   P = 6 ->  9 min active + 6 min transition
class RoundTiming {
  static const Duration block = Duration(minutes: 15);
  static const Duration perPerson = Duration(seconds: 90); // 1.5 min

  final Duration active;
  final Duration transition;

  const RoundTiming({required this.active, required this.transition});

  Duration get total => active + transition;

  factory RoundTiming.forPersonsPerTable(int personsPerTable) {
    final p = personsPerTable < 1 ? 1 : personsPerTable;
    final active = perPerson * p;
    // A table big enough to consume the whole block leaves no transition time.
    // Clamp rather than produce a negative duration.
    final transition = active >= block ? Duration.zero : block - active;
    return RoundTiming(active: active, transition: transition);
  }
}

/// Which phase of the round we are in right now.
enum RoundPhase {
  /// Members are at the table; attendance and referrals are open.
  active,

  /// Talking time is over and members are walking. Actions are closed.
  transition,

  /// The block elapsed and the admin has not started the next round.
  ended,
}

/// A person seated at the current user's table this round.
class TableSeat {
  final String userId; // Firestore uid
  final int participantId;
  final String name;
  final String businessName;
  final String category;
  final bool isCaptain;

  /// True when this seat is the signed-in user.
  final bool isSelf;

  const TableSeat({
    required this.userId,
    required this.participantId,
    required this.name,
    required this.businessName,
    required this.category,
    required this.isCaptain,
    required this.isSelf,
  });
}

/// Everything the active-round screen needs, resolved for the signed-in user.
class ActiveRound {
  final String conclaveId;
  final int roundNumber;
  final int totalRounds;
  final int tableNumber;

  /// When the admin started this round.
  final DateTime startTime;

  final RoundTiming timing;
  final List<TableSeat> seats;

  /// True when the signed-in user anchors this table.
  final bool isCaptain;

  final String currentUserId;
  final int currentParticipantId;

  const ActiveRound({
    required this.conclaveId,
    required this.roundNumber,
    required this.totalRounds,
    required this.tableNumber,
    required this.startTime,
    required this.timing,
    required this.seats,
    required this.isCaptain,
    required this.currentUserId,
    required this.currentParticipantId,
  });

  DateTime get activeEndsAt => startTime.add(timing.active);
  DateTime get transitionEndsAt => activeEndsAt.add(timing.transition);

  RoundPhase phaseAt(DateTime now) {
    if (now.isBefore(activeEndsAt)) return RoundPhase.active;
    if (now.isBefore(transitionEndsAt)) return RoundPhase.transition;
    return RoundPhase.ended;
  }

  /// Time left in the current phase; zero once the block has elapsed.
  Duration remainingAt(DateTime now) {
    switch (phaseAt(now)) {
      case RoundPhase.active:
        return activeEndsAt.difference(now);
      case RoundPhase.transition:
        return transitionEndsAt.difference(now);
      case RoundPhase.ended:
        return Duration.zero;
    }
  }

  /// Attendance and referrals are only accepted while the table is in session.
  bool canRecordAt(DateTime now) => phaseAt(now) == RoundPhase.active;

  /// The other people at the table — the ones the user can refer.
  List<TableSeat> get others => seats.where((s) => !s.isSelf).toList();
}
