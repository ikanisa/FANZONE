// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class SEn extends S {
  SEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'FANZONE';

  @override
  String get navScores => 'Scores';

  @override
  String get navFixtures => 'Fixtures';

  @override
  String get navFollowing => 'Following';

  @override
  String get navPredict => 'Predict';

  @override
  String get navProfile => 'Profile';

  @override
  String homeGreeting(String timeOfDay) {
    return 'Good $timeOfDay';
  }

  @override
  String get homeSubtitle => 'Football Prediction Hub';

  @override
  String get homeTabLive => 'Live';

  @override
  String get homeTabToday => 'Today';

  @override
  String get homeTabFollowing => 'Following';

  @override
  String get homeTabAll => 'All Leagues';

  @override
  String get matchStatusLive => 'LIVE';

  @override
  String get matchStatusFT => 'FT';

  @override
  String get matchStatusUpcoming => 'Upcoming';

  @override
  String get matchStatusPostponed => 'POSTPONED';

  @override
  String get matchStatusHT => 'HT';

  @override
  String get matchKickoff => 'Kickoff';

  @override
  String get matchVs => 'vs';

  @override
  String get leagueStandings => 'Standings';

  @override
  String get leagueFixtures => 'Fixtures';

  @override
  String get leagueResults => 'Results';

  @override
  String get leagueTeams => 'Teams';

  @override
  String get standingsPos => 'Pos';

  @override
  String get standingsTeam => 'Team';

  @override
  String get standingsP => 'P';

  @override
  String get standingsW => 'W';

  @override
  String get standingsD => 'D';

  @override
  String get standingsL => 'L';

  @override
  String get standingsGD => 'GD';

  @override
  String get standingsPts => 'Pts';

  @override
  String get predictTitle => 'Predict';

  @override
  String get predictSlip => 'Prediction Slip';

  @override
  String get predictMatchResult => 'Match Result';

  @override
  String get predictExactScore => 'Exact Score';

  @override
  String get predictStake => 'Stake';

  @override
  String get predictProjectedEarn => 'Projected Earn';

  @override
  String get predictSubmit => 'Submit Prediction';

  @override
  String get predictClear => 'Clear All';

  @override
  String predictMarketHome(String team) {
    return '$team to Win';
  }

  @override
  String get predictMarketDraw => 'Draw';

  @override
  String predictMarketAway(String team) {
    return '$team to Win';
  }

  @override
  String get poolTitle => 'POOL';

  @override
  String get poolStatus => 'Status';

  @override
  String get poolLockTime => 'LOCK TIME';

  @override
  String get poolStake => 'STAKE';

  @override
  String get poolTotalPool => 'TOTAL POOL';

  @override
  String get poolParticipants => 'PARTICIPANTS';

  @override
  String get poolCreatedBy => 'CREATED BY';

  @override
  String get poolPrediction => 'PREDICTION';

  @override
  String poolJoinFor(int stake) {
    return 'Join for $stake FET';
  }

  @override
  String get poolJoinTitle => 'JOIN POOL';

  @override
  String get poolConfirmStake => 'Confirm & Stake';

  @override
  String get poolRequiredStake => 'REQUIRED STAKE';

  @override
  String poolShareMessage(String url) {
    return 'Join my prediction pool on FANZONE! 🏆⚽\n$url';
  }

  @override
  String get poolShareSubject => 'FANZONE Pool Invite';

  @override
  String get poolStatusOpen => 'OPEN';

  @override
  String get poolStatusLocked => 'LOCKED';

  @override
  String get poolStatusSettled => 'SETTLED';

  @override
  String get poolStatusVoid => 'VOID';

  @override
  String poolIsClosed(String status) {
    return 'Pool is $status';
  }

  @override
  String get walletTitle => 'FET Wallet';

  @override
  String get walletBalance => 'Balance';

  @override
  String get walletTransactions => 'Transactions';

  @override
  String get walletTransfer => 'Transfer';

  @override
  String get walletSend => 'Send FET';

  @override
  String get walletRecipient => 'Recipient';

  @override
  String get walletAmount => 'Amount';

  @override
  String get walletInsufficientBalance => 'Insufficient FET balance';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileSettings => 'Settings';

  @override
  String get profileWallet => 'Wallet';

  @override
  String get profileLeaderboard => 'Leaderboard';

  @override
  String get profileNotifications => 'Notifications';

  @override
  String get profileHistory => 'Prediction History';

  @override
  String get profileSignIn => 'Sign in to unlock all features';

  @override
  String get profileSignInCta => 'Sign In';

  @override
  String get profileSignOut => 'Sign Out';

  @override
  String get profileGuest => 'Guest User';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsAbout => 'About FANZONE';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get leaderboardTitle => 'Leaderboard';

  @override
  String get leaderboardRank => 'Rank';

  @override
  String get leaderboardPoints => 'Points';

  @override
  String get leaderboardPredictions => 'Predictions';

  @override
  String get searchTitle => 'Search';

  @override
  String get searchHint => 'Search teams, leagues, matches...';

  @override
  String get searchNoResults => 'No results found';

  @override
  String get searchCompetitions => 'Competitions';

  @override
  String get searchTeams => 'Teams';

  @override
  String get searchMatches => 'Matches';

  @override
  String get teamProfile => 'Team Profile';

  @override
  String teamFans(int count) {
    return '$count fans';
  }

  @override
  String get teamSupport => 'Support';

  @override
  String get teamNews => 'News';

  @override
  String get teamFixtures => 'Fixtures';

  @override
  String get teamCommunity => 'Community';

  @override
  String get followingTitle => 'Following';

  @override
  String get followingEmpty =>
      'You haven\'t followed any teams or leagues yet.';

  @override
  String get followingDiscoverCaption => 'Explore teams and leagues to follow';

  @override
  String get followingDiscover => 'Discover';

  @override
  String get loginTitle => 'Welcome to FANZONE';

  @override
  String get loginSubtitle => 'The Global Football Prediction Platform';

  @override
  String get loginPhoneHint => 'Phone number';

  @override
  String get loginOtpHint => 'Enter verification code';

  @override
  String get loginSendOtp => 'Send Code';

  @override
  String get loginVerify => 'Verify';

  @override
  String get loginSkip => 'Continue as Guest';

  @override
  String get onboardingWelcome => 'Welcome to FANZONE';

  @override
  String get onboardingSubtitle => 'Predict. Compete. Win.';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingDone => 'Get Started';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonClose => 'Close';

  @override
  String get commonDone => 'Done';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonError => 'Something went wrong';

  @override
  String get commonEmpty => 'Nothing here yet';

  @override
  String get commonNetworkError =>
      'Network error. Check your connection and try again.';

  @override
  String get commonFet => 'FET';

  @override
  String get commonJustNow => 'just now';

  @override
  String commonMinAgo(int count) {
    return '${count}m ago';
  }

  @override
  String commonHrAgo(int count) {
    return '${count}h ago';
  }

  @override
  String get commonYesterday => 'Yesterday';

  @override
  String commonDaysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String featureUnavailableTitle(String feature) {
    return '$feature is coming soon';
  }

  @override
  String get featureUnavailableSubtitle =>
      'This feature will be available in a future update.';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsEmpty => 'No notifications yet';

  @override
  String get featuredEventBannerCta => 'View Event';

  @override
  String eventHubTitle(String eventName) {
    return '$eventName';
  }

  @override
  String get eventMatches => 'Event Matches';

  @override
  String get eventChallenges => 'Event Challenges';

  @override
  String get eventLeaderboard => 'Event Leaderboard';

  @override
  String get trendingGlobally => 'Trending Globally';

  @override
  String get regionAfrica => 'Africa';

  @override
  String get regionEurope => 'Europe';

  @override
  String get regionAmericas => 'Americas';

  @override
  String get regionGlobal => 'Global';

  @override
  String get popularTeamsTitle => 'Popular Teams';

  @override
  String get pickYourLocal => 'Pick your local favorite team';

  @override
  String get onboardingLocalHint =>
      'Search your favorite team from any league worldwide';
}
