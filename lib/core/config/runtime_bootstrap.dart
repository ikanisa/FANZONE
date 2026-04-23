import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bootstrap_config.dart';

/// Process-wide bootstrap snapshot used by static helpers and legacy code paths.
///
/// The app still has some APIs that are not provider-aware (for example
/// `AppConfig` and utility functions used by route definitions). This store
/// lets those call sites read the latest Supabase-backed bootstrap config
/// without changing the UI contract.
class RuntimeBootstrapStore extends ChangeNotifier {
  BootstrapConfig _config = BootstrapConfig.empty();

  BootstrapConfig get config => _config;

  void update(BootstrapConfig config) {
    _config = config;
    notifyListeners();
  }
}

final runtimeBootstrapStore = RuntimeBootstrapStore();

final runtimeBootstrapProvider = ChangeNotifierProvider<RuntimeBootstrapStore>((
  ref,
) {
  return runtimeBootstrapStore;
});
