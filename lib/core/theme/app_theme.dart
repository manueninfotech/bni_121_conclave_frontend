import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tokens.dart';

/// The app's themes.
///
/// Notes on the decisions that matter:
///
///  - **Plus Jakarta Sans, bundled.** Roboto is why an app reads as "default
///    Flutter". A variable font gives 200-800 in one file, and bundling it means
///    the typeface is right at a venue with no signal.
///  - **No `fontSize` outside this file.** Sizes come from the scale below,
///    which honours the user's system font-size setting.
///  - **No width constraint on buttons.** A global `double.infinity`
///    minimumSize makes every button demand infinite width and throw inside a
///    Row. Screens that want full-width say so.
///  - **The ColorScheme is explicit**, not seeded. Seeding from a saturated
///    crimson tints every surface pink.
class AppTheme {
  AppTheme._();

  static const _font = 'PlusJakartaSans';

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final semantic = isDark ? AppSemanticColors.dark() : AppSemanticColors.light();

    final scheme = isDark
        ? const ColorScheme.dark(
            primary: AppColors.crimsonDark,
            onPrimary: Color(0xFF40040F),
            primaryContainer: Color(0xFF3D141C),
            onPrimaryContainer: Color(0xFFFFD9DE),
            secondary: Color(0xFF9EC5FF),
            onSecondary: Color(0xFF0B1D2B),
            secondaryContainer: Color(0xFF17303F),
            onSecondaryContainer: Color(0xFFCFE4F5),
            surface: AppColors.charcoal,
            onSurface: AppColors.inkDark,
            surfaceContainerLowest: Color(0xFF0D0B0C),
            surfaceContainerLow: AppColors.charcoalRaised,
            surfaceContainer: Color(0xFF221D1E),
            surfaceContainerHigh: Color(0xFF282223),
            surfaceContainerHighest: Color(0xFF2F2829),
            onSurfaceVariant: AppColors.inkMutedDark,
            outline: Color(0xFF4C4445),
            outlineVariant: AppColors.hairlineDark,
            error: AppColors.dangerDark,
            onError: Color(0xFF3A1210),
          )
        : const ColorScheme.light(
            primary: AppColors.crimson,
            onPrimary: Colors.white,
            primaryContainer: Color(0xFFFDE8EB),
            onPrimaryContainer: Color(0xFF6E0A1B),
            secondary: AppColors.brandBlue,
            onSecondary: Colors.white,
            secondaryContainer: Color(0xFFE4EDF5),
            onSecondaryContainer: Color(0xFF00223F),
            surface: AppColors.paper,
            onSurface: AppColors.inkLight,
            surfaceContainerLowest: Colors.white,
            surfaceContainerLow: AppColors.paperRaised,
            surfaceContainer: Color(0xFFF6F2F0),
            surfaceContainerHigh: Color(0xFFF1ECEA),
            surfaceContainerHighest: Color(0xFFEBE5E2),
            onSurfaceVariant: AppColors.inkMutedLight,
            outline: Color(0xFFB5ACA8),
            outlineVariant: AppColors.hairlineLight,
            error: AppColors.dangerLight,
            onError: Colors.white,
          );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      fontFamily: _font,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      splashFactory: InkSparkle.splashFactory,
      // Cross-fade between full-screen routes instead of a horizontal slide.
      // The slide split the screen during the splash → app handoff — the splash
      // sliding out on one side, a still-loading dark screen on the other. A
      // fade has no such seam and reads as a clean hand-off.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadePageTransitionsBuilder(),
          TargetPlatform.iOS: _FadePageTransitionsBuilder(),
        },
      ),
    );

    return base.copyWith(
      extensions: [semantic],
      scaffoldBackgroundColor: scheme.surface,
      textTheme: _textTheme(scheme),

      // Flat, sits on the canvas. A coloured app bar is the single biggest thing
      // that dates an app.
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          fontFamily: _font,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: scheme.onSurface,
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          side: BorderSide(color: semantic.hairline),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 54),
          padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          textStyle: const TextStyle(
            fontFamily: _font,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(0, 54),
          padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          textStyle: const TextStyle(
            fontFamily: _font,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 50),
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: semantic.hairline, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          textStyle: const TextStyle(
            fontFamily: _font,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(
            fontFamily: _font,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? scheme.surfaceContainer : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: semantic.hairline, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: semantic.hairline, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Gap.lg,
          vertical: Gap.lg,
        ),
        labelStyle: TextStyle(
          fontFamily: _font,
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: TextStyle(
          fontFamily: _font,
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: scheme.onSurfaceVariant,
      ),

      chipTheme: ChipThemeData(
        side: BorderSide(color: semantic.hairline),
        backgroundColor: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
      ),

      dividerTheme: DividerThemeData(color: semantic.hairline, space: Gap.xl),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? scheme.surfaceContainerHighest : scheme.onSurface,
        contentTextStyle: TextStyle(
          fontFamily: _font,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDark ? scheme.onSurface : scheme.surface,
        ),
        actionTextColor: scheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        insetPadding: const EdgeInsets.all(Gap.lg),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.xl),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
        ),
      ),

      tabBarTheme: TabBarThemeData(
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: semantic.hairline,
        labelColor: scheme.onSurface,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        overlayColor: WidgetStatePropertyAll(scheme.primary.withValues(alpha: 0.05)),
        labelStyle: const TextStyle(
          fontFamily: _font,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: _font,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),

      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: Gap.lg),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: semantic.hairline,
        circularTrackColor: semantic.hairline,
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  /// The type scale.
  ///
  /// Tight tracking on display sizes, looser on small text — the opposite of
  /// Material's defaults, and the single change that most separates a designed
  /// app from a default one. Large type set at normal tracking always looks
  /// slack.
  static TextTheme _textTheme(ColorScheme s) {
    TextStyle t(double size, FontWeight w, double spacing, {double? height}) =>
        TextStyle(
          fontFamily: _font,
          fontSize: size,
          fontWeight: w,
          letterSpacing: spacing,
          height: height,
          color: s.onSurface,
        );

    return TextTheme(
      displayLarge: t(54, FontWeight.w800, -2.0, height: 1.05),
      displayMedium: t(44, FontWeight.w800, -1.6, height: 1.08),
      displaySmall: t(34, FontWeight.w800, -1.2, height: 1.1),
      headlineLarge: t(30, FontWeight.w700, -0.9, height: 1.15),
      headlineMedium: t(25, FontWeight.w700, -0.7, height: 1.2),
      headlineSmall: t(21, FontWeight.w700, -0.5, height: 1.25),
      titleLarge: t(18, FontWeight.w700, -0.3, height: 1.3),
      titleMedium: t(16, FontWeight.w600, -0.2, height: 1.35),
      titleSmall: t(14.5, FontWeight.w600, -0.1, height: 1.4),
      bodyLarge: t(16, FontWeight.w400, 0, height: 1.5),
      bodyMedium: t(14, FontWeight.w400, 0.05, height: 1.5),
      bodySmall: t(12.5, FontWeight.w400, 0.1, height: 1.45)
          .copyWith(color: s.onSurfaceVariant),
      labelLarge: t(14, FontWeight.w600, 0.1),
      labelMedium: t(12.5, FontWeight.w600, 0.2),
      labelSmall: t(11.5, FontWeight.w600, 0.4),
    );
  }
}

/// A plain cross-fade between routes — no slide, so a full-screen hand-off (the
/// splash into the app) never splits the screen into an old half and a new half.
class _FadePageTransitionsBuilder extends PageTransitionsBuilder {
  const _FadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(opacity: animation, child: child);
  }
}
