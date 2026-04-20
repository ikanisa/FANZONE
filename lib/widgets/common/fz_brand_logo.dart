import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/media/cdn_url_resolver.dart';
import '../../core/media/fz_image_cache_manager.dart';

class FzBrandLogo extends StatelessWidget {
  const FzBrandLogo({
    super.key,
    required this.width,
    required this.height,
    this.assetPath = 'assets/images/brand/logo-mark.png',
    this.preferCdn = false,
  });

  final double width;
  final double height;
  final String assetPath;
  final bool preferCdn;

  @override
  Widget build(BuildContext context) {
    final staticUrl = preferCdn
        ? CdnUrlResolver.resolveStaticAssetUrl(assetPath)
        : null;

    if (staticUrl != null) {
      return CachedNetworkImage(
        imageUrl: staticUrl,
        cacheManager: FzImageCacheManager.instance,
        width: width,
        height: height,
        fit: BoxFit.contain,
        placeholder: (_, _) => _localAsset(),
        errorWidget: (_, _, _) => _localAsset(),
      );
    }

    return _localAsset();
  }

  Widget _localAsset() {
    return Image.asset(assetPath, width: width, height: height);
  }
}
