import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../providers/currency_provider.dart';
import '../../theme/colors.dart';
import '../../theme/radii.dart';

class FzReferenceHeader extends ConsumerWidget {
  const FzReferenceHeader({
    super.key,
    this.title,
    this.subtitle,
    this.showSearch = true,
    this.showNotifications = true,
    this.trailing,
  });

  final String? title;
  final String? subtitle;
  final bool showSearch;
  final bool showNotifications;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fanId = ref.watch(userFanIdProvider).valueOrNull;

    return Row(
      children: [
        Semantics(
          button: true,
          label: 'Open profile',
          child: InkWell(
            onTap: () => context.push('/profile'),
            borderRadius: FzRadii.fullRadius,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: FzColors.darkSurface2,
                shape: BoxShape.circle,
                border: Border.all(color: FzColors.darkBorder),
              ),
              child: const Icon(LucideIcons.user, size: 20),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title ?? 'Sports Elite',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle ??
                    (fanId == null || fanId.isEmpty
                        ? 'ID: verify to claim'
                        : 'ID: $fanId'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: FzColors.darkMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (showSearch)
          _HeaderIconButton(
            tooltip: 'Search',
            icon: LucideIcons.search,
            onTap: () => context.push('/search'),
          ),
        if (showNotifications)
          _HeaderIconButton(
            tooltip: 'Alerts',
            icon: LucideIcons.bell,
            onTap: () => context.push('/notifications'),
          ),
        ...?trailing == null ? null : [trailing!],
      ],
    );
  }
}

class FzBackHeader extends StatelessWidget {
  const FzBackHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onClose,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _HeaderIconButton(
          tooltip: 'Back',
          icon: LucideIcons.chevronLeft,
          onTap: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: FzColors.darkMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (onClose != null)
          _HeaderIconButton(
            tooltip: 'Close',
            icon: LucideIcons.x,
            onTap: onClose!,
          ),
      ],
    );
  }
}

class FzSectionHeader extends StatelessWidget {
  const FzSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(foregroundColor: FzColors.darkText),
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

class FzMetricTile extends StatelessWidget {
  const FzMetricTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color = FzColors.accent,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FzColors.darkSurface2,
        borderRadius: FzRadii.compactRadius,
        border: Border.all(color: FzColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 8),
          ],
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: FzColors.darkMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class FzPill extends StatelessWidget {
  const FzPill({
    super.key,
    required this.label,
    this.icon,
    this.color = FzColors.accent,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: selected ? color : FzColors.darkSurface2,
        borderRadius: FzRadii.fullRadius,
        border: Border.all(color: selected ? color : FzColors.darkBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: selected ? Colors.white : color),
            const SizedBox(width: 7),
          ],
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : FzColors.darkText,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: FzRadii.fullRadius,
      child: content,
    );
  }
}

class FzImageSurface extends StatelessWidget {
  const FzImageSurface({
    super.key,
    this.imageUrl,
    required this.icon,
    this.height = 150,
  });

  final String? imageUrl;
  final IconData icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: FzColors.darkSurface2,
        borderRadius: FzRadii.cardRadius,
        border: Border.all(color: FzColors.darkBorder),
        image: url != null && url.isNotEmpty
            ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
            : null,
      ),
      child: url == null || url.isEmpty
          ? Center(child: Icon(icon, size: 34, color: FzColors.darkMuted))
          : DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: FzRadii.cardRadius,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.52),
                  ],
                ),
              ),
            ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: FzRadii.fullRadius,
        child: Container(
          width: 42,
          height: 42,
          margin: const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(
            color: FzColors.darkSurface2,
            shape: BoxShape.circle,
            border: Border.all(color: FzColors.darkBorder),
          ),
          child: Icon(icon, size: 18, color: FzColors.darkText),
        ),
      ),
    );
  }
}
