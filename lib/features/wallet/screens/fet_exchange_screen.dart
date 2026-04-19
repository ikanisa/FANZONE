
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/utils/currency_utils.dart';
import '../../../providers/currency_provider.dart';
import '../../../providers/exchange_rate_provider.dart';
import '../../../services/wallet_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';

/// FET Exchange screen — global multi-currency payout visualization.
///
/// Matches original design reference (FETExchange.tsx):
/// - Current FET balance with animated counter
/// - Exchange rate display (FET → EUR/USD)
/// - Payout rules and minimum thresholds
/// - Conversion calculator
class FetExchangeScreen extends ConsumerStatefulWidget {
  const FetExchangeScreen({super.key});

  @override
  ConsumerState<FetExchangeScreen> createState() => _FetExchangeScreenState();
}

class _FetExchangeScreenState extends ConsumerState<FetExchangeScreen> {
  final _fetController = TextEditingController(text: '100');

  @override
  void dispose() {
    _fetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final balanceAsync = ref.watch(walletServiceProvider);
    final currency = ref.watch(userCurrencyProvider).valueOrNull ?? 'EUR';
    final ratesAsync = ref.watch(fetExchangeRatesProvider);
    final fetInput = int.tryParse(_fetController.text) ?? 0;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: 68,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'EXCHANGE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: muted,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'FET Payout',
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
          // ── Balance Card ──
          FzCard(
            padding: EdgeInsets.zero,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    FzColors.teal.withValues(alpha: 0.12),
                    FzColors.accent.withValues(alpha: 0.12),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    'YOUR FET BALANCE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: muted,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  balanceAsync.when(
                    data: (balance) => Text(
                      formatFET(balance, currency),
                      style: FzTypography.score(
                        size: 36,
                        weight: FontWeight.w700,
                        color: FzColors.accent,
                      ),
                    ),
                    loading: () => Text(
                      '...',
                      style: FzTypography.score(
                        size: 36,
                        weight: FontWeight.w700,
                        color: muted,
                      ),
                    ),
                    error: (_, _) => Text(
                      '—',
                      style: FzTypography.score(
                        size: 36,
                        weight: FontWeight.w700,
                        color: muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Exchange Rates ──
          Text(
            'EXCHANGE RATES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: muted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          ratesAsync.when(
            data: (rates) => Row(
              children: rates.take(2).toList().asMap().entries.map((entry) {
                final i = entry.key;
                final r = entry.value;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: i > 0 ? 10 : 0),
                    child: _RateCard(
                      currency: r.currency,
                      symbol: r.symbol,
                      rate: r.rate,
                      textColor: textColor,
                      muted: muted,
                    ),
                  ),
                );
              }).toList(),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Text('Rate data unavailable', style: TextStyle(color: muted)),
          ),

          const SizedBox(height: 24),

          // ── Conversion Calculator ──
          Text(
            'CONVERSION CALCULATOR',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: muted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          FzCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _fetController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'FET Amount',
                    prefixIcon: Icon(LucideIcons.zap, size: 18, color: muted),
                  ),
                ),
                const SizedBox(height: 16),
                Icon(LucideIcons.arrowDown, size: 20, color: muted),
                const SizedBox(height: 16),
                ratesAsync.when(
                  data: (rates) => Row(
                    children: rates.take(2).toList().asMap().entries.map((entry) {
                      final i = entry.key;
                      final r = entry.value;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(left: i > 0 ? 10 : 0),
                          child: _ConversionResult(
                            symbol: r.symbol,
                            value: (fetInput * r.rate).toStringAsFixed(2),
                            label: r.currency,
                            textColor: textColor,
                            muted: muted,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Payout Rules ──
          Text(
            'PAYOUT RULES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: muted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          const FzCard(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                _PayoutRule(
                  icon: LucideIcons.shieldCheck,
                  text: 'Minimum payout threshold: 500 FET',
                ),
                SizedBox(height: 10),
                _PayoutRule(
                  icon: LucideIcons.clock,
                  text: 'Payouts processed within 3-5 business days',
                ),
                SizedBox(height: 10),
                _PayoutRule(
                  icon: LucideIcons.banknote,
                  text: 'Malta: Bank transfer (EUR). Rwanda: MoMo (RWF)',
                ),
                SizedBox(height: 10),
                _PayoutRule(
                  icon: LucideIcons.lock,
                  text: 'Phone verification required before payout',
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Request Payout CTA ──
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Payouts not yet available. Check back soon!',
                    ),
                  ),
                );
              },
              icon: const Icon(LucideIcons.arrowUpRight, size: 16),
              label: const Text('Request Payout'),
              style: FilledButton.styleFrom(
                backgroundColor: FzColors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RateCard extends StatelessWidget {
  const _RateCard({
    required this.currency,
    required this.symbol,
    required this.rate,
    required this.textColor,
    required this.muted,
  });

  final String currency;
  final String symbol;
  final double rate;
  final Color textColor;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return FzCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '1 FET =',
            style: TextStyle(fontSize: 11, color: muted),
          ),
          const SizedBox(height: 6),
          Text(
            '$symbol${rate.toStringAsFixed(3)}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: textColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            currency,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: FzColors.accent,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversionResult extends StatelessWidget {
  const _ConversionResult({
    required this.symbol,
    required this.value,
    required this.label,
    required this.textColor,
    required this.muted,
  });

  final String symbol;
  final String value;
  final String label;
  final Color textColor;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FzColors.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: FzColors.accent.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          Text(
            '$symbol$value',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: muted)),
        ],
      ),
    );
  }
}

class _PayoutRule extends StatelessWidget {
  const _PayoutRule({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: FzColors.teal),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: textColor, height: 1.4),
          ),
        ),
      ],
    );
  }
}
