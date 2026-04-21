import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

bool _didConfigureDependencies = false;

Future<GetIt> configureDependencies() async {
  if (_didConfigureDependencies) {
    return getIt;
  }

  _didConfigureDependencies = true;
  return getIt;
}
