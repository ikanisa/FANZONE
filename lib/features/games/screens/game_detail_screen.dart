import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../providers/auth_provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fz_reference_chrome.dart';
import '../../../widgets/common/state_view.dart';
import '../../auth/widgets/sign_in_required_sheet.dart';
import '../data/games_repository.dart';

class GameDetailScreen extends ConsumerWidget {
  const GameDetailScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(gameDetailRealtimeProvider(sessionId));

    return Scaffold(
      body: SafeArea(
        child: detailAsync.when(
          data: (detail) {
            if (detail == null) {
              return StateView.empty(
                title: 'Game not found',
                subtitle: 'Pick another.',
                icon: LucideIcons.gamepad2,
                action: () => context.go('/games'),
                actionLabel: 'Games',
              );
            }
            return _GameDetailContent(detail: detail);
          },
          loading: () => const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              children: [
                FzBackHeader(title: 'Game', subtitle: 'Loading session'),
                Expanded(child: Center(child: CircularProgressIndicator())),
              ],
            ),
          ),
          error: (error, _) => StateView.error(
            title: 'Game unavailable',
            subtitle: error.toString(),
            onRetry: () =>
                ref.invalidate(gameDetailRealtimeProvider(sessionId)),
          ),
        ),
      ),
    );
  }
}

class _GameDetailContent extends ConsumerWidget {
  const _GameDetailContent({required this.detail});

  final GameDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = detail.session;
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(gameDetailRealtimeProvider(session.id));
        await ref.read(gameDetailProvider(session.id).future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 130),
        children: [
          FzBackHeader(
            title: session.templateName,
            subtitle: session.venueName,
            onClose: () => context.go('/games'),
          ),
          const SizedBox(height: 18),
          _GameHero(detail: detail),
          const SizedBox(height: 16),
          _EligibilityCard(detail: detail),
          const SizedBox(height: 16),
          _TeamsSection(detail: detail),
          if (detail.myTeam != null &&
              session.isLive &&
              session.usesQuestions) ...[
            const SizedBox(height: 16),
            _QuestionCard(detail: detail),
          ],
          if (detail.myTeam != null && session.isMusicBingo) ...[
            const SizedBox(height: 16),
            _BingoCard(detail: detail),
          ],
          const SizedBox(height: 16),
          _LeaderboardCard(teams: detail.teams),
        ],
      ),
    );
  }
}

class _GameHero extends StatelessWidget {
  const _GameHero({required this.detail});

  final GameDetail detail;

