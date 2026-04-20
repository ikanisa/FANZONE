import 'package:flutter/services.dart' show rootBundle;
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/onboarding/data/team_search_catalog.dart';

@module
abstract class InjectionModule {
  @preResolve
  Future<SharedPreferences> get sharedPreferences async {
    return SharedPreferences.getInstance();
  }

  @preResolve
  Future<TeamSearchCatalog> get teamSearchCatalog async {
    final raw = await rootBundle.loadString(
      'assets/data/team_search_database.json',
    );
    return TeamSearchCatalog.fromRawJson(raw);
  }
}
