import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';

class SupportInfoScreen extends StatelessWidget {
  const SupportInfoScreen._({
    super.key,
    required this.title,
    required this.subtitle,
    required this.sections,
  });

  const SupportInfoScreen.help({Key? key})
    : this._(
        key: key,
        title: 'Help & FAQ',
        subtitle: 'Fast answers for match day, rewards, and venue support.',
        sections: const [
          SupportInfoSection(
            title: 'Getting into FANZONE',
            body:
                'Verify your WhatsApp number, choose Home, Play, or Settings, then use each screen to reach deeper match, venue, rewards, and support flows.',
          ),
          SupportInfoSection(
            title: 'Match and venue data',
            body:
                'Live and upcoming match cards are synchronized from the active football feed and refreshed by FANZONE operations.',
          ),
          SupportInfoSection(
            title: 'Support',
            body:
                'For account or venue help, contact the FANZONE operations team from the venue where you are checked in.',
          ),
        ],
      );

  const SupportInfoScreen.privacyPolicy({Key? key})
    : this._(
        key: key,
        title: 'Privacy Policy',
        subtitle: 'How FANZONE handles account, venue, and match-day data.',
        sections: const [
          SupportInfoSection(
            title: 'Account data',
            body:
                'FANZONE uses your verified WhatsApp number to protect your account, route notifications, and keep your rewards activity tied to you.',
          ),
          SupportInfoSection(
            title: 'Venue activity',
            body:
                'Venue, order, reward, and game activity is used to run the hospitality experience and is scoped by account and venue permissions.',
          ),
          SupportInfoSection(
            title: 'Location',
            body:
                'Location is used only when you allow it for nearby venue discovery. FANZONE does not sell location data.',
          ),
          SupportInfoSection(
            title: 'Payments',
            body:
                'FANZONE does not process card, bank, MoMo, Revolut, or other payment credentials. Venue payment instructions are completed outside the app.',
          ),
          SupportInfoSection(
            title: 'Controls',
            body:
                'Notification and privacy controls remain available in Settings. Account deletion and data access requests can be made through support and require a verified session.',
          ),
        ],
      );

  const SupportInfoScreen.terms({Key? key})
    : this._(
        key: key,
        title: 'Terms of Service',
        subtitle: 'The operating terms for FANZONE hospitality experiences.',
        sections: const [
          SupportInfoSection(
            title: 'Use of the app',
            body:
                'Use FANZONE for venue discovery, match-day experiences, rewards, and entertainment features provided by participating venues.',
          ),
          SupportInfoSection(
            title: 'Rewards',
            body:
                'FET is a closed-loop loyalty point used inside FANZONE rewards experiences. It has no monetary value and cannot be redeemed for currency.',
          ),
          SupportInfoSection(
            title: 'Closed-loop rewards only',
            body:
                'Pools and games use non-cash FET reward points for hospitality challenges, leaderboards, coupons, and venue experiences. FET stays inside the FANZONE rewards ledger.',
          ),
          SupportInfoSection(
            title: 'Venue operations',
            body:
                'Orders, payments, and venue service are handled according to each participating venue policy. Food and drink payments are completed through venue-supported off-platform channels.',
          ),
        ],
      );

  final String title;
  final String subtitle;
  final List<SupportInfoSection> sections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
          children: [
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: 'Back',
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/settings');
                    }
                  },
                  icon: const Icon(LucideIcons.chevronLeft, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: FzTypography.display(size: 28, color: textColor),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: muted,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            for (final section in sections) ...[
              FzCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      section.body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: muted,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class SupportInfoSection {
  const SupportInfoSection({required this.title, required this.body});

  final String title;
  final String body;
}
