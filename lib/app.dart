import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/services/local_notifications.dart';
import 'core/services/conclave_calendar.dart';
import 'core/services/analytics_service.dart';
import 'core/navigation.dart';
import 'core/theme/app_theme.dart';
import 'core/services/app_update_service.dart';
import 'features/active_conclave/data/sync_service.dart';
import 'features/active_conclave/data/notification_service.dart';
import 'features/active_conclave/data/round_sticky.dart';
import 'features/active_conclave/data/live_lock.dart';
import 'core/services/presence_service.dart';
import 'features/auth/presentation/splash_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/forgot_password_screen.dart';
import 'core/widgets/phone_field.dart' show LoginMethod;
import 'features/auth/presentation/register_screen.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/onboarding/data/onboarding_service.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'features/profile/data/profile_repository.dart';
import 'features/profile/presentation/profile_screen.dart';
import 'features/profile/presentation/edit_profile_screen.dart';
import 'features/conclaves/data/conclave_repository.dart';
import 'features/conclaves/domain/conclave_model.dart';
import 'features/conclaves/presentation/conclaves_list_screen.dart';
import 'features/conclaves/presentation/conclave_detail_screen.dart';
import 'features/conclaves/presentation/conclave_register_screen.dart';
import 'features/active_conclave/presentation/active_round_screen.dart';
import 'features/active_conclave/presentation/conclave_summary_screen.dart';
import 'features/members/presentation/members_directory_screen.dart';
import 'features/members/presentation/member_detail_screen.dart';
import 'features/members/presentation/my_referrals_screen.dart';
import 'features/members/presentation/people_met_screen.dart';
import 'features/members/presentation/my_card_screen.dart';
import 'features/members/presentation/one_to_ones_screen.dart';
import 'features/members/data/members_repository.dart';
import 'features/members/data/one_to_ones_repository.dart';
import 'features/members/data/my_referrals_repository.dart';
import 'features/notifications/data/notifications_repository.dart';
import 'features/notifications/presentation/notifications_screen.dart';
import 'features/home/presentation/home_screen.dart';
import 'core/widgets/scaffold_with_nav.dart';

/// Where the app should be, derived from auth AND whether the profile exists.
///
/// Composed as ONE provider rather than two independent listeners so the router
/// can never see a stale mix — "signed in" paired with the previous phase's
/// profile value. Riverpod rebuilds a dependent only after its inputs are up to
/// date, so when auth flips to a user, [myProfileProvider] is already showing
/// this user's loading state here, not the last one's null.
enum _NavState { authLoading, signedOut, profileLoading, needsProfile, ready }

final _navStateProvider = Provider<_NavState>((ref) {
  final auth = ref.watch(authStateProvider);
  if (auth.isLoading) return _NavState.authLoading;
  if (auth.value == null) return _NavState.signedOut;

  final profile = ref.watch(myProfileProvider);
  return profile.when(
    // Auth is known — don't keep the user on the splash just because their
    // profile is still loading. Send them to the app; it fills in when ready.
    loading: () => _NavState.profileLoading,
    error: (_, _) => _NavState.profileLoading,
    data: (p) => p == null ? _NavState.needsProfile : _NavState.ready,
  );
});

