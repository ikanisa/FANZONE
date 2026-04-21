import 'package:flutter/cupertino.dart';
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
import '../../../theme/radii.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';

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

  int get _phoneLength =>
      _phoneController.text.replaceAll(RegExp(r'\D'), '').length;

  bool get _canSend => !_loading && _phoneLength >= _phonePreset.minDigits;

  bool get _canVerify => !_loading && _otpLength == 6;

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? FzColors.darkBg : FzColors.lightBg;
    final surface = isDark ? FzColors.darkSurface2 : FzColors.lightSurface2;
    final surfaceAlt = isDark ? FzColors.darkSurface3 : FzColors.lightSurface3;
    final border = isDark ? FzColors.darkBorder : FzColors.lightBorder;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                24 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconButton(
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
                          style: IconButton.styleFrom(
                            backgroundColor: surfaceAlt,
                            foregroundColor: textColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: FzRadii.cardAltRadius,
                              side: BorderSide(color: border),
                            ),
                          ),
                          icon: const Icon(LucideIcons.arrowLeft, size: 18),
                        ),
                        const Spacer(),
                        Text(
                          'GUEST ACCESS',
                          style: FzTypography.metaLabel(color: muted),
                        ),
                        const Spacer(),
                        const SizedBox(width: 40),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Center(
                      child: Text(
                        'KEEP YOUR PROGRESS',
                        textAlign: TextAlign.center,
                        style: FzTypography.display(
                          size: 34,
                          color: textColor,
                          letterSpacing: 2.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Text(
                          'Verify via WhatsApp to secure your guest account, keep your picks, and unlock the full FANZONE experience.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: muted,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FzCard(
                      color: surface,
                      borderRadius: FzRadii.card,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: FzColors.whatsapp.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              LucideIcons.messageCircle,
                              color: FzColors.whatsapp,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            _view == _phoneView
                                ? 'VERIFY VIA WHATSAPP'
                                : 'ENTER OTP',
                            style: FzTypography.display(
                              size: 24,
                              color: textColor,
                              letterSpacing: 1.6,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _view == _phoneView
                                ? 'We\'ll send a 6-digit code to your WhatsApp. No names or emails required.'
                                : 'Enter the 6-digit code sent to your WhatsApp.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: muted,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (_view == _phoneView) ...[
                            Row(
                              children: [
                                Container(
                                  width: 92,
                                  height: 56,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: surfaceAlt,
                                    borderRadius: FzRadii.cardAltRadius,
                                    border: Border.all(color: border),
                                  ),
                                  child: Text(
                                    _dialCode,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          color: textColor,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _phoneController,
                                    autofocus: true,
                                    keyboardType: TextInputType.phone,
                                    onChanged: (_) {
                                      if (_error != null) {
                                        setState(() => _error = null);
                                      } else {
                                        setState(() {});
                                      }
                                    },
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    style: FzTypography.score(
                                      size: 16,
                                      color: textColor,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: _phoneHint,
                                      hintStyle: theme.textTheme.bodyLarge
                                          ?.copyWith(color: muted),
                                      filled: true,
                                      fillColor: surfaceAlt,
                                      border: OutlineInputBorder(
                                        borderRadius: FzRadii.cardAltRadius,
                                        borderSide: BorderSide(color: border),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: FzRadii.cardAltRadius,
                                        borderSide: BorderSide(color: border),
                                      ),
                                      focusedBorder: const OutlineInputBorder(
                                        borderRadius: FzRadii.cardAltRadius,
                                        borderSide: BorderSide(
                                          color: FzColors.whatsapp,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(
                                6,
                                (i) => SizedBox(
                                  width: 46,
                                  child: TextField(
                                    controller: _otpControllers[i],
                                    focusNode: _otpFocusNodes[i],
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    maxLength: 1,
                                    style: FzTypography.score(
                                      size: 22,
                                      color: textColor,
                                    ),
                                    decoration: InputDecoration(
                                      counterText: '',
                                      filled: true,
                                      fillColor: surfaceAlt,
                                      contentPadding: EdgeInsets.zero,
                                      border: OutlineInputBorder(
                                        borderRadius: FzRadii.cardAltRadius,
                                        borderSide: BorderSide(color: border),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: FzRadii.cardAltRadius,
                                        borderSide: BorderSide(color: border),
                                      ),
                                      focusedBorder: const OutlineInputBorder(
                                        borderRadius: FzRadii.cardAltRadius,
                                        borderSide: BorderSide(
                                          color: FzColors.whatsapp,
                                        ),
                                      ),
                                    ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(1),
                                    ],
                                    onChanged: (value) {
                                      if (_error != null) {
                                        setState(() => _error = null);
                                      } else {
                                        setState(() {});
                                      }
                                      if (value.isNotEmpty && i < 5) {
                                        _otpFocusNodes[i + 1].requestFocus();
                                      } else if (value.isEmpty && i > 0) {
                                        _otpFocusNodes[i - 1].requestFocus();
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            _UpgradeStatusBanner(message: _error!),
                          ],
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _view == _phoneView
                                  ? (_canSend ? _sendOtp : null)
                                  : (_canVerify ? _verifyOtp : null),
                              style: FilledButton.styleFrom(
                                backgroundColor: FzColors.whatsapp,
                                foregroundColor: const Color(0xFF1A1400),
                                disabledBackgroundColor: FzColors.darkSurface3,
                                disabledForegroundColor: muted,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: const RoundedRectangleBorder(
                                  borderRadius: FzRadii.cardAltRadius,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CupertinoActivityIndicator(
                                        color: Color(0xFF1A1400),
                                      ),
                                    )
                                  : Text(
                                      _view == _phoneView
                                          ? 'SEND CODE VIA WHATSAPP'
                                          : 'VERIFY CODE',
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: TextButton(
                              onPressed: _loading
                                  ? null
                                  : () {
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
                              child: Text(
                                _view == _phoneView
                                    ? 'Not Now'
                                    : 'Use a Different Number',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: muted,
                                ),
                              ),
                            ),
                          ),
                          if (_view == _otpView) ...[
                            const SizedBox(height: 2),
                            Center(
                              child: Text(
                                'Your number is never shown to others.',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: muted,
                                ),
                              ),
                            ),
                          ],
                        ],
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
}

class _UpgradeStatusBanner extends StatelessWidget {
  const _UpgradeStatusBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FzColors.error.withValues(alpha: 0.10),
        borderRadius: FzRadii.cardAltRadius,
        border: Border.all(color: FzColors.error.withValues(alpha: 0.24)),
      ),
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: FzColors.darkText, height: 1.4),
      ),
    );
  }
}
