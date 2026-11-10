import 'package:flutter/material.dart';
import '../../../core/widgets/app_spinner.dart';
import '../../../core/widgets/app_refresh.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../conclaves/data/conclave_repository.dart';
import '../../conclaves/domain/conclave_model.dart';
import '../../members/data/my_referrals_repository.dart';
import '../../members/data/one_to_ones_repository.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../profile/data/profile_repository.dart';
import 'package:conclave_1_2_1/core/theme/cool_icons.dart';

/// The landing hub: what's happening for this member right now — their next
/// conclave, pending 1-2-1 requests, and the business they've generated —
/// instead of dropping them straight into a list.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).asData?.value;
    final firstName = (profile?.name ?? '').split(' ').first;

    return Scaffold(
      // No app bar — a tinted greeting header (with the notification bell) leads
      // the screen and runs edge-to-edge behind the status bar (#17 / #13).
      body: AppRefresh(
        onRefresh: () async {
          ref.invalidate(conclavesStreamProvider);
          ref.invalidate(myOneToOnesProvider);
          ref.invalidate(myReferralsProvider);
          ref.invalidate(notificationsProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: context.bottomInset + Gap.xl),
          children: [
            _HomeHeader(
              greeting: _greeting(),
              firstName: firstName,
              profile: profile,
            ),
            const SizedBox(height: Gap.lg),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
              child: ContentWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _NextConclave(),
                    const SizedBox(height: Gap.lg),
                    const _HomeSectionLabel('Your impact'),
                    const SizedBox(height: Gap.sm),
                    const _ImpactCard(),
                    const SizedBox(height: Gap.lg),
                    const _HomeSectionLabel('Quick actions'),
                    const SizedBox(height: Gap.sm),
                    const _QuickActions(),
                    const SizedBox(height: Gap.lg),
                    const _PendingOneToOnes(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tinted greeting hero — avatar, time-of-day greeting, first name and the
/// notification bell. The premium top surface that replaces the plain app bar.
class _HomeHeader extends StatelessWidget {
  final String greeting;
  final String firstName;
  final UserProfile? profile;
  const _HomeHeader({
    required this.greeting,
    required this.firstName,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        topInset + Gap.md,
        context.pagePadding,
        Gap.xl,
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
      child: Row(
        children: [
          UserAvatar(
            name: profile?.name ?? '',
            photoUrl: profile?.photoUrl,
            radius: 26,
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: context.text.bodyMedium?.copyWith(
                    color: context.scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  firstName.isEmpty ? 'Welcome' : firstName,
                  style: context.text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const _NotificationBell(),
        ],
      ),
    );
  }
}

class _HomeSectionLabel extends StatelessWidget {
  final String text;
  const _HomeSectionLabel(this.text);

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

/// Referral impact — given, received, business closed — from real data.
class _ImpactCard extends ConsumerWidget {
  const _ImpactCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final referrals = ref.watch(myReferralsProvider).asData?.value;
    final given = referrals?.given.length ?? 0;
    final received = referrals?.received.length ?? 0;
    final closed = (referrals?.received ?? const [])
        .where((r) => r.outcome == ReferralOutcome.closed)
        .fold<int>(0, (s, r) => s + r.closedAmount);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: Gap.md, horizontal: Gap.sm),
      decoration: BoxDecoration(
        color: context.scheme.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: context.colors.hairline),
      ),
      child: Row(
        children: [
          _ImpactStat(
            icon: CoolIcons.arrowUpRight,
            value: '$given',
            label: 'Given',
            onTap: () => context.push('/profile/referrals'),
          ),
          _ImpactDivider(),
          _ImpactStat(
            icon: CoolIcons.arrowDownLeft,
            value: '$received',
            label: 'Received',
            onTap: () => context.push('/profile/referrals'),
          ),
          _ImpactDivider(),
          _ImpactStat(
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
    );
  }
}

class _ImpactStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final VoidCallback onTap;
  const _ImpactStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.onTap,
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

class _ImpactDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 34, color: context.colors.hairline);
}

/// Common shortcuts, surfaced so the hub actually sends people somewhere.
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _HomeActionTile(
              icon: CoolIcons.qrCode,
              label: 'My card',
              onTap: () => context.push('/profile/card'),
            ),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: _HomeActionTile(
              icon: CoolIcons.usersGroup,
              label: 'Members',
              onTap: () => context.go('/members'),
            ),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: _HomeActionTile(
              icon: CoolIcons.arrowLeftRight,
              label: 'Referrals',
              onTap: () => context.push('/profile/referrals'),
            ),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: _HomeActionTile(
              icon: CoolIcons.coffee,
              label: '1-2-1s',
              onTap: () => context.push('/profile/one-to-ones'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _HomeActionTile({
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
            horizontal: Gap.xs,
            vertical: Gap.md,
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
                style: context.text.labelMedium?.copyWith(
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

class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);
    return IconButton(
      tooltip: 'Notifications',
      onPressed: () => context.push('/notifications'),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text('$unread'),
        child: const Icon(CoolIcons.bell),
      ),
    );
  }
}

/// The soonest live-or-upcoming conclave.
class _NextConclave extends ConsumerWidget {
  const _NextConclave();

  Conclave? _pick(List<Conclave> all) {
    final live = all.where((c) => c.status == ConclaveStatus.running).toList();
    if (live.isNotEmpty) return live.first;
    final upcoming =
        all
            .where(
              (c) =>
                  c.status != ConclaveStatus.completed &&
                  c.status != ConclaveStatus.cancelled,
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    return upcoming.isNotEmpty ? upcoming.first : null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(conclavesStreamProvider);
    return async.when(
      loading: () => const _SectionCard(
        title: 'NEXT UP',
        child: SizedBox(height: 40, child: Center(child: AppSpinner(size: 28))),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (all) {
        final c = _pick(all);
        if (c == null) {
          return const _SectionCard(
            title: 'NEXT UP',
            child: Text('No upcoming conclaves yet.'),
          );
        }
        final live = c.status == ConclaveStatus.running;
        return _SectionCard(
          title: live ? 'LIVE NOW' : 'NEXT UP',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.name,
                style: context.text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${c.venueLocation}  ·  ${DateFormat('EEE, MMM d').format(c.date)}',
                style: context.text.bodySmall?.copyWith(
                  color: context.scheme.onSurfaceVariant,
                ),
              ),
              // As soon as the schedule is locked, the member's Round-1 table is
              // known — surface it here so they see where to go before Round 1
              // even starts (manager's R2), not only once the round is live.
              if (c.isRegistered && c.userTableNumber != null) ...[
                const SizedBox(height: Gap.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gap.md,
                    vertical: Gap.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandRed.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        CoolIcons.armchair,
                        size: 18,
                        color: AppColors.brandRed,
                      ),
                      const SizedBox(width: Gap.sm),
                      Expanded(
                        child: Text(
                          live
                              ? 'Your table — Table ${c.userTableNumber}'
                              : 'Go to Table ${c.userTableNumber} for Round 1',
                          style: context.text.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: context.scheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: Gap.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.push(
                    live && c.isRegistered
                        ? '/conclaves/${c.id}/active'
                        : '/conclaves/${c.id}',
                  ),
                  icon: Icon(live ? CoolIcons.playFill : CoolIcons.arrowRight),
                  label: Text(
                    live && c.isRegistered ? 'Join active round' : 'View',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PendingOneToOnes extends ConsumerWidget {
  const _PendingOneToOnes();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oneToOnes = ref.watch(myOneToOnesProvider).asData?.value ?? const [];
    final pending = oneToOnes
        .where((m) => !m.sent && m.status == OneToOneStatus.pending)
        .toList();
    if (pending.isEmpty) return const SizedBox.shrink();

    return _SectionCard(
      title: 'AWAITING YOUR REPLY',
      onTap: () => context.push('/profile/one-to-ones'),
      child: Column(
        children: [
          for (final m in pending.take(3))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(CoolIcons.coffee),
              title: Text(m.otherName.isEmpty ? 'A member' : m.otherName),
              subtitle: Text(
                m.proposedAt == null
                    ? '1-2-1 request'
                    : DateFormat('EEE, MMM d · h:mm a').format(m.proposedAt!),
              ),
              trailing: const Icon(CoolIcons.chevronRight),
              onTap: () => context.push('/profile/one-to-ones'),
            ),
        ],
      ),
    );
  }
}

// ---- small shared bits ----------------------------------------------------

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback? onTap;
  const _SectionCard({required this.title, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: context.text.labelSmall?.copyWith(
                  color: context.scheme.onSurfaceVariant,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: Gap.sm),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
