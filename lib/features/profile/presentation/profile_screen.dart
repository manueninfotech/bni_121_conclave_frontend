import 'package:flutter/material.dart';
import '../../../core/widgets/app_refresh.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_spinner.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/data/auth_repository.dart';
import '../../members/data/my_referrals_repository.dart';
import '../data/profile_repository.dart';
import 'package:conclave_1_2_1/core/theme/cool_icons.dart';

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

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(CoolIcons.triangleWarning, color: ctx.colors.danger),
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently deletes your account and profile — your details, '
          'networking info, referrals, and one-to-ones. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ctx.colors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    // Block the UI while the backend removes everything.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: AppSpinner(size: 46)),
    );
    try {
      await ref.read(authRepositoryProvider).deleteAccount();
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // dismiss the spinner
      context.go('/login');
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // dismiss the spinner
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);

    return Scaffold(
      // No app bar — the tinted header below carries the identity and the
      // sign-out/edit actions, and runs edge-to-edge behind the status bar (#17).
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
              icon: CoolIcons.userCloseCorner,
              title: 'Profile not found',
              message:
                  'We could not find your details. Try signing out and back '
                  'in, or contact the admin.',
              action: FilledButton(
                onPressed: () => _confirmLogout(context, ref),
                child: const Text('Sign out'),
              ),
            );
          }

          // Identity facts, rendered as clean labelled rows (not a boxy grid).
          final facts = <({IconData icon, String label, String value})>[
            if (p.membership.isNotEmpty)
              (
                icon: p.isBni ? CoolIcons.wavyCheck : CoolIcons.user,
                label: 'Membership',
                value: p.membership,
              ),
            if (p.businessCategory.isNotEmpty)
              (
                icon: CoolIcons.shapes,
                label: 'Category',
                value: p.businessCategory,
              ),
            if (p.location.isNotEmpty)
              (
                icon: CoolIcons.mapPin,
                label: 'Location',
                value: _titleCase(p.location),
              ),
            if (p.chapter != null && p.chapter!.isNotEmpty)
              (icon: CoolIcons.usersGroup, label: 'Chapter', value: p.chapter!),
            if (p.region != null && p.region!.isNotEmpty)
              (icon: CoolIcons.map, label: 'Region', value: p.region!),
            (icon: CoolIcons.globe, label: 'Country', value: p.country),
          ];

          return AppRefresh(
            onRefresh: () async => ref.invalidate(myProfileProvider),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(bottom: context.bottomInset + Gap.xl),
              children: [
                _ProfileHeader(
                  profile: p,
                  onSignOut: () => _confirmLogout(context, ref),
                ),
                const SizedBox(height: Gap.lg),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.pagePadding,
                  ),
                  child: ContentWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Key actions surfaced right under the header — not
                        // buried at the bottom where people miss them.
                        FadeSlideIn(
                          index: 1,
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _ActionTile(
                                    icon: CoolIcons.qrCode,
                                    label: 'My card',
                                    onTap: () => context.push('/profile/card'),
                                  ),
                                ),
                                const SizedBox(width: Gap.md),
                                Expanded(
                                  child: _ActionTile(
                                    icon: CoolIcons.arrowLeftRight,
                                    label: 'Referrals',
                                    onTap: () =>
                                        context.push('/profile/referrals'),
                                  ),
                                ),
                                const SizedBox(width: Gap.md),
                                Expanded(
                                  child: _ActionTile(
                                    icon: CoolIcons.coffee,
                                    label: '1-2-1s',
                                    onTap: () =>
                                        context.push('/profile/one-to-ones'),
                                  ),
                                ),
                                const SizedBox(width: Gap.md),
                                Expanded(
                                  child: _ActionTile(
                                    icon: CoolIcons.pencil,
                                    label: 'Edit',
                                    onTap: () => context.push('/profile/edit'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: Gap.lg),
                        _SectionLabel('About'),
                        const SizedBox(height: Gap.sm),
                        FadeSlideIn(index: 2, child: _AboutCard(rows: facts)),
                        if (p.lookingFor.isNotEmpty ||
                            p.canOffer.isNotEmpty) ...[
                          const SizedBox(height: Gap.lg),
                          _SectionLabel('Networking'),
                          const SizedBox(height: Gap.sm),
                          FadeSlideIn(
                            index: 3,
                            child: _NetworkingCard(profile: p),
                          ),
                        ],
                        const SizedBox(height: Gap.lg),
                        _SectionLabel('Contact'),
                        const SizedBox(height: Gap.sm),
                        FadeSlideIn(index: 4, child: _ContactCard(profile: p)),
                        const SizedBox(height: Gap.lg),
                        Center(
                          child: TextButton.icon(
                            onPressed: () =>
                                _confirmDeleteAccount(context, ref),
                            icon: Icon(
                              CoolIcons.trash,
                              color: context.colors.danger,
                            ),
                            label: Text(
                              'Delete account',
                              style: TextStyle(color: context.colors.danger),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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

/// The hero header: a soft brand-tinted banner that runs edge-to-edge behind
/// the status bar, with the avatar, identity and the member's impact stats —
/// the premium "this is me" surface that replaces the old plain app bar.
class _ProfileHeader extends ConsumerWidget {
  final UserProfile profile;
  final VoidCallback onSignOut;

  const _ProfileHeader({required this.profile, required this.onSignOut});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.scheme;
    final topInset = MediaQuery.paddingOf(context).top;

    final referrals = ref.watch(myReferralsProvider).asData?.value;
    final given = referrals?.given.length ?? 0;
    final received = referrals?.received.length ?? 0;
    final closed = (referrals?.received ?? const [])
        .where((r) => r.outcome == ReferralOutcome.closed)
        .fold<int>(0, (s, r) => s + r.closedAmount);

    final tagline = [
      if (profile.businessCategory.isNotEmpty) profile.businessCategory,
      if (profile.membership.isNotEmpty) profile.membership,
    ].join('  ·  ');

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        topInset + Gap.xs,
        context.pagePadding,
        Gap.lg,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.brandRed.withValues(alpha: 0.13),
            AppColors.brandRed.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(CoolIcons.logOut),
              tooltip: 'Sign out',
              onPressed: onSignOut,
            ),
          ),
          Hero(
            tag: 'profile-avatar',
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: scheme.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: UserAvatar(
                name: profile.name,
                photoUrl: profile.photoUrl,
                radius: 46,
              ),
            ),
          ),
          const SizedBox(height: Gap.md),
          Text(
            profile.name.isEmpty ? 'Unnamed' : profile.name,
            style: context.text.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          if (tagline.isNotEmpty) ...[
            const SizedBox(height: Gap.xs),
            Text(
              tagline,
              style: context.text.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (profile.location.isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CoolIcons.mapPin,
                  size: 14,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    _titleCase(profile.location),
                    style: context.text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: Gap.lg),
          Container(
            padding: const EdgeInsets.symmetric(
              vertical: Gap.md,
              horizontal: Gap.sm,
            ),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(Radii.lg),
              border: Border.all(color: context.colors.hairline),
            ),
            child: Row(
              children: [
                _HeaderStat(
                  icon: CoolIcons.arrowUpRight,
                  value: '$given',
                  label: 'Given',
                  onTap: () => context.push('/profile/referrals'),
                ),
                _HeaderStatDivider(),
                _HeaderStat(
                  icon: CoolIcons.arrowDownLeft,
                  value: '$received',
                  label: 'Received',
                  onTap: () => context.push('/profile/referrals'),
                ),
                _HeaderStatDivider(),
                _HeaderStat(
                  icon: CoolIcons.wavyCheck,
                  value: closed == 0
                      ? '₹0'
                      : NumberFormat.compactCurrency(
                          locale: 'en_IN',
                          symbol: '₹',
                          decimalDigits: 0,
                        ).format(closed),
                  label: 'Closed',
                  onTap: () => context.push('/profile/referrals'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final VoidCallback? onTap;

  const _HeaderStat({
    required this.icon,
    required this.value,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Gap.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.brandRed),
              const SizedBox(height: Gap.xs),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                label,
                style: context.text.labelSmall?.copyWith(
                  color: context.scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderStatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 34, color: context.colors.hairline);
  }
}

/// A small all-caps label that heads a section.
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: context.text.labelSmall?.copyWith(
        color: context.scheme.onSurfaceVariant,
        letterSpacing: 0.9,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

/// Identity facts as clean labelled rows in a single card — replaces the old
/// boxy two-column grid.
class _AboutCard extends StatelessWidget {
  final List<({IconData icon, String label, String value})> rows;
  const _AboutCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.xs),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: Gap.lg,
                  endIndent: Gap.lg,
                  color: context.colors.hairline,
                ),
              _AboutRow(row: rows[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final ({IconData icon, String label, String value}) row;
  const _AboutRow({required this.row});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
      child: Row(
        children: [
          Icon(row.icon, size: 18, color: context.scheme.onSurfaceVariant),
          const SizedBox(width: Gap.md),
          Text(
            row.label,
            style: context.text.bodyMedium?.copyWith(
              color: context.scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              row.value,
              textAlign: TextAlign.right,
              style: context.text.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
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
              icon: CoolIcons.mobile,
              label: 'Phone',
              value: profile.phone.isEmpty ? 'Not set' : profile.phone,
            ),
            InfoRow(
              icon: CoolIcons.mention,
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
            horizontal: Gap.sm,
            vertical: Gap.lg,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: context.scheme.primary),
              const SizedBox(height: Gap.sm),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
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
                icon: CoolIcons.search,
                label: 'Looking for',
                value: profile.lookingFor,
              ),
            if (profile.canOffer.isNotEmpty)
              InfoRow(
                icon: CoolIcons.handCoins,
                label: 'Can offer',
                value: profile.canOffer,
              ),
          ],
        ),
      ),
    );
  }
}
