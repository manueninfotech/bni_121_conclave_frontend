import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'core/config/remote_config_service.dart';
import 'core/services/local_notifications.dart';
import 'core/time/server_clock.dart';
import 'features/onboarding/data/onboarding_service.dart';
import 'firebase_options.dart';
import 'app.dart';

/// Handles round alerts that arrive while the app is backgrounded or killed.
///
/// Runs in its own isolate, so it must initialise Firebase itself and must not
/// touch app state. It deliberately does nothing but let the system display the
/// notification: the round the app acts on is always re-derived from the conclave
/// document when the user opens it, never from a push payload.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Some 1-2-1 pushes arrive as DATA messages so the app can build a richer
  // notification (Accept/Decline actions, or a sticky countdown). Everything
  // else (round alerts) carries its own notification payload and the system
  // shows it directly.
  final type = message.data['type'];
  if (type == 'one_to_one_request') {
    await LocalNotifications.handleRequestData(message.data);
    return;
  }
  if (type == 'one_to_one_reminder') {
    await LocalNotifications.handleReminderData(message.data);
    return;
  }
  debugPrint('Background alert: ${message.notification?.title}');
}

void main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Crash reporting. Route every Flutter framework error and every uncaught
  // async error to Crashlytics, so a crash on a member's phone comes back
  // symbolicated with the device, OS and stack — not just a store-level count.
  //
  // A failed report must be swallowed, never rethrown: if Crashlytics itself
  // errors, that error would land back in these handlers, get reported again,
  // fail again — an endless loop that pins the main thread at 100% CPU and
  // leaves the app stuck on the splash screen (shipped in 1.1.x–1.2.0).
  FlutterError.onError = (details) {
    FirebaseCrashlytics.instance
        .recordFlutterFatalError(details)
        .catchError((Object _) {});
  };
  binding.platformDispatcher.onError = (error, stack) {
    FirebaseCrashlytics.instance
        .recordError(error, stack, fatal: true)
        .catchError((Object _) {});
    return true;
  };

  // App Check attests requests come from the genuine app. Activated (tokens are
  // sent) but NOT enforced on the backend yet — enforcement is a console toggle
  // to flip only after the token flow is verified, so no one is locked out.
  try {
    // ignore: deprecated_member_use
    await FirebaseAppCheck.instance.activate(
      // ignore: deprecated_member_use
      androidProvider:
          kReleaseMode ? AndroidProvider.playIntegrity : AndroidProvider.debug,
      // ignore: deprecated_member_use
      appleProvider:
          kReleaseMode ? AppleProvider.deviceCheck : AppleProvider.debug,
    );
  } catch (e) {
    debugPrint('App Check activate failed (non-fatal): $e');
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  // Notification setup must never block or abort startup. If the plugin throws
  // (e.g. a release-build R8 strip) or a platform channel hangs, degrade to "no
  // local notifications" rather than stranding the user on the splash forever.
  try {
    await LocalNotifications.init().timeout(const Duration(seconds: 6));
  } catch (e) {
    debugPrint('LocalNotifications.init failed (non-fatal): $e');
  }

  // Timezone database + the device's local zone, so scheduled conclave reminders
  // fire at the right wall-clock time. Falls back to UTC if the lookup fails or
  // the platform channel does not answer promptly.
  //
  // Uses the FULL database (latest_all): many Android phones in India report the
  // legacy alias "Asia/Calcutta", which the trimmed `latest` set omits. The
  // fallback is the built-in tz.UTC — never a by-name lookup, because "UTC" is
  // also an alias and a throw here aborted main() before runApp, leaving those
  // phones stuck on the splash screen forever (1.2.0+21..26).
  tzdata.initializeTimeZones();
  try {
    final name = await FlutterTimezone.getLocalTimezone()
        .timeout(const Duration(seconds: 4));
    tz.setLocalLocation(tz.getLocation(name));
  } catch (e) {
    debugPrint('Timezone lookup failed, using UTC: $e');
    tz.setLocalLocation(tz.UTC);
  }

  // Resolve the backend URL from Remote Config before anything makes a request,
  // so the very first API call already targets the configured host. Never
  // throws; falls back to the in-app defaults offline.
  await RemoteConfigService.instance.init();

  // The venue has no usable connectivity for 300-400 people. Persist Firestore
  // locally so the conclave document — and with it the schedule and the table
  // roster — keeps resolving from cache once it has been fetched at least once.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Restore the last known server-clock offset before anything renders a timer,
  // so a phone that reopens with no connectivity still evaluates round
  // boundaries against the server's clock rather than its own.
  final container = ProviderContainer();
  await container.read(serverClockProvider).load();

  // Load the first-run flag before the first frame, so the router's synchronous
  // redirect can decide onboarding-vs-login without a flash of the wrong screen.
  final seenOnboarding = await container.read(onboardingServiceProvider).hasSeen();
  container.read(onboardingSeenProvider.notifier).set(seenOnboarding);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ConclaveApp(),
    ),
  );
}
