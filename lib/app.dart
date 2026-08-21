import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'core/services/app_update_service.dart';
import 'features/active_conclave/data/sync_service.dart';
import 'features/active_conclave/data/notification_service.dart';
import 'features/auth/data/session_service.dart';
import 'features/auth/presentation/splash_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/register_screen.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/onboarding/data/onboarding_service.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'features/profile/data/profile_repository.dart';
import 'features/profile/presentation/profile_screen.dart';
import 'features/profile/presentation/edit_profile_screen.dart';
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
import 'core/widgets/scaffold_with_nav.dart';

/// The root navigator. Detail pages that should cover the bottom nav bar are
/// pushed here (via `parentNavigatorKey`), not inside a tab's branch.
final _rootNavigatorKey = GlobalKey<NavigatorState>();

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

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: navNotifier,
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
          const authScreens = {'/login', '/register', '/onboarding'};
          return authScreens.contains(path) ? null : '/login';

        case _NavState.profileLoading:
          // Signed in; profile still loading. Head to home optimistically —
          // if it turns out there's no profile, needsProfile routes on to
          // /register next. Leaving them on /register mid-registration stands.
          if (path == '/register') return null;
          return preAuth.contains(path) ? '/conclaves' : null;

        case _NavState.needsProfile:
          // Authenticated but no profile doc — an interrupted registration.
          // Send them back to finish it (the register screen resumes at the
          // profile step). Never move them off /register while they do.
          return path == '/register' ? null : '/register';

        case _NavState.ready:
          return preAuth.contains(path) ? '/conclaves' : null;
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
      // The signed-in app: a bottom-nav shell with three tab roots. Each tab
      // keeps its own stack; detail pages below use parentNavigatorKey so they
      // push full-screen OVER the nav bar rather than inside a tab.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ScaffoldWithNavBar(navigationShell: navigationShell),
        branches: [
          // Conclaves
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/conclaves',
                builder: (context, state) => const ConclavesListScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => ConclaveDetailScreen(
                      conclaveId: state.pathParameters['id']!,
                    ),
                  ),
                  GoRoute(
                    path: ':id/register',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => ConclaveRegisterScreen(
                      conclaveId: state.pathParameters['id']!,
                    ),
                  ),
                  GoRoute(
                    path: ':id/active',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => ActiveRoundScreen(
                      conclaveId: state.pathParameters['id']!,
                    ),
                  ),
                  GoRoute(
                    path: ':id/summary',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => ConclaveSummaryScreen(
                      conclaveId: state.pathParameters['id']!,
                    ),
                  ),
                  GoRoute(
                    path: ':id/met',
                    parentNavigatorKey: _rootNavigatorKey,
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
                    parentNavigatorKey: _rootNavigatorKey,
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
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const EditProfileScreen(),
                  ),
                  GoRoute(
                    path: 'referrals',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const MyReferralsScreen(),
                  ),
                  GoRoute(
                    path: 'card',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const MyCardScreen(),
                  ),
                  GoRoute(
                    path: 'one-to-ones',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const OneToOnesScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
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
  Timer? _sessionTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Auto-logout after autoLogoutHours (default 5). Checked on resume — which
    // is when a phone that sat in a pocket all day comes back — and on a slow
    // timer to catch a session expiring while the app is open.
    _enforceSessionExpiry();
    _sessionTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _enforceSessionExpiry(),
    );

    // Drain pending records whenever the network returns, from ANY screen.
    // Started here rather than on the round screen because at the venue signal
    // comes back at an arbitrary moment — very likely not while the user happens
    // to be sitting on the one screen that used to own the sync timer.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncServiceProvider).startConnectivityWatch();
      // Force a Play update if a newer build is live. No-op off Play.
      const AppUpdateService().enforceUpdate();
    });
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    _enforceSessionExpiry();

    // Coming back to the foreground is the other moment worth retrying: the
    // phone may have regained signal while the app was backgrounded, and
    // connectivity events are not reliably delivered to a suspended app.
    ref.read(syncServiceProvider).syncAllPending();
  }

  Future<void> _enforceSessionExpiry() async {
    final expired = await ref.read(sessionServiceProvider).enforceExpiry();
    if (expired) {
      // The router's redirect watches auth state, so signing out lands the user
      // back on /login by itself.
      debugPrint('Session expired — signed out.');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep the member subscribed to their personal FCM topic while signed in, so
    // the backend can push them direct 1-2-1 alerts. Unsubscribe on sign-out.
    ref.listen(authStateProvider, (previous, next) {
      final uid = next.asData?.value?.uid;
      final notifications = ref.read(notificationServiceProvider);
      if (uid != null) {
        notifications.subscribeUser(uid);
      } else {
        notifications.unsubscribeUser();
      }
    });

    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'BNI 121 Conclave',
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
