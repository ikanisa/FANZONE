import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of S
/// returned by `S.of(context)`.
///
/// Applications need to include `S.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: S.localizationsDelegates,
///   supportedLocales: S.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the S.supportedLocales
/// property.
abstract class S {
  S(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static S of(BuildContext context) {
    return Localizations.of<S>(context, S)!;
  }

  static const LocalizationsDelegate<S> delegate = _SDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// Application name
  ///
  /// In en, this message translates to:
  /// **'FANZONE'**
  String get appName;

  /// Bottom nav: Scores tab
  ///
  /// In en, this message translates to:
  /// **'Scores'**
  String get navScores;

  /// Bottom nav: Fixtures tab
  ///
  /// In en, this message translates to:
  /// **'Fixtures'**
  String get navFixtures;

  /// Bottom nav: Following tab
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get navFollowing;

  /// Bottom nav: Predict tab
  ///
  /// In en, this message translates to:
  /// **'Predict'**
  String get navPredict;

  /// Bottom nav: Profile tab
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// Home screen greeting
  ///
  /// In en, this message translates to:
  /// **'Good {timeOfDay}'**
  String homeGreeting(String timeOfDay);

  /// Home screen subtitle
  ///
  /// In en, this message translates to:
  /// **'Football Prediction Hub'**
  String get homeSubtitle;

  /// No description provided for @homeTabLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get homeTabLive;

  /// No description provided for @homeTabToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get homeTabToday;

  /// No description provided for @homeTabFollowing.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get homeTabFollowing;

  /// No description provided for @homeTabAll.
  ///
  /// In en, this message translates to:
  /// **'All Leagues'**
  String get homeTabAll;

  /// No description provided for @matchStatusLive.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get matchStatusLive;

  /// No description provided for @matchStatusFT.
  ///
  /// In en, this message translates to:
  /// **'FT'**
  String get matchStatusFT;

  /// No description provided for @matchStatusUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get matchStatusUpcoming;

  /// No description provided for @matchStatusPostponed.
  ///
  /// In en, this message translates to:
  /// **'POSTPONED'**
  String get matchStatusPostponed;

  /// No description provided for @matchStatusHT.
  ///
  /// In en, this message translates to:
  /// **'HT'**
  String get matchStatusHT;

  /// No description provided for @matchKickoff.
  ///
  /// In en, this message translates to:
  /// **'Kickoff'**
  String get matchKickoff;

  /// No description provided for @matchVs.
  ///
  /// In en, this message translates to:
  /// **'vs'**
  String get matchVs;

  /// No description provided for @leagueStandings.
  ///
  /// In en, this message translates to:
  /// **'Standings'**
  String get leagueStandings;

  /// No description provided for @leagueFixtures.
  ///
  /// In en, this message translates to:
  /// **'Fixtures'**
  String get leagueFixtures;

  /// No description provided for @leagueResults.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get leagueResults;

  /// No description provided for @leagueTeams.
  ///
  /// In en, this message translates to:
  /// **'Teams'**
  String get leagueTeams;

  /// No description provided for @standingsPos.
  ///
  /// In en, this message translates to:
  /// **'Pos'**
  String get standingsPos;

  /// No description provided for @standingsTeam.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get standingsTeam;

  /// No description provided for @standingsP.
  ///
  /// In en, this message translates to:
  /// **'P'**
  String get standingsP;

  /// No description provided for @standingsW.
  ///
  /// In en, this message translates to:
  /// **'W'**
  String get standingsW;

  /// No description provided for @standingsD.
  ///
  /// In en, this message translates to:
  /// **'D'**
  String get standingsD;

  /// No description provided for @standingsL.
  ///
  /// In en, this message translates to:
  /// **'L'**
  String get standingsL;

  /// No description provided for @standingsGD.
  ///
  /// In en, this message translates to:
  /// **'GD'**
  String get standingsGD;

  /// No description provided for @standingsPts.
  ///
  /// In en, this message translates to:
  /// **'Pts'**
  String get standingsPts;

  /// No description provided for @predictTitle.
  ///
  /// In en, this message translates to:
  /// **'Predict'**
  String get predictTitle;

  /// No description provided for @predictSlip.
  ///
  /// In en, this message translates to:
  /// **'Prediction Slip'**
  String get predictSlip;

  /// No description provided for @predictMatchResult.
  ///
  /// In en, this message translates to:
  /// **'Match Result'**
  String get predictMatchResult;

  /// No description provided for @predictExactScore.
  ///
  /// In en, this message translates to:
  /// **'Exact Score'**
  String get predictExactScore;

  /// No description provided for @predictStake.
  ///
  /// In en, this message translates to:
  /// **'Stake'**
  String get predictStake;

  /// No description provided for @predictProjectedEarn.
  ///
  /// In en, this message translates to:
  /// **'Projected Earn'**
  String get predictProjectedEarn;

  /// No description provided for @predictSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit Prediction'**
  String get predictSubmit;

  /// No description provided for @predictClear.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get predictClear;

  /// No description provided for @predictMarketHome.
  ///
  /// In en, this message translates to:
  /// **'{team} to Win'**
  String predictMarketHome(String team);

  /// No description provided for @predictMarketDraw.
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get predictMarketDraw;

  /// No description provided for @predictMarketAway.
  ///
  /// In en, this message translates to:
  /// **'{team} to Win'**
  String predictMarketAway(String team);

  /// No description provided for @poolTitle.
  ///
  /// In en, this message translates to:
  /// **'POOL'**
  String get poolTitle;

  /// No description provided for @poolStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get poolStatus;

  /// No description provided for @poolLockTime.
  ///
  /// In en, this message translates to:
  /// **'LOCK TIME'**
  String get poolLockTime;

  /// No description provided for @poolStake.
  ///
  /// In en, this message translates to:
  /// **'STAKE'**
  String get poolStake;

  /// No description provided for @poolTotalPool.
  ///
  /// In en, this message translates to:
  /// **'TOTAL POOL'**
  String get poolTotalPool;

  /// No description provided for @poolParticipants.
  ///
  /// In en, this message translates to:
  /// **'PARTICIPANTS'**
  String get poolParticipants;

  /// No description provided for @poolCreatedBy.
  ///
  /// In en, this message translates to:
  /// **'CREATED BY'**
  String get poolCreatedBy;

  /// No description provided for @poolPrediction.
  ///
  /// In en, this message translates to:
  /// **'PREDICTION'**
  String get poolPrediction;

  /// No description provided for @poolJoinFor.
  ///
  /// In en, this message translates to:
  /// **'Join for {stake} FET'**
  String poolJoinFor(int stake);

  /// No description provided for @poolJoinTitle.
  ///
  /// In en, this message translates to:
  /// **'JOIN POOL'**
  String get poolJoinTitle;

  /// No description provided for @poolConfirmStake.
  ///
  /// In en, this message translates to:
  /// **'Confirm & Stake'**
  String get poolConfirmStake;

  /// No description provided for @poolRequiredStake.
  ///
  /// In en, this message translates to:
  /// **'REQUIRED STAKE'**
  String get poolRequiredStake;

  /// No description provided for @poolShareMessage.
  ///
  /// In en, this message translates to:
  /// **'Join my prediction pool on FANZONE! 🏆⚽\n{url}'**
  String poolShareMessage(String url);

  /// No description provided for @poolShareSubject.
  ///
  /// In en, this message translates to:
  /// **'FANZONE Pool Invite'**
  String get poolShareSubject;

  /// No description provided for @poolStatusOpen.
  ///
  /// In en, this message translates to:
  /// **'OPEN'**
  String get poolStatusOpen;

  /// No description provided for @poolStatusLocked.
  ///
  /// In en, this message translates to:
  /// **'LOCKED'**
  String get poolStatusLocked;

  /// No description provided for @poolStatusSettled.
  ///
  /// In en, this message translates to:
  /// **'SETTLED'**
  String get poolStatusSettled;

  /// No description provided for @poolStatusVoid.
  ///
  /// In en, this message translates to:
  /// **'VOID'**
  String get poolStatusVoid;

  /// No description provided for @poolIsClosed.
  ///
  /// In en, this message translates to:
  /// **'Pool is {status}'**
  String poolIsClosed(String status);

  /// No description provided for @walletTitle.
  ///
  /// In en, this message translates to:
  /// **'FET Wallet'**
  String get walletTitle;

  /// No description provided for @walletBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get walletBalance;

  /// No description provided for @walletTransactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get walletTransactions;

  /// No description provided for @walletTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get walletTransfer;

  /// No description provided for @walletSend.
  ///
  /// In en, this message translates to:
  /// **'Send FET'**
  String get walletSend;

  /// No description provided for @walletRecipient.
  ///
  /// In en, this message translates to:
  /// **'Recipient'**
  String get walletRecipient;

  /// No description provided for @walletAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get walletAmount;

  /// No description provided for @walletInsufficientBalance.
  ///
  /// In en, this message translates to:
  /// **'Insufficient FET balance'**
  String get walletInsufficientBalance;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get profileSettings;

  /// No description provided for @profileWallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get profileWallet;

  /// No description provided for @profileLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get profileLeaderboard;

  /// No description provided for @profileNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get profileNotifications;

  /// No description provided for @profileHistory.
  ///
  /// In en, this message translates to:
  /// **'Prediction History'**
  String get profileHistory;

  /// No description provided for @profileSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in to unlock all features'**
  String get profileSignIn;

  /// No description provided for @profileSignInCta.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get profileSignInCta;

  /// No description provided for @profileSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get profileSignOut;

  /// No description provided for @profileGuest.
  ///
  /// In en, this message translates to:
  /// **'Guest User'**
  String get profileGuest;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About FANZONE'**
  String get settingsAbout;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String settingsVersion(String version);

  /// No description provided for @leaderboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get leaderboardTitle;

  /// No description provided for @leaderboardRank.
  ///
  /// In en, this message translates to:
  /// **'Rank'**
  String get leaderboardRank;

  /// No description provided for @leaderboardPoints.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get leaderboardPoints;

  /// No description provided for @leaderboardPredictions.
  ///
  /// In en, this message translates to:
  /// **'Predictions'**
  String get leaderboardPredictions;

  /// No description provided for @searchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTitle;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search teams, leagues, matches...'**
  String get searchHint;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get searchNoResults;

  /// No description provided for @searchCompetitions.
  ///
  /// In en, this message translates to:
  /// **'Competitions'**
  String get searchCompetitions;

  /// No description provided for @searchTeams.
  ///
  /// In en, this message translates to:
  /// **'Teams'**
  String get searchTeams;

  /// No description provided for @searchMatches.
  ///
  /// In en, this message translates to:
  /// **'Matches'**
  String get searchMatches;

  /// No description provided for @teamProfile.
  ///
  /// In en, this message translates to:
  /// **'Team Profile'**
  String get teamProfile;

  /// No description provided for @teamFans.
  ///
  /// In en, this message translates to:
  /// **'{count} fans'**
  String teamFans(int count);

  /// No description provided for @teamSupport.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get teamSupport;

  /// No description provided for @teamNews.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get teamNews;

  /// No description provided for @teamFixtures.
  ///
  /// In en, this message translates to:
  /// **'Fixtures'**
  String get teamFixtures;

  /// No description provided for @teamCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get teamCommunity;

  /// No description provided for @followingTitle.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get followingTitle;

  /// No description provided for @followingEmpty.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t followed any teams or leagues yet.'**
  String get followingEmpty;

  /// No description provided for @followingDiscoverCaption.
  ///
  /// In en, this message translates to:
  /// **'Explore teams and leagues to follow'**
  String get followingDiscoverCaption;

  /// No description provided for @followingDiscover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get followingDiscover;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to FANZONE'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The Global Football Prediction Platform'**
  String get loginSubtitle;

  /// No description provided for @loginPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp number'**
  String get loginPhoneHint;

  /// No description provided for @loginOtpHint.
  ///
  /// In en, this message translates to:
  /// **'Enter WhatsApp verification code'**
  String get loginOtpHint;

  /// No description provided for @loginSendOtp.
  ///
  /// In en, this message translates to:
  /// **'Send Code Via WhatsApp'**
  String get loginSendOtp;

  /// No description provided for @loginVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify Code'**
  String get loginVerify;

  /// No description provided for @loginSkip.
  ///
  /// In en, this message translates to:
  /// **'Continue as Guest'**
  String get loginSkip;

  /// No description provided for @onboardingWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to FANZONE'**
  String get onboardingWelcome;

  /// No description provided for @onboardingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Predict. Compete. Win.'**
  String get onboardingSubtitle;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingDone.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboardingDone;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get commonLoading;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get commonError;

  /// No description provided for @commonEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get commonEmpty;

  /// No description provided for @commonNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network error. Check your connection and try again.'**
  String get commonNetworkError;

  /// No description provided for @commonFet.
  ///
  /// In en, this message translates to:
  /// **'FET'**
  String get commonFet;

  /// No description provided for @commonJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get commonJustNow;

  /// No description provided for @commonMinAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String commonMinAgo(int count);

  /// No description provided for @commonHrAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String commonHrAgo(int count);

  /// No description provided for @commonYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get commonYesterday;

  /// No description provided for @commonDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String commonDaysAgo(int count);

  /// No description provided for @featureUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'{feature} is coming soon'**
  String featureUnavailableTitle(String feature);

  /// No description provided for @featureUnavailableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This feature will be available in a future update.'**
  String get featureUnavailableSubtitle;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get notificationsEmpty;

  /// CTA on featured event banner
  ///
  /// In en, this message translates to:
  /// **'View Event'**
  String get featuredEventBannerCta;

  /// Event hub screen title
  ///
  /// In en, this message translates to:
  /// **'{eventName}'**
  String eventHubTitle(String eventName);

  /// No description provided for @eventMatches.
  ///
  /// In en, this message translates to:
  /// **'Event Matches'**
  String get eventMatches;

  /// No description provided for @eventChallenges.
  ///
  /// In en, this message translates to:
  /// **'Event Challenges'**
  String get eventChallenges;

  /// No description provided for @eventLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Event Leaderboard'**
  String get eventLeaderboard;

  /// No description provided for @trendingGlobally.
  ///
  /// In en, this message translates to:
  /// **'Trending Globally'**
  String get trendingGlobally;

  /// No description provided for @regionAfrica.
  ///
  /// In en, this message translates to:
  /// **'Africa'**
  String get regionAfrica;

  /// No description provided for @regionEurope.
  ///
  /// In en, this message translates to:
  /// **'Europe'**
  String get regionEurope;

  /// No description provided for @regionAmericas.
  ///
  /// In en, this message translates to:
  /// **'Americas'**
  String get regionAmericas;

  /// No description provided for @regionGlobal.
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get regionGlobal;

  /// No description provided for @popularTeamsTitle.
  ///
  /// In en, this message translates to:
  /// **'Popular Teams'**
  String get popularTeamsTitle;

  /// No description provided for @pickYourLocal.
  ///
  /// In en, this message translates to:
  /// **'Pick your local favorite team'**
  String get pickYourLocal;

  /// No description provided for @onboardingLocalHint.
  ///
  /// In en, this message translates to:
  /// **'Search your favorite team from any league worldwide'**
  String get onboardingLocalHint;
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  Future<S> load(Locale locale) {
    return SynchronousFuture<S>(lookupS(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_SDelegate old) => false;
}

S lookupS(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return SEn();
  }

  throw FlutterError(
    'S.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
