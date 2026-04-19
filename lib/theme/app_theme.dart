import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'colors.dart';
import 'radii.dart';
import 'typography.dart';

/// FANZONE theme — dark-first, premium, football-native, non-gambling.
abstract final class FzTheme {
  // ════════════════════════════════════════════
  // DARK THEME (default)
  // ════════════════════════════════════════════
  static ThemeData dark() {
    final textTheme = FzTypography.textTheme(Brightness.dark);

    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: FzColors.darkColorScheme,
      scaffoldBackgroundColor: FzColors.darkBg,
      textTheme: textTheme,
      useMaterial3: true,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: FzColors.darkSurface,
        foregroundColor: FzColors.darkText,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: textTheme.titleMedium,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),

      // Bottom Navigation
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: FzColors.darkSurface,
        selectedItemColor: FzColors.accent,
        unselectedItemColor: FzColors.darkMuted,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
        elevation: 0,
      ),

      // Cards
      cardTheme: const CardThemeData(
        color: FzColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: FzRadii.cardRadius,
          side: BorderSide(color: FzColors.darkBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: FzColors.darkBorder,
        thickness: 0.5,
        space: 0,
      ),

      // TabBar
      tabBarTheme: TabBarThemeData(
        labelColor: FzColors.accent,
        unselectedLabelColor: FzColors.darkMuted,
        indicatorColor: FzColors.accent,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: textTheme.titleSmall,
        unselectedLabelStyle: textTheme.bodySmall,
        dividerColor: FzColors.darkBorder,
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: FzColors.darkSurface2,
        selectedColor: FzColors.accent,
        labelStyle: textTheme.labelSmall!,
        side: const BorderSide(color: FzColors.darkBorder),
        shape: const RoundedRectangleBorder(
          borderRadius: FzRadii.compactRadius,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // Bottom Sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: FzColors.darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(FzRadii.card),
          ),
        ),
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FzColors.darkSurface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FzColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FzColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FzColors.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: FzColors.darkMuted),
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: FzColors.darkSurface2,
        contentTextStyle: textTheme.bodySmall?.copyWith(
          color: FzColors.darkText,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // Progress
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: FzColors.accent,
      ),

      // Splash / InkWell
      splashFactory: InkSparkle.splashFactory,
    );
  }

  // ════════════════════════════════════════════
  // LIGHT THEME
  // ════════════════════════════════════════════
  static ThemeData light() {
    final textTheme = FzTypography.textTheme(Brightness.light);

    return ThemeData(
      brightness: Brightness.light,
      colorScheme: FzColors.lightColorScheme,
      scaffoldBackgroundColor: FzColors.lightBg,
      textTheme: textTheme,
      useMaterial3: true,

      appBarTheme: AppBarTheme(
        backgroundColor: FzColors.lightSurface,
        foregroundColor: FzColors.lightText,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: textTheme.titleMedium,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: FzColors.lightSurface,
        selectedItemColor: FzColors.accentDark,
        unselectedItemColor: FzColors.lightMuted,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
        elevation: 0,
      ),

      cardTheme: const CardThemeData(
        color: FzColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: FzRadii.cardRadius,
          side: BorderSide(color: FzColors.lightBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      dividerTheme: const DividerThemeData(
        color: FzColors.lightBorder,
        thickness: 0.5,
        space: 0,
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: FzColors.accentDark,
        unselectedLabelColor: FzColors.lightMuted,
        indicatorColor: FzColors.accentDark,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: textTheme.titleSmall,
        unselectedLabelStyle: textTheme.bodySmall,
        dividerColor: FzColors.lightBorder,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: FzColors.lightSurface2,
        selectedColor: FzColors.accentDark,
        labelStyle: textTheme.labelSmall!,
        side: const BorderSide(color: FzColors.lightBorder),
        shape: const RoundedRectangleBorder(
          borderRadius: FzRadii.compactRadius,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: FzColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(FzRadii.card),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FzColors.lightSurface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FzColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FzColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FzColors.accentDark, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: FzColors.lightMuted),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: FzColors.lightSurface2,
        contentTextStyle: textTheme.bodySmall?.copyWith(
          color: FzColors.lightText,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: FzColors.accentDark,
      ),

      splashFactory: InkSparkle.splashFactory,
    );
  }
}
