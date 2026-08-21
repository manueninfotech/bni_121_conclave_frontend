import 'package:flutter/material.dart';
import '../../../core/widgets/app_refresh.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/user_avatar.dart';
import '../data/my_referrals_repository.dart';

/// This member's referrals across every conclave — who they referred, and who
/// referred them, plus what came of each (accepted / closed / didn't work out).
class MyReferralsScreen extends ConsumerWidget {
  const MyReferralsScreen({super.key});

  String _rupees(int n) => '₹${NumberFormat.decimalPattern('en_IN').format(n)}';

  /// Receiver-only: move a referral through its outcome lifecycle.
  Future<void> _update(
    BuildContext context,
    WidgetRef ref,
    ReferralEntry e,
  ) async {
    final choice = await showModalBottomSheet<ReferralOutcome>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.handshake_outlined),
              title: const Text('Accepted'),
              subtitle: const Text("You've picked up the lead"),
              onTap: () => Navigator.pop(ctx, ReferralOutcome.accepted),
            ),
            ListTile(
              leading: Icon(Icons.verified_rounded, color: ctx.colors.success),
              title: const Text('Closed — won business'),
              subtitle: const Text('Record the value (TYFCB)'),
              onTap: () => Navigator.pop(ctx, ReferralOutcome.closed),
            ),
            ListTile(
              leading: const Icon(Icons.cancel_outlined),
              title: const Text("Didn't work out"),
              onTap: () => Navigator.pop(ctx, ReferralOutcome.notClosed),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;

    var amount = 0;
    var note = '';
    if (choice == ReferralOutcome.closed) {
      if (!context.mounted) return;
      final res = await _askClosedDetails(context, e);
      if (res == null) return;
      amount = res.$1;
      note = res.$2;
    }

    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(myReferralsRepositoryProvider).updateOutcome(
            conclaveId: e.conclaveId,
            referralId: e.id,
            outcome: choice,
            amount: amount,
            note: note,
          );
      ref.invalidate(myReferralsProvider);
      HapticFeedback.lightImpact();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(choice == ReferralOutcome.closed
              ? 'Marked closed — ${_rupees(amount)}. Nice work.'
              : 'Updated to ${choice.label}.'),
        ));
    } catch (err) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(err.toString().replaceFirst('Exception: ', '')),
        ));
    }
  }

  Future<(int, String)?> _askClosedDetails(
    BuildContext context,
    ReferralEntry e,
  ) {
    final amountCtrl = TextEditingController(
      text: e.closedAmount > 0 ? e.closedAmount.toString() : '',
    );
    final noteCtrl = TextEditingController(text: e.outcomeNote);
    return showDialog<(int, String)>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Closed business'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Value (₹)',
                prefixIcon: Icon(Icons.currency_rupee_rounded),
              ),
            ),
            const SizedBox(height: Gap.md),
            TextField(
              controller: noteCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final amt = int.tryParse(amountCtrl.text.trim()) ?? 0;
              Navigator.pop(ctx, (amt, noteCtrl.text.trim()));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final referrals = ref.watch(myReferralsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My referrals'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Given'), Tab(text: 'Received')],
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
                rupees: _rupees,
              ),
              _ReferralList(
                entries: data.received,
                direction: _Direction.received,
                onRefresh: () async => ref.invalidate(myReferralsProvider),
                rupees: _rupees,
                onUpdate: (e) => _update(context, ref, e),
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
  final String Function(int) rupees;
  final void Function(ReferralEntry)? onUpdate;

  const _ReferralList({
    required this.entries,
    required this.direction,
    required this.onRefresh,
    required this.rupees,
    this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return AppRefresh(
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

    final closedTotal = entries
        .where((e) => e.outcome == ReferralOutcome.closed)
        .fold<int>(0, (s, e) => s + e.closedAmount);

    return AppRefresh(
      onRefresh: onRefresh,
      child: ContentWidth(
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: context.pageInsets,
          itemCount: entries.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: Gap.sm),
          itemBuilder: (context, i) {
            if (i == 0) {
              return _SummaryStrip(
                count: entries.length,
                closedTotal: closedTotal,
                direction: direction,
                rupees: rupees,
              );
            }
            final e = entries[i - 1];
            return _ReferralCard(
              entry: e,
              direction: direction,
              index: i - 1,
              rupees: rupees,
              onUpdate: onUpdate == null ? null : () => onUpdate!(e),
            );
          },
        ),
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  final int count;
  final int closedTotal;
  final _Direction direction;
  final String Function(int) rupees;

  const _SummaryStrip({
    required this.count,
    required this.closedTotal,
    required this.direction,
    required this.rupees,
  });

  @override
  Widget build(BuildContext context) {
    final label = direction == _Direction.given
        ? 'Business you generated'
        : 'Business you closed';
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Row(
        children: [
          Expanded(
            child: _stat(context, '$count', 'Referrals'),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: _stat(context, rupees(closedTotal), label),
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
    );
  }
}

class _ReferralCard extends StatelessWidget {
  final ReferralEntry entry;
  final _Direction direction;
  final int index;
  final String Function(int) rupees;
  final VoidCallback? onUpdate;

  const _ReferralCard({
    required this.entry,
    required this.direction,
    required this.index,
    required this.rupees,
    this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final name = entry.otherName.isEmpty ? 'A member' : entry.otherName;
    final lead = direction == _Direction.given ? 'You referred' : 'Referred you';

    final meta = [
      if (entry.conclaveName.isNotEmpty) entry.conclaveName,
      if (entry.roundNumber > 0) 'Round ${entry.roundNumber}',
      if (entry.createdAt != null) DateFormat('MMM d').format(entry.createdAt!),
    ].join('  ·  ');

    return FadeSlideIn(
      index: index,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                      ],
                    ),
                  ),
                  _OutcomeChip(
                    outcome: entry.outcome,
                    amount: entry.closedAmount,
                    rupees: rupees,
                  ),
                ],
              ),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: Gap.sm),
                Text(
                  meta,
                  style: context.text.bodySmall
                      ?.copyWith(color: context.scheme.onSurfaceVariant),
                ),
              ],
              if (entry.notes.isNotEmpty) ...[
                const SizedBox(height: Gap.sm),
                _NoteBox(text: entry.notes),
              ],
              if (entry.outcome == ReferralOutcome.closed &&
                  entry.outcomeNote.isNotEmpty) ...[
                const SizedBox(height: Gap.sm),
                _NoteBox(text: entry.outcomeNote),
              ],
              if (onUpdate != null) ...[
                const SizedBox(height: Gap.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onUpdate,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text(entry.outcome == ReferralOutcome.open
                        ? 'Update status'
                        : 'Change status'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OutcomeChip extends StatelessWidget {
  final ReferralOutcome outcome;
  final int amount;
  final String Function(int) rupees;

  const _OutcomeChip({
    required this.outcome,
    required this.amount,
    required this.rupees,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (bg, fg, text) = switch (outcome) {
      ReferralOutcome.open => (
          context.scheme.surfaceContainerHighest,
          context.scheme.onSurfaceVariant,
          'Open',
        ),
      ReferralOutcome.accepted => (
          c.infoContainer,
          c.onInfoContainer,
          'Accepted',
        ),
      ReferralOutcome.closed => (
          c.successContainer,
          c.onSuccessContainer,
          rupees(amount),
        ),
      ReferralOutcome.notClosed => (
          context.scheme.surfaceContainerHighest,
          context.scheme.onSurfaceVariant,
          'Closed lost',
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(
        text,
        style: context.text.labelSmall
            ?.copyWith(color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _NoteBox extends StatelessWidget {
  final String text;
  const _NoteBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Gap.sm),
      decoration: BoxDecoration(
        color: context.scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Text(text, style: context.text.bodySmall),
    );
  }
}
