import 'package:flutter/material.dart';

/// FANZONE design tokens — Night Sandstone dark mode + vibrant content palette.
///
/// Dark-first. Premium neon-accentuated sports-financial identity.
/// 7 strict content colors on a warm Stone-dark background.
///
/// Color Mapping:
///   Cream   #FDFCF0 — primary text (dark mode)
///   Cyan    #22D3EE — main interactive accent (nav, tabs, badges)
///   Blue    #2563EB — secondary interactive (gradients, hooks)
///   Teal    #0F7B6C — financial/stable data, brand highlight
///   Mint    #98FF98 — success, wins, positive earnings
///   Coral   #FF7F50 — pending, neutral tags, warnings
///   Red     #EF4444 — danger, LIVE, errors, notifications
abstract final class FzColors {
  // ════════════════════════════════════════════
  // Dark Theme (default) — Warm Stone palette
  // Night Sandstone foundation — UNTOUCHED.
  // ════════════════════════════════════════════
  static const darkBg = Color(0xFF0C0A09);       // Stone 950
  static const darkSurface = Color(0xFF1C1917);   // Stone 900
  static const darkSurface2 = Color(0xFF292524);  // Stone 800
  static const darkSurface3 = Color(0xFF44403C);  // Stone 700
  static const darkBorder = Color(0xFF292524);    // Stone 800
  static const darkText = Color(0xFFFDFCF0);      // Cream — enhanced readability
  static const darkMuted = Color(0xFFA8A29E);     // Stone 400

  // ════════════════════════════════════════════
  // Light Theme
  // ════════════════════════════════════════════
  static const lightBg = Color(0xFFF5F5F4);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurface2 = Color(0xFFE7E5E4);
  static const lightSurface3 = Color(0xFFD6D3D1);
  static const lightBorder = Color(0xFFD6D3D1);
  static const lightText = Color(0xFF1C1917);
  static const lightMuted = Color(0xFF57534E);   // Stone 600 — WCAG AA compliant

  // ════════════════════════════════════════════
  // Content Palette — 7 vibrant colors
  // Applied to text, icons, accents, badges,
  // charts, indicators. NEVER to backgrounds.
  // ════════════════════════════════════════════

  /// Cyan #22D3EE — primary interactive accent.
  /// Active navigation icons, tab indicators, interactive buttons,
  /// FAN badge glow, match sliders. CSS-glow-like presence.
  static const accent = Color(0xFF22D3EE);
  static const accentDark = Color(0xFF0891B2);    // Cyan deeper (pressed/focus)

  /// Blue #2563EB — secondary interactive hooks.
  /// Gradient endpoints, secondary CTAs, animated financial gradients.
  static const blue = Color(0xFF2563EB);

  /// Teal #0F7B6C — financial/stable data sections.
  /// Wallet split charts, data components, "FAN" brand highlight,
  /// upper navigation header accents.
  static const teal = Color(0xFF0F7B6C);

  /// Coral #FF7F50 — pending/neutral transaction tags.
  /// Interim transaction data, warnings, favourites stars,
  /// stake amounts. Professional warmth against dark frame.
  static const coral = Color(0xFFFF7F50);

  /// Mint Green #98FF98 — success driver.
  /// Prediction wins, positive wallet earnings, daily context,
  /// financial clarity numbers. Bright illuminating presence.
  static const success = Color(0xFF98FF98);

  /// Red #EF4444 — danger / LIVE / error.
  /// Notification badge bubbles, LIVE match indicator, error states,
  /// strict and noticeable app update/alert signals.
  static const danger = Color(0xFFEF4444);

  // Status semantic aliases
  static const live = danger;
  static const warning = coral;
  static const error = danger;

  // ════════════════════════════════════════════
  // Backwards-compatible aliases
  // Ensures existing code using old token names
  // compiles without changes.
  // ════════════════════════════════════════════
  static const maltaRed = danger;
  static const amber = coral;
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
    primary: accent,
    onPrimary: Colors.white,
    secondary: teal,
    onSecondary: Colors.white,
    error: error,
    onError: Colors.white,
    outline: darkBorder,
    surfaceContainerHighest: darkSurface3,
  );

  static const lightColorScheme = ColorScheme.light(
    surface: lightSurface,
    onSurface: lightText,
    primary: accentDark,
    onPrimary: Colors.white,
    secondary: teal,
    onSecondary: Colors.white,
    error: error,
    onError: Colors.white,
    outline: lightBorder,
    surfaceContainerHighest: lightSurface3,
  );
}
