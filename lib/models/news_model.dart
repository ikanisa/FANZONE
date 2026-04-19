import 'package:freezed_annotation/freezed_annotation.dart';

part 'news_model.freezed.dart';
part 'news_model.g.dart';

/// News article model — maps to Supabase `news` table.
@freezed
class NewsModel with _$NewsModel {
  const factory NewsModel({
    required String id,
    required String source,
    required String title,
    required String url,
    @JsonKey(name: 'image_url') String? imageUrl,
    @JsonKey(name: 'published_at') DateTime? publishedAt,
    @JsonKey(name: 'fetched_at') DateTime? fetchedAt,
  }) = _NewsModel;

  factory NewsModel.fromJson(Map<String, dynamic> json) =>
      _$NewsModelFromJson(json);
}
