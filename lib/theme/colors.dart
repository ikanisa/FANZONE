import 'package:flutter/material.dart';

/// FANZONE sports-hospitality design tokens.
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
  // Light Theme — match-day hospitality surfaces
  // ════════════════════════════════════════════
  static const lightBg = Color(0xFFF7F9FC);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurface2 = Color(0xFFF0F4F8);
  static const lightSurface3 = Color(0xFFE4EAF1);
  static const lightBorder = Color(0xFFD5DEE8);
  static const lightText = Color(0xFF10131A);
  static const lightTextSecondary = Color(0xFF3E4654);
  static const lightMuted = Color(0xFF657084);

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

  static const lightColorScheme = ColorScheme.light(
    surface: lightSurface,
    onSurface: lightText,
    primary: accent,
    onPrimary: onPrimary,
    secondary: secondary,
    onSecondary: onSecondary,
    tertiary: accent3,
    error: error,
    onError: Colors.white,
    outline: lightBorder,
    surfaceContainerHighest: lightSurface3,
  );

  static const highContrastDarkColorScheme = ColorScheme.dark(
    surface: darkSurface,
    onSurface: Colors.white,
    primary: Color(0xFF66EAFF),
    onPrimary: Color(0xFF000000),
    secondary: Color(0xFFFFA47F),
    onSecondary: Color(0xFF000000),
    tertiary: Color(0xFFFFDD75),
    error: Color(0xFFFF7A82),
    onError: Color(0xFF000000),
    outline: Colors.white,
    surfaceContainerHighest: darkSurface4,
  );

  static const highContrastLightColorScheme = ColorScheme.light(
    surface: Colors.white,
    onSurface: Color(0xFF000000),
    primary: Color(0xFF006B7A),
    onPrimary: Colors.white,
    secondary: Color(0xFF9A350F),
    onSecondary: Colors.white,
    tertiary: Color(0xFF725700),
    error: Color(0xFFB00020),
    onError: Colors.white,
    outline: Color(0xFF000000),
    surfaceContainerHighest: Color(0xFFE8EDF3),
  );
}
