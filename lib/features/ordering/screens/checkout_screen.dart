import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/di/gateway_providers.dart';
import '../../../theme/colors.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fz_reference_chrome.dart';
import '../../../widgets/common/fz_reference_modals.dart';
import '../../../widgets/common/state_view.dart';
import '../providers/cart_provider.dart';
import '../providers/order_provider.dart';
import '../providers/venue_context_provider.dart';
import '../data/order_gateway.dart';
import '../widgets/payment_handoff_sheet.dart';
import '../../../models/hospitality/order_model.dart';
import '../../../models/hospitality/venue_model.dart';
import '../../../services/wallet_service.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  final _notesController = TextEditingController();
  final _fetSpendController = TextEditingController();
  bool _useFetSpend = false;
  bool _submitting = false;

  bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

  Future<void> _placeOrder() async {
    if (_submitting) return;
    final fetSpendAmount = _useFetSpend
        ? int.tryParse(_fetSpendController.text.trim()) ?? 0
        : 0;
    if (fetSpendAmount > 0) {
      final wallet = await ref.read(walletBalanceProvider.future);
      if (wallet.availableFet < fetSpendAmount) {
        if (mounted) {
          await showFzInsufficientFetSheet(
            context,
            requiredFet: fetSpendAmount,
            availableFet: wallet.availableFet,
            onOpenWallet: () {
              if (mounted) context.push('/wallet');
            },
          );
        }
        return;
      }
    }

    setState(() => _submitting = true);
    final order = await placeOrderFromContext(
      ref,
      paymentMethod: _paymentMethod,
    );
    if (order != null && mounted) {
      if (fetSpendAmount > 0) {
        try {
          await ref
              .read(orderGatewayProvider)
              .spendFetOnOrder(orderId: order.id, amountFet: fetSpendAmount);
          ref.invalidate(walletBalanceProvider);
          ref.invalidate(transactionServiceProvider);
        } catch (error) {
          if (mounted) {
            await showFzNoticeSheet(
              context,
              title: 'FET spend not applied',
              message: 'Order placed, but FET spend was not applied: $error',
              icon: LucideIcons.alertTriangle,
              iconColor: FzColors.warning,
              primaryLabel: 'Continue',
            );
          }
        }
      }

      if (_paymentMethod == PaymentMethod.momo ||
          _paymentMethod == PaymentMethod.revolut) {
        try {
          final handoff = await ref
              .read(orderGatewayProvider)
              .createPaymentHandoff(
                orderId: order.id,
                venueId: order.venueId,
                method: _paymentMethod,
              );
          if (!mounted) return;
          await showPaymentHandoffSheet(context, handoff: handoff);
          await _launchPaymentHandoff(handoff);
        } catch (error) {
          if (mounted) {
            await showFzNoticeSheet(
              context,
              title: 'Payment handoff unavailable',
              message:
                  'Order placed, but payment instructions are unavailable. Please ask venue staff.',
              icon: LucideIcons.alertTriangle,
              iconColor: FzColors.warning,
              primaryLabel: 'Continue',
            );
          }
        }
      }

      if (mounted) {
        context.go('/order/${order.id}/success');
      }
    } else if (mounted) {
      await showFzNoticeSheet(
        context,
        title: 'Scan a table QR',
        message: 'Scan a table QR before placing an order at the venue.',
        icon: LucideIcons.qrCode,
        primaryLabel: 'Browse Venues',
        onPrimary: () {
          if (mounted) context.go('/venues');
        },
      );
    }

    if (mounted) {
      setState(() => _submitting = false);
    }
  }

  Future<void> _launchPaymentHandoff(PaymentHandoff handoff) async {
    final Uri? uri;
    if (handoff.method == PaymentMethod.momo) {
      final ussd = handoff.ussdString;
      if (ussd == null || ussd.isEmpty) return;
      uri = Uri.parse("tel:${ussd.replaceAll('#', '%23')}");
    } else {
      final paymentUrl = handoff.paymentUrl;
      if (paymentUrl == null || paymentUrl.isEmpty) return;
      uri = Uri.tryParse(paymentUrl);
    }

    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: handoff.method == PaymentMethod.revolut
            ? LaunchMode.externalApplication
            : LaunchMode.platformDefault,
      );
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _fetSpendController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final venue = ref.watch(venueContextProvider).venue;
    final acceptsFetSpend = _venueAcceptsFetSpend(venue);

    final isRwanda = venue?.countryCode == CountryCode.rw;
    final isMalta = venue?.countryCode == CountryCode.mt;
    final hasMomoHandoff =
        isRwanda && (_hasText(venue?.momoCode) || _hasText(venue?.whatsapp));
    final hasRevolutHandoff = isMalta && _hasText(venue?.revolutLink);

    if ((_paymentMethod == PaymentMethod.momo && !hasMomoHandoff) ||
        (_paymentMethod == PaymentMethod.revolut && !hasRevolutHandoff)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _paymentMethod = PaymentMethod.cash);
        }
      });
    }

    if (cart.isEmpty) {
      return Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
            children: [
              const FzBackHeader(title: 'Checkout', subtitle: 'Order to Play'),
              const SizedBox(height: 48),
              StateView.empty(
                title: 'Cart is empty',
                subtitle: 'Add menu items from a venue before checkout.',
                icon: LucideIcons.shoppingCart,
                action: () => context.go('/venues'),
                actionLabel: 'Browse Venues',
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 130),
          children: [
            FzBackHeader(
              title: 'Checkout',
              subtitle: venue?.name ?? 'Order to Play',
            ),
            const SizedBox(height: 18),
            const Text(
              'ORDER SUMMARY',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            FzCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ...cart.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${item.quantity}x ${item.name}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          Text(
                            item.lineTotalDisplay,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal'),
                      Text(
                        cart.items.first.currencyCode == 'EUR'
                            ? '€${cart.subtotal.toStringAsFixed(2)}'
                            : '${cart.items.first.currencyCode} ${cart.subtotal.toStringAsFixed(0)}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TOTAL',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        cart.totalDisplay,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: FzColors.accent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'ORDER NOTES',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 3,
              onChanged: (value) =>
                  ref.read(cartProvider.notifier).setSpecialInstructions(value),
              decoration: const InputDecoration(
                hintText: 'Table notes or item instructions',
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'FET REWARDS',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            FzCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(LucideIcons.coins, color: FzColors.accent2),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Earn about ${cart.estimatedFet} FET after venue staff confirms payment.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: FzColors.lightMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (acceptsFetSpend) ...[
              const SizedBox(height: 12),
              FzCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      value: _useFetSpend,
                      onChanged: (value) =>
                          setState(() => _useFetSpend = value),
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Spend FET on this order',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: const Text(
                        'Applied only through the wallet ledger after the order is created.',
                      ),
                    ),
                    if (_useFetSpend) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _fetSpendController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(LucideIcons.wallet),
                          suffixText: 'FET',
                          hintText: 'Amount to spend',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              'PAYMENT METHOD',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            FzCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _PaymentMethodTile(
                    method: PaymentMethod.cash,
                    selected: _paymentMethod == PaymentMethod.cash,
                    onTap: () =>
                        setState(() => _paymentMethod = PaymentMethod.cash),
                  ),
                  if (hasMomoHandoff) ...[
                    const Divider(height: 1),
                    _PaymentMethodTile(
                      method: PaymentMethod.momo,
                      selected: _paymentMethod == PaymentMethod.momo,
                      onTap: () =>
                          setState(() => _paymentMethod = PaymentMethod.momo),
                    ),
                  ],
                  if (hasRevolutHandoff) ...[
                    const Divider(height: 1),
                    _PaymentMethodTile(
                      method: PaymentMethod.revolut,
                      selected: _paymentMethod == PaymentMethod.revolut,
                      onTap: () => setState(
                        () => _paymentMethod = PaymentMethod.revolut,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _submitting ? null : _placeOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: FzColors.accent,
                foregroundColor: FzColors.darkBg,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                _submitting
                    ? 'PLACING ORDER...'
                    : _paymentMethod == PaymentMethod.cash
                    ? 'PLACE ORDER'
                    : (_paymentMethod == PaymentMethod.momo
                          ? 'PLACE ORDER + OPEN USSD'
                          : 'PLACE ORDER + OPEN REVOLUT'),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _paymentMethod == PaymentMethod.cash
                  ? 'Complete payment directly with venue staff.'
                  : 'Payment happens outside FANZONE and remains pending until staff confirm it.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: FzColors.lightMuted),
            ),
          ],
        ),
      ),
    );
  }

  bool _venueAcceptsFetSpend(VenueModel? venue) {
    final value = venue?.featuresJson?['accepts_fet_spend'];
    if (value is bool) return value;
    if (value is String) {
      return {'true', '1', 'yes', 'on'}.contains(value.toLowerCase());
    }
    return false;
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
        method == PaymentMethod.cash
            ? LucideIcons.banknote
            : (method == PaymentMethod.momo
                  ? LucideIcons.phoneCall
                  : LucideIcons.creditCard),
        color: selected ? FzColors.accent : null,
      ),
      title: Text(
        method.label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: selected
          ? const Icon(
              LucideIcons.checkCircle,
              color: FzColors.accent,
              size: 20,
            )
          : null,
    );
  }
}
