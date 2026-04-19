// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

import 'package:fanzone/core/cache/cache_service.dart' as _i401;
import 'package:fanzone/core/cache/shared_preferences_cache_service.dart'
    as _i336;
import 'package:fanzone/core/supabase/supabase_connection.dart' as _i535;
import 'package:fanzone/features/auth/data/auth_gateway.dart' as _i439;
import 'package:fanzone/features/community/data/community_gateway.dart'
    as _i236;
import 'package:fanzone/features/community/data/feed_gateway.dart' as _i738;
import 'package:fanzone/features/community/data/team_news_gateway.dart'
    as _i381;
import 'package:fanzone/features/community/data/team_support_gateway.dart'
    as _i849;
import 'package:fanzone/features/home/data/catalog_gateway.dart' as _i554;
import 'package:fanzone/features/home/data/competition_catalog_gateway.dart'
    as _i555;
import 'package:fanzone/features/home/data/event_catalog_gateway.dart' as _i329;
import 'package:fanzone/features/home/data/match_detail_gateway.dart' as _i621;
import 'package:fanzone/features/home/data/match_listing_gateway.dart' as _i731;
import 'package:fanzone/features/home/data/matches_gateway.dart' as _i54;
import 'package:fanzone/features/home/data/search_catalog_gateway.dart'
    as _i441;
import 'package:fanzone/features/home/data/team_catalog_gateway.dart' as _i756;
import 'package:fanzone/features/onboarding/data/onboarding_gateway.dart'
    as _i184;
import 'package:fanzone/features/onboarding/data/team_search_catalog.dart'
    as _i872;
import 'package:fanzone/features/predict/data/predict_gateway.dart' as _i521;
import 'package:fanzone/features/predict/data/daily_challenge_gateway.dart'
    as _i948;
import 'package:fanzone/features/predict/data/leaderboard_gateway.dart'
    as _i532;
import 'package:fanzone/features/predict/data/prediction_pool_gateway.dart'
    as _i756;
import 'package:fanzone/features/predict/data/prediction_slip_gateway.dart'
    as _i897;
import 'package:fanzone/features/profile/data/contest_gateway.dart' as _i807;
import 'package:fanzone/features/profile/data/engagement_gateway.dart' as _i508;
import 'package:fanzone/features/profile/data/fan_profile_gateway.dart'
    as _i214;
import 'package:fanzone/features/profile/data/season_leaderboard_gateway.dart'
    as _i390;
import 'package:fanzone/features/settings/data/account_settings_gateway.dart'
    as _i188;
import 'package:fanzone/features/settings/data/competition_preferences_gateway.dart'
    as _i938;
import 'package:fanzone/features/settings/data/market_preferences_gateway.dart'
    as _i576;
import 'package:fanzone/features/settings/data/notification_settings_gateway.dart'
    as _i131;
import 'package:fanzone/features/wallet/data/wallet_gateway.dart' as _i894;
import 'package:fanzone/services/auth_service.dart' as _i490;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:shared_preferences/shared_preferences.dart' as _i460;

import 'injection_module.dart' as _i988;

