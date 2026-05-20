class DitoNotificationInfo {
  final String id;
  final String notificationId;
  final String reference;
  final String title;
  final String message;
  final String link;
  final DateTime receivedAt;
  final bool isRead;

  const DitoNotificationInfo({
    required this.id,
    required this.notificationId,
    required this.reference,
    required this.title,
    required this.message,
    required this.link,
    required this.receivedAt,
    required this.isRead,
  });

  factory DitoNotificationInfo.fromMap(Map<Object?, Object?> map) {
    return DitoNotificationInfo(
      id: map['id'] as String? ?? '',
      notificationId: map['notificationId'] as String? ?? '',
      reference: map['reference'] as String? ?? '',
      title: map['title'] as String? ?? '',
      message: map['message'] as String? ?? '',
      link: map['link'] as String? ?? '',
      receivedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['receivedAt'] as num?)?.toInt() ?? 0,
      ),
      isRead: map['isRead'] as bool? ?? false,
    );
  }
}
