import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../providers/currency_provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';

/// Fan ID specification screen — privacy-first anonymous identity.
///
/// Matches the original design reference (FanIdScreen.tsx):
/// - Large mono Fan ID display with copy button
/// - Privacy badges (Anonymous, No Real Name, Permanent)
/// - 12-item identity rules list
class FanIdScreen extends ConsumerWidget {
  const FanIdScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fanId = ref.watch(userFanIdProvider).valueOrNull;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: 68,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'IDENTITY',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: muted,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'My Fan ID',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          Text(
            'FAN ID SPECIFICATION',
            textAlign: TextAlign.center,
            style: FzTypography.display(
              size: 28,
              color: textColor,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your privacy-first anonymous identity.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 24),
          // ── ID Display Card ──
          FzCard(
            padding: EdgeInsets.zero,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    FzColors.accent.withValues(alpha: 0.08),
                    FzColors.violet.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    'YOUR FAN ID',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: muted,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    fanId != null
                        ? '#${fanId.substring(0, 3)} ${fanId.substring(3)}'
                        : '# — — —',
                    style: FzTypography.score(
                      size: 40,
                      weight: FontWeight.w700,
                      color: FzColors.accent,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ActionChip(
                        icon: Icons.copy_rounded,
                        label: 'Copy',
                        onTap: fanId == null
                            ? null
                            : () async {
                                await Clipboard.setData(
                                  ClipboardData(text: fanId),
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Fan ID copied'),
                                  ),
                                );
                              },
                      ),
                      const SizedBox(width: 10),
                      _ActionChip(
                        icon: Icons.share_rounded,
                        label: 'Share',
                        onTap: () async {
                          final text = fanId != null
                              ? 'Send FET to Fan #$fanId on FANZONE.'
                              : 'Find me on FANZONE!';
                          await SharePlus.instance.share(
                            ShareParams(text: text),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Privacy Badges ──
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PrivacyBadge(
                icon: LucideIcons.shield,
                label: 'Anonymous',
                color: FzColors.accent,
              ),
              _PrivacyBadge(
                icon: LucideIcons.eyeOff,
                label: 'No Real Name',
                color: FzColors.violet,
              ),
              _PrivacyBadge(
                icon: LucideIcons.lock,
                label: 'Permanent',
                color: FzColors.amber,
              ),
            ],
          ),

          const SizedBox(height: 28),

          // ── Identity Rules ──
          Text(
            'IDENTITY RULES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: muted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          FzCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: _rules
                  .asMap()
                  .entries
                  .map(
                    (entry) => _RuleRow(
                      index: entry.key + 1,
                      text: entry.value,
                      muted: muted,
                      textColor: textColor,
                      isLast: entry.key == _rules.length - 1,
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

const _rules = [
  '6-digit numeric ID unique per supporter account.',
  'Stored securely as your primary FANZONE identifier.',
  'Displayed as #XXX XXX format throughout the app.',
  'No real name displayed anywhere in public UI.',
  'No phone number visible to other users ever.',
  'Club registries show Fan ID only, never personal details.',
  'Leaderboards show Fan ID plus avatar only.',
  'Membership surfaces show Fan ID with supporter tier only.',
  'FET transfers resolve by Fan ID, not phone numbers.',
  'Support and contribution records stay anonymous by Fan ID.',
  'Fan ID persists after authentication and device changes.',
  'Optional display nicknames can layer on top later.',
];

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: isDark ? FzColors.darkText : FzColors.lightText,
        side: BorderSide(
          color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _PrivacyBadge extends StatelessWidget {
  const _PrivacyBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
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
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.index,
    required this.text,
    required this.muted,
    required this.textColor,
    required this.isLast,
  });

  final int index;
  final String text;
  final Color muted;
  final Color textColor;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: FzColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: FzColors.accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(fontSize: 12, color: textColor, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: muted.withValues(alpha: 0.15)),
      ],
    );
  }
}
