import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

    // Light theme tokens
    test('light theme background colors are valid', () {
      expect(FzColors.lightBg, isA<Color>());
      expect(FzColors.lightSurface, isA<Color>());
      expect(FzColors.lightSurface2, isA<Color>());
      expect(FzColors.lightSurface3, isA<Color>());
      expect(FzColors.lightBorder, isA<Color>());
      expect(FzColors.lightText, isA<Color>());
      expect(FzColors.lightMuted, isA<Color>());
    });

    // Content palette
    test('content palette has 7 vibrant colors', () {
      expect(FzColors.accent, const Color(0xFF22D3EE));
      expect(FzColors.blue, const Color(0xFF2563EB));
      expect(FzColors.teal, const Color(0xFF0F7B6C));
      expect(FzColors.coral, const Color(0xFFFF7F50));
      expect(FzColors.success, const Color(0xFF98FF98));
      expect(FzColors.danger, const Color(0xFFEF4444));
      expect(FzColors.accentDark, const Color(0xFF0891B2));
    });

    // Semantic aliases
    test('semantic aliases map correctly', () {
      expect(FzColors.live, FzColors.danger);
      expect(FzColors.warning, FzColors.coral);
      expect(FzColors.error, FzColors.danger);
    });

    // Backwards-compatible aliases
    test('backwards-compatible aliases map correctly', () {
      expect(FzColors.maltaRed, FzColors.danger);
      expect(FzColors.amber, FzColors.coral);
      expect(FzColors.violet, FzColors.blue);
    });

    // Card colors
    test('card colors are valid', () {
      expect(FzColors.yellowCard, const Color(0xFFFBBF24));
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
      expect(FzColors.darkColorScheme.primary, FzColors.accent);
      expect(FzColors.darkColorScheme.secondary, FzColors.teal);
      expect(FzColors.darkColorScheme.error, FzColors.error);
      expect(FzColors.darkColorScheme.surface, FzColors.darkSurface);
      expect(FzColors.darkColorScheme.onSurface, FzColors.darkText);
    });

    test('light color scheme has correct primary', () {
      expect(FzColors.lightColorScheme.primary, FzColors.accentDark);
      expect(FzColors.lightColorScheme.secondary, FzColors.teal);
      expect(FzColors.lightColorScheme.error, FzColors.error);
      expect(FzColors.lightColorScheme.surface, FzColors.lightSurface);
      expect(FzColors.lightColorScheme.onSurface, FzColors.lightText);
    });

    test('dark and light schemes have distinct surfaces', () {
      expect(
        FzColors.darkColorScheme.surface,
        isNot(FzColors.lightColorScheme.surface),
      );
    });

    test('dark scheme brightness is dark', () {
      expect(FzColors.darkColorScheme.brightness, Brightness.dark);
    });

    test('light scheme brightness is light', () {
      expect(FzColors.lightColorScheme.brightness, Brightness.light);
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

    test('light text on light bg has sufficient contrast', () {
      final textLuminance = FzColors.lightText.computeLuminance();
      final bgLuminance = FzColors.lightBg.computeLuminance();

      final lighter = textLuminance > bgLuminance ? textLuminance : bgLuminance;
      final darker = textLuminance > bgLuminance ? bgLuminance : textLuminance;
      final ratio = (lighter + 0.05) / (darker + 0.05);

      expect(
        ratio,
        greaterThan(4.5),
        reason: 'Light text on light bg should meet WCAG AA',
      );
    });
  });
}
