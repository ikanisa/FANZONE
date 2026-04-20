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
        selectedItemColor: FzColors.primary,
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
        labelColor: FzColors.primary,
        unselectedLabelColor: FzColors.darkMuted,
        indicatorColor: FzColors.primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: textTheme.titleSmall,
        unselectedLabelStyle: textTheme.bodySmall,
        dividerColor: FzColors.darkBorder,
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: FzColors.darkSurface2,
        selectedColor: FzColors.primary,
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
          borderSide: const BorderSide(color: FzColors.primary, width: 1.5),
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
        color: FzColors.primary,
      ),

      // Splash / InkWell
      splashFactory: InkSparkle.splashFactory,
    );
  }

  // ════════════════════════════════════════════
  // Legacy light-theme entry point
  // Any caller that still requests a light theme gets the supported dark theme.
  // ════════════════════════════════════════════
  static ThemeData light() => dark();
}
