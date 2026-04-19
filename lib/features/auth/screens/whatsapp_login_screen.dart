import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/phone_presets.dart';
import '../../../core/market/launch_market.dart';
import '../../../core/runtime/app_runtime_state.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/market_preferences_provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_brand_logo.dart';
import '../../../widgets/common/fz_card.dart';

/// Accent used on the phone verification screen.
const _verificationAccent = FzColors.teal;

/// WhatsApp verification screen — used when a guest decides to sign in.
class PhoneLoginScreen extends ConsumerStatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  ConsumerState<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends ConsumerState<PhoneLoginScreen> {
  // ── Controllers ──
  final _phoneController = TextEditingController();
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(6, (_) => FocusNode());

  // ── State ──
  bool _otpSent = false;
  bool _loading = false;
  String? _error;
  bool _retryingInit = false;

  // ── Resend cooldown ──
  int _resendCooldown = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _phoneController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final n in _otpFocusNodes) {
      n.dispose();
    }
    _resendTimer?.cancel();
    super.dispose();
  }

  // ──────────────────────────────────────────────
  // Actions
  // ──────────────────────────────────────────────

  PhonePreset get _phonePreset => _resolvePhonePreset();

  String get _phoneHint => _phonePreset.example;

  String get _fullPhone {
    final raw = _phoneController.text.trim();
    if (raw.startsWith('+')) return raw;

    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final dialDigits = _phonePreset.dialCode.replaceAll('+', '');
    if (digits.startsWith(dialDigits)) {
      return '+$digits';
    }
    return '${_phonePreset.dialCode}$digits';
  }

  Future<void> _sendOtp() async {
    final phone = _fullPhone;
    final digitCount = phone.replaceAll(RegExp(r'\D'), '').length;
    if (!phone.startsWith('+') || digitCount < _phonePreset.minDigits) {
      setState(
        () => _error = 'Enter your WhatsApp number with country code.',
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final sent = await authService.sendOtp(phone);
      if (!mounted) return;

      if (sent) {
        setState(() => _otpSent = true);
        _startResendCooldown();
        // Auto-focus first OTP field
        _otpFocusNodes[0].requestFocus();
      } else {
        setState(
          () => _error = 'Could not send your WhatsApp code. Please try again.',
        );
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length != 6) {
      setState(() => _error = 'Enter the complete 6-digit code.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      await authService.verifyOtp(_fullPhone, otp);
      if (!mounted) return;
      context.go(_postAuthRedirect(context));
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Verification failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _retryInitialization() async {
    final retry = appRuntime.retrySupabaseInitialization;
    if (retry == null || _retryingInit) return;

    setState(() {
      _retryingInit = true;
      _error = null;
    });

    try {
      await retry();
      if (!mounted) return;
      if (appRuntime.supabaseInitError != null) {
        setState(() => _error = appRuntime.supabaseInitError);
      }
    } finally {
      if (mounted) {
        setState(() => _retryingInit = false);
      }
    }
  }

  void _startResendCooldown() {
    _resendCooldown = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) timer.cancel();
      });
    });
  }

  void _goBackToPhone() {
    setState(() {
      _otpSent = false;
      _error = null;
      for (final c in _otpControllers) {
        c.clear();
      }
    });
  }

  String _postAuthRedirect(BuildContext context) {
    final redirectTo = GoRouterState.of(context).uri.queryParameters['from'];
    if (redirectTo != null && redirectTo.startsWith('/')) {
      return redirectTo;
    }
    return '/';
  }

  PhonePreset _resolvePhonePreset() {
    final localeCountry = WidgetsBinding
        .instance
        .platformDispatcher
        .locale
        .countryCode
        ?.toUpperCase();
    final localePreset = phonePresetForCountry(localeCountry);
    if (localePreset != null) return localePreset;

    return phonePresetForRegion(
      normalizeRegionKey(ref.read(primaryMarketRegionProvider)),
    );
  }

  void _handleOtpChanged(int index, String value) {
    final digit = value.replaceAll(RegExp(r'\D'), '');
    if (_otpControllers[index].text != digit) {
      _otpControllers[index].value = TextEditingValue(
        text: digit,
        selection: TextSelection.collapsed(offset: digit.length),
      );
    }

    if (digit.isNotEmpty && index < _otpFocusNodes.length - 1) {
      _otpFocusNodes[index + 1].requestFocus();
    } else if (digit.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final mutedColor = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final surfaceColor = isDark ? FzColors.darkSurface2 : FzColors.lightSurface;
    final authUnavailable = appRuntime.supabaseInitError != null;
    final statusMessage = authUnavailable
        ? appRuntime.supabaseInitError
        : _error;

    return Scaffold(
      backgroundColor: isDark ? FzColors.darkBg : FzColors.lightBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    const Center(child: FzBrandLogo(width: 76, height: 76)),
                    const SizedBox(height: 18),
                    Text(
                      'FANZONE',
                      textAlign: TextAlign.center,
                      style: FzTypography.display(
                        size: 34,
                        color: textColor,
                        letterSpacing: 2.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _otpSent
                          ? 'Enter the 6-digit code sent to your WhatsApp.'
                          : 'Verify your number to start earning FET tokens and join fan clubs. It\'s 100% free.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: mutedColor,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FzCard(
                      color: surfaceColor,
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _otpSent
                            ? _buildOtpStep(
                                context: context,
                                textColor: textColor,
                                mutedColor: mutedColor,
                                statusMessage: statusMessage,
                                authUnavailable: authUnavailable,
                              )
                            : _buildPhoneStep(
                                context: context,
                                textColor: textColor,
                                mutedColor: mutedColor,
                                statusMessage: statusMessage,
                                authUnavailable: authUnavailable,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPhoneStep({
    required BuildContext context,
    required Color textColor,
    required Color mutedColor,
    required String? statusMessage,
    required bool authUnavailable,
  }) {
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('phone_step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.chat_bubble_outline_rounded,
              color: _verificationAccent,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'VERIFY VIA WHATSAPP',
                style: FzTypography.display(
                  size: 24,
                  color: textColor,
                  letterSpacing: 1.6,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 92,
              height: 56,
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? FzColors.darkSurface3
                    : FzColors.lightSurface2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.brightness == Brightness.dark
                      ? FzColors.darkBorder
                      : FzColors.lightBorder,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                _phonePreset.dialCode,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
                ],
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: textColor,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  hintText: _phoneHint,
                  hintStyle: theme.textTheme.bodyLarge?.copyWith(
                    color: mutedColor,
                    fontFamily: 'monospace',
                  ),
                  filled: true,
                  fillColor: theme.brightness == Brightness.dark
                      ? FzColors.darkSurface3
                      : FzColors.lightSurface2,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: theme.brightness == Brightness.dark
                          ? FzColors.darkBorder
                          : FzColors.lightBorder,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: _verificationAccent,
                      width: 1.5,
                    ),
                  ),
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onFieldSubmitted: (_) {
                  if (!_loading && !authUnavailable) {
                    unawaited(_sendOtp());
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (statusMessage != null)
          _StatusBanner(
            message: statusMessage,
            color: authUnavailable ? FzColors.coral : FzColors.danger,
            actionLabel: authUnavailable ? 'Retry' : null,
            loading: _retryingInit,
            onAction: authUnavailable ? _retryInitialization : null,
          ),
        if (statusMessage != null) const SizedBox(height: 14),
        _PrimaryActionButton(
          label: _loading ? 'SENDING...' : 'SEND CODE VIA WHATSAPP',
          onPressed: (_loading || authUnavailable) ? null : _sendOtp,
          color: _verificationAccent,
          textColor: const Color(0xFF061514),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildOtpStep({
    required BuildContext context,
    required Color textColor,
    required Color mutedColor,
    required String? statusMessage,
    required bool authUnavailable,
  }) {
    return Column(
      key: const ValueKey('otp_step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.chat_bubble_outline_rounded,
              color: _verificationAccent,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'ENTER OTP',
                style: FzTypography.display(
                  size: 24,
                  color: textColor,
                  letterSpacing: 1.6,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            _otpControllers.length,
            (index) => SizedBox(
              width: 44,
              child: TextField(
                controller: _otpControllers[index],
                focusNode: _otpFocusNodes[index],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? FzColors.darkSurface3
                      : FzColors.lightSurface2,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? FzColors.darkBorder
                          : FzColors.lightBorder,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: _verificationAccent,
                      width: 1.5,
                    ),
                  ),
                ),
                onChanged: (value) {
                  if (_error != null) setState(() => _error = null);
                  _handleOtpChanged(index, value);
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (statusMessage != null)
          _StatusBanner(
            message: statusMessage,
            color: authUnavailable ? FzColors.coral : FzColors.danger,
          ),
        if (statusMessage != null) const SizedBox(height: 14),
        _PrimaryActionButton(
          label: _loading ? 'VERIFYING...' : 'VERIFY CODE',
          onPressed: (_loading || authUnavailable) ? null : _verifyOtp,
          color: _verificationAccent,
          textColor: const Color(0xFF061514),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _loading ? null : _goBackToPhone,
              child: Text(
                'Use a different number',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: mutedColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              _resendCooldown > 0 ? 'Resend in ${_resendCooldown}s' : '',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: mutedColor),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'Your number is never shown to others.',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: mutedColor),
          ),
        ),
      ],
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.label,
    required this.onPressed,
    required this.color,
    required this.textColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          disabledBackgroundColor: color.withValues(alpha: 0.35),
          disabledForegroundColor: textColor.withValues(alpha: 0.7),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.message,
    required this.color,
    this.actionLabel,
    this.loading = false,
    this.onAction,
  });

  final String message;
  final Color color;
  final String? actionLabel;
  final bool loading;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.14 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark ? FzColors.darkText : FzColors.lightText,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: loading ? null : onAction,
              child: Text(loading ? '...' : actionLabel!),
            ),
        ],
      ),
    );
  }
}
