part of '../screens/predict_screen.dart';

class _CreatePoolSheet extends ConsumerStatefulWidget {
  const _CreatePoolSheet();

  @override
  ConsumerState<_CreatePoolSheet> createState() => _CreatePoolSheetState();
}

class _CreatePoolSheetState extends ConsumerState<_CreatePoolSheet> {
  final _stakeController = TextEditingController();
  final _homeScoreController = TextEditingController();
  final _awayScoreController = TextEditingController();
  late final MatchesFilter _matchFilter;
  String? _selectedMatchId;
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

  @override
  void dispose() {
    _stakeController.dispose();
    _homeScoreController.dispose();
    _awayScoreController.dispose();
    super.dispose();
  }

  Future<void> _createPool() async {
    if (!ref.read(isAuthenticatedProvider)) {
      await showSignInRequiredSheet(
        context,
        title: 'Sign in to create a pool',
        message: 'Phone verification is required to create and manage pools.',
        from: '/pools',
      );
      return;
    }

    final matchId = _selectedMatchId;
    final stake = int.tryParse(_stakeController.text.trim()) ?? 0;
    final homeScore = int.tryParse(_homeScoreController.text.trim());
    final awayScore = int.tryParse(_awayScoreController.text.trim());

    if (matchId == null || matchId.isEmpty) {
      setState(() => _error = 'Select an upcoming match.');
      return;
    }
    if (stake <= 0) {
      setState(() => _error = 'Enter a valid FET stake amount.');
      return;
    }
    if (homeScore == null || awayScore == null) {
      setState(() => _error = 'Enter your score prediction.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref
          .read(poolServiceProvider.notifier)
          .createPool(
            matchId: matchId,
            homeScore: homeScore,
            awayScore: awayScore,
            stake: stake,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pool created! Waiting for opponents.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final currency = ref.watch(userCurrencyProvider).valueOrNull ?? 'EUR';
    final balance = ref.watch(walletServiceProvider).valueOrNull ?? 0;
    final matchesAsync = ref.watch(matchesProvider(_matchFilter));
    final availableMatches = (matchesAsync.valueOrNull ?? const <MatchModel>[])
        .where((match) => match.isUpcoming)
        .toList(growable: false);
    final selectedMatch = _selectedMatch(availableMatches);
    final canCreatePool =
        !_submitting && matchesAsync.hasValue && availableMatches.isNotEmpty;
    final inset = MediaQuery.of(context).viewInsets.bottom;

    if (_selectedMatchId == null && availableMatches.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _selectedMatchId != null) return;
        setState(() => _selectedMatchId = availableMatches.first.id);
      });
    }

    return Container(
      padding: EdgeInsets.only(bottom: inset),
      decoration: BoxDecoration(
        color: isDark ? FzColors.darkSurface : FzColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: muted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Create Pool',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Create a prediction pool. Others can join by matching your stake.',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 18),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Match',
                  prefixIcon: Icon(LucideIcons.swords, size: 18, color: muted),
                  errorText: matchesAsync.hasError
                      ? 'Could not load upcoming matches.'
                      : null,
                ),
                child: matchesAsync.when(
                  data: (matches) {
                    final items = matches
                        .where((match) => match.isUpcoming)
                        .toList(growable: false);

                    if (items.isEmpty) {
                      return Text(
                        'No upcoming matches are available to pool yet.',
                        style: TextStyle(fontSize: 13, color: muted),
                      );
                    }

                    return DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selectedMatch?.id ?? items.first.id,
                        items: items
                            .map(
                              (match) => DropdownMenuItem<String>(
                                value: match.id,
                                child: Text(
                                  '${match.homeTeam} vs ${match.awayTeam}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: _submitting
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() {
                                  _selectedMatchId = value;
                                  _error = null;
                                });
                              },
                      ),
                    );
                  },
                  loading: () => Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: FzGlassLoader(useBackdrop: false),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Loading upcoming matches...',
                        style: TextStyle(fontSize: 13, color: muted),
                      ),
                    ],
                  ),
                  error: (_, _) => Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Retry to load matches before creating a pool.',
                          style: TextStyle(fontSize: 13, color: muted),
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(matchesProvider(_matchFilter)),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              if (selectedMatch != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Locks before ${_formatMatchWindow(selectedMatch)}',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _stakeController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Stake (FET)',
                  hintText: '50',
                  helperText: 'Available: ${formatFET(balance, currency)}',
                  prefixIcon: Icon(LucideIcons.zap, size: 18, color: muted),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'YOUR SCORE PREDICTION',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: muted,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _NumberField(
                      controller: _homeScoreController,
                      label: selectedMatch?.homeTeam ?? 'Home',
                      enabled: !_submitting,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      '-',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: muted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _NumberField(
                      controller: _awayScoreController,
                      label: selectedMatch?.awayTeam ?? 'Away',
                      enabled: !_submitting,
                    ),
                  ),
                ],
              ),
              if ((_error ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: FzColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.alertCircle,
                        size: 16,
                        color: FzColors.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: FzColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: canCreatePool ? _createPool : null,
                  icon: _submitting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: FzGlassLoader(useBackdrop: false),
                        )
                      : const Icon(LucideIcons.plus, size: 16),
                  label: Text(_submitting ? 'Creating...' : 'Create Pool'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  MatchModel? _selectedMatch(List<MatchModel> matches) {
    for (final match in matches) {
      if (match.id == _selectedMatchId) return match;
    }
    return matches.isNotEmpty ? matches.first : null;
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
    final kickoff = match.kickoffTime ?? '--:--';
    return '$day/$month at $kickoff';
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
