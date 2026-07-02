import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/splash_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/register_screen.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/conclaves/presentation/conclaves_list_screen.dart';
import 'features/conclaves/presentation/conclave_detail_screen.dart';
import 'features/conclaves/presentation/conclave_register_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      // If authState is loading, wait on splash
      if (authState.isLoading) return '/';
      
      final isAuth = authState.value != null;
      final isSplash = state.matchedLocation == '/';
      final isLoggingIn = state.matchedLocation == '/login';
      final isRegistering = state.matchedLocation == '/register';

      // If on splash and finished loading auth
      if (isSplash) {
        return isAuth ? '/conclaves' : '/login';
      }

      if (isAuth) {
        if (isLoggingIn || isRegistering) return '/conclaves';
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
        ],
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
