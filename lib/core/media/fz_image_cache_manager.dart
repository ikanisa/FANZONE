import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class FzImageCacheManager extends CacheManager {
  FzImageCacheManager._() : super(_config());

  static final FzImageCacheManager instance = FzImageCacheManager._();

  static Config _config() {
    if (_isWidgetTestBinding || _isFlutterTestProcess) {
      return Config(
        'fanzone_image_cache_v1',
        stalePeriod: const Duration(days: 14),
        maxNrOfCacheObjects: 400,
        repo: JsonCacheInfoRepository(databaseName: 'fanzone_image_cache_v1'),
      );
    }

    return Config(
      'fanzone_image_cache_v1',
      stalePeriod: const Duration(days: 14),
      maxNrOfCacheObjects: 400,
    );
  }

  static bool get _isWidgetTestBinding {
    return WidgetsBinding.instance.runtimeType.toString().contains(
      'TestWidgetsFlutterBinding',
    );
  }

  static bool get _isFlutterTestProcess {
    return Platform.environment.containsKey('FLUTTER_TEST');
  }
}
