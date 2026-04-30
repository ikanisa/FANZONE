class AccountDeletionRequestModel {
  const AccountDeletionRequestModel({
    required this.id,
    required this.status,
    required this.requestedAt,
    this.reason,
    this.contactEmail,
    this.resolutionNotes,
    this.processedAt,
  });

  final String id;
  final String status;
  final DateTime requestedAt;
  final String? reason;
  final String? contactEmail;
  final String? resolutionNotes;
  final DateTime? processedAt;

  bool get isActive => status == 'pending' || status == 'in_review';

  factory AccountDeletionRequestModel.fromJson(Map<String, dynamic> json) {
    return AccountDeletionRequestModel(
      id: json['id'] as String,
      status: json['status'] as String? ?? 'pending',
      requestedAt: DateTime.parse(
        json['requested_at'] as String? ??
            json['created_at'] as String? ??
            DateTime.now().toUtc().toIso8601String(),
      ),
      reason: json['reason'] as String?,
      contactEmail: json['contact_email'] as String?,
      resolutionNotes: json['resolution_notes'] as String?,
      processedAt: json['processed_at'] == null
          ? null
          : DateTime.parse(json['processed_at'] as String),
    );
  }
}
