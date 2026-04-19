import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/injection.dart';
import '../core/utils/extensions.dart';
import '../features/home/data/catalog_gateway.dart';
import '../features/home/data/home_dtos.dart';
import '../models/search_result_model.dart';

final searchProvider = FutureProvider.family.autoDispose<SearchResults, String>(
  (ref, rawQuery) async {
    return getIt<CatalogGateway>().search(SearchQueryDto(rawQuery.sanitisedForSearch));
  },
);
