import 'package:flutter/material.dart';

/// Shared rounded-corner tokens aligned with the FANZONE reference UI.
///
/// - 20px: compact section surfaces and interactive pills
/// - 24px: primary card and empty-state surfaces
/// - 28px: hero/profile emphasis surfaces
abstract final class FzRadii {
  static const double compact = 20;
  static const double card = 24;
  static const double hero = 28;
  static const double full = 999;

  static const BorderRadius compactRadius = BorderRadius.all(
    Radius.circular(compact),
  );
  static const BorderRadius cardRadius = BorderRadius.all(
    Radius.circular(card),
  );
  static const BorderRadius heroRadius = BorderRadius.all(
    Radius.circular(hero),
  );
  static const BorderRadius fullRadius = BorderRadius.all(
    Radius.circular(full),
  );
}
