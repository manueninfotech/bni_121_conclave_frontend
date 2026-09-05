import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/remote_config_service.dart';
import '../navigation.dart';

/// Keeps clients current — with the mechanism each store actually provides.
///
/// **Android** uses Google Play's immediate (blocking, full-screen) in-app
/// update: Play is the source of truth, so publishing a release is the only
/// trigger and there are no version numbers to maintain.
///
/// **iOS has no equivalent** — Apple offers no in-app update API, and updates
/// only ever happen through the App Store app. So iOS uses a two-tier check:
///
///   1. **Forced** — Remote Config `ios_min_version`. Set ONLY when an old
///      client can no longer safely talk to the backend; below it, the app is
///      blocked behind a non-dismissible dialog. This is the rare, deliberate
///      case, so it is the only thing that needs a console change.
///   2. **Soft** — the App Store's own latest version, read automatically from
///      the iTunes Lookup API. No per-release work: every published version is
///      noticed on its own and surfaced as a dismissible "update available"
///      nudge. (Returns nothing while the app is only on TestFlight — testers
///      are notified by TestFlight itself — and has a few-hours CDN lag, both
///      fine for a soft nudge.)
///
/// Either tier sends the user to the App Store; the app never self-updates.
class AppUpdateService {
  const AppUpdateService();

  /// Numeric App Store id for `com.manuen.bniconclave` ("BNI 1-2-1 Conclave").
  static const String _appStoreId = '6809010007';
  static const String _appStoreUrl =
      'https://apps.apple.com/app/id$_appStoreId';

  Future<void> enforceUpdate() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _enforceAndroid();
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _enforceIOS();
    }
  }

  // ---- Android: Play immediate update ------------------------------------

  Future<void> _enforceAndroid() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      final available =
          info.updateAvailability == UpdateAvailability.updateAvailable;
      if (available && info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
      }
    } catch (e) {
      // Sideloaded / debug / no Play Services / offline — can't enforce here.
      debugPrint('In-app update check skipped: $e');
    }
  }

  // ---- iOS: forced gate (Remote Config) then soft nudge (App Store) -------

  Future<void> _enforceIOS() async {
    // Never nag while developing; profile and release builds run the check.
    if (kDebugMode) return;

    try {
      final current = (await PackageInfo.fromPlatform()).version.trim();
      if (current.isEmpty) return;

      // 1) Forced update — a minimum version the console can raise.
      final minVersion = RemoteConfigService.instance.iosMinVersion;
      if (minVersion.isNotEmpty && _isOlder(current, minVersion)) {
        _showUpdateDialog(forced: true);
        return;
      }

      // 2) Soft nudge — the live App Store version, detected automatically.
      final latest = await _appStoreVersion();
      if (latest != null && _isOlder(current, latest)) {
        _showUpdateDialog(forced: false);
      }
    } catch (e) {
      debugPrint('iOS update check skipped: $e');
    }
  }

  /// The current App Store version, or null when the app isn't live yet
  /// (TestFlight-only) or the lookup fails.
  Future<String?> _appStoreVersion() async {
    try {
      final res = await Dio().get(
        'https://itunes.apple.com/lookup',
        queryParameters: {'id': _appStoreId},
        options: Options(responseType: ResponseType.json),
      );
      final data = res.data is Map ? res.data as Map : null;
      final results = data?['results'];
      if (results is List && results.isNotEmpty) {
        final v = (results.first as Map)['version'];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
    } catch (e) {
      debugPrint('App Store version lookup failed: $e');
    }
    return null;
  }

  void _showUpdateDialog({required bool forced}) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return; // No tree yet — caught again next launch.

    showDialog<void>(
      context: context,
      // A forced update can't be tapped away or dismissed by the back gesture.
      barrierDismissible: !forced,
      builder: (ctx) => PopScope(
        canPop: !forced,
        child: AlertDialog(
          title: Text(forced ? 'Update required' : 'Update available'),
          content: Text(
            forced
                ? 'This version is out of date and can no longer be used. '
                    'Please update to keep using the app.'
                : 'A newer version is available on the App Store.',
          ),
          actions: [
            if (!forced)
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Later'),
              ),
            FilledButton(
              onPressed: () {
                launchUrl(
                  Uri.parse(_appStoreUrl),
                  mode: LaunchMode.externalApplication,
                );
                // Soft nudge closes; a forced dialog stays up so a user who
                // backs out of the App Store without updating is still blocked.
                if (!forced) Navigator.of(ctx).pop();
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  /// True when marketing version [a] is older than [b] ("1.1.0" < "1.2.0").
  /// Compares dotted numeric components; missing trailing parts count as 0.
  static bool _isOlder(String a, String b) {
    final pa = _parts(a), pb = _parts(b);
    final n = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < n; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x < y;
    }
    return false;
  }

  static List<int> _parts(String v) => v
      .split('.')
      .map((s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
      .toList();
}
