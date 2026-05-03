import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../models/platform/notification_model.dart';
import '../../../services/notification_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fz_reference_chrome.dart';
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
  Widget build(BuildContext context) {
    _notificationController ??= ref.read(notificationServiceProvider.notifier);
    final notificationsAsync = ref.watch(notificationLogProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: FzReferenceHeader(
                title: 'Sports Elite',
                showNotifications: false,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Alerts',
                      style: FzTypography.display(
                        size: 36,
                        color: isDark ? FzColors.darkText : FzColors.lightText,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () async {
                      try {
                        await ref
                            .read(notificationServiceProvider.notifier)
                            .markAllRead();
                      } catch (_) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Could not mark all notifications as read.',
                            ),
                          ),
                        );
                      }
                    },
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
                          color: isDark
                              ? FzColors.darkBorder
                              : FzColors.lightBorder,
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.bell,
                            size: 32,
                            color: muted.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Nothing here',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                    children: [
                      _CriticalAlertCard(
                        count: notifications
                            .where((item) => item.readAt == null)
                            .length,
                      ),
                      const SizedBox(height: 16),
                      const FzSectionHeader(title: 'Recent'),
                      const SizedBox(height: 10),
                      for (final item in notifications)
                        _NotificationCard(
                          item: item,
                          isDark: isDark,
                          muted: muted,
                          iconForType: _iconForType,
                          colorForType: _colorForType,
                          timeLabel: _formatTime(item.sentAt),
                          onTap: () async {
                            if (item.readAt == null) {
                              try {
                                await ref
                                    .read(notificationServiceProvider.notifier)
                                    .markAsRead(item.id);
                              } catch (_) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Could not update notification status.',
                                    ),
                                  ),
                                );
                              }
                            }
                            if (!context.mounted) return;
                            _handleNotificationTap(context, item);
                          },
                        ),
                    ],
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
      case 'pool_update':
      case 'pool_created':
      case 'pool_reminder':
        return LucideIcons.swords;
      case 'goal_alert':
        return LucideIcons.target;
      case 'pool_settled':
      case 'pool_reward':
        return LucideIcons.trophy;
      case 'wallet_credit':
      case 'wallet_debit':
      case 'wallet':
        return LucideIcons.wallet;
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
      case 'pool_update':
      case 'pool_created':
      case 'pool_reminder':
        return FzColors.accent;
      case 'pool_settled':
      case 'pool_reward':
        return FzColors.accent3;
      case 'system':
        return FzColors.accent2;
      case 'goal_alert':
        return FzColors.accent2;
      case 'wallet_credit':
      case 'wallet_debit':
      case 'wallet':
        return FzColors.secondary;
      case 'community':
        return FzColors.secondary;
      case 'marketing':
        return FzColors.secondary;
      default:
        return FzColors.accent2;
    }
  }

  void _handleNotificationTap(BuildContext context, NotificationItem item) {
    final route = _routeForNotification(item);
    if (route != null) {
      context.go(route);
    }
  }

  String? _routeForNotification(NotificationItem item) {
    final matchId = _stringValue(item.data['match_id']);
    final teamId = _stringValue(item.data['team_id']);
    final competitionId = _stringValue(item.data['competition_id']);
    final screen = _stringValue(item.data['screen']);

    if (teamId != null || competitionId != null) return '/pools';
    if (matchId != null) return '/match/$matchId';

    if (screen != null) {
      if (screen == '/profile') {
        switch (item.type) {
          case 'wallet':
          case 'wallet_credit':
          case 'wallet_debit':
            return '/wallet';
          default:
            return '/pools';
        }
      }
      if (screen.startsWith('/')) return screen;
    }

    switch (item.type) {
      case 'pool_update':
      case 'pool_created':
      case 'pool_reminder':
      case 'pool_settled':
      case 'pool_reward':
        return '/pools';
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

class _CriticalAlertCard extends StatelessWidget {
  const _CriticalAlertCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final hasUnread = count > 0;
    return FzCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      color: hasUnread
          ? FzColors.accent.withValues(alpha: 0.12)
          : FzColors.darkSurface,
      borderColor: hasUnread
          ? FzColors.accent.withValues(alpha: 0.42)
          : FzColors.darkBorder,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: hasUnread
                  ? FzColors.accent.withValues(alpha: 0.14)
                  : FzColors.darkSurface2,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              hasUnread ? LucideIcons.zap : LucideIcons.badgeCheck,
              color: hasUnread ? FzColors.accent : FzColors.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasUnread ? '$count unread alerts' : 'All clear',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hasUnread
                      ? 'Review pool, wallet, order, and match updates.'
                      : 'No critical FANZONE alerts need action.',
                  style: const TextStyle(
                    color: FzColors.darkMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.isDark,
    required this.muted,
    required this.iconForType,
    required this.colorForType,
    required this.timeLabel,
    required this.onTap,
  });

  final NotificationItem item;
  final bool isDark;
  final Color muted;
  final IconData Function(String type) iconForType;
  final Color Function(String type) colorForType;
  final String timeLabel;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final isUnread = item.readAt == null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isUnread
                ? FzColors.accent.withValues(alpha: 0.06)
                : (isDark ? FzColors.darkSurface : FzColors.lightSurface),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isUnread
                  ? FzColors.accent.withValues(alpha: 0.4)
                  : (isDark ? FzColors.darkBorder : FzColors.lightBorder),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colorForType(item.type).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colorForType(item.type).withValues(alpha: 0.22),
                  ),
                ),
                child: Icon(
                  iconForType(item.type),
                  size: 17,
                  color: colorForType(item.type),
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: isDark
                                  ? FzColors.darkText
                                  : FzColors.lightText,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                    if (item.body.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                    ],
                  ],
                ),
              ),
              if (isUnread)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 5, left: 8),
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
  }
}