final routerProvider = Provider<GoRouter>((ref) {
  final navNotifier = ValueNotifier<_NavState>(_NavState.authLoading);
  ref.listen<_NavState>(
    _navStateProvider,
    (_, next) => navNotifier.value = next,
    fireImmediately: true,
  );

  // Second signal that re-runs the router's redirect: the id of the conclave the
  // member is locked into (or null). Riverpod only fires this listener when the
  // value actually changes, so the redirect runs on lock engage/release — not on
  // the per-second round ticks underneath.
  final lockNotifier = ValueNotifier<String?>(null);
  ref.listen<String?>(
    liveConclaveProvider.select((c) => c?.id),
    (_, next) => lockNotifier.value = next,
    fireImmediately: true,
  );

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: Listenable.merge([navNotifier, lockNotifier]),
    // Logs a screen_view to Analytics on every navigation.
    observers: [Analytics.observer],
    redirect: (context, state) {
      final navState = navNotifier.value;
      final path = state.uri.path;
      final seenOnboarding = ref.read(onboardingSeenProvider);

      const preAuth = {'/', '/login', '/onboarding'};

      switch (navState) {
        case _NavState.authLoading:
          // The ONLY time we hold on the splash — the brief check of whether
          // anyone is signed in. Everything else routes into the app.
          return path == '/' ? null : '/';

        case _NavState.signedOut:
          if (!seenOnboarding) {
            return path == '/onboarding' ? null : '/onboarding';
          }
          const authScreens = {'/login', '/register', '/onboarding', '/forgot-password'};
          return authScreens.contains(path) ? null : '/login';

        case _NavState.profileLoading:
          // Signed in; profile still loading. Head to home optimistically —
          // if it turns out there's no profile, needsProfile routes on to
          // /register next. Leaving them on /register mid-registration stands.
          if (path == '/register') return null;
          return preAuth.contains(path) ? '/home' : null;

        case _NavState.needsProfile:
          // Authenticated but no profile doc — an interrupted registration.
          // Send them back to finish it (the register screen resumes at the
          // profile step). Never move them off /register while they do.
          // A forgot-password check signs in briefly to find "no account" and
          // signs straight out again — don't bounce it to /register meanwhile.
          if (path == '/forgot-password') return null;
          return path == '/register' ? null : '/register';

        case _NavState.ready:
          // Rapido-style lock: while a round the member is seated in is live,
          // the active-round screen is the ONLY reachable place. Any other route
          // — a tab, a deep link, a back-pop landing elsewhere — is redirected
          // straight back to it until the conclave ends and the lock releases.
          final locked = lockNotifier.value;
          if (locked != null) {
            final activePath = '/conclaves/$locked/active';
            return path == activePath ? null : activePath;
          }
          return preAuth.contains(path) ? '/home' : null;
      }
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => ForgotPasswordScreen(
          initialMethod: state.uri.queryParameters['method'] == 'email'
              ? LoginMethod.email
              : LoginMethod.phone,
        ),
      ),
      // The signed-in app: a bottom-nav shell with three tab roots. Each tab
      // keeps its own stack; detail pages below use parentNavigatorKey so they
      // push full-screen OVER the nav bar rather than inside a tab.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ScaffoldWithNavBar(navigationShell: navigationShell),
        branches: [
          // Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          // Conclaves
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/conclaves',
                builder: (context, state) => const ConclavesListScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => ConclaveDetailScreen(
                      conclaveId: state.pathParameters['id']!,
                    ),
                  ),
                  GoRoute(
                    path: ':id/register',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => ConclaveRegisterScreen(
                      conclaveId: state.pathParameters['id']!,
                    ),
                  ),
                  GoRoute(
                    path: ':id/active',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => ActiveRoundScreen(
                      conclaveId: state.pathParameters['id']!,
                    ),
                  ),
                  GoRoute(
                    path: ':id/summary',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => ConclaveSummaryScreen(
                      conclaveId: state.pathParameters['id']!,
                    ),
                  ),
                  GoRoute(
                    path: ':id/met',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => PeopleMetScreen(
                      conclaveId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Members directory
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/members',
                builder: (context, state) => const MembersDirectoryScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => MemberDetailScreen(
                      memberId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Profile
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'edit',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const EditProfileScreen(),
                  ),
                  GoRoute(
                    path: 'referrals',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const MyReferralsScreen(),
                  ),
                  GoRoute(
                    path: 'card',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const MyCardScreen(),
                  ),
                  GoRoute(
                    path: 'one-to-ones',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const OneToOnesScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      // Full-screen, over the nav shell.
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const NotificationsScreen(),
      ),
    ],
  );
});

class ConclaveApp extends ConsumerStatefulWidget {
  const ConclaveApp({super.key});

  @override
  ConsumerState<ConclaveApp> createState() => _ConclaveAppState();
}

