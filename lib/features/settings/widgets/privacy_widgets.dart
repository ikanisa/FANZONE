import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../theme/colors.dart';

// ──────────────────────────────────────────────
// Header
// ──────────────────────────────────────────────

class PrivacySettingsHeader extends StatelessWidget {
  const PrivacySettingsHeader({
    super.key,
    required this.onBack,
    required this.muted,
    required this.textColor,
  });

  final VoidCallback onBack;
  final Color muted;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: (isDark ? FzColors.darkSurface : FzColors.lightSurface).withValues(alpha: 0.9),
        border: Border(bottom: BorderSide(color: isDark ? FzColors.darkBorder : FzColors.lightBorder)),
      ),
      child: Row(
        children: [
          IconButton(onPressed: onBack, icon: Icon(LucideIcons.chevronLeft, color: textColor)),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Settings', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: muted, letterSpacing: 1.4)),
                const SizedBox(height: 2),
                Text('Privacy', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Source card container
// ──────────────────────────────────────────────

class PrivacySourceCard extends StatelessWidget {
  const PrivacySourceCard({super.key, required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? FzColors.darkSurface2 : FzColors.lightSurface2,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: isDark ? FzColors.darkBorder : FzColors.lightBorder),
      ),
      child: child,
    );
  }
}

// ──────────────────────────────────────────────
// Guarantee row
// ──────────────────────────────────────────────

class GuaranteeRow extends StatelessWidget {
  const GuaranteeRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.showDivider,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: showDivider ? Border(bottom: BorderSide(color: isDark ? FzColors.darkBorder : FzColors.lightBorder)) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(description, style: TextStyle(fontSize: 12, color: muted, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Visibility control row
// ──────────────────────────────────────────────

class VisibilityControlRow extends StatelessWidget {
  const VisibilityControlRow({
    super.key,
    required this.title,
    required this.description,
    required this.value,
    required this.enabled,
    required this.showDivider,
    required this.onChanged,
  });

  final String title;
  final String description;
  final bool value;
  final bool enabled;
  final bool showDivider;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: showDivider ? Border(bottom: BorderSide(color: isDark ? FzColors.darkBorder : FzColors.lightBorder)) : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
                      if (!enabled) ...[const SizedBox(width: 8), Icon(LucideIcons.lock, size: 12, color: muted)],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(description, style: TextStyle(fontSize: 12, color: muted, height: 1.45)),
                ],
              ),
            ),
          ),
          PrivacyToggle(value: value && enabled, enabled: enabled, onTap: enabled ? () => onChanged(!value) : null),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Custom toggle
// ──────────────────────────────────────────────

class PrivacyToggle extends StatelessWidget {
  const PrivacyToggle({super.key, required this.value, required this.enabled, required this.onTap});

  final bool value;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final background = value ? FzColors.primary : _trackColor(context);
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 48, height: 24,
          decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                left: value ? 28 : 4,
                top: 4,
                child: Container(width: 16, height: 16, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _trackColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? FzColors.darkSurface3 : FzColors.lightSurface3;
  }
}
