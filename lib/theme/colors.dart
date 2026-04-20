import 'package:flutter/material.dart';

/// FANZONE design tokens — Night Sandstone dark mode + vibrant content palette.
///
/// Dark-first. Premium sports-financial identity.
/// Canonical tokens are sourced from /Users/jeanbosco/Downloads/FANZONE.
///
/// Color Mapping:
///   Cream   #FDFCF0 — primary text (dark mode)
///   Cyan    #22D3EE — primary interactive (nav, tabs, badges, focus)
///   Blue    #2563EB — data visualization accent
///   Coral   #FF7F50 — warm highlights / secondary accent
///   Mint    #98FF98 — success / positive states
///   Teal    #0F7B6C — financial/stable data, brand highlight
///   Red     #EF4444 — danger, LIVE, errors, notifications
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
  // Platform primary / accent colors
  // ════════════════════════════════════════════

  /// Cyan #22D3EE — primary interactive accent.
  /// Active navigation icons, tab indicators, interactive elements,
  /// badges and focus rings.
  static const primary = Color(0xFF22D3EE);
  static const primaryDark = Color(0xFF0891B2);

  /// Warm Coral #FF7F50 — secondary interactive / CTA accent.
  /// Primary CTA buttons, warm highlights, step indicators,
  /// notification dots, active borders, hover accents.
  static const secondary = Color(0xFFFF7F50);
  static const secondaryLight = Color(0xFFFF9E7A); // Lighter coral (hover)
  static const secondaryDark = Color(0xFFE5673E); // Darker coral (pressed)

  // ════════════════════════════════════════════
  // Content Palette — supporting colors
  // Applied to text, icons, accents, badges,
  // charts, indicators. NEVER to backgrounds.
  // ════════════════════════════════════════════

  /// Blue #2563EB — data visualization accent.
  /// Chart gradients, secondary data hooks, animated financial gradients.
  static const blue = Color(0xFF2563EB);

  /// Teal #0F7B6C — financial/stable data sections.
  /// Wallet split charts, data components, "FAN" brand highlight,
  /// upper navigation header accents.
  static const teal = Color(0xFF0F7B6C);

  /// Red #EF4444 — danger / LIVE / error.
  /// Notification badge bubbles, LIVE match indicator, error states,
  /// strict and noticeable app update/alert signals.
  static const danger = Color(0xFFEF4444);

  // ════════════════════════════════════════════
  // Semantic aliases
  // ════════════════════════════════════════════
  static const success = Color(0xFF98FF98);
  static const coral = secondary; // Coral = pending/warm tags
  static const live = danger;
  static const warning = secondary; // Warm coral for warnings
  static const error = danger;

  // ════════════════════════════════════════════
  // Backwards-compatible aliases
  // Maps old token names → new tokens so existing
  // code compiles without changes during migration.
  // ════════════════════════════════════════════
  static const accent = primary;
  static const accentDark = primaryDark;
  static const maltaRed = danger;
  static const amber = secondary;
  static const violet = blue;

  // Cards / Yellow / Red
  static const yellowCard = Color(0xFFFBBF24);
  static const redCard = Color(0xFFDC2626);

  // ════════════════════════════════════════════
  // Color Schemes
  // ════════════════════════════════════════════
  static const darkColorScheme = ColorScheme.dark(
    surface: darkSurface,
    onSurface: darkText,
    primary: primary,
    onPrimary: Color(0xFF09090B),
    secondary: teal,
    onSecondary: Colors.white,
    error: error,
    onError: Colors.white,
    outline: darkBorder,
    surfaceContainerHighest: darkSurface3,
  );

  static const lightColorScheme = darkColorScheme;
}
