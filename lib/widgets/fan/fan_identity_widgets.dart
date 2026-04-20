import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/fan_identity_model.dart';
import '../../providers/fan_identity_provider.dart';
import '../../theme/colors.dart';
import '../common/fz_card.dart';

// ─── Level Badge (compact) ─────────────────────────────────────────

/// Small level badge showing level number and title.
class FanLevelBadge extends StatelessWidget {
  const FanLevelBadge({
    super.key,
    required this.level,
    required this.title,
    required this.colorValue,
    this.compact = false,
  });

  final int level;
  final String title;
  final int colorValue;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = Color(colorValue);

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Text(
          'Lv.$level',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_levelIcon(level), size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static IconData _levelIcon(int level) {
    switch (level) {
      case 1:
        return LucideIcons.user;
      case 2:
        return LucideIcons.star;
      case 3:
        return LucideIcons.heart;
      case 4:
        return LucideIcons.shield;
      case 5:
        return LucideIcons.award;
      case 6:
        return LucideIcons.crown;
      case 7:
        return LucideIcons.trophy;
      default:
        return LucideIcons.user;
    }
  }
}

// ─── XP Progress Bar ───────────────────────────────────────────────

/// Animated XP progress bar with level labels.
class XpProgressBar extends StatelessWidget {
  const XpProgressBar({
    super.key,
    required this.currentXp,
    required this.progress,
    required this.xpToNext,
    required this.levelColor,
  });

  final int currentXp;
  final double progress;
  final int xpToNext;
  final Color levelColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$currentXp XP',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: levelColor,
              ),
            ),
            if (xpToNext > 0)
              Text(
                '$xpToNext XP to next level',
                style: TextStyle(fontSize: 10, color: muted),
              )
            else
              Text(
                'MAX LEVEL',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: levelColor,
                  letterSpacing: 0.5,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: Stack(
              children: [
                // Background
                Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? FzColors.darkSurface3
                        : FzColors.lightSurface3,
                  ),
                ),
                // Progress
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [levelColor, levelColor.withValues(alpha: 0.7)],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Badge Grid ────────────────────────────────────────────────────

/// Grid of earned badges with rarity glow.
class BadgeGrid extends StatelessWidget {
  const BadgeGrid({
    super.key,
    required this.earnedBadges,
    this.maxVisible = 6,
    this.onViewAll,
  });

  final List<EarnedBadge> earnedBadges;
  final int maxVisible;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final visible = earnedBadges.take(maxVisible).toList();
    final remaining = earnedBadges.length - maxVisible;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...visible.map((earned) => _BadgeChip(earned: earned)),
        if (remaining > 0)
          GestureDetector(
            onTap: onViewAll,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: FzColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '+$remaining more',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: FzColors.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.earned});

  final EarnedBadge earned;

  @override
  Widget build(BuildContext context) {
    final badge = earned.badge;
    if (badge == null) return const SizedBox.shrink();

    final rarityColor = Color(badge.rarityColorValue);

    return Tooltip(
      message: '${badge.name}: ${badge.description}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: rarityColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: rarityColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_badgeIcon(badge.iconName), size: 13, color: rarityColor),
            const SizedBox(width: 5),
            Text(
              badge.name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: rarityColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _badgeIcon(String iconName) {
    switch (iconName) {
      case 'target':
        return LucideIcons.target;
      case 'crosshair':
        return LucideIcons.crosshair;
      case 'eye':
        return LucideIcons.eye;
      case 'flame':
        return LucideIcons.flame;
      case 'waves':
        return LucideIcons.waves;
      case 'trophy':
        return LucideIcons.trophy;
      case 'fish':
        return LucideIcons.fish;
      case 'coins':
        return LucideIcons.coins;
      case 'heart':
        return LucideIcons.heart;
      case 'hand-heart':
        return LucideIcons.heartHandshake;
      case 'users':
        return LucideIcons.users;
      case 'newspaper':
        return LucideIcons.newspaper;
      case 'calendar':
        return LucideIcons.calendar;
      case 'calendar-check':
        return LucideIcons.calendarCheck;
      case 'award':
        return LucideIcons.award;
      case 'crown':
        return LucideIcons.crown;
      case 'rocket':
        return LucideIcons.rocket;
      case 'flag':
        return LucideIcons.flag;
      case 'swords':
        return LucideIcons.swords;
      case 'star':
        return LucideIcons.star;
      default:
        return LucideIcons.badge;
    }
  }
}

// ─── Fan Identity Card (Profile Header) ────────────────────────────

/// Full fan identity card for the profile screen — level + XP + badges.
class FanIdentityCard extends ConsumerWidget {
  const FanIdentityCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(fanProfileProvider);
    final badgesAsync = ref.watch(earnedBadgesProvider);
    final levelsAsync = ref.watch(fanLevelsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return profileAsync.when(
      data: (profile) {
        if (profile == null) return const SizedBox.shrink();

        final levels = levelsAsync.valueOrNull ?? [];
        final levelColor = Color(profile.level?.colorValue ?? 0xFFA8A29E);
        final progress = profile.xpProgress(levels);
        final xpToNext = profile.xpToNextLevel(levels);

        return FzCard(
          padding: const EdgeInsets.all(16),
          borderColor: levelColor.withValues(alpha: 0.3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Level badge + streak
              Row(
                children: [
                  FanLevelBadge(
                    level: profile.currentLevel,
                    title: profile.level?.title ?? 'Fan',
                    colorValue: profile.level?.colorValue ?? 0xFFA8A29E,
                  ),
                  const Spacer(),
                  // Streak
                  if (profile.streakDays > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.flame,
                          size: 14,
                          color: profile.streakDays >= 7
                              ? FzColors.secondary
                              : muted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${profile.streakDays}d streak',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: profile.streakDays >= 7
                                ? FzColors.secondary
                                : muted,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // XP Progress
              XpProgressBar(
                currentXp: profile.totalXp,
                progress: progress,
                xpToNext: xpToNext,
                levelColor: levelColor,
              ),

              // Badges
              badgesAsync.when(
                data: (badges) {
                  if (badges.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BADGES',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: muted,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        BadgeGrid(earnedBadges: badges),
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    'Badges unavailable right now.',
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => FzCard(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Fan identity is unavailable right now.',
          style: TextStyle(fontSize: 12, color: muted),
        ),
      ),
    );
  }
}
