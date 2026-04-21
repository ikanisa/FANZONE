import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/di/gateway_providers.dart';
import '../../../core/market/launch_market.dart';
import '../../../core/runtime/app_runtime_state.dart';
import '../widgets/country_code_picker.dart';
import '../../../data/team_search_database.dart';
import '../../../models/user_market_preferences_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/market_preferences_provider.dart';
import '../../../providers/region_provider.dart';
import '../../../theme/colors.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_phone_verification_steps.dart';
import '../widgets/onboarding_team_selection_steps.dart';
import '../widgets/onboarding_welcome_step.dart';

/// Production onboarding flow — matches the reference Onboarding.tsx exactly:
///
/// Step 1: Welcome — FANZONE branding + GET STARTED
/// Step 2: Enter Phone — phone input + SEND OTP
/// Step 3: Verify OTP — 6-digit code + VERIFY
/// Step 4: Favorite Team — anonymous Fan ID + optional team + enter app
///
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  // Reference-aligned step indices (matches Onboarding.tsx steps 1–4)
  static const _welcomeStep = 0; // Step 1
  static const _phoneStep = 1; // Step 2
  static const _otpStep = 2; // Step 3
  static const _favoriteTeamStep = 3; // Step 4

  final _phoneController = TextEditingController();
  final _favoriteSearchController = TextEditingController();
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(6, (_) => FocusNode());

  int _currentStep = _welcomeStep;
  bool _loading = false;
  String? _error;
  late CountryEntry _selectedCountry;

  @override
  void initState() {
    super.initState();
    _selectedCountry = findCountryByCode('RW');
    ref.read(selectedLaunchRegionProvider.notifier).state = 'global';
    ref.read(selectedLaunchFocusTagsProvider.notifier).replaceAll({});
    ref.read(localTeamSearchQueryProvider.notifier).state = '';
    ref.read(selectedLocalTeamProvider.notifier).state = null;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _favoriteSearchController.dispose();
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
    return '${_selectedCountry.dialCode}$digits';
  }

  int get _otpLength => _otpControllers.fold<int>(
    0,
    (count, controller) => count + controller.text.trim().length,
  );

  String get _localPhoneDigits =>
      _phoneController.text.replaceAll(RegExp(r'\D'), '');

  bool get _isPhoneNumberValid =>
      _localPhoneDigits.length >= _selectedCountry.minDigits;

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
      _selectedCountry.hint,
      minDigits: _selectedCountry.minDigits,
    );
    if (digits.length > maxDigits) {
      digits = digits.substring(0, maxDigits);
    }

    final formatted = formatPhoneDigits(digits, _selectedCountry.hint);
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
      // Already authenticated — skip to team selection (step 4)
      _setStep(_favoriteTeamStep);
      return;
    }
    // Go to phone input (step 2) — matches reference Step1 → Step2
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
      _setStep(_favoriteTeamStep);
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

  void _handleFavoriteSearchChanged(String value) {
    ref.read(localTeamSearchQueryProvider.notifier).state = value;
    if (_error != null) {
      setState(() => _error = null);
    }
  }

  void _handleFavoriteTeamSelected(OnboardingTeam team) {
    HapticFeedback.selectionClick();
    ref.read(selectedLocalTeamProvider.notifier).state = team;
    _favoriteSearchController.clear();
    ref.read(localTeamSearchQueryProvider.notifier).state = '';
  }

  void _goBackFromFavoriteTeam() {
    if (_isAlreadyAuthenticated) {
      _setStep(_welcomeStep);
      return;
    }
    _setStep(_otpStep);
  }

  Future<void> _completeOnboarding() async {
    final localTeam = ref.read(selectedLocalTeamProvider);
    final launchRegion = ref.read(selectedLaunchRegionProvider);
    final selectedTags = ref.read(selectedLaunchFocusTagsProvider);
    final focusTags = selectedTags.isEmpty
        ? defaultFocusTagsForRegion(launchRegion)
        : selectedTags.toList();

    await ref
        .read(onboardingGatewayProvider)
        .saveOnboardingTeams(
          localTeam: localTeam,
          popularTeamIds: const <String>{},
        );
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
            followChampionsLeague: focusTags.contains('ucl-final-2026'),
            updatedAt: DateTime.now(),
          ),
        );

    ref.invalidate(userMarketPreferencesProvider);
    ref.invalidate(userRegionProvider);
    ref.invalidate(homeLaunchEventsProvider);
    ref.invalidate(spotlightChallengesProvider);

    await ref.read(cacheServiceProvider).setBool('onboarding_complete', true);
    if (!mounted) return;
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final suggestedTeams = allTeams
        .where(
          (team) => const {
            'APR FC',
            'Rayon Sports',
            'Arsenal',
            'Real Madrid',
          }.contains(team.name),
        )
        .take(4)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: isDark ? FzColors.darkBg : FzColors.lightBg,
      body: Stack(
        children: [
          // Background glow — matches reference
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    FzColors.primary.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            right: -90,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    FzColors.coral.withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
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
                            suggestedTeams: suggestedTeams,
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
    required List<OnboardingTeam> suggestedTeams,
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
      // Step 4: Favorite Team (ref: Step4)
      case _favoriteTeamStep:
        return OnboardingFavoriteTeamStep(
          textColor: textColor,
          muted: muted,
          isDark: isDark,
          searchController: _favoriteSearchController,
          results: ref.watch(localTeamSearchResultsProvider),
          selectedTeam: ref.watch(selectedLocalTeamProvider),
          query: ref.watch(localTeamSearchQueryProvider),
          suggestedTeams: suggestedTeams,
          onSearchChanged: _handleFavoriteSearchChanged,
          onTeamSelected: _handleFavoriteTeamSelected,
          onBack: _goBackFromFavoriteTeam,
          onNext: _completeOnboarding,
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
