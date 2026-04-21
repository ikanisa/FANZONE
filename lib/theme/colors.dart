import 'package:flutter/material.dart';

/// FANZONE design tokens aligned to the permanent source-of-truth reference.
///
/// Canonical interactive palette:
/// - Accent   #22D3EE
/// - Accent2  #2563EB
/// - Accent3  #FF7F50
/// - Success  #98FF98
/// - Danger   #EF4444
/// - Teal     #0F7B6C
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
  // Canonical FANZONE accents from the original design
  // ════════════════════════════════════════════
  static const accent = Color(0xFF22D3EE);
  static const accent2 = Color(0xFF2563EB);
  static const accent3 = Color(0xFFFF7F50);
  static const success = Color(0xFF98FF98);
  static const danger = Color(0xFFEF4444);
  static const teal = Color(0xFF0F7B6C);
  static const warning = Color(0xFFEAB308);
  static const whatsapp = Color(0xFF25D366);

  // Legacy aliases still used across the Flutter codebase.
  static const primary = accent;
  static const onPrimary = darkBg;
  static const secondary = accent3;
  static const onSecondary = darkBg;

  // ════════════════════════════════════════════
  // Semantic aliases
  // ════════════════════════════════════════════
  static const cyan = accent;
  static const blue = accent2;
  static const coral = accent3;
  static const live = danger;
  static const error = danger;

  // Cards / Yellow / Red
  static const yellowCard = warning;
  static const redCard = Color(0xFFDC2626);

  // ════════════════════════════════════════════
  // Color Schemes
  // ════════════════════════════════════════════
  static const darkColorScheme = ColorScheme.dark(
    surface: darkSurface,
    onSurface: darkText,
    primary: accent,
    onPrimary: onPrimary,
    secondary: accent3,
    onSecondary: onSecondary,
    tertiary: accent2,
    error: error,
    onError: Colors.white,
    outline: darkBorder,
    surfaceContainerHighest: darkSurface3,
  );

  static const lightColorScheme = darkColorScheme;
}
