// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wallet.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$WalletTransactionImpl _$$WalletTransactionImplFromJson(
  Map<String, dynamic> json,
) => _$WalletTransactionImpl(
  id: json['id'] as String,
  title: json['title'] as String,
  amount: (json['amount'] as num).toInt(),
  type: json['type'] as String,
  date: DateTime.parse(json['date'] as String),
  dateStr: json['dateStr'] as String,
);

Map<String, dynamic> _$$WalletTransactionImplToJson(
  _$WalletTransactionImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'amount': instance.amount,
  'type': instance.type,
  'date': instance.date.toIso8601String(),
  'dateStr': instance.dateStr,
};
