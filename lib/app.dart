import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/splash_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/register_screen.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/profile/presentation/profile_screen.dart';
import 'features/conclaves/presentation/conclaves_list_screen.dart';
import 'features/conclaves/presentation/conclave_detail_screen.dart';
import 'features/conclaves/presentation/conclave_register_screen.dart';
import 'features/active_conclave/presentation/active_round_screen.dart';

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
        ],
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );
});

class ConclaveApp extends ConsumerWidget {
  const ConclaveApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    
    return MaterialApp.router(
      title: 'BNI 121 Conclave',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
