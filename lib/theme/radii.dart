import 'package:flutter/material.dart';

/// Shared rounded-corner tokens — large rounded cards per reference.
///
/// - 14px: buttons and small interactive elements
/// - 18px: secondary cards and inputs
/// - 22px: compact section surfaces and interactive pills
/// - 28px: primary card surfaces (large rounded per reference)
/// - 32px: hero/profile emphasis surfaces
/// - 36px: bottom sheet top corners
abstract final class FzRadii {
  static const double button = 14;
  static const double cardAlt = 18;
  static const double compact = 22;
  static const double card = 28;
  static const double hero = 32;
  static const double bottomSheet = 36;
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
