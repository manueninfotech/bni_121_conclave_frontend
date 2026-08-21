import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/data/auth_repository.dart';
import '../data/members_repository.dart';
import 'propose_one_to_one.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Member')),
      body: members.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: 'Could not load this member.',
          detail: e.toString(),
          onRetry: () => ref.invalidate(membersProvider),
        ),
        data: (all) {
          final myUid = ref.watch(authStateProvider).asData?.value?.uid;
          final member = all.where((m) => m.uid == memberId).firstOrNull;
          if (member == null) {
            return EmptyView(
              icon: Icons.person_off_outlined,
              title: 'Member not found',
              message: 'They may have left, or the directory has moved on.',
              action: FilledButton(
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go('/members'),
                child: const Text('Back to members'),
              ),
            );
          }
          return _Detail(member: member, isSelf: member.uid == myUid);
        },
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  final Member member;
  final bool isSelf;
  const _Detail({required this.member, required this.isSelf});

  @override
  Widget build(BuildContext context) {
    return ContentWidth(
      child: ListView(
        padding: context.pageInsets,
        children: [
          const SizedBox(height: Gap.md),
          Center(
            child: UserAvatar(
              name: member.name,
              photoUrl: member.photoUrl,
              radius: 52,
            ),
          ),
          const SizedBox(height: Gap.lg),
          Text(
            member.name,
            textAlign: TextAlign.center,
            style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (member.businessCategory.isNotEmpty) ...[
            const SizedBox(height: Gap.sm),
            Center(
              child: StatusBadge(
                label: member.businessCategory,
                tone: StatusTone.info,
                icon: Icons.category_outlined,
              ),
            ),
          ],
          const SizedBox(height: Gap.xl),

          if (!isSelf) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => showProposeOneToOne(
                  context,
                  toUserId: member.uid,
                  toName: member.name.isEmpty ? 'this member' : member.name,
                ),
                icon: const Icon(Icons.coffee_outlined),
                label: const Text('Request a 1-2-1'),
              ),
            ),
            const SizedBox(height: Gap.md),
          ],

          Card(
            child: Padding(
              padding: const EdgeInsets.all(Gap.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (member.membership.isNotEmpty)
                    InfoRow(
                      icon: member.isBni
                          ? Icons.verified_outlined
                          : Icons.person_outline,
                      label: 'Membership',
                      value: member.membership,
                    ),
                  if (member.businessName.isNotEmpty)
                    InfoRow(
                      icon: Icons.business_outlined,
                      label: 'Business',
                      value: member.businessName,
                    ),
                  if (member.location.isNotEmpty)
                    InfoRow(
                      icon: Icons.place_outlined,
                      label: 'Location',
                      value: _titleCase(member.location),
                    ),
                  if (member.chapter != null && member.chapter!.isNotEmpty)
                    InfoRow(
                      icon: Icons.groups_2_outlined,
                      label: 'Chapter',
                      value: member.chapter!,
                    ),
                  if (member.region != null && member.region!.isNotEmpty)
                    InfoRow(
                      icon: Icons.map_outlined,
                      label: 'Region',
                      value: member.region!,
                    ),
                ],
              ),
            ),
          ),

          if (member.lookingFor.isNotEmpty) ...[
            const SizedBox(height: Gap.md),
            _MatchCard(
              icon: Icons.search_rounded,
              title: 'Looking for',
              body: member.lookingFor,
            ),
          ],
          if (member.canOffer.isNotEmpty) ...[
            const SizedBox(height: Gap.md),
            _MatchCard(
              icon: Icons.volunteer_activism_outlined,
              title: 'Can offer',
              body: member.canOffer,
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

/// A "looking for" / "can offer" panel — the matchmaking signal on a profile.
class _MatchCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _MatchCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: context.scheme.primary),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: context.text.labelSmall?.copyWith(
                      color: context.scheme.onSurfaceVariant,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: Gap.xs),
                  Text(body, style: context.text.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
