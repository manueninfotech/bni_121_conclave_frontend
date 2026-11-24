import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'links/shared_links.dart';

/// The app's root navigator. Shared so notification handlers — which run outside
/// the widget tree — can route to a screen when a notification is tapped.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// App routes a notification may name directly in its `link` field.
const _linkablePrefixes = ['/conclaves/', '/profile/', '/home', '/notifications'];

/// The screen a notification's data payload should open, or null for none.
///
/// A `link` in the payload wins (a manuen.com conclave link or an app route),
/// so the server can point any notification at any screen without an app
/// release. Otherwise the type decides: live-round alerts open the round,
/// a finished conclave opens its summary.
String? routeForNotification(Map<String, dynamic> data) {
  final link = data['link'];
  if (link is String && link.isNotEmpty) {
    final uri = Uri.tryParse(link);
    if (uri != null && uri.hasScheme) {
      final route = SharedLinks.routeFor(uri);
      if (route != null) return route;
    } else if (_linkablePrefixes.any(link.startsWith) && !link.contains('..')) {
      return link;
    }
  }

  final cid = data['conclaveId'];
  final conclave = cid is String && cid.isNotEmpty ? cid : null;
  switch (data['type']) {
    case 'one_to_one_request':
    case 'one_to_one':
    case 'one_to_one_reminder':
      return '/profile/one-to-ones';
    case 'referral_received':
      return '/profile/referrals';
    case 'round_started':
    case 'round_paused':
    case 'round_resumed':
    case 'round_ended':
    case 'table_changed':
    case 'stand_in_captain':
    case 'walk_in_approved':
      return conclave == null ? null : '/conclaves/$conclave/active';
    case 'conclave_completed':
      return conclave == null ? null : '/conclaves/$conclave/summary';
    default:
      return conclave == null ? null : '/conclaves/$conclave';
  }
}

/// Opens the screen for a notification.
///
/// From the in-app list ([fromList]) the screen is pushed, so Back returns to
/// the list. A push notification tapped outside the app goes through the same
/// queue as shared links: the router opens it once the member is signed in
/// with a profile, so a tap that launched the app is not lost while sign-in
/// and the profile load.
void openFromNotification(Map<String, dynamic> data, {bool fromList = false}) {
  final path = routeForNotification(data);
  if (path == null) return;
  if (fromList) {
    rootNavigatorKey.currentContext?.push(path);
    return;
  }
  SharedLinks.offer(path);
}
