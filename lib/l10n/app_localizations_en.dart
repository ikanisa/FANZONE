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
  String get navFixtures => 'Pools';

  @override
  String get navFollowing => 'Following';

  @override
  String get navProfile => 'Profile';

  @override
  String homeGreeting(String timeOfDay) {
    return 'Good $timeOfDay';
  }

  @override
  String get homeSubtitle => 'Sports-bar ordering and match pools';

  @override
  String get homeTabLive => 'Live';

  @override
  String get homeTabToday => 'Today';

  @override
  String get homeTabFollowing => 'My Teams';

  @override
  String get homeTabAll => 'All Matches';

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
  String get profileNotifications => 'Notifications';

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
  String get searchTitle => 'Search';

  @override
  String get searchHint => 'Search teams, bars, matches...';

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
  String get followingTitle => 'Following';

  @override
  String get followingEmpty => 'You haven\'t picked any favorite teams yet.';

  @override
  String get followingDiscoverCaption =>
      'Pick teams to personalize featured pools';

  @override
  String get followingDiscover => 'Discover';

  @override
  String get loginTitle => 'Welcome to FANZONE';

  @override
  String get loginSubtitle =>
      'Sports-bar ordering, match pools, and FET wallet';

  @override
  String get loginPhoneHint => 'WhatsApp number';

  @override
  String get loginOtpHint => 'Enter WhatsApp verification code';

  @override
  String get loginSendOtp => 'Send Code Via WhatsApp';

  @override
  String get loginVerify => 'Verify Code';

  @override
  String get loginSkip => 'Continue as Guest';

  @override
  String get onboardingWelcome => 'Welcome to FANZONE';

  @override
  String get onboardingSubtitle => 'Order. Pool. Earn.';

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
    return '$feature is unavailable';
  }

  @override
  String get featureUnavailableSubtitle =>
      'This feature is not enabled for your account or market.';

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
  String get popularTeamsTitle => 'Featured Teams';
}
