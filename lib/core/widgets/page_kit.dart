import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/cool_icons.dart';
import '../theme/tokens.dart';
import 'responsive.dart';

/// The app's building blocks for a pushed (non-tab) page, so every inner page
/// looks the same: a light page, a balanced top bar, small-caps section labels,
/// white field cards, and one flat red action pinned at the bottom.

/// Brand red for primary actions (same as the round deck's lower stop).
const kActionRed = Color(0xFFB00E29);

/// The white "premium panel" surface: a card with a soft, low shadow.
BoxDecoration pagePanel(BuildContext context, {double radius = 24}) =>
    BoxDecoration(
      color: context.scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ],
    );

/// A full pushed page: top bar, scrolling [body], optional pinned [action].
class AppPage extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? action;
  final Widget? trailing;
  final VoidCallback? onBack;

  const AppPage({
    super.key,
    required this.title,
    required this.body,
    this.action,
    this.trailing,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: SafeArea(
          bottom: action == null,
          child: Column(
            children: [
              PageBar(title: title, trailing: trailing, onBack: onBack),
              Expanded(child: body),
              if (action != null) PinnedAction(child: action!),
            ],
          ),
        ),
      ),
    );
  }
}

/// Back · centred title · optional trailing action (kept balanced).
class PageBar extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final VoidCallback? onBack;

  const PageBar({super.key, required this.title, this.trailing, this.onBack});

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding - Gap.sm,
        Gap.xs,
        context.pagePadding - Gap.sm,
        0,
      ),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            SizedBox(
              width: 56,
              child: Align(
                alignment: Alignment.centerLeft,
                child: (onBack != null || canPop)
                    ? IconButton(
                        icon: const Icon(CoolIcons.arrowLeft),
                        tooltip: 'Back',
                        onPressed:
                            onBack ?? () => Navigator.of(context).maybePop(),
                      )
                    : null,
              ),
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(
              width: 56,
              child: Align(alignment: Alignment.centerRight, child: trailing),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bold page heading with a softer line under it.
class PageHeading extends StatelessWidget {
  final String title;
  final String? subtitle;
  const PageHeading({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: context.text.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: Gap.xs),
            Text(
              subtitle!,
              style: context.text.bodyLarge?.copyWith(
                color: context.scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A small-caps label above a card.
class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: Gap.xs, bottom: Gap.sm),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text.toUpperCase(),
            style: context.text.labelMedium?.copyWith(
              color: context.scheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// A group of rows on one white card. Spaces its children evenly ([gap]);
/// pass [gap] 0 for list rows that bring their own dividers.
class SectionCard extends StatelessWidget {
  final List<Widget> children;
  final double gap;
  final EdgeInsetsGeometry padding;

  const SectionCard({
    super.key,
    required this.children,
    this.gap = Gap.md,
    this.padding = const EdgeInsets.all(Gap.lg),
  });

  @override
  Widget build(BuildContext context) {
    final spaced = <Widget>[];
    for (final c in children) {
      // The card spaces its own rows.
      if (c is SizedBox && c.width == null && c.child == null) continue;
      if (spaced.isNotEmpty && gap > 0) spaced.add(SizedBox(height: gap));
      spaced.add(c);
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: padding,
      decoration: pagePanel(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: spaced,
      ),
    );
  }
}

/// A tappable row inside a [SectionCard] (padding zero): tinted icon chip,
/// title, optional subtitle, optional trailing.
class CardRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? tint;

  const CardRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final c = tint ?? context.scheme.onSurface;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: 14),
        child: Row(
          children: [
            IconChip(icon: icon, color: c),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: tint,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: context.text.bodySmall?.copyWith(
                        color: context.scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ?trailing,
            if (trailing == null && onTap != null)
              Icon(
                CoolIcons.chevronRight,
                size: 18,
                color: context.scheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}

/// A soft rounded square holding an icon.
class IconChip extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;
  const IconChip({super.key, required this.icon, this.color, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.scheme.onSurface;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(size * 0.33),
      ),
      child: Icon(icon, size: size * 0.5, color: c),
    );
  }
}

/// A quiet note: an info icon and one or two lines of soft text.
class PageNote extends StatelessWidget {
  final String text;
  final IconData icon;
  const PageNote(this.text, {super.key, this.icon = CoolIcons.circleInfo});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: context.scheme.onSurfaceVariant),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(
              text,
              style: context.text.bodySmall?.copyWith(
                color: context.scheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The one flat red button. [busy] shows a spinner and disables it.
class AppPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;

  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: kActionRed,
          foregroundColor: Colors.white,
          disabledBackgroundColor: kActionRed.withValues(
            alpha: busy ? 0.85 : 0.35,
          ),
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        child: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: Gap.sm),
                  ],
                  Text(label),
                ],
              ),
      ),
    );
  }
}

/// A quiet secondary button (same size as [AppPrimaryButton]).
class AppSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  const AppSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: context.scheme.surfaceContainerHighest.withValues(
            alpha: 0.8,
          ),
          foregroundColor: context.scheme.onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: Gap.sm),
            ],
            Text(label),
          ],
        ),
      ),
    );
  }
}

/// The bottom bar that holds a page's main action, above the home indicator.
class PinnedAction extends StatelessWidget {
  final Widget child;
  const PinnedAction({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.scheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        Gap.md,
        context.pagePadding,
        Gap.md + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: ContentWidth(max: 520, child: child),
    );
  }
}

/// Icon chip, small label, bold value: a read-only fact on a [SectionCard].
class DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final Widget? trailing;

  const DetailRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      excludeSemantics: trailing == null,
      child: Row(
        children: [
          IconChip(icon: icon),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: context.text.labelMedium?.copyWith(
                    color: context.scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
