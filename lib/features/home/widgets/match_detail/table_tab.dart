part of '../../screens/match_detail_screen.dart';

class _TableTab extends StatelessWidget {
  const _TableTab({
    required this.standingsAsync,
    required this.highlightTeamIds,
  });

  final AsyncValue<List<dynamic>> standingsAsync;
  final Set<String> highlightTeamIds;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        standingsAsync.when(
          data: (rows) {
            if (rows.isEmpty) {
              return StateView.empty(
                title: 'No table',
                subtitle: 'Standings unavailable.',
                icon: Icons.table_rows_rounded,
              );
            }
            return StandingsTable(
              rows: rows.cast(),
              highlightTeamIds: highlightTeamIds,
              onTapTeam: (teamId) => context.push('/clubs/team/$teamId'),
            );
          },
          loading: () => const FzCard(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stackTrace) => StateView.empty(
            title: 'No table',
            subtitle: 'Standings unavailable.',
            icon: Icons.table_rows_rounded,
          ),
        ),
      ],
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this.tabBar);

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}
