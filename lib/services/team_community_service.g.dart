// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'team_community_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$teamCommunityStatsHash() =>
    r'a1d2ca8d04b7a005549e7a89d2c1c2f51263f175';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [teamCommunityStats].
@ProviderFor(teamCommunityStats)
const teamCommunityStatsProvider = TeamCommunityStatsFamily();

/// See also [teamCommunityStats].
class TeamCommunityStatsFamily extends Family<AsyncValue<TeamCommunityStats?>> {
  /// See also [teamCommunityStats].
  const TeamCommunityStatsFamily();

  /// See also [teamCommunityStats].
  TeamCommunityStatsProvider call(String teamId) {
    return TeamCommunityStatsProvider(teamId);
  }

  @override
  TeamCommunityStatsProvider getProviderOverride(
    covariant TeamCommunityStatsProvider provider,
  ) {
    return call(provider.teamId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'teamCommunityStatsProvider';
}

/// See also [teamCommunityStats].
class TeamCommunityStatsProvider
    extends AutoDisposeFutureProvider<TeamCommunityStats?> {
  /// See also [teamCommunityStats].
  TeamCommunityStatsProvider(String teamId)
    : this._internal(
        (ref) => teamCommunityStats(ref as TeamCommunityStatsRef, teamId),
        from: teamCommunityStatsProvider,
        name: r'teamCommunityStatsProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$teamCommunityStatsHash,
        dependencies: TeamCommunityStatsFamily._dependencies,
        allTransitiveDependencies:
            TeamCommunityStatsFamily._allTransitiveDependencies,
        teamId: teamId,
      );

  TeamCommunityStatsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.teamId,
  }) : super.internal();

  final String teamId;

