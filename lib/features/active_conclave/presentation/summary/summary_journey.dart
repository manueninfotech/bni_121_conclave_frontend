import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/live_conclave_source.dart';
import '../../../auth/data/auth_repository.dart';
import '../../domain/active_conclave_models.dart';

/// One round of the member's day: where they sat and with whom.
class RoundStop {
  final int roundNumber;
  final int tableNumber;
  final bool wasCaptain;
  final int tablemates;

  const RoundStop({
    required this.roundNumber,
    required this.tableNumber,
    required this.wasCaptain,
    required this.tablemates,
  });
}

/// The shape of the member's conclave, read from the frozen schedule (network
/// if possible, else the on-device copy) — no extra backend call.
class SummaryJourney {
  final String conclaveName;
  final List<RoundStop> rounds;

  /// Everyone they sat with, most-met first.
  final List<ScheduleParticipant> people;

  const SummaryJourney({
    required this.conclaveName,
    required this.rounds,
    required this.people,
  });

  static const empty =
      SummaryJourney(conclaveName: '', rounds: [], people: []);
}

final summaryJourneyProvider =
    FutureProvider.family<SummaryJourney, String>((ref, conclaveId) async {
  ref.watch(authStateProvider.select((a) => a.asData?.value?.uid));
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return SummaryJourney.empty;

  final data = await readConclaveDoc(conclaveId);
  if (data == null) return SummaryJourney.empty;
  final name = (data['name'] ?? '') as String;

  final schedule = ConclaveSchedule.fromConclaveDoc(data);
  final me = schedule?.participantForUid(uid);
  if (schedule == null || me == null) {
    return SummaryJourney(conclaveName: name, rounds: const [], people: const []);
  }

  final stops = <RoundStop>[];
  final timesMet = <int, int>{};
  for (final round in schedule.rounds) {
    final table = round.tableFor(me.participantId);
    if (table == null) continue;
    final others = table.occupantIds.where((id) => id != me.participantId);
    for (final o in others) {
      timesMet[o] = (timesMet[o] ?? 0) + 1;
    }
    stops.add(RoundStop(
      roundNumber: round.roundNumber,
      tableNumber: table.tableNumber,
      wasCaptain: table.captainId == me.participantId,
      tablemates: others.length,
    ));
  }
  stops.sort((a, b) => a.roundNumber.compareTo(b.roundNumber));

  final ids = timesMet.keys.toList()
    ..sort((a, b) => timesMet[b]!.compareTo(timesMet[a]!));
  final people = [
    for (final id in ids)
      if (schedule.byParticipantId[id] != null) schedule.byParticipantId[id]!,
  ];

  return SummaryJourney(conclaveName: name, rounds: stops, people: people);
});
