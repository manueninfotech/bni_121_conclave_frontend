import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// The source of truth for runtime-configurable values — currently the backend
/// URL, so it can be repointed from the Firebase console WITHOUT shipping a new
/// build.
///
/// Two parameters are published in Remote Config:
///   - `backend_url_prod` — the live backend the app talks to.
///   - `backend_url_dev`  — a development/staging backend, used only by builds
///     started with `--dart-define=BACKEND_ENV=dev`.
///
/// In-app defaults mirror those below, so the app works on first launch (before
/// any fetch) and offline; a published console value overrides them.
class RemoteConfigService {
  RemoteConfigService._();
  static final RemoteConfigService instance = RemoteConfigService._();

  final FirebaseRemoteConfig _rc = FirebaseRemoteConfig.instance;

  /// Baked-in fallbacks. `prod` is the real deployed backend; `dev` is the
  /// Android-emulator alias for the host's localhost.
  static const String defaultProdUrl =
      'https://bni-1-2-1-backend.onrender.com/api';
  static const String defaultDevUrl = 'http://10.0.2.2:3000/api';

  bool _ready = false;

  /// Loads defaults and fetches the latest values. Safe to call once at startup
  /// before `runApp`; it never throws — a failed fetch just leaves the last
  /// activated values (or the in-app defaults) in place.
  Future<void> init() async {
    try {
      await _rc.setDefaults(const {
        'backend_url_prod': defaultProdUrl,
        'backend_url_dev': defaultDevUrl,
        // Lowest iOS version allowed to keep running. Empty = no forced update
        // (the normal case — a new build is surfaced as a soft nudge from the
        // App Store instead). Bump this ONLY when an old client can no longer
        // safely talk to the backend.
        'ios_min_version': '',
      });
      await _rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 8),
        // Pull changes promptly while developing; cache for an hour in release
        // so we are not fetching on every cold start.
        minimumFetchInterval:
            kReleaseMode ? const Duration(hours: 1) : Duration.zero,
      ));
      await _rc.fetchAndActivate();
    } catch (e) {
      debugPrint('Remote Config init failed (using cached/defaults): $e');
    } finally {
      _ready = true;
    }
  }

  String _urlFor(String key, String fallback) {
    if (!_ready) return fallback;
    final v = _rc.getString(key).trim();
    return v.isEmpty ? fallback : v;
  }

  String get backendUrlProd => _urlFor('backend_url_prod', defaultProdUrl);
  String get backendUrlDev => _urlFor('backend_url_dev', defaultDevUrl);

  /// The lowest iOS marketing version (e.g. "1.2.0") the app may keep running.
  /// Empty when no forced update is in effect. See [AppUpdateService].
  String get iosMinVersion => _ready ? _rc.getString('ios_min_version').trim() : '';
}
