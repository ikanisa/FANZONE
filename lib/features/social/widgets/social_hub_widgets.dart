import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../models/team_model.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/common/team_crest.dart';

class FriendHandle {
  const FriendHandle({
    required this.fanId,
    required this.accuracy,
    required this.isOnline,
  });

  final String fanId;
  final String accuracy;
  final bool isOnline;
}

class FanBoardEntry {
  const FanBoardEntry({
    required this.rank,
    required this.label,
    required this.points,
    required this.isMe,
  });

  final int rank;
  final String label;
  final String points;
  final bool isMe;
}

enum SocialTab { friends, clubFanZone }

class SocialHeader extends StatelessWidget {
  const SocialHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).brightness == Brightness.dark
        ? FzColors.darkText
        : FzColors.lightText;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      alignment: Alignment.centerLeft,
      child: Text(
        'Social Hub',
        style: FzTypography.display(
          size: 28,
          color: textColor,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class SocialTabBar extends StatelessWidget {
  const SocialTabBar({
    super.key,
    required this.activeTab,
    required this.onChanged,
  });

  final SocialTab activeTab;
  final ValueChanged<SocialTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? FzColors.darkSurface : FzColors.lightSurface;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        border: Border(
          top: BorderSide(
            color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
          ),
          bottom: BorderSide(
            color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
          ),
        ),
      ),
      child: Row(
        children: [
          _TabButton(
            label: 'Friends',
            selected: activeTab == SocialTab.friends,
            muted: muted,
            onTap: () => onChanged(SocialTab.friends),
          ),
          _TabButton(
            label: 'Club Fan Zone',
            selected: activeTab == SocialTab.clubFanZone,
            muted: muted,
            onTap: () => onChanged(SocialTab.clubFanZone),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.muted,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? FzColors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected ? FzColors.primary : muted,
            ),
          ),
        ),
      ),
    );
  }
}

class FriendsTabView extends StatelessWidget {
  const FriendsTabView({
    super.key,
    required this.query,
    required this.onQueryChanged,
    required this.onAddPressed,
    required this.onPoolPressed,
    required this.friends,
  });

