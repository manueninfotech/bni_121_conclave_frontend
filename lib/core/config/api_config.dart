import 'remote_config_service.dart';

/// Where the backend lives.
///
/// The URL is NO LONGER hardcoded or baked in at build time. It comes from
/// Firebase Remote Config ([RemoteConfigService]), so the backend can be
/// repointed from the Firebase console without shipping a new app.
///
/// The app talks to the **prod** backend by default. A build started with
/// `--dart-define=BACKEND_ENV=dev` uses the `backend_url_dev` parameter instead
/// — the only reason to select an environment at build time, since which server
/// a dev build hits is a developer decision, not a remote one.
///
/// `--dart-define=API_BASE_URL=...` still wins over everything, as an explicit
/// one-off override for local experiments.
class ApiConfig {
  /// 'prod' (default) or 'dev'. Chooses WHICH Remote Config URL to read.
  static const String _env =
      String.fromEnvironment('BACKEND_ENV', defaultValue: 'prod');

  /// An explicit hard override for one-off runs; empty unless supplied.
  static const String _explicit = String.fromEnvironment('API_BASE_URL');

  static bool get _isDev => _env == 'dev';

  static String get baseUrl {
    if (_explicit.isNotEmpty) return _explicit;
    final rc = RemoteConfigService.instance;
    return _isDev ? rc.backendUrlDev : rc.backendUrlProd;
  }

  /// True when this build targets the development backend.
  static bool get isDev => _isDev;
}
