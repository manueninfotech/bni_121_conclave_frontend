import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/page_kit.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/data/auth_repository.dart';
import '../data/members_repository.dart';
import '../data/one_to_ones_repository.dart';
import 'propose_one_to_one.dart';
import 'package:conclave_1_2_1/core/theme/cool_icons.dart';

/// One member's public profile.
///
/// Resolved from the already-loaded directory rather than a second request —
/// the same pattern the conclave detail screen uses. Shows only the safe,
/// public fields; there is nothing to contact them with here by design.
class MemberDetailScreen extends ConsumerWidget {
  final String memberId;

  const MemberDetailScreen({super.key, required this.memberId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(membersProvider);

    final all = members.asData?.value;
    final myUid = ref.watch(authStateProvider).asData?.value?.uid;
    final oneToOnes = ref.watch(myOneToOnesProvider).asData?.value ?? const [];
    final m = all?.where((x) => x.uid == memberId).firstOrNull;
    final pending =
        m != null &&
        oneToOnes.any(
          (x) =>
              x.sent &&
              x.otherUserId == m.uid &&
              x.status == OneToOneStatus.pending,
        );

    return AppPage(
      title: 'Member',
      // The one thing to do here: ask for a 1-2-1.
      action: (m == null || m.uid == myUid)
          ? null
          : AppPrimaryButton(
              label: pending ? 'Request pending' : 'Request a 1-2-1',
              icon: pending ? CoolIcons.hourglass : CoolIcons.coffee,
              onPressed: pending
                  ? null
                  : () => showProposeOneToOne(
                      context,
                      toUserId: m.uid,
                      toName: m.name.isEmpty ? 'this member' : m.name,
                    ),
            ),
      body: members.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: 'Could not load this member.',
          detail: e.toString(),
          onRetry: () => ref.invalidate(membersProvider),
        ),
        data: (_) {
          final member = m;
          if (member == null) {
            return EmptyView(
              icon: CoolIcons.userCloseCorner,
              title: 'Member not found',
              message: 'They may have left, or the directory has moved on.',
              action: FilledButton(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/members'),
                child: const Text('Back to members'),
              ),
            );
          }
          return _Detail(member: member);
        },
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  final Member member;
  const _Detail({required this.member});

  @override
  Widget build(BuildContext context) {
    final facts = <Widget>[
      if (member.businessName.isNotEmpty)
        DetailRow(
          icon: CoolIcons.building2,
          label: 'Business',
          value: member.businessName,
        ),
      if (member.location.isNotEmpty)
        DetailRow(
          icon: CoolIcons.mapPin,
          label: 'Location',
          value: _titleCase(member.location),
        ),
      if (member.membership.isNotEmpty)
        DetailRow(
          icon: member.isBni ? CoolIcons.wavyCheck : CoolIcons.user,
          label: 'Membership',
          value: member.membership,
        ),
      if (member.chapter != null && member.chapter!.isNotEmpty)
        DetailRow(
          icon: CoolIcons.usersGroup,
          label: 'Chapter',
          value: member.chapter!,
        ),
      if (member.region != null && member.region!.isNotEmpty)
        DetailRow(icon: CoolIcons.map, label: 'Region', value: member.region!),
    ];

    return ContentWidth(
      max: 520,
      child: ListView(
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          context.pagePadding,
          Gap.lg,
          context.pagePadding,
          Gap.xl,
        ),
        children: [
          // Who they are, on one card.
          Container(
            padding: const EdgeInsets.all(Gap.xl),
            decoration: pagePanel(context, radius: 28),
            child: Column(
              children: [
                UserAvatar(
                  name: member.name,
                  photoUrl: member.photoUrl,
                  radius: 44,
                ),
                const SizedBox(height: Gap.md),
                Text(
                  member.name,
                  textAlign: TextAlign.center,
                  style: context.text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                if (member.businessCategory.isNotEmpty) ...[
                  const SizedBox(height: Gap.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: kActionRed.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      member.businessCategory,
                      style: context.text.labelLarge?.copyWith(
                        color: kActionRed,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (facts.isNotEmpty) ...[
            const SizedBox(height: Gap.xl),
            const SectionLabel('Details'),
            SectionCard(children: facts),
          ],
          if (member.lookingFor.isNotEmpty || member.canOffer.isNotEmpty) ...[
            const SizedBox(height: Gap.xl),
            const SectionLabel('Networking'),
            SectionCard(
              children: [
                if (member.lookingFor.isNotEmpty)
                  _MatchRow(
                    icon: CoolIcons.search,
                    title: 'Looking for',
                    body: member.lookingFor,
                  ),
                if (member.canOffer.isNotEmpty)
                  _MatchRow(
                    icon: CoolIcons.handCoins,
                    title: 'Can offer',
                    body: member.canOffer,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _titleCase(String s) => s
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

/// A "looking for" / "can offer" row: the matchmaking signal on a profile.
class _MatchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _MatchRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconChip(icon: icon),
        const SizedBox(width: Gap.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: context.text.labelMedium?.copyWith(
                  color: context.scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(body, style: context.text.bodyMedium?.copyWith(height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}