  @override
  Override overrideWith(
    FutureOr<TeamCommunityStats?> Function(TeamCommunityStatsRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: TeamCommunityStatsProvider._internal(
        (ref) => create(ref as TeamCommunityStatsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        teamId: teamId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<TeamCommunityStats?> createElement() {
    return _TeamCommunityStatsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TeamCommunityStatsProvider && other.teamId == teamId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, teamId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin TeamCommunityStatsRef
    on AutoDisposeFutureProviderRef<TeamCommunityStats?> {
  /// The parameter `teamId` of this provider.
  String get teamId;
}

class _TeamCommunityStatsProviderElement
    extends AutoDisposeFutureProviderElement<TeamCommunityStats?>
    with TeamCommunityStatsRef {
  _TeamCommunityStatsProviderElement(super.provider);

  @override
  String get teamId => (origin as TeamCommunityStatsProvider).teamId;
}

String _$teamAnonymousFansHash() => r'b88f7b9e61e866b3f7b7feabb7d4f4c9bdab67d4';

/// See also [teamAnonymousFans].
@ProviderFor(teamAnonymousFans)
const teamAnonymousFansProvider = TeamAnonymousFansFamily();

/// See also [teamAnonymousFans].
class TeamAnonymousFansFamily
    extends Family<AsyncValue<List<AnonymousFanRecord>>> {
  /// See also [teamAnonymousFans].
  const TeamAnonymousFansFamily();

  /// See also [teamAnonymousFans].
  TeamAnonymousFansProvider call(String teamId, {int limit = 50}) {
    return TeamAnonymousFansProvider(teamId, limit: limit);
  }

  @override
  TeamAnonymousFansProvider getProviderOverride(
    covariant TeamAnonymousFansProvider provider,
  ) {
    return call(provider.teamId, limit: provider.limit);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'teamAnonymousFansProvider';
}

/// See also [teamAnonymousFans].
class TeamAnonymousFansProvider
    extends AutoDisposeFutureProvider<List<AnonymousFanRecord>> {
  /// See also [teamAnonymousFans].
  TeamAnonymousFansProvider(String teamId, {int limit = 50})
    : this._internal(
        (ref) => teamAnonymousFans(
          ref as TeamAnonymousFansRef,
          teamId,
          limit: limit,
        ),
        from: teamAnonymousFansProvider,
        name: r'teamAnonymousFansProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$teamAnonymousFansHash,
        dependencies: TeamAnonymousFansFamily._dependencies,
        allTransitiveDependencies:
            TeamAnonymousFansFamily._allTransitiveDependencies,
        teamId: teamId,
        limit: limit,
      );

  TeamAnonymousFansProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.teamId,
    required this.limit,
  }) : super.internal();

  final String teamId;
  final int limit;

  @override
  Override overrideWith(
    FutureOr<List<AnonymousFanRecord>> Function(TeamAnonymousFansRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: TeamAnonymousFansProvider._internal(
        (ref) => create(ref as TeamAnonymousFansRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        teamId: teamId,
        limit: limit,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<AnonymousFanRecord>> createElement() {
    return _TeamAnonymousFansProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TeamAnonymousFansProvider &&
        other.teamId == teamId &&
        other.limit == limit;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, teamId.hashCode);
    hash = _SystemHash.combine(hash, limit.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin TeamAnonymousFansRef
    on AutoDisposeFutureProviderRef<List<AnonymousFanRecord>> {
  /// The parameter `teamId` of this provider.
  String get teamId;

  /// The parameter `limit` of this provider.
  int get limit;
}

class _TeamAnonymousFansProviderElement
    extends AutoDisposeFutureProviderElement<List<AnonymousFanRecord>>
    with TeamAnonymousFansRef {
  _TeamAnonymousFansProviderElement(super.provider);

  @override
  String get teamId => (origin as TeamAnonymousFansProvider).teamId;
  @override
  int get limit => (origin as TeamAnonymousFansProvider).limit;
}

String _$teamContributionHistoryHash() =>
    r'2d427c852465e0f00b44e9d4d8902c290323f525';

/// See also [teamContributionHistory].
@ProviderFor(teamContributionHistory)
const teamContributionHistoryProvider = TeamContributionHistoryFamily();

/// See also [teamContributionHistory].
class TeamContributionHistoryFamily
    extends Family<AsyncValue<List<TeamContributionModel>>> {
  /// See also [teamContributionHistory].
  const TeamContributionHistoryFamily();

  /// See also [teamContributionHistory].
  TeamContributionHistoryProvider call(String teamId) {
    return TeamContributionHistoryProvider(teamId);
  }

  @override
  TeamContributionHistoryProvider getProviderOverride(
    covariant TeamContributionHistoryProvider provider,
  ) {
    return call(provider.teamId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'teamContributionHistoryProvider';
}

/// See also [teamContributionHistory].
class TeamContributionHistoryProvider
    extends AutoDisposeFutureProvider<List<TeamContributionModel>> {
  /// See also [teamContributionHistory].
  TeamContributionHistoryProvider(String teamId)
    : this._internal(
        (ref) =>
            teamContributionHistory(ref as TeamContributionHistoryRef, teamId),
        from: teamContributionHistoryProvider,
        name: r'teamContributionHistoryProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$teamContributionHistoryHash,
        dependencies: TeamContributionHistoryFamily._dependencies,
        allTransitiveDependencies:
            TeamContributionHistoryFamily._allTransitiveDependencies,
        teamId: teamId,
      );

  TeamContributionHistoryProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.teamId,
  }) : super.internal();

  final String teamId;

  @override
  Override overrideWith(
    FutureOr<List<TeamContributionModel>> Function(
      TeamContributionHistoryRef provider,
    )
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: TeamContributionHistoryProvider._internal(
        (ref) => create(ref as TeamContributionHistoryRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        teamId: teamId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<TeamContributionModel>>
  createElement() {
    return _TeamContributionHistoryProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TeamContributionHistoryProvider && other.teamId == teamId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, teamId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin TeamContributionHistoryRef
    on AutoDisposeFutureProviderRef<List<TeamContributionModel>> {
  /// The parameter `teamId` of this provider.
  String get teamId;
}

class _TeamContributionHistoryProviderElement
    extends AutoDisposeFutureProviderElement<List<TeamContributionModel>>
    with TeamContributionHistoryRef {
  _TeamContributionHistoryProviderElement(super.provider);

  @override
  String get teamId => (origin as TeamContributionHistoryProvider).teamId;
}

String _$teamNewsHash() => r'b7fbb780905d31e78b574abf0c95d20d5bc232ce';

/// See also [teamNews].
@ProviderFor(teamNews)
const teamNewsProvider = TeamNewsFamily();

/// See also [teamNews].
class TeamNewsFamily extends Family<AsyncValue<List<TeamNewsModel>>> {
  /// See also [teamNews].
  const TeamNewsFamily();

  /// See also [teamNews].
  TeamNewsProvider call(String teamId, {String? category, int limit = 20}) {
    return TeamNewsProvider(teamId, category: category, limit: limit);
  }

  @override
  TeamNewsProvider getProviderOverride(covariant TeamNewsProvider provider) {
    return call(
      provider.teamId,
      category: provider.category,
      limit: provider.limit,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'teamNewsProvider';
}

/// See also [teamNews].
class TeamNewsProvider extends AutoDisposeFutureProvider<List<TeamNewsModel>> {
  /// See also [teamNews].
  TeamNewsProvider(String teamId, {String? category, int limit = 20})
    : this._internal(
        (ref) => teamNews(
          ref as TeamNewsRef,
          teamId,
          category: category,
          limit: limit,
        ),
        from: teamNewsProvider,
        name: r'teamNewsProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$teamNewsHash,
        dependencies: TeamNewsFamily._dependencies,
        allTransitiveDependencies: TeamNewsFamily._allTransitiveDependencies,
        teamId: teamId,
        category: category,
        limit: limit,
      );

  TeamNewsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.teamId,
    required this.category,
    required this.limit,
  }) : super.internal();

  final String teamId;
  final String? category;
  final int limit;

  @override
  Override overrideWith(
    FutureOr<List<TeamNewsModel>> Function(TeamNewsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: TeamNewsProvider._internal(
        (ref) => create(ref as TeamNewsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        teamId: teamId,
        category: category,
        limit: limit,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<TeamNewsModel>> createElement() {
    return _TeamNewsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TeamNewsProvider &&
        other.teamId == teamId &&
        other.category == category &&
        other.limit == limit;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, teamId.hashCode);
    hash = _SystemHash.combine(hash, category.hashCode);
    hash = _SystemHash.combine(hash, limit.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin TeamNewsRef on AutoDisposeFutureProviderRef<List<TeamNewsModel>> {
  /// The parameter `teamId` of this provider.
  String get teamId;

  /// The parameter `category` of this provider.
  String? get category;

  /// The parameter `limit` of this provider.
  int get limit;
}

class _TeamNewsProviderElement
    extends AutoDisposeFutureProviderElement<List<TeamNewsModel>>
    with TeamNewsRef {
  _TeamNewsProviderElement(super.provider);

  @override
  String get teamId => (origin as TeamNewsProvider).teamId;
  @override
  String? get category => (origin as TeamNewsProvider).category;
  @override
  int get limit => (origin as TeamNewsProvider).limit;
}

String _$teamNewsDetailHash() => r'0c14884781e35c5ffb09efabe6f90d2101148ecc';

/// See also [teamNewsDetail].
@ProviderFor(teamNewsDetail)
const teamNewsDetailProvider = TeamNewsDetailFamily();

/// See also [teamNewsDetail].
class TeamNewsDetailFamily extends Family<AsyncValue<TeamNewsModel?>> {
  /// See also [teamNewsDetail].
  const TeamNewsDetailFamily();

  /// See also [teamNewsDetail].
  TeamNewsDetailProvider call(String newsId) {
    return TeamNewsDetailProvider(newsId);
  }

  @override
  TeamNewsDetailProvider getProviderOverride(
    covariant TeamNewsDetailProvider provider,
  ) {
    return call(provider.newsId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'teamNewsDetailProvider';
}

/// See also [teamNewsDetail].
class TeamNewsDetailProvider extends AutoDisposeFutureProvider<TeamNewsModel?> {
  /// See also [teamNewsDetail].
  TeamNewsDetailProvider(String newsId)
    : this._internal(
        (ref) => teamNewsDetail(ref as TeamNewsDetailRef, newsId),
        from: teamNewsDetailProvider,
        name: r'teamNewsDetailProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$teamNewsDetailHash,
        dependencies: TeamNewsDetailFamily._dependencies,
        allTransitiveDependencies:
            TeamNewsDetailFamily._allTransitiveDependencies,
        newsId: newsId,
      );

  TeamNewsDetailProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.newsId,
  }) : super.internal();

  final String newsId;

  @override
  Override overrideWith(
    FutureOr<TeamNewsModel?> Function(TeamNewsDetailRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: TeamNewsDetailProvider._internal(
        (ref) => create(ref as TeamNewsDetailRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        newsId: newsId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<TeamNewsModel?> createElement() {
    return _TeamNewsDetailProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TeamNewsDetailProvider && other.newsId == newsId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, newsId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin TeamNewsDetailRef on AutoDisposeFutureProviderRef<TeamNewsModel?> {
  /// The parameter `newsId` of this provider.
  String get newsId;
}

class _TeamNewsDetailProviderElement
    extends AutoDisposeFutureProviderElement<TeamNewsModel?>
    with TeamNewsDetailRef {
  _TeamNewsDetailProviderElement(super.provider);

  @override
  String get newsId => (origin as TeamNewsDetailProvider).newsId;
}

String _$featuredTeamsRawHash() => r'727c78618ddb1317116b06c01b3e0f51377271da';

/// See also [featuredTeamsRaw].
@ProviderFor(featuredTeamsRaw)
final featuredTeamsRawProvider =
    AutoDisposeFutureProvider<List<Map<String, dynamic>>>.internal(
      featuredTeamsRaw,
      name: r'featuredTeamsRawProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$featuredTeamsRawHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FeaturedTeamsRawRef =
    AutoDisposeFutureProviderRef<List<Map<String, dynamic>>>;
String _$supportedTeamsServiceHash() =>
    r'893827aeda261a09dac56e732406e382075a7bf3';

/// See also [SupportedTeamsService].
@ProviderFor(SupportedTeamsService)
final supportedTeamsServiceProvider =
    AutoDisposeAsyncNotifierProvider<
      SupportedTeamsService,
      Set<String>
    >.internal(
      SupportedTeamsService.new,
      name: r'supportedTeamsServiceProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$supportedTeamsServiceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SupportedTeamsService = AutoDisposeAsyncNotifier<Set<String>>;
String _$teamContributionServiceHash() =>
    r'd9edd53576c186fb277f996b5dbf70087b078a32';

/// See also [TeamContributionService].
@ProviderFor(TeamContributionService)
final teamContributionServiceProvider =
    AutoDisposeAsyncNotifierProvider<TeamContributionService, void>.internal(
      TeamContributionService.new,
      name: r'teamContributionServiceProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$teamContributionServiceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$TeamContributionService = AutoDisposeAsyncNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
