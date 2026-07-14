import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// Screen-size breakpoints.
///
/// The app had none: one fixed layout for every device. On a tablet the cards
/// stretched edge-to-edge into unreadable 1000px lines; on a small phone the same
/// layout overflowed.
enum ScreenSize { compact, medium, expanded }

extension ResponsiveX on BuildContext {
  ScreenSize get screenSize {
    final w = MediaQuery.sizeOf(this).width;
    if (w < 600) return ScreenSize.compact; // phones
    if (w < 1000) return ScreenSize.medium; // large phones, small tablets
    return ScreenSize.expanded; // tablets, desktop
  }

  bool get isCompact => screenSize == ScreenSize.compact;

  /// Horizontal padding that grows with the viewport.
  double get pagePadding => switch (screenSize) {
        ScreenSize.compact => Gap.lg,
        ScreenSize.medium => Gap.xl,
        ScreenSize.expanded => Gap.xxl,
      };

  /// True when the user has turned their font size up. Layouts that pack things
  /// into a Row should stack instead at this point, rather than overflow.
  bool get isLargeText => MediaQuery.textScalerOf(this).scale(14) > 18;
}

/// Centres content and stops it stretching into unreadably long lines on a wide
/// screen. Text is hard to read past ~70 characters; a card 1000px wide is worse
/// than one 700px wide, not better.
class ContentWidth extends StatelessWidget {
  final Widget child;
  final double max;

  const ContentWidth({super.key, required this.child, this.max = 720});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: max),
        child: child,
      ),
    );
  }
}

/// A Row that becomes a Column when the text is scaled up or the screen is
/// narrow.
///
/// This is the fix for the app's overflow class of bug: a Row with a couple of
/// buttons is fine at the default font size and blows up with yellow-and-black
/// stripes at 200% text — which is exactly the setting an older user will have on.
class AdaptiveRow extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final double spacing;

  /// Force stacking regardless of measurement.
  final bool? stack;

  const AdaptiveRow({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.spacing = Gap.sm,
    this.stack,
  });

  @override
  Widget build(BuildContext context) {
    final shouldStack = stack ?? context.isLargeText;

    if (shouldStack) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: spacing),
            children[i],
          ],
        ],
      );
    }

    return Row(
      mainAxisAlignment: mainAxisAlignment,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(width: spacing),
          children[i],
        ],
      ],
    );
  }
}
