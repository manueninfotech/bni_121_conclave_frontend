import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import '../services/analytics_service.dart';

/// Shared links: `https://www.manuen.com/conclave/c/<id>` opens that conclave
/// in the app (universal links on iOS, app links on Android, both verified by
/// the files in manuen.com/.well-known). Without the app, the same URL shows a
/// preview page with the store buttons.
///
/// Flutter's built-in deep linking is switched off (Info.plist and the Android
/// manifest), so only these links reach the router. That keeps other URLs the
/// app receives, such as Firebase's phone-verification return, out of it.
class SharedLinks {
  SharedLinks._();

  static const host = 'www.manuen.com';

  /// The link to share for a conclave.
  static Uri conclave(String id) =>
      Uri.https(host, '/conclave/c/${Uri.encodeComponent(id)}');

  /// The app route for an incoming link, or null when it is not one of ours.
  static String? routeFor(Uri uri) {
    final h = uri.host.toLowerCase();
    if (h != host && h != 'manuen.com') return null;
    final s = uri.pathSegments.where((p) => p.isNotEmpty).toList();
    if (s.length >= 3 && s[0] == 'conclave' && s[1] == 'c') {
      final id = s[2];
      if (RegExp(r'^[A-Za-z0-9_-]{6,64}$').hasMatch(id)) {
        return '/conclaves/$id';
      }
    }
    return null;
  }

  /// Signals the router that a link arrived. The route itself waits in
  /// [_pending] until the member is signed in with a profile, then the router
  /// takes it (see [take]).
  static final arrived = _Signal();
  static String? _pending;

  /// The waiting route, cleared as it is read.
  static String? take() {
    final p = _pending;
    _pending = null;
    return p;
  }

  /// Queues [route] and wakes the router.
  static void offer(String route) {
    _pending = route;
    arrived.ping();
  }

  static StreamSubscription<Uri>? _sub;

  /// Starts listening: the link that launched the app, then any while it runs.
  static void listen() {
    if (_sub != null) return;
    final links = AppLinks();
    void handle(Uri? uri) {
      if (uri == null) return;
      final route = routeFor(uri);
      if (route != null) {
        Analytics.linkOpened(route);
        offer(route);
      }
    }

    links.getInitialLink().then(handle, onError: (_) {});
    _sub = links.uriLinkStream.listen(handle, onError: (_) {});
  }
}

class _Signal extends ChangeNotifier {
  void ping() => notifyListeners();
}
