import 'package:flutter/material.dart';
import '../../../core/widgets/app_refresh.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/data/auth_repository.dart';
import '../data/profile_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    // Signing out at a live event means re-authenticating in a room with no
    // signal. Worth one tap of confirmation.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again to take part in a conclave.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(authRepositoryProvider).logout();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => _confirmLogout(context, ref),
          ),
        ],
      ),
      body: profile.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: 'Could not load your profile.',
          detail: e.toString(),
          onRetry: () => ref.invalidate(myProfileProvider),
        ),
        data: (p) {
          if (p == null) {
            return EmptyView(
              icon: Icons.person_off_outlined,
              title: 'Profile not found',
              message: 'We could not find your details. Try signing out and back '
                  'in, or contact the admin.',
              action: FilledButton(
                onPressed: () => _confirmLogout(context, ref),
                child: const Text('Sign out'),
              ),
            );
          }

          // The short facts that read well as compact tiles.
          final facts = <Widget>[
            if (p.membership.isNotEmpty)
              _FactTile(
                icon: p.isBni ? Icons.verified_outlined : Icons.person_outline,
                label: 'Membership',
                value: p.membership,
              ),
            if (p.businessCategory.isNotEmpty)
              _FactTile(
                icon: Icons.category_outlined,
                label: 'Category',
                value: p.businessCategory,
              ),
            if (p.location.isNotEmpty)
              _FactTile(
                icon: Icons.place_outlined,
                label: 'Location',
                value: _titleCase(p.location),
              ),
            if (p.chapter != null && p.chapter!.isNotEmpty)
              _FactTile(
                icon: Icons.groups_2_outlined,
                label: 'Chapter',
                value: p.chapter!,
              ),
            if (p.region != null && p.region!.isNotEmpty)
              _FactTile(
                icon: Icons.map_outlined,
                label: 'Region',
                value: p.region!,
              ),
            _FactTile(
              icon: Icons.public,
              label: 'Country',
              value: p.country,
            ),
          ];

          return AppRefresh(
            onRefresh: () async => ref.invalidate(myProfileProvider),
            child: ContentWidth(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: context.tabScrollInsets,
                children: [
                  FadeSlideIn(index: 0, child: _IdentityCard(profile: p)),
                  const SizedBox(height: Gap.md),

                  FadeSlideIn(index: 1, child: _FactGrid(tiles: facts)),
                  const SizedBox(height: Gap.md),

                  if (p.lookingFor.isNotEmpty || p.canOffer.isNotEmpty) ...[
                    FadeSlideIn(
                      index: 2,
                      child: _NetworkingCard(profile: p),
                    ),
                    const SizedBox(height: Gap.md),
                  ],

                  FadeSlideIn(index: 2, child: _ContactCard(profile: p)),
                  const SizedBox(height: Gap.md),

                  FadeSlideIn(
                    index: 3,
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: context.scheme.secondaryContainer,
                          child: Icon(Icons.coffee_outlined,
                              color: context.scheme.onSecondaryContainer),
                        ),
                        title: const Text('My 1-2-1s'),
                        subtitle: const Text('One-to-one meetings you\'ve set up'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push('/profile/one-to-ones'),
                      ),
                    ),
                  ),
                  const SizedBox(height: Gap.md),

                  FadeSlideIn(
                    index: 4,
                    child: Row(
                      children: [
                        Expanded(
                          child: _ActionTile(
                            icon: Icons.swap_horiz_rounded,
                            label: 'Referrals',
                            onTap: () => context.push('/profile/referrals'),
                          ),
                        ),
                        const SizedBox(width: Gap.md),
                        Expanded(
                          child: _ActionTile(
                            icon: Icons.qr_code_2_rounded,
                            label: 'My card',
                            onTap: () => context.push('/profile/card'),
                          ),
                        ),
                        const SizedBox(width: Gap.md),
                        Expanded(
                          child: _ActionTile(
                            icon: Icons.edit_outlined,
                            label: 'Edit',
                            onTap: () => context.push('/profile/edit'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

String _titleCase(String s) => s
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

/// Avatar + identity in one compact horizontal card.
class _IdentityCard extends StatelessWidget {
  final UserProfile profile;
  const _IdentityCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Row(
          children: [
            Hero(
              tag: 'profile-avatar',
              child: UserAvatar(
                name: profile.name,
                photoUrl: profile.photoUrl,
                radius: 34,
              ),
            ),
            const SizedBox(width: Gap.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    profile.name.isEmpty ? 'Unnamed' : profile.name,
                    style: context.text.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (profile.businessName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      profile.businessName,
                      style: context.text.bodyMedium
                          ?.copyWith(color: context.scheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A short fact as a small stat card.
class _FactTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _FactTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: context.scheme.onSurfaceVariant),
            const SizedBox(height: Gap.sm),
            Text(
              label.toUpperCase(),
              style: context.text.labelSmall?.copyWith(
                color: context.scheme.onSurfaceVariant,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Lays fact tiles out two per row. Cheap and predictable — no GridView inside a
/// scroll view, no intrinsic-height passes.
class _FactGrid extends StatelessWidget {
  final List<Widget> tiles;
  const _FactGrid({required this.tiles});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      final left = tiles[i];
      final right = i + 1 < tiles.length ? tiles[i + 1] : null;
      // IntrinsicHeight bounds the row's height (the ListView gives it an
      // unbounded one), which is what lets the two tiles share a height via
      // stretch instead of each demanding infinite height.
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: left),
            const SizedBox(width: Gap.md),
            // An empty slot keeps a lone tile at half width instead of stretching.
            Expanded(child: right ?? const SizedBox()),
          ],
        ),
      ));
      if (i + 2 < tiles.length) rows.add(const SizedBox(height: Gap.md));
    }
    return Column(children: rows);
  }
}

/// Contact — kept as full-width rows because emails and numbers are long.
class _ContactCard extends StatelessWidget {
  final UserProfile profile;
  const _ContactCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CONTACT',
              style: context.text.labelSmall?.copyWith(
                color: context.scheme.onSurfaceVariant,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: Gap.sm),
            InfoRow(
              icon: Icons.phone_iphone_rounded,
              label: 'Phone',
              value: profile.phone.isEmpty ? 'Not set' : profile.phone,
            ),
            InfoRow(
              icon: Icons.alternate_email_rounded,
              label: 'Email',
              // Never surface the synthetic sign-in address.
              value: profile.email.isEmpty ? 'Not set' : profile.email,
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact tappable card — icon over label.
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.md,
            vertical: Gap.lg,
          ),
          child: Column(
            children: [
              Icon(icon, color: context.scheme.primary),
              const SizedBox(height: Gap.sm),
              Text(
                label,
                style: context.text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The member's own matchmaking signals — what they're looking for and can offer.
class _NetworkingCard extends StatelessWidget {
  final UserProfile profile;
  const _NetworkingCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NETWORKING',
              style: context.text.labelSmall?.copyWith(
                color: context.scheme.onSurfaceVariant,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: Gap.sm),
            if (profile.lookingFor.isNotEmpty)
              InfoRow(
                icon: Icons.search_rounded,
                label: 'Looking for',
                value: profile.lookingFor,
              ),
            if (profile.canOffer.isNotEmpty)
              InfoRow(
                icon: Icons.volunteer_activism_outlined,
                label: 'Can offer',
                value: profile.canOffer,
              ),
          ],
        ),
      ),
    );
  }
}
