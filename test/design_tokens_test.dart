import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fanzone/theme/app_theme.dart';
import 'package:fanzone/theme/colors.dart';
import 'package:fanzone/theme/radii.dart';

void main() {
  group('FzColors design tokens', () {
    // Dark theme tokens
    test('dark theme background colors are valid', () {
      expect(FzColors.darkBg, isA<Color>());
      expect(FzColors.darkSurface, isA<Color>());
      expect(FzColors.darkSurface2, isA<Color>());
      expect(FzColors.darkSurface3, isA<Color>());
      expect(FzColors.darkBorder, isA<Color>());
      expect(FzColors.darkText, isA<Color>());
      expect(FzColors.darkMuted, isA<Color>());
    });

    test('legacy light token names resolve to the dark palette', () {
      expect(FzColors.lightBg, FzColors.darkBg);
      expect(FzColors.lightSurface, FzColors.darkSurface);
      expect(FzColors.lightSurface2, FzColors.darkSurface2);
      expect(FzColors.lightSurface3, FzColors.darkSurface3);
      expect(FzColors.lightBorder, FzColors.darkBorder);
      expect(FzColors.lightText, FzColors.darkText);
      expect(FzColors.lightMuted, FzColors.darkMuted);
    });

    // Content palette
    test('brand palette exposes the official platform colors', () {
      expect(FzColors.primary, const Color(0xFF98FF98));
      expect(FzColors.onPrimary, const Color(0xFF061514));
      expect(FzColors.secondary, const Color(0xFFFF7F50));
      expect(FzColors.onSecondary, const Color(0xFF2A120A));
      expect(FzColors.coral, FzColors.secondary);
      expect(FzColors.success, FzColors.primary);
      expect(FzColors.warning, FzColors.secondary);
      expect(FzColors.danger, const Color(0xFFEF4444));
    });

    // Semantic aliases
    test('semantic aliases map correctly', () {
      expect(FzColors.live, FzColors.danger);
      expect(FzColors.warning, FzColors.coral);
      expect(FzColors.error, FzColors.danger);
    });

    // Card colors
    test('card colors are valid', () {
      expect(FzColors.yellowCard, FzColors.secondary);
      expect(FzColors.redCard, const Color(0xFFDC2626));
    });
  });

  group('FzRadii design tokens', () {
    test('shared radii stay aligned with the reference contexts', () {
      expect(FzRadii.compact, 20);
      expect(FzRadii.card, 24);
      expect(FzRadii.hero, 28);
      expect(FzRadii.full, 999);
    });
  });

  group('FzColors ColorSchemes', () {
    test('dark color scheme has correct primary', () {
      expect(FzColors.darkColorScheme.primary, FzColors.primary);
      expect(FzColors.darkColorScheme.secondary, FzColors.secondary);
      expect(FzColors.darkColorScheme.error, FzColors.error);
      expect(FzColors.darkColorScheme.surface, FzColors.darkSurface);
      expect(FzColors.darkColorScheme.onSurface, FzColors.darkText);
    });

    test('legacy light color scheme resolves to the supported dark scheme', () {
      expect(FzColors.lightColorScheme, same(FzColors.darkColorScheme));
      expect(FzColors.lightColorScheme.surface, FzColors.darkSurface);
      expect(FzColors.lightColorScheme.onSurface, FzColors.darkText);
    });

    test('dark and legacy light schemes share the same surface', () {
      expect(
        FzColors.lightColorScheme.surface,
        FzColors.darkColorScheme.surface,
      );
    });

    test('dark scheme brightness is dark', () {
      expect(FzColors.darkColorScheme.brightness, Brightness.dark);
    });

    test('legacy light scheme brightness is dark', () {
      expect(FzColors.lightColorScheme.brightness, Brightness.dark);
    });
  });

  group('Dark-only theme enforcement', () {
    test('legacy light theme builder resolves to dark ThemeData', () {
      final theme = FzTheme.light();
      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme, same(FzColors.darkColorScheme));
    });
  });

  group('WCAG contrast compliance', () {
    test('dark text on dark bg has sufficient contrast', () {
      // FzColors.darkText (Cream #FDFCF0) on darkBg (#0C0A09)
      // This is a light-on-dark combination, should have high contrast
      final textLuminance = FzColors.darkText.computeLuminance();
      final bgLuminance = FzColors.darkBg.computeLuminance();

      // WCAG contrast ratio formula
      final lighter = textLuminance > bgLuminance ? textLuminance : bgLuminance;
      final darker = textLuminance > bgLuminance ? bgLuminance : textLuminance;
      final ratio = (lighter + 0.05) / (darker + 0.05);

      // WCAG AA requires 4.5:1 for normal text
      expect(
        ratio,
        greaterThan(4.5),
        reason: 'Dark text on dark bg should meet WCAG AA',
      );
    });

    test('legacy light text aliases still preserve dark-mode contrast', () {
      final textLuminance = FzColors.lightText.computeLuminance();
      final bgLuminance = FzColors.lightBg.computeLuminance();

      final lighter = textLuminance > bgLuminance ? textLuminance : bgLuminance;
      final darker = textLuminance > bgLuminance ? bgLuminance : textLuminance;
      final ratio = (lighter + 0.05) / (darker + 0.05);

      expect(
        ratio,
        greaterThan(4.5),
        reason: 'Dark-only aliases should meet WCAG AA',
      );
    });
  });
}
