import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'colors.dart';
import 'radii.dart';
import 'typography.dart';

/// FANZONE theme — sports-hospitality aesthetic.
///
/// Cyan primary actions, orange FET accents, red live states.
/// Large rounded cards, pill CTAs, bold typography.
abstract final class FzTheme {
  static ThemeData dark() => _build(
    brightness: Brightness.dark,
    colorScheme: FzColors.darkColorScheme,
    background: FzColors.darkBg,
    surface: FzColors.darkSurface,
    surfaceAlt: FzColors.darkSurface2,
    chipSurface: FzColors.darkSurface2,
    border: FzColors.darkBorder,
    text: FzColors.darkText,
    muted: FzColors.darkMuted,
  );

  static ThemeData light() => _build(
    brightness: Brightness.light,
    colorScheme: FzColors.lightColorScheme,
    background: FzColors.lightBg,
    surface: FzColors.lightSurface,
    surfaceAlt: FzColors.lightSurface2,
    chipSurface: FzColors.lightSurface2,
    border: FzColors.lightBorder,
    text: FzColors.lightText,
    muted: FzColors.lightMuted,
  );

  static ThemeData highContrastDark() => _build(
    brightness: Brightness.dark,
    colorScheme: FzColors.highContrastDarkColorScheme,
    background: Colors.black,
    surface: FzColors.darkSurface,
    surfaceAlt: FzColors.darkSurface3,
    chipSurface: FzColors.darkSurface4,
    border: Colors.white,
    text: Colors.white,
    muted: const Color(0xFFE0E0E0),
    highContrast: true,
  );

  static ThemeData highContrastLight() => _build(
    brightness: Brightness.light,
    colorScheme: FzColors.highContrastLightColorScheme,
    background: Colors.white,
    surface: Colors.white,
    surfaceAlt: const Color(0xFFF2F5F8),
    chipSurface: const Color(0xFFE8EDF3),
    border: Colors.black,
    text: Colors.black,
    muted: const Color(0xFF20242B),
    highContrast: true,
  );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme colorScheme,
    required Color background,
    required Color surface,
    required Color surfaceAlt,
    required Color chipSurface,
    required Color border,
    required Color text,
    required Color muted,
    bool highContrast = false,
  }) {
    final textTheme = FzTypography.textTheme(brightness);
    final primary = colorScheme.primary;
    final onPrimary = colorScheme.onPrimary;
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      useMaterial3: true,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: textTheme.titleMedium,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: background,
        ),
      ),

      // Bottom Navigation
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: muted,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        elevation: 0,
      ),

      // Cards
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(FzRadii.card)),
          side: BorderSide(color: border, width: highContrast ? 1.5 : 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: border,
        thickness: highContrast ? 1 : 0.5,
        space: 0,
      ),

      // TabBar
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: muted,
        indicatorColor: primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: textTheme.titleSmall,
        unselectedLabelStyle: textTheme.bodySmall,
        dividerColor: border,
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: chipSurface,
        selectedColor: primary.withValues(alpha: isDark ? 0.18 : 0.12),
        labelStyle: textTheme.labelSmall!,
        side: BorderSide(color: border, width: highContrast ? 1.5 : 1),
        shape: const RoundedRectangleBorder(
          borderRadius: FzRadii.compactRadius,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),

      // Filled Button — cyan pill CTA
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          disabledBackgroundColor: primary.withValues(alpha: 0.35),
          disabledForegroundColor: onPrimary.withValues(alpha: 0.7),
          minimumSize: const Size(64, 56),
          shape: const RoundedRectangleBorder(borderRadius: FzRadii.fullRadius),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ),

      // Elevated Button — cyan pill
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          disabledBackgroundColor: primary.withValues(alpha: 0.35),
          disabledForegroundColor: onPrimary.withValues(alpha: 0.7),
          minimumSize: const Size(64, 56),
          shape: const RoundedRectangleBorder(borderRadius: FzRadii.fullRadius),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          elevation: 0,
        ),
      ),

      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: BorderSide(color: border, width: highContrast ? 1.5 : 1),
          minimumSize: const Size(64, 56),
          shape: const RoundedRectangleBorder(borderRadius: FzRadii.fullRadius),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          shape: const RoundedRectangleBorder(
            borderRadius: FzRadii.compactRadius,
          ),
        ),
      ),

      // Bottom Sheet — large rounded top corners
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(FzRadii.bottomSheet),
          ),
        ),
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FzRadii.button),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FzRadii.button),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FzRadii.button),
          borderSide: BorderSide(color: primary, width: highContrast ? 2 : 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: muted),
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceAlt,
        contentTextStyle: textTheme.bodySmall?.copyWith(color: text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FzRadii.button),
        ),
      ),

      // Progress
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),

      // Splash / InkWell
      splashFactory: InkRipple.splashFactory,
    );
  }
}
