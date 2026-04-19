import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// FANZONE typography system.
///
/// - Outfit: clean modern sans-serif for all UI text
/// - Bebas Neue: display font for screen titles and section headers
/// - JetBrains Mono: tabular numerals for scores only
/// - Minimum 12px for accessibility
abstract final class FzTypography {
  /// Base text theme using Outfit for the entire app.
  static TextTheme textTheme(Brightness brightness) {
    final color = brightness == Brightness.dark
        ? const Color(0xFFFDFCF0)  // Cream — vibrant readability
        : const Color(0xFF1C1917);

    return GoogleFonts.outfitTextTheme(
      TextTheme(
        // Display
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: color,
          height: 1.2,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: color,
          height: 1.2,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: color,
          height: 1.2,
        ),

        // Headlines
        headlineLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: color,
          height: 1.3,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: color,
          height: 1.3,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: color,
          height: 1.3,
        ),

        // Titles
        titleLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: color,
          height: 1.4,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: color,
          height: 1.4,
        ),
        titleSmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: color,
          height: 1.4,
        ),

        // Body
        bodyLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: color,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: color,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: color,
          height: 1.5,
        ),

        // Labels
        labelLarge: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: color,
          height: 1.3,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
          height: 1.3,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
          height: 1.3,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  /// Score text style — JetBrains Mono with tabular figures.
  static TextStyle score({
    double size = 16,
    FontWeight weight = FontWeight.w700,
    Color? color,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: weight,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// Compact score for list rows (14px).
  static TextStyle scoreCompact({Color? color}) =>
      score(size: 14, color: color);

  /// Large score for match detail header (24px).
  static TextStyle scoreLarge({Color? color}) => score(size: 24, color: color);

  /// Medium score for match cards (18px).
  static TextStyle scoreMedium({Color? color}) => score(size: 18, color: color);

  /// Display style — Bebas Neue for screen titles and section headers.
  /// Matches the original design's `font-display` class.
  static TextStyle display({
    double size = 32,
    Color? color,
    double letterSpacing = 2.0,
  }) {
    return GoogleFonts.bebasNeue(
      fontSize: size,
      fontWeight: FontWeight.w400, // Bebas Neue only has 400
      color: color,
      height: 1.1,
      letterSpacing: letterSpacing,
    );
  }

  /// Section label style — uppercase, spaced, theme-aware muted color.
  static TextStyle sectionLabel(Brightness brightness) => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: brightness == Brightness.dark
        ? const Color(0xFFA8A29E)  // FzColors.darkMuted (Stone 400)
        : const Color(0xFF57534E), // FzColors.lightMuted (Stone 600)
    letterSpacing: 0.8,
  );
}
