import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../domain/active_conclave_models.dart';
import 'round_avatar.dart';
import 'round_timer.dart';
import 'package:conclave_1_2_1/core/theme/cool_icons.dart';

/// The shared "premium panel" surface for the light chrome: a white card with a
/// soft, low shadow instead of flat grey fills.
BoxDecoration roundPanel(BuildContext context, {double radius = 20}) =>
    BoxDecoration(
      color: context.scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ],
    );

/// The "right now" card: the single best thing to do, derived from the round.
/// Hidden by the deck while paused.
class NowBand extends StatelessWidget {
  final RoundTimer vm;
  const NowBand({super.key, required this.vm});

  String _message() {
    if (vm.headline != null) return vm.headline!;
    if (vm.phase == RoundPhase.active) {
      if (vm.selfNow) {
        return vm.isReferral
            ? "It's your turn — pass a referral to someone here."
            : "It's your turn — give your 60-second intro.";
      }
      if (vm.nowName != null) {
        return vm.isReferral
            ? '${vm.nowName} is giving a referral — listen for a lead.'
            : '${vm.nowName} is speaking — note what they do.';
      }
      return 'Referrals are open — pass one to someone you can help.';
    }
    return vm.kicker;
  }

  @override
  Widget build(BuildContext context) {
    final message = _message();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.sm, Gap.md, Gap.sm),
      decoration: roundPanel(context, radius: 18),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: kDeckBottom.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(vm.icon, size: 18, color: kDeckBottom),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.centerLeft,
                children: [...previous, ?current],
              ),
              child: Text(
                message,
                key: ValueKey(message),
                style: context.text.bodyMedium?.copyWith(
                  color: context.scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Page dots under the deck.
class DeckDots extends StatelessWidget {
  final int count;
  final int index;
  const DeckDots({super.key, required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: Motion.normal,
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 20 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == index
                  ? context.scheme.onSurface
                  : context.scheme.outlineVariant,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
    );
  }
}

/// The speaking order as a story: who has spoken (dimmed, ticked), who is on
/// now (live ring), and who is still to come — tap anyone to jump the deck to
/// their card.
class SpeakingOrderPanel extends StatelessWidget {
  final List<TableSeat> order;
  final SpeakingTurn? currentTurn;
  final DateTime now;

  /// In session but nobody's turn — this pass is complete for everyone.
  final bool passComplete;
  final int? selectedId;
  final ValueChanged<int> onJump;

  const SpeakingOrderPanel({
    super.key,
    required this.order,
    required this.currentTurn,
    required this.now,
    required this.passComplete,
    required this.selectedId,
    required this.onJump,
  });

  @override
  Widget build(BuildContext context) {
    final turn = currentTurn;
    final currentIdx = turn == null
        ? -1
        : order.indexWhere(
            (s) => s.participantId == turn.speaker.participantId,
          );
    final referral = turn?.kind == TurnKind.referral;
    final title = referral ? 'REFERRALS' : 'SPEAKING ORDER';
    final count = currentIdx >= 0
        ? '${currentIdx + 1} of ${order.length}'
        : (passComplete ? 'All done' : '');
    final muted = context.scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm + 2, Gap.md, Gap.sm),
      decoration: roundPanel(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: context.text.labelSmall?.copyWith(
                  color: muted,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                count,
                style: context.text.labelMedium?.copyWith(
                  color: muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          SizedBox(
            height: 70,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: order.length,
              separatorBuilder: (_, _) => const SizedBox(width: Gap.sm),
              itemBuilder: (context, i) {
                final seat = order[i];
                final speaking = i == currentIdx;
                final done = currentIdx >= 0 ? i < currentIdx : passComplete;
                // A still ring marks the speaker; the card owns the countdown.
                final progress = speaking ? 1.0 : null;
                return GestureDetector(
                  onTap: () => onJump(seat.participantId),
                  child: _OrderAvatar(
                    seat: seat,
                    label: speaking
                        ? 'Now'
                        : (seat.isSelf ? 'You' : '#${i + 1}'),
                    speaking: speaking,
                    done: done,
                    selected: seat.participantId == selectedId,
                    progress: progress,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderAvatar extends StatelessWidget {
  final TableSeat seat;
  final String label;
  final bool speaking;
  final bool done;
  final bool selected;
  final double? progress;

  const _OrderAvatar({
    required this.seat,
    required this.label,
    required this.speaking,
    required this.done,
    required this.selected,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final ink = context.scheme.onSurface;
    const size = 44.0;
    return SizedBox(
      width: 52,
      child: Column(
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 400),
            opacity: done && !speaking ? 0.45 : 1,
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  if (progress != null)
                    SizedBox(
                      width: size,
                      height: size,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: progress!),
                        duration: const Duration(milliseconds: 900),
                        builder: (context, v, _) => CircularProgressIndicator(
                          value: v,
                          strokeWidth: 2.5,
                          backgroundColor: context.scheme.outlineVariant
                              .withValues(alpha: 0.5),
                          valueColor: AlwaysStoppedAnimation(ink),
                        ),
                      ),
                    ),
                  Container(
                    width: progress != null ? size - 8 : size,
                    height: progress != null ? size - 8 : size,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.scheme.surfaceContainerHighest,
                      border: selected && !speaking
                          ? Border.all(color: ink, width: 1.5)
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: seat.photoUrl != null
                        ? Image.network(
                            seat.photoUrl!,
                            fit: BoxFit.cover,
                            width: size,
                            height: size,
                            errorBuilder: (_, _, _) =>
                                roundInitialAvatarText(context, seat),
                          )
                        : roundInitialAvatarText(context, seat),
                  ),
                  if (seat.isCaptain)
                    Positioned(
                      right: -3,
                      top: -3,
                      child: _Badge(
                        color: context.scheme.surfaceContainerLowest,
                        child: const Icon(
                          CoolIcons.crownFill,
                          size: 13,
                          color: Color(0xFFE0A200),
                        ),
                      ),
                    ),
                  if (done && !speaking)
                    Positioned(
                      right: -3,
                      bottom: -3,
                      child: _Badge(
                        color: ink,
                        child: Icon(
                          CoolIcons.check,
                          size: 11,
                          color: context.scheme.surface,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            style: context.text.labelSmall?.copyWith(
              color: speaking ? ink : context.scheme.onSurfaceVariant,
              fontWeight: speaking ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final Color color;
  final Widget child;
  const _Badge({required this.color, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(2),
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: child,
  );
}
