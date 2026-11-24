import 'package:conclave_1_2_1/core/theme/app_theme.dart';
import 'package:conclave_1_2_1/features/active_conclave/data/round_sticky.dart';
import 'package:conclave_1_2_1/features/active_conclave/domain/active_conclave_models.dart';
import 'package:conclave_1_2_1/features/active_conclave/presentation/round/deck_footer.dart';
import 'package:conclave_1_2_1/features/active_conclave/presentation/round/round_timer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// One clock sized for tables of 5: bios 0:00 to 5:00, referrals 5:00 to 7:30.
void main() {
  final t0 = DateTime.utc(2026, 11, 18, 5);
  DateTime at(int seconds) => t0.add(Duration(seconds: seconds));

  ActiveRound round(int seated, {Duration extension = Duration.zero}) =>
      ActiveRound(
        conclaveId: 'c',
        roundNumber: 1,
        totalRounds: 4,
        tableNumber: 2,
        nextTableNumber: 3,
        startTime: t0,
        timing: RoundTiming.forRound(personsPerTable: 5, extension: extension),
        seats: [
          for (var i = 1; i <= seated; i++)
            TableSeat(
              userId: 'u$i',
              participantId: i,
              name: 'Member $i',
              businessName: 'Business $i',
              category: 'Category $i',
              isCaptain: i == 1,
              isSelf: i == 2,
            ),
        ],
        isCaptain: false,
        currentUserId: 'u2',
        currentParticipantId: 2,
      );

  test('a full table never waits', () {
    final r = round(5);
    for (var s = 0; s < 450; s++) {
      expect(r.waitAt(at(s)), isNull, reason: 'at ${s}s');
    }
  });

  test('a table of 4 waits one minute before referrals', () {
    final r = round(4);
    expect(r.waitAt(at(239)), isNull);
    final wait = r.waitAt(at(240))!;
    expect(wait.kind, TableWaitKind.forReferrals);
    expect(wait.length, const Duration(minutes: 1));
    expect(wait.remainingAt(at(258)), const Duration(seconds: 42));
    expect(r.waitAt(at(300)), isNull);
  });

  test('a table of 4 waits 30 seconds after its last referral', () {
    final r = round(4);
    expect(r.waitAt(at(419)), isNull);
    final wait = r.waitAt(at(420))!;
    expect(wait.kind, TableWaitKind.forOtherTables);
    expect(wait.length, const Duration(seconds: 30));
    expect(r.isReferralOpenAt(at(420)), isTrue);
    expect(r.waitAt(at(450)), isNull);
  });

  test('extra time is not a wait', () {
    final r = round(4, extension: const Duration(minutes: 2));
    expect(r.waitAt(at(460)), isNull);
    expect(stickyLineFor(r, at(460)), 'Extra time · one-to-ones');
  });

  test('the lock-screen line matches the wait', () {
    final r = round(4);
    expect(stickyLineFor(r, at(250)), 'Short wait · referrals start soon');
    expect(stickyLineFor(r, at(430)), 'Waiting for other tables');
  });

  Future<void> pumpBand(WidgetTester tester, ActiveRound r, DateTime now) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (c) => NowBand(vm: RoundTimer.of(r, now, c)),
            ),
          ),
        ),
      );

  testWidgets('the band explains each wait with a live countdown', (
    tester,
  ) async {
    await pumpBand(tester, round(4), at(258));
    expect(
      find.text(
        'Your table has fewer members, so you have a short wait. Referrals start in 00:42.',
      ),
      findsOneWidget,
    );
    await pumpBand(tester, round(4), at(426));
    expect(
      find.text(
        'Your table finished first. Other tables finish in 00:24. You can still pass a referral.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('extra time no longer reads as a person speaking', (
    tester,
  ) async {
    await pumpBand(
      tester,
      round(4, extension: const Duration(minutes: 2)),
      at(460),
    );
    expect(
      find.text('Extra time. Talk one-to-one with your table.'),
      findsOneWidget,
    );
    expect(find.textContaining('is speaking'), findsNothing);
  });
}
