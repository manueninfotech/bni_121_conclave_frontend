import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import 'illustrations.dart';

/// The three states every async screen has, in one place.
///
/// Screens used to hand-roll these, which is how the profile screen ended up
/// showing users the string "Profile document does not exist in Firestore."

class LoadingView extends StatelessWidget {
  final String? label;
  const LoadingView({super.key, this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (label != null) ...[
            const SizedBox(height: Gap.lg),
            Text(label!, style: context.text.bodyMedium),
          ],
        ],
      ),
    );
  }
}

/// An error the user can actually act on.
///
/// Never shows a raw exception: a stack trace or a Firestore error code tells the
/// user nothing and makes the app feel broken. The technical detail is kept
/// behind a disclosure for when someone reports a bug.
class ErrorView extends StatelessWidget {
  final String message;
  final String? detail;
  final VoidCallback? onRetry;
  final IconData icon;

  const ErrorView({
    super.key,
    required this.message,
    this.detail,
    this.onRetry,
    this.icon = Icons.cloud_off_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const OfflineIllustration(size: 120),
            const SizedBox(height: Gap.xl),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.text.titleMedium,
            ),
            if (detail != null) ...[
              const SizedBox(height: Gap.sm),
              // Collapsed by default — useful when reporting a bug, noise otherwise.
              ExpansionTile(
                title: Text('Details', style: context.text.bodySmall),
                tilePadding: EdgeInsets.zero,
                shape: const Border(),
                collapsedShape: const Border(),
                children: [
                  SelectableText(
                    detail!,
                    style: context.text.bodySmall?.copyWith(
                      color: context.scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: Gap.xl),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// An empty state that says what to do next, not just that there's nothing here.
class EmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  /// A drawn illustration. Strongly preferred over [icon]: a greyed-out 48px
  /// Material glyph is the loudest "unfinished" signal an app can send.
  final Widget? art;

  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.art,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            art ??
                Icon(icon, size: 48, color: context.scheme.onSurfaceVariant),
            const SizedBox(height: Gap.xl),
            Text(title, textAlign: TextAlign.center, style: context.text.titleMedium),
            if (message != null) ...[
              const SizedBox(height: Gap.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: context.text.bodyMedium?.copyWith(
                  color: context.scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: Gap.xl), action!],
          ],
        ),
      ),
    );
  }
}

/// Which semantic tone a status carries.
enum StatusTone { neutral, success, warning, danger, info }

/// A status badge that never relies on colour alone.
///
/// Colour + icon + text. A colour-blind user, or anyone glancing at a phone in
/// direct sunlight at a venue, still gets the message. The old badges were
/// colour-only.
class StatusBadge extends StatelessWidget {
  final String label;
  final StatusTone tone;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    this.tone = StatusTone.neutral,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final scheme = context.scheme;

    final (bg, fg, defaultIcon) = switch (tone) {
      StatusTone.success => (c.successContainer, c.onSuccessContainer, Icons.check_circle_outline),
      StatusTone.warning => (c.warningContainer, c.onWarningContainer, Icons.schedule),
      StatusTone.danger => (c.dangerContainer, c.onDangerContainer, Icons.error_outline),
      StatusTone.info => (c.infoContainer, c.onInfoContainer, Icons.info_outline),
      StatusTone.neutral => (
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
          Icons.circle_outlined,
        ),
    };

    return Semantics(
      label: 'Status: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon ?? defaultIcon, size: 13, color: fg),
            const SizedBox(width: Gap.xs),
            // Flexible so a long label ellipsizes rather than overflowing when
            // the user's font size is turned up.
            Flexible(
              child: Text(
                label,
                style: context.text.labelSmall?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A label/value row that stacks when text is scaled up instead of overflowing.
class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 18, color: context.scheme.onSurfaceVariant),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: context.text.labelSmall?.copyWith(
                      color: context.scheme.onSurfaceVariant,
                    ),
                  ),
                  Text(value, style: context.text.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fades and lifts a child into place. Used for list items so a screen resolves
/// rather than snapping.
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final int index;

  const FadeSlideIn({super.key, required this.child, this.index = 0});

  @override
  Widget build(BuildContext context) {
    // Stagger, but cap it: with 40 conclaves the last one must not wait 4s.
    final delayMs = (index.clamp(0, 8)) * 40;

    return TweenAnimationBuilder<double>(
      key: ValueKey(index),
      tween: Tween(begin: 0, end: 1),
      duration: Motion.normal + Duration(milliseconds: delayMs),
      curve: Motion.curve,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}
