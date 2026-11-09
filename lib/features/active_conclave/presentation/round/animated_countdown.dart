import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'round_timer.dart';

/// An mm:ss countdown where each changing digit dissolves: the old digit blurs
/// and fades out while the new one sharpens in, with a slight drift. Only the
/// digits that actually change animate (tick 0:41 → 0:40 moves just the last
/// one), and tabular figures keep the width rock-steady.
class AnimatedCountdown extends StatelessWidget {
  final Duration remaining;
  final TextStyle? style;

  const AnimatedCountdown({super.key, required this.remaining, this.style});

  @override
  Widget build(BuildContext context) {
    final base = (style ?? DefaultTextStyle.of(context).style)
        .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    final text = roundMmss(remaining);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < text.length; i++)
          text[i] == ':'
              ? Text(':', style: base)
              : _DissolveDigit(digit: text[i], style: base),
      ],
    );
  }
}

class _DissolveDigit extends StatelessWidget {
  final String digit;
  final TextStyle style;
  const _DissolveDigit({required this.digit, required this.style});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      // Old and new digit overlap in place — that's what makes it a dissolve
      // rather than a slide.
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.center,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) => AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) {
          final v = animation.value;
          final blur = (1 - v) * 6;
          return Opacity(
            opacity: v.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, (1 - v) * 5),
              child: ImageFiltered(
                enabled: blur > 0.05,
                imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: child,
              ),
            ),
          );
        },
      ),
      child: Text(digit, key: ValueKey(digit), style: style),
    );
  }
}
