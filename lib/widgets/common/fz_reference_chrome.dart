import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../providers/currency_provider.dart';
import '../../theme/colors.dart';
import '../../theme/radii.dart';
import '../../theme/typography.dart';
import 'fz_brand_logo.dart';

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
    final showBrandLogo = title == null || title!.trim().toUpperCase() == 'FZ';

    return Row(
      children: [
        Semantics(
          button: true,
          label: 'Open profile',
          child: InkWell(
            onTap: () => context.push('/profile'),
            borderRadius: FzRadii.fullRadius,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: FzColors.darkSurface2,
                shape: BoxShape.circle,
                border: Border.all(color: FzColors.darkBorder),
              ),
              child: const Icon(LucideIcons.user, size: 20),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showBrandLogo)
                const FzBrandLogo(width: 36, height: 36, preferCdn: true)
              else
                Text(
                  title!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FzTypography.sportsTitle(
                    size: 20,
                    color: FzColors.darkText,
                  ),
                ),
              const SizedBox(height: 2),
              Text(
                subtitle ??
                    (fanId == null || fanId.isEmpty
                        ? 'Verify to claim'
                        : '#$fanId'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: FzColors.darkMuted,
                  fontWeight: FontWeight.w800,
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
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FzTypography.sportsTitle(
                  size: 22,
                  color: FzColors.darkText,
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
                    fontWeight: FontWeight.w800,
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
            title.toUpperCase(),
            style: FzTypography.sportsTitle(size: 24, color: FzColors.darkText),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: FzColors.cyan,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Text(
              actionLabel!,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FzColors.darkSurface2,
        borderRadius: FzRadii.compactRadius,
        border: Border.all(color: FzColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 8),
          ],
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 20,
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
              fontSize: 12,
              fontWeight: FontWeight.w800,
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
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.18) : FzColors.darkSurface2,
        borderRadius: FzRadii.fullRadius,
        border: Border.all(color: selected ? color : FzColors.darkBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
          ] else if (icon != null) ...[
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 7),
          ],
          Text(
            label.toUpperCase(),
            style: FzTypography.chipLabel(
              size: 12,
              color: selected ? color : FzColors.darkText,
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
          width: 44,
          height: 44,
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
