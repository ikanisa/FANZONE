class PredictionSlipModel {
  const PredictionSlipModel({
    required this.id,
    required this.userId,
    required this.status,
    required this.selectionCount,
    required this.projectedEarnFet,
    this.submittedAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String status;
  final int selectionCount;
  final int projectedEarnFet;
  final DateTime? submittedAt;
  final DateTime? updatedAt;

  factory PredictionSlipModel.fromJson(Map<String, dynamic> json) {
    return PredictionSlipModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      status: json['status'] as String? ?? 'submitted',
      selectionCount: (json['selection_count'] as num?)?.toInt() ?? 0,
      projectedEarnFet: (json['projected_earn_fet'] as num?)?.toInt() ?? 0,
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }
}
