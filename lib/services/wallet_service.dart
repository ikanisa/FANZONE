import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/logging/app_logger.dart';
import '../main.dart' show supabaseInitialized;
import '../providers/auth_provider.dart';
import '../models/wallet.dart';

part 'wallet_service.g.dart';

@riverpod
class WalletService extends _$WalletService {
  @override
  FutureOr<int> build() async {
    ref.watch(authStateProvider);

    if (!supabaseInitialized) return 0;

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return 0;

    // Real table: fet_wallets, column: available_balance_fet
    final data = await client
        .from('fet_wallets')
        .select('available_balance_fet')
        .eq('user_id', userId)
        .maybeSingle();

    if (data == null) return 0;
    return (data['available_balance_fet'] as num?)?.toInt() ?? 0;
  }

  /// Transfer FET to another user by phone/email identifier.
  /// Transfer FET to another user by their 6-digit Fan ID.

  Future<void> transferByFanId(String fanId, int amount) async {
    if (!supabaseInitialized) {
      throw StateError('Supabase not initialized');
    }

    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) {
      throw StateError('Not authenticated');
    }

    if (amount <= 0) {
      throw ArgumentError('Amount must be greater than zero');
    }

    if (!RegExp(r'^\d{6}$').hasMatch(fanId)) {
      throw ArgumentError('Fan ID must be exactly 6 digits');
    }

    state = const AsyncValue.loading();

    try {
      await client.rpc(
        'transfer_fet_by_fan_id',
        params: {'p_recipient_fan_id': fanId, 'p_amount_fet': amount},
      );

      ref.invalidateSelf();
      ref.invalidate(transactionServiceProvider);
    } on PostgrestException catch (e) {
      AppLogger.d('Transfer by Fan ID failed: ${e.message}');
      state = AsyncValue.error(e.message, StackTrace.current);
      rethrow;
    } catch (e) {
      AppLogger.d('Transfer by Fan ID failed: $e');
      state = AsyncValue.error('Transfer failed', StackTrace.current);
      rethrow;
    }
  }
}

@riverpod
class TransactionService extends _$TransactionService {
  @override
  FutureOr<List<WalletTransaction>> build() async {
    ref.watch(authStateProvider);

    if (!supabaseInitialized) return const [];

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return const [];

    // Real table: fet_wallet_transactions — let errors propagate
    final data = await client
        .from('fet_wallet_transactions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);

    return (data as List).map((row) {
      final direction = row['direction']?.toString() ?? 'debit';
      final txType = row['tx_type']?.toString() ?? '';
      final type = _mapType(txType, direction);
      return WalletTransaction(
        id: row['id']?.toString() ?? '',
        title: row['title']?.toString() ?? _defaultTitle(txType, direction),
        amount: (row['amount_fet'] as num?)?.toInt() ?? 0,
        type: type,
        date: row['created_at'] != null
            ? DateTime.tryParse(row['created_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
        dateStr: _formatDate(row['created_at']),
      );
    }).toList();
  }

  String _mapType(String txType, String direction) {
    switch (txType) {
      case 'transfer':
      case 'peer_transfer':
        return direction == 'credit' ? 'transfer_received' : 'transfer_sent';
      case 'challenge_payout':
      case 'payout':
      case 'admin_credit':
      case 'bonus':
      case 'reward':
        return 'earn';
      case 'redemption':
        return 'spend';
      case 'team_contribution':
      case 'challenge_stake':
      case 'admin_debit':
        return 'spend';
      default:
        return direction == 'credit' ? 'earn' : 'spend';
    }
  }

  String _defaultTitle(String txType, String direction) {
    switch (txType) {
      case 'transfer':
      case 'peer_transfer':
        return direction == 'credit' ? 'FET received' : 'FET sent';
      case 'challenge_payout':
      case 'payout':
        return 'Challenge payout';
      case 'challenge_stake':
        return 'Challenge stake';
      case 'redemption':
        return 'Reward redeemed';
      case 'team_contribution':
        return 'Team support';
      case 'admin_credit':
        return 'Admin credit';
      case 'admin_debit':
        return 'Admin debit';
      case 'bonus':
        return 'Bonus';
      default:
        return 'Transaction';
    }
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'Unknown';
    final date = DateTime.tryParse(dateValue.toString());
    if (date == null) return 'Unknown';

    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

@riverpod
class FanClubService extends _$FanClubService {
  @override
  FutureOr<List<FanClub>> build() async {
    if (!supabaseInitialized) return const [];

    final client = Supabase.instance.client;
    // Let errors propagate — don't mask as empty
    final data = await client
        .from('fan_clubs')
        .select()
        .order('rank')
        .limit(20);

    return (data as List).map((row) => FanClub.fromJson(row)).toList();
  }
}
