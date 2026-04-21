part of '../screens/predict_screen.dart';

enum _CreatePoolStep { selectMatch, predictScore, setStake }

class CreatePoolScreen extends ConsumerStatefulWidget {
  const CreatePoolScreen({super.key});

  @override
  ConsumerState<CreatePoolScreen> createState() => _CreatePoolScreenState();
}

class _CreatePoolScreenState extends ConsumerState<CreatePoolScreen> {
  late final MatchesFilter _matchFilter;
  _CreatePoolStep _step = _CreatePoolStep.selectMatch;
  String? _selectedMatchId;
  int _homeScore = 0;
  int _awayScore = 0;
  double _stake = 100;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 14));
    _matchFilter = MatchesFilter(
      dateFrom: _formatDate(start),
      dateTo: _formatDate(end),
      limit: 24,
      ascending: true,
    );
  }

  Future<void> _createPool() async {
    if (!ref.read(isAuthenticatedProvider)) {
      await showSignInRequiredSheet(
        context,
        title: 'Sign in to create a pool',
        message: 'Phone verification is required to create and manage pools.',
        from: '/pools/create',
      );
      return;
    }

    final selectedMatch = _selectedMatch;
    if (selectedMatch == null) {
      setState(() => _error = 'Select an upcoming match.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final poolId = await ref
          .read(poolServiceProvider.notifier)
          .createPool(
            matchId: selectedMatch.id,
            homeScore: _homeScore,
            awayScore: _awayScore,
            stake: _stake.round(),
          );
      if (!mounted) return;
      context.go('/pool/$poolId');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = _formatError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const muted = FzColors.darkMuted;
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final currency = ref.watch(userCurrencyProvider).valueOrNull ?? 'EUR';
    final balance = ref.watch(walletServiceProvider).valueOrNull ?? 0;
    final matchesAsync = ref.watch(matchesProvider(_matchFilter));
    final availableMatches = (matchesAsync.valueOrNull ?? const <MatchModel>[])
        .where((match) => match.isUpcoming)
        .toList(growable: false);
    final selectedMatch = _selectedMatchFrom(availableMatches);
    final effectiveStep =
        selectedMatch == null && _step != _CreatePoolStep.selectMatch
        ? _CreatePoolStep.selectMatch
        : _step;
    final canAffordStake = balance >= _stake.round();
    final isAffordable = !isAuthenticated || canAffordStake;

    return Scaffold(
      backgroundColor: FzColors.darkBg,
      body: Column(
        children: [
          _CreatePoolHeader(onBack: _handleBack),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 156),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((_error ?? '').isNotEmpty) ...[
                    _WizardErrorBanner(message: _error!),
                    const SizedBox(height: 18),
                  ],
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) {
                      final offset = Tween<Offset>(
                        begin: const Offset(0.06, 0),
                        end: Offset.zero,
                      ).animate(animation);
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(position: offset, child: child),
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey(effectiveStep),
                      child: switch (effectiveStep) {
                        _CreatePoolStep.selectMatch => _MatchSelectionStep(
                          matchesAsync: matchesAsync,
                          matches: availableMatches,
                          onRetry: () =>
                              ref.invalidate(matchesProvider(_matchFilter)),
                          onSelectMatch: _handleSelectMatch,
                          formatTime: _formatMatchTime,
                        ),
                        _CreatePoolStep.predictScore
                            when selectedMatch != null =>
                          _ScorePredictionStep(
                            match: selectedMatch,
                            homeScore: _homeScore,
                            awayScore: _awayScore,
                            onIncrementHome: () =>
                                _adjustScore(home: true, delta: 1),
                            onDecrementHome: () =>
                                _adjustScore(home: true, delta: -1),
                            onIncrementAway: () =>
                                _adjustScore(home: false, delta: 1),
                            onDecrementAway: () =>
                                _adjustScore(home: false, delta: -1),
                            onContinue: _goToStake,
                          ),
                        _CreatePoolStep.setStake when selectedMatch != null =>
                          _StakeStep(
                            stake: _stake,
                            currency: currency,
                            balanceLabel: isAuthenticated
                                ? formatFETCompact(balance)
                                : 'Sign in to view',
                            isAffordable: isAffordable,
                            isSubmitting: _submitting,
                            onStakeChanged: (value) =>
                                setState(() => _stake = value),
                            onCreate: _createPool,
                          ),
                        _ => _MatchSelectionStep(
                          matchesAsync: matchesAsync,
                          matches: availableMatches,
                          onRetry: () =>
                              ref.invalidate(matchesProvider(_matchFilter)),
                          onSelectMatch: _handleSelectMatch,
                          formatTime: _formatMatchTime,
                        ),
                      },
                    ),
                  ),
                  if (selectedMatch != null) ...[
                    const SizedBox(height: 18),
                    Text(
                      'Pool locks 30 minutes before kickoff: ${_formatMatchWindow(selectedMatch)}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: muted,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  MatchModel? get _selectedMatch {
    final matches = ref.read(matchesProvider(_matchFilter)).valueOrNull;
    if (matches == null) return null;
    return _selectedMatchFrom(
      matches.where((match) => match.isUpcoming).toList(),
    );
  }

  MatchModel? _selectedMatchFrom(List<MatchModel> matches) {
    for (final match in matches) {
      if (match.id == _selectedMatchId) return match;
    }
    return null;
  }

  void _handleBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      context.pop();
      return;
    }
    context.go('/pools');
  }

  void _handleSelectMatch(MatchModel match) {
    setState(() {
      _selectedMatchId = match.id;
      _homeScore = 0;
      _awayScore = 0;
      _step = _CreatePoolStep.predictScore;
      _error = null;
    });
  }

  void _adjustScore({required bool home, required int delta}) {
    setState(() {
      if (home) {
        _homeScore = (_homeScore + delta).clamp(0, 99).toInt();
      } else {
        _awayScore = (_awayScore + delta).clamp(0, 99).toInt();
      }
      _error = null;
    });
  }

  void _goToStake() {
    setState(() {
      _step = _CreatePoolStep.setStake;
      _error = null;
    });
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _formatMatchWindow(MatchModel match) {
    final date = match.date;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final kickoff = match.kickoffTimeLocalLabel;
    return '$day/$month at $kickoff';
  }

  String _formatMatchTime(MatchModel match) {
    final date = match.date;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final kickoff = match.kickoffTimeLocalLabel;
    return '$day/$month • $kickoff';
  }

  String _formatError(Object error) {
    final message = error.toString();
    final failureMatch = RegExp(
      r'^Failure\([^:]*: (.*)\)$',
    ).firstMatch(message);
    if (failureMatch != null) {
      return failureMatch.group(1) ?? message;
    }
    return message.replaceFirst('Exception: ', '');
  }
}

class _CreatePoolHeader extends StatelessWidget {
  const _CreatePoolHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: FzColors.darkSurface.withValues(alpha: 0.92),
        border: const Border(bottom: BorderSide(color: FzColors.darkBorder)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            splashRadius: 22,
            icon: const Icon(
              LucideIcons.chevronLeft,
              size: 24,
              color: FzColors.darkText,
            ),
          ),
          const Expanded(
            child: Column(
              children: [
                Text(
                  'Create',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: FzColors.darkMuted,
                    letterSpacing: 1.4,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'New Pool',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: FzColors.darkText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _MatchSelectionStep extends StatelessWidget {
  const _MatchSelectionStep({
    required this.matchesAsync,
    required this.matches,
    required this.onRetry,
    required this.onSelectMatch,
    required this.formatTime,
  });

  final AsyncValue<List<MatchModel>> matchesAsync;
  final List<MatchModel> matches;
  final VoidCallback onRetry;
  final ValueChanged<MatchModel> onSelectMatch;
  final String Function(MatchModel match) formatTime;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('match-selection-step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _WizardStepTitle(
          title: 'Select a Match',
          showDivider: true,
          centered: false,
        ),
        const SizedBox(height: 24),
        if (matchesAsync.isLoading && matches.isEmpty)
          const _WizardLoadingState(label: 'Loading upcoming matches...')
        else if (matchesAsync.hasError && matches.isEmpty)
          _WizardStateCard(
            message: 'Could not load upcoming matches.',
            actionLabel: 'Retry',
            onAction: onRetry,
          )
        else if (matches.isEmpty)
          const _WizardStateCard(
            message: 'No upcoming matches are available to pool yet.',
          )
        else
          Column(
            children: matches
                .map(
                  (match) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _MatchSelectionCard(
                      match: match,
                      timeLabel: formatTime(match),
                      onTap: () => onSelectMatch(match),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
      ],
    );
  }
}

class _ScorePredictionStep extends StatelessWidget {
  const _ScorePredictionStep({
    required this.match,
    required this.homeScore,
    required this.awayScore,
    required this.onIncrementHome,
    required this.onDecrementHome,
    required this.onIncrementAway,
    required this.onDecrementAway,
    required this.onContinue,
  });

  final MatchModel match;
  final int homeScore;
  final int awayScore;
  final VoidCallback onIncrementHome;
  final VoidCallback onDecrementHome;
  final VoidCallback onIncrementAway;
  final VoidCallback onDecrementAway;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('score-prediction-step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _WizardStepTitle(
          title: 'Predict Score',
          showDivider: false,
          centered: true,
        ),
        const SizedBox(height: 32),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _ScoreControl(
                teamName: match.homeTeam,
                crestUrl: match.homeLogoUrl,
                score: homeScore,
                onIncrement: onIncrementHome,
                onDecrement: onDecrementHome,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 72),
              child: Text(
                ':',
                style: FzTypography.display(
                  size: 36,
                  color: FzColors.darkMuted.withValues(alpha: 0.3),
                  letterSpacing: 0,
                ),
              ),
            ),
            Expanded(
              child: _ScoreControl(
                teamName: match.awayTeam,
                crestUrl: match.awayLogoUrl,
                score: awayScore,
                onIncrement: onIncrementAway,
                onDecrement: onDecrementAway,
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
        _WizardPrimaryButton(label: 'Continue to Stake', onPressed: onContinue),
      ],
    );
  }
}

class _StakeStep extends StatelessWidget {
  const _StakeStep({
    required this.stake,
    required this.currency,
    required this.balanceLabel,
    required this.isAffordable,
    required this.isSubmitting,
    required this.onStakeChanged,
    required this.onCreate,
  });

  final double stake;
  final String currency;
  final String balanceLabel;
  final bool isAffordable;
  final bool isSubmitting;
  final ValueChanged<double> onStakeChanged;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final amount = stake.round();

    return Column(
      key: const ValueKey('stake-step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _WizardStepTitle(
          title: 'Set Your Stake',
          showDivider: true,
          centered: false,
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
          decoration: BoxDecoration(
            color: FzColors.darkSurface2,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: FzColors.darkBorder),
          ),
          child: Column(
            children: [
              const Text(
                'STAKE AMOUNT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: FzColors.darkMuted,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                formatFET(amount, currency),
                textAlign: TextAlign.center,
                style: FzTypography.score(
                  size: 30,
                  weight: FontWeight.w700,
                  color: FzColors.secondary,
                ),
              ),
              const SizedBox(height: 24),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: FzColors.primary,
                  inactiveTrackColor: FzColors.darkSurface3,
                  thumbColor: FzColors.secondary,
                  overlayColor: FzColors.secondary.withValues(alpha: 0.14),
                  trackHeight: 4,
                ),
                child: Slider(
                  min: 50,
                  max: 5000,
                  divisions: 99,
                  value: stake.clamp(50, 5000),
                  onChanged: isSubmitting ? null : onStakeChanged,
                ),
              ),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Expanded(
                    child: Text(
                      'Min: 50',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: FzColors.darkMuted,
                      ),
                    ),
                  ),
                  Text(
                    'Max: 5000',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: FzColors.darkMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: FzColors.darkSurface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: FzColors.darkBorder),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Your Balance',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: FzColors.darkText,
                  ),
                ),
              ),
              Text(
                balanceLabel,
                style: FzTypography.score(
                  size: 16,
                  weight: FontWeight.w700,
                  color: isAffordable ? FzColors.primary : FzColors.secondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _WizardPrimaryButton(
          label: isAffordable ? 'CREATE CHALLENGE' : 'INSUFFICIENT FUNDS',
          onPressed: isAffordable && !isSubmitting ? onCreate : null,
          isLoading: isSubmitting,
          enabled: isAffordable && !isSubmitting,
        ),
      ],
    );
  }
}

class _WizardStepTitle extends StatelessWidget {
  const _WizardStepTitle({
    required this.title,
    required this.showDivider,
    required this.centered,
  });

  final String title;
  final bool showDivider;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final child = Text(
      title,
      textAlign: centered ? TextAlign.center : TextAlign.start,
      style: FzTypography.display(
        size: 32,
        color: FzColors.darkText,
        letterSpacing: 1.4,
      ),
    );

    if (!showDivider) return child;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: FzColors.darkBorder)),
      ),
      child: child,
    );
  }
}

