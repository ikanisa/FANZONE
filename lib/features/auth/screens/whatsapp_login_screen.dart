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
import '../../../widgets/common/fz_brand_logo.dart';

/// Accent used on the phone verification screen.
const _verificationAccent = FzColors.teal;

/// Phone verification screen — used when a guest decides to sign in.
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

  String get _fullPhone => _phoneController.text.trim();

  Future<void> _sendOtp() async {
    final phone = _fullPhone;
    final digitCount = phone.replaceAll(RegExp(r'\D'), '').length;
    if (!phone.startsWith('+') || digitCount < _phonePreset.minDigits) {
      setState(
        () => _error = 'Enter your full phone number with country code.',
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
        setState(() => _error = 'Could not send OTP. Please try again.');
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
}
