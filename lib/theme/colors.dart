import 'package:flutter/material.dart';

/// FANZONEUI Electric Noir design tokens.
///
/// The standalone FANZONEUI export is the primary visual reference for the
/// Flutter client. These tokens intentionally mirror its obsidian surfaces,
/// electric blue actions, and neon green reward language.
abstract final class FzColors {
  // ════════════════════════════════════════════
  // Dark Theme (default) — Warm Stone palette
  // Night Sandstone foundation — UNTOUCHED.
  // ════════════════════════════════════════════
  static const darkBg = Color(0xFF0F0F12);
  static const darkSurface = Color(0xFF16161D);
  static const darkSurface2 = Color(0xFF1E1E27);
  static const darkSurface3 = Color(0xFF272735);
  static const darkSurface4 = Color(0xFF323244);
  static const darkBorder = Color(0xFF2A2A36);
  static const darkText = Color(0xFFF6F7FB);
  static const darkTextSecondary = Color(0xFFD4D7E2);
  static const darkMuted = Color(0xFF8B90A0);

  // ════════════════════════════════════════════
  // Compatibility light-theme aliases
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
  static const accent = Color(0xFF2E5BFF);
  static const accent2 = Color(0xFF39FF14);
  static const accent3 = Color(0xFFFFB020);
  static const success = Color(0xFF39FF14);
  static const danger = Color(0xFFFF4D6D);
  static const teal = Color(0xFF00D4C8);
  static const warning = Color(0xFFFFB020);
  static const whatsapp = Color(0xFF25D366);

  // Compatibility aliases still used across the Flutter codebase.
  static const primary = accent;
  static const onPrimary = Colors.white;
  static const secondary = accent2;
  static const onSecondary = darkBg;
  static const action = accent;
  static const onAction = Colors.white;

  // ════════════════════════════════════════════
  // Semantic aliases
  // ════════════════════════════════════════════
  static const cyan = accent;
  static const blue = accent2;
  static const coral = accent3;
  static const live = danger;
  static const error = danger;
  static const info = accent;

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
    secondary: secondary,
    onSecondary: onSecondary,
    tertiary: accent3,
    error: error,
    onError: Colors.white,
    outline: darkBorder,
    surfaceContainerHighest: darkSurface3,
  );

  static const lightColorScheme = darkColorScheme;
}
