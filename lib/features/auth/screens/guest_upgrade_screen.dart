import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/phone_presets.dart';
import '../../../providers/auth_provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';

/// Screen for upgrading a guest/anonymous user to a fully authenticated user
/// via WhatsApp OTP verification. Reuses the same WhatsApp Cloud API pipeline.
class GuestUpgradeScreen extends ConsumerStatefulWidget {
  const GuestUpgradeScreen({super.key, this.returnTo});

  /// Route to return to after successful upgrade. If null, pops the screen.
  final String? returnTo;

  @override
  ConsumerState<GuestUpgradeScreen> createState() => _GuestUpgradeScreenState();
}

class _GuestUpgradeScreenState extends ConsumerState<GuestUpgradeScreen> {
  static const _phoneView = 0;
  static const _otpView = 1;

  final _phoneController = TextEditingController();
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(6, (_) => FocusNode());

  int _view = _phoneView;
  bool _loading = false;
  String? _error;
  String? _anonymousUserId;
  String? _anonymousUpgradeClaim;

  @override
  void initState() {
    super.initState();
    // Capture the current anonymous user ID before upgrade
    _anonymousUserId = ref.read(authServiceProvider).currentUser?.id;
    unawaited(_prepareAnonymousUpgradeClaim());
  }

  @override
  void dispose() {
    _phoneController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  PhonePreset get _phonePreset {
    final localeCountry = WidgetsBinding
        .instance
        .platformDispatcher
        .locale
        .countryCode
        ?.toUpperCase();
    final preset = phonePresetForCountry(localeCountry);
    if (preset != null) return preset;
    return phonePresetForRegion('europe');
  }

  String get _dialCode => _phonePreset.dialCode;
  String get _phoneHint => _phonePreset.hint;

  String get _fullPhone {
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    return '$_dialCode$digits';
  }

  int get _otpLength =>
      _otpControllers.fold<int>(0, (count, c) => count + c.text.trim().length);

  Future<void> _prepareAnonymousUpgradeClaim() async {
    if (_anonymousUserId == null) return;
    try {
      _anonymousUpgradeClaim = await ref
          .read(authServiceProvider)
          .issueAnonymousUpgradeClaim();
    } catch (_) {
      // Keep the upgrade flow usable; merge will simply be skipped if the
      // server-side claim could not be created.
    }
  }

  Future<void> _sendOtp() async {
    if (_anonymousUpgradeClaim == null && _anonymousUserId != null) {
      await _prepareAnonymousUpgradeClaim();
    }

    final phone = _fullPhone;
    if (_phoneController.text.replaceAll(RegExp(r'\D'), '').length <
        _phonePreset.minDigits) {
      setState(() => _error = 'Enter your mobile number.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(authServiceProvider).sendOtp(phone);
      if (!mounted) return;
      unawaited(HapticFeedback.lightImpact());
      setState(() {
        _view = _otpView;
        _error = null;
      });
      _otpFocusNodes.first.requestFocus();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not send verification code.');
    } finally {
      if (mounted) setState(() => _loading = false);
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
      final otp = _otpControllers.map((c) => c.text).join();
      await ref.read(authServiceProvider).verifyOtp(_fullPhone, otp);

      // Merge anonymous data to the new authenticated user
      final newUserId = ref.read(authServiceProvider).currentUser?.id;
      if (_anonymousUserId != null &&
          _anonymousUpgradeClaim != null &&
          newUserId != null &&
          _anonymousUserId != newUserId) {
        await ref
            .read(authServiceProvider)
            .mergeAnonymousToAuthenticated(
              _anonymousUserId!,
              _anonymousUpgradeClaim!,
            );
      }

      if (!mounted) return;

      // Navigate back
      if (widget.returnTo != null) {
        context.go(widget.returnTo!);
      } else {
        context.pop();
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Verification failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? FzColors.darkBg : FzColors.lightBg;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: textColor, size: 20),
          onPressed: () {
            if (_view == _otpView) {
              setState(() {
                _view = _phoneView;
                _error = null;
                for (final c in _otpControllers) {
                  c.clear();
                }
              });
            } else {
              context.pop();
            }
          },
        ),
        title: Text(
          'Verify Account',
          style: FzTypography.display(size: 18, color: textColor),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),

              // Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  LucideIcons.messageCircle,
                  color: Color(0xFF25D366),
                  size: 24,
                ),
              ),
              const SizedBox(height: 20),

              Text(
                _view == _phoneView
                    ? 'Verify with WhatsApp'
                    : 'Enter verification code',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _view == _phoneView
                    ? 'We\'ll send a 6-digit code to your WhatsApp to verify your identity and unlock all features.'
                    : 'Enter the 6-digit code sent to your WhatsApp at $_fullPhone',
                style: TextStyle(fontSize: 13, color: muted, height: 1.5),
              ),

              const SizedBox(height: 32),

              if (_view == _phoneView) ...[
                // Phone input
                Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? FzColors.darkSurface
                        : FzColors.lightSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? FzColors.darkBorder
                          : FzColors.lightBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text(
                          _dialCode,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 24,
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        color: isDark
                            ? FzColors.darkBorder
                            : FzColors.lightBorder,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: TextStyle(fontSize: 16, color: textColor),
                          decoration: InputDecoration(
                            hintText: _phoneHint,
                            hintStyle: TextStyle(color: muted),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 16,
                            ),
                          ),
                          onChanged: (_) {
                            if (_error != null) {
                              setState(() => _error = null);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // OTP input
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(6, (i) {
                    return SizedBox(
                      width: 46,
                      height: 54,
                      child: TextField(
                        controller: _otpControllers[i],
                        focusNode: _otpFocusNodes[i],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: isDark
                              ? FzColors.darkSurface
                              : FzColors.lightSurface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? FzColors.darkBorder
                                  : FzColors.lightBorder,
                            ),
                          ),
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
                              color: FzColors.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (value) {
                          if (value.isNotEmpty && i < 5) {
                            _otpFocusNodes[i + 1].requestFocus();
                          }
                          if (_error != null) {
                            setState(() => _error = null);
                          }
                        },
                      ),
                    );
                  }),
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: FzColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(fontSize: 12, color: FzColors.error),
                  ),
                ),
              ],

              const Spacer(flex: 2),

              // Action button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading
                      ? null
                      : (_view == _phoneView ? _sendOtp : _verifyOtp),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(
                      0xFF25D366,
                    ).withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _view == _phoneView
                              ? 'SEND CODE VIA WHATSAPP'
                              : 'VERIFY',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
