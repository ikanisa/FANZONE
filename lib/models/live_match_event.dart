class LiveMatchEvent {
  final String id;
  final String matchId;
  final int? minute;
  final String? eventType;
  final String? team;
  final String? player;
  final String? details;
  final DateTime? createdAt;

  const LiveMatchEvent({
    required this.id,
    required this.matchId,
    this.minute,
    this.eventType,
    this.team,
    this.player,
    this.details,
    this.createdAt,
  });

  factory LiveMatchEvent.fromJson(Map<String, dynamic> json) {
    return LiveMatchEvent(
      id: json['id'] as String,
      matchId: json['match_id'] as String,
      minute: json['minute'] as int?,
      eventType: json['event_type'] as String?,
      team: json['team'] as String?,
      player: json['player'] as String?,
      details: json['details'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }
}
