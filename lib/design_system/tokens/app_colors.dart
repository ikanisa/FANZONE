import 'package:flutter/material.dart';

import '../../theme/colors.dart';

/// Public design-system color aliases — sports-gaming palette.
///
/// Existing code can keep using [FzColors]; new UI should prefer [AppColors]
/// so feature screens read against product-level design-system names.
abstract final class AppColors {
  static const background = FzColors.darkBg;
  static const surface = FzColors.darkSurface;
  static const surfaceAlt = FzColors.darkSurface2;
  static const surfaceRaised = FzColors.darkSurface3;
  static const surfaceStrong = FzColors.darkSurface4;
  static const border = FzColors.darkBorder;

  static const text = FzColors.darkText;
  static const textSecondary = FzColors.darkTextSecondary;
  static const muted = FzColors.darkMuted;

  static const primary = FzColors.primary;
  static const onPrimary = FzColors.onPrimary;
  static const success = FzColors.success;
  static const warning = FzColors.warning;
  static const danger = FzColors.danger;
  static const info = FzColors.info;
  static const fet = FzColors.orange;
  static const whatsapp = FzColors.whatsapp;

  // Controlled accent colors
  static const cyan = FzColors.cyan;
  static const orange = FzColors.orange;
  static const red = FzColors.red;
  static const green = FzColors.green;
  static const gold = FzColors.gold;

  // Semantic border accents
  static const liveBorder = FzColors.activeBorderRed;
  static const actionBorder = FzColors.activeBorderCyan;
  static const fetAccent = FzColors.orange;

  static const Color transparent = Colors.transparent;
}
