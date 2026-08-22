import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The app's loading indicator: crimson dots orbiting a hub — members around a
/// table. Used everywhere instead of the stock [CircularProgressIndicator], so
/// every spinner in the app is the same branded mark.
///
/// Give it a [color] (e.g. white) when it sits on a coloured surface like a
/// filled button.
class AppSpinner extends StatefulWidget {
  final double size;
  final Color? color;

  const AppSpinner({super.key, this.size = 40, this.color});

  @override
  State<AppSpinner> createState() => _AppSpinnerState();
}

class _AppSpinnerState extends State<AppSpinner>
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
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _spin,
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: OrbitPainter(
            progress: 1,
            loading: true,
            spin: _spin.value,
            color: widget.color ?? AppColors.crimson,
          ),
        ),
      ),
    );
  }
}

/// Paints the orbiting-dots mark. Shared by [AppSpinner] and the pull-to-refresh
/// indicator. All sizes are relative to the canvas, so it scales cleanly from a
/// tiny button spinner to a full-screen loader.
class OrbitPainter extends CustomPainter {
  /// 0..1 — how "drawn" the ring is (the pull amount). 1 for a plain spinner.
  final double progress;

  /// When true the ring is a comet-trail spinner; when false it draws in
  /// proportion to [progress].
  final bool loading;

  /// 0..1 rotation phase.
  final double spin;
  final Color color;

  static const int _dots = 6;

  OrbitPainter({
    required this.progress,
    required this.loading,
    required this.spin,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final s = size.shortestSide;
    final maxOrbit = s * 0.36;
    final dotMax = s * 0.11;
    final orbit = maxOrbit * (loading ? 1.0 : progress);
    final rotation = loading ? spin * 2 * math.pi : progress * math.pi * 0.9;

    final paint = Paint()..isAntiAlias = true;

    for (var i = 0; i < _dots; i++) {
      final t = i / _dots; // 0..1 position along the comet trail
      final angle = rotation + t * 2 * math.pi;
      final pos = center + Offset(math.cos(angle), math.sin(angle)) * orbit;

      final trail = 0.35 + 0.65 * t; // trailing dots smaller/fainter
      final pullIn = loading ? 1.0 : (0.45 + 0.55 * progress);
      final dotRadius = (0.4 + 0.6 * t) * dotMax * pullIn;
      final opacity = (loading ? trail : progress * trail).clamp(0.0, 1.0);

      paint.color = color.withValues(alpha: opacity);
      canvas.drawCircle(pos, dotRadius, paint);
    }

    // The hub the dots gather around; gentle pulse while loading.
    final hubPulse =
        loading ? 0.85 + 0.15 * math.sin(spin * 2 * math.pi) : progress;
    paint.color = color.withValues(
        alpha: (0.4 + 0.6 * (loading ? 1 : progress)).clamp(0.0, 1.0));
    canvas.drawCircle(center, s * 0.06 * hubPulse.clamp(0.25, 1.0), paint);
  }

  @override
  bool shouldRepaint(OrbitPainter old) =>
      old.progress != progress || old.loading != loading || old.spin != spin;
}
