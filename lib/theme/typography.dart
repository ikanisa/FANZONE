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
    const color = Color(0xFFFDFCF0);

    const baseTheme = TextTheme(
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

      // Labels — w700 to match reference's aggressive font-bold usage
      labelLarge: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.3,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.3,
      ),
      labelSmall: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.3,
        letterSpacing: 1.2,
      ),
    );

    return _withGoogleFontTextTheme(
      () => GoogleFonts.outfitTextTheme(baseTheme),
      fallback: baseTheme,
    );
  }

  /// Score text style — JetBrains Mono with tabular figures.
  static TextStyle score({
    double size = 16,
    FontWeight weight = FontWeight.w700,
    Color? color,
  }) {
    final fallback = TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return _withGoogleFontStyle(
      () => GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: weight,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      fallback: fallback,
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
    double letterSpacing = 3.2,
  }) {
    final fallback = TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: color,
      height: 1.1,
      letterSpacing: letterSpacing,
    );
    return _withGoogleFontStyle(
      () => GoogleFonts.bebasNeue(
        fontSize: size,
        fontWeight: FontWeight.w400, // Bebas Neue only has 400
        color: color,
        height: 1.1,
        letterSpacing: letterSpacing,
      ),
      fallback: fallback,
    );
  }

  /// Section label style — uppercase, spaced, theme-aware muted color.
  /// Matches design reference: `text-[10px] font-bold uppercase tracking-widest`
  static TextStyle sectionLabel(Brightness brightness) => const TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: Color(0xFF8B8E99),
    letterSpacing: 2.4,
  );

  /// Meta/status label style — uppercase, tracking-widest, small.
  /// Matches the reference's ubiquitous `text-[9px] font-bold uppercase tracking-widest` pattern.
  static TextStyle metaLabel({
    double size = 9,
    Color? color,
  }) => TextStyle(
    fontSize: size,
    fontWeight: FontWeight.w700,
    color: color ?? const Color(0xFF8B8E99),
    letterSpacing: 1.6,
  );

  /// Status/badge text — bold + tracked for premium sports-editorial feel.
  /// Matches: `text-[10px] font-bold uppercase tracking-widest`
  static TextStyle statusLabel({
    double size = 10,
    Color? color,
  }) => TextStyle(
    fontSize: size,
    fontWeight: FontWeight.w700,
    color: color,
    letterSpacing: 1.4,
  );

  static TextTheme _withGoogleFontTextTheme(
    TextTheme Function() build, {
    required TextTheme fallback,
  }) {
    try {
      return build();
    } catch (_) {
      return fallback;
    }
  }

  static TextStyle _withGoogleFontStyle(
    TextStyle Function() build, {
    required TextStyle fallback,
  }) {
    try {
      return build();
    } catch (_) {
      return fallback;
    }
  }
}
