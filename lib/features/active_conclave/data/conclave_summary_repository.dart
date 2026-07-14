import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/referral_models.dart';
import 'local_db.dart';
import 'referral_repository.dart';

/// This user's attendance for one round, and whether it reached the server.
class RoundAttendance {
  final int roundNumber;
  final bool isPresent;
  final bool synced;

  const RoundAttendance({
    required this.roundNumber,
    required this.isPresent,
    required this.synced,
  });
}

/// Everything shown after the conclave ends.
class ConclaveSummary {
  final List<RoundAttendance> attendance;
  final ReferralSummary referrals;

  const ConclaveSummary({required this.attendance, required this.referrals});

  int get roundsAttended => attendance.where((a) => a.isPresent).length;

  /// Records that have not reached the server yet — across both attendance and
  /// referrals given. This is the number the user actually cares about: "did my
  /// day survive?"
  int get pendingSyncCount =>
      attendance.where((a) => !a.synced).length + referrals.unsyncedGivenCount;

  bool get fullySynced => pendingSyncCount == 0;
}

final conclaveSummaryProvider =
    FutureProvider.family<ConclaveSummary, String>((ref, conclaveId) async {
  final db = ref.watch(localDbProvider);
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    return const ConclaveSummary(
      attendance: [],
      referrals: ReferralSummary.empty,
    );
  }

  final rows = await db.getMyAttendance(conclaveId: conclaveId, userId: uid);
  final attendance = rows
      .map((r) => RoundAttendance(
            roundNumber: (r['roundNumber'] as num).toInt(),
            isPresent: (r['isPresent'] as int) == 1,
            synced: (r['synced'] as int) == 1,
          ))
      .toList();

  final referrals =
      await ref.watch(referralRepositoryProvider).summaryFor(conclaveId);

  return ConclaveSummary(attendance: attendance, referrals: referrals);
});
