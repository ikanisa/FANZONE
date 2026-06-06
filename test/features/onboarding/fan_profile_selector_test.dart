import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fanzone/data/team_search_database.dart';
import 'package:fanzone/features/onboarding/data/onboarding_gateway.dart';
import 'package:fanzone/features/onboarding/widgets/fan_profile_selector.dart';

void main() {
  testWidgets('local onboarding step browses Supabase teams by country code', (
    tester,
  ) async {
    final gateway = _RecordingOnboardingGateway();
    FanProfileSelection? savedSelection;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FanProfileSelector(
            gateway: gateway,
            initialTeams: const [],
            textColor: Colors.white,
            muted: Colors.grey,
            isDark: true,
            localCountryCode: 'MT',
            requireLocalTeam: true,
            requireTopEuropeanTeam: true,
            onSave: (selection) async {
              savedSelection = selection;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(gateway.lastLocalOnly, isTrue);
    expect(gateway.lastCountryCode, 'MT');
    expect(find.text('Valletta'), findsOneWidget);

    await tester.tap(find.text('SAVE FAN PROFILE'));
    await tester.pumpAndSettle();

    expect(savedSelection, isNull);
    expect(find.text('Select one local team to continue.'), findsOneWidget);

    await tester.tap(find.text('Valletta'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('fan_profile_step_topEuropean')),
      findsOneWidget,
    );
    expect(gateway.lastRegion, 'europe');
    expect(gateway.lastPopularOnly, isTrue);
    expect(find.text('Arsenal'), findsOneWidget);

    await tester.tap(find.text('Arsenal'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('fan_profile_category_national')),
    );
    await tester.pumpAndSettle();

    expect(gateway.lastNationalOnly, isTrue);
    expect(find.text('Brazil'), findsOneWidget);

    await tester.tap(find.text('Brazil'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('SAVE FAN PROFILE'));
    await tester.pumpAndSettle();

    expect(savedSelection, isNotNull);
    expect(savedSelection!.localTeam?.id, 'clubfeed_comp_mpl_valletta');
    expect(savedSelection!.topEuropeanTeamIds, {'arsenal'});
    expect(savedSelection!.nationalTeamIds, {'brazil'});
  });
}

class _RecordingOnboardingGateway implements OnboardingGateway {
  String? lastCountryCode;
  bool? lastLocalOnly;
  String? lastRegion;
  bool? lastPopularOnly;
  bool? lastNationalOnly;

  @override
  List<OnboardingTeam> get allTeams => const [];

  @override
  Future<void> addFavoriteTeam(
    OnboardingTeam team, {
    String source = 'settings',
  }) async {}

  @override
  Future<List<OnboardingTeam>> browseTeams({
    String query = '',
    String? region,
    String? countryCode,
    bool localOnly = false,
    bool popularOnly = false,
    bool nationalOnly = false,
    int limit = 20,
  }) async {
    lastCountryCode = countryCode;
    lastLocalOnly = localOnly;
    lastRegion = region;
    lastPopularOnly = popularOnly;
    lastNationalOnly = nationalOnly;

    if (nationalOnly) {
      return const [
        OnboardingTeam(
          id: 'brazil',
          name: 'Brazil',
          country: 'Brazil',
          league: 'FIFA World Cup 2026',
          countryCodeOverride: 'BR',
          shortNameOverride: 'BRA',
        ),
      ];
    }

    if (popularOnly || region == 'europe') {
      return const [
        OnboardingTeam(
          id: 'arsenal',
          name: 'Arsenal',
          country: 'England',
          league: 'Premier League',
          countryCodeOverride: 'GB',
          shortNameOverride: 'ARS',
          popularRank: 1,
        ),
      ];
    }

    return const [
      OnboardingTeam(
        id: 'clubfeed_comp_mpl_valletta',
        name: 'Valletta',
        country: 'Malta',
        league: 'Malta Premier League',
        countryCodeOverride: 'MT',
        shortNameOverride: 'VAL',
      ),
    ];
  }

  @override
  Future<void> deleteFavoriteTeam(String teamId) async {}

  @override
  Future<List<FavoriteTeamRecordDto>> getCachedFavoriteTeams() async =>
      const [];

  @override
  Future<List<FavoriteTeamRecordDto>> getUserFavoriteTeams() async => const [];

  @override
  List<OnboardingTeam> popularTeamsForRegion(String region) => const [];

  @override
  Future<OnboardingTeam?> resolveTeam(String teamId) async => null;

  @override
  Future<void> saveFanProfileTeams({
    OnboardingTeam? localTeam,
    Set<String> topEuropeanTeamIds = const <String>{},
    Set<String> nationalTeamIds = const <String>{},
    bool requireLocalTeam = false,
    bool requireTopEuropeanTeam = false,
    bool requireRemoteSync = false,
  }) async {}

  @override
  Future<void> saveOnboardingTeams({
    OnboardingTeam? localTeam,
    Set<String> popularTeamIds = const <String>{},
  }) async {}

  @override
  List<OnboardingTeam> searchPopularTeams(String query, {int limit = 10}) =>
      const [];

  @override
  List<OnboardingTeam> searchTeams(String query, {int limit = 10}) => const [];

  @override
  Future<void> syncCachedTeamsIfAuthenticated() async {}
}