  @override
  Widget build(BuildContext context) {
    final session = detail.session;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FzColors.darkSurface, FzColors.primary, FzColors.teal],
          stops: [0, 0.62, 1],
        ),
        borderRadius: FzRadii.heroRadius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusPill(status: session.status),
              const Spacer(),
              Text(
                '${detail.teams.length} teams',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            session.templateName,
            style: FzTypography.display(
              size: 34,
              color: Colors.white,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            session.venueName,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  label: 'Reward',
                  value: '${session.rewardFet} FET',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroMetric(
                  label: 'Starts',
                  value: _timeLabel(session.scheduledStartAt),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EligibilityCard extends StatelessWidget {
  const _EligibilityCard({required this.detail});

  final GameDetail detail;

  @override
  Widget build(BuildContext context) {
    final joined = detail.myTeam != null;
    final title = !joined
        ? 'Not joined'
        : detail.isEligible
        ? 'Eligible'
        : 'Order needed';
    final color = !joined
        ? FzColors.darkMuted
        : detail.isEligible
        ? FzColors.success
        : FzColors.warning;
    final subtitle = !joined
        ? 'Join team.'
        : detail.isEligible
        ? 'Order linked.'
        : 'Order required.';

    return FzCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(LucideIcons.receipt, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: FzColors.darkMuted,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamsSection extends ConsumerWidget {
  const _TeamsSection({required this.detail});

  final GameDetail detail;

  Future<void> _createTeam(BuildContext context, WidgetRef ref) async {
    if (!await _ensureVerified(context, ref, detail.session.id)) return;
    if (!context.mounted) return;
    final name = await _askTeamName(context);
    if (!context.mounted) return;
    if (name == null || name.trim().length < 2) return;
    try {
      await ref
          .read(gamesRepositoryProvider)
          .createTeam(sessionId: detail.session.id, name: name);
      ref.invalidate(gameDetailRealtimeProvider(detail.session.id));
      if (!context.mounted) return;
      _showSnack(context, 'Team created.');
    } catch (error) {
      if (!context.mounted) return;
      _showSnack(context, 'Team creation failed: $error');
    }
  }

  Future<void> _joinTeam(
    BuildContext context,
    WidgetRef ref,
    GameTeam team,
  ) async {
    if (!await _ensureVerified(context, ref, detail.session.id)) return;
    if (!context.mounted) return;
    try {
      await ref.read(gamesRepositoryProvider).joinTeam(team.id);
      ref.invalidate(gameDetailRealtimeProvider(detail.session.id));
      if (!context.mounted) return;
      _showSnack(context, 'Joined ${team.name}.');
    } catch (error) {
      if (!context.mounted) return;
      _showSnack(context, 'Join failed: $error');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myTeam = detail.myTeam;
    return FzCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Teams',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              if (myTeam == null && detail.session.isJoinable)
                TextButton.icon(
                  onPressed: () => _createTeam(context, ref),
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: const Text('Create'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (detail.teams.isEmpty)
            const Text(
              'Need 2 teams.',
              style: TextStyle(color: FzColors.darkMuted),
            )
          else
            ...detail.teams.map(
              (team) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            team.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            '${team.scoreFet} FET score',
                            style: const TextStyle(
                              color: FzColors.darkMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (myTeam?.id == team.id)
                      const _JoinedPill()
                    else if (myTeam == null && detail.session.isJoinable)
                      OutlinedButton(
                        onPressed: () => _joinTeam(context, ref, team),
                        child: const Text('Join'),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuestionCard extends ConsumerStatefulWidget {
  const _QuestionCard({required this.detail});

  final GameDetail detail;

  @override
  ConsumerState<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends ConsumerState<_QuestionCard> {
  final _answerController = TextEditingController();
  var _submitting = false;

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _submit(String answer) async {
    final detail = widget.detail;
    final question = detail.currentQuestion;
    final team = detail.myTeam;
    if (question == null || team == null || answer.trim().isEmpty) return;

    setState(() => _submitting = true);
    try {
      final result = await ref
          .read(gamesRepositoryProvider)
          .submitAnswer(
            sessionId: detail.session.id,
            questionId: question.questionId,
            teamId: team.id,
            answer: answer,
          );
      ref.invalidate(gameDetailRealtimeProvider(detail.session.id));
      if (!mounted) return;
      final firstCorrect = result['is_first_correct'] == true;
      final correct = result['is_correct'] == true;
      _showSnack(
        context,
        firstCorrect
            ? 'First correct.'
            : correct
            ? 'Correct.'
            : 'Got it.',
      );
    } catch (error) {
      if (!mounted) return;
      _showSnack(context, 'Answer failed: $error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.detail.currentQuestion;
    if (question == null) {
      return const FzCard(
        padding: EdgeInsets.all(16),
        child: Text(
          'Waiting for host.',
          style: TextStyle(color: FzColors.darkMuted),
        ),
      );
    }

    return FzCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Question ${question.ordinal}',
            style: const TextStyle(
              color: FzColors.accent,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            question.prompt,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          if (question.options.isNotEmpty)
            ...question.options.map(
              (option) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _submitting ? null : () => _submit(option),
                    child: Text(option),
                  ),
                ),
              ),
            )
          else ...[
            TextField(
              controller: _answerController,
              decoration: const InputDecoration(labelText: 'Answer'),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitting
                    ? null
                    : () => _submit(_answerController.text),
                icon: const Icon(LucideIcons.send, size: 16),
                label: const Text('Submit'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BingoCard extends ConsumerWidget {
  const _BingoCard({required this.detail});

  final GameDetail detail;

  Future<void> _toggleTile(
    BuildContext context,
    WidgetRef ref,
    BingoTile tile,
    bool marked,
  ) async {
    final card = detail.bingoCard;
    if (card == null || tile.key == 'tile_13') return;
    try {
      await ref
          .read(gamesRepositoryProvider)
          .markBingoTile(cardId: card.id, tileKey: tile.key, marked: !marked);
      ref.invalidate(gameDetailRealtimeProvider(detail.session.id));
    } catch (error) {
      if (!context.mounted) return;
      _showSnack(context, 'Could not update tile: $error');
    }
  }

  Future<void> _claim(BuildContext context, WidgetRef ref) async {
    final card = detail.bingoCard;
    if (card == null) return;
    try {
      await ref.read(gamesRepositoryProvider).submitBingoClaim(card.id);
      if (!context.mounted) return;
      _showSnack(context, 'Claim sent.');
    } catch (error) {
      if (!context.mounted) return;
      _showSnack(context, 'Claim failed: $error');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = detail.bingoCard;
    if (card == null || card.tiles.length < 25) {
      return const FzCard(
        padding: EdgeInsets.all(16),
        child: Text(
          'Card loading.',
          style: TextStyle(color: FzColors.darkMuted),
        ),
      );
    }

    return FzCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Music Bingo',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Mark tiles. Claim.',
            style: TextStyle(
              color: FzColors.darkMuted,
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 25,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              final tile = card.tiles[index];
              final marked = card.marks.contains(tile.key);
              return InkWell(
                onTap: () => _toggleTile(context, ref, tile, marked),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: marked
                        ? FzColors.success.withValues(alpha: 0.18)
                        : FzColors.darkSurface2,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: marked ? FzColors.success : FzColors.darkBorder,
                    ),
                  ),
                  child: Text(
                    tile.label,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: marked ? FzColors.success : FzColors.darkText,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _claim(context, ref),
              icon: const Icon(LucideIcons.badgeCheck, size: 16),
              label: const Text('Claim'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardCard extends StatelessWidget {
  const _LeaderboardCard({required this.teams});

  final List<GameTeam> teams;

  @override
  Widget build(BuildContext context) {
    if (teams.isEmpty) return const SizedBox.shrink();

    return FzCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Leaderboard',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          ...teams.map(
            (team) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      team.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    '${team.scoreFet} FET',
                    style: const TextStyle(
                      color: FzColors.success,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: FzRadii.buttonRadius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'live' => FzColors.success,
      'lobby' => FzColors.accent,
      'settled' => FzColors.accent2,
      'ended' => FzColors.warning,
      _ => Colors.white70,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: FzRadii.fullRadius,
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _JoinedPill extends StatelessWidget {
  const _JoinedPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: FzColors.success.withValues(alpha: 0.12),
        borderRadius: FzRadii.fullRadius,
      ),
      child: const Text(
        'JOINED',
        style: TextStyle(
          color: FzColors.success,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

Future<bool> _ensureVerified(
  BuildContext context,
  WidgetRef ref,
  String sessionId,
) async {
  final isVerified = ref.read(isFullyAuthenticatedProvider);
  if (isVerified) return true;
  await showSignInRequiredSheet(
    context,
    title: 'Verify WhatsApp',
    message: 'Unlock games.',
    from: '/game/$sessionId',
  );
  return false;
}

Future<String?> _askTeamName(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Create'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Team'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: const Text('Create'),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

String _timeLabel(DateTime dateTime) {
  final local = dateTime.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.month}/${local.day} $hour:$minute';
}