  final String query;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onAddPressed;
  final ValueChanged<FriendHandle> onPoolPressed;
  final List<FriendHandle> friends;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface2 = isDark ? FzColors.darkSurface2 : FzColors.lightSurface2;
    final border = isDark ? FzColors.darkBorder : FzColors.lightBorder;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: surface2,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border),
                ),
                child: TextField(
                  onChanged: onQueryChanged,
                  maxLength: 6,
                  buildCounter:
                      (
                        _, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) => null,
                  decoration: InputDecoration(
                    hintText: 'Search by 6-digit Fan ID...',
                    hintStyle: TextStyle(color: muted),
                    prefixIcon: Icon(
                      LucideIcons.search,
                      size: 18,
                      color: muted,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: onAddPressed,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: FzColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: FzColors.primary.withValues(alpha: 0.20),
                  ),
                ),
                child: const Icon(
                  LucideIcons.userPlus,
                  size: 22,
                  color: FzColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: FzCard(
            padding: EdgeInsets.zero,
            borderRadius: 28,
            child: friends.isEmpty
                ? StateView.empty(
                    title: 'No friends found',
                    subtitle:
                        'Search by Fan ID or add a friend to build your pool network.',
                    icon: LucideIcons.users,
                  )
                : ListView.separated(
                    itemCount: friends.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, indent: 74, color: border),
                    itemBuilder: (context, index) => _FriendRow(
                      friend: friends[index],
                      onPoolPressed: () => onPoolPressed(friends[index]),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({required this.friend, required this.onPoolPressed});

  final FriendHandle friend;
  final VoidCallback onPoolPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? FzColors.darkSurface : FzColors.lightSurface;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
                  ),
                ),
                child: const Icon(LucideIcons.user, size: 18),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: friend.isOnline ? FzColors.primary : muted,
                    shape: BoxShape.circle,
                    border: Border.all(color: surface, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#${friend.fanId}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Acc: ${friend.accuracy}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: muted,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: onPoolPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: FzColors.primary,
              side: BorderSide(color: FzColors.primary.withValues(alpha: 0.24)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(LucideIcons.swords, size: 14),
            label: const Text(
              'Pool',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class PoolPromptSheet extends StatelessWidget {
  const PoolPromptSheet({super.key, required this.friend});

  final FriendHandle friend;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? FzColors.darkSurface : FzColors.lightSurface;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: muted.withValues(alpha: 0.34),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Create a Pool',
              style: FzTypography.display(
                size: 24,
                color: isDark ? FzColors.darkText : FzColors.lightText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a challenge for #${friend.fanId} from the Pools hub.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: muted, height: 1.45),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}

class ClubFanZoneView extends StatelessWidget {
  const ClubFanZoneView({
    super.key,
    required this.team,
    required this.fanId,
    required this.fanRows,
    required this.fanLoadError,
    required this.onRetry,
  });

  final TeamModel? team;
  final String? fanId;
  final List<FanBoardEntry> fanRows;
  final bool fanLoadError;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final surface = isDark ? FzColors.darkSurface : FzColors.lightSurface;
    final surface2 = isDark ? FzColors.darkSurface2 : FzColors.lightSurface2;
    final border = isDark ? FzColors.darkBorder : FzColors.lightBorder;

    if (fanLoadError) {
      return StateView.error(
        title: 'Could not load fan zone',
        onRetry: onRetry,
      );
    }

    if (team == null) {
      return StateView.empty(
        title: 'No active club selected',
        subtitle: 'Support a club first to unlock its fan zone.',
        icon: LucideIcons.shield,
      );
    }

    final teamData = team!;
    final fanZoneLabel = (teamData.shortName ?? teamData.name.split(' ').first)
        .toUpperCase();

    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [surface2, surface],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              TeamCrest(
                label: teamData.name,
                crestUrl: teamData.crestUrl ?? teamData.logoUrl,
                size: 64,
                backgroundColor: surface,
                borderColor: border,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$fanZoneLabel FANS',
                      style: FzTypography.display(
                        size: 24,
                        color: textColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      fanId == null
                          ? 'Support this club to enter the fan ranking.'
                          : 'You are ranked in the ${teamData.name} fan zone.',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'FAN LEADERBOARD',
          style: FzTypography.display(
            size: 20,
            color: textColor,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        if (fanRows.isEmpty)
          StateView.empty(
            title: 'No fans ranked yet',
            subtitle: 'The leaderboard will populate once fans join this club.',
            icon: LucideIcons.trophy,
          )
        else
          FzCard(
            padding: EdgeInsets.zero,
            borderRadius: 28,
            child: Column(
              children: [
                for (int index = 0; index < fanRows.length; index++) ...[
                  _FanRow(row: fanRows[index]),
                  if (index < fanRows.length - 1)
                    Divider(height: 1, indent: 54, color: border),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _FanRow extends StatelessWidget {
  const _FanRow({required this.row});

  final FanBoardEntry row;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;

    return Container(
      color: row.isMe ? FzColors.primary.withValues(alpha: 0.05) : null,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '${row.rank}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: row.rank <= 3 ? FzColors.coral : muted,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isDark ? FzColors.darkSurface2 : FzColors.lightSurface2,
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.user, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '#${row.label}${row.isMe ? ' (You)' : ''}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: row.isMe ? FzColors.primary : textColor,
              ),
            ),
          ),
          Text(
            row.points,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: FzColors.coral,
            ),
          ),
        ],
      ),
    );
  }
}

class AddFriendWizard extends StatefulWidget {
  const AddFriendWizard({
    super.key,
    required this.isOpen,
    required this.onClose,
  });

  final bool isOpen;
  final VoidCallback onClose;

  @override
  State<AddFriendWizard> createState() => _AddFriendWizardState();
}

class _AddFriendWizardState extends State<AddFriendWizard> {
  SocialAddFriendTab _tab = SocialAddFriendTab.id;
  String _friendId = '';

  @override
  Widget build(BuildContext context) {
    if (!widget.isOpen) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? FzColors.darkSurface : FzColors.lightSurface;
    final surface2 = isDark ? FzColors.darkSurface2 : FzColors.lightSurface2;
    final border = isDark ? FzColors.darkBorder : FzColors.lightBorder;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            child: Container(color: Colors.black.withValues(alpha: 0.70)),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              border: Border(top: BorderSide(color: border)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Add Friend',
                        style: FzTypography.display(
                          size: 24,
                          color: textColor,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: widget.onClose,
                        icon: const Icon(LucideIcons.x, size: 18),
                        style: IconButton.styleFrom(
                          backgroundColor: surface2,
                          foregroundColor: muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _AddFriendTabButton(
                        label: 'ENTER ID',
                        selected: _tab == SocialAddFriendTab.id,
                        onTap: () =>
                            setState(() => _tab = SocialAddFriendTab.id),
                      ),
                      const SizedBox(width: 12),
                      _AddFriendTabButton(
                        label: 'SCAN QR',
                        selected: _tab == SocialAddFriendTab.scan,
                        onTap: () =>
                            setState(() => _tab = SocialAddFriendTab.scan),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_tab == SocialAddFriendTab.id) ...[
                    Text(
                      'Enter a friend\'s 6-digit Fan ID to add them to your pool network.',
                      style: TextStyle(
                        fontSize: 14,
                        color: muted,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(
                        6,
                        (index) => SizedBox(
                          width: 44,
                          child: TextField(
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              final sanitized = value.replaceAll(
                                RegExp(r'\D'),
                                '',
                              );
                              final chars = _friendId.padRight(6).split('');
                              chars[index] = sanitized.isEmpty
                                  ? ''
                                  : sanitized[0];
                              setState(
                                () => _friendId = chars.join().trimRight(),
                              );
                            },
                            inputFormatters: const [],
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: surface2,
                              contentPadding: EdgeInsets.zero,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: FzColors.primary,
                                ),
                              ),
                            ),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _friendId.length == 6
                            ? widget.onClose
                            : null,
                        child: const Text('Send Request'),
                      ),
                    ),
                  ] else ...[
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 220,
                            height: 220,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: FzColors.primary.withValues(alpha: 0.35),
                                width: 2,
                              ),
                            ),
                            child: Stack(
                              children: [
                                const Center(
                                  child: Icon(
                                    LucideIcons.qrCode,
                                    size: 52,
                                    color: FzColors.darkMuted,
                                  ),
                                ),
                                Positioned(
                                  top: 18,
                                  left: 18,
                                  right: 18,
                                  child: Container(
                                    height: 2,
                                    color: FzColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Scan a friend\'s Fan ID QR Code',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Position the QR code within the frame to scan automatically.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: muted,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum SocialAddFriendTab { id, scan }

class _AddFriendTabButton extends StatelessWidget {
  const _AddFriendTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? FzColors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected
                  ? FzColors.primary
                  : (Theme.of(context).brightness == Brightness.dark
                        ? FzColors.darkMuted
                        : FzColors.lightMuted),
            ),
          ),
        ),
      ),
    );
  }
}
