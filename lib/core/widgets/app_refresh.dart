import 'dart:math' as math;

import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The app's own pull-to-refresh: crimson dots that orbit a hub — members
/// around a table — fading in as you pull, then circling smoothly while it
/// loads. Identical on iOS and Android; replaces the stock Material spinner.
///
/// Drop-in for `RefreshIndicator` — same `onRefresh` + `child`.
class AppRefresh extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;

  const AppRefresh({super.key, required this.onRefresh, required this.child});

  /// How far the content slides down at full pull.
  static const double _reveal = 78;

  @override
  Widget build(BuildContext context) {
    return CustomRefreshIndicator(
      onRefresh: onRefresh,
      offsetToArmed: 96,
      builder: (context, child, controller) {
        return AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final gap = (controller.value * _reveal).clamp(0.0, _reveal);
            return Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: gap,
                  child: OverflowBox(
                    minHeight: 0,
                    maxHeight: 56,
                    alignment: Alignment.center,
                    child: Opacity(
                      opacity: controller.value.clamp(0.0, 1.0),
                      child: _OrbitIndicator(controller: controller),
                    ),
                  ),
                ),
                Transform.translate(offset: Offset(0, gap), child: child),
              ],
            );
          },
        );
      },
      child: child,
    );
  }
}

class _OrbitIndicator extends StatefulWidget {
  final IndicatorController controller;
  const _OrbitIndicator({required this.controller});

  @override
  State<_OrbitIndicator> createState() => _OrbitIndicatorState();
}

class _OrbitIndicatorState extends State<_OrbitIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.controller, _spin]),
      builder: (context, _) {
        final loading = widget.controller.isLoading ||
            widget.controller.isFinalizing ||
            widget.controller.isSettling;
        return SizedBox(
          width: 44,
          height: 44,
          child: CustomPaint(
            painter: _OrbitPainter(
              progress: widget.controller.value.clamp(0.0, 1.0),
              loading: loading,
              spin: _spin.value,
              color: AppColors.crimson,
            ),
          ),
        );
      },
    );
  }
}

class _OrbitPainter extends CustomPainter {
  final double progress;
  final bool loading;
  final double spin;
  final Color color;

  static const int _dots = 6;

  _OrbitPainter({
    required this.progress,
    required this.loading,
    required this.spin,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxOrbit = size.width / 2 - 5;
    // The ring opens up as you pull; full while loading.
    final orbit = maxOrbit * (loading ? 1.0 : progress);
    // Rotates continuously while loading; eases round a little as you pull.
    final rotation = loading ? spin * 2 * math.pi : progress * math.pi * 0.9;

    final paint = Paint()..isAntiAlias = true;

    for (var i = 0; i < _dots; i++) {
      final t = i / _dots; // 0..1 position along the comet trail
      final angle = rotation + t * 2 * math.pi;
      final pos = center + Offset(math.cos(angle), math.sin(angle)) * orbit;

      // Trailing dots are smaller and fainter, so the ring reads as spinning.
      final trail = 0.35 + 0.65 * t;
      final pullIn = loading ? 1.0 : (0.45 + 0.55 * progress);
      final dotRadius = (1.4 + 3.0 * t) * pullIn;
      final opacity = (loading ? trail : progress * trail).clamp(0.0, 1.0);

      paint.color = color.withValues(alpha: opacity);
      canvas.drawCircle(pos, dotRadius, paint);
    }

    // The hub — the "table" the dots gather around. Gentle pulse while loading.
    final hubPulse = loading ? 0.85 + 0.15 * math.sin(spin * 2 * math.pi) : progress;
    paint.color = color.withValues(alpha: (0.4 + 0.6 * (loading ? 1 : progress)).clamp(0.0, 1.0));
    canvas.drawCircle(center, 2.4 * hubPulse.clamp(0.25, 1.0), paint);
  }

  @override
  bool shouldRepaint(_OrbitPainter old) =>
      old.progress != progress || old.loading != loading || old.spin != spin;
}
