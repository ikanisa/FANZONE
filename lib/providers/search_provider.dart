import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/injection.dart';
import '../core/utils/extensions.dart';
import '../features/home/data/home_dtos.dart';
import '../features/home/data/search_catalog_gateway.dart';
import '../models/search_result_model.dart';

final searchProvider = FutureProvider.family.autoDispose<SearchResults, String>(
  (ref, rawQuery) async {
    return getIt<SearchCatalogGateway>().search(
      SearchQueryDto(rawQuery.sanitisedForSearch),
    );
  },
);
