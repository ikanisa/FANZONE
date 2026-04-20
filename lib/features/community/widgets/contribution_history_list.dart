import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../models/team_contribution_model.dart';
import '../../../theme/colors.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';

/// Scrollable list of verified supporter contributions.
class ContributionHistoryList extends StatelessWidget {
  const ContributionHistoryList({
    super.key,
    required this.contributions,
    required this.membershipTier,
  });

  final List<TeamContributionModel> contributions;
  final String membershipTier;

  @override
  Widget build(BuildContext context) {
    if (contributions.isEmpty) {
      return StateView.empty(
        title: 'No verified contributions yet',
        subtitle:
            'Your supporter payments and FET support will appear here once they are recorded.',
        icon: LucideIcons.receipt,
      );
    }

    return Column(
      children: [
        for (var i = 0; i < contributions.length; i++) ...[
          _ContributionRow(
            contribution: contributions[i],
            membershipTier: membershipTier,
          ),
          if (i < contributions.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ContributionRow extends StatelessWidget {
  const _ContributionRow({
    required this.contribution,
    required this.membershipTier,
  });

  final TeamContributionModel contribution;
  final String membershipTier;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final amountLabel = contribution.amountFet != null
        ? 'FET ${contribution.amountFet}'
        : '${contribution.currencyCode ?? 'EUR'} ${contribution.amountMoney?.toStringAsFixed(2) ?? '0.00'}';
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(contribution.createdAt);

    return FzCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  amountLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(date, style: TextStyle(fontSize: 11, color: muted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                membershipTier,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: FzColors.secondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                contribution.status.toUpperCase(),
                style: TextStyle(fontSize: 10, color: muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
