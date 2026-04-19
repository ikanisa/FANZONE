import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/di/gateway_providers.dart';
import '../../../core/constants/phone_presets.dart';
import '../../../core/market/launch_market.dart';
import '../../../core/runtime/app_runtime_state.dart';
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

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _welcomeStep = 0;
  static const _phoneStep = 1;
  static const _otpStep = 2;
  static const _favoriteTeamStep = 3;
  static const _popularTeamsStep = 4;

  final _phoneController = TextEditingController();
  final _favoriteSearchController = TextEditingController();
  final _popularSearchController = TextEditingController();
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(6, (_) => FocusNode());

  int _currentStep = _welcomeStep;
  bool _loading = false;
  bool _otpSent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    ref.read(selectedLaunchRegionProvider.notifier).state = 'europe';
    ref.read(selectedLaunchFocusTagsProvider.notifier).replaceAll({});
    ref.read(localTeamSearchQueryProvider.notifier).state = '';
    ref.read(popularTeamSearchQueryProvider.notifier).state = '';
    ref.read(selectedLocalTeamProvider.notifier).state = null;
    ref.read(selectedPopularTeamProvider.notifier).state = null;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _favoriteSearchController.dispose();
    _popularSearchController.dispose();
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
    return authService.isAvailable &&
        !authService.isAuthenticated &&
        appRuntime.supabaseInitError == null;
  }

  bool get _isAlreadyAuthenticated {
    return ref.read(authServiceProvider).isAuthenticated;
  }

  PhonePreset get _phonePreset => _resolvePhonePreset();

  String get _dialCode => _phonePreset.dialCode;

  String get _phoneHint => _phonePreset.hint;

  String get _fullPhone {
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    return '$_dialCode$digits';
  }

  int get _otpLength => _otpControllers.fold<int>(
    0,
    (count, controller) => count + controller.text.trim().length,
  );

  void _setStep(int step) {
    HapticFeedback.lightImpact();
    setState(() {
      _currentStep = step;
      _error = null;
    });
  }

  void _handleWelcomeContinue() {
    if (_isAlreadyAuthenticated) {
      _setStep(_favoriteTeamStep);
      return;
    }
    _setStep(_phoneStep);
  }

  Future<void> _handlePhoneContinue() async {
    if (!_canUseOtp) {
      setState(() {
        _error = appRuntime.supabaseInitError == null
            ? 'Phone verification is required before continuing.'
            : 'Phone verification is temporarily unavailable. Retry when the auth service reconnects.';
      });
      return;
    }

    final phone = _fullPhone;
    if (_phoneController.text.replaceAll(RegExp(r'\D'), '').length <
        _phonePreset.minDigits) {
      setState(() {
        _error = 'Enter your mobile number before continuing.';
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
        _otpSent = true;
        _setStep(_otpStep);
        _otpFocusNodes.first.requestFocus();
      } else {
        setState(() {
          _error = 'Could not send the verification code. Please try again.';
        });
      }
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong while sending the verification code.';
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
        _error = 'Enter the full 6-digit code before verifying.';
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
        _error = 'Verification failed. Please try again.';
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

  void _handlePopularSearchChanged(String value) {
    ref.read(popularTeamSearchQueryProvider.notifier).state = value;
  }

  void _handlePopularTeamSelected(OnboardingTeam team) {
    HapticFeedback.selectionClick();
    ref.read(selectedPopularTeamProvider.notifier).state = team;
    _popularSearchController.clear();
    ref.read(popularTeamSearchQueryProvider.notifier).state = '';
  }

  void _goBackFromFavoriteTeam() {
    if (_otpSent) {
      _setStep(_otpStep);
      return;
    }
    if (_isAlreadyAuthenticated) {
      _setStep(_welcomeStep);
      return;
    }
    _setStep(_phoneStep);
  }

  Future<void> _completeOnboarding() async {
    final localTeam = ref.read(selectedLocalTeamProvider);
    final popularTeam = ref.read(selectedPopularTeamProvider);
    final popularTeamIds = <String>{if (popularTeam != null) popularTeam.id};
    if (localTeam != null) {
      popularTeamIds.remove(localTeam.id);
    }

    final launchRegion = ref.read(selectedLaunchRegionProvider);
    final selectedTags = ref.read(selectedLaunchFocusTagsProvider);
    final focusTags = selectedTags.isEmpty
        ? defaultFocusTagsForRegion(launchRegion)
        : selectedTags.toList();

    await ref.read(onboardingGatewayProvider).saveOnboardingTeams(
      localTeam: localTeam,
      popularTeamIds: popularTeamIds,
    );
    await ref.read(marketPreferencesGatewayProvider).saveUserMarketPreferences(
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
    final popularTeams = popularTeamsForRegion(
      ref.watch(selectedLaunchRegionProvider),
    );

    return Scaffold(
      backgroundColor: isDark ? FzColors.darkBg : FzColors.lightBg,
      body: Stack(
        children: [
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
                    FzColors.accent.withValues(alpha: 0.18),
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
                            popularTeams: popularTeams,
                          ),
                        ),
                      ),
                    ),
                    if (_currentStep == _phoneStep && !_canUseOtp)
                      _OnboardingInfoBanner(
                        message:
                            'Phone verification is required to complete onboarding. The current session cannot reach the auth service, so this flow stays locked until verification is available.',
                        color: FzColors.accent,
                        textColor: textColor,
                      ),
                    if (_error != null)
                      _OnboardingInfoBanner(
                        message: _error!,
                        color: FzColors.error,
                        textColor: textColor,
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
    required List<OnboardingTeam> popularTeams,
  }) {
    switch (_currentStep) {
      case _welcomeStep:
        return OnboardingWelcomeStep(
          textColor: textColor,
          muted: muted,
          isDark: isDark,
          onNext: _handleWelcomeContinue,
        );
      case _phoneStep:
        return OnboardingPhoneStep(
          textColor: textColor,
          muted: muted,
          isDark: isDark,
          phoneController: _phoneController,
          onChanged: (_) {
            if (_error != null) {
              setState(() => _error = null);
            }
          },
          canContinue: _loading
              ? false
              : (_canUseOtp &&
                    _phoneController.text
                            .replaceAll(RegExp(r'\D'), '')
                            .length >=
                        _phonePreset.minDigits),
          onBack: () => _setStep(_welcomeStep),
          onNext: _handlePhoneContinue,
          countryCode: _dialCode,
          phoneHint: _phoneHint,
          buttonLabel: _loading
              ? 'SENDING...'
              : (_canUseOtp
                    ? 'SEND CODE VIA WHATSAPP'
                    : 'VERIFICATION REQUIRED'),
        );
      case _otpStep:
        return OnboardingOtpStep(
          textColor: textColor,
          muted: muted,
          isDark: isDark,
          otpControllers: _otpControllers,
          otpFocusNodes: _otpFocusNodes,
          onOtpChanged: () {
            if (_error != null) {
              setState(() => _error = null);
            }
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
          buttonLabel: _loading ? 'VERIFYING...' : 'VERIFY',
        );
      case _favoriteTeamStep:
        return OnboardingFavoriteTeamStep(
          textColor: textColor,
          muted: muted,
          isDark: isDark,
          searchController: _favoriteSearchController,
          results: ref.watch(localTeamSearchResultsProvider),
          selectedTeam: ref.watch(selectedLocalTeamProvider),
          query: ref.watch(localTeamSearchQueryProvider),
          onSearchChanged: _handleFavoriteSearchChanged,
          onTeamSelected: _handleFavoriteTeamSelected,
          onBack: _goBackFromFavoriteTeam,
          onNext: () => _setStep(_popularTeamsStep),
        );
      case _popularTeamsStep:
        return OnboardingPopularTeamsStep(
          textColor: textColor,
          muted: muted,
          isDark: isDark,
          searchController: _popularSearchController,
          query: ref.watch(popularTeamSearchQueryProvider),
          searchResults: ref.watch(popularTeamSearchResultsProvider),
          popularTeams: popularTeams,
          selectedTeam: ref.watch(selectedPopularTeamProvider),
          onSearchChanged: _handlePopularSearchChanged,
          onSelectTeam: _handlePopularTeamSelected,
          onBack: () => _setStep(_favoriteTeamStep),
          onFinish: _completeOnboarding,
        );
      default:
        return const SizedBox.shrink();
    }
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

    final selectedRegion = normalizeRegionKey(
      ref.read(selectedLaunchRegionProvider),
    );
    return phonePresetForRegion(selectedRegion);
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
