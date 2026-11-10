import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../domain/active_conclave_models.dart';
import 'round_timer.dart';
import 'package:conclave_1_2_1/core/theme/cool_icons.dart';

/// The glanceable top strip: round/table, the phase line, the one dynamic status
/// (live countdown or a single "Paused"), and a slim bar showing how far through
/// the round the table is. Neutral ink — red is kept for the card and for the
/// last ten seconds of a turn, so it still means something when it appears.
class DeckHeader extends StatelessWidget {
  final ActiveRound round;
  final RoundTimer vm;
  final bool showUpcoming;
  final bool paused;

  /// 0..1 through the round's talking time.
  final double progress;
  final int pendingSync;
  final VoidCallback onSync;

  const DeckHeader({
    super.key,
    required this.round,
    required this.vm,
    required this.showUpcoming,
    required this.paused,
    required this.progress,
    required this.pendingSync,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    final table = showUpcoming ? round.nextTableNumber : round.tableNumber;
    final ink = context.scheme.onSurface;
    final muted = context.scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ROUND ${round.roundNumber} OF ${round.totalRounds}'
                      '${table != null ? '  ·  TABLE $table' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelMedium?.copyWith(
                        color: ink,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: Text(
                        vm.kicker,
                        key: ValueKey(vm.kicker),
                        style: context.text.bodySmall?.copyWith(color: muted),
                      ),
                    ),
                  ],
                ),
              ),
              if (pendingSync > 0) ...[
                _SyncChip(pending: pendingSync, onTap: onSync),
                const SizedBox(width: Gap.sm),
              ],
              // The ONE place "Paused" is said. No clock here: the card owns the
              // turn countdown, the bar below owns the round.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: paused
                    ? Container(
                        key: const ValueKey('paused'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: context.scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CoolIcons.pauseFill, color: ink, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              'Paused',
                              style: context.text.labelLarge?.copyWith(
                                color: ink,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('live')),
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          // How far through the round — a quiet ink line, eased as it moves.
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 3,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: progress.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOut,
                builder: (context, v, _) => LinearProgressIndicator(
                  value: v,
                  backgroundColor: context.scheme.outlineVariant.withValues(
                    alpha: 0.45,
                  ),
                  valueColor: AlwaysStoppedAnimation(
                    paused ? muted : ink.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A quiet "N waiting to sync" chip — the offline-queue affordance. Tap to flush.
class _SyncChip extends StatelessWidget {
  final int pending;
  final VoidCallback onTap;
  const _SyncChip({required this.pending, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: context.scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CoolIcons.cloudUpload,
              size: 16,
              color: context.scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              '$pending',
              style: context.text.labelMedium?.copyWith(
                color: context.scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
