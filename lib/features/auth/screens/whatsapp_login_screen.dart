import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/bootstrap_config.dart';
import '../../../core/constants/phone_presets.dart';
import '../../../core/di/gateway_providers.dart';
import '../../../core/runtime/app_runtime_state.dart';
import '../../../core/utils/phone_country_catalog.dart';
import '../../../providers/auth_provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_brand_logo.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fz_wordmark.dart';

/// Accent used on the phone verification screen.
const _verificationAccent = FzColors.whatsapp;

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
  String _selectedCountryCode = '';

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
    return preferredPhoneCountry(
      config: ref.read(bootstrapConfigProvider),
      explicitCountryCode: countryCode,
    ).preset;
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

  Future<void> _handleCountryTap(
    List<_PhoneCountryOption> phoneCountries,
    _PhoneCountryOption selectedCountry,
  ) async {
    unawaited(HapticFeedback.selectionClick());
    final picked = await _showPhoneCountryPicker(
      context,
      countries: phoneCountries,
      selected: selectedCountry,
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedCountryCode = picked.countryCode;
        _error = null;
        _reformatLocalNumber();
      });
    }
  }

  void _handlePhoneChanged(String value) {
    final bootstrapConfig = ref.read(bootstrapConfigProvider);
    final supportedCountries = _phoneCountries(bootstrapConfig);
    final adoptedCountry = resolvePhoneCountryFromPhoneInput(
      value,
      fallback:
          _countryByCode(supportedCountries, _selectedCountryCode) ??
          preferredPhoneCountry(config: bootstrapConfig),
      config: bootstrapConfig,
    );
    var digits = value.replaceAll(RegExp(r'\D'), '');

    if (value.trim().startsWith('+')) {
      final dialDigits = adoptedCountry.dialDigits;
      if (digits.startsWith(dialDigits)) {
        digits = digits.substring(dialDigits.length);
      }
    }

    final nextCountryCode = adoptedCountry.countryCode;

    final nextPreset = adoptedCountry.preset;
    final maxDigits = maxPhoneDigitsForHint(
      nextPreset.hint,
      minDigits: nextPreset.minDigits,
    );
    if (digits.length > maxDigits) {
      digits = digits.substring(0, maxDigits);
    }

    final formatted = formatPhoneDigits(digits, nextPreset.hint);
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
    final maxDigits = maxPhoneDigitsForHint(
      _phonePreset.hint,
      minDigits: _phonePreset.minDigits,
    );
    final clipped = digits.length > maxDigits
        ? digits.substring(0, maxDigits)
        : digits;
    final formatted = formatPhoneDigits(clipped, _phonePreset.hint);
    _phoneController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
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
    final selectedCountry = preferredPhoneCountry(
      config: bootstrapConfig,
      explicitCountryCode: _selectedCountryCode,
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
                          ? 'Enter the 6-digit OTP sent to your WhatsApp.'
                          : 'Verify your number to save picks, earn FET rewards, and track your record. It\'s 100% free.',
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
        ? LucideIcons.info
        : _isPhoneValid
        ? LucideIcons.checkCircle
        : LucideIcons.pencil;
    final helperText = _localDigits.isEmpty
        ? '${selectedCountry.countryName} • ${selectedCountry.preset.dialCode} • e.g. ${selectedCountry.preset.hint}'
        : _isPhoneValid
        ? 'Ready to send your WhatsApp OTP to ${selectedCountry.countryName}.'
        : 'Add $_remainingDigits more digit${_remainingDigits == 1 ? '' : 's'} for ${selectedCountry.countryName}.';

    return Column(
      key: const ValueKey('phone_step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              LucideIcons.messageCircle,
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
              child: GestureDetector(
                onTap: () => _handleCountryTap(phoneCountries, selectedCountry),
                child: Container(
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
                      Icon(LucideIcons.chevronDown, color: mutedColor),
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
              LucideIcons.messageCircle,
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

typedef _PhoneCountryOption = PhoneCountryEntry;

List<_PhoneCountryOption> _phoneCountries(BootstrapConfig config) {
  return phoneCountryCatalog(config: config);
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
            fontSize: 14,
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
          Icon(LucideIcons.info, size: 18, color: color),
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

Future<_PhoneCountryOption?> _showPhoneCountryPicker(
  BuildContext context, {
  required List<_PhoneCountryOption> countries,
  _PhoneCountryOption? selected,
}) {
  return showModalBottomSheet<_PhoneCountryOption>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) =>
        _SmartPhoneCountryPickerSheet(countries: countries, selected: selected),
  );
}

class _SmartPhoneCountryPickerSheet extends StatefulWidget {
  const _SmartPhoneCountryPickerSheet({required this.countries, this.selected});

  final List<_PhoneCountryOption> countries;
  final _PhoneCountryOption? selected;

  @override
  State<_SmartPhoneCountryPickerSheet> createState() =>
      _SmartPhoneCountryPickerSheetState();
}

class _SmartPhoneCountryPickerSheetState
    extends State<_SmartPhoneCountryPickerSheet> {
  final _searchController = TextEditingController();
  late List<_PhoneCountryOption> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.countries;
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filtered = widget.countries;
      } else {
        final scored = <MapEntry<_PhoneCountryOption, int>>[];
        for (final c in widget.countries) {
          final score = phoneCountrySearchScore(c, query);
          if (score > 0) {
            scored.add(MapEntry(c, score));
          }
        }
        scored.sort((a, b) {
          final cmp = b.value.compareTo(a.value);
          if (cmp != 0) return cmp;
          return a.key.countryName.compareTo(b.key.countryName);
        });
        _filtered = scored.map((e) => e.key).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? FzColors.darkSurface : FzColors.lightBg;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final border = isDark ? FzColors.darkBorder : FzColors.lightBorder;
    final maxHeight = MediaQuery.of(context).size.height * 0.72;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'Select Country',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: border.withValues(alpha: 0.5),
                    ),
                    child: Icon(LucideIcons.x, size: 16, color: muted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              autofocus: false,
              style: TextStyle(fontSize: 15, color: textColor),
              decoration: InputDecoration(
                hintText: 'Search country or dial code...',
                hintStyle: TextStyle(fontSize: 14, color: muted),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 14, right: 10),
                  child: Icon(LucideIcons.search, size: 18, color: muted),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 20,
                  minHeight: 20,
                ),
                filled: true,
                fillColor: isDark
                    ? FzColors.darkSurface2
                    : FzColors.lightSurface2,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
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
                  borderSide: const BorderSide(color: _verificationAccent),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _searchController.text.isEmpty
                    ? '${widget.countries.length} countries'
                    : '${_filtered.length} results',
                style: TextStyle(
                  fontSize: 10,
                  color: muted,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.searchX, size: 40, color: muted),
                          const SizedBox(height: 12),
                          Text(
                            'No countries match your search',
                            style: TextStyle(fontSize: 14, color: muted),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: _filtered.length,
                    itemBuilder: (ctx, i) {
                      final entry = _filtered[i];
                      final isSelected =
                          widget.selected?.countryCode == entry.countryCode;
                      return Material(
                        color: isSelected
                            ? _verificationAccent.withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.pop(context, entry);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 13,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  entry.flagEmoji,
                                  style: const TextStyle(fontSize: 24),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.countryName,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        entry.countryCode,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  entry.preset.dialCode,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? _verificationAccent
                                        : muted,
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 8),
                                  const Icon(
                                    LucideIcons.checkCircle2,
                                    size: 18,
                                    color: _verificationAccent,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
