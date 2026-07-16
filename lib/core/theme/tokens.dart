import 'package:flutter/material.dart';

/// Design tokens.
///
/// The brief: BNI's crimson, but a product that looks like it belongs next to
/// Linear or Revolut rather than an internal admin tool.
///
/// The two failure modes this navigates between:
///
///  - Flooding the brand red across app bars and surfaces. Loud, dated, and it
///    destroys hierarchy — when everything is emphasised, nothing is.
///  - Draining all colour out in reaction, which is how you get beige-on-beige
///    with 1px boxes: technically clean, completely lifeless.
///
/// What it does instead: a warm INK canvas with real depth (layered surfaces,
/// soft shadows, tinted glass), crimson as a confident accent on the one thing
/// that matters per screen, and a deep plum "hero" surface for moments that
/// deserve to feel like an occasion — the live round, the splash.
class AppColors {
  AppColors._();

  // --- Brand -------------------------------------------------------------
  static const brandRed = Color(0xFFC41230);
  static const brandBlue = Color(0xFF003058);

  /// A hair brighter than the raw brand for interactive fills — the flat
  /// crimson goes muddy against a warm canvas.
  static const crimson = Color(0xFFD81E3F);
  static const crimsonDeep = Color(0xFF8E0C22);

  /// Lifted for dark surfaces, where the raw crimson fails contrast.
  static const crimsonDark = Color(0xFFFF6B7E);

  /// The hero surface. Deep plum rather than black: it carries the crimson
  /// family into the dark without going neutral, and gradients over it read as
  /// intentional instead of muddy.
  static const plum = Color(0xFF1B0A10);
  static const plumRaised = Color(0xFF2A1119);

  // --- Light canvas: warm, low-glare -------------------------------------
  static const paper = Color(0xFFFAF7F6);
  static const paperRaised = Color(0xFFFFFFFF);
  static const inkLight = Color(0xFF17110F);
  static const inkMutedLight = Color(0xFF6B615D);
  static const hairlineLight = Color(0xFFEAE3E0);

  // --- Dark canvas: warm charcoal, never black ---------------------------
  static const charcoal = Color(0xFF131011);
  static const charcoalRaised = Color(0xFF1D1819);
  static const inkDark = Color(0xFFF6F2F1);
  static const inkMutedDark = Color(0xFFA79D99);
  static const hairlineDark = Color(0xFF302A2B);

  // --- Status: rich but adult -------------------------------------------
  static const successLight = Color(0xFF12734B);
  static const successDark = Color(0xFF4ADE9B);
  static const warningLight = Color(0xFF9A5B00);
  static const warningDark = Color(0xFFF0B457);
  static const dangerLight = Color(0xFFC0271B);
  static const dangerDark = Color(0xFFFF8A7D);
  static const infoLight = Color(0xFF1B5E9B);
  static const infoDark = Color(0xFF7FBEF5);
}

/// Gradients. Used on hero surfaces and the primary action only — a gradient on
/// every card is how 2014 looked.
class AppGradients {
  AppGradients._();

  static const primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.crimson, AppColors.crimsonDeep],
  );

  static const hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2A1119), AppColors.plum],
  );

  /// A soft crimson bloom for backgrounds — the thing that stops a warm canvas
  /// reading as dead beige.
  static RadialGradient bloom(Color c) => RadialGradient(
        center: const Alignment(-0.7, -0.9),
        radius: 1.4,
        colors: [c.withValues(alpha: 0.10), c.withValues(alpha: 0.0)],
      );
}

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

  /// Hairline borders. Depth comes from a line plus a soft shadow, not a slab.
  final Color hairline;

  /// Shadows for raised surfaces. Warm-tinted — a neutral grey shadow on a warm
  /// canvas looks like dirt.
  final List<BoxShadow> shadowSm;
  final List<BoxShadow> shadowMd;
  final List<BoxShadow> shadowLg;

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
    required this.shadowSm,
    required this.shadowMd,
    required this.shadowLg,
  });

  factory AppSemanticColors.light() => AppSemanticColors(
        success: AppColors.successLight,
        successContainer: const Color(0xFFE3F4EB),
        onSuccessContainer: const Color(0xFF0A4A30),
        warning: AppColors.warningLight,
        warningContainer: const Color(0xFFFCEFDC),
        onWarningContainer: const Color(0xFF6B3E00),
        danger: AppColors.dangerLight,
        dangerContainer: const Color(0xFFFCE8E6),
        onDangerContainer: const Color(0xFF861A11),
        info: AppColors.infoLight,
        infoContainer: const Color(0xFFE4EFF9),
        onInfoContainer: const Color(0xFF10416C),
        hairline: AppColors.hairlineLight,
        shadowSm: [
          BoxShadow(
            color: const Color(0xFF3D2B26).withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        shadowMd: [
          BoxShadow(
            color: const Color(0xFF3D2B26).withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
        shadowLg: [
          BoxShadow(
            color: const Color(0xFF3D2B26).withValues(alpha: 0.12),
            blurRadius: 36,
            offset: const Offset(0, 14),
          ),
        ],
      );

  factory AppSemanticColors.dark() => AppSemanticColors(
        success: AppColors.successDark,
        successContainer: const Color(0xFF14352A),
        onSuccessContainer: const Color(0xFFA6EDC8),
        warning: AppColors.warningDark,
        warningContainer: const Color(0xFF362818),
        onWarningContainer: const Color(0xFFF6D9A6),
        danger: AppColors.dangerDark,
        dangerContainer: const Color(0xFF3B211E),
        onDangerContainer: const Color(0xFFFFC2BA),
        info: AppColors.infoDark,
        infoContainer: const Color(0xFF17293A),
        onInfoContainer: const Color(0xFFC4DEF7),
        hairline: AppColors.hairlineDark,
        // Shadows barely read on a dark canvas; depth there comes from the
        // surface step and the hairline instead.
        shadowSm: const [],
        shadowMd: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
        shadowLg: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 36,
            offset: const Offset(0, 14),
          ),
        ],
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
    List<BoxShadow>? shadowSm,
    List<BoxShadow>? shadowMd,
    List<BoxShadow>? shadowLg,
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
      shadowSm: shadowSm ?? this.shadowSm,
      shadowMd: shadowMd ?? this.shadowMd,
      shadowLg: shadowLg ?? this.shadowLg,
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
      shadowSm: t < 0.5 ? shadowSm : other.shadowSm,
      shadowMd: t < 0.5 ? shadowMd : other.shadowMd,
      shadowLg: t < 0.5 ? shadowLg : other.shadowLg,
    );
  }
}

class Gap {
  Gap._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double huge = 48;
}

class Radii {
  Radii._();
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;
}

/// Motion.
///
/// This app is used standing up, in a noisy room, under a countdown. Animation
/// is for orientation — what changed, where it came from — never decoration.
/// Everything is under 400ms; anything slower is something you WAIT for.
class Motion {
  Motion._();
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 420);

  /// The house curve. Decelerating — things arrive and settle, they don't
  /// coast to a linear stop.
  static const Curve curve = Cubic(0.2, 0, 0, 1);
  static const Curve spring = Cubic(0.34, 1.56, 0.64, 1); // slight overshoot
}

extension AppThemeX on BuildContext {
  ColorScheme get scheme => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;

  AppSemanticColors get colors =>
      Theme.of(this).extension<AppSemanticColors>() ?? AppSemanticColors.light();

  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
