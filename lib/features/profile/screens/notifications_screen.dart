import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../models/notification_model.dart';
import '../../../services/notification_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/common/fz_glass_loader.dart';

/// Inbox screen aligned to the original reference shell and naming.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  NotificationService? _notificationController;

  @override
  void dispose() {
    final controller = _notificationController;
    if (controller != null) {
      try {
        unawaited(controller.markAllRead().catchError((_) {}));
      } catch (_) {
        // Ignore teardown-time failures when Supabase/auth is unavailable.
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _notificationController ??= ref.read(notificationServiceProvider.notifier);
    final notificationsAsync = ref.watch(notificationLogProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Inbox',
                      style: FzTypography.display(
                        size: 36,
                        color: isDark ? FzColors.darkText : FzColors.lightText,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () =>
                        ref.read(notificationServiceProvider.notifier).markAllRead(),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark
                            ? FzColors.darkSurface2
                            : FzColors.lightSurface2,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              isDark ? FzColors.darkBorder : FzColors.lightBorder,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        LucideIcons.badgeCheck,
                        size: 18,
                        color: muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: notificationsAsync.when(
                data: (notifications) {
                  if (notifications.isEmpty) {
                    return Center(
                      child: StateView.empty(
                        title: 'Nothing here',
                        subtitle: 'Pool updates and alerts will land here.',
                        icon: LucideIcons.bell,
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final item = notifications[index];
                      final isUnread = item.readAt == null;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GestureDetector(
                          onTap: () {
                            if (isUnread) {
                              ref
                                  .read(notificationServiceProvider.notifier)
                                  .markAsRead(item.id);
                            }
                            _handleNotificationTap(context, item);
                          },
                          child: FzCard(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isUnread
                                        ? _colorForType(item.type).withValues(
                                            alpha: 0.1,
                                          )
                                        : (isDark
                                              ? FzColors.darkSurface2
                                              : FzColors.lightSurface2),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isUnread
                                          ? _colorForType(item.type).withValues(
                                              alpha: 0.2,
                                            )
                                          : (isDark
                                                ? FzColors.darkBorder
                                                : FzColors.lightBorder),
                                    ),
                                  ),
                                  child: Icon(
                                    _iconForType(item.type),
                                    size: 16,
                                    color: _colorForType(item.type),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.title,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: isDark
                                                    ? FzColors.darkText
                                                    : FzColors.lightText,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            _formatTime(item.sentAt),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (item.body.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          item.body,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: muted,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (isUnread)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(
                                      top: 4,
                                      left: 8,
                                    ),
                                    decoration: const BoxDecoration(
                                      color: FzColors.accent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const FzGlassLoader(message: 'Syncing...'),
                error: (error, stackTrace) => Center(
                  child: StateView.error(
                    title: 'Could not load inbox',
                    onRetry: () => ref.invalidate(notificationLogProvider),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'goal_alert':
        return LucideIcons.target;
      case 'pool_update':
        return LucideIcons.swords;
      case 'pool_settled':
        return LucideIcons.trophy;
      case 'wallet_credit':
      case 'wallet_debit':
      case 'wallet':
        return LucideIcons.wallet;
      case 'daily_challenge':
        return LucideIcons.calendar;
      case 'community':
        return LucideIcons.users;
      case 'marketing':
        return LucideIcons.megaphone;
      case 'system':
        return LucideIcons.zap;
      default:
        return LucideIcons.bell;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'goal_alert':
        return FzColors.success;
      case 'pool_update':
      case 'pool_settled':
        return FzColors.accent;
      case 'wallet_credit':
      case 'wallet_debit':
      case 'wallet':
        return FzColors.violet;
      case 'daily_challenge':
        return FzColors.amber;
      case 'community':
        return FzColors.accentDark;
      case 'marketing':
        return FzColors.amber;
      default:
        return FzColors.accent;
    }
  }

  void _handleNotificationTap(BuildContext context, NotificationItem item) {
    final route = _routeForNotification(item);
    if (route != null) {
      context.go(route);
    }
  }

  String? _routeForNotification(NotificationItem item) {
    final poolId = _stringValue(item.data['pool_id']);
    final challengeId = _stringValue(item.data['challenge_id']);
    final matchId = _stringValue(item.data['match_id']);
    final teamId = _stringValue(item.data['team_id']);
    final newsId = _stringValue(item.data['news_id']);
    final competitionId = _stringValue(item.data['competition_id']);
    final screen = _stringValue(item.data['screen']);

    if (poolId != null) return '/pool/$poolId';
    if (challengeId != null) return '/profile';
    if (newsId != null && teamId != null) {
      return '/team/$teamId/news/$newsId';
    }
    if (teamId != null) return '/team/$teamId';
    if (competitionId != null) return '/league/$competitionId';
    if (matchId != null) return '/match/$matchId';

    if (screen != null) {
      if (screen == '/profile') {
        switch (item.type) {
          case 'daily_challenge':
            return '/profile';
          case 'wallet':
          case 'wallet_credit':
          case 'wallet_debit':
            return '/wallet';
          default:
            return '/profile';
        }
      }
      if (screen.startsWith('/')) return screen;
    }

    switch (item.type) {
      case 'pool_update':
      case 'pool_settled':
        return '/pools';
      case 'daily_challenge':
        return '/profile';
      case 'wallet':
      case 'wallet_credit':
      case 'wallet_debit':
        return '/wallet';
      default:
        return null;
    }
  }

  static String? _stringValue(Object? value) {
    if (value == null) return null;
    final stringValue = value.toString().trim();
    return stringValue.isEmpty ? null : stringValue;
  }

  static String _formatTime(DateTime sentAt) {
    final diff = DateTime.now().difference(sentAt);
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'Now';
  }
}

/// Hidden advanced notification settings surface retained for ops parity.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(notificationServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notification Settings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark ? FzColors.darkText : FzColors.lightText,
          ),
        ),
      ),
      body: prefsAsync.when(
        data: (prefs) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _PreferenceToggle(
              icon: LucideIcons.target,
              title: 'Goal Alerts',
              subtitle:
                  'Get notified when goals are scored in matches you follow',
              value: prefs.goalAlerts,
              onChanged: (v) => _update(ref, prefs.copyWith(goalAlerts: v)),
            ),
            _PreferenceToggle(
              icon: LucideIcons.swords,
              title: 'Pool Updates',
              subtitle: 'New participants, pool results, and payouts',
              value: prefs.poolUpdates,
              onChanged: (v) => _update(ref, prefs.copyWith(poolUpdates: v)),
            ),
            _PreferenceToggle(
              icon: LucideIcons.calendar,
              title: 'Daily Challenge',
              subtitle: 'Daily challenge reminder and results',
              value: prefs.dailyChallenge,
              onChanged: (v) => _update(ref, prefs.copyWith(dailyChallenge: v)),
            ),
            _PreferenceToggle(
              icon: LucideIcons.wallet,
              title: 'Wallet Activity',
              subtitle: 'FET credits, transfers, and payouts',
              value: prefs.walletActivity,
              onChanged: (v) => _update(ref, prefs.copyWith(walletActivity: v)),
            ),
            _PreferenceToggle(
              icon: LucideIcons.users,
              title: 'Community News',
              subtitle: 'Team news and community updates',
              value: prefs.communityNews,
              onChanged: (v) => _update(ref, prefs.copyWith(communityNews: v)),
            ),
            const Divider(height: 32),
            _PreferenceToggle(
              icon: LucideIcons.megaphone,
              title: 'Marketing',
              subtitle: 'Promotions, new features, and special offers',
              value: prefs.marketing,
              onChanged: (v) => _update(ref, prefs.copyWith(marketing: v)),
            ),
          ],
        ),
        loading: () => const FzGlassLoader(message: 'Syncing...'),
        error: (error, stackTrace) => Center(
          child: StateView.error(
            title: 'Could not load settings',
            onRetry: () => ref.invalidate(notificationServiceProvider),
          ),
        ),
      ),
    );
  }

  void _update(WidgetRef ref, NotificationPreferences prefs) {
    ref.read(notificationServiceProvider.notifier).updatePreferences(prefs);
  }
}

class _PreferenceToggle extends StatelessWidget {
  const _PreferenceToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: FzColors.accent),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? FzColors.darkText : FzColors.lightText,
                  ),
                ),
                Text(subtitle, style: TextStyle(fontSize: 11, color: muted)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: FzColors.accent,
            activeTrackColor: FzColors.accent.withValues(alpha: 0.35),
          ),
        ],
      ),
    );
  }
}
