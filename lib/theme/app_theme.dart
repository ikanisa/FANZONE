import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'colors.dart';
import 'radii.dart';
import 'typography.dart';

/// FANZONE theme — dark sports-gaming aesthetic.
///
/// Cyan primary actions, orange FET accents, red live states.
/// Large rounded cards, pill CTAs, bold typography.
abstract final class FzTheme {
  // ════════════════════════════════════════════
  // DARK THEME (only supported app appearance)
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
        backgroundColor: FzColors.darkBg,
        foregroundColor: FzColors.darkText,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: textTheme.titleMedium,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: FzColors.darkBg,
        ),
      ),

      // Bottom Navigation
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: FzColors.darkSurface,
        selectedItemColor: FzColors.accent,
        unselectedItemColor: FzColors.darkMuted,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
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
        selectedColor: FzColors.accent.withValues(alpha: 0.14),
        labelStyle: textTheme.labelSmall!,
        side: const BorderSide(color: FzColors.darkBorder),
        shape: const RoundedRectangleBorder(
          borderRadius: FzRadii.compactRadius,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),

      // Filled Button — cyan pill CTA
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: FzColors.accent,
          foregroundColor: FzColors.onAction,
          disabledBackgroundColor: FzColors.accent.withValues(alpha: 0.35),
          disabledForegroundColor: FzColors.onAction.withValues(alpha: 0.7),
          minimumSize: const Size(64, 56),
          shape: const RoundedRectangleBorder(borderRadius: FzRadii.fullRadius),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ),

      // Elevated Button — cyan pill
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: FzColors.accent,
          foregroundColor: FzColors.onAction,
          disabledBackgroundColor: FzColors.accent.withValues(alpha: 0.35),
          disabledForegroundColor: FzColors.onAction.withValues(alpha: 0.7),
          minimumSize: const Size(64, 56),
          shape: const RoundedRectangleBorder(borderRadius: FzRadii.fullRadius),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          elevation: 0,
        ),
      ),

      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: FzColors.darkText,
          side: const BorderSide(color: FzColors.darkBorder),
          minimumSize: const Size(64, 56),
          shape: const RoundedRectangleBorder(borderRadius: FzRadii.fullRadius),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: FzColors.accent,
          shape: const RoundedRectangleBorder(
            borderRadius: FzRadii.compactRadius,
          ),
        ),
      ),

      // Bottom Sheet — large rounded top corners
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: FzColors.darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(FzRadii.bottomSheet),
          ),
        ),
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FzColors.darkSurface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FzRadii.button),
          borderSide: const BorderSide(color: FzColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FzRadii.button),
          borderSide: const BorderSide(color: FzColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FzRadii.button),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FzRadii.button),
        ),
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
  // Compatibility guard
  // ════════════════════════════════════════════
  static ThemeData light() => dark();
}
