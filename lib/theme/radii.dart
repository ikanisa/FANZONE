import 'package:flutter/material.dart';

/// Shared rounded-corner tokens aligned with the FANZONE reference UI.
///
/// - 10px: buttons and small interactive elements
/// - 14px: secondary cards and inputs
/// - 18px: compact section surfaces and interactive pills
/// - 20px: primary card and empty-state surfaces
/// - 22px: hero/profile emphasis surfaces
/// - 26px: bottom sheet top corners
abstract final class FzRadii {
  static const double button = 10;
  static const double cardAlt = 14;
  static const double compact = 18;
  static const double card = 20;
  static const double hero = 22;
  static const double bottomSheet = 26;
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
