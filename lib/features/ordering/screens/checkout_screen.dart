import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../theme/colors.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fet_display.dart';
import '../../../services/wallet_service.dart';
import '../providers/cart_provider.dart';
import '../providers/order_provider.dart';
import '../providers/venue_context_provider.dart';
import '../../../models/hospitality/order_model.dart';
import '../../../models/hospitality/venue_model.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  bool _useFet = false;

  Future<void> _placeOrder() async {
    final order = await placeOrderFromContext(ref, paymentMethod: _paymentMethod);
    if (order != null && mounted) {
      // 1. Show Handoff Interstitial for external methods
      if (_paymentMethod == PaymentMethod.momo || _paymentMethod == PaymentMethod.revolut) {
        await _showHandoffInterstitial(_paymentMethod);
      }

      // 2. Automatic Handoff logic based on country and method
      if (_paymentMethod == PaymentMethod.momo) {
        await _launchMoMoHandoff();
      } else if (_paymentMethod == PaymentMethod.revolut) {
        await _launchRevolutHandoff(order.totalAmount);
      }

      if (mounted) {
        context.go('/order-success/${order.id}');
      }
    }
  }

  Future<void> _showHandoffInterstitial(PaymentMethod method) async {
    final isMoMo = method == PaymentMethod.momo;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(isMoMo ? 'MoMo Payment' : 'Revolut Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isMoMo ? LucideIcons.phoneCall : LucideIcons.creditCard,
              size: 48,
              color: FzColors.accent,
            ),
            const SizedBox(height: 16),
            Text(
              isMoMo 
                ? 'We will now launch your phone dialer to complete the MoMo transfer. \n\nIMPORTANT: Once done, please show the confirmation SMS to our staff to verify your order.'
                : 'We will now open Revolut to complete your payment. \n\nIMPORTANT: Please show the transaction confirmation to our staff once complete.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: FzColors.accent),
            child: const Text('PROCEED'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchMoMoHandoff() async {
    // In Rwanda, we launch a USSD dialer string for the merchant
    // Merchant code would ideally come from the venue metadata
    const merchantCode = '123456'; 
    final uri = Uri.parse('tel:*182*8*1*$merchantCode%23');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchRevolutHandoff(double amount) async {
    // In Malta, we open the Revolut.me link
    // Revolut handle would ideally come from the venue metadata
    const handle = 'stadiumsportsbar';
    final uri = Uri.parse('https://revolut.me/$handle/${amount.toStringAsFixed(2)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final walletBalance = ref.watch(walletServiceProvider).valueOrNull ?? 0;
    final venue = ref.watch(venueContextProvider).venue;

    final isRwanda = venue?.countryCode == CountryCode.rw;
    final isMalta = venue?.countryCode == CountryCode.mt;

    // Max FET that can be applied (capped by balance and order total)
    final maxFetNeeded = (cart.subtotal * cart.fetConversionRate).ceil();
    final applicableFet = walletBalance < maxFetNeeded ? walletBalance : maxFetNeeded;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('ORDER SUMMARY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
          const SizedBox(height: 12),
          FzCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ...cart.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${item.quantity}x ${item.name}', style: const TextStyle(fontSize: 14)),
                      Text(item.lineTotalDisplay, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                )),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal'),
                    Text(cart.items.first.currencyCode == 'EUR' ? '€${cart.subtotal.toStringAsFixed(2)}' : '${cart.items.first.currencyCode} ${cart.subtotal.toStringAsFixed(0)}'),
                  ],
                ),
                if (_useFet) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Token Discount', style: TextStyle(color: FzColors.success)),
                      Text('- ${cart.items.first.currencyCode == 'EUR' ? '€${cart.discountFromFet.toStringAsFixed(2)}' : '${cart.items.first.currencyCode} ${cart.discountFromFet.toStringAsFixed(0)}'}', style: const TextStyle(color: FzColors.success)),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                    Text(cart.totalDisplay, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: FzColors.accent)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('PAY WITH TOKENS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
          const SizedBox(height: 12),
          FzCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.coins, color: FzColors.accent2),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Available Balance', style: TextStyle(fontSize: 12, color: FzColors.lightMuted)),
                          FETDisplay(amount: walletBalance, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Switch(
                      value: _useFet,
                      onChanged: applicableFet > 0 ? (val) {
                        setState(() => _useFet = val);
                        ref.read(cartProvider.notifier).applyFet(val ? applicableFet : 0);
                      } : null,
                      activeThumbColor: FzColors.accent2,
                    ),
                  ],
                ),
                if (applicableFet > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Apply $applicableFet FET to get a discount of ${cart.items.first.currencyCode == 'EUR' ? '€${(applicableFet / 100).toStringAsFixed(2)}' : '${cart.items.first.currencyCode} ${(applicableFet / 100).toStringAsFixed(0)}'}.',
                      style: const TextStyle(fontSize: 12, color: FzColors.success),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('PAYMENT METHOD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
          const SizedBox(height: 12),
          FzCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _PaymentMethodTile(
                  method: PaymentMethod.cash,
                  selected: _paymentMethod == PaymentMethod.cash,
                  onTap: () => setState(() => _paymentMethod = PaymentMethod.cash),
                ),
                if (isRwanda) ...[
                  const Divider(height: 1),
                  _PaymentMethodTile(
                    method: PaymentMethod.momo,
                    selected: _paymentMethod == PaymentMethod.momo,
                    onTap: () => setState(() => _paymentMethod = PaymentMethod.momo),
                  ),
                ],
                if (isMalta) ...[
                  const Divider(height: 1),
                  _PaymentMethodTile(
                    method: PaymentMethod.revolut,
                    selected: _paymentMethod == PaymentMethod.revolut,
                    onTap: () => setState(() => _paymentMethod = PaymentMethod.revolut),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _placeOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: FzColors.accent,
              foregroundColor: FzColors.darkBg,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(
              _paymentMethod == PaymentMethod.cash ? 'PLACE ORDER' : (_paymentMethod == PaymentMethod.momo ? 'PAY WITH MOMO' : 'PAY WITH REVOLUT'),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _paymentMethod == PaymentMethod.cash 
              ? 'Complete payment directly with venue staff.'
              : 'You will be redirected to complete payment.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: FzColors.lightMuted),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(
        method == PaymentMethod.cash ? LucideIcons.banknote : (method == PaymentMethod.momo ? LucideIcons.phoneCall : LucideIcons.creditCard),
        color: selected ? FzColors.accent : null,
      ),
      title: Text(method.label, style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      trailing: selected ? const Icon(LucideIcons.checkCircle, color: FzColors.accent, size: 20) : null,
    );
  }
}
