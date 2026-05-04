import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fanzone/core/config/bootstrap_config.dart';
import 'package:fanzone/core/di/gateway_providers.dart';
import 'package:fanzone/features/auth/data/auth_gateway.dart';
import 'package:fanzone/features/auth/screens/whatsapp_login_screen.dart';
import 'package:fanzone/features/pools/screens/pools_screen.dart';
import 'package:fanzone/features/wallet/data/wallet_gateway.dart';
import 'package:fanzone/features/wallet/screens/wallet_screen.dart';
import 'package:fanzone/providers/auth_provider.dart';
import 'package:fanzone/providers/currency_provider.dart';
import 'package:fanzone/providers/market_preferences_provider.dart';
import 'package:fanzone/services/auth_service.dart';
import 'package:fanzone/services/wallet_service.dart';
import 'package:fanzone/theme/app_theme.dart';

import 'support/test_app.dart';
import 'support/test_fakes.dart';
import 'support/test_fixtures.dart';

void main() {
  group('feature flow integration', () {
    testWidgets('auth flow sends OTP, verifies, and redirects', (tester) async {
      final gateway = _FakeAuthGateway();
      await _pumpLoginFlow(tester, gateway);

      await tester.enterText(find.byType(TextFormField), '99112233');
      await tester.pump();
      await tester.tap(find.text('Send OTP'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(gateway.sentPhones, ['+11199112233']);
      expect(find.text('OTP'), findsOneWidget);

      final otpFields = find.byType(TextField);
      for (var index = 0; index < 6; index++) {
        await tester.enterText(otpFields.at(index), '${index + 1}');
        await tester.pump();
      }
      await tester.tap(find.text('Verify'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(gateway.verifiedCodes, [('+11199112233', '123456')]);
      expect(find.text('Wallet destination'), findsOneWidget);

      // Dispose the login widget tree so the resend cooldown timer is cleaned
      // up before the test completes.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('wallet transfer flow submits recipient and amount', (
      tester,
    ) async {
      final walletService = _RecordingWalletService(980);

      await pumpAppScreen(
        tester,
        const WalletScreen(),
        overrides: [
          walletServiceProvider.overrideWith(() => walletService),
          transactionServiceProvider.overrideWith(
            () => FakeTransactionService([sampleWalletTransaction()]),
          ),
          isAuthenticatedProvider.overrideWith((ref) => true),
          userFanIdProvider.overrideWith((ref) async => '123456'),
          userCurrencyProvider.overrideWith((ref) async => 'EUR'),
          primaryMarketRegionProvider.overrideWith((ref) => 'europe'),
          marketFocusTagsProvider.overrideWith((ref) => <String>{}),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Earned'), findsOneWidget);
      expect(find.text('Spent'), findsOneWidget);

      await tester.tap(find.text('Send').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Recipient Fan ID'), findsOneWidget);
      expect(find.text('MAX'), findsOneWidget);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '654321');
      await tester.enterText(fields.at(1), '150');
      await tester.pump();

      await tester.tap(find.text('Confirm Transfer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(walletService.transferRequests, hasLength(1));
      expect(walletService.transferRequests.single.fanId, '654321');
      expect(walletService.transferRequests.single.amount, 150);
      expect(find.text('Sent Successfully!'), findsOneWidget);
      expect(find.text('You sent 150 FET to Fan #654321'), findsOneWidget);
    });

    testWidgets('guest wallet transfer routes to the sign-in requirement', (
      tester,
    ) async {
      await pumpAppScreen(
        tester,
        const WalletScreen(),
        overrides: [
          walletServiceProvider.overrideWith(() => FakeWalletService(980)),
          transactionServiceProvider.overrideWith(
            () => FakeTransactionService([sampleWalletTransaction()]),
          ),
          isFullyAuthenticatedProvider.overrideWith((ref) => false),
          userCurrencyProvider.overrideWith((ref) async => 'EUR'),
          primaryMarketRegionProvider.overrideWith((ref) => 'europe'),
          marketFocusTagsProvider.overrideWith((ref) => <String>{}),
        ],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Send').first);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Verify'), findsOneWidget);
      expect(find.text('Unlock transfer.'), findsOneWidget);
      expect(find.text('Confirm Transfer'), findsNothing);
    });

    testWidgets('guest pool join routes to the sign-in requirement', (
      tester,
    ) async {
      const pool = PoolSummary(
        id: 'pool_1',
        title: 'Derby pool',
        status: 'open',
        scope: 'venue',
        isOfficial: true,
        totalMembers: 12,
        totalStakedFet: 120,
        entryFeeFet: 10,
        camps: [
          PoolCamp(
            id: 'camp_home',
            label: 'Test Club A',
            memberCount: 7,
            totalStakedFet: 70,
          ),
        ],
      );

      await pumpAppScreen(
        tester,
        const PoolsScreen(),
        overrides: [
          poolsProvider.overrideWith((ref) async => const [pool]),
          isFullyAuthenticatedProvider.overrideWith((ref) => false),
        ],
      );
      await tester.pumpAndSettle();

      // Tap the 'Join' CTA button in the pool card action row
      await tester.tap(find.text('Join'));
      await tester.pumpAndSettle();

      expect(find.text('Verify WhatsApp'), findsOneWidget);
      expect(find.text('Unlock pools.'), findsOneWidget);
    });
  });
}

Future<void> _pumpLoginFlow(
  WidgetTester tester,
  _FakeAuthGateway gateway,
) async {
  SharedPreferences.setMockInitialValues({});
  final sharedPreferences = await SharedPreferences.getInstance();
  tester.view
    ..physicalSize = const Size(400, 844)
    ..devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final router = GoRouter(
    initialLocation: '/login?from=%2Fwallet',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const PhoneLoginScreen(),
      ),
      GoRoute(
        path: '/wallet',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Wallet destination'))),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Home destination'))),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        authServiceProvider.overrideWith((ref) => AuthService(gateway)),
        bootstrapConfigProvider.overrideWithValue(_testBootstrapConfig),
        primaryMarketRegionProvider.overrideWith((ref) => 'europe'),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: FzTheme.dark(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
}

final _testBootstrapConfig = BootstrapConfig(
  regions: const {
    'AA': RegionInfo(
      countryCode: 'AA',
      region: 'europe',
      countryName: 'Test Country',
      flagEmoji: '🏳️',
    ),
  },
  phonePresets: const {
    'AA': PhonePresetInfo(dialCode: '+111', hint: '99XX XXXX', minDigits: 8),
  },
  currencyDisplay: const {},
  countryCurrencies: const {'AA': 'EUR'},
  featureFlags: const {},
  appConfig: const {
    'default_phone_country_code': 'AA',
    'priority_phone_country_codes': ['AA'],
  },
  launchMoments: const [],
);

User _testUser({String id = 'user_1', String? phone}) {
  return User(
    id: id,
    appMetadata: const <String, dynamic>{},
    userMetadata: const <String, dynamic>{},
    aud: 'authenticated',
    phone: phone,
    createdAt: DateTime(2026, 4, 19).toIso8601String(),
  );
}

class _FakeAuthGateway implements AuthGateway {
  final List<String> sentPhones = <String>[];
  final List<(String, String)> verifiedCodes = <(String, String)>[];
  final StreamController<AuthState> _authStates =
      StreamController<AuthState>.broadcast();

  User? _currentUser;

  @override
  bool get isInitialized => true;

  @override
  User? get currentUser => _currentUser;

  @override
  Session? get currentSession => null;

  @override
  bool get isAuthenticated => _currentUser != null;

  @override
  Stream<AuthState> get onAuthStateChange => _authStates.stream;

  @override
  Future<bool> sendOtp(String phone) async {
    sentPhones.add(phone);
    return true;
  }

  @override
  Future<void> verifyOtp(String phone, String otp) async {
    verifiedCodes.add((phone, otp));
    _currentUser = _testUser(id: 'verified_user', phone: phone);
    _authStates.add(const AuthState(AuthChangeEvent.signedIn, null));
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _authStates.add(const AuthState(AuthChangeEvent.signedOut, null));
  }

  @override
  Future<bool> isOnboardingCompletedForCurrentUser() async => false;

  @override
  bool get isAnonymousUser => false;

  @override
  Future<AuthResponse> signInAnonymously() async {
    _currentUser = _testUser(id: 'anon_user');
    _authStates.add(const AuthState(AuthChangeEvent.signedIn, null));
    return AuthResponse(session: null, user: _currentUser);
  }

  @override
  Future<String?> issueAnonymousUpgradeClaim() async => 'test-claim';

  @override
  Future<bool> refreshSession() async => false;

  @override
  Future<void> mergeAnonymousToAuthenticated(
    String anonId,
    String claimToken,
  ) async {}
}

class _RecordingWalletService extends FakeWalletService {
  _RecordingWalletService(super.balance);

  final List<WalletTransferByFanIdDto> transferRequests =
      <WalletTransferByFanIdDto>[];

  @override
  Future<void> transferByFanId(String fanId, int amount) async {
    transferRequests.add(
      WalletTransferByFanIdDto(fanId: fanId, amount: amount),
    );
  }
}
