import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../domain/active_conclave_models.dart';

/// BNI-red card-gradient endpoints, shared across the live-round deck.
const kDeckTop = Color(0xFFF04E66);
const kDeckBottom = Color(0xFFB00E29);

/// mm:ss for the on-screen countdowns.
String roundMmss(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Everything the timer needs, resolved once from the round + clock.
///
/// During the active phase the timer tracks the *current speaker's* turn — their
/// bio or referral countdown, who is up, who is next. Off the active phase it
/// falls back to the phase countdown (walk to your next table / round ended).
class RoundTimer {
  final RoundPhase phase;
  final Color fg;
  final Color bg;
  final IconData icon;
  final String kicker;
  final Duration remaining;
  final Duration total;
  final String? nowName; // current speaker; null off the active phase
  final bool selfNow; // the current speaker is the signed-in user
  final bool isReferral; // the current turn is a referral, not a bio (#10)
  final String? nextName; // next speaker; null when the last person is up
  final bool urgent;
  // The prominent line for the non-speaking phases — e.g. the transition
  // destination ("Go to Table 3" / "Stay at Table 1 · next group arriving").
  final String? headline;

  const RoundTimer({
    required this.phase,
    required this.fg,
    required this.bg,
    required this.icon,
    required this.kicker,
    required this.remaining,
    required this.total,
    required this.nowName,
    required this.selfNow,
    required this.nextName,
    required this.urgent,
    this.isReferral = false,
    this.headline,
  });

  double get progress => total.inMilliseconds == 0
      ? 0.0
      : (remaining.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);

  static RoundTimer of(ActiveRound round, DateTime now, BuildContext context) {
    final c = context.colors;
    final phase = round.phaseAt(now);
    final turn = phase == RoundPhase.active ? round.currentTurnAt(now) : null;

    if (turn != null) {
      final next = round.nextTurnAt(now);
      final remaining = turn.remainingAt(now);
      return RoundTimer(
        phase: phase,
        fg: c.onSuccessContainer,
        bg: c.successContainer,
        icon: turn.kind == TurnKind.bio
            ? Icons.record_voice_over_outlined
            : Icons.handshake_outlined,
        kicker: turn.kind == TurnKind.bio ? 'Bio' : 'Referrals',
        remaining: remaining,
        total: turn.length,
        nowName: turn.speaker.isSelf ? 'You' : turn.speaker.name,
        selfNow: turn.speaker.isSelf,
        isReferral: turn.kind == TurnKind.referral,
        nextName: next == null
            ? null
            : (next.speaker.isSelf ? 'You' : next.speaker.name),
        // The last ten seconds of any turn pulse — the cue to wrap up before the
        // floor passes to the next person.
        urgent: remaining.inSeconds <= 10 && remaining.inSeconds > 0,
      );
    }

    // In session but nobody's turn: a table one short of full waiting for the
    // referral slot, or the extra time the organiser added for one-to-ones.
    if (phase == RoundPhase.active) {
      final beforeReferrals = now.isBefore(round.referralOpensAt);
      final ends = beforeReferrals ? round.referralOpensAt : round.activeEndsAt;
      return RoundTimer(
        phase: phase,
        fg: c.onSuccessContainer,
        bg: c.successContainer,
        icon: beforeReferrals ? Icons.hourglass_top : Icons.forum_outlined,
        kicker: beforeReferrals ? 'Referrals start soon' : 'Extra time',
        remaining:
            ends.difference(now).isNegative ? Duration.zero : ends.difference(now),
        total: beforeReferrals
            ? round.timing.referralOpensAfter
            : round.activeEndsAt.difference(round.referralClosesAt),
        nowName: beforeReferrals ? null : 'One-to-ones',
        selfNow: false,
        nextName: null,
        urgent: false,
      );
    }

    if (phase == RoundPhase.transition) {
      final next = round.nextTableNumber;
      // Captains anchor their table (next == current), everyone else moves —
      // including a stand-in, who only captains for this round.
      final staying = next != null && next == round.tableNumber;
      String kicker;
      String? headline;
      IconData icon;
      if (next == null) {
        kicker = 'Round over';
        headline = null;
        icon = Icons.flag_outlined;
      } else if (staying) {
        kicker = 'Stay at your table';
        headline = 'Table $next · your next group is arriving';
        icon = Icons.chair_alt_outlined;
      } else {
        kicker = 'Move to your next table';
        headline = 'Move to Table $next';
        icon = Icons.directions_walk;
      }
      return RoundTimer(
        phase: phase,
        fg: c.onWarningContainer,
        bg: c.warningContainer,
        icon: icon,
        kicker: kicker,
        remaining: round.remainingAt(now),
        total: round.timing.transition,
        nowName: null,
        selfNow: false,
        nextName: null,
        urgent: false,
        headline: headline,
      );
    }

    // Round block fully elapsed. In manual mode this gap can last a while before
    // the organiser starts the next round — so if there IS a next round, keep
    // telling the member where to go and that their next group is forming,
    // instead of a blank "Round ended". (#2 / move guidance)
    final endedNext = round.nextTableNumber;
    if (endedNext != null) {
      final staying = endedNext == round.tableNumber;
      return RoundTimer(
        phase: phase,
        fg: c.onWarningContainer,
        bg: c.warningContainer,
        icon: staying ? Icons.chair_alt_outlined : Icons.directions_walk,
        kicker: staying ? 'Stay at your table' : 'Move to your next table',
        remaining: Duration.zero,
        total: round.timing.transition,
        nowName: null,
        selfNow: false,
        nextName: null,
        urgent: false,
        headline: staying
            ? 'Table $endedNext · your next group is arriving'
            : 'Move to Table $endedNext',
      );
    }

    return RoundTimer(
      phase: phase,
      fg: context.scheme.onSurfaceVariant,
      bg: context.scheme.surfaceContainerHighest,
      icon: Icons.hourglass_empty,
      kicker: 'Round ended',
      remaining: Duration.zero,
      total: round.timing.transition,
      nowName: null,
      selfNow: false,
      nextName: null,
      urgent: false,
    );
  }
}
