import 'package:conclave_1_2_1/features/active_conclave/domain/active_conclave_models.dart';
import 'package:conclave_1_2_1/features/active_conclave/domain/round_clock.dart';
import 'package:flutter_test/flutter_test.dart';

// Same cases as the backend's src/domain/__tests__/roundClock.test.ts.
void main() {
  final t0 = DateTime.utc(2026, 11, 1, 5);
  DateTime at(num minutes) => t0.add(Duration(milliseconds: (minutes * 60000).round()));
  RoundClock clock({bool automatic = false, int ext = 0, int move = 120, int current = 1, bool paused = false, int? pausedMs}) => RoundClock(
        currentRound: current,
        currentRoundStartedAt: t0,
        roundCount: 4,
        personsPerTable: 8,
        automatic: automatic,
        extension: Duration(seconds: ext),
        move: Duration(seconds: move),
        paused: paused,
        elapsedBeforePause: pausedMs == null ? null : Duration(milliseconds: pausedMs),
      );

  test('8 per table: bios 8 min then referrals 4 min', () {
    final c = clock();
    expect(c.talk, const Duration(minutes: 12));
    expect(c.live(at(1)).phase, ClockPhase.bio);
    expect(c.live(at(9)).phase, ClockPhase.referral);
  });

  test('manual waits for the admin; last round reads done', () {
    expect(clock().live(at(30)).phase, ClockPhase.waiting);
    expect(clock().live(at(30)).round, 1);
    expect(clock(current: 4).live(at(30)).phase, ClockPhase.done);
  });

  test('extension is added after the referral slot', () {
    final c = clock(ext: 120);
    expect(c.live(at(13)).phase, ClockPhase.extension);
    final timing = RoundTiming.forRound(personsPerTable: 8, extension: const Duration(minutes: 2));
    expect(timing.referralOpensAfter, const Duration(minutes: 8));
    expect(timing.referralClosesAfter, const Duration(minutes: 12));
    expect(timing.active, const Duration(minutes: 14));
  });

  test('automatic moves on after talk + move', () {
    final c = clock(automatic: true);
    expect(c.live(at(13)).phase, ClockPhase.move);
    expect(c.roundStart(2), at(14));
    expect(c.live(at(15)).round, 2);
    expect(clock(automatic: true, ext: 300).roundStart(2), at(19));
    expect(c.live(at(200)).phase, ClockPhase.done);
  });

  test('pause freezes the clock', () {
    expect(clock(paused: true, pausedMs: 3 * 60000).live(at(60)).phase, ClockPhase.bio);
  });

  test('tables never exceed 8', () {
    expect(RoundTiming.forRound(personsPerTable: 10).referralClosesAfter, const Duration(minutes: 12));
  });

  // Same cases as the backend and the panel: per-round sizes.
  RoundClock sized() => RoundClock(
        currentRound: 1,
        currentRoundStartedAt: t0,
        roundCount: 4,
        personsPerTable: 5,
        roundPeople: const [5, 5, 6, 5],
        automatic: true,
        extension: Duration.zero,
        move: const Duration(seconds: 120),
        paused: false,
        elapsedBeforePause: null,
      );

  test('each round is timed for its own size', () {
    expect(sized().talkFor(1), const Duration(seconds: 450));
    expect(sized().talkFor(3), const Duration(minutes: 9));
    expect(sized().peopleFor(3), 6);
  });

  test('automatic: later rounds start after each earlier round at its own length', () {
    expect(sized().roundStart(2), at(9.5));
    expect(sized().roundStart(3), at(19));
    expect(sized().roundStart(4), at(30));
    expect(sized().live(at(24.5)).round, 3);
    expect(sized().live(at(24.5)).phase, ClockPhase.bio);
    expect(sized().live(at(25.5)).phase, ClockPhase.referral);
  });

  test('falls back to people-per-table', () {
    expect(clock().talkFor(3), const Duration(minutes: 12));
    expect(sized().talkFor(9), const Duration(seconds: 450));
    expect(RoundClock.fromDoc({'personsPerTable': 5, 'roundPeople': [12]}).talkFor(1), const Duration(minutes: 12));
  });
}