class _MatchSelectionCard extends StatelessWidget {
  const _MatchSelectionCard({
    required this.match,
    required this.timeLabel,
    required this.onTap,
  });

  final MatchModel match;
  final String timeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: FzColors.darkSurface2,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: FzColors.darkBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: 0,
                          child: TeamCrest(
                            label: match.homeTeam,
                            crestUrl: match.homeLogoUrl,
                            size: 32,
                            backgroundColor: FzColors.darkSurface,
                            borderColor: FzColors.darkBorder,
                          ),
                        ),
                        Positioned(
                          left: 20,
                          child: TeamCrest(
                            label: match.awayTeam,
                            crestUrl: match.awayLogoUrl,
                            size: 32,
                            backgroundColor: FzColors.darkSurface,
                            borderColor: FzColors.darkBorder,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${match.homeTeam} vs ${match.awayTeam}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: FzColors.darkText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.calendar,
                              size: 10,
                              color: FzColors.darkMuted,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                timeLabel,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: FzColors.darkMuted,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: FzColors.darkMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreControl extends StatelessWidget {
  const _ScoreControl({
    required this.teamName,
    required this.crestUrl,
    required this.score,
    required this.onIncrement,
    required this.onDecrement,
  });

  final String teamName;
  final String? crestUrl;
  final int score;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TeamCrest(
          label: teamName,
          crestUrl: crestUrl,
          size: 64,
          backgroundColor: FzColors.darkSurface3,
          borderColor: FzColors.darkBorder,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 90,
          child: Text(
            teamName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: FzColors.darkText,
            ),
          ),
        ),
        const SizedBox(height: 14),
        _ScoreAdjustButton(icon: LucideIcons.plus, onTap: onIncrement),
        const SizedBox(height: 10),
        SizedBox(
          width: 72,
          child: Text(
            '$score',
            textAlign: TextAlign.center,
            style: FzTypography.display(
              size: 52,
              color: FzColors.darkText,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(height: 10),
        _ScoreAdjustButton(icon: LucideIcons.minus, onTap: onDecrement),
      ],
    );
  }
}

class _ScoreAdjustButton extends StatelessWidget {
  const _ScoreAdjustButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        width: 56,
        height: 42,
        decoration: BoxDecoration(
          color: FzColors.darkSurface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: FzColors.darkBorder),
        ),
        child: Icon(icon, size: 18, color: FzColors.darkText),
      ),
    );
  }
}

class _WizardPrimaryButton extends StatelessWidget {
  const _WizardPrimaryButton({
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final background = enabled ? FzColors.primary : FzColors.darkSurface3;
    final foreground = enabled ? FzColors.onPrimary : FzColors.darkMuted;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: background,
          disabledForegroundColor: foreground,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: FzGlassLoader(useBackdrop: false, size: 18),
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: foreground,
                ),
              ),
      ),
    );
  }
}

class _WizardLoadingState extends StatelessWidget {
  const _WizardLoadingState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: FzColors.darkSurface2,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: FzColors.darkBorder),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: FzGlassLoader(useBackdrop: false, size: 16),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: FzColors.darkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _WizardStateCard extends StatelessWidget {
  const _WizardStateCard({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: FzColors.darkSurface2,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: FzColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: FzColors.darkMuted,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _WizardErrorBanner extends StatelessWidget {
  const _WizardErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: FzColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FzColors.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.alertCircle, size: 16, color: FzColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: FzColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  const _SliverAppBarDelegate({required this.child});

  final Widget child;

  static const _tabStripExtent = 42.0;

  @override
  double get minExtent => _tabStripExtent;

  @override
  double get maxExtent => _tabStripExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _SliverAppBarDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}
