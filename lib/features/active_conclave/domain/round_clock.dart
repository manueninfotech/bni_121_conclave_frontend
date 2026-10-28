/// The round clock — a mirror of the backend's `src/domain/roundClock.ts`
/// (and the admin panel's `src/utils/roundClock.js`), so every phone shows the
/// same round and phase as the server. Keep the three in step.
///
/// Rules (organisers, 2026-10-28):
///  - A round: 1-min bio per person, then ONE referral slot of 30 s per
///    person, after all bios. Max 8 per table; every table follows one clock
///    sized by the conclave's people-per-table (8 → 8 + 4 = 12 min).
///  - Referrals only in the referral slot.
///  - Admin "extend" (+1/+2/+5 min) adds time after the referral slot.
///  - Manual (default): the admin starts each round; a finished round waits.
///    Automatic: after the round (+ extension), a move break (1/2/5 min),
///    then the next round starts by itself.
///  - Paused: frozen.
library;

const int bioSecondsPerPerson = 60;
const int referralSecondsPerPerson = 30;
const int maxPersonsPerTable = 8;
const int defaultMoveSeconds = 120;

enum ClockPhase { notStarted, bio, referral, extension, move, waiting, done }

class LiveClock {
  /// The round in progress (or the last one reached); 0 before round 1.
  final int round;
  final ClockPhase phase;
  final DateTime? roundStart;

  /// Extra time on this round (only the stored current round has any).
  final Duration extension;

  const LiveClock({
    required this.round,
    required this.phase,
    required this.roundStart,
    required this.extension,
  });
}

class RoundClock {
  final int currentRound;
  final DateTime? currentRoundStartedAt;
  final int roundCount;
  final int personsPerTable;
  final bool automatic;
  final Duration extension;
  final Duration move;
  final bool paused;
  final Duration? elapsedBeforePause;

  const RoundClock({
    required this.currentRound,
    required this.currentRoundStartedAt,
    required this.roundCount,
    required this.personsPerTable,
    required this.automatic,
    required this.extension,
    required this.move,
    required this.paused,
    required this.elapsedBeforePause,
  });

  /// From the conclave document / live state the backend sends.
  factory RoundClock.fromDoc(Map<String, dynamic> d, {int? fallbackRoundCount}) {
    int i(Object? v, int fb) => (v as num?)?.toInt() ?? fb;
    final started = d['currentRoundStartedAt'];
    final pausedMs = (d['roundElapsedMsBeforePause'] as num?)?.toInt();
    return RoundClock(
      currentRound: i(d['currentRound'], 0),
      currentRoundStartedAt: started is String ? DateTime.tryParse(started) : null,
      roundCount: i(d['roundCount'], fallbackRoundCount ?? 0),
      personsPerTable: i(d['personsPerTable'], 7),
      automatic: d['roundProgressionMode'] == 'automatic',
      extension: Duration(seconds: i(d['roundExtensionSeconds'], 0).clamp(0, 3600)),
      move: Duration(seconds: i(d['moveSeconds'], defaultMoveSeconds).clamp(0, 3600)),
      paused: d['isRoundPaused'] == true,
      elapsedBeforePause: pausedMs == null ? null : Duration(milliseconds: pausedMs),
    );
  }

  int get people => personsPerTable.clamp(1, maxPersonsPerTable);
  Duration get bio => Duration(seconds: people * bioSecondsPerPerson);
  Duration get referral => Duration(seconds: people * referralSecondsPerPerson);
  Duration get talk => bio + referral;

  /// "Now" for the clock: frozen at the pause point while paused.
  DateTime clockNow(DateTime now) {
    final a = currentRoundStartedAt;
    if (paused && a != null) return a.add(elapsedBeforePause ?? Duration.zero);
    return now;
  }

  DateTime? roundStart(int k) {
    final a = currentRoundStartedAt;
    if (a == null || currentRound < 1 || k < currentRound) return null;
    if (k == currentRound) return a;
    if (!automatic) return null;
    return a.add(talk + extension + move).add((talk + move) * (k - currentRound - 1));
  }

  LiveClock live(DateTime now) {
    final a = currentRoundStartedAt;
    if (currentRound < 1 || a == null) {
      return const LiveClock(round: 0, phase: ClockPhase.notStarted, roundStart: null, extension: Duration.zero);
    }
    final t = clockNow(now);
    var k = currentRound;
    if (automatic) {
      while (k < roundCount) {
        final next = roundStart(k + 1);
        if (next == null || t.isBefore(next)) break;
        k++;
      }
    }
    final start = roundStart(k)!;
    final ext = k == currentRound ? extension : Duration.zero;
    final into = t.difference(start);
    ClockPhase phase;
    if (into < bio) {
      phase = ClockPhase.bio;
    } else if (into < talk) {
      phase = ClockPhase.referral;
    } else if (into < talk + ext) {
      phase = ClockPhase.extension;
    } else if (k >= roundCount) {
      phase = ClockPhase.done;
    } else {
      phase = automatic ? ClockPhase.move : ClockPhase.waiting;
    }
    return LiveClock(round: k, phase: phase, roundStart: start, extension: ext);
  }
}
