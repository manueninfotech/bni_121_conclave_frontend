import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

/// Forced updates, driven entirely by Google Play.
///
/// When Play reports a newer build than the one installed, the app launches
/// Play's **immediate** (blocking, full-screen) update flow — the user cannot
/// continue on the stale version. Play is the source of truth: there are no
/// version numbers or backend switches to maintain. Publishing a release to Play
/// is the only trigger.
///
/// This matters because the app talks to a backend whose contract evolves; an
/// old client left running can silently misbehave against a newer server.
///
/// Android/Play only. `checkForUpdate` throws when the app wasn't installed from
/// Play (a sideloaded APK, a debug build, or a device with no Play Services), so
/// every path fails silently and lets the app run — a forced update can only be
/// offered to users who can actually take it.
class AppUpdateService {
  const AppUpdateService();

  Future<void> enforceUpdate() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    try {
      final info = await InAppUpdate.checkForUpdate();
      final available =
          info.updateAvailability == UpdateAvailability.updateAvailable;
      if (available && info.immediateUpdateAllowed) {
        // Blocks until the user updates (or Play cancels/fails). On a successful
        // update Play restarts the app.
        await InAppUpdate.performImmediateUpdate();
      }
    } catch (e) {
      // Sideloaded / debug / no Play Services / offline. Not an error worth
      // surfacing — it just means we can't enforce here.
      debugPrint('In-app update check skipped: $e');
    }
  }
}
