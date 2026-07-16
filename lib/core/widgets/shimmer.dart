import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// Skeleton loading.
///
/// A centred spinner tells the user "wait" and nothing else. A skeleton tells
/// them what is coming and roughly how much of it — the screen appears to be
/// assembling rather than stalling, and the layout doesn't jump when data lands
/// because the shape was already there.
class Shimmer extends StatefulWidget {
  final Widget child;

  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.scheme.surfaceContainerHigh;
    final highlight = context.isDark
        ? context.scheme.surfaceContainerHighest
        : Colors.white;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            // A band travelling left to right across the whole subtree, so a
            // group of skeletons shimmers as one surface rather than each
            // element pulsing on its own.
            final w = bounds.width;
            final dx = (_c.value * 2 - 0.5) * w;
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [base, highlight, base],
              stops: const [0.35, 0.5, 0.65],
              transform: _SlideGradient(dx),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlideGradient extends GradientTransform {
  final double dx;
  const _SlideGradient(this.dx);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(dx, 0, 0);
}

/// A single skeleton block. Colour is irrelevant — the Shimmer above paints
/// over it — so this only defines shape.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = Radii.sm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class SkeletonCircle extends StatelessWidget {
  final double size;
  const SkeletonCircle({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.scheme.surfaceContainerHigh,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// The conclave list's loading state — mirrors the real card's geometry so the
/// transition to data is a cross-fade, not a re-layout.
class ConclaveCardSkeleton extends StatelessWidget {
  const ConclaveCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: context.scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: context.colors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SkeletonBox(width: 160, height: 18),
              const Spacer(),
              SkeletonBox(width: 74, height: 24, radius: Radii.pill),
            ],
          ),
          const SizedBox(height: Gap.lg),
          Row(
            children: [
              const SkeletonCircle(size: 18),
              const SizedBox(width: Gap.md),
              SkeletonBox(width: MediaQuery.sizeOf(context).width * 0.35),
            ],
          ),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              const SkeletonCircle(size: 18),
              const SizedBox(width: Gap.md),
              SkeletonBox(width: MediaQuery.sizeOf(context).width * 0.45),
            ],
          ),
          const SizedBox(height: Gap.lg),
          const SkeletonBox(height: 50, radius: Radii.md),
        ],
      ),
    );
  }
}

class ConclaveListSkeleton extends StatelessWidget {
  const ConclaveListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.separated(
        padding: const EdgeInsets.all(Gap.xl),
        itemCount: 3,
        physics: const NeverScrollableScrollPhysics(),
        separatorBuilder: (_, _) => const SizedBox(height: Gap.md),
        itemBuilder: (_, _) => const ConclaveCardSkeleton(),
      ),
    );
  }
}
