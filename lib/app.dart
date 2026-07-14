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
      
      // If authState is loading, wait on splash
      if (authState.isLoading) return '/';
      
      final isAuth = authState.value != null;
      final isSplash = state.uri.path == '/';
      final isLoggingIn = state.uri.path == '/login';
      final isRegistering = state.uri.path == '/register';

      // If on splash and finished loading auth
      if (isSplash) {
        // Only redirect to conclaves if they are fully authenticated
        // Note: For phone auth, they might be authenticated but missing a profile.
        // If they restart the app mid-registration, we ideally want to send them back to /register.
        // But for simplicity, we just send to /conclaves. If profile fails, they can logout.
        return isAuth ? '/conclaves' : '/login';
      }

      if (isAuth) {
        if (isLoggingIn) return '/conclaves';
        // Do not redirect away from /register so they can finish their profile!
      } else {
        if (!isLoggingIn && !isRegistering) return '/login';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
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
