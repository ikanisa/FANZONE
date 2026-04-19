import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fanzone/features/auth/data/auth_gateway.dart';
import 'package:fanzone/features/auth/screens/whatsapp_login_screen.dart';
import 'package:fanzone/features/pools/widgets/pool_join_sheet.dart';
import 'package:fanzone/features/predict/data/predict_gateway.dart';
import 'package:fanzone/features/wallet/data/wallet_gateway.dart';
import 'package:fanzone/features/wallet/screens/wallet_screen.dart';
import 'package:fanzone/models/daily_challenge_model.dart';
import 'package:fanzone/models/pool.dart';
import 'package:fanzone/models/prediction_slip_model.dart';
import 'package:fanzone/providers/auth_provider.dart';
import 'package:fanzone/providers/currency_provider.dart';
import 'package:fanzone/providers/market_preferences_provider.dart';
import 'package:fanzone/providers/prediction_slip_provider.dart';
import 'package:fanzone/services/auth_service.dart';
import 'package:fanzone/services/pool_service.dart';
import 'package:fanzone/services/prediction_slip_service.dart';
import 'package:fanzone/services/team_community_service.dart';
import 'package:fanzone/services/wallet_service.dart';
import 'package:fanzone/theme/app_theme.dart';
import 'package:fanzone/widgets/predict/prediction_slip_dock.dart';

import 'support/test_app.dart';
import 'support/test_fakes.dart';
import 'support/test_fixtures.dart';

