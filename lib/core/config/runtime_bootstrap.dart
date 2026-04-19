import 'bootstrap_config.dart';

/// Process-wide bootstrap snapshot used by static helpers and legacy code paths.
///
/// The app still has some APIs that are not provider-aware (for example
/// `AppConfig` and utility functions used by route definitions). This store
/// lets those call sites read the latest Supabase-backed bootstrap config
/// without changing the UI contract.
class RuntimeBootstrapStore {
  BootstrapConfig _config = BootstrapConfig.empty();

  BootstrapConfig get config => _config;

  void update(BootstrapConfig config) {
    _config = config;
  }
}

final runtimeBootstrapStore = RuntimeBootstrapStore();
