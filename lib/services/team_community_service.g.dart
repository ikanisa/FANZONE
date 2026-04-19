// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'team_community_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$teamCommunityStatsHash() =>
    r'c5fcad94329dfbfab25a7eb9761d885ddf7ab6a7';

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

String _$teamAnonymousFansHash() => r'6061e2e04d933b13e4b7930c9b55e9d9a8705c80';

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
    r'caac637927e34997baf003742fdf8e6013ce1b9c';

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

String _$teamNewsHash() => r'24a4e860bab479beff53aeda993e477eeb1d32a6';

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

String _$teamNewsDetailHash() => r'affb266d106223f37a82396de1736aa4233435f9';

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

String _$featuredTeamsRawHash() => r'ed7d0ece505f996857b95a20f6325055d01a9174';

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
    r'ba93619b0f765718300b8ecfeff5197a620183e7';

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
    r'9b3b1475c79ff57cb546bd8376edd8bc067f8a40';

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