void main() {
  group('feature flow integration', () {
    testWidgets('auth flow sends OTP, verifies, and redirects', (tester) async {
      final gateway = _FakeAuthGateway();
      await _pumpLoginFlow(tester, gateway);

      await tester.enterText(find.byType(TextFormField), '+35699112233');
      await tester.tap(find.text('SEND CODE VIA WHATSAPP'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(gateway.sentPhones, ['+35699112233']);
      expect(find.text('VERIFY CODE'), findsOneWidget);

      final otpFields = find.byType(TextField);
      for (var index = 0; index < 6; index++) {
        await tester.enterText(otpFields.at(index), '${index + 1}');
        await tester.pump();
      }
      await tester.tap(find.text('VERIFY CODE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(gateway.verifiedCodes, [('+35699112233', '123456')]);
      expect(find.text('Wallet destination'), findsOneWidget);

      // Dispose the login widget tree so the resend cooldown timer is cleaned
      // up before the test completes.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('prediction submission locks slip and clears selections', (
      tester,
    ) async {
      final gateway = _RecordingPredictGateway();

      await pumpAppScreen(
        tester,
        const Scaffold(
          body: Stack(children: [SizedBox.expand(), PredictionSlipDock()]),
        ),
        overrides: [
          predictionSlipServiceProvider.overrideWith(
            (ref) => PredictionSlipService(gateway),
          ),
          myPredictionSlipsProvider.overrideWith(
            (ref) async => <PredictionSlipModel>[],
          ),
        ],
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(PredictionSlipDock)),
      );
      container
          .read(predictionSlipProvider.notifier)
          .toggleMatchResult(sampleMatch(), '1', multiplier: 1.7);
      await tester.pump();

      await tester.tap(find.text('Free Prediction Slip'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Lock Free Prediction'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(gateway.lastSlipSubmission, isNotNull);
      expect(gateway.lastSlipSubmission!.selections, hasLength(1));
      expect(container.read(predictionSlipProvider), isEmpty);
      expect(find.text('Predictions Locked! 🔒'), findsOneWidget);
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
          supportedTeamsServiceProvider.overrideWith(
            () => _FakeSupportedTeamsService(<String>{'liverpool'}),
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
      expect(find.text('Club Earnings Split'), findsOneWidget);
      expect(find.text('80% YOU'), findsOneWidget);
      expect(find.text('20% CLUB'), findsOneWidget);
      expect(find.text('Supporter'), findsOneWidget);
      expect(find.text('Member'), findsOneWidget);
      expect(find.text('Ultra'), findsOneWidget);
      expect(find.text('Legend'), findsOneWidget);

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

    testWidgets('pool join flow submits score prediction and shows success', (
      tester,
    ) async {
      final poolService = _RecordingPoolService([samplePool()]);
      final pool = samplePool();

      await pumpAppScreen(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => PoolJoinSheet(
                    pool: pool,
                    isDark: false,
                    textColor: Colors.black,
                    muted: Colors.grey,
                  ),
                ),
                child: const Text('Open pool join'),
              ),
            ),
          ),
        ),
        overrides: [
          poolServiceProvider.overrideWith(() => poolService),
          isAuthenticatedProvider.overrideWith((ref) => true),
          userCurrencyProvider.overrideWith((ref) async => 'EUR'),
        ],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open pool join'));
      await tester.pumpAndSettle();

      expect(find.text('JOIN POOL'), findsOneWidget);

      await tester.tap(find.byIcon(LucideIcons.plus).at(0));
      await tester.tap(find.byIcon(LucideIcons.plus).at(0));
      await tester.tap(find.byIcon(LucideIcons.plus).at(1));
      await tester.pump();

      await tester.tap(find.text('Confirm & Stake'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(poolService.joinRequests, [
        const (poolId: 'pool_1', homeScore: 2, awayScore: 1, stake: 150),
      ]);
      expect(find.text('Pool joined successfully.'), findsOneWidget);
    });
  });
}

Future<void> _pumpLoginFlow(
  WidgetTester tester,
  _FakeAuthGateway gateway,
) async {
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
        authServiceProvider.overrideWith((ref) => AuthService(gateway)),
        primaryMarketRegionProvider.overrideWith((ref) => 'europe'),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: FzTheme.light(),
        darkTheme: FzTheme.dark(),
        themeMode: ThemeMode.dark,
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
}

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
}

class _RecordingPredictGateway implements PredictGateway {
  PredictionSlipSubmissionDto? lastSlipSubmission;

  @override
  Future<void> createPool(PoolCreateRequestDto request) async {}

  @override
  Future<List<DailyChallengeEntry>> getDailyChallengeHistory(
    String userId,
  ) async => const [];

  @override
  Future<List<Map<String, dynamic>>> getGlobalLeaderboard() async => const [];

  @override
  Future<List<PoolEntry>> getMyEntries(String userId) async => const [];

  @override
  Future<List<PredictionSlipModel>> getMyPredictionSlips(
    String userId, {
    int limit = 30,
  }) async => const [];

  @override
  Future<DailyChallengeEntry?> getMyDailyEntry({
    required String challengeId,
    required String userId,
  }) async => null;

  @override
  Future<ScorePool?> getPoolDetail(String id) async => null;

  @override
  Future<List<ScorePool>> getPools() async => [samplePool()];

  @override
  Future<DailyChallenge?> getTodaysDailyChallenge() async => null;

  @override
  Future<int?> getUserRank(String userId) async => null;

  @override
  Future<void> joinPool(PoolJoinRequestDto request) async {}

  @override
  Future<String> submitPredictionSlip(
    PredictionSlipSubmissionDto request,
  ) async {
    lastSlipSubmission = request;
    return 'slip_test_1';
  }

  @override
  Future<void> submitDailyPrediction({
    required String challengeId,
    required int homeScore,
    required int awayScore,
  }) async {}
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

class _RecordingPoolService extends FakePoolService {
  _RecordingPoolService(super.pools);

  final List<({String poolId, int homeScore, int awayScore, int stake})>
  joinRequests = <({String poolId, int homeScore, int awayScore, int stake})>[];

  @override
  Future<void> joinPool({
    required String poolId,
    required int homeScore,
    required int awayScore,
    required int stake,
  }) async {
    joinRequests.add((
      poolId: poolId,
      homeScore: homeScore,
      awayScore: awayScore,
      stake: stake,
    ));
  }
}

class _FakeSupportedTeamsService extends SupportedTeamsService {
  _FakeSupportedTeamsService(this.teamIds);

  final Set<String> teamIds;

  @override
  FutureOr<Set<String>> build() => teamIds;
}
