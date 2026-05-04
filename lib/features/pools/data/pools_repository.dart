import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/gateway_providers.dart';
import '../../../providers/profile_country_provider.dart';

class PoolSummary {
  const PoolSummary({
    required this.id,
    required this.title,
    required this.status,
    required this.scope,
    required this.isOfficial,
    required this.totalMembers,
    required this.totalStakedFet,
    required this.entryFeeFet,
    this.stakeMinFet = 1,
    this.stakeMaxFet = 100000,
    required this.camps,
    this.matchId,
    this.countryCode,
    this.venueId,
    this.venueName,
    this.shareSlug,
    this.shareUrl,
    this.deepLinkUrl,
    this.socialCardUrl,
    this.resultCampId,
    this.hasMyEntry = false,
  });

  factory PoolSummary.fromJson(Map<String, dynamic> json) {
    final rawCamps = json['camps'];
    final camps = rawCamps is List
        ? rawCamps
              .whereType<Map>()
              .map((camp) => PoolCamp.fromJson(Map<String, dynamic>.from(camp)))
              .toList(growable: false)
        : const <PoolCamp>[];

    return PoolSummary(
      id: json['id'] as String,
      matchId: json['match_id']?.toString(),
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? json['title'] as String
          : 'Match pool',
      status: json['status'] as String? ?? 'open',
      scope: json['scope'] as String? ?? 'venue',
      countryCode: json['country_code'] as String?,
      venueId: json['venue_id'] as String?,
      venueName: json['venue_name']?.toString(),
      isOfficial: json['is_official'] == true,
      totalMembers: (json['total_members'] as num?)?.toInt() ?? 0,
      totalStakedFet: (json['total_staked_fet'] as num?)?.toInt() ?? 0,
      entryFeeFet: (json['entry_fee_fet'] as num?)?.toInt() ?? 0,
      stakeMinFet: (json['stake_min_fet'] as num?)?.toInt() ?? 1,
      stakeMaxFet: (json['stake_max_fet'] as num?)?.toInt() ?? 100000,
      shareSlug: json['share_slug'] as String?,
      shareUrl: json['share_url'] as String?,
      deepLinkUrl: json['deep_link_url'] as String?,
      socialCardUrl: json['social_card_url'] as String?,
      resultCampId: json['result_camp_id']?.toString(),
      camps: camps,
    );
  }

  final String id;
  final String? matchId;
  final String title;
  final String status;
  final String scope;
  final String? countryCode;
  final String? venueId;
  final String? venueName;
  final bool isOfficial;
  final int totalMembers;
  final int totalStakedFet;
  final int entryFeeFet;
  final int stakeMinFet;
  final int stakeMaxFet;
  final String? shareSlug;
  final String? shareUrl;
  final String? deepLinkUrl;
  final String? socialCardUrl;
  final String? resultCampId;
  final List<PoolCamp> camps;
  final bool hasMyEntry;

  int get defaultStakeFet => entryFeeFet > 0 ? entryFeeFet : stakeMinFet;
  bool get isOpen => status == 'open';
  bool get isSettled => status == 'settled';

  PoolSummary withVenueName(String? name) {
    return PoolSummary(
      id: id,
      title: title,
      status: status,
      scope: scope,
      isOfficial: isOfficial,
      totalMembers: totalMembers,
      totalStakedFet: totalStakedFet,
      entryFeeFet: entryFeeFet,
      stakeMinFet: stakeMinFet,
      stakeMaxFet: stakeMaxFet,
      camps: camps,
      matchId: matchId,
      countryCode: countryCode,
      venueId: venueId,
      venueName: name ?? venueName,
      shareSlug: shareSlug,
      shareUrl: shareUrl,
      deepLinkUrl: deepLinkUrl,
      socialCardUrl: socialCardUrl,
      resultCampId: resultCampId,
      hasMyEntry: hasMyEntry,
    );
  }

  PoolSummary withMyEntry(bool value) {
    return PoolSummary(
      id: id,
      title: title,
      status: status,
      scope: scope,
      isOfficial: isOfficial,
      totalMembers: totalMembers,
      totalStakedFet: totalStakedFet,
      entryFeeFet: entryFeeFet,
      stakeMinFet: stakeMinFet,
      stakeMaxFet: stakeMaxFet,
      camps: camps,
      matchId: matchId,
      countryCode: countryCode,
      venueId: venueId,
      venueName: venueName,
      shareSlug: shareSlug,
      shareUrl: shareUrl,
      deepLinkUrl: deepLinkUrl,
      socialCardUrl: socialCardUrl,
      resultCampId: resultCampId,
      hasMyEntry: value,
    );
  }
}

