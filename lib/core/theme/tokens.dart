import 'package:flutter/material.dart';

/// Design tokens.
///
/// The palette philosophy: **brand colour is punctuation, not paint.**
///
/// BNI red is a loud, saturated crimson. Flooding it across app bars, buttons
/// and surfaces (as the first pass did) reads heavy and dated, and it destroys
/// hierarchy — when everything is emphasised, nothing is. The apps people
/// actually admire do the opposite: a calm, warm neutral canvas, hairline
/// borders instead of heavy shadows, generous whitespace, and the brand colour
/// held back for the ONE decisive action on a screen.
///
/// So: the canvas is warm paper (light) / warm charcoal (dark), never pure white
/// or pure black — pure #FFF glares under venue lighting and pure #000 crushes
/// depth. Red appears on the primary call to action and nowhere else. BNI blue
/// carries informational weight. Status colours are muted rather than saturated,
/// because a live event screen with three neon chips on it looks like an alarm.
class AppColors {
  AppColors._();

  // --- Brand -------------------------------------------------------------
  /// The BNI crimson. Used sparingly, on purpose.
  static const brandRed = Color(0xFFC41230);
  static const brandBlue = Color(0xFF003058);

  /// Lifted for dark surfaces — the raw crimson fails contrast on charcoal.
  static const brandRedDark = Color(0xFFFF7A88);
  static const brandBlueDark = Color(0xFF8FBEEB);

  // --- Light canvas: warm paper, not clinical white ----------------------
  static const paper = Color(0xFFFBF9F8);
  static const paperRaised = Color(0xFFFFFFFF);
  static const paperSunken = Color(0xFFF3F0EE);
  static const inkLight = Color(0xFF1A1614);
  static const inkMutedLight = Color(0xFF6E6663);
  static const hairlineLight = Color(0xFFE7E2DF);

  // --- Dark canvas: warm charcoal, not black ----------------------------
  static const charcoal = Color(0xFF121110);
  static const charcoalRaised = Color(0xFF1C1A19);
  static const charcoalSunken = Color(0xFF0C0B0B);
  static const inkDark = Color(0xFFF3F0EE);
  static const inkMutedDark = Color(0xFFA49C98);
  static const hairlineDark = Color(0xFF2F2B29);

  // --- Status: muted, adult, legible ------------------------------------
  static const successLight = Color(0xFF2E7D5B);
  static const successDark = Color(0xFF6DDBA4);

  static const warningLight = Color(0xFF9A6100);
  static const warningDark = Color(0xFFE9B563);

  static const dangerLight = Color(0xFFB3382B);
  static const dangerDark = Color(0xFFF08C82);

  static const infoLight = Color(0xFF1F5C8B);
  static const infoDark = Color(0xFF8FBEEB);
}

/// Status colours that adapt to brightness, reached via `context.colors`.
///
/// A ThemeExtension rather than globals, so dark mode isn't an `if (isDark)`
/// check at every call site.
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

  /// Hairline borders. Modern surfaces are separated by a 1px line, not a shadow.
  final Color hairline;

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
    required this.hairline,
  });

  factory AppSemanticColors.light() => const AppSemanticColors(
        success: AppColors.successLight,
        successContainer: Color(0xFFE7F3ED),
        onSuccessContainer: Color(0xFF14503A),
        warning: AppColors.warningLight,
        warningContainer: Color(0xFFFBF0DF),
        onWarningContainer: Color(0xFF6B4300),
        danger: AppColors.dangerLight,
        dangerContainer: Color(0xFFFBEAE8),
        onDangerContainer: Color(0xFF7E241B),
        info: AppColors.infoLight,
        infoContainer: Color(0xFFE6EEF5),
        onInfoContainer: Color(0xFF163F60),
        hairline: AppColors.hairlineLight,
      );

  factory AppSemanticColors.dark() => const AppSemanticColors(
        success: AppColors.successDark,
        successContainer: Color(0xFF19332A),
        onSuccessContainer: Color(0xFFA9E9C8),
        warning: AppColors.warningDark,
        warningContainer: Color(0xFF352A17),
        onWarningContainer: Color(0xFFF2D5A4),
        danger: AppColors.dangerDark,
        dangerContainer: Color(0xFF3A2320),
        onDangerContainer: Color(0xFFF6BDB6),
        info: AppColors.infoDark,
        infoContainer: Color(0xFF1B2C3A),
        onInfoContainer: Color(0xFFC3DCF1),
        hairline: AppColors.hairlineDark,
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
    Color? hairline,
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
      hairline: hairline ?? this.hairline,
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
      hairline: Color.lerp(hairline, other.hairline, t)!,
    );
  }
}

/// Spacing scale.
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
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;
}

/// Motion. Short and purposeful — this is used standing up, under time pressure,
/// in a noisy room. Animation is for orientation (what changed, where from),
/// never decoration.
class Motion {
  Motion._();
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 420);
  static const Curve curve = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutBack;
}

extension AppThemeX on BuildContext {
  ColorScheme get scheme => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;

  AppSemanticColors get colors =>
      Theme.of(this).extension<AppSemanticColors>() ?? AppSemanticColors.light();

  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
