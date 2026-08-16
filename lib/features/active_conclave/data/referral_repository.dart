import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../domain/active_conclave_models.dart';
import '../domain/referral_models.dart';
import 'local_db.dart';

final referralRepositoryProvider = Provider<ReferralRepository>((ref) {
  return ReferralRepository(
    ref.watch(localDbProvider),
    FirebaseAuth.instance,
    FirebaseFirestore.instance,
  );
});

/// The signed-in user's referrals for one conclave, read from the local store so
/// it works with no network.
final referralSummaryProvider =
    FutureProvider.family<ReferralSummary, String>((ref, conclaveId) {
  // Re-fetch when the signed-in user changes — the summary is scoped to their
  // uid, so an account switch must not surface the previous member's referrals.
  ref.watch(authStateProvider.select((a) => a.asData?.value?.uid));
  return ref.watch(referralRepositoryProvider).summaryFor(conclaveId);
});

class ReferralRepository {
  final LocalDatabase _db;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  ReferralRepository(this._db, this._auth, this._firestore);

  Future<ReferralSummary> summaryFor(String conclaveId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return ReferralSummary.empty;

    final givenRows = await _db.getGivenReferrals(
      conclaveId: conclaveId,
      fromUserId: uid,
    );
    final receivedRows = await _db.getReceivedReferrals(
      conclaveId: conclaveId,
      toUserId: uid,
    );

    // Referrals given before the recipient's name was stored locally have only a
    // uid. The conclave's participant snapshot still knows who that is, and it's
    // served from Firestore's offline cache, so this works without a network.
    final roster = await _rosterFor(conclaveId);

    return buildReferralSummary(
      given: givenRows.map((r) => _givenFromRow(r, roster)).toList(),
      received: receivedRows.map(_receivedFromRow).toList(),
    );
  }

  /// uid -> participant, from `conclaves/{id}.participants`.
  Future<Map<String, ScheduleParticipant>> _rosterFor(String conclaveId) async {
    try {
      final doc = await _firestore.collection('conclaves').doc(conclaveId).get();
      final data = doc.data();
      if (data == null) return const {};

      final schedule = ConclaveSchedule.fromConclaveDoc(data);
      if (schedule == null) return const {};

      return {
        for (final p in schedule.byParticipantId.values)
          if (p.uid.isNotEmpty) p.uid: p,
      };
    } catch (_) {
      // No cache, no network: fall back to showing the uid rather than failing.
      return const {};
    }
  }

  Referral _givenFromRow(
    Map<String, dynamic> r,
    Map<String, ScheduleParticipant> roster,
  ) {
    final toUserId = r['toUserId'] as String;

    // Prefer the name captured when the referral was given; fall back to the
    // roster for referrals recorded before that was stored.
    var name = (r['toName'] ?? '') as String;
    var business = (r['toBusinessName'] ?? '') as String;
    if (name.isEmpty) {
      final p = roster[toUserId];
      name = p?.name ?? '';
      business = p?.businessName ?? '';
    }

    return Referral(
      id: r['id'] as String,
      conclaveId: r['conclaveId'] as String,
      roundNumber: (r['roundNumber'] as num).toInt(),
      fromUserId: r['fromUserId'] as String,
      toUserId: toUserId,
      otherName: name,
      otherBusinessName: business,
      notes: (r['notes'] ?? '') as String,
      createdAt: DateTime.tryParse((r['timestamp'] ?? '') as String) ?? DateTime.now(),
      synced: (r['synced'] as int) == 1,
    );
  }

  /// A referral someone gave to this user. Came down from the server, which
  /// joined in the giver's name and business.
  Referral _receivedFromRow(Map<String, dynamic> r) {
    return Referral(
      id: r['id'] as String,
      conclaveId: r['conclaveId'] as String,
      roundNumber: (r['roundNumber'] as num).toInt(),
      fromUserId: r['fromUserId'] as String,
      toUserId: r['toUserId'] as String,
      otherName: (r['fromName'] ?? '') as String,
      otherBusinessName: (r['fromBusinessName'] ?? '') as String,
      notes: (r['notes'] ?? '') as String,
      createdAt: DateTime.tryParse((r['timestamp'] ?? '') as String) ?? DateTime.now(),
      // Received referrals came FROM the server, so they are synced by definition.
      synced: true,
    );
  }
}
