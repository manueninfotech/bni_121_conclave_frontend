import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
  debugPrint('Background round alert: ${message.notification?.title}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

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
