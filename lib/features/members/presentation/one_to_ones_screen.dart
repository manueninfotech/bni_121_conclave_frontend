import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/user_avatar.dart';
import '../data/one_to_ones_repository.dart';

/// The member's one-to-one meetings — requested and received — with the actions
/// each side can take (respond, or cancel).
class OneToOnesScreen extends ConsumerWidget {
  const OneToOnesScreen({super.key});

  Future<void> _set(
    BuildContext context,
    WidgetRef ref,
    OneToOne m,
    OneToOneStatus status,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(oneToOnesRepositoryProvider).updateStatus(m.id, status);
      ref.invalidate(myOneToOnesProvider);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('1-2-1 ${status.label.toLowerCase()}.')));
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myOneToOnesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My 1-2-1s')),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: 'Could not load your 1-2-1s.',
          detail: e.toString(),
          onRetry: () => ref.invalidate(myOneToOnesProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyView(
              icon: Icons.coffee_outlined,
              title: 'No 1-2-1s yet',
              message: 'Open a member from the directory and request a one-to-one '
                  'to meet outside the conclave.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myOneToOnesProvider),
            child: ContentWidth(
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: context.pageInsets,
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: Gap.sm),
                itemBuilder: (context, i) => _OneToOneCard(
                  m: list[i],
                  index: i,
                  onAccept: () => _set(context, ref, list[i], OneToOneStatus.accepted),
                  onDecline: () => _set(context, ref, list[i], OneToOneStatus.declined),
                  onCancel: () => _set(context, ref, list[i], OneToOneStatus.cancelled),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OneToOneCard extends StatelessWidget {
  final OneToOne m;
  final int index;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onCancel;

  const _OneToOneCard({
    required this.m,
    required this.index,
    required this.onAccept,
    required this.onDecline,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final name = m.otherName.isEmpty ? 'A member' : m.otherName;
    final lead = m.sent ? 'You requested' : 'Requested you';
    final when = m.proposedAt == null
        ? ''
        : DateFormat('EEE, MMM d · h:mm a').format(m.proposedAt!);

    final canRespond = !m.sent && m.status == OneToOneStatus.pending;
    final canCancel = m.status == OneToOneStatus.pending ||
        m.status == OneToOneStatus.accepted;

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
                  UserAvatar(name: name, photoUrl: m.otherPhotoUrl, radius: 24),
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
                      ],
                    ),
                  ),
                  _StatusChip(status: m.status),
                ],
              ),
              const SizedBox(height: Gap.md),
              if (when.isNotEmpty)
                _line(context, Icons.event_rounded, when),
              if (m.location.isNotEmpty)
                _line(context, Icons.place_outlined, m.location),
              if (m.note.isNotEmpty)
                _line(context, Icons.chat_bubble_outline_rounded, m.note),

              if (canRespond) ...[
                const SizedBox(height: Gap.sm),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onDecline,
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: FilledButton(
                        onPressed: onAccept,
                        child: const Text('Accept'),
                      ),
                    ),
                  ],
                ),
              ] else if (canCancel && m.sent) ...[
                const SizedBox(height: Gap.xs),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onCancel,
                    child: const Text('Cancel request'),
                  ),
                ),
              ] else if (canCancel && !m.sent && m.status == OneToOneStatus.accepted) ...[
                const SizedBox(height: Gap.xs),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onCancel,
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: context.scheme.onSurfaceVariant),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(text, style: context.text.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final OneToOneStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (bg, fg) = switch (status) {
      OneToOneStatus.pending => (
          context.scheme.surfaceContainerHighest,
          context.scheme.onSurfaceVariant,
        ),
      OneToOneStatus.accepted => (c.successContainer, c.onSuccessContainer),
      OneToOneStatus.declined => (c.dangerContainer, c.onDangerContainer),
      OneToOneStatus.cancelled => (
          context.scheme.surfaceContainerHighest,
          context.scheme.onSurfaceVariant,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(
        status.label,
        style: context.text.labelSmall
            ?.copyWith(color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }
}
