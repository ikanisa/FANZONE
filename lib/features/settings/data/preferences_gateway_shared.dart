import '../../../models/account_deletion_request_model.dart';

/// Cache key constants for settings gateways.
const marketPreferencesCacheKey = 'preferences.market';
const privacySettingsCachePrefix = 'preferences.privacy.';
const deletionRequestCachePrefix = 'preferences.account_deletion.';
const notificationPreferencesCachePrefix = 'preferences.notifications.';
const notificationLogCachePrefix = 'preferences.notification_log.';
const matchAlertsCachePrefix = 'preferences.match_alerts.';
const deviceTokensCachePrefix = 'preferences.device_tokens.';
const competitionIdsCachePrefix = 'preferences.favourites.competitions.';

/// Serializes an [AccountDeletionRequestModel] for local cache storage.
Map<String, dynamic> accountDeletionToJson(
  AccountDeletionRequestModel request,
) {
  return {
    'id': request.id,
    'status': request.status,
    'requested_at': request.requestedAt.toIso8601String(),
    'reason': request.reason,
    'contact_email': request.contactEmail,
    'resolution_notes': request.resolutionNotes,
    'processed_at': request.processedAt?.toIso8601String(),
  };
}
