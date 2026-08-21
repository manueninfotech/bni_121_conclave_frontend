import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../active_conclave/domain/active_conclave_models.dart';
import '../../auth/data/auth_repository.dart';

/// Someone you shared a table with at a conclave, and in which rounds.
class MetPerson {
  final String uid;
  final String name;
  final String businessName;
  final String businessCategory;
  final String phone;
  final List<int> rounds;

  const MetPerson({
    required this.uid,
    required this.name,
    required this.businessName,
    required this.businessCategory,
    required this.phone,
    required this.rounds,
  });
}

/// Everyone the signed-in member sat with across all rounds of one conclave,
/// computed from the frozen schedule snapshot — no extra backend call.
final peopleMetProvider =
    FutureProvider.family<List<MetPerson>, String>((ref, conclaveId) async {
  ref.watch(authStateProvider.select((a) => a.asData?.value?.uid));
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return const [];

  final doc = await FirebaseFirestore.instance
      .collection('conclaves')
      .doc(conclaveId)
      .get();
  final data = doc.data();
  if (data == null) return const [];

  final schedule = ConclaveSchedule.fromConclaveDoc(data);
  final me = schedule?.participantForUid(uid);
  if (schedule == null || me == null) return const [];

  // participantId -> the rounds we shared a table.
  final metRounds = <int, Set<int>>{};
  for (final round in schedule.rounds) {
    final table = round.tableFor(me.participantId);
    if (table == null) continue;
    for (final occupant in table.occupantIds) {
      if (occupant == me.participantId) continue;
      (metRounds[occupant] ??= <int>{}).add(round.roundNumber);
    }
  }

  final people = <MetPerson>[];
  metRounds.forEach((pid, rounds) {
    final p = schedule.byParticipantId[pid];
    if (p == null) return;
    people.add(MetPerson(
      uid: p.uid,
      name: p.name,
      businessName: p.businessName,
      businessCategory: p.businessCategory,
      phone: p.phone,
      rounds: rounds.toList()..sort(),
    ));
  });

  people.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return people;
});
