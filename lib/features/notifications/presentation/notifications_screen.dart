import 'package:flutter/material.dart';
import '../../../core/widgets/app_refresh.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/navigation.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/page_kit.dart';
import '../data/notifications_repository.dart';
import 'package:conclave_1_2_1/core/theme/cool_icons.dart';

/// The notification hub: a history of everything the app has told this member,
/// with an unread count that clears when they open it.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Opening the hub is "I've seen these" — clear the badge.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(notificationsRepositoryProvider).markAllRead();
      ref.invalidate(notificationsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notificationsProvider);

    return AppPage(
      title: 'Notifications',
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: 'Could not load notifications.',
          detail: e.toString(),
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
        data: (data) {
          if (data.items.isEmpty) {
            return const EmptyView(
              icon: CoolIcons.bell,
              title: 'Nothing yet',
              message: 'Referrals, 1-2-1 requests and round alerts land here.',
            );
          }
          final fresh = data.items.where((n) => !n.read).toList();
          final earlier = data.items.where((n) => n.read).toList();
          return AppRefresh(
            onRefresh: () async => ref.invalidate(notificationsProvider),
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
                  for (final (label, items) in [
                    ('New', fresh),
                    ('Earlier', earlier),
                  ])
                    if (items.isNotEmpty) ...[
                      SectionLabel(label),
                      FadeSlideIn(
                        index: label == 'New' ? 0 : 1,
                        child: SectionCard(
                          gap: 0,
                          padding: EdgeInsets.zero,
                          children: [
                            for (var i = 0; i < items.length; i++) ...[
                              if (i > 0)
                                Divider(
                                  height: 1,
                                  indent: Gap.lg + 36 + Gap.md,
                                  color: context.colors.hairline,
                                ),
                              _NotificationRow(n: items[i]),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: Gap.xl),
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

class _NotificationRow extends StatelessWidget {
  final AppNotification n;
  const _NotificationRow({required this.n});

  (IconData, Color) _icon(BuildContext context) {
    final c = context.colors;
    return switch (n.type) {
      'referral_received' => (CoolIcons.arrowLeftRight, c.success),
      'one_to_one' ||
      'one_to_one_request' ||
      'one_to_one_reminder' => (CoolIcons.coffee, kActionRed),
      _ => (CoolIcons.bellFill, context.scheme.onSurface),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (icon, tint) = _icon(context);
    final when = n.createdAt == null ? '' : _ago(n.createdAt!);

    return InkWell(
      onTap: () => openFromNotification(n.data),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconChip(icon: icon, color: tint),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          style: context.text.titleSmall?.copyWith(
                            fontWeight: n.read
                                ? FontWeight.w700
                                : FontWeight.w800,
                          ),
                        ),
                      ),
                      if (when.isNotEmpty) ...[
                        const SizedBox(width: Gap.sm),
                        Text(
                          when,
                          style: context.text.labelSmall?.copyWith(
                            color: context.scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (!n.read) ...[
                        const SizedBox(width: Gap.sm),
                        Container(
                          margin: const EdgeInsets.only(top: 5),
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: kActionRed,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    n.body,
                    style: context.text.bodyMedium?.copyWith(
                      color: context.scheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return DateFormat('MMM d').format(t);
  }
}
