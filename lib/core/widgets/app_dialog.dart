import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The app's one dialog style: a tinted icon chip, a bold title, a soft
/// message, and full-width stacked actions (primary red, quiet secondary).
/// Use [showAppConfirm] for yes/no questions, or [AppDialog] directly for
/// custom content (e.g. a form).
class AppDialog extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? message;
  final Widget? content;

  /// Primary action. Null for an info-only dialog with just [secondaryLabel].
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Destructive actions (delete, sign out) use the danger colour.
  final bool destructive;

  const AppDialog({
    super.key,
    this.icon,
    required this.title,
    this.message,
    this.content,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = destructive ? context.colors.danger : const Color(0xFFB00E29);
    return Dialog(
      backgroundColor: context.scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: Gap.xl, vertical: Gap.xl),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.xl, Gap.xl, Gap.lg),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: accent, size: 24),
                  ),
                  const SizedBox(height: Gap.lg),
                ],
                Text(
                  title,
                  style: context.text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: Gap.sm),
                  Text(
                    message!,
                    style: context.text.bodyMedium?.copyWith(
                      color: context.scheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ],
                if (content != null) ...[
                  const SizedBox(height: Gap.lg),
                  content!,
                ],
                const SizedBox(height: Gap.xl),
                if (primaryLabel != null)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: onPrimary,
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        textStyle: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      child: Text(primaryLabel!),
                    ),
                  ),
                if (secondaryLabel != null) ...[
                  const SizedBox(height: Gap.xs),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: TextButton(
                      onPressed: onSecondary ?? () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: context.scheme.onSurface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        textStyle: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      child: Text(secondaryLabel!),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A yes/no question in the app's dialog style. Resolves true on [confirmLabel].
Future<bool> showAppConfirm(
  BuildContext context, {
  IconData? icon,
  required String title,
  String? message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => AppDialog(
      icon: icon,
      title: title,
      message: message,
      primaryLabel: confirmLabel,
      onPrimary: () => Navigator.pop(ctx, true),
      secondaryLabel: cancelLabel,
      onSecondary: () => Navigator.pop(ctx, false),
      destructive: destructive,
    ),
  );
  return ok == true;
}

/// An information dialog with a single dismiss button.
Future<void> showAppNotice(
  BuildContext context, {
  IconData? icon,
  required String title,
  required String message,
  String okLabel = 'OK',
}) {
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => AppDialog(
      icon: icon,
      title: title,
      message: message,
      primaryLabel: okLabel,
      onPrimary: () => Navigator.pop(ctx),
    ),
  );
}
