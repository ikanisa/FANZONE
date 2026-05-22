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
  String? _paymentMethodVenueId;
  final _tableNumberController = TextEditingController();
  final _notesController = TextEditingController();
  final _fetSpendController = TextEditingController();
  bool _useFetSpend = false;
  bool _submitting = false;

  Future<void> _placeOrder() async {
    if (_submitting) return;
    final tableNumber = normalizeManualTableNumber(_tableNumberController.text);
    if (tableNumber == null) {
      await showFzNoticeSheet(
        context,
        title: 'Add table number',
        message: 'Enter your table number so venue staff can bring the order.',
        icon: LucideIcons.hash,
        iconColor: FzColors.warning,
        primaryLabel: 'Continue',
      );
      return;
    }

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
      tableNumber: tableNumber,
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
              message: 'Order placed. FET failed: $error',
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
          final launched = await _launchPaymentHandoff(handoff);
          if (!launched && mounted) {
            await showFzNoticeSheet(
              context,
              title: 'Payment handoff ready',
              message:
                  'Order placed. Open ${handoff.method.label} from your phone, then tap I paid after sending payment.',
              icon: LucideIcons.externalLink,
              iconColor: FzColors.warning,
              primaryLabel: 'Continue',
            );
          }
        } catch (error) {
          if (mounted) {
            await showFzNoticeSheet(
              context,
              title: 'Payment handoff unavailable',
              message:
                  'Order placed. Ask venue staff for payment instructions, then tap I paid after sending payment.',
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
      final placementState = ref.read(orderPlacementProvider);
      final errorMessage = placementState.errorMessage;
      await showFzNoticeSheet(
        context,
        title: errorMessage == null ? 'Choose a bar' : 'Order unavailable',
        message: errorMessage ?? 'Open a bar menu before ordering.',
        icon: errorMessage == null
            ? LucideIcons.mapPin
            : LucideIcons.alertTriangle,
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

  Future<bool> _launchPaymentHandoff(PaymentHandoff handoff) async {
    final uri = paymentHandoffLaunchUri(handoff);
    if (uri == null) return false;

    if (await canLaunchUrl(uri)) {
      return launchUrl(
        uri,
        mode: handoff.method == PaymentMethod.revolut
            ? LaunchMode.externalApplication
            : LaunchMode.platformDefault,
      );
    }
    return false;
  }

  @override
  void dispose() {
    _tableNumberController.dispose();
    _notesController.dispose();
    _fetSpendController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final venue = ref.watch(venueContextProvider).venue;
    final acceptsFetSpend = _venueAcceptsFetSpend(venue);

    final hasMomoHandoff = venueSupportsPaymentMethod(
      venue,
      PaymentMethod.momo,
    );
    final hasRevolutHandoff = venueSupportsPaymentMethod(
      venue,
      PaymentMethod.revolut,
    );

    final resolvedPaymentMethod = _paymentMethodVenueId != venue?.id
        ? defaultCheckoutPaymentMethod(venue)
        : preferredCheckoutPaymentMethod(current: _paymentMethod, venue: venue);
    if (resolvedPaymentMethod != _paymentMethod) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _paymentMethod = resolvedPaymentMethod;
            _paymentMethodVenueId = venue?.id;
          });
        }
      });
    } else if (_paymentMethodVenueId != venue?.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _paymentMethodVenueId = venue?.id);
        }
      });
    }

    if (cart.isEmpty) {
      return Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
            children: [
              const FzBackHeader(title: 'Checkout', subtitle: 'Order'),
              const SizedBox(height: 48),
              StateView.empty(
                title: 'Cart is empty',
                subtitle: 'Add items.',
                icon: LucideIcons.shoppingCart,
                action: () => context.go('/venues'),
                actionLabel: 'Bars',
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
            FzBackHeader(title: 'Checkout', subtitle: venue?.name ?? 'Order'),
            const SizedBox(height: 18),
            const Text(
              'SUMMARY',
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
            TextField(
              controller: _tableNumberController,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                prefixIcon: Icon(LucideIcons.hash),
                labelText: 'Table number',
                hintText: 'Example: 12 or VIP 2',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 3,
              onChanged: (value) =>
                  ref.read(cartProvider.notifier).setSpecialInstructions(value),
              decoration: const InputDecoration(
                hintText: 'Special instructions',
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
                        'Spend FET',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: const Text('Wallet ledger.'),
                    ),
                    if (_useFetSpend) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _fetSpendController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(LucideIcons.wallet),
                          suffixText: 'FET',
                          hintText: 'Amount',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              'PAYMENT',
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
                    ? 'ORDERING...'
                    : _paymentMethod == PaymentMethod.cash
                    ? 'ORDER'
                    : (_paymentMethod == PaymentMethod.momo
                          ? 'OPEN USSD'
                          : 'OPEN REVOLUT'),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _paymentMethod == PaymentMethod.cash
                  ? 'Pay staff.'
                  : 'Awaiting venue.',
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

@visibleForTesting
bool venueSupportsPaymentMethod(VenueModel? venue, PaymentMethod method) {
  if (venue == null) return method == PaymentMethod.cash;

  switch (method) {
    case PaymentMethod.cash:
      return true;
    case PaymentMethod.momo:
      return venue.countryCode == CountryCode.rw &&
          (_hasCheckoutText(venue.momoCode) ||
              _hasCheckoutText(venue.whatsapp));
    case PaymentMethod.revolut:
      return venue.countryCode == CountryCode.mt &&
          _hasCheckoutText(venue.revolutLink);
    case PaymentMethod.card:
    case PaymentMethod.other:
      return false;
  }
}

@visibleForTesting
PaymentMethod preferredCheckoutPaymentMethod({
  required PaymentMethod current,
  required VenueModel? venue,
}) {
  if (venueSupportsPaymentMethod(venue, current)) return current;
  return PaymentMethod.cash;
}

@visibleForTesting
PaymentMethod defaultCheckoutPaymentMethod(VenueModel? venue) {
  if (venueSupportsPaymentMethod(venue, PaymentMethod.momo)) {
    return PaymentMethod.momo;
  }
  if (venueSupportsPaymentMethod(venue, PaymentMethod.revolut)) {
    return PaymentMethod.revolut;
  }
  return PaymentMethod.cash;
}

@visibleForTesting
String? normalizeManualTableNumber(String raw) {
  final normalized = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.isEmpty || normalized.length > 24) return null;
  return normalized;
}

@visibleForTesting
Uri? paymentHandoffLaunchUri(PaymentHandoff handoff) {
  switch (handoff.method) {
    case PaymentMethod.momo:
      final ussd = handoff.ussdString?.trim();
      if (ussd == null || ussd.isEmpty) return null;
      return Uri.parse("tel:${ussd.replaceAll('#', '%23')}");
    case PaymentMethod.revolut:
      final paymentUrl = handoff.paymentUrl?.trim();
      if (paymentUrl == null || paymentUrl.isEmpty) return null;
      final uri = Uri.tryParse(paymentUrl);
      if (uri == null || !uri.hasScheme) return null;
      return uri;
    case PaymentMethod.cash:
    case PaymentMethod.card:
    case PaymentMethod.other:
      return null;
  }
}

bool _hasCheckoutText(String? value) =>
    value != null && value.trim().isNotEmpty;

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
