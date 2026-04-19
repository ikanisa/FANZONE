import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
      if (url.toLowerCase().endsWith('.svg')) {
        return SvgPicture.network(
          url,
          fit: BoxFit.contain,
          placeholderBuilder: (_) => _fallback(fg),
        );
      }

      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.contain,
        errorWidget: (_, __, ___) => _fallback(fg),
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
