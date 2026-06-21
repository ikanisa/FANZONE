class VenueSupportRequestModel {
  const VenueSupportRequestModel({
    required this.id,
    required this.venueId,
    required this.userId,
    required this.topic,
    required this.message,
    required this.status,
    required this.createdAt,
    this.orderId,
    this.tableNumber,
    this.resolutionNotes,
    this.resolvedAt,
  });

  final String id;
  final String venueId;
  final String userId;
  final String topic;
  final String message;
  final String status;
  final DateTime createdAt;
  final String? orderId;
  final String? tableNumber;
  final String? resolutionNotes;
  final DateTime? resolvedAt;

  bool get isActive => status == 'open' || status == 'in_review';

  factory VenueSupportRequestModel.fromJson(Map<String, dynamic> json) {
    return VenueSupportRequestModel(
      id: json['id'] as String,
      venueId: json['venue_id'] as String,
      userId: json['user_id'] as String,
      topic: json['topic'] as String? ?? 'general',
      message: json['message'] as String? ?? '',
      status: json['status'] as String? ?? 'open',
      createdAt: DateTime.parse(
        json['created_at'] as String? ??
            DateTime.now().toUtc().toIso8601String(),
      ),
      orderId: json['order_id'] as String?,
      tableNumber: json['table_number'] as String?,
      resolutionNotes: json['resolution_notes'] as String?,
      resolvedAt: json['resolved_at'] == null
          ? null
          : DateTime.parse(json['resolved_at'] as String),
    );
  }
}
