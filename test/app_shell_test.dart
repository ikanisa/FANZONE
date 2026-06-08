import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fanzone/design_system/design_system.dart';
import 'package:fanzone/theme/app_theme.dart';
import 'package:fanzone/widgets/navigation/app_shell.dart';

const _items = [
  NavItem(
    label: 'Home',
    icon: AppIconName.home,
    route: '/home',
    keyName: 'home',
    branchIndex: 0,
  ),
  NavItem(
    label: 'Play',
    icon: AppIconName.play,
    route: '/pools',
    keyName: 'play',
    branchIndex: 1,
  ),
  NavItem(
    label: 'Settings',
    icon: AppIconName.settings,
    route: '/settings',
    keyName: 'settings',
    branchIndex: 2,
  ),
];

void main() {
  testWidgets('uses bottom navigation on compact widths', (tester) async {
    final selected = <String>[];

    await _pumpShell(
      tester,
      size: const Size(390, 844),
      currentIndex: 0,
      onSelect: (item, _) => selected.add(item.route),
    );

    expect(find.byKey(const ValueKey('bottom_nav_home')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('adaptive_navigation_rail')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('bottom_nav_play')));
    await tester.pumpAndSettle();

    expect(selected, ['/pools']);
  });

  testWidgets('uses compact navigation rail on medium widths', (tester) async {
    final selected = <String>[];

    await _pumpShell(
      tester,
      size: const Size(700, 900),
      currentIndex: 1,
      onSelect: (item, _) => selected.add(item.route),
    );

    expect(find.byKey(const ValueKey('bottom_nav_home')), findsNothing);
    expect(
      find.byKey(const ValueKey('adaptive_navigation_rail')),
      findsOneWidget,
    );

    final rail = tester.widget<NavigationRail>(
      find.byKey(const ValueKey('adaptive_navigation_rail')),
    );
    expect(rail.extended, isFalse);

    rail.onDestinationSelected!(2);
    await tester.pumpAndSettle();

    expect(selected, ['/settings']);
  });

  testWidgets('extends navigation rail on expanded widths', (tester) async {
    await _pumpShell(
      tester,
      size: const Size(1024, 900),
      currentIndex: 2,
      onSelect: (_, _) {},
    );

    final rail = tester.widget<NavigationRail>(
      find.byKey(const ValueKey('adaptive_navigation_rail')),
    );
    expect(rail.extended, isTrue);
  });

  testWidgets('navigation rail follows light theme surfaces', (tester) async {
    await _pumpShell(
      tester,
      size: const Size(700, 900),
      currentIndex: 0,
      theme: FzTheme.light(),
      onSelect: (_, _) {},
    );

    final rail = tester.widget<NavigationRail>(
      find.byKey(const ValueKey('adaptive_navigation_rail')),
    );
    expect(rail.backgroundColor, FzTheme.light().cardTheme.color);
  });
}

Future<void> _pumpShell(
  WidgetTester tester, {
  required Size size,
  required int currentIndex,
  required void Function(NavItem item, bool isSelected) onSelect,
  ThemeData? theme,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme ?? FzTheme.dark(),
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          devicePixelRatio: 1,
          disableAnimations: true,
          accessibleNavigation: true,
        ),
        child: AppAdaptiveNavigationScaffold(
          currentIndex: currentIndex,
          items: _items,
          onSelect: onSelect,
          showOfflineBanner: false,
          showLiveOrderPill: false,
          body: const ColoredBox(
            key: ValueKey('adaptive_shell_body'),
            color: Colors.black,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
