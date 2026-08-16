import 'package:flutter/material.dart';
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
  late final Animation<double> _logoScale = Tween<double>(
    begin: 0.85,
    end: 1,
  ).animate(CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.6, curve: Curves.easeOutBack),
  ));

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.3, 1, curve: Curves.easeOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final width = MediaQuery.sizeOf(context).width;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scheme.surface,
              Color.alphaBlend(
                scheme.primary.withValues(alpha: 0.06),
                scheme.surface,
              ),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              ScaleTransition(
                scale: _logoScale,
                child: Container(
                  // Scales with the viewport rather than a fixed 120px, which was
                  // oversized on a small phone and lost on a tablet.
                  width: width * 0.28,
                  height: width * 0.28,
                  constraints: const BoxConstraints(
                    minWidth: 96,
                    minHeight: 96,
                    maxWidth: 160,
                    maxHeight: 160,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.20),
                        blurRadius: 32,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  // The client is providing artwork; it drops in here.
                  child: Icon(
                    Icons.groups_rounded,
                    size: 56,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: Gap.xl),
              FadeTransition(
                opacity: _fade,
                child: Column(
                  children: [
                    Text(
                      'BNI 121 Conclave',
                      textAlign: TextAlign.center,
                      style: context.text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: Gap.xs),
                    Text(
                      'Structured 1-to-1 networking',
                      textAlign: TextAlign.center,
                      style: context.text.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
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
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.primary.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: Gap.lg),
                      Text(
                        'In association with Manuen Infotech',
                        textAlign: TextAlign.center,
                        style: context.text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
