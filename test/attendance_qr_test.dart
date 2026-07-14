import 'package:flutter_test/flutter_test.dart';
import 'package:conclave_1_2_1/features/active_conclave/domain/active_conclave_models.dart';
import 'package:conclave_1_2_1/features/active_conclave/domain/attendance_qr.dart';

TableSeat seat(String uid, String name, {bool isCaptain = false, bool isSelf = false}) {
  return TableSeat(
    userId: uid,
    participantId: uid.hashCode,
    name: name,
    businessName: '$name Biz',
    category: 'Cat-$name',
    isCaptain: isCaptain,
    isSelf: isSelf,
  );
}

/// A captain (uid-cap) at table 4 with two members. P=8 -> 12 min active.
final start = DateTime(2026, 7, 14, 10, 0, 0);
final round = ActiveRound(
  conclaveId: 'conclave-A',
  roundNumber: 2,
  totalRounds: 6,
  tableNumber: 4,
  startTime: start,
  timing: RoundTiming.forPersonsPerTable(8),
  seats: [
    seat('uid-cap', 'Ganesh', isCaptain: true, isSelf: true),
    seat('uid-m1', 'Sravan'),
    seat('uid-m2', 'Bhanu'),
  ],
  isCaptain: true,
  currentUserId: 'uid-cap',
  currentParticipantId: 'uid-cap'.hashCode,
);

/// Mid-round: attendance is open.
final duringRound = start.add(const Duration(minutes: 5));

void main() {
  group('AttendanceQr payload', () {
    test('round-trips', () {
      const qr = AttendanceQr(conclaveId: 'conclave-A', uid: 'uid-m1');
      final parsed = AttendanceQr.tryParse(qr.encode())!;
      expect(parsed.conclaveId, 'conclave-A');
      expect(parsed.uid, 'uid-m1');
    });

    test('encodes in the documented badge-printable format', () {
      expect(
        const AttendanceQr(conclaveId: 'c1', uid: 'u1').encode(),
        'BNI121|1|c1|u1',
      );
    });

    test('rejects foreign QR codes', () {
      // The camera will read every QR in the room, including these.
      expect(AttendanceQr.tryParse('https://example.com'), isNull);
      expect(AttendanceQr.tryParse('WIFI:S:venue;P:pass;;'), isNull);
      expect(AttendanceQr.tryParse(''), isNull);
    });

    test('rejects a different payload version', () {
      expect(AttendanceQr.tryParse('BNI121|2|c1|u1'), isNull);
    });

    test('rejects malformed or empty fields', () {
      expect(AttendanceQr.tryParse('BNI121|1|c1'), isNull);
      expect(AttendanceQr.tryParse('BNI121|1||u1'), isNull);
      expect(AttendanceQr.tryParse('BNI121|1|c1|'), isNull);
    });
  });

  group('validateScan', () {
    test('accepts a member seated at this captain\'s table', () {
      final outcome = validateScan(
        raw: const AttendanceQr(conclaveId: 'conclave-A', uid: 'uid-m1').encode(),
        round: round,
        now: duringRound,
      );
      expect(outcome.isAccepted, isTrue);
      expect(outcome.seat!.name, 'Sravan');
      expect(scanMessage(outcome), 'Marked Sravan present.');
    });

    // The rule that matters at a crowded venue: tables are inches apart.
    test('rejects a real member who is NOT at this table this round', () {
      final outcome = validateScan(
        raw: const AttendanceQr(conclaveId: 'conclave-A', uid: 'uid-stranger').encode(),
        round: round,
        now: duringRound,
      );
      expect(outcome.result, ScanResult.notAtThisTable);
      expect(outcome.seat, isNull);
    });

    test('rejects a code from a different conclave', () {
      final outcome = validateScan(
        raw: const AttendanceQr(conclaveId: 'conclave-B', uid: 'uid-m1').encode(),
        round: round,
        now: duringRound,
      );
      expect(outcome.result, ScanResult.wrongConclave);
    });

    test('rejects the captain scanning their own code', () {
      final outcome = validateScan(
        raw: const AttendanceQr(conclaveId: 'conclave-A', uid: 'uid-cap').encode(),
        round: round,
        now: duringRound,
      );
      expect(outcome.result, ScanResult.selfScan);
    });

    test('rejects anything that is not our code', () {
      final outcome = validateScan(
        raw: 'https://bni.com',
        round: round,
        now: duringRound,
      );
      expect(outcome.result, ScanResult.notOurCode);
    });

    test('rejects a valid member once the talking window has closed', () {
      // 13 min in: transition phase, attendance is closed.
      final outcome = validateScan(
        raw: const AttendanceQr(conclaveId: 'conclave-A', uid: 'uid-m1').encode(),
        round: round,
        now: start.add(const Duration(minutes: 13)),
      );
      expect(outcome.result, ScanResult.roundClosed);
    });

    test('a foreign code is rejected as foreign even after the round closes', () {
      // Parse failures short-circuit before the clock check — the message the
      // captain sees should describe the actual problem.
      final outcome = validateScan(
        raw: 'nonsense',
        round: round,
        now: start.add(const Duration(hours: 2)),
      );
      expect(outcome.result, ScanResult.notOurCode);
    });
  });
}
