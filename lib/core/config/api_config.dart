import 'package:flutter/foundation.dart';

/// Where the backend lives.
///
/// A shipped build cannot talk to localhost — the phone's localhost is the
/// phone. So the base URL is a build-time constant, supplied with --dart-define:
///
///   `flutter build apk --dart-define=API_BASE_URL=https://your-app.vercel.app/api`
///
/// In debug builds, if nothing is supplied we fall back to the local dev server
/// (10.0.2.2 is the Android emulator's alias for the host machine's localhost).
///
/// In a RELEASE build with no API_BASE_URL we deliberately fail loudly rather
/// than silently shipping an app that points at a server nobody can reach. A
/// release APK quietly wired to localhost is exactly the bug this guards.
class ApiConfig {
  static const String _fromEnv = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_fromEnv.isNotEmpty) return _fromEnv;

    if (kReleaseMode) {
      throw StateError(
        'API_BASE_URL was not set for this release build. Rebuild with:\n'
        '  flutter build apk --dart-define=API_BASE_URL=https://<your-app>.vercel.app/api',
      );
    }

    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:3000/api' // Android emulator -> host localhost
        : 'http://localhost:3000/api';
  }

  /// True when we're using the local dev fallback rather than a configured host.
  static bool get isUsingLocalFallback => _fromEnv.isEmpty;
}
