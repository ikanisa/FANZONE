import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/media/cdn_url_resolver.dart';
import '../../core/media/fz_image_cache_manager.dart';

class TeamCrest extends StatelessWidget {
  const TeamCrest({
    super.key,
    required this.label,
    this.crestUrl,
    this.fallbackEmoji,
    this.size = 40,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1.0,
    this.textColor,
  });

  final String label;
  final String? crestUrl;
  final String? fallbackEmoji;
  final double size;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = backgroundColor ?? theme.colorScheme.surfaceContainerHighest;
    final border = borderColor ?? theme.dividerColor;
    final fg = textColor ?? theme.colorScheme.onSurfaceVariant;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: Border.all(color: border, width: borderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(size * 0.14),
        child: _buildContent(fg),
      ),
    );
  }

  Widget _buildContent(Color fg) {
    final url = crestUrl?.trim();
    if (url != null && url.isNotEmpty) {
      final resolvedUrl = CdnUrlResolver.resolveImageUrl(
        url,
        width: size.round() * 2,
      );

      if (url.toLowerCase().endsWith('.svg')) {
        return _SafeSvgCrest(
          url: resolvedUrl,
          size: size,
          fallback: _fallback(fg),
        );
      }

      return CachedNetworkImage(
        imageUrl: resolvedUrl,
        cacheManager: FzImageCacheManager.instance,
        fit: BoxFit.contain,
        errorWidget: (_, _, _) => _fallback(fg),
      );
    }

    return _fallback(fg);
  }

  Widget _fallback(Color fg) {
    if (fallbackEmoji != null && fallbackEmoji!.trim().isNotEmpty) {
      return Center(
        child: Text(fallbackEmoji!, style: TextStyle(fontSize: size * 0.42)),
      );
    }

    return Center(
      child: Text(
        _initials(label),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: size * 0.26,
          fontWeight: FontWeight.w800,
          color: fg,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  String _initials(String text) {
    final parts = text
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'FC';
    if (parts.length == 1) {
      return parts.first.characters.take(3).toString().toUpperCase();
    }

    return parts
        .take(2)
        .map((part) => part.characters.first)
        .join()
        .toUpperCase();
  }
}

/// Error-safe SVG crest renderer.
///
/// `SvgPicture.network` throws unhandled isolate exceptions when it receives
/// invalid SVG data (HTML error pages, 404 bodies, malformed XML). This widget
/// catches those errors and falls back to the initials display instead of
/// flooding the console with "[ERROR] Unhandled Exception: Bad state: Invalid
/// SVG data" messages.
class _SafeSvgCrest extends StatefulWidget {
  const _SafeSvgCrest({
    required this.url,
    required this.size,
    required this.fallback,
  });

  final String url;
  final double size;
  final Widget fallback;

  @override
  State<_SafeSvgCrest> createState() => _SafeSvgCrestState();
}

class _SafeSvgCrestState extends State<_SafeSvgCrest> {
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    if (_hasError) return widget.fallback;

    return SvgPicture.network(
      widget.url,
      fit: BoxFit.contain,
      placeholderBuilder: (_) => widget.fallback,
      errorBuilder: (context, error, stackTrace) {
        // Schedule the error state for after the current build frame.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_hasError) {
            setState(() => _hasError = true);
          }
        });
        return widget.fallback;
      },
    );
  }
}
