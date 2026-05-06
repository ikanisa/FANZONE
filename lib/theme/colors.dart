import 'package:flutter/material.dart';

/// FANZONE Dark Sports-Gaming design tokens.
///
/// Near-black surfaces, cyan/orange/red controlled accents,
/// warm off-white text. No bright whites, no dirty greys.
abstract final class FzColors {
  // ════════════════════════════════════════════
  // Dark Theme — Deep Black surfaces
  // ════════════════════════════════════════════
  static const darkBg = Color(0xFF050607);
  static const darkSurface = Color(0xFF15161D);
  static const darkSurface2 = Color(0xFF1B1C25);
  static const darkSurface3 = Color(0xFF20212B);
  static const darkSurface4 = Color(0xFF2A2C39);
  static const darkBorder = Color(0xFF2A2C39);
  static const darkText = Color(0xFFFFFDF3);
  static const darkTextSecondary = Color(0xFF9A9CA8);
  static const darkMuted = Color(0xFF6F7280);

  // ════════════════════════════════════════════
  // Compatibility light-theme aliases
  // FANZONE is dark-only, so these resolve to the dark palette.
  // ════════════════════════════════════════════
  static const lightBg = darkBg;
  static const lightSurface = darkSurface;
  static const lightSurface2 = darkSurface2;
  static const lightSurface3 = darkSurface3;
  static const lightBorder = darkBorder;
  static const lightText = darkText;
  static const lightMuted = darkMuted;

  // ════════════════════════════════════════════
  // Primary accents — cyan/orange/red sports-gaming palette
  // ════════════════════════════════════════════
  static const accent = Color(0xFF27D8F2); // cyan — primary action
  static const accent2 = Color(0xFFFF7A4D); // orange — FET / reward
  static const accent3 = Color(0xFFFFD166); // gold — tertiary / warning
  static const success = Color(0xFF5BE06B); // green — open / eligible
  static const danger = Color(0xFFFF4D57); // red — live / error
  static const teal = Color(0xFF19D6F2); // active border cyan
  static const warning = Color(0xFFFFD166); // gold
  static const whatsapp = Color(0xFF25D366);

  // Compatibility aliases used across the Flutter codebase.
  static const primary = accent;
  static const onPrimary = Color(0xFF050607);
  static const secondary = accent2;
  static const onSecondary = Color(0xFF050607);
  static const action = accent;
  static const onAction = Color(0xFF050607);

  // ════════════════════════════════════════════
  // Semantic aliases
  // ════════════════════════════════════════════
  static const cyan = Color(0xFF27D8F2);
  static const orange = Color(0xFFFF7A4D);
  static const red = Color(0xFFFF4D57);
  static const green = Color(0xFF5BE06B);
  static const gold = Color(0xFFFFD166);
  static const blue = accent;
  static const coral = accent2;
  static const live = danger;
  static const error = danger;
  static const info = accent;

  // Active border accents
  static const activeBorderCyan = Color(0xFF19D6F2);
  static const activeBorderRed = Color(0xFFFF3E4D);

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
