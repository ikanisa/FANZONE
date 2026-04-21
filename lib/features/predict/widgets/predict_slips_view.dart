part of '../screens/predict_screen.dart';

// ignore: unused_element
class _MySlipsView extends StatelessWidget {
  const _MySlipsView({required this.slipsAsync});

  final AsyncValue<List<PredictionSlipModel>> slipsAsync;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;

    return slipsAsync.when(
      data: (slips) {
        if (slips.isEmpty) {
          return StateView.empty(
            title: 'No prediction slips yet',
            subtitle:
                'Browse matches and tap odds to add selections to your slip. Predict for free — no FET required.',
            icon: LucideIcons.fileText,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: slips.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final slip = slips[index];
            return _SlipCard(
              slip: slip,
              isDark: isDark,
              muted: muted,
              textColor: textColor,
            );
          },
        );
      },
      loading: () => const FzGlassLoader(message: 'Syncing...'),
      error: (error, stack) => StateView.error(
        title: 'Could not load slips',
        subtitle: 'Pull down to try again.',
      ),
    );
  }
}

class _SlipCard extends ConsumerWidget {
  const _SlipCard({
    required this.slip,
    required this.isDark,
    required this.muted,
    required this.textColor,
  });

  final PredictionSlipModel slip;
  final bool isDark;
  final Color muted;
  final Color textColor;

  Color _statusColor() {
    switch (slip.status) {
      case 'settled_win':
        return FzColors.success;
      case 'settled_loss':
        return FzColors.danger;
      case 'voided':
        return FzColors.secondary;
      default:
        return FzColors.primary;
    }
  }

  String _statusLabel() {
    switch (slip.status) {
      case 'settled_win':
        return 'WON';
      case 'settled_loss':
        return 'LOST';
      case 'voided':
        return 'VOIDED';
      default:
        return 'SUBMITTED';
    }
  }

  FzBadgeVariant _statusVariant() {
    switch (slip.status) {
      case 'settled_win':
        return FzBadgeVariant.success;
      case 'settled_loss':
        return FzBadgeVariant.danger;
      case 'voided':
        return FzBadgeVariant.secondary;
      default:
        return FzBadgeVariant.primary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(userCurrencyProvider).valueOrNull ?? 'EUR';
    final submitted = slip.submittedAt;
    final dateLabel = submitted != null
        ? '${submitted.day}/${submitted.month}/${submitted.year}'
        : '';

    return FzCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _statusColor().withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '${slip.selectionCount}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _statusColor(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${slip.selectionCount} selection${slip.selectionCount != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FzBadge(label: _statusLabel(), variant: _statusVariant()),
                  ],
                ),
                const SizedBox(height: 4),
                Text(dateLabel, style: TextStyle(fontSize: 10, color: muted)),
              ],
            ),
          ),
          if (slip.projectedEarnFet > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatFETSigned(
                    slip.projectedEarnFet,
                    currency,
                    positive: true,
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: FzColors.success,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
