import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../providers/currency_provider.dart';
import '../../../providers/fan_identity_provider.dart';
import '../../../services/team_community_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../common/fz_wordmark.dart';

/// Digital Membership Card share modal — show and share fan identity card.
///
/// Matches original design reference (MembershipShareModal.tsx):
/// - Premium card visualization with fan ID and tier
/// - Supported clubs count
/// - Share to socials + copy Fan ID
void showMembershipShareModal(BuildContext context, {required WidgetRef ref}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => UncontrolledProviderScope(
      container: ProviderScope.containerOf(context),
      child: const _MembershipShareSheet(),
    ),
  );
}

class _MembershipShareSheet extends ConsumerWidget {
  const _MembershipShareSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final fanId = ref.watch(userFanIdProvider).valueOrNull;
    final fanProfile = ref.watch(fanProfileProvider).valueOrNull;
    final supportedIds =
        ref.watch(supportedTeamsServiceProvider).valueOrNull ??
        const <String>{};

    final tier = _tierForLevel(fanProfile?.currentLevel ?? 0);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? FzColors.darkSurface : FzColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: muted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 20),

              // ── Digital Membership Card ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      tier.color.withValues(alpha: 0.12),
                      FzColors.primary.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: tier.color.withValues(alpha: 0.25)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        FzWordmark(
                          style: FzTypography.display(
                            size: 16,
                            letterSpacing: 2,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: tier.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            tier.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: tier.color,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      fanId != null
                          ? '#${fanId.substring(0, 3)} ${fanId.substring(3)}'
                          : '# — — —',
                      style: FzTypography.score(
                        size: 36,
                        weight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Digital Member',
                      style: TextStyle(
                        fontSize: 12,
                        color: muted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _CardMetric(
                          label: 'Clubs',
                          value: '${supportedIds.length}',
                          muted: muted,
                          textColor: textColor,
                        ),
                        Container(
                          width: 1,
                          height: 28,
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          color: muted.withValues(alpha: 0.2),
                        ),
                        _CardMetric(
                          label: 'Level',
                          value: '${fanProfile?.currentLevel ?? 0}',
                          muted: muted,
                          textColor: textColor,
                        ),
                        Container(
                          width: 1,
                          height: 28,
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          color: muted.withValues(alpha: 0.2),
                        ),
                        _CardMetric(
                          label: 'XP',
                          value: '${fanProfile?.totalXp ?? 0}',
                          muted: muted,
                          textColor: textColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Actions ──
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        unawaited(HapticFeedback.selectionClick());
                        final text = fanId != null
                            ? '🏟️ I\'m Fan #$fanId on FANZONE!\n'
                                  '${tier.name} Tier • ${supportedIds.length} clubs supported\n'
                                  'Join me! https://play.google.com/store/apps/details?id=app.fanzone.football'
                            : '🏟️ Join me on FANZONE!\nhttps://play.google.com/store/apps/details?id=app.fanzone.football';
                        await SharePlus.instance.share(ShareParams(text: text));
                      },
                      icon: const Icon(Icons.share_rounded, size: 16),
                      label: const Text('Share Card'),
                      style: FilledButton.styleFrom(
                        backgroundColor: tier.color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: fanId == null
                        ? null
                        : () async {
                            unawaited(HapticFeedback.selectionClick());
                            await Clipboard.setData(ClipboardData(text: fanId));
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Fan ID copied')),
                            );
                          },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy ID'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side: BorderSide(
                        color: isDark
                            ? FzColors.darkBorder
                            : FzColors.lightBorder,
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Close',
                  style: TextStyle(
                    fontSize: 13,
                    color: muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static _Tier _tierForLevel(int level) {
    if (level >= 20) return const _Tier('Legend', FzColors.primary);
    if (level >= 10) return const _Tier('Ultra', FzColors.blue);
    if (level >= 5) return const _Tier('Member', FzColors.teal);
    return const _Tier('Supporter', FzColors.coral);
  }
}

class _Tier {
  const _Tier(this.name, this.color);
  final String name;
  final Color color;
}

class _CardMetric extends StatelessWidget {
  const _CardMetric({
    required this.label,
    required this.value,
    required this.muted,
    required this.textColor,
  });

  final String label;
  final String value;
  final Color muted;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: muted)),
      ],
    );
  }
}
