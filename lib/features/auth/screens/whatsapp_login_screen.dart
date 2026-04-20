import 'dart:async';
import 'dart:math' as math;

import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/bootstrap_config.dart';
import '../../../core/constants/phone_presets.dart';
import '../../../core/di/gateway_providers.dart';
import '../../../core/market/launch_market.dart';
import '../../../core/runtime/app_runtime_state.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/market_preferences_provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_brand_logo.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fz_wordmark.dart';

/// Accent used on the phone verification screen.
const _verificationAccent = FzColors.teal;
const _defaultPhoneCountryCode = 'MT';
const _fallbackPhonePreset = PhonePreset(
  dialCode: '+356',
  hint: '79XX XXXX',
  minDigits: 8,
);
const _priorityPhoneCountryCodes = <String>[
  'MT',
  'GB',
  'RW',
  'NG',
  'KE',
  'UG',
  'DE',
  'FR',
  'IT',
  'ES',
  'PT',
  'NL',
  'US',
  'CA',
  'MX',
];

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
  String _selectedCountryCode = _defaultPhoneCountryCode;

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

  PhonePreset get _phonePreset => _presetForCountry(_selectedCountryCode);

  String get _localDigits =>
      _phoneController.text.replaceAll(RegExp(r'\D'), '');
  bool get _isPhoneValid => _localDigits.length >= _phonePreset.minDigits;
  int get _remainingDigits =>
      math.max(0, _phonePreset.minDigits - _localDigits.length);

  String get _fullPhone {
    return '${_phonePreset.dialCode}$_localDigits';
  }

  Future<void> _sendOtp() async {
    final phone = _fullPhone;
    if (!phone.startsWith('+') || !_isPhoneValid) {
      setState(() => _error = 'Enter your WhatsApp number with country code.');
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

  PhonePreset _presetForCountry(String countryCode) {
    final preset = phonePresetForCountry(countryCode);
    if (preset != null) return preset;

    if (countryCode == _defaultPhoneCountryCode) {
      return _fallbackPhonePreset;
    }

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

  void _handleCountryChanged(CountryCode selection) {
    final code = selection.code?.toUpperCase();
    if (code == null || code.isEmpty) return;

    setState(() {
      _selectedCountryCode = code;
      _error = null;
      _reformatLocalNumber();
    });
    unawaited(HapticFeedback.selectionClick());
  }

  void _handlePhoneChanged(String value) {
    final supportedCountries = _phoneCountries(
      ref.read(bootstrapConfigProvider),
    );
    final adoptedCountry = _matchCountryFromInput(
      value,
      supportedCountries,
      fallbackCountryCode: _selectedCountryCode,
    );
    var digits = value.replaceAll(RegExp(r'\D'), '');

    if (value.trim().startsWith('+') && adoptedCountry != null) {
      final dialDigits = adoptedCountry.dialDigits;
      if (digits.startsWith(dialDigits)) {
        digits = digits.substring(dialDigits.length);
      }
    }

    final nextCountryCode = adoptedCountry?.countryCode ?? _selectedCountryCode;

    final nextPreset = adoptedCountry?.preset ?? _phonePreset;
    final maxDigits = _maxDigitsForHint(nextPreset.hint);
    if (digits.length > maxDigits) {
      digits = digits.substring(0, maxDigits);
    }

    final formatted = _formatDigits(digits, nextPreset.hint);
    if (_phoneController.text != formatted) {
      _phoneController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    if (!mounted) return;
    setState(() {
      _selectedCountryCode = nextCountryCode;
      _error = null;
    });
  }

  void _reformatLocalNumber() {
    final digits = _localDigits;
    final maxDigits = _maxDigitsForHint(_phonePreset.hint);
    final clipped = digits.length > maxDigits
        ? digits.substring(0, maxDigits)
        : digits;
    final formatted = _formatDigits(clipped, _phonePreset.hint);
    _phoneController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  int _maxDigitsForHint(String hint) {
    final groups = hint
        .split(RegExp(r'[^0-9Xx]+'))
        .where((group) => group.isNotEmpty)
        .map((group) => group.length)
        .toList(growable: false);
    if (groups.isEmpty) return math.max(_phonePreset.minDigits, 12);
    final total = groups.fold<int>(0, (sum, part) => sum + part);
    return math.max(total, _phonePreset.minDigits);
  }

  String _formatDigits(String digits, String hint) {
    if (digits.isEmpty) return '';

    final groups = hint
        .split(RegExp(r'[^0-9Xx]+'))
        .where((group) => group.isNotEmpty)
        .map((group) => group.length)
        .toList(growable: false);
    if (groups.isEmpty) return digits;

    final parts = <String>[];
    var cursor = 0;
    for (final size in groups) {
      if (cursor >= digits.length) break;
      final end = math.min(cursor + size, digits.length);
      parts.add(digits.substring(cursor, end));
      cursor = end;
    }
    if (cursor < digits.length) {
      parts.add(digits.substring(cursor));
    }

    return parts.join(' ');
  }

  _PhoneCountryOption? _matchCountryFromInput(
    String value,
    List<_PhoneCountryOption> countries, {
    required String fallbackCountryCode,
  }) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    final fallback = _countryByCode(countries, fallbackCountryCode);
    if (digits.isEmpty || !value.trimLeft().startsWith('+')) return fallback;

    final matches = [...countries]
      ..sort((a, b) => b.dialDigits.length.compareTo(a.dialDigits.length));

    for (final country in matches) {
      if (digits.startsWith(country.dialDigits)) {
        return country;
      }
    }
    return fallback;
  }

  _PhoneCountryOption? _countryByCode(
    List<_PhoneCountryOption> countries,
    String countryCode,
  ) {
    for (final country in countries) {
      if (country.countryCode == countryCode) {
        return country;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bootstrapConfig = ref.watch(bootstrapConfigProvider);
    final phoneCountries = _phoneCountries(bootstrapConfig);
    final selectedCountry = phoneCountries.firstWhere(
      (country) => country.countryCode == _selectedCountryCode,
      orElse: () => phoneCountries.firstWhere(
        (country) => country.countryCode == _defaultPhoneCountryCode,
        orElse: () => phoneCountries.first,
      ),
    );
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
                    FzWordmark(
                      textAlign: TextAlign.center,
                      style: FzTypography.display(size: 34, letterSpacing: 2.4),
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
                                phoneCountries: phoneCountries,
                                selectedCountry: selectedCountry,
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
    required List<_PhoneCountryOption> phoneCountries,
    required _PhoneCountryOption selectedCountry,
    required Color textColor,
    required Color mutedColor,
    required String? statusMessage,
    required bool authUnavailable,
  }) {
    final theme = Theme.of(context);
    final helperColor = _localDigits.isEmpty
        ? mutedColor
        : _isPhoneValid
        ? FzColors.success
        : FzColors.coral;
    final helperIcon = _localDigits.isEmpty
        ? Icons.info_outline_rounded
        : _isPhoneValid
        ? Icons.check_circle_outline_rounded
        : Icons.edit_outlined;
    final helperText = _localDigits.isEmpty
        ? '${selectedCountry.countryName} • ${selectedCountry.preset.dialCode} • e.g. ${selectedCountry.preset.hint}'
        : _isPhoneValid
        ? 'Ready to send your WhatsApp code to ${selectedCountry.countryName}.'
        : 'Add $_remainingDigits more digit${_remainingDigits == 1 ? '' : 's'} for ${selectedCountry.countryName}.';

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
                'ENTER WHATSAPP NUMBER',
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
            SizedBox(
              width: 122,
              child: CountryCodePicker(
                key: ValueKey(_selectedCountryCode),
                initialSelection: _selectedCountryCode,
                favorite: _priorityPhoneCountryCodes,
                countryFilter: phoneCountries
                    .map((country) => country.countryCode)
                    .toList(growable: false),
                onChanged: _handleCountryChanged,
                pickerStyle: PickerStyle.bottomSheet,
                hideMainText: true,
                showFlagMain: false,
                alignLeft: true,
                backgroundColor: theme.brightness == Brightness.dark
                    ? FzColors.darkSurface2
                    : FzColors.lightSurface,
                barrierColor: Colors.black.withValues(alpha: 0.35),
                searchDecoration: InputDecoration(
                  hintText: 'Search country or dial code',
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: mutedColor,
                  ),
                  filled: true,
                  fillColor: theme.brightness == Brightness.dark
                      ? FzColors.darkSurface3
                      : FzColors.lightSurface2,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
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
                      width: 1.4,
                    ),
                  ),
                ),
                searchStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: textColor,
                ),
                dialogBackgroundColor: theme.brightness == Brightness.dark
                    ? FzColors.darkSurface2
                    : FzColors.lightSurface,
                dialogTextStyle: theme.textTheme.bodyLarge?.copyWith(
                  color: textColor,
                ),
                textStyle: theme.textTheme.bodyLarge?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
                headerText: 'Select country code',
                headerTextStyle: FzTypography.display(
                  size: 24,
                  color: textColor,
                  letterSpacing: 1.2,
                ),
                closeIcon: Icon(Icons.close_rounded, color: mutedColor),
                showDropDownButton: false,
                hideCloseIcon: false,
                searchPadding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                topBarPadding: const EdgeInsets.fromLTRB(20, 18, 12, 6),
                dialogItemPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                builder: (_) => Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
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
                  child: Row(
                    children: [
                      Text(
                        selectedCountry.flagEmoji,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          selectedCountry.preset.dialCode,
                          overflow: TextOverflow.fade,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: textColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: mutedColor,
                      ),
                    ],
                  ),
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
                  hintText: selectedCountry.preset.hint,
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
                onChanged: _handlePhoneChanged,
                onFieldSubmitted: (_) {
                  if (!_loading && !authUnavailable && _isPhoneValid) {
                    unawaited(_sendOtp());
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(helperIcon, size: 16, color: helperColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                helperText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: helperColor,
                  height: 1.35,
                ),
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
          onPressed: (_loading || authUnavailable || !_isPhoneValid)
              ? null
              : _sendOtp,
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

class _PhoneCountryOption {
  const _PhoneCountryOption({
    required this.countryCode,
    required this.countryName,
    required this.flagEmoji,
    required this.preset,
  });

  final String countryCode;
  final String countryName;
  final String flagEmoji;
  final PhonePreset preset;

  String get dialDigits => preset.dialCode.replaceAll('+', '');
}

List<_PhoneCountryOption> _phoneCountries(BootstrapConfig config) {
  final configuredCodes = config.phonePresets.keys.map(
    (code) => code.toUpperCase(),
  );
  final availableCodes =
      {
        ...configuredCodes,
        ..._priorityPhoneCountryCodes,
      }.toList(growable: false)..sort((a, b) {
        final aPriority = _priorityPhoneCountryCodes.indexOf(a);
        final bPriority = _priorityPhoneCountryCodes.indexOf(b);
        if (aPriority != -1 || bPriority != -1) {
          if (aPriority == -1) return 1;
          if (bPriority == -1) return -1;
          return aPriority.compareTo(bPriority);
        }
        final aName =
            config.countryNameForCode(a) ??
            CountryCode.tryFromCountryCode(a)?.name ??
            a;
        final bName =
            config.countryNameForCode(b) ??
            CountryCode.tryFromCountryCode(b)?.name ??
            b;
        return aName.compareTo(bName);
      });

  return availableCodes
      .map((countryCode) {
        final presetInfo = config.phonePresetForCountry(countryCode);
        final preset = presetInfo != null
            ? PhonePreset.fromInfo(presetInfo)
            : (phonePresetForCountry(countryCode) ??
                  (countryCode == _defaultPhoneCountryCode
                      ? _fallbackPhonePreset
                      : phonePresetForRegion('europe')));
        final countryName =
            config.countryNameForCode(countryCode) ??
            CountryCode.tryFromCountryCode(countryCode)?.name ??
            countryCode;
        final flagEmoji = _flagEmojiForCountryCode(
          countryCode,
          fallback: config.flagEmojiForCountryCode(countryCode),
        );

        return _PhoneCountryOption(
          countryCode: countryCode,
          countryName: countryName,
          flagEmoji: flagEmoji,
          preset: preset,
        );
      })
      .toList(growable: false);
}

String _flagEmojiForCountryCode(String countryCode, {String? fallback}) {
  if (fallback != null && fallback != '🌍') return fallback;
  if (countryCode.length != 2) return '🌍';

  final upper = countryCode.toUpperCase();
  final runes = upper.codeUnits
      .map((unit) => unit + 127397)
      .toList(growable: false);
  return String.fromCharCodes(runes);
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
