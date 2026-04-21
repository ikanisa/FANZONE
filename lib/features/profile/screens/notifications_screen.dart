import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../models/notification_model.dart';
import '../../../services/notification_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
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

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final item = notifications[index];
                      final isUnread = item.readAt == null;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GestureDetector(
                          onTap: () async {
                            if (isUnread) {
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
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isUnread
                                  ? FzColors.accent.withValues(alpha: 0.05)
                                  : (isDark
                                        ? FzColors.darkSurface
                                        : FzColors.lightSurface),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isUnread
                                    ? FzColors.accent.withValues(alpha: 0.4)
                                    : (isDark
                                          ? FzColors.darkBorder
                                          : FzColors.lightBorder),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isUnread
                                        ? FzColors.accent.withValues(alpha: 0.1)
                                        : (isDark
                                              ? FzColors.darkSurface2
                                              : FzColors.lightSurface2),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isUnread
                                          ? FzColors.accent.withValues(
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                                fontWeight: FontWeight.w700,
                                                color: isDark
                                                    ? FzColors.darkText
                                                    : FzColors.lightText,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
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
                                        const SizedBox(height: 2),
                                        Text(
                                          item.body,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: muted,
                                          ),
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
      case 'pool_received':
        return LucideIcons.swords;
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
      case 'pool_received':
      case 'pool_update':
        return FzColors.accent;
      case 'pool_settled':
        return FzColors.accent3;
      case 'system':
        return FzColors.accent2;
      case 'goal_alert':
        return FzColors.accent2;
      case 'wallet_credit':
      case 'wallet_debit':
      case 'wallet':
        return FzColors.secondary;
      case 'daily_challenge':
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
    final poolId = _stringValue(item.data['pool_id']);
    final challengeId = _stringValue(item.data['challenge_id']);
    final matchId = _stringValue(item.data['match_id']);
    final teamId = _stringValue(item.data['team_id']);
    final competitionId = _stringValue(item.data['competition_id']);
    final screen = _stringValue(item.data['screen']);

    if (poolId != null) return '/pool/$poolId';
    if (challengeId != null) return '/profile';
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
      case 'pool_received':
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
