import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'app_spinner.dart';

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
  static const double _reveal = 90;

  @override
  Widget build(BuildContext context) {
    return CustomRefreshIndicator(
      onRefresh: onRefresh,
      offsetToArmed: 110,
      builder: (context, child, controller) {
        return AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final loading = controller.isLoading ||
                controller.isFinalizing ||
                controller.isSettling;
            // Hold the strip fully open while it loads, so the loader can't
            // shrink or clip as the pull value settles.
            final v = loading ? 1.0 : controller.value.clamp(0.0, 1.0);
            final gap = v * _reveal;

            return Stack(
              children: [
                Transform.translate(offset: Offset(0, gap), child: child),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: gap,
                  // Centre the loader in the opened strip, and scale it DOWN to
                  // fit while the strip is still small — so it is never clipped
                  // and always keeps its square aspect (a true circle).
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Opacity(
                        opacity: v,
                        child: _OrbitIndicator(controller: controller),
                      ),
                    ),
                  ),
                ),
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
        return CustomPaint(
          size: const Size(44, 44),
          painter: OrbitPainter(
            progress: widget.controller.value.clamp(0.0, 1.0),
            loading: loading,
            spin: _spin.value,
            color: AppColors.crimson,
          ),
        );
      },
    );
  }
}
