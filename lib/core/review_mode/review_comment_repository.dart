import 'package:uuid/uuid.dart';

import '../../config/app_config.dart';
import '../logging/app_logger.dart';
import '../storage/structured_cache_store.dart';
import '../supabase/supabase_connection.dart';
import 'review_comment.dart';

class ReviewCommentRepository {
  ReviewCommentRepository({SupabaseConnection? connection})
    : _connection = connection ?? SupabaseConnectionImpl();

  static const _localCacheKey = 'app_review_comments_local_v1';

  final SupabaseConnection _connection;

  Future<ReviewCommentSaveResult> save({
    required String route,
    required int viewportWidth,
    required int viewportHeight,
    required String devicePreset,
    required double xPosition,
    required double yPosition,
    required String comment,
    required String severity,
    String? componentKey,
    String? reviewerName,
    String? reviewerContact,
  }) async {
    final now = DateTime.now().toUtc();
    final reviewComment = ReviewComment(
      id: const Uuid().v4(),
      appSlug: AppConfig.appSlug,
      environment: AppConfig.environmentName,
      platform: 'web_review',
      route: route,
      screenName: _screenNameFromRoute(route),
      componentKey: _blankToNull(componentKey),
      viewportWidth: viewportWidth,
      viewportHeight: viewportHeight,
      devicePreset: devicePreset,
      xPosition: xPosition,
      yPosition: yPosition,
      comment: comment.trim(),
      severity: severity,
      status: 'open',
      reviewerName: _blankToNull(reviewerName),
      reviewerContact: _blankToNull(reviewerContact),
      gitBranch: _blankToNull(AppConfig.gitBranch),
      gitCommit: _blankToNull(AppConfig.gitCommit),
      createdAt: now,
      updatedAt: now,
    );

    final client = _connection.client;
    if (client != null) {
      try {
        await client
            .from('app_review_comments')
            .insert(reviewComment.toInsertJson());
        return const ReviewCommentSaveResult(savedRemotely: true);
      } catch (error, stackTrace) {
        AppLogger.e(
          'Failed to persist review comment remotely',
          error,
          stackTrace,
        );
        await _saveLocal(reviewComment);
        return ReviewCommentSaveResult(
          savedRemotely: false,
          errorMessage: error.toString(),
        );
      }
    }

    await _saveLocal(reviewComment);
    return const ReviewCommentSaveResult(savedRemotely: false);
  }

  Future<List<ReviewComment>> readLocalComments() async {
    final snapshot = await StructuredCacheStore.readList(_localCacheKey);
    return snapshot?.payload
            .map(ReviewComment.fromLocalJson)
            .whereType<ReviewComment>()
            .toList(growable: false) ??
        const <ReviewComment>[];
  }

  Future<void> _saveLocal(ReviewComment comment) async {
    final existing = await readLocalComments();
    await StructuredCacheStore.writeList(_localCacheKey, [
      ...existing.map((item) => item.toLocalJson()),
      comment.toLocalJson(),
    ]);
  }

  String _screenNameFromRoute(String route) {
    final uri = Uri.tryParse(route);
    final path = uri?.path ?? route;
    if (path == '/' || path.isEmpty) return 'home';
    return path
        .split('/')
        .where((segment) => segment.trim().isNotEmpty)
        .map((segment) => segment.startsWith(':') ? 'detail' : segment)
        .join('.');
  }

  String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
