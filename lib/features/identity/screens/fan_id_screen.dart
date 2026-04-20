import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../providers/currency_provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';

class FanIdScreen extends ConsumerWidget {
  const FanIdScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fanId = ref.watch(userFanIdProvider).valueOrNull ?? '000000';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;

    return Scaffold(
      backgroundColor: isDark ? FzColors.darkBg : FzColors.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            _IdentityHeader(
              muted: muted,
              textColor: textColor,
              onBack: () => context.go('/profile'),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                    children: [
                      Column(
                        children: [
                          Text(
                            'FAN ID SPECIFICATION',
                            textAlign: TextAlign.center,
                            style: FzTypography.display(
                              size: 32,
                              color: textColor,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your privacy-first anonymous identity.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: muted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      _FanIdCard(fanId: fanId),
                      const SizedBox(height: 28),
                      _RulesCard(textColor: textColor, muted: muted),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdentityHeader extends StatelessWidget {
  const _IdentityHeader({
    required this.muted,
    required this.textColor,
    required this.onBack,
  });

  final Color muted;
  final Color textColor;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: (isDark ? FzColors.darkSurface : FzColors.lightSurface)
            .withValues(alpha: 0.9),
        border: Border(
          bottom: BorderSide(
            color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: Icon(LucideIcons.chevronLeft, color: textColor),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Identity',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: muted,
                    letterSpacing: 1.4,
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
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _FanIdCard extends StatelessWidget {
  const _FanIdCard({required this.fanId});

  final String fanId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? FzColors.darkSurface2 : FzColors.lightSurface2,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -28,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: FzColors.primary.withValues(alpha: 0.08),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [FzColors.primary, FzColors.secondary],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Text('⚽', style: TextStyle(fontSize: 30)),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                fanId,
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'monospace',
                                  letterSpacing: 3.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            _CopyButton(fanId: fanId),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Auto-assigned on first app open',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: muted,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _IdentityBadge(
                    icon: LucideIcons.shieldCheck,
                    label: 'Anonymous',
                    background: Color(0x1498FF98),
                    border: Color(0x3398FF98),
                    color: FzColors.primary,
                  ),
                  _IdentityBadge(
                    icon: LucideIcons.eyeOff,
                    label: 'No Real Name',
                    background: Color(0x1422232A),
                    border: Color(0x33272831),
                    color: FzColors.darkMuted,
                  ),
                  _IdentityBadge(
                    icon: LucideIcons.checkCircle2,
                    label: 'Permanent',
                    background: Color(0x1422232A),
                    border: Color(0x33272831),
                    color: FzColors.darkMuted,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.fanId});

  final String fanId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: fanId));
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Fan ID copied')));
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isDark ? FzColors.darkSurface3 : FzColors.lightSurface3,
          shape: BoxShape.circle,
        ),
        child: Icon(
          LucideIcons.copy,
          size: 16,
          color: isDark ? FzColors.darkMuted : FzColors.lightMuted,
        ),
      ),
    );
  }
}

class _IdentityBadge extends StatelessWidget {
  const _IdentityBadge({
    required this.icon,
    required this.label,
    required this.background,
    required this.border,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color border;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: label == 'Anonymous'
            ? background
            : (isDark ? FzColors.darkSurface3 : FzColors.lightSurface3),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: label == 'Anonymous'
              ? border
              : (isDark ? FzColors.darkBorder : FzColors.lightBorder),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _RulesCard extends StatelessWidget {
  const _RulesCard({required this.textColor, required this.muted});

  final Color textColor;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? FzColors.darkSurface2 : FzColors.lightSurface2,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark
                  ? FzColors.darkSurface3.withValues(alpha: 0.6)
                  : FzColors.lightSurface3.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
                ),
              ),
            ),
            child: Text(
              'IDENTITY RULES',
              style: FzTypography.display(
                size: 22,
                color: textColor,
                letterSpacing: 1.1,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final useTwoColumns = constraints.maxWidth >= 540;
                final items = _fanIdRules
                    .map((rule) => _RuleItem(text: rule))
                    .toList();

                if (!useTwoColumns) {
                  return Column(
                    children: [
                      for (int index = 0; index < items.length; index++) ...[
                        items[index],
                        if (index < items.length - 1)
                          const SizedBox(height: 14),
                      ],
                    ],
                  );
                }

                final left = <Widget>[];
                final right = <Widget>[];
                for (int index = 0; index < items.length; index++) {
                  (index.isEven ? left : right).add(items[index]);
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          for (int index = 0; index < left.length; index++) ...[
                            left[index],
                            if (index < left.length - 1)
                              const SizedBox(height: 14),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        children: [
                          for (
                            int index = 0;
                            index < right.length;
                            index++
                          ) ...[
                            right[index],
                            if (index < right.length - 1)
                              const SizedBox(height: 14),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleItem extends StatelessWidget {
  const _RuleItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(
            LucideIcons.fingerprint,
            size: 14,
            color: FzColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).brightness == Brightness.dark
                  ? FzColors.darkText
                  : FzColors.lightText,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

const _fanIdRules = [
  '6-digit numeric ID — unique per device/session',
  'Stored securely as your primary identifier',
  "Displayed as '#XXX XXX' format throughout app",
  'Auto-generated avatar assigned to your ID',
  'No real name displayed anywhere in public UI',
  'No phone number visible to other users ever',
  'No WhatsApp number exposed — server-side only',
  'Leaderboards show Fan ID + avatar only',
  'Membership shows Fan ID + tier badge only',
  'MoMo contributions anonymous by Fan ID only',
  'Fan ID persists post-WA auth — same ID retained',
  'User can set a custom display nickname (post-auth)',
];
