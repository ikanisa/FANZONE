class ReviewComment {
  const ReviewComment({
    required this.id,
    required this.appSlug,
    required this.environment,
    required this.platform,
    required this.route,
    this.screenName,
    this.componentKey,
    this.viewportWidth,
    this.viewportHeight,
    this.devicePreset,
    this.xPosition,
    this.yPosition,
    required this.comment,
    required this.severity,
    required this.status,
    this.reviewerName,
    this.reviewerContact,
    this.screenshotUrl,
    this.gitBranch,
    this.gitCommit,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String appSlug;
  final String environment;
  final String platform;
  final String route;
  final String? screenName;
  final String? componentKey;
  final int? viewportWidth;
  final int? viewportHeight;
  final String? devicePreset;
  final double? xPosition;
  final double? yPosition;
  final String comment;
  final String severity;
  final String status;
  final String? reviewerName;
  final String? reviewerContact;
  final String? screenshotUrl;
  final String? gitBranch;
  final String? gitCommit;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toInsertJson() => {
    'app_slug': appSlug,
    'environment': environment,
    'platform': platform,
    'route': route,
    'screen_name': screenName,
    'component_key': componentKey,
    'viewport_width': viewportWidth,
    'viewport_height': viewportHeight,
    'device_preset': devicePreset,
    'x_position': xPosition,
    'y_position': yPosition,
    'comment': comment,
    'severity': severity,
    'status': status,
    'reviewer_name': reviewerName,
    'reviewer_contact': reviewerContact,
    'screenshot_url': screenshotUrl,
    'git_branch': gitBranch,
    'git_commit': gitCommit,
  };

  Map<String, dynamic> toLocalJson() => {
    'id': id,
    ...toInsertJson(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  static ReviewComment? fromLocalJson(Map<String, dynamic> json) {
    final id = json['id']?.toString();
    final appSlug = json['app_slug']?.toString();
    final environment = json['environment']?.toString();
    final route = json['route']?.toString();
    final comment = json['comment']?.toString();
    final createdAt = DateTime.tryParse(json['created_at']?.toString() ?? '');
    final updatedAt = DateTime.tryParse(json['updated_at']?.toString() ?? '');
    if (id == null ||
        appSlug == null ||
        environment == null ||
        route == null ||
        comment == null ||
        createdAt == null ||
        updatedAt == null) {
      return null;
    }

    return ReviewComment(
      id: id,
      appSlug: appSlug,
      environment: environment,
      platform: json['platform']?.toString() ?? 'web_review',
      route: route,
      screenName: json['screen_name']?.toString(),
      componentKey: json['component_key']?.toString(),
      viewportWidth: _intValue(json['viewport_width']),
      viewportHeight: _intValue(json['viewport_height']),
      devicePreset: json['device_preset']?.toString(),
      xPosition: _doubleValue(json['x_position']),
      yPosition: _doubleValue(json['y_position']),
      comment: comment,
      severity: json['severity']?.toString() ?? 'medium',
      status: json['status']?.toString() ?? 'open',
      reviewerName: json['reviewer_name']?.toString(),
      reviewerContact: json['reviewer_contact']?.toString(),
      screenshotUrl: json['screenshot_url']?.toString(),
      gitBranch: json['git_branch']?.toString(),
      gitCommit: json['git_commit']?.toString(),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static int? _intValue(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static double? _doubleValue(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}

class ReviewCommentSaveResult {
  const ReviewCommentSaveResult({
    required this.savedRemotely,
    this.errorMessage,
  });

  final bool savedRemotely;
  final String? errorMessage;
}
