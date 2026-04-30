import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet.freezed.dart';
part 'wallet.g.dart';

@freezed
class WalletTransaction with _$WalletTransaction {
  const factory WalletTransaction({
    required String id,
    required String title,
    required int amount,
    required String
    type, // 'earn' | 'spend' | 'transfer_sent' | 'transfer_received'
    required DateTime date,
    required String dateStr,
  }) = _WalletTransaction;

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      _$WalletTransactionFromJson(json);
}
