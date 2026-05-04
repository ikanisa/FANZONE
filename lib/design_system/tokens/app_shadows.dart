import 'package:flutter/material.dart';

/// Shared shadows for elevated dark surfaces.
abstract final class AppShadows {
  static List<BoxShadow> get card => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.18),
      blurRadius: 24,
      offset: const Offset(0, 12),
    ),
  ];

  static List<BoxShadow> get elevated => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.28),
      blurRadius: 36,
      offset: const Offset(0, 18),
    ),
  ];
}
