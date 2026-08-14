import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'features/active_conclave/data/sync_service.dart';
import 'features/auth/data/session_service.dart';
import 'features/auth/presentation/splash_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/register_screen.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/onboarding/data/onboarding_service.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'features/profile/presentation/profile_screen.dart';
import 'features/profile/presentation/edit_profile_screen.dart';
import 'features/conclaves/presentation/conclaves_list_screen.dart';
import 'features/conclaves/presentation/conclave_detail_screen.dart';
import 'features/conclaves/presentation/conclave_register_screen.dart';
import 'features/active_conclave/presentation/active_round_screen.dart';
import 'features/active_conclave/presentation/conclave_summary_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Create a listenable for GoRouter to refresh on auth changes
  final authNotifier = ValueNotifier<AsyncValue<User?>>(const AsyncLoading());
  
  // Listen to auth state and update the notifier
  ref.listen<AsyncValue<User?>>(
    authStateProvider,
    (_, next) => authNotifier.value = next,
    fireImmediately: true,
  );

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final authState = authNotifier.value;

      // Auth still resolving — hold on the splash.
      if (authState.isLoading) {
        return state.uri.path == '/' ? null : '/';
      }

      final isAuth = authState.value != null;
      final seenOnboarding = ref.read(onboardingSeenProvider);
      final path = state.uri.path;

      if (isAuth) {
        // A signed-in user has no business on the pre-auth screens — except
        // /register, where a phone user may still be finishing their profile
        // (they authenticate via OTP partway through). Leave them there.
        if (path == '/' || path == '/login' || path == '/onboarding') {
          return '/conclaves';
        }
        return null;
      }

      // Signed out. First-time users see the tour before the login wall.
      if (!seenOnboarding) {
        return path == '/onboarding' ? null : '/onboarding';
      }

      // Onboarding done: the only valid places are the auth screens.
      const authScreens = {'/login', '/register', '/onboarding'};
      if (!authScreens.contains(path)) return '/login';
      return null;
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
        path: '/conclaves',
        builder: (context, state) => const ConclavesListScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) => ConclaveDetailScreen(
              conclaveId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: ':id/register',
            builder: (context, state) => ConclaveRegisterScreen(
              conclaveId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: ':id/active',
            builder: (context, state) => ActiveRoundScreen(
              conclaveId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: ':id/summary',
            builder: (context, state) => ConclaveSummaryScreen(
              conclaveId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) => const EditProfileScreen(),
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
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'BNI 121 Conclave',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // Follow the device. The app previously forced light, ignoring the system
      // setting entirely — including for anyone who uses dark mode for
      // readability rather than preference.
      themeMode: ThemeMode.system,
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
