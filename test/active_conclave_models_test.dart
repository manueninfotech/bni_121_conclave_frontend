import 'package:flutter_test/flutter_test.dart';
import 'package:conclave_1_2_1/features/active_conclave/domain/active_conclave_models.dart';

/// Mirrors the shape the backend writes to `conclaves/{id}`.
Map<String, dynamic> conclaveDoc({
  int personsPerTable = 7,
  List<Map<String, dynamic>>? participants,
  List<Map<String, dynamic>>? rounds,
}) {
  return {
    'personsPerTable': personsPerTable,
    'roundCount': 2,
    'participants': participants ??
        [
          {
            'id': 1,
            '_originalUid': 'uid-captain',
            'name': 'Ganesh',
            'phone': '111',
            'businessName': 'Ganesh Software',
            'businessCategory': 'Software Development',
          },
          {
            'id': 2,
            '_originalUid': 'uid-member',
            'name': 'Sravan',
            'phone': '222',
            'businessName': 'Sravan Boutique',
            'businessCategory': 'Boutique',
          },
          {
            'id': 3,
            '_originalUid': 'uid-other',
            'name': 'Kartheek',
            'phone': '333',
            'businessName': 'Kartheek Restaurant',
            'businessCategory': 'Restaurant',
          },
        ],
    'schedule': {
      'tableCount': 2,
      'rounds': rounds ??
          [
            {
              'roundNumber': 1,
              'tables': [
                {'tableNumber': 1, 'captainId': 1, 'memberIds': [2]},
                {'tableNumber': 2, 'captainId': 3, 'memberIds': <int>[]},
              ],
            },
          ],
    },
  };
}

void main() {
  group('RoundTiming', () {
    // The two worked examples from the spec.
    test('P=8 gives 12 min active + 3 min transition', () {
      final t = RoundTiming.forPersonsPerTable(8);
      expect(t.active, const Duration(minutes: 12));
      expect(t.transition, const Duration(minutes: 3));
      expect(t.total, RoundTiming.block);
    });

    test('P=6 gives 9 min active + 6 min transition', () {
      final t = RoundTiming.forPersonsPerTable(6);
      expect(t.active, const Duration(minutes: 9));
      expect(t.transition, const Duration(minutes: 6));
      expect(t.total, RoundTiming.block);
    });

    test('active time is 1.5 minutes per person', () {
      expect(RoundTiming.forPersonsPerTable(7).active, const Duration(minutes: 10, seconds: 30));
    });

    test('a table that fills the whole block leaves no transition time', () {
      // P=10 -> 15 min of talking, which consumes the entire block.
      final t = RoundTiming.forPersonsPerTable(10);
      expect(t.active, RoundTiming.block);
      expect(t.transition, Duration.zero);
    });

    test('an oversized table clamps transition to zero rather than going negative', () {
      final t = RoundTiming.forPersonsPerTable(20);
      expect(t.transition, Duration.zero);
      expect(t.transition.isNegative, isFalse);
    });
  });

  group('ConclaveSchedule parsing', () {
    test('maps uids to dense engine participant ids', () {
      final s = ConclaveSchedule.fromConclaveDoc(conclaveDoc())!;

      expect(s.tableCount, 2);
      expect(s.participantIdByUid['uid-captain'], 1);
      expect(s.participantForUid('uid-member')!.name, 'Sravan');
      expect(s.participantForUid('nobody'), isNull);
    });

    test('returns null when the admin has not generated a schedule yet', () {
      expect(ConclaveSchedule.fromConclaveDoc({'status': 'registrationOpen'}), isNull);
    });

    test('finds the table seating a participant, captain or member', () {
      final round = ConclaveSchedule.fromConclaveDoc(conclaveDoc())!.round(1)!;

      expect(round.tableFor(1)!.tableNumber, 1); // captain of table 1
      expect(round.tableFor(2)!.tableNumber, 1); // member at table 1
      expect(round.tableFor(3)!.tableNumber, 2); // captain of table 2
      expect(round.tableFor(99), isNull); // not seated
    });

    test('occupants are captain-first', () {
      final table = ConclaveSchedule.fromConclaveDoc(conclaveDoc())!.round(1)!.tables.first;
      expect(table.occupantIds, [1, 2]);
    });

    test('round() returns null for a round that does not exist', () {
      expect(ConclaveSchedule.fromConclaveDoc(conclaveDoc())!.round(9), isNull);
    });
  });

  group('ActiveRound phases and gating', () {
    // P=8 -> 12 min active, 3 min transition.
    final start = DateTime(2026, 7, 14, 10, 0, 0);
    final round = ActiveRound(
      conclaveId: 'c1',
      roundNumber: 1,
      totalRounds: 6,
      tableNumber: 4,
      startTime: start,
      timing: RoundTiming.forPersonsPerTable(8),
      seats: const [
        TableSeat(
          userId: 'uid-captain',
          participantId: 1,
          name: 'Ganesh',
          businessName: 'Ganesh Software',
          category: 'Software Development',
          isCaptain: true,
          isSelf: false,
        ),
        TableSeat(
          userId: 'uid-member',
          participantId: 2,
          name: 'Sravan',
          businessName: 'Sravan Boutique',
          category: 'Boutique',
          isCaptain: false,
          isSelf: true,
        ),
      ],
      isCaptain: false,
      currentUserId: 'uid-member',
      currentParticipantId: 2,
    );

    test('is active during the talking window', () {
      expect(round.phaseAt(start.add(const Duration(minutes: 5))), RoundPhase.active);
      expect(round.canRecordAt(start.add(const Duration(minutes: 5))), isTrue);
    });

    test('switches to transition once talking time expires', () {
      final t = start.add(const Duration(minutes: 13));
      expect(round.phaseAt(t), RoundPhase.transition);
      // Attendance and referrals must be closed outside the active window.
      expect(round.canRecordAt(t), isFalse);
    });

    test('ends after the full 15 minute block', () {
      final t = start.add(const Duration(minutes: 16));
      expect(round.phaseAt(t), RoundPhase.ended);
      expect(round.canRecordAt(t), isFalse);
      expect(round.remainingAt(t), Duration.zero);
    });

    test('the active/transition boundary is exactly at 12 minutes', () {
      expect(round.phaseAt(start.add(const Duration(minutes: 12))), RoundPhase.transition);
      expect(
        round.phaseAt(start.add(const Duration(minutes: 11, seconds: 59))),
        RoundPhase.active,
      );
    });

    test('counts down within the active phase', () {
      expect(
        round.remainingAt(start.add(const Duration(minutes: 2))),
        const Duration(minutes: 10),
      );
    });

    test('others() excludes the signed-in user', () {
      expect(round.others.map((s) => s.userId), ['uid-captain']);
    });
  });
}
