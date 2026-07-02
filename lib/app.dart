import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/splash_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/register_screen.dart';
import 'features/conclaves/presentation/conclaves_list_screen.dart';
import 'features/conclaves/presentation/conclave_detail_screen.dart';
import 'features/conclaves/presentation/conclave_register_screen.dart';

final _router = GoRouter(
  initialLocation: '/',
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

class ConclaveApp extends StatelessWidget {
  const ConclaveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'BNI 121 Conclave',
      theme: AppTheme.lightTheme,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
