import 'package:flutter/material.dart';

/// Shared rounded-corner tokens aligned with the FANZONE reference UI.
///
/// - 12px: buttons and small interactive elements
/// - 16px: secondary cards and inputs
/// - 20px: compact section surfaces and interactive pills
/// - 24px: primary card and empty-state surfaces
/// - 28px: hero/profile emphasis surfaces
/// - 32px: bottom sheet top corners
abstract final class FzRadii {
  static const double button = 12;
  static const double cardAlt = 16;
  static const double compact = 20;
  static const double card = 24;
  static const double hero = 28;
  static const double bottomSheet = 32;
  static const double full = 999;

  static const BorderRadius buttonRadius = BorderRadius.all(
    Radius.circular(button),
  );
  static const BorderRadius cardAltRadius = BorderRadius.all(
    Radius.circular(cardAlt),
  );
  static const BorderRadius compactRadius = BorderRadius.all(
    Radius.circular(compact),
  );
  static const BorderRadius cardRadius = BorderRadius.all(
    Radius.circular(card),
  );
  static const BorderRadius heroRadius = BorderRadius.all(
    Radius.circular(hero),
  );
  static const BorderRadius bottomSheetRadius = BorderRadius.only(
    topLeft: Radius.circular(bottomSheet),
    topRight: Radius.circular(bottomSheet),
  );
  static const BorderRadius fullRadius = BorderRadius.all(
    Radius.circular(full),
  );
}
