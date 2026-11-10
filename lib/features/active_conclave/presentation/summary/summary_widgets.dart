import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../domain/active_conclave_models.dart';
import '../../domain/referral_models.dart';
import '../round/deck_footer.dart' show roundPanel;
import 'package:conclave_1_2_1/core/theme/cool_icons.dart';

/// The three referral numbers in one white card, with the sync state as a quiet
/// line underneath — loud only when something is still waiting to upload.
class SummaryStats extends StatelessWidget {
  final ReferralSummary referrals;
  final int pendingSync;

  const SummaryStats({
    super.key,
    required this.referrals,
    required this.pendingSync,
  });

  @override
  Widget build(BuildContext context) {
    final muted = context.scheme.onSurfaceVariant;
    final divider = Container(
      width: 1,
      height: 40,
      color: context.scheme.outlineVariant.withValues(alpha: 0.6),
    );
    final synced = pendingSync == 0;
    final warn = context.colors.warning;

    return Container(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.lg, Gap.md, Gap.md),
      decoration: roundPanel(context, radius: 22),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _Number('${referrals.givenCount}', 'Given')),
              divider,
              Expanded(
                child: _Number('${referrals.receivedCount}', 'Received'),
              ),
              divider,
              Expanded(child: _Number('${referrals.mutualCount}', 'Mutual')),
            ],
          ),
          const SizedBox(height: Gap.md),
          Divider(
            height: 1,
            color: context.scheme.outlineVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: Gap.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                synced ? CoolIcons.cloudCheck : CoolIcons.cloudUpload,
                size: 16,
                color: synced ? context.colors.success : warn,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  synced
                      ? 'Everything is saved'
                      : '$pendingSync still uploading — keep the app installed',
                  style: context.text.labelMedium?.copyWith(
                    color: synced ? muted : warn,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Number extends StatelessWidget {
  final String value;
  final String label;
  const _Number(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: context.text.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: context.scheme.onSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          label.toUpperCase(),
          style: context.text.labelSmall?.copyWith(
            color: context.scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

/// Small caps section heading with an optional right-hand note or action.
class SummarySection extends StatelessWidget {
  final String title;
  final String? note;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SummarySection(
    this.title, {
    super.key,
    this.note,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final muted = context.scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(left: Gap.xs, bottom: Gap.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: context.text.labelMedium?.copyWith(
                color: muted,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          if (note != null)
            Text(
              note!,
              style: context.text.labelMedium?.copyWith(
                color: muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: context.scheme.onSurface,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(
                actionLabel!,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

/// A round photo, or the person's initial when there is none.
class SummaryAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double size;

  const SummaryAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final initial = Text(
      name.isEmpty ? '?' : name[0].toUpperCase(),
      style: TextStyle(
        fontSize: size * 0.4,
        fontWeight: FontWeight.w700,
        color: context.scheme.onSurfaceVariant,
      ),
    );
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.scheme.surfaceContainerHighest,
      ),
      child: photoUrl == null
          ? initial
          : Image.network(
              photoUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => initial,
            ),
    );
  }
}

/// The people they sat with: faces, who they are, and one clear Save action.
class SummaryPeople extends StatelessWidget {
  final List<ScheduleParticipant> people;
  final VoidCallback onOpen;

  const SummaryPeople({super.key, required this.people, required this.onOpen});

  String get _names {
    final first = [for (final p in people) p.name.split(' ').first];
    if (first.isEmpty) return '';
    if (first.length == 1) return first.first;
    if (first.length == 2) return '${first[0]} and ${first[1]}';
    return '${first[0]}, ${first[1]} and ${first.length - 2} more';
  }

  @override
  Widget build(BuildContext context) {
    const shown = 3;
    const size = 36.0;
    const step = 24.0;
    final faces = people.take(shown).toList();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onOpen,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.sm, Gap.md),
          decoration: roundPanel(context),
          child: Row(children: [
            SizedBox(
              width: size + step * (faces.length - 1) + 4,
              height: size + 4,
              child: Stack(children: [
                for (var i = 0; i < faces.length; i++)
                  Positioned(
                    left: i * step,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.scheme.surfaceContainerLowest,
                      ),
                      child: SummaryAvatar(
                        name: faces[i].name,
                        photoUrl: faces[i].photoUrl,
                        size: size,
                      ),
                    ),
                  ),
              ]),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Text(
                _names,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: Gap.sm),
            Material(
              color: AppColors.brandRed.withValues(alpha: 0.08),
              shape: const StadiumBorder(),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: onOpen,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(CoolIcons.userPlusCorner, size: 16, color: AppColors.brandRed),
                    const SizedBox(width: 6),
                    Text(
                      'Save',
                      style: context.text.labelLarge?.copyWith(
                        color: AppColors.brandRed,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Where they sat each round, as a compact timeline.
class SummaryRounds extends StatelessWidget {
  final List<
    ({int round, int table, bool captain, int tablemates, bool? present})
  >
  stops;

  const SummaryRounds({super.key, required this.stops});

  @override
  Widget build(BuildContext context) {
    final muted = context.scheme.onSurfaceVariant;
    final ink = context.scheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: Gap.xs),
      decoration: roundPanel(context),
      child: Column(
        children: [
          for (var i = 0; i < stops.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.md,
                vertical: Gap.sm + 2,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.scheme.surfaceContainerHighest,
                    ),
                    child: Text(
                      '${stops[i].round}',
                      style: context.text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Table ${stops[i].table}'
                          '${stops[i].captain ? '  ·  Captain' : ''}',
                          style: context.text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Round ${stops[i].round}  ·  '
                          '${stops[i].tablemates} at the table',
                          style: context.text.bodySmall?.copyWith(color: muted),
                        ),
                      ],
                    ),
                  ),
                  if (stops[i].present != null)
                    _PresenceTag(present: stops[i].present!),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PresenceTag extends StatelessWidget {
  final bool present;
  const _PresenceTag({required this.present});

  @override
  Widget build(BuildContext context) {
    final color = present
        ? context.colors.success
        : context.scheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          present ? CoolIcons.circleCheckFill : CoolIcons.circleMinus,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          present ? 'Present' : 'Missed',
          style: context.text.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Referrals for one direction, grouped by round, one white card per round.
class SummaryReferrals extends StatelessWidget {
  final List<Referral> referrals;
  final bool outgoing;
  final bool Function(String uid) isMutual;

  const SummaryReferrals({
    super.key,
    required this.referrals,
    required this.outgoing,
    required this.isMutual,
  });

  @override
  Widget build(BuildContext context) {
    final byRound = <int, List<Referral>>{};
    for (final r in referrals) {
      (byRound[r.roundNumber] ??= []).add(r);
    }
    final rounds = byRound.keys.toList()..sort();
    final muted = context.scheme.onSurfaceVariant;

    return Column(
      children: [
        for (final round in rounds) ...[
          Container(
            margin: const EdgeInsets.only(bottom: Gap.sm),
            padding: const EdgeInsets.fromLTRB(
              Gap.md,
              Gap.sm + 2,
              Gap.md,
              Gap.xs,
            ),
            decoration: roundPanel(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ROUND $round',
                  style: context.text.labelSmall?.copyWith(
                    color: muted,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                for (final r in byRound[round]!)
                  _ReferralLine(
                    r: r,
                    outgoing: outgoing,
                    mutual: isMutual(outgoing ? r.toUserId : r.fromUserId),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ReferralLine extends StatelessWidget {
  final Referral r;
  final bool outgoing;
  final bool mutual;

  const _ReferralLine({
    required this.r,
    required this.outgoing,
    required this.mutual,
  });

  @override
  Widget build(BuildContext context) {
    final muted = context.scheme.onSurfaceVariant;
    final name = r.otherName.isNotEmpty ? r.otherName : 'Unknown participant';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SummaryAvatar(name: name, size: 36),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (mutual) ...[
                      const SizedBox(width: Gap.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: context.scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Mutual',
                          style: context.text.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: muted,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (r.otherBusinessName.isNotEmpty)
                  Text(
                    r.otherBusinessName,
                    style: context.text.bodySmall?.copyWith(color: muted),
                  ),
                if (r.notes.isNotEmpty) ...[
                  const SizedBox(height: Gap.xs),
                  Text(
                    r.notes,
                    style: context.text.bodySmall?.copyWith(
                      color: context.scheme.onSurface,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (outgoing) ...[
            const SizedBox(width: Gap.sm),
            Tooltip(
              message: r.synced ? 'Saved to the server' : 'Waiting to upload',
              child: Icon(
                r.synced ? CoolIcons.cloudCheck : CoolIcons.cloudUpload,
                size: 16,
                color: r.synced
                    ? context.colors.success
                    : context.colors.warning,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A calm empty line inside a section.
class SummaryEmpty extends StatelessWidget {
  final String text;
  const SummaryEmpty(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(Gap.md),
    decoration: roundPanel(context),
    child: Text(
      text,
      style: context.text.bodySmall?.copyWith(
        color: context.scheme.onSurfaceVariant,
      ),
    ),
  );
}
