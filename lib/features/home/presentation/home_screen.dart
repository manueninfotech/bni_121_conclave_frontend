import 'package:flutter/material.dart';
import '../../../core/widgets/app_refresh.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/responsive.dart';
import '../../conclaves/data/conclave_repository.dart';
import '../../conclaves/domain/conclave_model.dart';
import '../../members/data/my_referrals_repository.dart';
import '../../members/data/one_to_ones_repository.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../profile/data/profile_repository.dart';

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
      appBar: AppBar(
        title: const Text('Home'),
        actions: const [_NotificationBell()],
      ),
      body: AppRefresh(
        onRefresh: () async {
          ref.invalidate(conclavesStreamProvider);
          ref.invalidate(myOneToOnesProvider);
          ref.invalidate(myReferralsProvider);
          ref.invalidate(notificationsProvider);
        },
        child: ContentWidth(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: context.tabScrollInsets,
            children: [
              Text(
                firstName.isEmpty ? _greeting() : '${_greeting()}, $firstName',
                style: context.text.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: Gap.lg),
              const _NextConclave(),
              const SizedBox(height: Gap.md),
              const _StatsRow(),
              const SizedBox(height: Gap.md),
              const _PendingOneToOnes(),
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
        child: const Icon(Icons.notifications_none_rounded),
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
    final upcoming = all
        .where((c) =>
            c.status != ConclaveStatus.completed &&
            c.status != ConclaveStatus.cancelled)
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
        child: SizedBox(
          height: 40,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
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
                style: context.text.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                '${c.venueLocation}  ·  ${DateFormat('EEE, MMM d').format(c.date)}',
                style: context.text.bodySmall
                    ?.copyWith(color: context.scheme.onSurfaceVariant),
              ),
              const SizedBox(height: Gap.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.push(
                    live && c.isRegistered
                        ? '/conclaves/${c.id}/active'
                        : '/conclaves/${c.id}',
                  ),
                  icon: Icon(live ? Icons.play_arrow_rounded : Icons.arrow_forward_rounded),
                  label: Text(live && c.isRegistered ? 'Join active round' : 'View'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatsRow extends ConsumerWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oneToOnes = ref.watch(myOneToOnesProvider).asData?.value ?? const [];
    final pending = oneToOnes
        .where((m) => !m.sent && m.status == OneToOneStatus.pending)
        .length;

    final referrals = ref.watch(myReferralsProvider).asData?.value;
    final closed = (referrals?.received ?? const [])
        .where((r) => r.outcome == ReferralOutcome.closed)
        .fold<int>(0, (s, r) => s + r.closedAmount);

    return Row(
      children: [
        Expanded(
          child: _StatTile(
            value: '$pending',
            label: 'Pending 1-2-1s',
            icon: Icons.coffee_outlined,
            onTap: () => context.push('/profile/one-to-ones'),
          ),
        ),
        const SizedBox(width: Gap.md),
        Expanded(
          child: _StatTile(
            value: '₹${NumberFormat.decimalPattern('en_IN').format(closed)}',
            label: 'Business closed',
            icon: Icons.verified_outlined,
            onTap: () => context.push('/profile/referrals'),
          ),
        ),
      ],
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
              leading: const Icon(Icons.coffee_outlined),
              title: Text(m.otherName.isEmpty ? 'A member' : m.otherName),
              subtitle: Text(m.proposedAt == null
                  ? '1-2-1 request'
                  : DateFormat('EEE, MMM d · h:mm a').format(m.proposedAt!)),
              trailing: const Icon(Icons.chevron_right_rounded),
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

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _StatTile({
    required this.value,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: context.scheme.primary),
              const SizedBox(height: Gap.sm),
              Text(
                value,
                style: context.text.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: context.scheme.primary,
                ),
              ),
              Text(
                label,
                style: context.text.labelSmall
                    ?.copyWith(color: context.scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