class _ConclaveAppState extends ConsumerState<ConclaveApp>
    with WidgetsBindingObserver {
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Presence instead of auto-logout: members stay signed in, and the app
    // tells the server when it is open so the admin sees who is online.
    PresenceService.instance.appOpened();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        PresenceService.instance.appOpened();
      } else {
        PresenceService.instance.stop();
      }
    });

    // Drain pending records whenever the network returns, from ANY screen.
    // Started here rather than on the round screen because at the venue signal
    // comes back at an arbitrary moment — very likely not while the user happens
    // to be sitting on the one screen that used to own the sync timer.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncServiceProvider).startConnectivityWatch();
      // Force a Play update if a newer build is live. No-op off Play.
      const AppUpdateService().enforceUpdate();
      // Route if the app was launched by tapping a local notification.
      LocalNotifications.handleAppLaunch();
    });

    // A 1-2-1 reminder that lands while the app is open: raise the same sticky
    // countdown the background handler would (FCM won't show a data message).
    _reminderSub = FirebaseMessaging.onMessage.listen((message) {
      final type = message.data['type'];
      switch (type) {
        // These two are data-only messages that build a richer, interactive
        // notification (sticky countdown / Accept-Decline), so they're special.
        case 'one_to_one_request':
          LocalNotifications.handleRequestData(message.data);
          return;
        case 'one_to_one_reminder':
          LocalNotifications.handleReminderData(message.data);
          return;
      }

      // Everything else (round started, referral passed, generic updates): on
      // Android, FCM does not show a notification message while the app is open,
      // so mirror it into the tray ourselves — otherwise the user, who is IN the
      // app exactly when a round starts, sees nothing at all. On iOS we instead
      // let FCM present it natively (setForegroundNotificationPresentationOptions
      // in main()); mirroring there too would show the banner twice.
      if (defaultTargetPlatform == TargetPlatform.iOS) return;
      final title = message.notification?.title ?? message.data['title'] as String?;
      final body = message.notification?.body ?? message.data['body'] as String?;
      if (title == null || body == null) return;
      LocalNotifications.showMessage(
        title: title,
        body: body,
        channel: switch (type) {
          'round_started' => LocalNotifications.channelRoundAlerts,
          'referral' || 'referral_received' => LocalNotifications.channelReferrals,
          _ => LocalNotifications.channelGeneral,
        },
      );
    });

    // Deep-link: a notification tapped while the app was backgrounded…
    _openedSub =
        FirebaseMessaging.onMessageOpenedApp.listen((m) => openFromNotification(m.data));
    // …or tapped from a terminated state (delivered once on launch).
    FirebaseMessaging.instance.getInitialMessage().then((m) {
      if (m != null) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => openFromNotification(m.data));
      }
    });
  }

  StreamSubscription<RemoteMessage>? _openedSub;

  StreamSubscription<RemoteMessage>? _reminderSub;

  @override
  void dispose() {
    _authSub?.cancel();
    PresenceService.instance.stop();
    _reminderSub?.cancel();
    _openedSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      PresenceService.instance.appClosed();
      return;
    }
    if (state != AppLifecycleState.resumed) return;

    PresenceService.instance.appOpened();

    // Coming back to the foreground is the other moment worth retrying: the
    // phone may have regained signal while the app was backgrounded, and
    // connectivity events are not reliably delivered to a suspended app.
    ref.read(syncServiceProvider).syncAllPending();

    // A 1-2-1 may have been accepted/declined from the notification tray while
    // we were away, and referrals may have landed. Refresh those views.
    ref.invalidate(myOneToOnesProvider);
    ref.invalidate(myReferralsProvider);
    ref.invalidate(notificationsProvider);
    ref.invalidate(membersProvider);
  }

  @override
  Widget build(BuildContext context) {
    // Keep the member subscribed to their personal FCM topic while signed in, so
    // the backend can push them direct 1-2-1 alerts. Unsubscribe on sign-out.
    ref.listen(authStateProvider, (previous, next) {
      final uid = next.asData?.value?.uid;
      final notifications = ref.read(notificationServiceProvider);
      // Tie analytics + crash reports to the signed-in member (null on sign-out).
      Analytics.setUser(uid: uid);
      FirebaseCrashlytics.instance.setUserIdentifier(uid ?? '');
      if (uid != null) {
        notifications.subscribeUser(uid);
      } else {
        notifications.unsubscribeUser();
      }
    });

    // Re-arm conclave reminders every time the list updates — which, with the
    // list's resume-refresh, now includes app-open. A reminder is otherwise
    // scheduled only once at registration, so a reboot, an OS that dropped the
    // alarm, or an inexact alarm that slipped by would leave the member with no
    // reminder. Re-scheduling is idempotent (stable id per conclave), so this
    // just keeps the pending alarm fresh (#1).
    ref.listen(conclavesStreamProvider, (previous, next) {
      final list = next.asData?.value;
      if (list == null) return;
      final now = DateTime.now();
      for (final c in list) {
        if (!c.isRegistered) continue;
        if (c.effectiveStatus == ConclaveStatus.completed ||
            c.effectiveStatus == ConclaveStatus.cancelled) {
          continue;
        }
        if (ConclaveCalendar.eventStart(c).isAfter(now)) {
          ConclaveCalendar.scheduleReminder(c);
        }
      }
    });

    // Keep the ongoing Android "live round" sticky driven from here — above any
    // screen — so it persists and keeps updating while the member is on another
    // tab or has the phone pocketed. The provider returns void and dedupes its
    // own reposts, so this watch keeps it (and the live stream) alive without
    // rebuilding the app each second.
    ref.watch(roundStickyDriverProvider);

    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: '1-2-1 Connect',
      theme: AppTheme.light(),
      darkTheme: AppTheme.light(),
      // Light only, by the client's direction: BNI's look is a white background
      // with red-and-black text, and the app must not adopt the device's dark
      // theme. Both slots point at the light theme so even a forced-dark device
      // stays white.
      themeMode: ThemeMode.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        // Respect the user's font-size setting, but clamp the extremes: beyond
        // ~1.6x, layouts that must stay usable at a venue (a live round timer,
        // a table roster) stop fitting on a phone at all. Users who need more
        // than that are better served by the system magnifier than by a broken
        // screen.
        final scaler = MediaQuery.textScalerOf(context).clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.6,
        );
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scaler),
          child: child!,
        );
      },
    );
  }
}
