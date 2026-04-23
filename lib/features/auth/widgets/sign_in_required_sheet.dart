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
  String? _anonymousUserId;
  String? _anonymousUpgradeClaim;

  @override
  void initState() {
    super.initState();
    final authService = ref.read(authServiceProvider);
    if (authService.isAnonymousUser) {
      _anonymousUserId = authService.currentUser?.id;
      unawaited(_prepareAnonymousUpgradeClaim());
    }
  }

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

  PhonePreset get _phonePreset =>
      preferredPhoneCountry(config: ref.read(bootstrapConfigProvider)).preset;

  String get _fullPhone {
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    return '${_phonePreset.dialCode}$digits';
  }

  int get _phoneLength =>
      _phoneController.text.replaceAll(RegExp(r'\D'), '').length;

  int get _otpLength => _otpControllers.fold<int>(
    0,
    (count, controller) => count + controller.text.length,
  );

  Future<void> _prepareAnonymousUpgradeClaim() async {
    try {
      final claim = await ref
          .read(authServiceProvider)
          .issueAnonymousUpgradeClaim();
      if (!mounted) return;
      setState(() => _anonymousUpgradeClaim = claim);
    } catch (_) {
      // Keep the modal usable even if the merge-prep call fails.
    }
  }

  Future<void> _continueAsGuest() async {
    final authService = ref.read(authServiceProvider);
    if (authService.currentUser == null) {
      setState(() {
        _loading = true;
        _error = null;
      });
      try {
        await authService.signInAnonymously();
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _error = 'Could not continue as guest right now. Please try again.';
          _loading = false;
        });
        return;
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _sendOtp() async {
    if (_phoneLength < _phonePreset.minDigits) {
      setState(() => _error = 'Enter your WhatsApp number.');
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

      final authService = ref.read(authServiceProvider);
      final newUserId = authService.currentUser?.id;
      if (_anonymousUserId != null &&
          _anonymousUpgradeClaim != null &&
          newUserId != null &&
          _anonymousUserId != newUserId) {
        await authService.mergeAnonymousToAuthenticated(
          _anonymousUserId!,
          _anonymousUpgradeClaim!,
        );
      }

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

  @override
  Widget build(BuildContext context) {
    ref.watch(bootstrapConfigProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? FzColors.darkSurface2 : FzColors.lightSurface2;
    final surface = isDark ? FzColors.darkSurface3 : FzColors.lightSurface3;
    final border = isDark ? FzColors.darkBorder : FzColors.lightBorder;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final canSend = !_loading && _phoneLength >= _phonePreset.minDigits;
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
              Text(
                _step == _AuthSheetStep.phone
                    ? 'VERIFY VIA WHATSAPP'
                    : 'ENTER OTP',
                style: FzTypography.display(
                  size: 20,
                  color: textColor,
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _step == _AuthSheetStep.phone
                ? (widget.message.isNotEmpty
                      ? widget.message
                      : 'Verify your number to save picks, earn FET rewards, and track your record. It\'s 100% free.')
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
                          Container(
                            width: 92,
                            height: 56,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: border),
                            ),
                            child: Text(
                              _phonePreset.dialCode,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                                fontFamily: FzTypography.score(
                                  size: 16,
                                  color: textColor,
                                ).fontFamily,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _phoneController,
                              autofocus: true,
                              keyboardType: TextInputType.phone,
                              onChanged: (value) {
                                var digits = value.replaceAll(
                                  RegExp(r'\D'),
                                  '',
                                );
                                final maxDigits = maxPhoneDigitsForHint(
                                  _phonePreset.hint,
                                  minDigits: _phonePreset.minDigits,
                                );
                                if (digits.length > maxDigits) {
                                  digits = digits.substring(0, maxDigits);
                                }

                                final formatted = formatPhoneDigits(
                                  digits,
                                  _phonePreset.hint,
                                );
                                if (_phoneController.text != formatted) {
                                  _phoneController.value = TextEditingValue(
                                    text: formatted,
                                    selection: TextSelection.collapsed(
                                      offset: formatted.length,
                                    ),
                                  );
                                }

                                setState(() => _error = null);
                              },
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9\s]'),
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
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton(
                          onPressed: _loading ? null : _continueAsGuest,
                          child: Text(
                            'Continue as Guest',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: muted,
                            ),
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
                          style: TextStyle(fontSize: 11, color: muted),
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
