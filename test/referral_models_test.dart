import 'package:flutter_test/flutter_test.dart';
import 'package:conclave_1_2_1/features/active_conclave/domain/referral_models.dart';

Referral ref({
  required String from,
  required String to,
  int round = 1,
  bool synced = true,
  String name = '',
}) {
  return Referral(
    id: '$from->$to@$round',
    conclaveId: 'c1',
    roundNumber: round,
    fromUserId: from,
    toUserId: to,
    otherName: name,
    otherBusinessName: '',
    notes: '',
    createdAt: DateTime(2026, 7, 14),
    synced: synced,
  );
}

void main() {
  group('buildReferralSummary', () {
    test('counts referrals given and received', () {
      final s = buildReferralSummary(
        given: [ref(from: 'me', to: 'a'), ref(from: 'me', to: 'b')],
        received: [ref(from: 'c', to: 'me')],
      );

      expect(s.givenCount, 2);
      expect(s.receivedCount, 1);
      expect(s.totalCount, 3);
    });

    // The spec's mutual case: "B can also give a referral to A — this case it
    // says both referred each other".
    test('detects a mutual pair when both directions exist', () {
      final s = buildReferralSummary(
        given: [ref(from: 'me', to: 'bhanu')],
        received: [ref(from: 'bhanu', to: 'me')],
      );

      expect(s.mutualCount, 1);
      expect(s.isMutualWith('bhanu'), isTrue);
    });

    test('a one-way referral is not mutual', () {
      final s = buildReferralSummary(
        given: [ref(from: 'me', to: 'bhanu')],
        received: [],
      );

      expect(s.mutualCount, 0);
      expect(s.isMutualWith('bhanu'), isFalse);
    });

    test('receiving without giving back is not mutual', () {
      final s = buildReferralSummary(
        given: [],
        received: [ref(from: 'bhanu', to: 'me')],
      );

      expect(s.receivedCount, 1);
      expect(s.mutualCount, 0);
    });

    test('counts each mutual counterparty once, across rounds', () {
      // Same two people exchanged referrals in different rounds. That is one
      // mutual relationship, not two.
      final s = buildReferralSummary(
        given: [ref(from: 'me', to: 'bhanu', round: 1)],
        received: [ref(from: 'bhanu', to: 'me', round: 3)],
      );

      expect(s.mutualCount, 1);
    });

    test('mixes mutual and one-way counterparties', () {
      final s = buildReferralSummary(
        given: [
          ref(from: 'me', to: 'bhanu'),
          ref(from: 'me', to: 'sravan'), // one-way out
        ],
        received: [
          ref(from: 'bhanu', to: 'me'), // mutual
          ref(from: 'kartheek', to: 'me'), // one-way in
        ],
      );

      expect(s.givenCount, 2);
      expect(s.receivedCount, 2);
      expect(s.mutualUids, {'bhanu'});
      expect(s.isMutualWith('sravan'), isFalse);
      expect(s.isMutualWith('kartheek'), isFalse);
    });

    test('A can give multiple referrals', () {
      final s = buildReferralSummary(
        given: [
          ref(from: 'me', to: 'a'),
          ref(from: 'me', to: 'b'),
          ref(from: 'me', to: 'c'),
        ],
        received: [],
      );
      expect(s.givenCount, 3);
    });

    // Drives the post-conclave "did my day survive?" banner.
    test('counts given referrals that have not reached the server', () {
      final s = buildReferralSummary(
        given: [
          ref(from: 'me', to: 'a', synced: true),
          ref(from: 'me', to: 'b', synced: false),
          ref(from: 'me', to: 'c', synced: false),
        ],
        received: [],
      );

      expect(s.unsyncedGivenCount, 2);
    });

    test('the empty summary is inert', () {
      const s = ReferralSummary.empty;
      expect(s.givenCount, 0);
      expect(s.receivedCount, 0);
      expect(s.mutualCount, 0);
      expect(s.unsyncedGivenCount, 0);
    });
  });
}
