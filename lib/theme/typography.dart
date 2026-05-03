import 'package:flutter/material.dart';

/// FANZONE typography system.
///
/// - Outfit: clean modern sans-serif for all UI text
/// - Outfit: display and body text for a premium operational feel
/// - JetBrains Mono: tabular numerals for scores only
/// - Minimum 12px for accessibility
/// - Large, high-weight hierarchy for the sports-bar command-center UI
abstract final class FzTypography {
  static const String _outfitFamily = 'Outfit';
  static const String _monoFamily = 'JetBrains Mono';

  /// Base text theme using Outfit for the entire app.
  static TextTheme textTheme(Brightness brightness) {
    const color = Color(0xFFF8FAFC);

    const baseTheme = TextTheme(
      // Display
      displayLarge: TextStyle(
        fontSize: 48,
        fontWeight: FontWeight.w900,
        color: color,
        height: 1.05,
      ),
      displayMedium: TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.w900,
        color: color,
        height: 1.08,
      ),
      displaySmall: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        color: color,
        height: 1.1,
      ),

      // Headlines
      headlineLarge: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        color: color,
        height: 1.15,
      ),
      headlineMedium: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: color,
        height: 1.18,
      ),
      headlineSmall: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: color,
        height: 1.2,
      ),

      // Titles
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: color,
        height: 1.25,
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.3,
      ),
      titleSmall: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.35,
      ),

      // Body
      bodyLarge: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.45,
      ),
      bodyMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: color,
        height: 1.45,
      ),
      bodySmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.45,
      ),

      // Labels — high weight for operational chips, buttons, and badges.
      labelLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: color,
        height: 1.25,
      ),
      labelMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: color,
        height: 1.25,
      ),
      labelSmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: color,
        height: 1.25,
        letterSpacing: 1.2,
      ),
    );

    return baseTheme.apply(fontFamily: _outfitFamily);
  }

  /// Score text style — JetBrains Mono with tabular figures.
  static TextStyle score({
    double size = 18,
    FontWeight weight = FontWeight.w800,
    Color? color,
  }) {
    final fallback = TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return _withGoogleFontStyle(
      () => TextStyle(
        fontFamily: _monoFamily,
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

  /// Large score for match detail headers and hero numbers (32px).
  static TextStyle scoreLarge({Color? color}) => score(size: 32, color: color);

  /// Medium score for match cards (20px).
  static TextStyle scoreMedium({Color? color}) => score(size: 20, color: color);

  /// Display style for screen titles and section headers.
  /// Uses bundled Outfit weights to keep tests and offline builds deterministic.
  static TextStyle display({
    double size = 40,
    Color? color,
    double letterSpacing = 0,
    FontWeight weight = FontWeight.w900,
  }) {
    final fallback = TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: 1.1,
      letterSpacing: letterSpacing,
    );
    return _withGoogleFontStyle(
      () => TextStyle(
        fontFamily: _outfitFamily,
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: 1.1,
        letterSpacing: letterSpacing,
      ),
      fallback: fallback,
    );
  }

  /// Section label style — uppercase, spaced, theme-aware muted color.
  /// Keeps compact metadata legible without dropping below 12px.
  static TextStyle sectionLabel(Brightness brightness) => const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w800,
    color: Color(0xFF8B8E99),
    letterSpacing: 1.8,
  );

  /// Meta/status label style — uppercase, tracking-widest, small.
  static TextStyle metaLabel({double size = 12, Color? color}) => TextStyle(
    fontSize: size,
    fontWeight: FontWeight.w800,
    color: color ?? const Color(0xFF8B8E99),
    letterSpacing: 1.2,
  );

  /// Status/badge text — bold + tracked for premium sports-editorial feel.
  static TextStyle statusLabel({double size = 13, Color? color}) => TextStyle(
    fontSize: size,
    fontWeight: FontWeight.w800,
    color: color,
    letterSpacing: 1.1,
  );

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
