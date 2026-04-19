import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fanzone/theme/colors.dart';
import 'package:fanzone/theme/radii.dart';
import 'package:fanzone/widgets/common/fz_badge.dart';
import 'package:fanzone/widgets/common/fz_card.dart';
import 'package:fanzone/widgets/common/fz_empty_state.dart';

import 'support/test_app.dart';

void main() {
  testWidgets('FzBadge variants follow the reference palettes', (tester) async {
    await pumpAppScreen(
      tester,
      Scaffold(
        body: Column(
          children: const [
            FzBadge(
              key: ValueKey('accent-badge'),
              label: 'ACCENT',
              variant: FzBadgeVariant.accent,
            ),
            FzBadge(
              key: ValueKey('danger-badge'),
              label: 'LIVE',
              variant: FzBadgeVariant.danger,
              pulse: true,
            ),
            FzBadge(
              key: ValueKey('ghost-badge'),
              label: 'LOCKED',
              variant: FzBadgeVariant.ghost,
            ),
            FzBadge(
              key: ValueKey('accent3-badge'),
              label: 'SETTLED',
              variant: FzBadgeVariant.accent3,
            ),
          ],
        ),
      ),
    );

    final accentDecoration = _containerDecoration(
      tester,
      const ValueKey('accent-badge'),
    );
    final dangerDecoration = _containerDecoration(
      tester,
      const ValueKey('danger-badge'),
    );
    final ghostDecoration = _containerDecoration(
      tester,
      const ValueKey('ghost-badge'),
    );
    final accent3Decoration = _containerDecoration(
      tester,
      const ValueKey('accent3-badge'),
    );

    expect(accentDecoration.borderRadius, FzRadii.fullRadius);
    expect(accentDecoration.color, FzColors.accent.withValues(alpha: 0.10));
    expect(dangerDecoration.color, FzColors.danger.withValues(alpha: 0.10));
    expect(ghostDecoration.color, FzColors.darkSurface3);
    expect(accent3Decoration.color, FzColors.coral.withValues(alpha: 0.10));
  });

  testWidgets('FzCard default radius matches the primary card token', (
    tester,
  ) async {
    await pumpAppScreen(
      tester,
      const Scaffold(
        body: FzCard(
          key: ValueKey('card'),
          child: SizedBox(width: 40, height: 40),
        ),
      ),
    );

    final decoration = _containerDecoration(tester, const ValueKey('card'));
    expect(decoration.borderRadius, BorderRadius.circular(FzRadii.card));
  });

  testWidgets('FzEmptyState renders reference structure and action', (
    tester,
  ) async {
    var tapped = false;

    await pumpAppScreen(
      tester,
      Scaffold(
        body: FzEmptyState(
          key: const ValueKey('empty'),
          title: 'No Live Matches',
          description: 'Check upcoming.',
          actionLabel: 'Browse Fixtures',
          onAction: () => tapped = true,
        ),
      ),
    );

    expect(find.text('No Live Matches'), findsOneWidget);
    expect(find.text('Check upcoming.'), findsOneWidget);
    expect(find.text('Browse Fixtures'), findsOneWidget);
    expect(find.byType(CustomPaint), findsOneWidget);

    await tester.tap(find.text('Browse Fixtures'));
    await tester.pump();

    expect(tapped, isTrue);
  });
}

BoxDecoration _containerDecoration(WidgetTester tester, ValueKey<String> key) {
  final containerFinder = find.descendant(
    of: find.byKey(key),
    matching: find.byType(Container),
  );
  final container = tester.widget<Container>(containerFinder.first);
  return container.decoration! as BoxDecoration;
}
