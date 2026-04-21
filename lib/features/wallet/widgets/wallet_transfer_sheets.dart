import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/currency_utils.dart';
import '../../../models/wallet.dart';
import '../../../providers/currency_provider.dart';
import '../../../services/wallet_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fz_glass_loader.dart';
import '../../../widgets/common/fz_wordmark.dart';
import 'wallet_screen_components.dart';

typedef WalletTransferSubmit = Future<void> Function(String fanId, int amount);

class TransferFetSheet extends ConsumerStatefulWidget {
  const TransferFetSheet({super.key, this.onSubmitTransfer});

  final WalletTransferSubmit? onSubmitTransfer;

  @override
  ConsumerState<TransferFetSheet> createState() => _TransferFetSheetState();
}

class _TransferFetSheetState extends ConsumerState<TransferFetSheet> {
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();
  bool _submitting = false;
  bool _success = false;
  String? _error;
  Timer? _successTimer;

  @override
  void dispose() {
    _successTimer?.cancel();
    _recipientController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  bool get _isValidFanId {
    final text = _recipientController.text.trim();
    return RegExp(r'^\d{6}$').hasMatch(text);
  }

  Future<void> _submit() async {
    final fanId = _recipientController.text.trim();
    final amount = int.tryParse(_amountController.text.trim()) ?? 0;

    if (!_isValidFanId) {
      setState(() => _error = 'Enter a valid 6-digit Fan ID.');
      return;
    }

    if (amount <= 0) {
      setState(() => _error = 'Enter a valid FET amount.');
      return;
    }

    final myFanId = ref.read(userFanIdProvider).valueOrNull;
    if (myFanId != null && myFanId == fanId) {
      setState(() => _error = 'You cannot transfer tokens to yourself.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final submitTransfer =
          widget.onSubmitTransfer ??
          (fanId, amount) => ref
              .read(walletServiceProvider.notifier)
              .transferByFanId(fanId, amount);

      await submitTransfer(fanId, amount);

      if (!mounted) return;
      setState(() {
        _submitting = false;
        _success = true;
      });
      _successTimer?.cancel();
      _successTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) Navigator.of(context).pop();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final fieldSurface = isDark
        ? FzColors.darkSurface2
        : FzColors.lightSurface2;
    final fieldBorder = isDark ? FzColors.darkBorder : FzColors.lightBorder;
    final balance = ref.watch(walletServiceProvider).valueOrNull ?? 0;
    final currency = ref.watch(userCurrencyProvider).valueOrNull ?? 'EUR';
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final amountValue = int.tryParse(_amountController.text.trim()) ?? 0;
    final canSubmit =
        _isValidFanId &&
        amountValue > 0 &&
        amountValue <= balance &&
        !_submitting;

    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: isDark ? FzColors.darkSurface : FzColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: muted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (_success) ...[
                const SizedBox(height: 24),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: FzColors.primary.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.send,
                          size: 34,
                          color: FzColors.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Sent Successfully!',
                        style: FzTypography.display(
                          size: 28,
                          color: textColor,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You sent ${_amountController.text.trim()} FET to Fan #${_recipientController.text.trim()}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: muted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Transfer FET',
                            style: FzTypography.display(
                              size: 28,
                              color: textColor,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Send tokens to other fans instantly.',
                            style: TextStyle(fontSize: 14, color: muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: fieldSurface,
                          shape: BoxShape.circle,
                          border: Border.all(color: fieldBorder),
                        ),
                        child: Icon(LucideIcons.x, size: 18, color: muted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Recipient Fan ID',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: muted,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: fieldSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: fieldBorder),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '#',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: muted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _recipientController,
                          maxLength: 6,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          onChanged: (_) => setState(() {}),
                          style: FzTypography.score(
                            size: 20,
                            weight: FontWeight.w700,
                            color: textColor,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: '123456',
                            hintStyle: TextStyle(
                              color: muted.withValues(alpha: 0.5),
                              fontSize: 20,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Amount to Send',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: muted,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      'Balance: ${formatFET(balance, currency)}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: FzColors.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: fieldSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: fieldBorder),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'FET',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: muted,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (_) => setState(() {}),
                          style: FzTypography.score(
                            size: 20,
                            weight: FontWeight.w700,
                            color: textColor,
                          ),
                          decoration: InputDecoration(
                            hintText: '0',
                            hintStyle: TextStyle(
                              color: muted.withValues(alpha: 0.5),
                              fontSize: 20,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: balance <= 0
                            ? null
                            : () {
                                _amountController.text = '$balance';
                                setState(() {});
                              },
                        style: TextButton.styleFrom(
                          backgroundColor: FzColors.primary.withValues(
                            alpha: 0.1,
                          ),
                          foregroundColor: FzColors.primary,
                          minimumSize: const Size(0, 28),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'MAX',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if ((_error ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: FzColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: FzColors.error.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.alertCircle,
                          size: 16,
                          color: FzColors.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: FzColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: canSubmit ? _submit : null,
                    icon: _submitting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: FzGlassLoader(useBackdrop: false, size: 14),
                          )
                        : const Icon(LucideIcons.send, size: 16),
                    label: Text(
                      _submitting ? 'Sending...' : 'Confirm Transfer',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: textColor,
                      foregroundColor: isDark
                          ? FzColors.darkBg
                          : FzColors.lightSurface,
                      disabledBackgroundColor: isDark
                          ? FzColors.darkSurface3
                          : FzColors.lightSurface3,
                      disabledForegroundColor: muted,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ReceiveFetSheet extends ConsumerWidget {
  const ReceiveFetSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fanId = ref.watch(userFanIdProvider).valueOrNull;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final shareText = fanId != null
        ? 'Send FET to Fan #$fanId on FANZONE.'
        : 'Find me on FANZONE and send FET using my Fan ID.';
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: isDark ? FzColors.darkSurface : FzColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: muted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Receive FET',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Share your Fan ID so other fans can send you tokens.',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 18),
              FzCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    fanId != null
                        ? Text(
                            'Fan #$fanId',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          )
                        : Text.rich(
                            TextSpan(
                              children: FzWordmark.spansForText(
                                'FANZONE Member',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ),
                    const SizedBox(height: 6),
                    Text(
                      'Your Fan ID',
                      style: TextStyle(
                        fontSize: 10,
                        color: muted,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: FzColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: FzColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        fanId != null ? '#$fanId' : 'Loading...',
                        style: FzTypography.score(
                          size: 28,
                          weight: FontWeight.w700,
                          color: FzColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Others can send FET to you using this 6-digit Fan ID.',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: fanId == null
                          ? null
                          : () async {
                              await Clipboard.setData(
                                ClipboardData(text: fanId),
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Fan ID copied.')),
                              );
                            },
                      icon: const Icon(LucideIcons.copy, size: 18),
                      label: const Text('Copy'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        await SharePlus.instance.share(
                          ShareParams(text: shareText),
                        );
                      },
                      icon: const Icon(LucideIcons.share2, size: 18),
                      label: const Text('Share'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PartnerSpendSheet extends ConsumerStatefulWidget {
  const PartnerSpendSheet({super.key, required this.offer});

  final WalletPromoOffer offer;

  @override
  ConsumerState<PartnerSpendSheet> createState() => _PartnerSpendSheetState();
}

class _PartnerSpendSheetState extends ConsumerState<PartnerSpendSheet> {
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();
  String _step = 'details';

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  bool get _isValidRecipient =>
      RegExp(r'^\d{6}$').hasMatch(_recipientController.text.trim());

  int get _cost {
    if (!widget.offer.flexible) return widget.offer.cost;
    return int.tryParse(_amountController.text.trim()) ?? 0;
  }

  Future<void> _pay(int balance) async {
    if (!_isValidRecipient || _cost <= 0 || _cost > balance) return;
    setState(() => _step = 'processing');
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() => _step = 'success');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? FzColors.darkSurface : FzColors.lightSurface;
    final panel = isDark ? FzColors.darkSurface2 : FzColors.lightSurface2;
    final border = isDark ? FzColors.darkBorder : FzColors.lightBorder;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final balance = ref.watch(walletServiceProvider).valueOrNull ?? 0;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final canPay = _isValidRecipient && _cost > 0 && _cost <= balance;

    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _step == 'processing'
                ? SizedBox(
                    key: const ValueKey('promo-processing'),
                    height: 320,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 64,
                            height: 64,
                            child: CircularProgressIndicator(
                              strokeWidth: 4,
                              color: FzColors.primary,
                              backgroundColor: panel,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Processing Payment...',
                            style: FzTypography.display(
                              size: 22,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Awaiting confirmation from ${widget.offer.title}',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: muted),
                          ),
                        ],
                      ),
                    ),
                  )
                : _step == 'success'
                ? SizedBox(
                    key: const ValueKey('promo-success'),
                    height: 340,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: FzColors.success.withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.checkSquare,
                            size: 38,
                            color: FzColors.success,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Success!',
                          style: FzTypography.display(
                            size: 30,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You paid $_cost FET for ${widget.offer.title}',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: muted),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: panel,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: border),
                          ),
                          child: Text(
                            'Recipient: #${_recipientController.text.trim()}',
                            style: TextStyle(
                              fontSize: 12,
                              color: muted,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textColor,
                              side: BorderSide(color: border),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            child: const Text(
                              'Done',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    key: const ValueKey('promo-details'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Checkout ',
                                      style: FzTypography.display(
                                        size: 26,
                                        color: textColor,
                                      ),
                                    ),
                                    TextSpan(
                                      text: widget.offer.emoji,
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () => Navigator.of(context).pop(),
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: panel,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  LucideIcons.x,
                                  size: 16,
                                  color: muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: panel,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.offer.title,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.offer.description,
                                style: TextStyle(fontSize: 14, color: muted),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Recipient ID (6 Digits)',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: muted,
                                  letterSpacing: 0.9,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _recipientController,
                                maxLength: 6,
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(6),
                                ],
                                onChanged: (_) => setState(() {}),
                                style: FzTypography.score(
                                  size: 22,
                                  weight: FontWeight.w700,
                                  color: textColor,
                                ),
                                decoration: InputDecoration(
                                  counterText: '',
                                  hintText: '582910',
                                  hintStyle: TextStyle(
                                    color: muted.withValues(alpha: 0.45),
                                    fontSize: 22,
                                  ),
                                  filled: true,
                                  fillColor: surface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: border),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: border),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: FzColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (widget.offer.flexible) ...[
                                Row(
                                  children: [
                                    Text(
                                      'Enter FET Amount',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: muted,
                                        letterSpacing: 0.9,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      'Balance: $balance FET',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: FzColors.accent2,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _amountController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  onChanged: (_) => setState(() {}),
                                  style: FzTypography.score(
                                    size: 22,
                                    weight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '0',
                                    hintStyle: TextStyle(
                                      color: muted.withValues(alpha: 0.45),
                                      fontSize: 22,
                                    ),
                                    filled: true,
                                    fillColor: surface,
                                    suffixIcon: TextButton(
                                      onPressed: balance <= 0
                                          ? null
                                          : () {
                                              _amountController.text =
                                                  '$balance';
                                              setState(() {});
                                            },
                                      child: const Text('MAX'),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(color: border),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(color: border),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                        color: FzColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ] else
                                Row(
                                  children: [
                                    Text(
                                      'Total Cost',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: muted,
                                        letterSpacing: 0.9,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${widget.offer.cost} FET',
                                      style: FzTypography.score(
                                        size: 20,
                                        weight: FontWeight.w700,
                                        color: textColor,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: canPay ? () => _pay(balance) : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: textColor,
                              foregroundColor: isDark
                                  ? FzColors.darkBg
                                  : FzColors.lightBg,
                              disabledBackgroundColor: panel,
                              disabledForegroundColor: muted,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            child: const Text(
                              'Pay Now',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class TransactionReceiptDialog extends StatelessWidget {
  const TransactionReceiptDialog({super.key, required this.transaction});

  final WalletTransaction transaction;

  static Future<void> show(
    BuildContext context, {
    required WalletTransaction transaction,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => TransactionReceiptDialog(transaction: transaction),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? FzColors.darkSurface : FzColors.lightSurface;
    final panel = isDark ? FzColors.darkSurface2 : FzColors.lightSurface2;
    final border = isDark ? FzColors.darkBorder : FzColors.lightBorder;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final isPositive =
        transaction.type == 'earn' || transaction.type == 'transfer_received';
    final amountColor = isPositive ? FzColors.success : FzColors.coral;
    final refSuffix = transaction.id.substring(
      0,
      transaction.id.length < 8 ? transaction.id.length : 8,
    );

    return Dialog(
      backgroundColor: surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: panel,
                    shape: BoxShape.circle,
                    border: Border.all(color: border),
                  ),
                  child: Icon(LucideIcons.receipt, size: 22, color: muted),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: panel,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(LucideIcons.x, size: 16, color: muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  Text(
                    '${isPositive ? '+' : '-'}${transaction.amount} FET',
                    style: FzTypography.score(
                      size: 38,
                      weight: FontWeight.w700,
                      color: amountColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    transaction.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    transaction.dateStr,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: muted,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: panel,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: border),
              ),
              child: Column(
                children: [
                  _ReceiptRow(
                    label: 'Status',
                    value: 'Completed',
                    valueColor: FzColors.success,
                    muted: muted,
                    leadingIcon: LucideIcons.checkSquare,
                  ),
                  const SizedBox(height: 12),
                  _ReceiptRow(
                    label: 'Type',
                    value: transaction.type.replaceAll('_', ' ').toUpperCase(),
                    valueColor: textColor,
                    muted: muted,
                  ),
                  const SizedBox(height: 12),
                  _ReceiptRow(
                    label: 'Ref ID',
                    value: 'TX_${refSuffix.toUpperCase()}',
                    valueColor: muted,
                    muted: muted,
                    monospace: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: textColor,
                  foregroundColor: isDark ? FzColors.darkBg : FzColors.lightBg,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: const Text(
                  'Close Receipt',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.muted,
    this.leadingIcon,
    this.monospace = false,
  });

  final String label;
  final String value;
  final Color valueColor;
  final Color muted;
  final IconData? leadingIcon;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: muted,
            letterSpacing: 0.9,
          ),
        ),
        const Spacer(),
        if (leadingIcon != null) ...[
          Icon(leadingIcon, size: 12, color: valueColor),
          const SizedBox(width: 4),
        ],
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: valueColor,
            fontFamily: monospace ? 'monospace' : null,
          ),
        ),
      ],
    );
  }
}
