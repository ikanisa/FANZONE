import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/cache/cache_service.dart';
import '../../../core/di/injection.dart';
import '../../../core/market/launch_market.dart';
import '../../../data/team_search_database.dart';
import '../../../main.dart' show supabaseInitError;
import '../../../models/user_market_preferences_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/market_preferences_provider.dart';
import '../../../providers/region_provider.dart';
import '../../../services/market_preferences_service.dart';
import '../../../theme/colors.dart';
import '../providers/onboarding_provider.dart';
import '../providers/onboarding_service.dart';
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
    ref.read(selectedPopularTeamsProvider.notifier).clear();
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
        supabaseInitError == null;
  }

  bool get _isAlreadyAuthenticated {
    return ref.read(authServiceProvider).isAuthenticated;
  }

  String get _dialCode => '+356';

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
      _setStep(_favoriteTeamStep);
      return;
    }

    final phone = _fullPhone;
    if (phone.length < 8) {
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
    _favoriteSearchController.text = team.name;
    ref.read(localTeamSearchQueryProvider.notifier).state = team.name;
  }

  void _clearFavoriteTeam() {
    ref.read(selectedLocalTeamProvider.notifier).state = null;
    _favoriteSearchController.clear();
    ref.read(localTeamSearchQueryProvider.notifier).state = '';
  }

  void _handlePopularSearchChanged(String value) {
    ref.read(popularTeamSearchQueryProvider.notifier).state = value;
  }

  void _togglePopularTeam(String teamId) {
    ref.read(selectedPopularTeamsProvider.notifier).toggle(teamId);
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
    final popularTeamIds = {...ref.read(selectedPopularTeamsProvider)};
    if (localTeam != null) {
      popularTeamIds.remove(localTeam.id);
    }

    final launchRegion = ref.read(selectedLaunchRegionProvider);
    final selectedTags = ref.read(selectedLaunchFocusTagsProvider);
    final focusTags = selectedTags.isEmpty
        ? defaultFocusTagsForRegion(launchRegion)
        : selectedTags.toList();

    await OnboardingService.saveOnboardingTeams(
      localTeam: localTeam,
      popularTeamIds: popularTeamIds,
    );
    await MarketPreferencesService.saveUserPreferences(
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

    await getIt<CacheService>().setBool('onboarding_complete', true);
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
                            'Phone verification is unavailable right now. Continue as a guest and verify later when you want to transfer FET or join protected actions.',
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
              : (_canUseOtp
                    ? _phoneController.text
                              .replaceAll(RegExp(r'\D'), '')
                              .length >=
                          6
                    : true),
          onBack: () => _setStep(_welcomeStep),
          onNext: _handlePhoneContinue,
          countryCode: _dialCode,
          phoneHint: '79XX XXXX',
          buttonLabel: _loading
              ? 'SENDING...'
              : (_canUseOtp ? 'SEND OTP' : 'CONTINUE'),
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
          onTeamRemoved: _clearFavoriteTeam,
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
          selectedIds: ref.watch(selectedPopularTeamsProvider),
          onSearchChanged: _handlePopularSearchChanged,
          onToggleTeam: _togglePopularTeam,
          onBack: () => _setStep(_favoriteTeamStep),
          onFinish: _completeOnboarding,
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
