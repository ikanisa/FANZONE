import 'package:flutter/material.dart';

/// FANZONE design tokens — dark-first with a two-color brand system.
///
/// The only platform brand colors are:
///   Soft Mint  #98FF98 — primary interactive, selected, focus, positive
///   Warm Coral #FF7F50 — CTA, highlight, pending, emphasis
///
/// Supporting colors are limited to neutral surfaces plus strict danger/error.
abstract final class FzColors {
  // ════════════════════════════════════════════
  // Dark Theme (default) — Warm Stone palette
  // Night Sandstone foundation — UNTOUCHED.
  // ════════════════════════════════════════════
  static const darkBg = Color(0xFF09090B);
  static const darkSurface = Color(0xFF131418);
  static const darkSurface2 = Color(0xFF18191E);
  static const darkSurface3 = Color(0xFF22232A);
  static const darkBorder = Color(0xFF272831);
  static const darkText = Color(0xFFFDFCF0);
  static const darkMuted = Color(0xFF8B8E99);

  // ════════════════════════════════════════════
  // Legacy light-theme aliases
  // FANZONE is dark-only, so these names resolve to the dark palette to
  // collapse any stray light-mode code paths back onto the supported colors.
  // ════════════════════════════════════════════
  static const lightBg = darkBg;
  static const lightSurface = darkSurface;
  static const lightSurface2 = darkSurface2;
  static const lightSurface3 = darkSurface3;
  static const lightBorder = darkBorder;
  static const lightText = darkText;
  static const lightMuted = darkMuted;

  // ════════════════════════════════════════════
  // Official platform brand colors
  // ════════════════════════════════════════════

  /// Soft Mint #98FF98 — primary interactive, selected and focus color.
  static const primary = Color(0xFF98FF98);
  static const onPrimary = Color(0xFF061514);

  /// Warm Coral #FF7F50 — emphasized CTA and highlight color.
  static const secondary = Color(0xFFFF7F50);
  static const onSecondary = Color(0xFF2A120A);

  // ════════════════════════════════════════════
  // Semantic support colors
  // ════════════════════════════════════════════
  /// Red #EF4444 — danger / LIVE / error.
  static const danger = Color(0xFFEF4444);

  static const success = primary;
  static const coral = secondary;
  static const live = danger;
  static const warning = secondary;
  static const error = danger;

  // Cards / Yellow / Red
  static const yellowCard = secondary;
  static const redCard = Color(0xFFDC2626);

  // ════════════════════════════════════════════
  // Color Schemes
  // ════════════════════════════════════════════
  static const darkColorScheme = ColorScheme.dark(
    surface: darkSurface,
    onSurface: darkText,
    primary: primary,
    onPrimary: onPrimary,
    secondary: secondary,
    onSecondary: onSecondary,
    tertiary: secondary,
    error: error,
    onError: Colors.white,
    outline: darkBorder,
    surfaceContainerHighest: darkSurface3,
  );

  static const lightColorScheme = darkColorScheme;
}
