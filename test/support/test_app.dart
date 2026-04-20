import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fanzone/core/di/gateway_providers.dart';
import 'package:fanzone/theme/app_theme.dart';

Future<void> pumpAppScreen(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
  Size surfaceSize = const Size(390, 844),
  bool reduceMotion = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  final sharedPreferences = await SharedPreferences.getInstance();
  tester.view
    ..physicalSize = surfaceSize
    ..devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        ...overrides,
      ],
      child: MediaQuery(
        data: MediaQueryData(
          size: surfaceSize,
          devicePixelRatio: 1,
          textScaler: TextScaler.noScaling,
          disableAnimations: reduceMotion,
          accessibleNavigation: reduceMotion,
        ),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: FzTheme.dark(),
          darkTheme: FzTheme.dark(),
          themeMode: ThemeMode.dark,
          home: child,
        ),
      ),
    ),
  );
  await tester.pump();
}
