class VenueChatThreadModel {
  const VenueChatThreadModel({
    required this.id,
    required this.venueId,
    required this.customerUserId,
    required this.topic,
    required this.status,
    required this.lastMessageAt,
    required this.createdAt,
    required this.updatedAt,
    this.orderId,
    this.supportRequestId,
    this.subject,
    this.assignedTo,
    this.resolutionNotes,
    this.closedAt,
    this.closedBy,
    this.messages = const [],
  });

  final String id;
  final String venueId;
  final String customerUserId;
  final String? orderId;
  final String? supportRequestId;
  final String topic;
  final String? subject;
  final String status;
  final String? assignedTo;
  final String? resolutionNotes;
  final DateTime lastMessageAt;
  final DateTime? closedAt;
  final String? closedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<VenueChatMessageModel> messages;

  bool get isOpen => status == 'open' || status == 'in_review';

  String get title {
    final cleanSubject = subject?.trim();
    if (cleanSubject != null && cleanSubject.isNotEmpty) return cleanSubject;
    return '${topic.replaceAll('_', ' ')} chat';
  }

  VenueChatMessageModel? get lastMessage =>
      messages.isEmpty ? null : messages.last;

  factory VenueChatThreadModel.fromJson(
    Map<String, dynamic> json, {
    List<VenueChatMessageModel> messages = const [],
  }) {
    return VenueChatThreadModel(
      id: json['id']?.toString() ?? '',
      venueId: json['venue_id']?.toString() ?? '',
      customerUserId: json['customer_user_id']?.toString() ?? '',
      orderId: _optionalString(json['order_id']),
      supportRequestId: _optionalString(json['support_request_id']),
      topic: json['topic']?.toString() ?? 'general',
      subject: _optionalString(json['subject']),
      status: json['status']?.toString() ?? 'open',
      assignedTo: _optionalString(json['assigned_to']),
      resolutionNotes: _optionalString(json['resolution_notes']),
      lastMessageAt: _date(json['last_message_at']),
      closedAt: _optionalDate(json['closed_at']),
      closedBy: _optionalString(json['closed_by']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
      messages: List.unmodifiable(messages),
    );
  }
}

class VenueChatMessageModel {
  const VenueChatMessageModel({
    required this.id,
    required this.threadId,
    required this.venueId,
    required this.senderRole,
    required this.body,
    required this.messageType,
    required this.moderationStatus,
    required this.createdAt,
    this.senderUserId,
  });

  final String id;
  final String threadId;
  final String venueId;
  final String? senderUserId;
  final String senderRole;
  final String body;
  final String messageType;
  final String moderationStatus;
  final DateTime createdAt;

  bool get isCustomer => senderRole == 'customer';
  bool get isSystem => messageType == 'system';

  factory VenueChatMessageModel.fromJson(Map<String, dynamic> json) {
    return VenueChatMessageModel(
      id: json['id']?.toString() ?? '',
      threadId: json['thread_id']?.toString() ?? '',
      venueId: json['venue_id']?.toString() ?? '',
      senderUserId: _optionalString(json['sender_user_id']),
      senderRole: json['sender_role']?.toString() ?? 'system',
      body: json['body']?.toString() ?? '',
      messageType: json['message_type']?.toString() ?? 'text',
      moderationStatus: json['moderation_status']?.toString() ?? 'visible',
      createdAt: _date(json['created_at']),
    );
  }
}

String? _optionalString(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

DateTime _date(Object? value) {
  return _optionalDate(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? _optionalDate(Object? value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) return null;
  return DateTime.tryParse(text);
}
