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
import 'package:fanzone/features/predict/data/prediction_hub_gateway.dart';
import 'package:fanzone/features/predict/widgets/prediction_entry_sheet.dart';
import 'package:fanzone/features/wallet/data/wallet_gateway.dart';
import 'package:fanzone/features/wallet/screens/wallet_screen.dart';
import 'package:fanzone/models/match_model.dart';
import 'package:fanzone/models/prediction_engine_output_model.dart';
import 'package:fanzone/models/team_form_feature_model.dart';
import 'package:fanzone/models/user_prediction_model.dart';
import 'package:fanzone/providers/auth_provider.dart';
import 'package:fanzone/providers/currency_provider.dart';
import 'package:fanzone/providers/market_preferences_provider.dart';
import 'package:fanzone/services/auth_service.dart';
import 'package:fanzone/services/prediction_service.dart';
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
      await tester.tap(find.text('SEND CODE VIA WHATSAPP'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(gateway.sentPhones, ['+11199112233']);
      expect(find.text('VERIFY CODE'), findsOneWidget);

      final otpFields = find.byType(TextField);
      for (var index = 0; index < 6; index++) {
        await tester.enterText(otpFields.at(index), '${index + 1}');
        await tester.pump();
      }
      await tester.tap(find.text('VERIFY CODE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(gateway.verifiedCodes, [('+11199112233', '123456')]);
      expect(find.text('Wallet destination'), findsOneWidget);

      // Dispose the login widget tree so the resend cooldown timer is cleaned
      // up before the test completes.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('prediction entry flow submits a free pick and shows success', (
      tester,
    ) async {
      final gateway = _RecordingPredictionHubGateway();
      final match = sampleMatch();
      final engine = PredictionEngineOutputModel(
        id: 'engine_1',
        matchId: match.id,
        modelVersion: 'simple_form_v1',
        homeWinScore: 0.56,
        drawScore: 0.24,
        awayWinScore: 0.20,
        over25Score: 0.61,
        bttsScore: 0.57,
        predictedHomeGoals: 2,
        predictedAwayGoals: 1,
        confidenceLabel: 'medium',
        generatedAt: DateTime(2026, 4, 19, 12),
      );

      await pumpAppScreen(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showPredictionEntrySheet(
                  context,
                  match: match,
                  engineOutput: engine,
                ),
                child: const Text('Open prediction entry'),
              ),
            ),
          ),
        ),
        overrides: [
          predictionServiceProvider.overrideWithValue(
            PredictionService(gateway),
          ),
          isFullyAuthenticatedProvider.overrideWith((ref) => true),
        ],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open prediction entry'));
      await tester.pumpAndSettle();

      expect(find.text('Your Pick'), findsOneWidget);
      expect(find.text('Test Club A vs Test Club B'), findsOneWidget);

      await tester.tap(find.text('Draw'));
      await tester.pump();
      await tester.tap(find.byType(Switch).at(0));
      await tester.tap(find.byType(Switch).at(1));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.tap(find.byIcon(Icons.add_rounded).last);
      await tester.pump();

      await tester.tap(find.text('Save prediction'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(gateway.submissions, hasLength(1));
      expect(gateway.submissions.single.matchId, match.id);
      expect(gateway.submissions.single.predictedResultCode, 'D');
      expect(gateway.submissions.single.predictedOver25, true);
      expect(gateway.submissions.single.predictedBtts, true);
      expect(gateway.submissions.single.predictedHomeGoals, 3);
      expect(gateway.submissions.single.predictedAwayGoals, 2);
      expect(find.text('Prediction saved.'), findsOneWidget);
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
      expect(
        find.text(
          'Wallet activity now covers transfers and lean prediction rewards only.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('SEND').first);
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

    testWidgets('guest prediction entry routes to the sign-in requirement', (
      tester,
    ) async {
      final match = sampleMatch();

      await pumpAppScreen(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showPredictionEntrySheet(
                  context,
                  match: match,
                  engineOutput: PredictionEngineOutputModel(
                    id: 'engine_guest',
                    matchId: match.id,
                    modelVersion: 'simple_form_v1',
                    homeWinScore: 0.48,
                    drawScore: 0.27,
                    awayWinScore: 0.25,
                    over25Score: 0.52,
                    bttsScore: 0.51,
                    predictedHomeGoals: 1,
                    predictedAwayGoals: 1,
                    confidenceLabel: 'low',
                    generatedAt: DateTime(2026, 4, 19, 12),
                  ),
                ),
                child: const Text('Open prediction entry'),
              ),
            ),
          ),
        ),
        overrides: [isFullyAuthenticatedProvider.overrideWith((ref) => false)],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open prediction entry'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save prediction'));
      await tester.tap(find.text('Save prediction'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Sign in to save your pick'), findsOneWidget);
      expect(
        find.text(
          'Create a free account to lock predictions, earn rewards, and track your record.',
        ),
        findsOneWidget,
      );
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
        darkTheme: FzTheme.dark(),
        themeMode: ThemeMode.dark,
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

class _RecordingPredictionHubGateway implements PredictionHubGateway {
  final List<PredictionSubmissionRequest> submissions =
      <PredictionSubmissionRequest>[];

  @override
  Future<PredictionEngineOutputModel?> getEngineOutput(String matchId) async =>
      null;

  @override
  Future<List<TeamFormFeatureModel>> getMatchFormFeatures(
    String matchId,
  ) async => const <TeamFormFeatureModel>[];

  @override
  Future<UserPredictionModel?> getMyPredictionForMatch(
    String userId,
    String matchId,
  ) async => null;

  @override
  Future<List<UserPredictionModel>> getMyPredictions(
    String userId, {
    int limit = 100,
  }) async => const <UserPredictionModel>[];

  @override
  Future<Map<String, MatchModel>> getMatchesByIds(
    Iterable<String> matchIds,
  ) async => const <String, MatchModel>{};

  @override
  Future<void> submitPrediction(PredictionSubmissionRequest request) async {
    submissions.add(request);
  }
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
