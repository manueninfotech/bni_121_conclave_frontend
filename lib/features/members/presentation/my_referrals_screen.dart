import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/user_avatar.dart';
import '../data/my_referrals_repository.dart';

/// This member's referrals across every conclave — who they referred, and who
/// referred them. Self-scoped: the backend only ever returns your own.
class MyReferralsScreen extends ConsumerWidget {
  const MyReferralsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final referrals = ref.watch(myReferralsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My referrals'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Given'),
              Tab(text: 'Received'),
            ],
          ),
        ),
        body: referrals.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: 'Could not load your referrals.',
            detail: e.toString(),
            onRetry: () => ref.invalidate(myReferralsProvider),
          ),
          data: (data) => TabBarView(
            children: [
              _ReferralList(
                entries: data.given,
                direction: _Direction.given,
                onRefresh: () async => ref.invalidate(myReferralsProvider),
              ),
              _ReferralList(
                entries: data.received,
                direction: _Direction.received,
                onRefresh: () async => ref.invalidate(myReferralsProvider),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Direction { given, received }

class _ReferralList extends StatelessWidget {
  final List<ReferralEntry> entries;
  final _Direction direction;
  final Future<void> Function() onRefresh;

  const _ReferralList({
    required this.entries,
    required this.direction,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.15),
            EmptyView(
              icon: direction == _Direction.given
                  ? Icons.north_east_rounded
                  : Icons.south_west_rounded,
              title: direction == _Direction.given
                  ? 'No referrals given yet'
                  : 'No referrals received yet',
              message: direction == _Direction.given
                  ? 'Referrals you pass at a conclave show up here.'
                  : 'Referrals other members pass to you show up here.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ContentWidth(
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: context.pageInsets,
          itemCount: entries.length,
          separatorBuilder: (_, _) => const SizedBox(height: Gap.sm),
          itemBuilder: (context, i) => _ReferralCard(
            entry: entries[i],
            direction: direction,
            index: i,
          ),
        ),
      ),
    );
  }
}

class _ReferralCard extends StatelessWidget {
  final ReferralEntry entry;
  final _Direction direction;
  final int index;

  const _ReferralCard({
    required this.entry,
    required this.direction,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final name = entry.otherName.isEmpty ? 'A member' : entry.otherName;
    final lead = direction == _Direction.given ? 'You referred' : 'Referred you';

    final context2 = [
      if (entry.conclaveName.isNotEmpty) entry.conclaveName,
      if (entry.roundNumber > 0) 'Round ${entry.roundNumber}',
      if (entry.createdAt != null) DateFormat('MMM d').format(entry.createdAt!),
    ].join('  ·  ');

    return FadeSlideIn(
      index: index,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserAvatar(name: name, photoUrl: null, radius: 24),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lead,
                      style: context.text.labelSmall?.copyWith(
                        color: context.scheme.onSurfaceVariant,
                        letterSpacing: 0.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      style: context.text.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (entry.otherBusinessName.isNotEmpty)
                      Text(
                        entry.otherBusinessName,
                        style: context.text.bodySmall?.copyWith(
                          color: context.scheme.onSurfaceVariant,
                        ),
                      ),
                    if (context2.isNotEmpty) ...[
                      const SizedBox(height: Gap.sm),
                      Text(
                        context2,
                        style: context.text.bodySmall?.copyWith(
                          color: context.scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (entry.notes.isNotEmpty) ...[
                      const SizedBox(height: Gap.sm),
                      Container(
                        padding: const EdgeInsets.all(Gap.sm),
                        decoration: BoxDecoration(
                          color: context.scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(Radii.sm),
                        ),
                        child: Text(
                          entry.notes,
                          style: context.text.bodySmall,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
