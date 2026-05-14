import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fanzone/shells/web_mobile_shell.dart';

void main() {
  testWidgets('constrains a desktop web viewport to phone width', (
    tester,
  ) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    tester.view
      ..physicalSize = const Size(1200, 900)
      ..devicePixelRatio = 1;

    Size? mediaSize;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: WebMobileShell(
          child: Builder(
            builder: (context) {
              mediaSize = MediaQuery.sizeOf(context);
              return const ColoredBox(
                key: ValueKey('mobile-shell-probe'),
                color: Colors.red,
              );
            },
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('mobile-shell-probe'))),
      const Size(WebMobileShell.maxMobileWidth, 900),
    );
    expect(mediaSize, const Size(WebMobileShell.maxMobileWidth, 900));
  });

  testWidgets('uses the full viewport on narrow mobile web screens', (
    tester,
  ) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;

    Size? mediaSize;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: WebMobileShell(
          child: Builder(
            builder: (context) {
              mediaSize = MediaQuery.sizeOf(context);
              return const ColoredBox(
                key: ValueKey('mobile-shell-probe'),
                color: Colors.red,
              );
            },
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('mobile-shell-probe'))),
      const Size(390, 844),
    );
    expect(mediaSize, const Size(390, 844));
  });
}
