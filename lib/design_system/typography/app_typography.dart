import 'package:flutter/material.dart';

import '../../theme/typography.dart';
import '../tokens/app_colors.dart';

/// Public typography facade — sports-gaming style.
abstract final class AppTypography {
  static TextTheme textTheme(Brightness brightness) =>
      FzTypography.textTheme(brightness);

  // ════════════════════════════════════════════
  // Bebas Neue — condensed sports headings
  // ════════════════════════════════════════════

  /// Hero score — 64–84px Bebas Neue for massive score displays.
  static TextStyle heroScore({double size = 72, Color color = AppColors.text}) =>
      FzTypography.heroScore(size: size, color: color);

  /// Hero FET number — 34–44px Bebas Neue for large balance displays.
  static TextStyle heroFet({double size = 40, Color color = AppColors.text}) =>
      FzTypography.heroFet(size: size, color: color);

  /// Sports heading — 26–34px Bebas Neue for section titles.
  static TextStyle sportsHeading({
    double size = 30,
    Color color = AppColors.text,
  }) => FzTypography.sportsTitle(size: size, color: color);

  // ════════════════════════════════════════════
  // Outfit — body / UI text
  // ════════════════════════════════════════════

  static TextStyle display({
    double size = 48,
    Color color = AppColors.text,
    FontWeight weight = FontWeight.w900,
  }) => FzTypography.display(size: size, color: color, weight: weight);

  static TextStyle h1({Color color = AppColors.text}) =>
      FzTypography.display(size: 36, color: color, weight: FontWeight.w900);

  static TextStyle h2({Color color = AppColors.text}) =>
      FzTypography.display(size: 30, color: color, weight: FontWeight.w900);

  static TextStyle h3({Color color = AppColors.text}) =>
      FzTypography.display(size: 24, color: color, weight: FontWeight.w900);

  static const TextStyle cardTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w900,
    color: AppColors.text,
    height: 1.2,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
    height: 1.45,
  );

  static const TextStyle secondary = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.textSecondary,
    height: 1.45,
  );

  static const TextStyle label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w900,
    color: AppColors.text,
    height: 1.25,
  );

  /// Chip label — small, uppercase-ready, very bold.
  static TextStyle chipLabel({
    double size = 13,
    Color color = AppColors.text,
  }) => FzTypography.chipLabel(size: size, color: color);

  static TextStyle metric({double size = 44, Color color = AppColors.text}) =>
      FzTypography.score(size: size, weight: FontWeight.w900, color: color);

  static TextStyle status({Color? color}) =>
      FzTypography.statusLabel(size: 13, color: color ?? AppColors.text);
}
