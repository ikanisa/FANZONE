import 'package:get_it/get_it.dart';

import 'injection.config.dart';

final getIt = GetIt.instance;

bool _didConfigureDependencies = false;

Future<GetIt> configureDependencies() async {
  if (_didConfigureDependencies) {
    return getIt;
  }

  await getIt.init();

  _didConfigureDependencies = true;
  return getIt;
}
