import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/cool_icons.dart';
import '../../../../core/theme/tokens.dart';
import '../../../active_conclave/presentation/round/card_backdrop.dart';
import '../../../active_conclave/presentation/round/deck_footer.dart' show roundPanel;
import '../../../active_conclave/presentation/round/person_card.dart' show PulseDot;
import '../../../active_conclave/presentation/round/round_timer.dart' show kDeckBottom;
import '../../domain/conclave_model.dart';
import 'date_tile.dart';

/// A conclave that is running now: the one red moment on the screen — the
/// same silk as the live round — with a single clear action.
class LiveConclaveCard extends StatelessWidget {
  final Conclave conclave;
  const LiveConclaveCard({super.key, required this.conclave});

  @override
  Widget build(BuildContext context) {
    final c = conclave;
    final round = c.currentRound > 0 ? 'Round ${c.currentRound} of ${c.roundCount}' : 'Starting';
    final (label, route) = c.isRegistered
        ? ('Join round', '/conclaves/${c.id}/active')
        : (c.walkInOpen || c.walkInStatus == 'pending')
            ? ('Join as walk-in', '/conclaves/${c.id}')
            : ('View conclave', '/conclaves/${c.id}');

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          const Positioned.fill(child: CardBackdrop(mood: CardMood.bio, seed: 2.2)),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.push('/conclaves/${c.id}'),
              child: Padding(
                padding: const EdgeInsets.all(Gap.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const PulseDot(),
                          const SizedBox(width: 6),
                          Text('LIVE',
                              style: context.text.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              )),
                        ]),
                      ),
                      const SizedBox(width: Gap.sm),
                      Text(round,
                          style: context.text.labelLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          )),
                    ]),
                    const SizedBox(height: Gap.md),
                    Text(
                      c.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: Gap.xs),
                    _MetaLine(icon: CoolIcons.mapPin, text: c.venueLocation, onDark: true),
                    const SizedBox(height: Gap.lg),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: () => context.push(route),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: kDeckBottom,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        child: Text(label),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A conclave still ahead: calendar tile, when and where in two quiet lines,
/// and one status — Register only when it's the thing to do.
class UpcomingConclaveCard extends StatelessWidget {
  final Conclave conclave;
  const UpcomingConclaveCard({super.key, required this.conclave});

  @override
  Widget build(BuildContext context) {
    final c = conclave;
    final canRegister = c.canRegister && !c.isRegistered;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/conclaves/${c.id}'),
        child: Ink(
          padding: const EdgeInsets.all(Gap.md),
          decoration: roundPanel(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DateTile(date: c.date),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _MetaLine(icon: CoolIcons.clock, text: conclaveWhen(c.date, c.startTime)),
                        _MetaLine(icon: CoolIcons.mapPin, text: c.venueLocation),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.md),
              Row(
                children: [
                  Expanded(child: _UpcomingStatus(conclave: c)),
                  if (canRegister)
                    FilledButton(
                      onPressed: () => context.push('/conclaves/${c.id}/register'),
                      style: FilledButton.styleFrom(
                        backgroundColor: kDeckBottom,
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      child: const Text('Register'),
                    )
                  else
                    Icon(CoolIcons.chevronRight, color: context.scheme.onSurfaceVariant),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpcomingStatus extends StatelessWidget {
  final Conclave conclave;
  const _UpcomingStatus({required this.conclave});

  @override
  Widget build(BuildContext context) {
    final c = conclave;
    final (IconData icon, String text, Color color) = c.isRegistered
        ? (
            CoolIcons.circleCheckFill,
            c.userTableNumber != null ? 'Registered  ·  Table ${c.userTableNumber}' : 'Registered',
            context.colors.success,
          )
        : c.canRegister
            ? (CoolIcons.userCheckCorner, 'Registration open', context.scheme.onSurface)
            : c.effectiveStatus == ConclaveStatus.registrationNotOpen
                ? (CoolIcons.clock, 'Registration opens soon', context.scheme.onSurfaceVariant)
                : (CoolIcons.lock, 'Registration closed', context.scheme.onSurfaceVariant);
    return Row(children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w700),
        ),
      ),
    ]);
  }
}

/// A finished conclave: a compact row. Opens your summary if you attended.
class PastConclaveRow extends StatelessWidget {
  final Conclave conclave;
  const PastConclaveRow({super.key, required this.conclave});

  @override
  Widget build(BuildContext context) {
    final c = conclave;
    final cancelled = c.effectiveStatus == ConclaveStatus.cancelled;
    final attended = c.isRegistered && !cancelled;
    final status = cancelled ? 'Cancelled' : (attended ? 'Attended' : 'Ended');
    final muted = context.scheme.onSurfaceVariant;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push(attended ? '/conclaves/${c.id}/summary' : '/conclaves/${c.id}'),
        child: Ink(
          padding: const EdgeInsets.all(Gap.md),
          decoration: roundPanel(context),
          child: Row(
            children: [
              DateTile(date: c.date, muted: true),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$status  ·  ${c.venueLocation}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(
                        color: attended ? context.colors.success : muted,
                        fontWeight: attended ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (attended) ...[
                const SizedBox(width: Gap.sm),
                _SummaryPill(onTap: () => context.push('/conclaves/${c.id}/summary')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The past-row action: a tinted pill that reads as a button, not a label.
class _SummaryPill extends StatelessWidget {
  final VoidCallback onTap;
  const _SummaryPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.brandRed.withValues(alpha: 0.08),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(CoolIcons.receipt, size: 16, color: AppColors.brandRed),
            const SizedBox(width: 6),
            Text(
              'Summary',
              style: context.text.labelLarge?.copyWith(
                color: AppColors.brandRed,
                fontWeight: FontWeight.w800,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool onDark;
  const _MetaLine({required this.icon, required this.text, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    final color = onDark ? Colors.white.withValues(alpha: 0.9) : context.scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySmall?.copyWith(color: color),
          ),
        ),
      ]),
    );
  }
}
