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
import 'package:fanzone/features/home/data/catalog_gateway.dart' as _i554;
import 'package:fanzone/features/home/data/matches_gateway.dart' as _i54;
import 'package:fanzone/features/onboarding/data/onboarding_gateway.dart'
    as _i184;
import 'package:fanzone/features/onboarding/data/team_search_catalog.dart'
    as _i872;
import 'package:fanzone/features/predict/data/predict_gateway.dart' as _i521;
import 'package:fanzone/features/profile/data/engagement_gateway.dart'
    as _i508;
import 'package:fanzone/features/settings/data/preferences_gateway.dart'
    as _i576;
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
    gh.lazySingleton<_i576.PreferencesGateway>(
      () => _i576.SupabasePreferencesGateway(
        gh<_i401.CacheService>(),
        gh<_i535.SupabaseConnection>(),
      ),
    );
    gh.lazySingleton<_i554.CatalogGateway>(
      () => _i554.SupabaseCatalogGateway(gh<_i535.SupabaseConnection>()),
    );
    gh.lazySingleton<_i54.MatchesGateway>(
      () => _i54.SupabaseMatchesGateway(gh<_i535.SupabaseConnection>()),
    );
    gh.lazySingleton<_i508.EngagementGateway>(
      () => _i508.SupabaseEngagementGateway(gh<_i535.SupabaseConnection>()),
    );
    gh.lazySingleton<_i236.CommunityGateway>(
      () => _i236.SupabaseCommunityGateway(
        gh<_i401.CacheService>(),
        gh<_i535.SupabaseConnection>(),
      ),
    );
    gh.lazySingleton<_i521.PredictGateway>(
      () => _i521.SupabasePredictGateway(gh<_i535.SupabaseConnection>()),
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
