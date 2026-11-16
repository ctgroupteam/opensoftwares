class CrmNotification {
  final String id;
  final String userId;
  final String deviceToken;
  final String platform;
  final String notificationType; // 'alerts', 'reminders', 'general', 'task', 'meeting', 'collection'
  final String? title;
  final String? body;
  final Map<String, dynamic> payload;
  final bool isRead;
  final DateTime? acknowledgedAt;
  final DateTime? createdAt;

  CrmNotification({
    required this.id,
    required this.userId,
    required this.deviceToken,
    this.platform = 'android',
    this.notificationType = 'general',
    this.title,
    this.body,
    this.payload = const {},
    this.isRead = false,
    this.acknowledgedAt,
    this.createdAt,
  });

  factory CrmNotification.fromJson(Map<String, dynamic> json) {
    return CrmNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      deviceToken: json['device_token'] as String? ?? '',
      platform: json['platform'] as String? ?? 'android',
      notificationType: json['notification_type'] as String? ?? 'general',
      title: json['title'] as String?,
      body: json['body'] as String?,
      payload: json['payload'] as Map<String, dynamic>? ?? {},
      isRead: json['is_read'] as bool? ?? false,
      acknowledgedAt: json['acknowledged_at'] != null
          ? DateTime.tryParse(json['acknowledged_at'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'device_token': deviceToken,
      'platform': platform,
      'notification_type': notificationType,
      'title': title,
      'body': body,
      'payload': payload,
      'is_read': isRead,
      'acknowledged_at': acknowledgedAt?.toIso8601String(),
    };
  }
}

