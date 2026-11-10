import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/widgets/app_spinner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';

/// The first thing anyone sees.
///
/// The router holds us here while auth resolves, so the motion is doing real
/// work: it tells the user the app is alive rather than frozen. Deliberately
/// short — nobody wants to admire a splash screen.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  // Starts at 0.85, not 0: the splash is often on screen for only a moment (the
  // auth check), and a logo caught mid-grow from nothing looked like a tiny
  // glitch. This way any glimpse of it is already a sensible size.
  late final Animation<double> _logoScale = Tween<double>(begin: 0.96, end: 1)
      .animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0, 0.6, curve: Curves.easeOutBack),
        ),
      );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.3, 1, curve: Curves.easeOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The native launch screen's red (ios LaunchScreen.storyboard), so the
  /// hand-off from the OS splash to this one is seamless.
  static const _launchRed = Color(0xFFD8061B);

  @override
  Widget build(BuildContext context) {
    final white70 = Colors.white.withValues(alpha: 0.8);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: _launchRed,
        body: Stack(
          children: [
            // The mark stays exactly where the launch screen drew it (centred,
            // 140 pt wide), so nothing jumps; only a gentle settle.
            Center(
              child: ScaleTransition(
                scale: _logoScale,
                child: Image.asset(
                  'assets/images/app_mark_white.png',
                  width: 140,
                  semanticLabel: '1-2-1 Connect',
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  const Spacer(),
                  const SizedBox(height: 140 + Gap.xxl * 2),
                  FadeTransition(
                    opacity: _fade,
                    child: Column(
                      children: [
                        Text(
                          '1-2-1 Connect',
                          textAlign: TextAlign.center,
                          style: context.text.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: Gap.xs),
                        Text(
                          'Structured 1-to-1 networking',
                          textAlign: TextAlign.center,
                          style: context.text.bodyMedium?.copyWith(color: white70),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  FadeTransition(
                    opacity: _fade,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: Gap.xl),
                      child: Column(
                        children: [
                          const AppSpinner(size: 26, color: Colors.white),
                          const SizedBox(height: Gap.lg),
                          Text(
                            'In association with Manuen Infotech',
                            textAlign: TextAlign.center,
                            style: context.text.bodySmall?.copyWith(color: white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
