import 'package:conclave_1_2_1/features/active_conclave/domain/active_conclave_models.dart';
import 'package:conclave_1_2_1/features/active_conclave/domain/attendance_qr.dart';
import 'package:flutter_test/flutter_test.dart';

TableSeat _seat(String uid, int pid, {bool self = false, bool captain = false}) =>
    TableSeat(
      userId: uid,
      participantId: pid,
      name: uid,
      businessName: '',
      category: '',
      isCaptain: captain,
      isSelf: self,
    );

/// A captain at Table 1 in round 1; their next group (round 2) is b and c.
ActiveRound _round({required DateTime start}) => ActiveRound(
      conclaveId: 'c1',
      roundNumber: 1,
      totalRounds: 3,
      tableNumber: 1,
      nextTableNumber: 1,
      startTime: start,
      timing: RoundTiming.forRound(personsPerTable: 3),
      seats: [_seat('cap', 1, self: true, captain: true), _seat('a', 2)],
      upcomingSeats: [
        _seat('cap', 1, self: true, captain: true),
        _seat('b', 3),
        _seat('c', 4),
      ],
      isCaptain: true,
      currentUserId: 'cap',
      currentParticipantId: 1,
    );

String _code(String uid) => AttendanceQr(conclaveId: 'c1', uid: uid).encode();

void main() {
  // Long after round 1's talk ended — i.e. in the move window.
  final start = DateTime(2026, 1, 1, 10);
  final duringMove = start.add(const Duration(hours: 1));

  test('arrivalsRound is the next round at the next table with the incoming group', () {
    final next = _round(start: start).arrivalsRound()!;
    expect(next.roundNumber, 2);
    expect(next.tableNumber, 1);
    expect(next.seats.map((s) => s.userId), ['cap', 'b', 'c']);
  });

  test('arrivalsRound is null on the last round (no next table)', () {
    final last = ActiveRound(
      conclaveId: 'c1',
      roundNumber: 3,
      totalRounds: 3,
      tableNumber: 1,
      startTime: start,
      timing: RoundTiming.forRound(personsPerTable: 3),
      seats: [_seat('cap', 1, self: true, captain: true)],
      isCaptain: true,
      currentUserId: 'cap',
      currentParticipantId: 1,
    );
    expect(last.arrivalsRound(), isNull);
  });

  test('a normal scan is refused once the talk has ended', () {
    final outcome =
        validateScan(raw: _code('a'), round: _round(start: start), now: duringMove);
    expect(outcome.result, ScanResult.roundClosed);
  });

  test('an arrivals scan accepts a member of the incoming group', () {
    final next = _round(start: start).arrivalsRound()!;
    final outcome =
        validateScan(raw: _code('b'), round: next, now: duringMove, arrivals: true);
    expect(outcome.result, ScanResult.accepted);
    expect(outcome.seat!.userId, 'b');
  });

  test('an arrivals scan still refuses someone not in the incoming group', () {
    final next = _round(start: start).arrivalsRound()!;
    // 'a' sat with the captain in round 1 but is NOT in round 2's group.
    final outcome =
        validateScan(raw: _code('a'), round: next, now: duringMove, arrivals: true);
    expect(outcome.result, ScanResult.notAtThisTable);
  });
}
