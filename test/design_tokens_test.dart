import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fanzone/theme/app_theme.dart';
import 'package:fanzone/theme/colors.dart';
import 'package:fanzone/theme/radii.dart';
import 'package:fanzone/theme/typography.dart';
import 'package:fanzone/design_system/design_system.dart';

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

    test('compat light token names resolve to the dark palette', () {
      expect(FzColors.lightBg, FzColors.darkBg);
      expect(FzColors.lightSurface, FzColors.darkSurface);
      expect(FzColors.lightSurface2, FzColors.darkSurface2);
      expect(FzColors.lightSurface3, FzColors.darkSurface3);
      expect(FzColors.lightBorder, FzColors.darkBorder);
      expect(FzColors.lightText, FzColors.darkText);
      expect(FzColors.lightMuted, FzColors.darkMuted);
    });

    // Content palette
    test('brand palette exposes the canonical source-of-truth colors', () {
      expect(FzColors.accent, const Color(0xFF27D8F2));
      expect(FzColors.accent2, const Color(0xFFFF7A4D));
      expect(FzColors.accent3, const Color(0xFFFFD166));
      expect(FzColors.success, const Color(0xFF5BE06B));
      expect(FzColors.danger, const Color(0xFFFF4D57));
      expect(FzColors.teal, const Color(0xFF19D6F2));
      expect(FzColors.primary, FzColors.accent);
      expect(FzColors.secondary, FzColors.accent2);
      expect(FzColors.onPrimary, const Color(0xFF050607));
      expect(FzColors.onSecondary, const Color(0xFF050607));
    });

    // Semantic aliases
    test('semantic aliases map correctly', () {
      expect(FzColors.live, FzColors.danger);
      expect(FzColors.coral, FzColors.accent2);
      expect(FzColors.cyan, const Color(0xFF27D8F2));
      expect(FzColors.blue, FzColors.accent);
      expect(FzColors.error, FzColors.danger);
    });

    // Card colors
    test('card colors are valid', () {
      expect(FzColors.yellowCard, FzColors.warning);
      expect(FzColors.redCard, const Color(0xFFDC2626));
    });
  });

  group('FzRadii design tokens', () {
    test('shared radii stay aligned with the reference contexts', () {
      expect(FzRadii.compact, 22);
      expect(FzRadii.card, 28);
      expect(FzRadii.hero, 32);
      expect(FzRadii.full, 999);
    });
  });

  group('FzTypography design tokens', () {
    test('large text hierarchy is bold and readable', () {
      final textTheme = FzTypography.textTheme(Brightness.dark);

      expect(textTheme.displayLarge?.fontSize, greaterThanOrEqualTo(44));
      expect(
        textTheme.displayLarge?.fontWeight?.value,
        greaterThanOrEqualTo(800),
      );
      expect(textTheme.headlineLarge?.fontSize, greaterThanOrEqualTo(30));
      expect(
        textTheme.headlineLarge?.fontWeight?.value,
        greaterThanOrEqualTo(800),
      );
      expect(textTheme.titleLarge?.fontSize, greaterThanOrEqualTo(20));
      expect(textTheme.bodyMedium?.fontSize, greaterThanOrEqualTo(16));
      expect(textTheme.labelSmall?.fontSize, greaterThanOrEqualTo(12));
    });

    test('specialized score and badge labels avoid tiny text', () {
      expect(FzTypography.score().fontSize, greaterThanOrEqualTo(18));
      expect(FzTypography.scoreLarge().fontSize, greaterThanOrEqualTo(32));
      expect(
        FzTypography.sectionLabel(Brightness.dark).fontSize,
        greaterThanOrEqualTo(12),
      );
      expect(FzTypography.metaLabel().fontSize, greaterThanOrEqualTo(12));
      expect(FzTypography.statusLabel().fontSize, greaterThanOrEqualTo(13));
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

    test('compat light color scheme resolves to the supported dark scheme', () {
      expect(FzColors.lightColorScheme, same(FzColors.darkColorScheme));
      expect(FzColors.lightColorScheme.surface, FzColors.darkSurface);
      expect(FzColors.lightColorScheme.onSurface, FzColors.darkText);
    });

    test('dark and compat light schemes share the same surface', () {
      expect(
        FzColors.lightColorScheme.surface,
        FzColors.darkColorScheme.surface,
      );
    });

    test('dark scheme brightness is dark', () {
      expect(FzColors.darkColorScheme.brightness, Brightness.dark);
    });

    test('compat light scheme brightness is dark', () {
      expect(FzColors.lightColorScheme.brightness, Brightness.dark);
    });
  });

  group('Dark-only theme enforcement', () {
    test('compat light theme builder resolves to dark ThemeData', () {
      final theme = FzTheme.light();
      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme, same(FzColors.darkColorScheme));
    });
  });

  group('App design-system facade', () {
    test('public aliases resolve to canonical FANZONE tokens', () {
      expect(AppColors.background, FzColors.darkBg);
      expect(AppColors.primary, FzColors.primary);
      expect(AppColors.fet, FzColors.secondary);
      expect(AppSpacing.touch, 48);
      expect(AppRadii.card, FzRadii.card);
      expect(AppTypography.textTheme(Brightness.dark).bodyMedium?.fontSize, 16);
    });

    test('public typography scale keeps bold hierarchy', () {
      expect(AppTypography.h1().fontSize, greaterThanOrEqualTo(32));
      expect(AppTypography.h1().fontWeight?.value, greaterThanOrEqualTo(800));
      expect(AppTypography.cardTitle.fontSize, greaterThanOrEqualTo(18));
      expect(AppTypography.body.fontSize, greaterThanOrEqualTo(16));
      expect(AppTypography.label.fontWeight?.value, greaterThanOrEqualTo(700));
    });
  });

  group('WCAG contrast compliance', () {
    test('dark text on dark bg has sufficient contrast', () {
      // FzColors.darkText (#F8FAFC) on darkBg (#0B0D10)
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

    test('compat light text aliases still preserve dark-mode contrast', () {
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
