import 'package:flutter/material.dart';

/// FANZONE typography system — dark sports-gaming style.
///
/// - Bebas Neue: condensed sports headings, hero scores, FET numbers
/// - Outfit: clean rounded sans for body/UI text
/// - JetBrains Mono: tabular numerals for scores
/// - Minimum 12px for accessibility
/// - Large, high-weight hierarchy for the sports-gaming aesthetic
abstract final class FzTypography {
  static const String _outfitFamily = 'Outfit';
  static const String _monoFamily = 'JetBrains Mono';
  static const String _bebasFamily = 'Bebas Neue';

  /// Base text theme using Outfit for the entire app.
  static TextTheme textTheme(Brightness brightness) {
    const color = Color(0xFFFFFDF3);

    const baseTheme = TextTheme(
      // Display
      displayLarge: TextStyle(
        fontSize: 52,
        fontWeight: FontWeight.w900,
        color: color,
        height: 1.05,
      ),
      displayMedium: TextStyle(
        fontSize: 44,
        fontWeight: FontWeight.w900,
        color: color,
        height: 1.08,
      ),
      displaySmall: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w900,
        color: color,
        height: 1.1,
      ),

      // Headlines
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w900,
        color: color,
        height: 1.12,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w900,
        color: color,
        height: 1.15,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w900,
        color: color,
        height: 1.18,
      ),

      // Titles
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w900,
        color: color,
        height: 1.2,
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: color,
        height: 1.25,
      ),
      titleSmall: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: color,
        height: 1.3,
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
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.45,
      ),
      bodySmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.45,
      ),

      // Labels — high weight for operational chips, buttons, and badges.
      labelLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w900,
        color: color,
        height: 1.25,
      ),
      labelMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w900,
        color: color,
        height: 1.25,
      ),
      labelSmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        color: color,
        height: 1.25,
        letterSpacing: 1.2,
      ),
    );

    return baseTheme.apply(fontFamily: _outfitFamily);
  }

  /// Hero score — Bebas Neue condensed, 64–84px.
  /// Used for massive score displays on match detail screens.
  static TextStyle heroScore({double size = 72, Color? color}) {
    return TextStyle(
      fontFamily: _bebasFamily,
      fontSize: size,
      fontWeight: FontWeight.w400, // Bebas only has 400
      color: color,
      height: 1.0,
      letterSpacing: 2.0,
    );
  }

  /// Hero FET number — Bebas Neue, 34–44px.
  /// Used for large FET balance displays.
  static TextStyle heroFet({double size = 40, Color? color}) {
    return TextStyle(
      fontFamily: _bebasFamily,
      fontSize: size,
      fontWeight: FontWeight.w400,
      color: color,
      height: 1.1,
      letterSpacing: 1.5,
    );
  }

  /// Sports title — Bebas Neue, 26–34px, for section headings.
  static TextStyle sportsTitle({
    double size = 30,
    Color? color,
    double letterSpacing = 1.0,
  }) {
    return TextStyle(
      fontFamily: _bebasFamily,
      fontSize: size,
      fontWeight: FontWeight.w400,
      color: color,
      height: 1.15,
      letterSpacing: letterSpacing,
    );
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
    fontSize: 13,
    fontWeight: FontWeight.w900,
    color: Color(0xFF6F7280),
    letterSpacing: 1.8,
  );

  /// Meta/status label style — uppercase, tracking-widest, small.
  static TextStyle metaLabel({double size = 12, Color? color}) => TextStyle(
    fontSize: size,
    fontWeight: FontWeight.w900,
    color: color ?? const Color(0xFF6F7280),
    letterSpacing: 1.2,
  );

  /// Status/badge text — bold + tracked for premium sports-editorial feel.
  static TextStyle statusLabel({double size = 13, Color? color}) => TextStyle(
    fontSize: size,
    fontWeight: FontWeight.w900,
    color: color,
    letterSpacing: 1.1,
  );

  /// Chip label — small, uppercase, very bold.
  static TextStyle chipLabel({double size = 13, Color? color}) => TextStyle(
    fontSize: size,
    fontWeight: FontWeight.w900,
    color: color,
    letterSpacing: 0.8,
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
