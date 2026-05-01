import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../providers/order_provider.dart';

class OrderSuccessScreen extends ConsumerWidget {
  const OrderSuccessScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                LucideIcons.checkCircle2,
                size: 80,
                color: FzColors.success,
              ),
              const SizedBox(height: 24),
              Text(
                'Order received',
                style: FzTypography.display(
                  size: 32,
                  color: isDark ? FzColors.darkText : FzColors.lightText,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your order has been sent to the venue. Payment remains pending until staff confirm it.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: FzColors.lightMuted),
              ),
              const SizedBox(height: 40),
              orderAsync.when(
                data: (order) {
                  if (order == null) return const SizedBox.shrink();
                  return FzCard(
                    child: Column(
                      children: [
                        Text(
                          'ORDER #${order.orderCode}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total'),
                            Text(
                              order.totalDisplay,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (order.paymentFetAmount > 0) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Tokens Used'),
                              Text(
                                '${order.paymentFetAmount} FET',
                                style: const TextStyle(
                                  color: FzColors.success,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
              ),
              const SizedBox(height: 60),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/bar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FzColors.accent,
                    foregroundColor: FzColors.darkBg,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'BACK TO BAR',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
