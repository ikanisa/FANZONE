import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/di/gateway_providers.dart';
import '../../../core/market/launch_market.dart';
import '../../../core/runtime/app_runtime_state.dart';
import '../../../core/utils/phone_country_catalog.dart';
import '../../../data/team_search_database.dart';
import '../widgets/country_code_picker.dart';
import '../../../models/auth_and_user/user_market_preferences_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/favorite_teams_provider.dart';
import '../../../providers/market_preferences_provider.dart';
import '../../../providers/region_provider.dart';
import '../../../theme/colors.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/fan_profile_selector.dart';
import '../widgets/onboarding_phone_verification_steps.dart';
import '../widgets/onboarding_welcome_step.dart';

/// Production onboarding flow for the sports-bar product:
///
/// Step 1: Welcome
/// Step 2: Enter WhatsApp phone
/// Step 3: Verify OTP and enter the app
/// Step 4: Optional fan profile setup
///
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _welcomeStep = 0;
  static const _phoneStep = 1;
  static const _otpStep = 2;
  static const _fanProfileStep = 3;

  final _phoneController = TextEditingController();
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(6, (_) => FocusNode());

  int _currentStep = _welcomeStep;
  bool _loading = false;
  String? _error;
  late CountryEntry _selectedCountry;
  bool _completedOtpInThisSession = false;

  @override
  void initState() {
    super.initState();
    _selectedCountry = findCountryByCode(null);
    ref.read(selectedLaunchRegionProvider.notifier).state = 'global';
    ref.read(selectedLaunchFocusTagsProvider.notifier).replaceAll({});
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

  bool get _canUseOtp {
    final authService = ref.read(authServiceProvider);
    return authService.isAvailable && appRuntime.supabaseInitError == null;
  }

  bool get _isAlreadyAuthenticated {
    return ref.read(authServiceProvider).isAuthenticated;
  }

  String get _fullPhone {
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    return '${_selectedCountry.preset.dialCode}$digits';
  }

  int get _otpLength => _otpControllers.fold<int>(
    0,
    (count, controller) => count + controller.text.trim().length,
  );

  String get _localPhoneDigits =>
      _phoneController.text.replaceAll(RegExp(r'\D'), '');

  bool get _isPhoneNumberValid =>
      _localPhoneDigits.length >= _selectedCountry.preset.minDigits;

  void _setStep(int step) {
    HapticFeedback.lightImpact();
    setState(() {
      _currentStep = step;
      _error = null;
    });
  }

  void _handlePhoneChanged(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');

    final maxDigits = maxPhoneDigitsForHint(
      _selectedCountry.preset.hint,
      minDigits: _selectedCountry.preset.minDigits,
    );
    if (digits.length > maxDigits) {
      digits = digits.substring(0, maxDigits);
    }

    final formatted = formatPhoneDigits(digits, _selectedCountry.preset.hint);
    if (_phoneController.text != formatted) {
      _phoneController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    setState(() {
      _error = null;
    });
  }

  // ── Step handlers ──

  void _handleWelcomeContinue() {
    if (_isAlreadyAuthenticated) {
      _setStep(_fanProfileStep);
      return;
    }
    _setStep(_phoneStep);
  }

  Future<void> _handlePhoneContinue() async {
    if (!_canUseOtp) {
      setState(() {
        _error = appRuntime.supabaseInitError == null
            ? 'WhatsApp OTP verification is required before continuing.'
            : 'WhatsApp OTP verification is temporarily unavailable.';
      });
      return;
    }

    final phone = _fullPhone;
    if (!_isPhoneNumberValid) {
      setState(() {
        _error = 'Enter your WhatsApp number before continuing.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final sent = await ref.read(authServiceProvider).sendOtp(phone);
      if (!mounted) return;

      if (sent) {
        _setStep(_otpStep);
        _otpFocusNodes.first.requestFocus();
      } else {
        setState(() {
          _error = 'Could not send the WhatsApp OTP. Please try again.';
        });
      }
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong while sending the WhatsApp OTP.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _handleOtpContinue() async {
    if (_otpLength != 6) {
      setState(() {
        _error = 'Enter the full 6-digit WhatsApp OTP before verifying.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref
          .read(authServiceProvider)
          .verifyOtp(
            _fullPhone,
            _otpControllers.map((controller) => controller.text).join(),
          );
      if (!mounted) return;
      _completedOtpInThisSession = true;
      _setStep(_fanProfileStep);
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'WhatsApp OTP verification failed. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _handleFanProfileSave(FanProfileSelection selection) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref
          .read(onboardingGatewayProvider)
          .saveFanProfileTeams(
            localTeam: selection.localTeam,
            topEuropeanTeamIds: selection.topEuropeanTeamIds,
            nationalTeamIds: selection.nationalTeamIds,
          );
      ref.invalidate(favoriteTeamRecordsProvider);
      await _completeOnboarding();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not save your fan profile. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _completeOnboarding() async {
    final launchRegion = ref.read(selectedLaunchRegionProvider);
    final selectedTags = ref.read(selectedLaunchFocusTagsProvider);
    final focusTags = selectedTags.isEmpty
        ? defaultFocusTagsForRegion(launchRegion)
        : selectedTags.toList();

    setState(() {
      _loading = true;
      _error = null;
    });

    await ref
        .read(marketPreferencesGatewayProvider)
        .saveUserMarketPreferences(
          UserMarketPreferences(
            primaryRegion: launchRegion,
            selectedRegions: {'global', launchRegion}.toList(),
            focusEventTags: focusTags,
            followWorldCup: focusTags.any(
              (tag) => tag.contains('world-cup') || tag == 'worldcup2026',
            ),
            updatedAt: DateTime.now(),
          ),
        );

    ref.invalidate(userMarketPreferencesProvider);
    ref.invalidate(userRegionProvider);
    ref.invalidate(homeLaunchEventsProvider);

    await ref.read(cacheServiceProvider).setBool('onboarding_complete', true);
    if (!mounted) return;
    context.go(appRuntime.consumePendingAppRoute() ?? '/');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return Scaffold(
      backgroundColor: isDark ? FzColors.darkBg : FzColors.lightBg,
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  children: [
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 320),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.08, 0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: KeyedSubtree(
                          key: ValueKey(_currentStep),
                          child: _buildStep(
                            textColor: textColor,
                            muted: muted,
                            isDark: isDark,
                          ),
                        ),
                      ),
                    ),
                    if (_error != null)
                      _OnboardingInfoBanner(
                        message: _error!,
                        color: FzColors.error,
                        textColor: textColor,
                      ),
                    if (_loading)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: const LinearProgressIndicator(
                            minHeight: 2,
                            color: FzColors.primary,
                            backgroundColor: FzColors.darkBorder,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep({
    required Color textColor,
    required Color muted,
    required bool isDark,
  }) {
    switch (_currentStep) {
      // Step 1: Welcome (ref: Step1)
      case _welcomeStep:
        return OnboardingWelcomeStep(
          textColor: textColor,
          muted: muted,
          isDark: isDark,
          onNext: _handleWelcomeContinue,
        );
      // Step 2: Phone Input (ref: Step2)
      case _phoneStep:
        return OnboardingPhoneStep(
          textColor: textColor,
          muted: muted,
          isDark: isDark,
          phoneController: _phoneController,
          selectedCountry: _selectedCountry,
          onChanged: _handlePhoneChanged,
          canContinue: _loading ? false : (_canUseOtp && _isPhoneNumberValid),
          onBack: () => _setStep(_welcomeStep),
          onNext: _handlePhoneContinue,
          buttonLabel: _loading
              ? 'SENDING...'
              : (_canUseOtp ? 'SEND OTP TO WHATSAPP' : 'VERIFICATION REQUIRED'),
        );
      // Step 3: OTP Verify (ref: Step3)
      case _otpStep:
        return OnboardingOtpStep(
          textColor: textColor,
          muted: muted,
          isDark: isDark,
          otpControllers: _otpControllers,
          otpFocusNodes: _otpFocusNodes,
          onOtpChanged: () {
            setState(() {
              _error = null;
            });
          },
          canVerify: !_loading && _otpLength == 6,
          onBack: () {
            for (final controller in _otpControllers) {
              controller.clear();
            }
            _otpFocusNodes.first.requestFocus();
            _setStep(_phoneStep);
          },
          onNext: _handleOtpContinue,
          buttonLabel: _loading ? 'VERIFYING...' : 'VERIFY CODE',
        );
      case _fanProfileStep:
        return FanProfileSelector(
          gateway: ref.read(onboardingGatewayProvider),
          initialTeams:
              ref.watch(favoriteTeamRecordsProvider).valueOrNull ??
              const <FavoriteTeamRecordDto>[],
          textColor: textColor,
          muted: muted,
          isDark: isDark,
          onBack: () =>
              _setStep(_completedOtpInThisSession ? _otpStep : _welcomeStep),
          onSave: _handleFanProfileSave,
          onSkip: _completeOnboarding,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _OnboardingInfoBanner extends StatelessWidget {
  const _OnboardingInfoBanner({
    required this.message,
    required this.color,
    required this.textColor,
  });

  final String message;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Text(
          message,
          style: TextStyle(fontSize: 12, height: 1.45, color: textColor),
        ),
      ),
    );
  }
}
