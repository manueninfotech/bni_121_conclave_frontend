import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/theme/tokens.dart';
import '../../domain/active_conclave_models.dart';
import '../../domain/attendance_qr.dart';
import 'animated_countdown.dart';
import 'card_backdrop.dart';
import 'round_avatar.dart';
import 'round_timer.dart';
import 'package:conclave_1_2_1/core/theme/cool_icons.dart';

/// One person at the table, as a BNI-red gradient card. The card fills its slot
/// (identity on top, a hero in the middle, actions at the bottom) so there's no
/// dead space. While the round is paused the card simply dims and its live cues
/// freeze — the word "Paused" is said once, in the header, not here.
class PersonCard extends StatelessWidget {
  final ActiveRound round;
  final TableSeat seat;
  final bool isSpeaker;
  final SpeakingTurn? turn;
  final DateTime now;
  final bool preview;
  final bool paused;
  final bool? attendance;
  final bool canMark;
  final bool canRefer;
  final bool canNote;
  final bool alreadyReferred;
  final bool hasNote;
  final ValueChanged<bool> onAttendance;
  final VoidCallback onRefer;
  final VoidCallback onAddNote;

  const PersonCard({
    super.key,
    required this.round,
    required this.seat,
    required this.isSpeaker,
    required this.turn,
    required this.now,
    required this.preview,
    required this.paused,
    required this.attendance,
    required this.canMark,
    required this.canRefer,
    required this.canNote,
    required this.alreadyReferred,
    required this.hasNote,
    required this.onAttendance,
    required this.onRefer,
    required this.onAddNote,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = turn?.remainingAt(now);
    final progress = (turn != null && turn!.length.inMilliseconds > 0)
        ? (remaining!.inMilliseconds / turn!.length.inMilliseconds).clamp(
            0.0,
            1.0,
          )
        : null;
    final urgent =
        !paused &&
        remaining != null &&
        remaining.inSeconds <= 10 &&
        remaining.inSeconds > 0;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _avatar(context, size: 68, progress: progress, urgent: urgent),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    seat.isSelf ? 'You' : seat.name,
                    style: context.text.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  if (seat.businessName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      seat.businessName,
                      style: context.text.bodyMedium?.copyWith(
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (seat.category.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      seat.category,
                      style: context.text.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (seat.isCaptain || seat.isStandIn)
              _captainBadge(context, standIn: seat.isStandIn),
          ],
        ),
        // Their Conclave Specific Ask: what they hope to get from today, so a
        // tablemate who can help sees it while they listen.
        if (seat.ask != null) ...[
          const SizedBox(height: Gap.md),
          _ask(context, seat.ask!),
        ],
        const SizedBox(height: Gap.lg),
        // Cross-fade between hero states (tablemate -> speaking -> done) so a
        // turn change eases in instead of popping. Keyed by the KIND of hero,
        // not its contents, so the ticking clock doesn't re-trigger it.
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: KeyedSubtree(
              key: ValueKey(_heroKind(remaining)),
              child: _hero(context, remaining),
            ),
          ),
        ),
        const SizedBox(height: Gap.md),
        _actions(context),
      ],
    );

    final radius = BorderRadius.circular(28);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: kDeckBottom,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: kDeckBottom.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      // Border on top of the animated backdrop, not under it.
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: isSpeaker && !paused
            ? Border.all(color: Colors.white, width: 2)
            : Border.all(color: Colors.white24, width: 1),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The living, phase-aware background (see CardBackdrop).
          CardBackdrop(
            mood: _mood,
            intense: isSpeaker,
            // A different fold arrangement per person.
            seed: seat.participantId * 1.37,
          ),
          Padding(
            padding: const EdgeInsets.all(Gap.lg),
            // Paused: the backdrop freezes + desaturates; content softens a
            // touch. The header carries the one "Paused".
            child: paused ? Opacity(opacity: 0.8, child: content) : content,
          ),
        ],
      ),
    );
  }

  CardMood get _mood {
    if (paused) return CardMood.paused;
    if (preview || round.phaseAt(now) != RoundPhase.active) {
      return CardMood.move;
    }
    if (turn?.kind == TurnKind.referral || round.isReferralOpenAt(now)) {
      return CardMood.referral;
    }
    return CardMood.bio;
  }

  String _heroKind(Duration? remaining) {
    if (isSpeaker && remaining != null) {
      return 'speak-${turn!.kind.name}-$paused';
    }
    if (seat.isSelf && !preview) return 'qr';
    return 'info';
  }

  /// The middle of the card, sized to fill the space: the live countdown for the
  /// speaker, your QR on your own card, or the person's headline for a tablemate.
  Widget _hero(BuildContext context, Duration? remaining) {
    if (isSpeaker && remaining != null) {
      final label = seat.isSelf
          ? 'YOUR TURN'
          : (turn!.kind == TurnKind.bio ? 'SPEAKING NOW' : 'REFERRING NOW');
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The live pulse only makes sense while the clock is running.
            if (!paused)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PulseDot(),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: context.text.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            if (!paused) const SizedBox(height: 10),
            AnimatedCountdown(
              remaining: remaining,
              style: context.text.displayLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              turn!.kind == TurnKind.bio
                  ? 'Bio · 60 seconds'
                  : 'Referral · 30 seconds',
              style: context.text.bodyMedium?.copyWith(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (seat.isSelf && !preview) {
      return Center(child: _qrPlateBig(context));
    }

    final chips = <Widget>[];
    if (seat.metBefore) {
      chips.add(_tag(context, CoolIcons.history, 'Met before'));
    }
    if (preview) {
      chips.add(_tag(context, CoolIcons.usersGroup, 'Joining your next table'));
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CoolIcons.briefcase,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            seat.category.isNotEmpty ? seat.category : 'At your table',
            textAlign: TextAlign.center,
            style: context.text.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: chips,
            ),
          ],
        ],
      ),
    );
  }

  Widget _actions(BuildContext context) {
    final items = <Widget>[];
    if (canMark) {
      if (attendance == true) {
        items.add(
          _chip(context, CoolIcons.circleCheckFill, 'Here', filled: true),
        );
      } else if (seat.isSelf) {
        items.add(
          _chip(
            context,
            CoolIcons.handPointer,
            "I'm here",
            onTap: () => onAttendance(true),
          ),
        );
      } else {
        items.add(
          _chip(
            context,
            CoolIcons.check,
            'Present',
            onTap: () => onAttendance(true),
          ),
        );
        items.add(
          _chip(
            context,
            CoolIcons.close,
            'Absent',
            onTap: () => onAttendance(false),
          ),
        );
      }
    }
    if (alreadyReferred) {
      items.add(
        _chip(context, CoolIcons.handshakeFill, 'Referred', filled: true),
      );
    } else if (canRefer) {
      items.add(
        _chip(context, CoolIcons.handshake, 'Give referral', onTap: onRefer),
      );
    }
    if (canNote) {
      items.add(
        _chip(
          context,
          CoolIcons.note,
          hasNote ? 'Edit note' : 'Add note',
          onTap: onAddNote,
        ),
      );
    }
    if (items.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: items);
  }

  Widget _qrPlateBig(BuildContext context) {
    final payload = AttendanceQr(
      conclaveId: round.conclaveId,
      uid: round.currentUserId,
    ).encode();
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QrImageView(data: payload, size: 148, backgroundColor: Colors.white),
          const SizedBox(height: 10),
          Text(
            'Show to your captain to be marked present',
            textAlign: TextAlign.center,
            style: context.text.bodySmall?.copyWith(
              color: const Color(0xFF8A1020),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(
    BuildContext context, {
    required double size,
    double? progress,
    bool urgent = false,
  }) {
    // The ring greys out while paused — a quiet "frozen" cue, no words.
    final ringColor = paused
        ? Colors.white38
        : (urgent ? Colors.amberAccent : Colors.white);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (progress != null)
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 4,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation(ringColor),
              ),
            ),
          Container(
            width: size - 14,
            height: size - 14,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white24,
              border: Border.all(color: Colors.white, width: 2),
            ),
            alignment: Alignment.center,
            child: seat.photoUrl != null
                ? Image.network(
                    seat.photoUrl!,
                    width: size - 14,
                    height: size - 14,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        roundInitialAvatarText(context, seat),
                  )
                : roundInitialAvatarText(context, seat),
          ),
        ],
      ),
    );
  }

  Widget _ask(BuildContext context, String ask) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.sm),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            seat.isSelf ? 'YOUR ASK' : 'THEIR ASK',
            style: context.text.labelSmall?.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            ask,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  /// A clear "Captain" pill — the captain anchors the table, so it is labelled,
  /// not left as a bare star that reads like a favourite.
  Widget _captainBadge(BuildContext context, {bool standIn = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CoolIcons.crownFill, color: Colors.amberAccent, size: 15),
          const SizedBox(width: 4),
          Text(
            standIn ? 'Captain this round' : 'Captain',
            style: context.text.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: context.text.labelSmall?.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    IconData icon,
    String label, {
    VoidCallback? onTap,
    bool filled = false,
  }) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: filled ? Colors.white : Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: filled ? kDeckBottom : Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: context.text.labelLarge?.copyWith(
              color: filled ? kDeckBottom : Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return child;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: child,
    );
  }
}

/// A soft pulsing dot — the "live" cue next to the current speaker.
class PulseDot extends StatefulWidget {
  const PulseDot({super.key});
  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.3, end: 1.0).animate(_c),
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
