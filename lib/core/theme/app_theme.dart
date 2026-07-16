import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tokens.dart';

/// The app's themes.
///
/// The ColorScheme is written out explicitly rather than derived from
/// `ColorScheme.fromSeed(brandRed)`. Seeding from a saturated crimson tints
/// EVERY surface pink — cards, sheets, app bars, backgrounds — which is exactly
/// the heavy, dated look we're getting away from. Here the canvas is a warm
/// neutral and red exists only where it is asked for.
///
/// Two other rules the theme enforces:
///
///  - No `fontSize` anywhere. Sizes come from the type scale, which honours the
///    user's system font-size setting. Hardcoding sizes silently ignores it.
///  - No width constraint on buttons. A global `double.infinity` minimumSize
///    makes every button demand infinite width and throw inside a Row.
class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final semantic = isDark ? AppSemanticColors.dark() : AppSemanticColors.light();

    final scheme = isDark
        ? const ColorScheme.dark(
            primary: AppColors.brandRedDark,
            onPrimary: Color(0xFF3B0710),
            primaryContainer: Color(0xFF3A1218),
            onPrimaryContainer: Color(0xFFFFD9DD),
            secondary: AppColors.brandBlueDark,
            onSecondary: Color(0xFF0B1D2B),
            secondaryContainer: Color(0xFF17303F),
            onSecondaryContainer: Color(0xFFCFE4F5),
            surface: AppColors.charcoal,
            onSurface: AppColors.inkDark,
            surfaceContainerLowest: AppColors.charcoalSunken,
            surfaceContainerLow: AppColors.charcoalRaised,
            surfaceContainer: Color(0xFF201E1D),
            surfaceContainerHigh: Color(0xFF262322),
            surfaceContainerHighest: Color(0xFF2C2928),
            onSurfaceVariant: AppColors.inkMutedDark,
            outline: Color(0xFF4A4644),
            outlineVariant: AppColors.hairlineDark,
            error: AppColors.dangerDark,
            onError: Color(0xFF3A1210),
          )
        : const ColorScheme.light(
            primary: AppColors.brandRed,
            onPrimary: Colors.white,
            primaryContainer: Color(0xFFFCE7EA),
            onPrimaryContainer: Color(0xFF6E0A1B),
            secondary: AppColors.brandBlue,
            onSecondary: Colors.white,
            secondaryContainer: Color(0xFFE4EDF5),
            onSecondaryContainer: Color(0xFF00223F),
            surface: AppColors.paper,
            onSurface: AppColors.inkLight,
            surfaceContainerLowest: Colors.white,
            surfaceContainerLow: AppColors.paperRaised,
            surfaceContainer: Color(0xFFF7F4F2),
            surfaceContainerHigh: AppColors.paperSunken,
            surfaceContainerHighest: Color(0xFFEDE9E6),
            onSurfaceVariant: AppColors.inkMutedLight,
            outline: Color(0xFFB9B2AE),
            outlineVariant: AppColors.hairlineLight,
            error: AppColors.dangerLight,
            onError: Colors.white,
          );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      splashFactory: InkSparkle.splashFactory,
    );

    final text = base.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    return base.copyWith(
      extensions: [semantic],
      scaffoldBackgroundColor: scheme.surface,

      textTheme: text.copyWith(
        // Tighter tracking on large type — loose headlines look amateur.
        displaySmall: text.displaySmall?.copyWith(letterSpacing: -1.0),
        headlineMedium: text.headlineMedium?.copyWith(letterSpacing: -0.5),
        headlineSmall: text.headlineSmall?.copyWith(letterSpacing: -0.3),
        titleLarge: text.titleLarge?.copyWith(
          letterSpacing: -0.2,
          fontWeight: FontWeight.w600,
        ),
      ),

      // A flat app bar that sits ON the canvas. A coloured bar is the single
      // biggest thing that dates an app.
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: scheme.onSurface,
        ),
      ),

      // Hairline borders, no shadows. Depth comes from the line, not a blur.
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

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: semantic.hairline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          foregroundColor: scheme.primary,
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: scheme.surfaceContainerHigh,
          foregroundColor: scheme.onSurfaceVariant,
          selectedBackgroundColor: scheme.onSurface,
          selectedForegroundColor: scheme.surface,
          side: BorderSide(color: semantic.hairline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: semantic.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: semantic.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: scheme.onSurface, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Gap.lg,
          vertical: Gap.lg,
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
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
        backgroundColor: scheme.onSurface,
        contentTextStyle: text.bodyMedium?.copyWith(color: scheme.surface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
      ),

      tabBarTheme: TabBarThemeData(
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: semantic.hairline,
        labelColor: scheme.onSurface,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        labelStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: text.titleSmall,
      ),

      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: Gap.lg),
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