extension GetItInjectableX on _i174.GetIt {
  Future<_i174.GetIt> init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) async {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final injectionModule = _$InjectionModule();

    final sharedPreferences = await injectionModule.sharedPreferences;
    gh.singleton<_i460.SharedPreferences>(() => sharedPreferences);

    final teamSearchCatalog = await injectionModule.teamSearchCatalog;
    gh.singleton<_i872.TeamSearchCatalog>(() => teamSearchCatalog);

    gh.lazySingleton<_i401.CacheService>(
      () => _i336.SharedPreferencesCacheService(gh<_i460.SharedPreferences>()),
    );
    gh.lazySingleton<_i535.SupabaseConnection>(
      () => _i535.SupabaseConnectionImpl(),
    );
    gh.lazySingleton<_i439.AuthGateway>(
      () => _i439.SupabaseAuthGateway(gh<_i535.SupabaseConnection>()),
    );
    gh.lazySingleton<_i184.OnboardingGateway>(
      () => _i184.SupabaseOnboardingGateway(
        gh<_i872.TeamSearchCatalog>(),
        gh<_i401.CacheService>(),
        gh<_i535.SupabaseConnection>(),
      ),
    );
    gh.lazySingleton<_i938.CompetitionPreferencesGateway>(
      () => _i938.SupabaseCompetitionPreferencesGateway(
        gh<_i401.CacheService>(),
        gh<_i535.SupabaseConnection>(),
      ),
    );
    gh.lazySingleton<_i188.AccountSettingsGateway>(
      () => _i188.SupabaseAccountSettingsGateway(
        gh<_i401.CacheService>(),
        gh<_i535.SupabaseConnection>(),
      ),
    );
    gh.lazySingleton<_i131.NotificationSettingsGateway>(
      () => _i131.SupabaseNotificationSettingsGateway(
        gh<_i401.CacheService>(),
        gh<_i535.SupabaseConnection>(),
      ),
    );
    gh.lazySingleton<_i576.MarketPreferencesGateway>(
      () => _i576.SupabaseMarketPreferencesGateway(
        gh<_i401.CacheService>(),
        gh<_i535.SupabaseConnection>(),
      ),
    );
    gh.lazySingleton<_i555.CompetitionCatalogGateway>(
      () => _i555.SupabaseCompetitionCatalogGateway(
        gh<_i535.SupabaseConnection>(),
      ),
    );
    gh.lazySingleton<_i756.TeamCatalogGateway>(
      () => _i756.SupabaseTeamCatalogGateway(gh<_i535.SupabaseConnection>()),
    );
    gh.lazySingleton<_i329.EventCatalogGateway>(
      () => _i329.SupabaseEventCatalogGateway(gh<_i535.SupabaseConnection>()),
    );
    gh.lazySingleton<_i441.SearchCatalogGateway>(
      () => _i441.SupabaseSearchCatalogGateway(
        gh<_i555.CompetitionCatalogGateway>(),
        gh<_i756.TeamCatalogGateway>(),
      ),
    );
    gh.lazySingleton<_i554.CatalogGateway>(
      () => _i554.SupabaseCatalogGateway(
        gh<_i555.CompetitionCatalogGateway>(),
        gh<_i756.TeamCatalogGateway>(),
        gh<_i329.EventCatalogGateway>(),
        gh<_i441.SearchCatalogGateway>(),
      ),
    );
    gh.lazySingleton<_i731.MatchListingGateway>(
      () => _i731.SupabaseMatchListingGateway(gh<_i535.SupabaseConnection>()),
    );
    gh.lazySingleton<_i621.MatchDetailGateway>(
      () => _i621.SupabaseMatchDetailGateway(gh<_i535.SupabaseConnection>()),
    );
    gh.lazySingleton<_i54.MatchesGateway>(
      () => _i54.SupabaseMatchesGateway(
        gh<_i731.MatchListingGateway>(),
        gh<_i621.MatchDetailGateway>(),
      ),
    );
    gh.lazySingleton<_i807.ContestGateway>(
      () => _i807.SupabaseContestGateway(gh<_i535.SupabaseConnection>()),
    );
    gh.lazySingleton<_i390.SeasonLeaderboardGateway>(
      () => _i390.SupabaseSeasonLeaderboardGateway(
        gh<_i535.SupabaseConnection>(),
      ),
    );
    gh.lazySingleton<_i214.FanProfileGateway>(
      () => _i214.SupabaseFanProfileGateway(gh<_i535.SupabaseConnection>()),
    );
    gh.lazySingleton<_i508.EngagementGateway>(
      () => _i508.SupabaseEngagementGateway(
        gh<_i807.ContestGateway>(),
        gh<_i390.SeasonLeaderboardGateway>(),
        gh<_i214.FanProfileGateway>(),
      ),
    );
    gh.lazySingleton<_i849.TeamSupportGateway>(
      () => _i849.SupabaseTeamSupportGateway(
        gh<_i401.CacheService>(),
        gh<_i535.SupabaseConnection>(),
      ),
    );
    gh.lazySingleton<_i381.TeamNewsGateway>(
      () => _i381.SupabaseTeamNewsGateway(gh<_i535.SupabaseConnection>()),
    );
    gh.lazySingleton<_i738.FeedGateway>(
      () => _i738.SupabaseFeedGateway(
        gh<_i401.CacheService>(),
        gh<_i535.SupabaseConnection>(),
      ),
    );
    gh.lazySingleton<_i236.CommunityGateway>(
      () => _i236.SupabaseCommunityGateway(
        gh<_i849.TeamSupportGateway>(),
        gh<_i381.TeamNewsGateway>(),
        gh<_i738.FeedGateway>(),
      ),
    );
    gh.lazySingleton<_i756.PredictionPoolGateway>(
      () => _i756.SupabasePredictionPoolGateway(gh<_i535.SupabaseConnection>()),
    );
    gh.lazySingleton<_i532.LeaderboardGateway>(
      () => _i532.SupabaseLeaderboardGateway(gh<_i535.SupabaseConnection>()),
    );
    gh.lazySingleton<_i948.DailyChallengeGateway>(
      () => _i948.SupabaseDailyChallengeGateway(gh<_i535.SupabaseConnection>()),
    );
    gh.lazySingleton<_i897.PredictionSlipGateway>(
      () => _i897.SupabasePredictionSlipGateway(gh<_i535.SupabaseConnection>()),
    );
    gh.lazySingleton<_i521.PredictGateway>(
      () => _i521.SupabasePredictGateway(
        gh<_i756.PredictionPoolGateway>(),
        gh<_i532.LeaderboardGateway>(),
        gh<_i948.DailyChallengeGateway>(),
        gh<_i897.PredictionSlipGateway>(),
      ),
    );
    gh.lazySingleton<_i894.WalletGateway>(
      () => _i894.SupabaseWalletGateway(gh<_i535.SupabaseConnection>()),
    );
    gh.factory<_i490.AuthService>(
      () => _i490.AuthService(gh<_i439.AuthGateway>()),
    );

    return this;
  }
}

class _$InjectionModule extends _i988.InjectionModule {}
