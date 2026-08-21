import 'dart:math' as math;

import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The app's own pull-to-refresh — a crimson ring that draws itself as you pull
/// (with the BNI mark growing at its centre), then spins as a smooth branded
/// loader while it refreshes. Identical on iOS and Android, and it replaces the
/// stock Material spinner everywhere.
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
                // The indicator lives in the gap the pull opens at the top.
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
                      child: _RingIndicator(controller: controller),
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

class _RingIndicator extends StatefulWidget {
  final IndicatorController controller;
  const _RingIndicator({required this.controller});

  @override
  State<_RingIndicator> createState() => _RingIndicatorState();
}

class _RingIndicatorState extends State<_RingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final track = context.colors.hairline;
    return AnimatedBuilder(
      animation: Listenable.merge([widget.controller, _spin]),
      builder: (context, _) {
        final loading = widget.controller.isLoading ||
            widget.controller.isFinalizing ||
            widget.controller.isSettling;
        final progress = widget.controller.value.clamp(0.0, 1.0);
        final iconScale = loading
            ? 0.9 + 0.12 * math.sin(_spin.value * 2 * math.pi)
            : 0.55 + 0.45 * progress;

        return SizedBox(
          width: 40,
          height: 40,
          child: CustomPaint(
            painter: _RingPainter(
              progress: progress,
              loading: loading,
              spin: _spin.value,
              color: AppColors.crimson,
              track: track,
            ),
            child: Center(
              child: Transform.scale(
                scale: iconScale,
                child: Icon(
                  Icons.groups_rounded,
                  size: 15,
                  color: AppColors.crimson,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final bool loading;
  final double spin;
  final Color color;
  final Color track;

  _RingPainter({
    required this.progress,
    required this.loading,
    required this.spin,
    required this.color,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 3;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = track;
    canvas.drawCircle(center, radius, trackPaint);

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = color;

    if (loading) {
      // A sweeping arc that rotates — the branded spinner.
      final start = spin * 2 * math.pi;
      canvas.drawArc(rect, start, math.pi * 1.4, false, arcPaint);
    } else {
      // Draw the ring in proportion to how far you've pulled.
      canvas.drawArc(rect, -math.pi / 2, progress * 2 * math.pi, false, arcPaint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.loading != loading || old.spin != spin;
}
