import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// The app's root navigator. Shared so notification handlers — which run outside
/// the widget tree — can route to a screen when a notification is tapped.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// The screen a notification's data payload should open, or null for none.
String? routeForNotification(Map<String, dynamic> data) {
  switch (data['type']) {
    case 'one_to_one_request':
    case 'one_to_one':
    case 'one_to_one_reminder':
      return '/profile/one-to-ones';
    case 'referral_received':
      return '/profile/referrals';
    default:
      final cid = data['conclaveId'];
      if (cid is String && cid.isNotEmpty) return '/conclaves/$cid';
      return null;
  }
}

/// Navigates to the screen for a tapped notification, if the router is ready.
void openFromNotification(Map<String, dynamic> data) {
  final path = routeForNotification(data);
  if (path == null) return;
  final context = rootNavigatorKey.currentContext;
  if (context == null) return;
  context.push(path);
}
