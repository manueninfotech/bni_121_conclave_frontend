import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../round/card_backdrop.dart';

/// The top of the summary: the same silk as the live round, now settled, with
/// the conclave's name and the shape of the day. The one red moment on the page.
class SummaryHero extends StatelessWidget {
  final String conclaveName;
  final int rounds;
  final int peopleMet;
  final bool syncing;
  final VoidCallback onBack;
  final VoidCallback onSync;

  /// Space left at the bottom for the stats card that overlaps the hero.
  static const double overlap = 44;

  const SummaryHero({
    super.key,
    required this.conclaveName,
    required this.rounds,
    required this.peopleMet,
    required this.syncing,
    required this.onBack,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final facts = [
      if (rounds > 0) '$rounds ${rounds == 1 ? 'round' : 'rounds'}',
      if (peopleMet > 0) '$peopleMet people met',
    ].join('  ·  ');

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      child: Stack(
        children: [
          const Positioned.fill(
            child: CardBackdrop(mood: CardMood.bio, seed: 5.3),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                Gap.sm, top + Gap.xs, Gap.sm, Gap.xl + overlap),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  IconButton(
                    onPressed: onBack,
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: syncing ? null : onSync,
                    tooltip: 'Sync now',
                    icon: syncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.sync_rounded, color: Colors.white),
                  ),
                ]),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: Gap.md),
                      Text(
                        "THAT'S A WRAP",
                        style: context.text.labelLarge?.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: Gap.xs),
                      Text(
                        conclaveName.isEmpty ? 'Your conclave' : conclaveName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      if (facts.isNotEmpty) ...[
                        const SizedBox(height: Gap.sm),
                        Text(
                          facts,
                          style: context.text.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
