import 'package:flutter/material.dart';

import '../../theme/radii.dart';

/// Public radius scale for app and dashboard-like surfaces.
abstract final class AppRadii {
  static const button = FzRadii.button;
  static const input = FzRadii.cardAlt;
  static const chip = FzRadii.compact;
  static const card = FzRadii.card;
  static const hero = FzRadii.hero;
  static const full = FzRadii.full;

  static const BorderRadius buttonRadius = FzRadii.buttonRadius;
  static const BorderRadius inputRadius = FzRadii.cardAltRadius;
  static const BorderRadius chipRadius = FzRadii.compactRadius;
  static const BorderRadius cardRadius = FzRadii.cardRadius;
  static const BorderRadius heroRadius = FzRadii.heroRadius;
  static const BorderRadius fullRadius = FzRadii.fullRadius;
}
