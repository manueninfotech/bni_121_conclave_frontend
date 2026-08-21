import 'package:flutter/material.dart';
import '../../../core/widgets/app_refresh.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/navigation.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/responsive.dart';
import '../data/notifications_repository.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
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
              icon: Icons.notifications_none_rounded,
              title: 'Nothing yet',
              message: 'Referrals, 1-2-1 requests and round alerts land here.',
            );
          }
          return AppRefresh(
            onRefresh: () async => ref.invalidate(notificationsProvider),
            child: ContentWidth(
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: context.pageInsets,
                itemCount: data.items.length,
                separatorBuilder: (_, _) => const SizedBox(height: Gap.sm),
                itemBuilder: (context, i) =>
                    _NotificationCard(n: data.items[i], index: i),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification n;
  final int index;
  const _NotificationCard({required this.n, required this.index});

  (IconData, Color) _icon(BuildContext context) {
    final c = context.colors;
    return switch (n.type) {
      'referral_received' => (Icons.swap_horiz_rounded, c.success),
      'one_to_one' || 'one_to_one_request' || 'one_to_one_reminder' => (
          Icons.coffee_outlined,
          context.scheme.primary,
        ),
      _ => (Icons.notifications_rounded, context.scheme.onSurfaceVariant),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (icon, tint) = _icon(context);
    final when = n.createdAt == null ? '' : _ago(n.createdAt!);

    return FadeSlideIn(
      index: index,
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: n.read ? null : context.colors.infoContainer.withValues(alpha: 0.4),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: tint.withValues(alpha: 0.14),
            child: Icon(icon, color: tint),
          ),
          title: Text(
            n.title,
            style: context.text.titleSmall?.copyWith(
              fontWeight: n.read ? FontWeight.w600 : FontWeight.w800,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(n.body),
              if (when.isNotEmpty)
                Text(
                  when,
                  style: context.text.labelSmall
                      ?.copyWith(color: context.scheme.onSurfaceVariant),
                ),
            ],
          ),
          isThreeLine: true,
          onTap: () => openFromNotification(n.data),
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
