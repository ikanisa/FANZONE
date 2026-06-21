class AccountDataRequestModel {
  const AccountDataRequestModel({
    required this.id,
    required this.status,
    required this.requestedAt,
    required this.requestType,
    this.reason,
    this.contactEmail,
    this.resolutionNotes,
    this.processedAt,
  });

  final String id;
  final String status;
  final DateTime requestedAt;
  final String requestType;
  final String? reason;
  final String? contactEmail;
  final String? resolutionNotes;
  final DateTime? processedAt;

  bool get isActive => status == 'pending' || status == 'in_review';

  factory AccountDataRequestModel.fromJson(Map<String, dynamic> json) {
    return AccountDataRequestModel(
      id: json['id'] as String,
      status: json['status'] as String? ?? 'pending',
      requestedAt: DateTime.parse(
        json['requested_at'] as String? ??
            json['created_at'] as String? ??
            DateTime.now().toUtc().toIso8601String(),
      ),
      requestType: json['request_type'] as String? ?? 'export',
      reason: json['reason'] as String?,
      contactEmail: json['contact_email'] as String?,
      resolutionNotes: json['resolution_notes'] as String?,
      processedAt: json['processed_at'] == null
          ? null
          : DateTime.parse(json['processed_at'] as String),
    );
  }
}
