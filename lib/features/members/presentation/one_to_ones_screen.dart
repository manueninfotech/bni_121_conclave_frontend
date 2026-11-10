import 'package:flutter/material.dart';
import '../../../core/widgets/app_refresh.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/page_kit.dart';
import '../../../core/widgets/user_avatar.dart';
import '../data/one_to_ones_repository.dart';
import 'package:conclave_1_2_1/core/theme/cool_icons.dart';

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
        ..showSnackBar(
          SnackBar(content: Text('1-2-1 ${status.label.toLowerCase()}.')),
        );
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

    return AppPage(
      title: 'My 1-2-1s',
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
              icon: CoolIcons.coffee,
              title: 'No 1-2-1s yet',
              message:
                  'Open a member from the directory and request a one-to-one '
                  'to meet outside the conclave.',
            );
          }
          // Grouped by what each one needs from you.
          final groups = <(String, List<OneToOne>)>[
            (
              'Needs your reply',
              [
                for (final m in list)
                  if (!m.sent && m.status == OneToOneStatus.pending) m,
              ],
            ),
            (
              'Confirmed',
              [
                for (final m in list)
                  if (m.status == OneToOneStatus.accepted) m,
              ],
            ),
            (
              'Waiting on them',
              [
                for (final m in list)
                  if (m.sent && m.status == OneToOneStatus.pending) m,
              ],
            ),
            (
              'Past',
              [
                for (final m in list)
                  if (m.status == OneToOneStatus.declined ||
                      m.status == OneToOneStatus.cancelled)
                    m,
              ],
            ),
          ];
          var index = 0;
          return AppRefresh(
            onRefresh: () async => ref.invalidate(myOneToOnesProvider),
            child: ContentWidth(
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
                  for (final (label, items) in groups)
                    if (items.isNotEmpty) ...[
                      SectionLabel('$label  ${items.length}'),
                      for (final m in items) ...[
                        _OneToOneCard(
                          m: m,
                          index: index++,
                          onAccept: () =>
                              _set(context, ref, m, OneToOneStatus.accepted),
                          onDecline: () =>
                              _set(context, ref, m, OneToOneStatus.declined),
                          onCancel: () =>
                              _set(context, ref, m, OneToOneStatus.cancelled),
                        ),
                        const SizedBox(height: Gap.md),
                      ],
                      const SizedBox(height: Gap.md),
                    ],
                ],
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
        : DateFormat('EEE, d MMM · h:mm a').format(m.proposedAt!);

    final canRespond = !m.sent && m.status == OneToOneStatus.pending;
    final cancelLabel = switch ((m.sent, m.status)) {
      (true, OneToOneStatus.pending) => 'Cancel request',
      (_, OneToOneStatus.accepted) => 'Cancel 1-2-1',
      _ => null,
    };
    final past =
        m.status == OneToOneStatus.declined ||
        m.status == OneToOneStatus.cancelled;

    return FadeSlideIn(
      index: index,
      child: Opacity(
        opacity: past ? 0.7 : 1,
        child: Container(
          padding: const EdgeInsets.all(Gap.lg),
          decoration: pagePanel(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  UserAvatar(name: name, photoUrl: m.otherPhotoUrl, radius: 22),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: context.text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          lead,
                          style: context.text.bodySmall?.copyWith(
                            color: context.scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusChip(status: m.status),
                ],
              ),
              if (when.isNotEmpty ||
                  m.location.isNotEmpty ||
                  m.note.isNotEmpty) ...[
                const SizedBox(height: Gap.md),
                Container(
                  padding: const EdgeInsets.all(Gap.md),
                  decoration: BoxDecoration(
                    color: context.scheme.surfaceContainerHighest.withValues(
                      alpha: 0.45,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (when.isNotEmpty)
                        _line(
                          context,
                          CoolIcons.calendarEventFill,
                          when,
                          bold: true,
                        ),
                      if (m.location.isNotEmpty)
                        _line(context, CoolIcons.mapPin, m.location),
                      if (m.note.isNotEmpty)
                        _line(context, CoolIcons.chat, m.note),
                    ],
                  ),
                ),
              ],
              if (canRespond) ...[
                const SizedBox(height: Gap.md),
                Row(
                  children: [
                    Expanded(
                      child: _SmallButton(label: 'Decline', onTap: onDecline),
                    ),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: _SmallButton(
                        label: 'Accept',
                        onTap: onAccept,
                        primary: true,
                      ),
                    ),
                  ],
                ),
              ] else if (cancelLabel != null) ...[
                const SizedBox(height: Gap.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onCancel,
                    style: TextButton.styleFrom(
                      foregroundColor: context.scheme.onSurfaceVariant,
                    ),
                    child: Text(cancelLabel),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(
    BuildContext context,
    IconData icon,
    String text, {
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: context.scheme.onSurfaceVariant),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(
              text,
              style: context.text.bodyMedium?.copyWith(
                fontWeight: bold ? FontWeight.w700 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool primary;
  const _SmallButton({
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: primary
              ? kActionRed
              : context.scheme.surfaceContainerHighest.withValues(alpha: 0.8),
          foregroundColor: primary ? Colors.white : context.scheme.onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        child: Text(label),
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
        style: context.text.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
