import 'package:flutter/material.dart';

/// Design tokens.
///
/// Everything visual comes from here, so a change lands everywhere at once. The
/// app previously had 50 hardcoded `Colors.grey`/`Colors.white` calls scattered
/// through the screens, which meant the theme was decorative — changing it moved
/// almost nothing.
class AppColors {
  AppColors._();

  /// BNI brand.
  static const brandRed = Color(0xFFC41230);
  static const brandBlue = Color(0xFF003058);

  /// Semantic roles, resolved per-brightness by [AppSemanticColors].
  ///
  /// Status must never be conveyed by colour ALONE (colour-blind users, and
  /// anyone glancing at a phone in sunlight), so every use of these is paired
  /// with an icon and a text label.
  static const successLight = Color(0xFF1B7F3B);
  static const successDark = Color(0xFF4ADE80);

  static const warningLight = Color(0xFF9A5B00);
  static const warningDark = Color(0xFFFBBF24);

  static const dangerLight = Color(0xFFB3261E);
  static const dangerDark = Color(0xFFF87171);

  static const infoLight = Color(0xFF1D4ED8);
  static const infoDark = Color(0xFF93C5FD);
}

/// Status colours that adapt to light/dark, reached via `context.colors`.
///
/// A ThemeExtension rather than a global constant, so dark mode is not an
/// afterthought bolted on with `if (isDark)` checks at every call site.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  final Color success;
  final Color onSuccessContainer;
  final Color successContainer;

  final Color warning;
  final Color onWarningContainer;
  final Color warningContainer;

  final Color danger;
  final Color onDangerContainer;
  final Color dangerContainer;

  final Color info;
  final Color onInfoContainer;
  final Color infoContainer;

  const AppSemanticColors({
    required this.success,
    required this.onSuccessContainer,
    required this.successContainer,
    required this.warning,
    required this.onWarningContainer,
    required this.warningContainer,
    required this.danger,
    required this.onDangerContainer,
    required this.dangerContainer,
    required this.info,
    required this.onInfoContainer,
    required this.infoContainer,
  });

  factory AppSemanticColors.light() => AppSemanticColors(
        success: AppColors.successLight,
        successContainer: AppColors.successLight.withValues(alpha: 0.10),
        onSuccessContainer: const Color(0xFF0B4A21),
        warning: AppColors.warningLight,
        warningContainer: AppColors.warningLight.withValues(alpha: 0.12),
        onWarningContainer: const Color(0xFF5C3600),
        danger: AppColors.dangerLight,
        dangerContainer: AppColors.dangerLight.withValues(alpha: 0.10),
        onDangerContainer: const Color(0xFF7A1710),
        info: AppColors.infoLight,
        infoContainer: AppColors.infoLight.withValues(alpha: 0.10),
        onInfoContainer: const Color(0xFF14307D),
      );

  factory AppSemanticColors.dark() => AppSemanticColors(
        success: AppColors.successDark,
        successContainer: AppColors.successDark.withValues(alpha: 0.16),
        onSuccessContainer: const Color(0xFFBBF7D0),
        warning: AppColors.warningDark,
        warningContainer: AppColors.warningDark.withValues(alpha: 0.16),
        onWarningContainer: const Color(0xFFFDE68A),
        danger: AppColors.dangerDark,
        dangerContainer: AppColors.dangerDark.withValues(alpha: 0.16),
        onDangerContainer: const Color(0xFFFECACA),
        info: AppColors.infoDark,
        infoContainer: AppColors.infoDark.withValues(alpha: 0.16),
        onInfoContainer: const Color(0xFFDBEAFE),
      );

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? onSuccessContainer,
    Color? successContainer,
    Color? warning,
    Color? onWarningContainer,
    Color? warningContainer,
    Color? danger,
    Color? onDangerContainer,
    Color? dangerContainer,
    Color? info,
    Color? onInfoContainer,
    Color? infoContainer,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      successContainer: successContainer ?? this.successContainer,
      warning: warning ?? this.warning,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      warningContainer: warningContainer ?? this.warningContainer,
      danger: danger ?? this.danger,
      onDangerContainer: onDangerContainer ?? this.onDangerContainer,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      info: info ?? this.info,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
      infoContainer: infoContainer ?? this.infoContainer,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccessContainer: Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarningContainer: Color.lerp(onWarningContainer, other.onWarningContainer, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      onDangerContainer: Color.lerp(onDangerContainer, other.onDangerContainer, t)!,
      dangerContainer: Color.lerp(dangerContainer, other.dangerContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
    );
  }
}

/// Spacing scale. Use these instead of arbitrary numbers so rhythm stays
/// consistent and a density change is a one-line edit.
class Gap {
  Gap._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class Radii {
  Radii._();
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double pill = 999;
}

/// Motion. Short and purposeful — this is an app people use standing up, under
/// time pressure, at a noisy event. Animation here is for orientation (what
/// changed, where did it come from), never decoration.
class Motion {
  Motion._();
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Curve curve = Curves.easeOutCubic;
}

extension AppThemeX on BuildContext {
  ColorScheme get scheme => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;

  /// Status colours (success/warning/danger/info) for the current brightness.
  AppSemanticColors get colors =>
      Theme.of(this).extension<AppSemanticColors>() ?? AppSemanticColors.light();

  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
