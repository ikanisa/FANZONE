import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/phone_presets.dart';
import '../../../core/di/gateway_providers.dart';
import '../../../core/utils/phone_country_catalog.dart';
import '../../../providers/auth_provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../theme/typography.dart';
import '../../onboarding/widgets/country_code_picker.dart';

Future<void> showSignInRequiredSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String from,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _SignInRequiredSheet(title: title, message: message, from: from),
  );
}

enum _AuthSheetStep { phone, otp }

class _SignInRequiredSheet extends ConsumerStatefulWidget {
  const _SignInRequiredSheet({
    required this.title,
    required this.message,
    required this.from,
  });

  final String title;
  final String message;
  final String from;

  @override
  ConsumerState<_SignInRequiredSheet> createState() =>
      _SignInRequiredSheetState();
}

class _SignInRequiredSheetState extends ConsumerState<_SignInRequiredSheet> {
  final _phoneController = TextEditingController();
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(6, (_) => FocusNode());

  _AuthSheetStep _step = _AuthSheetStep.phone;
  bool _loading = false;
  String? _error;
  String _selectedCountryCode = '';

  @override
  void dispose() {
    _phoneController.dispose();
    for (final controller in _otpControllers) {
      controller.dispose();
    }
    for (final focusNode in _otpFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  PhoneCountryEntry get _selectedCountry => preferredPhoneCountry(
    config: ref.read(bootstrapConfigProvider),
    explicitCountryCode: _selectedCountryCode,
  );

  PhonePreset get _phonePreset => _selectedCountry.preset;

  String get _localDigits =>
      _phoneController.text.replaceAll(RegExp(r'\D'), '');

  int get _maxDigits => maxPhoneDigitsForHint(
    _phonePreset.hint,
    minDigits: _phonePreset.minDigits,
  );

  bool get _isGenericPhoneCountry =>
      _selectedCountry.countryCode == 'INTL' || _phonePreset.dialCode == '+';

  bool get _isPhoneValid {
    final length = _localDigits.length;
    if (length < _phonePreset.minDigits) return false;
    if (_isGenericPhoneCountry) return length <= 15;
    return length == _maxDigits;
  }

  String get _fullPhone {
    if (_localDigits.isEmpty) return '';
    return '${_phonePreset.dialCode}$_localDigits';
  }

  int get _otpLength => _otpControllers.fold<int>(
    0,
    (count, controller) => count + controller.text.length,
  );

  Future<void> _sendOtp() async {
    if (!_isPhoneValid) {
      setState(() => _error = 'Enter a valid WhatsApp number.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(authServiceProvider).sendOtp(_fullPhone);
      if (!mounted) return;
      unawaited(HapticFeedback.lightImpact());
      setState(() => _step = _AuthSheetStep.otp);
      _otpFocusNodes.first.requestFocus();
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not send the WhatsApp OTP.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpLength != 6) {
      setState(() => _error = 'Enter the full 6-digit code.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final otp = _otpControllers.map((controller) => controller.text).join();
      await ref.read(authServiceProvider).verifyOtp(_fullPhone, otp);

      if (!mounted) return;
      Navigator.of(context).pop();
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'WhatsApp OTP verification failed.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pickCountry() async {
    final picked = await showCountryCodePicker(
      context,
      selected: _selectedCountry,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedCountryCode = picked.countryCode;
      _error = null;
      _reformatPhoneForPreset(picked.preset);
    });
  }

  void _handlePhoneChanged(String value) {
    final config = ref.read(bootstrapConfigProvider);
    final resolved = resolvePhoneCountryFromPhoneInput(
      value,
      fallback: _selectedCountry,
      config: config,
    );
    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (value.trimLeft().startsWith('+')) {
      final dialDigits = resolved.dialDigits;
      if (dialDigits.isNotEmpty && digits.startsWith(dialDigits)) {
        digits = digits.substring(dialDigits.length);
      }
    }

    final maxDigits = maxPhoneDigitsForHint(
      resolved.preset.hint,
      minDigits: resolved.preset.minDigits,
    );
    if (digits.length > maxDigits) digits = digits.substring(0, maxDigits);

    final formatted = formatPhoneDigits(digits, resolved.preset.hint);
    if (_phoneController.text != formatted) {
      _phoneController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    setState(() {
      _selectedCountryCode = resolved.countryCode;
      _error = null;
    });
  }

  void _reformatPhoneForPreset(PhonePreset preset) {
    var digits = _localDigits;
    final maxDigits = maxPhoneDigitsForHint(
      preset.hint,
      minDigits: preset.minDigits,
    );
    if (digits.length > maxDigits) digits = digits.substring(0, maxDigits);
    final formatted = formatPhoneDigits(digits, preset.hint);
    _phoneController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String get _phoneHelpText {
    if (_localDigits.isEmpty) {
      return '${_selectedCountry.countryName} ${_phonePreset.dialCode} · ${_phonePreset.hint}';
    }
    if (_isPhoneValid) return 'Ready.';
    if (_localDigits.length < _phonePreset.minDigits) {
      final remaining = _phonePreset.minDigits - _localDigits.length;
      return '$remaining more digit${remaining == 1 ? '' : 's'}.';
    }
    if (_isGenericPhoneCountry) return 'Use 7 to 15 digits.';
    return '${_selectedCountry.countryName} numbers use $_maxDigits digits.';
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(bootstrapConfigProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? FzColors.darkSurface2 : FzColors.lightSurface2;
    final surface = isDark ? FzColors.darkSurface3 : FzColors.lightSurface3;
    final border = isDark ? FzColors.darkBorder : FzColors.lightBorder;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final canSend = !_loading && _isPhoneValid;
    final canVerify = !_loading && _otpLength == 6;

    return Container(
      constraints: const BoxConstraints(maxWidth: 440),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: FzRadii.bottomSheetRadius,
        border: Border(top: BorderSide(color: border)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        14,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  margin: const EdgeInsets.only(left: 48),
                  decoration: BoxDecoration(
                    color: muted.withValues(alpha: 0.34),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _loading
                    ? null
                    : () {
                        if (_step == _AuthSheetStep.otp) {
                          setState(() {
                            _step = _AuthSheetStep.phone;
                            _error = null;
                            for (final controller in _otpControllers) {
                              controller.clear();
                            }
                          });
                          return;
                        }
                        Navigator.of(context).pop();
                      },
                icon: const Icon(LucideIcons.x, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: surface,
                  foregroundColor: muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                LucideIcons.messageCircle,
                size: 24,
                color: Color(0xFF25D366),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _step == _AuthSheetStep.phone
                      ? 'VERIFY VIA WHATSAPP'
                      : 'ENTER OTP',
                  style: FzTypography.display(
                    size: 20,
                    color: textColor,
                    letterSpacing: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _step == _AuthSheetStep.phone
                ? (widget.message.isNotEmpty
                      ? widget.message
                      : 'Verify your number to keep your wallet, orders, and match pools secured. It\'s 100% free.')
                : 'Enter the 6-digit code sent to your WhatsApp.',
            style: TextStyle(fontSize: 14, color: muted, height: 1.5),
          ),
          if (widget.title.isNotEmpty && _step == _AuthSheetStep.phone) ...[
            const SizedBox(height: 8),
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textColor.withValues(alpha: 0.72),
              ),
            ),
          ],
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.06, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: _step == _AuthSheetStep.phone
                ? Column(
                    key: const ValueKey('phone-step'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          InkWell(
                            onTap: _loading ? null : _pickCountry,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 92,
                              height: 56,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: border),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _selectedCountry.flagEmoji,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _phonePreset.dialCode,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: textColor,
                                        fontFamily: FzTypography.score(
                                          size: 16,
                                          color: textColor,
                                        ).fontFamily,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _phoneController,
                              autofocus: true,
                              keyboardType: TextInputType.phone,
                              onChanged: _handlePhoneChanged,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9+\s-]'),
                                ),
                              ],
                              style: FzTypography.score(
                                size: 16,
                                color: textColor,
                              ),
                              decoration: InputDecoration(
                                hintText: _phonePreset.hint,
                                hintStyle: TextStyle(color: muted),
                                filled: true,
                                fillColor: surface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF25D366),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _phoneHelpText,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: _isPhoneValid || _localDigits.isEmpty
                              ? muted
                              : FzColors.coral,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: canSend ? _sendOtp : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: const Color(0xFF1A1400),
                            disabledBackgroundColor: surface,
                            disabledForegroundColor: muted,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: Text(
                            _loading ? 'SENDING...' : 'SEND CODE VIA WHATSAPP',
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    key: const ValueKey('otp-step'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(
                          6,
                          (index) => SizedBox(
                            width: 46,
                            child: TextField(
                              controller: _otpControllers[index],
                              focusNode: _otpFocusNodes[index],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              onChanged: (value) {
                                if (_error != null) {
                                  setState(() => _error = null);
                                } else {
                                  setState(() {});
                                }
                                if (value.isNotEmpty && index < 5) {
                                  _otpFocusNodes[index + 1].requestFocus();
                                } else if (value.isEmpty && index > 0) {
                                  _otpFocusNodes[index - 1].requestFocus();
                                }
                              },
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(1),
                              ],
                              style: FzTypography.score(
                                size: 22,
                                color: textColor,
                              ),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: surface,
                                contentPadding: EdgeInsets.zero,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF25D366),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: canVerify ? _verifyOtp : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: const Color(0xFF1A1400),
                            disabledBackgroundColor: surface,
                            disabledForegroundColor: muted,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: Text(
                            _loading ? 'VERIFYING...' : 'VERIFY CODE',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'Your number is never shown to others.',
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                      ),
                    ],
                  ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FzColors.error.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: FzColors.error.withValues(alpha: 0.24),
                ),
              ),
              child: Text(
                _error!,
                style: TextStyle(fontSize: 12, color: textColor, height: 1.4),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
