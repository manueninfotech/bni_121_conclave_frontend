import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// Screen-size breakpoints.
enum ScreenSize { compact, medium, expanded }

extension ResponsiveX on BuildContext {
  ScreenSize get screenSize {
    final w = MediaQuery.sizeOf(this).width;
    if (w < 600) return ScreenSize.compact;
    if (w < 1000) return ScreenSize.medium;
    return ScreenSize.expanded;
  }

  bool get isCompact => screenSize == ScreenSize.compact;

  double get pagePadding => switch (screenSize) {
        ScreenSize.compact => Gap.xl,
        ScreenSize.medium => Gap.xl,
        ScreenSize.expanded => Gap.xxl,
      };

  /// True when the user has turned their font size up. Layouts that pack things
  /// into a Row should stack at this point rather than overflow.
  bool get isLargeText => MediaQuery.textScalerOf(this).scale(14) > 18;

  /// The system inset at the bottom of the screen — Android's gesture pill or
  /// 3-button navigation bar.
  ///
  /// A Scaffold does NOT wrap its body in a bottom SafeArea, so a full-bleed
  /// scroll view has to add this to its own bottom padding; otherwise the last
  /// card or the primary CTA is drawn under the system bar and is partly
  /// untappable. `viewPadding` rather than `padding`, so it stays the physical
  /// inset even while the keyboard is up.
  double get bottomInset => MediaQuery.viewPaddingOf(this).bottom;

  /// Page padding on the sides and top, with the bottom grown to clear the
  /// system navigation bar. The default for any full-screen scroll view filling
  /// a Scaffold body (a pushed detail page, not a tab root).
  EdgeInsets get pageInsets => EdgeInsets.fromLTRB(
        pagePadding,
        pagePadding,
        pagePadding,
        pagePadding + bottomInset,
      );

  /// Bottom room a TAB ROOT's scroll view needs so its last item clears the
  /// floating navigation bar, which hovers over the content. That bar sits above
  /// the system gesture inset, so this is that inset plus the pill's height and
  /// its margins.
  double get floatingNavClearance => bottomInset + 84;

  /// Page padding for a tab-root scroll view: normal on the sides and top, with
  /// the bottom grown to clear the floating navigation bar.
  EdgeInsets get tabScrollInsets => EdgeInsets.fromLTRB(
        pagePadding,
        pagePadding,
        pagePadding,
        floatingNavClearance,
      );
}

/// Constrains content width on wide screens WITHOUT centring it vertically.
///
/// This used a plain `Center`, which centres on BOTH axes — so any screen that
/// put it above a scroll view got its content floating in the middle of a huge
/// void. `Align(topCenter)` pins to the top and only centres horizontally,
/// which is what "max content width" is supposed to mean.
class ContentWidth extends StatelessWidget {
  final Widget child;
  final double max;

  /// Set for genuinely centred layouts (a sign-in form on a tablet). Off by
  /// default — vertical centring should be a decision, not an accident.
  final bool centerVertically;

  const ContentWidth({
    super.key,
    required this.child,
    this.max = 720,
    this.centerVertically = false,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: centerVertically ? Alignment.center : Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: max),
        child: child,
      ),
    );
  }
}

/// A Row that becomes a Column when the text is scaled up.
///
/// The fix for the app's overflow class of bug: a Row of buttons is fine at the
/// default font size and blows up with yellow-and-black stripes at 200% text —
/// which is exactly the setting an older user will have on.
class AdaptiveRow extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final double spacing;
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

/// A full-width primary action.
///
/// Exists because the theme deliberately does NOT force button width (a global
/// `double.infinity` minimumSize throws inside a Row), which means every screen
/// that wants a full-width CTA has to say so — and forgetting leaves a small
/// button marooned in the middle of the screen.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.md),
          // The gradient is the "one decisive action" signal. Flat crimson on a
          // warm canvas goes muddy; the gradient keeps it alive.
          gradient: enabled ? AppGradients.primary : null,
          color: enabled ? null : context.scheme.surfaceContainerHighest,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.crimson.withValues(alpha: 0.28),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: FilledButton(
          onPressed: enabled ? onPressed : null,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledForegroundColor: context.scheme.onSurfaceVariant,
            shadowColor: Colors.transparent,
          ),
          child: loading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 19),
                      const SizedBox(width: Gap.sm),
                    ],
                    Flexible(
                      child: Text(label, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Scales a child down slightly while pressed.
///
/// The cheapest way to make an interface feel physical. Without it a tap is a
/// colour flash; with it the thing you touched acknowledges you.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;

    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: Motion.instant,
        curve: Motion.curve,
        child: widget.child,
      ),
    );
  }
}
