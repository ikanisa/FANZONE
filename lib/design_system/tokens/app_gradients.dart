import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppGradients {
  static const pool = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF27D8F2), Color(0xFF0A1A3F)],
  );

  static const game = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF4D57), Color(0xFFFF7A4D)],
  );

  static const team = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF27D8F2), Color(0xFF5BE06B)],
  );

  static const order = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFD166), Color(0xFFFF7A4D)],
  );

  static const wallet = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF7A4D), Color(0xFF27D8F2)],
  );

  static const venue = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF27D8F2), Color(0xFF5BE06B)],
  );

  static const hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF27D8F2), Color(0xFF0A1A3F)],
  );

  static const fetHero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.orange, Color(0xFF15161D)],
  );

  static const liveHero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF4D57), Color(0xFF15161D)],
  );
}
