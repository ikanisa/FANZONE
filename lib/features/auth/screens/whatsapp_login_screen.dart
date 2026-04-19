import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  _PhoneLoginPreset get _phonePreset => _resolvePhonePreset();

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

  _PhoneLoginPreset _resolvePhonePreset() {
    final localeCountry = WidgetsBinding
        .instance
        .platformDispatcher
        .locale
        .countryCode
        ?.toUpperCase();
    final localePreset = _presetForCountryCode(localeCountry);
    if (localePreset != null) return localePreset;

    switch (normalizeRegionKey(ref.read(primaryMarketRegionProvider))) {
      case 'africa':
        return const _PhoneLoginPreset(
          example: '+250 7XX XXX XXX',
          minDigits: 9,
        );
      case 'europe':
        return const _PhoneLoginPreset(
          example: '+44 7XXX XXX XXX',
          minDigits: 10,
        );
      case 'north_america':
        return const _PhoneLoginPreset(
          example: '+1 555 123 4567',
          minDigits: 10,
        );
      default:
        return const _PhoneLoginPreset(
          example: '+1 555 123 4567',
          minDigits: 10,
        );
    }
  }

  _PhoneLoginPreset? _presetForCountryCode(String? code) {
    switch (code) {
      case 'MT':
        return const _PhoneLoginPreset(example: '+356 79XX XXXX', minDigits: 8);
      case 'RW':
        return const _PhoneLoginPreset(
          example: '+250 7XX XXX XXX',
          minDigits: 9,
        );
      case 'NG':
        return const _PhoneLoginPreset(
          example: '+234 80X XXX XXXX',
          minDigits: 10,
        );
      case 'KE':
      case 'UG':
        return const _PhoneLoginPreset(
          example: '+254 7XX XXX XXX',
          minDigits: 9,
        );
      case 'GB':
        return const _PhoneLoginPreset(
          example: '+44 7XXX XXX XXX',
          minDigits: 10,
        );
      case 'DE':
        return const _PhoneLoginPreset(
          example: '+49 15XX XXX XXX',
          minDigits: 10,
        );
      case 'FR':
        return const _PhoneLoginPreset(
          example: '+33 6 XX XX XX XX',
          minDigits: 9,
        );
      case 'IT':
        return const _PhoneLoginPreset(
          example: '+39 3XX XXX XXXX',
          minDigits: 10,
        );
      case 'ES':
        return const _PhoneLoginPreset(
          example: '+34 6XX XXX XXX',
          minDigits: 9,
        );
      case 'PT':
        return const _PhoneLoginPreset(
          example: '+351 9XX XXX XXX',
          minDigits: 9,
        );
      case 'NL':
        return const _PhoneLoginPreset(
          example: '+31 6 XX XX XX XX',
          minDigits: 9,
        );
      case 'US':
      case 'CA':
        return const _PhoneLoginPreset(
          example: '+1 555 123 4567',
          minDigits: 10,
        );
      case 'MX':
        return const _PhoneLoginPreset(
          example: '+52 55 1234 5678',
          minDigits: 10,
        );
      default:
        return null;
    }
  }

  // ──────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // ── Connection error state ──
    if (appRuntime.supabaseInitError != null) {
      return _buildConnectionError(theme, isDark);
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 40),

                // ── Logo ──
                const FzBrandLogo(width: 72, height: 72, preferCdn: true),
                const SizedBox(height: 24),
                Text(
                  'FANZONE',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _otpSent
                      ? 'Enter your verification code'
                      : 'Verify your phone number when you want to predict, join pools, or transfer FET',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? FzColors.darkMuted : FzColors.lightMuted,
                  ),
                ),
                const SizedBox(height: 40),

                // ── Phone or OTP step ──
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _otpSent
                      ? _buildOtpStep(theme, isDark)
                      : _buildPhoneStep(theme, isDark),
                ),

                // ── Error ──
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: FzColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: FzColors.error,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: FzColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // ── Continue as guest ──
                TextButton(
                  onPressed: () => context.go('/'),
                  child: Text(
                    'Continue as guest',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? FzColors.darkMuted : FzColors.lightMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Phone entry step
  // ──────────────────────────────────────────────

  Widget _buildPhoneStep(ThemeData theme, bool isDark) {
    return Column(
      key: const ValueKey('phone_step'),
      children: [
        // Phone input with country code prefix
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          autocorrect: false,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _sendOtp(),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
            LengthLimitingTextInputFormatter(15),
          ],
          decoration: InputDecoration(
            labelText: 'Mobile number',
            hintText: _phoneHint,
            helperText: 'Use international format, for example $_phoneHint.',
            prefixIcon: Icon(
              Icons.phone_rounded,
              color: isDark ? FzColors.darkMuted : FzColors.lightMuted,
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Send OTP button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _loading ? null : _sendOtp,
            style: FilledButton.styleFrom(
              backgroundColor: _verificationAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sms_rounded, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Send code via SMS',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),

        const SizedBox(height: 16),

        Text(
          'We\'ll send a 6-digit SMS code to this number.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isDark ? FzColors.darkMuted : FzColors.lightMuted,
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // OTP entry step
  // ──────────────────────────────────────────────

  Widget _buildOtpStep(ThemeData theme, bool isDark) {
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return Column(
      key: const ValueKey('otp_step'),
      children: [
        // Sent-to indicator
        Text(
          'Code sent to $_fullPhone',
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: _goBackToPhone,
          child: Text(
            'Change number',
            style: theme.textTheme.bodySmall?.copyWith(
              color: _verificationAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // 6-digit OTP fields
        LayoutBuilder(
          builder: (context, constraints) {
            const boxCount = 6;
            const gap = 6.0;
            final fieldWidth =
                ((constraints.maxWidth - (gap * (boxCount - 1))) / boxCount)
                    .clamp(40.0, 46.0);

            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(boxCount, (i) {
                return Container(
                  width: fieldWidth,
                  height: 56,
                  margin: EdgeInsets.only(right: i == boxCount - 1 ? 0 : gap),
                  child: TextField(
                    controller: _otpControllers[i],
                    focusNode: _otpFocusNodes[i],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark
                              ? FzColors.darkBorder
                              : FzColors.lightBorder,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: _verificationAccent,
                          width: 2,
                        ),
                      ),
                    ),
                    onChanged: (value) {
                      if (value.isNotEmpty && i < 5) {
                        _otpFocusNodes[i + 1].requestFocus();
                      }
                      // H-6 fix: If the field was cleared (backspace) and this
                      // isn't the first field, move focus to the previous field.
                      if (value.isEmpty && i > 0) {
                        _otpFocusNodes[i - 1].requestFocus();
                      }
                      // Auto-submit when all 6 digits entered
                      if (i == 5 && value.isNotEmpty) {
                        final otp = _otpControllers.map((c) => c.text).join();
                        if (otp.length == 6) {
                          _verifyOtp();
                        }
                      }
                    },
                  ),
                );
              }),
            );
          },
        ),

        const SizedBox(height: 24),

        // Verify button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _loading ? null : _verifyOtp,
            style: FilledButton.styleFrom(
              backgroundColor: _verificationAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Verify & Continue',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
          ),
        ),

        const SizedBox(height: 16),

        // Resend
        _resendCooldown > 0
            ? Text(
                'Resend in ${_resendCooldown}s',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              )
            : GestureDetector(
                onTap: _loading ? null : _sendOtp,
                child: Text(
                  'Resend code',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _verificationAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // Connection error (preserved from old login)
  // ──────────────────────────────────────────────

  Widget _buildConnectionError(ThemeData theme, bool isDark) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: FzColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  size: 28,
                  color: FzColors.error,
                ),
              ),
              const SizedBox(height: 20),
              Text('Connection Error', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                appRuntime.supabaseInitError!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? FzColors.darkMuted : FzColors.lightMuted,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _retryingInit
                    ? null
                    : () async {
                        final router = GoRouter.of(context);
                        setState(() => _retryingInit = true);
                        final retry = appRuntime.retrySupabaseInitialization;
                        if (retry != null) {
                          await retry();
                        }
                        if (!mounted) return;
                        final shouldNavigate =
                            appRuntime.supabaseInitError == null;
                        setState(() => _retryingInit = false);
                        if (shouldNavigate) {
                          router.go('/splash');
                        }
                      },
                icon: _retryingInit
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
                label: Text(_retryingInit ? 'Retrying...' : 'Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhoneLoginPreset {
  const _PhoneLoginPreset({required this.example, required this.minDigits});

  final String example;
  final int minDigits;
}