class PoolCamp {
  const PoolCamp({
    required this.id,
    required this.label,
    required this.memberCount,
    required this.totalStakedFet,
  });

  factory PoolCamp.fromJson(Map<String, dynamic> json) {
    return PoolCamp(
      id: json['id'] as String,
      label: json['label'] as String? ?? 'Camp',
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
      totalStakedFet: (json['total_staked_fet'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String label;
  final int memberCount;
  final int totalStakedFet;
}

class PoolEntryState {
  const PoolEntryState({
    required this.id,
    required this.campId,
    required this.amountFet,
    required this.status,
    this.payoutFet = 0,
  });

  factory PoolEntryState.fromJson(Map<String, dynamic> json) {
    return PoolEntryState(
      id: json['id']?.toString() ?? '',
      campId: json['camp_id']?.toString() ?? '',
      amountFet: (json['amount_fet'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'active',
      payoutFet: (json['payout_fet'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String campId;
  final int amountFet;
  final String status;
  final int payoutFet;
}

class PoolCreateRequest {
  const PoolCreateRequest({
    required this.matchId,
    required this.scope,
    required this.title,
    required this.stakeMinFet,
    required this.stakeMaxFet,
    this.venueId,
    this.countryId,
  });

  final String matchId;
  final String scope;
  final String title;
  final int stakeMinFet;
  final int stakeMaxFet;
  final String? venueId;
  final String? countryId;
}

abstract interface class PoolsRepository {
  Future<List<PoolSummary>> listPools({String? countryCode});

  Future<List<PoolSummary>> listPoolsForMatch(String matchId);

  Future<PoolSummary?> getPool(String poolId);

  Future<PoolSummary?> getPoolBySlug(String shareSlug);

  Future<PoolSummary?> getPoolByShareLink({
    required String shareSlug,
    String? inviteCode,
    String? source,
  });

  Future<PoolEntryState?> getMyEntry(String poolId);

  Future<Map<String, dynamic>> stakeInPool({
    required String poolId,
    required String campId,
    required int stakeAmountFet,
    String source = 'direct',
    String? inviteCode,
  });

  Future<Map<String, dynamic>> createPool(PoolCreateRequest request);

  Future<Map<String, dynamic>> createInvite(String poolId);

  Future<Map<String, dynamic>> ensureSocialCard(String poolId);
}

class SupabasePoolsRepository implements PoolsRepository {
  SupabasePoolsRepository(this.ref);

  final Ref ref;

  static const _poolColumns =
      'id,match_id,title,status,scope,country_code,venue_id,is_official,'
      'total_members,total_staked_fet,entry_fee_fet,stake_min_fet,'
      'stake_max_fet,share_slug,share_url,deep_link_url,social_card_url,'
      'result_camp_id,camps,created_at';

  @override
  Future<List<PoolSummary>> listPools({String? countryCode}) async {
    final connection = ref.watch(supabaseConnectionProvider);
    final client = connection.client;
    if (client == null) {
      throw StateError(
        'Pools are unavailable until the backend is configured.',
      );
    }

    var request = client.from('match_pool_stats').select(_poolColumns).inFilter(
      'status',
      ['open', 'locked', 'live', 'settling', 'settled'],
    );

    if (countryCode != null && countryCode.trim().isNotEmpty) {
      request = request.eq('country_code', countryCode.trim().toUpperCase());
    }

    final rows = await request.order('created_at', ascending: false).limit(50);

    return _withEntryFlags(
      client,
      await _withVenueNames(client, _parsePools(rows)),
      connection.currentUser?.id,
    );
  }

  @override
  Future<List<PoolSummary>> listPoolsForMatch(String matchId) async {
    final client = ref.watch(supabaseConnectionProvider).client;
    if (client == null) {
      throw StateError(
        'Pools are unavailable until the backend is configured.',
      );
    }

    final rows = await client
        .from('match_pool_stats')
        .select(_poolColumns)
        .eq('match_id', matchId)
        .inFilter('status', ['open', 'locked', 'live', 'settling', 'settled'])
        .order('created_at', ascending: false)
        .limit(20);

    return _withVenueNames(client, _parsePools(rows));
  }

  @override
  Future<PoolSummary?> getPool(String poolId) async {
    final client = ref.watch(supabaseConnectionProvider).client;
    if (client == null) {
      throw StateError(
        'Pools are unavailable until the backend is configured.',
      );
    }

    final row = await client
        .from('match_pool_stats')
        .select(_poolColumns)
        .eq('id', poolId)
        .maybeSingle();
    if (row == null) return null;
    return _withVenueNames(client, [
      PoolSummary.fromJson(Map<String, dynamic>.from(row as Map)),
    ]).then((pools) => pools.first);
  }

  @override
  Future<PoolSummary?> getPoolBySlug(String shareSlug) async {
    return getPoolByShareLink(shareSlug: shareSlug);
  }

  @override
  Future<PoolSummary?> getPoolByShareLink({
    required String shareSlug,
    String? inviteCode,
    String? source,
  }) async {
    final client = ref.watch(supabaseConnectionProvider).client;
    if (client == null) {
      throw StateError(
        'Pools are unavailable until the backend is configured.',
      );
    }

    final sharePayload = await client.rpc(
      'get_public_pool_share',
      params: {
        'p_slug_or_pool_id': shareSlug,
        'p_invite_code': inviteCode,
        'p_source': _safeShareSource(source, inviteCode),
      },
    );
    final share = Map<String, dynamic>.from(sharePayload as Map);
    final poolPayload = share['pool'] is Map
        ? Map<String, dynamic>.from(share['pool'] as Map)
        : const <String, dynamic>{};
    final poolId = poolPayload['id']?.toString();
    if (poolId == null || poolId.isEmpty) return null;

    final row = await client
        .from('match_pool_stats')
        .select(_poolColumns)
        .eq('id', poolId)
        .maybeSingle();
    if (row == null) return null;
    return _withVenueNames(client, [
      PoolSummary.fromJson(Map<String, dynamic>.from(row as Map)),
    ]).then((pools) => pools.first);
  }

  @override
  Future<PoolEntryState?> getMyEntry(String poolId) async {
    final connection = ref.watch(supabaseConnectionProvider);
    final client = connection.client;
    final userId = connection.currentUser?.id;
    if (client == null || userId == null) return null;

    final row = await client
        .from('match_pool_entries')
        .select('id,camp_id,amount_fet,status,payout_fet')
        .eq('pool_id', poolId)
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    return PoolEntryState.fromJson(Map<String, dynamic>.from(row as Map));
  }

  @override
  Future<Map<String, dynamic>> stakeInPool({
    required String poolId,
    required String campId,
    required int stakeAmountFet,
    String source = 'direct',
    String? inviteCode,
  }) async {
    final client = ref.watch(supabaseConnectionProvider).client;
    if (client == null) {
      throw StateError('Pool staking is unavailable right now.');
    }

    final response = await client.rpc(
      'stake_fet',
      params: {
        'p_pool_id': poolId,
        'p_camp_id': campId,
        'p_stake_amount': stakeAmountFet,
        'p_source': source,
        'p_invite_code': inviteCode,
      },
    );
    return Map<String, dynamic>.from(response as Map);
  }

  @override
  Future<Map<String, dynamic>> createPool(PoolCreateRequest request) async {
    final client = ref.watch(supabaseConnectionProvider).client;
    if (client == null) {
      throw StateError('Pool creation is unavailable right now.');
    }

    final response = await client.rpc(
      'create_pool',
      params: {
        'p_match_id': request.matchId,
        'p_scope': request.scope,
        'p_country_id': request.countryId,
        'p_venue_id': request.venueId,
        'p_title': request.title,
        'p_stake_min': request.stakeMinFet,
        'p_stake_max': request.stakeMaxFet,
        'p_creator_reward_per_qualified_member': 1,
        'p_rules_json': {
          'min_qualified_stake': request.stakeMinFet,
          'release_path': 'mobile_guest_create_pool',
        },
        'p_allow_multiple': false,
      },
    );
    final result = Map<String, dynamic>.from(response as Map);
    final poolId = result['pool_id']?.toString();
    if (poolId != null && poolId.isNotEmpty) {
      try {
        final card = await ensureSocialCard(poolId);
        final url = card['social_card_url']?.toString();
        if (url != null && url.isNotEmpty) {
          result['social_card_url'] = url;
        }
      } catch (_) {
        // Pool creation should not fail because a share card worker is down.
      }
    }
    return result;
  }

  @override
  Future<Map<String, dynamic>> createInvite(String poolId) async {
    final client = ref.watch(supabaseConnectionProvider).client;
    if (client == null) {
      throw StateError('Pool sharing is unavailable right now.');
    }

    final response = await client.rpc(
      'create_match_pool_invite',
      params: {'p_pool_id': poolId},
    );
    return Map<String, dynamic>.from(response as Map);
  }

  @override
  Future<Map<String, dynamic>> ensureSocialCard(String poolId) async {
    final client = ref.watch(supabaseConnectionProvider).client;
    if (client == null) {
      throw StateError('Pool share cards are unavailable right now.');
    }

    final response = await client.functions.invoke(
      'generate-pool-social-card',
      body: {'pool_id': poolId},
    );
    return Map<String, dynamic>.from(
      response.data as Map<String, dynamic>? ?? const {},
    );
  }

  List<PoolSummary> _parsePools(Object? rows) {
    return (rows as List)
        .whereType<Map>()
        .map((row) => PoolSummary.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<List<PoolSummary>> _withVenueNames(
    dynamic client,
    List<PoolSummary> pools,
  ) async {
    final venueIds = pools
        .map((pool) => pool.venueId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (venueIds.isEmpty) return pools;

    final rows = await client
        .from('venues')
        .select('id,name')
        .inFilter('id', venueIds);
    final names = {
      for (final row in (rows as List).whereType<Map>())
        row['id']?.toString() ?? '': row['name']?.toString(),
    };

    return pools
        .map((pool) => pool.withVenueName(names[pool.venueId]))
        .toList(growable: false);
  }

  Future<List<PoolSummary>> _withEntryFlags(
    dynamic client,
    List<PoolSummary> pools,
    String? userId,
  ) async {
    if (userId == null || userId.isEmpty || pools.isEmpty) return pools;

    final poolIds = pools.map((pool) => pool.id).toList(growable: false);
    final rows = await client
        .from('match_pool_entries')
        .select('pool_id')
        .eq('user_id', userId)
        .eq('status', 'active')
        .inFilter('pool_id', poolIds);

    final enteredPoolIds = {
      for (final row in (rows as List).whereType<Map>())
        row['pool_id']?.toString(),
    }..remove(null);

    if (enteredPoolIds.isEmpty) return pools;
    return pools
        .map((pool) => pool.withMyEntry(enteredPoolIds.contains(pool.id)))
        .toList(growable: false);
  }
}

String _safeShareSource(String? source, String? inviteCode) {
  if (inviteCode != null && inviteCode.trim().isNotEmpty) {
    return 'invite_link';
  }
  switch (source) {
    case 'venue_qr':
    case 'social_share':
    case 'web_fallback':
    case 'deep_link':
      return source!;
    default:
      return 'direct';
  }
}

final poolsRepositoryProvider = Provider<PoolsRepository>((ref) {
  return SupabasePoolsRepository(ref);
});

final poolsProvider = FutureProvider.autoDispose<List<PoolSummary>>((ref) {
  final countryCode = ref.watch(profileCountryProvider);
  return ref.watch(poolsRepositoryProvider).listPools(countryCode: countryCode);
});

final poolDetailProvider = FutureProvider.autoDispose
    .family<PoolSummary?, String>((ref, poolId) {
      return ref.watch(poolsRepositoryProvider).getPool(poolId);
    });

final poolBySlugProvider = FutureProvider.autoDispose
    .family<PoolSummary?, String>((ref, shareSlug) {
      return ref.watch(poolsRepositoryProvider).getPoolBySlug(shareSlug);
    });

class PoolShareLookup {
  const PoolShareLookup({
    required this.shareSlug,
    this.inviteCode,
    this.source,
  });

  final String shareSlug;
  final String? inviteCode;
  final String? source;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PoolShareLookup &&
            shareSlug == other.shareSlug &&
            inviteCode == other.inviteCode &&
            source == other.source;
  }

  @override
  int get hashCode => Object.hash(shareSlug, inviteCode, source);
}

final poolShareProvider = FutureProvider.autoDispose
    .family<PoolSummary?, PoolShareLookup>((ref, lookup) {
      return ref
          .watch(poolsRepositoryProvider)
          .getPoolByShareLink(
            shareSlug: lookup.shareSlug,
            inviteCode: lookup.inviteCode,
            source: lookup.source,
          );
    });

final matchPoolsProvider = FutureProvider.autoDispose
    .family<List<PoolSummary>, String>((ref, matchId) {
      return ref.watch(poolsRepositoryProvider).listPoolsForMatch(matchId);
    });

final poolEntryStateProvider = FutureProvider.autoDispose
    .family<PoolEntryState?, String>((ref, poolId) {
      return ref.watch(poolsRepositoryProvider).getMyEntry(poolId);
    });
