import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/onboarding/data/team_search_catalog.dart';

@module
abstract class InjectionModule {
  @preResolve
  Future<SharedPreferences> get sharedPreferences async {
    return SharedPreferences.getInstance();
  }

  /// Team search catalog — starts empty, populated from Supabase teams table.
  TeamSearchCatalog get teamSearchCatalog => TeamSearchCatalog.empty();
}
