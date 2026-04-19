import '../../config/app_config.dart';

abstract final class CdnUrlResolver {
  static String resolveImageUrl(String rawUrl, {int? width}) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty || !AppConfig.hasImageCdn) {
      return trimmed;
    }

    final baseUri = Uri.parse(AppConfig.imageCdnBaseUrl);
    final query = <String, String>{
      ...baseUri.queryParameters,
      'url': trimmed,
      if (width != null && width > 0) 'w': '$width',
      if (AppConfig.staticAssetVersion.isNotEmpty)
        'v': AppConfig.staticAssetVersion,
    };

    return baseUri.replace(queryParameters: query).toString();
  }

  static String? resolveStaticAssetUrl(String assetPath) {
    if (!AppConfig.hasStaticCdn) return null;

    final sanitized = assetPath.startsWith('/')
        ? assetPath.substring(1)
        : assetPath;

    final baseUri = Uri.parse(AppConfig.staticCdnBaseUrl);
    final resolved = baseUri.resolve(sanitized);
    final query = <String, String>{
      ...resolved.queryParameters,
      if (AppConfig.staticAssetVersion.isNotEmpty)
        'v': AppConfig.staticAssetVersion,
    };

    return resolved.replace(queryParameters: query).toString();
  }
}
