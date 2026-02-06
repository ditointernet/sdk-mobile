import 'package:flutter/services.dart';

class DitoNotificationClick {
  const DitoNotificationClick({
    required this.deeplink,
    required this.notificationId,
    required this.reference,
    required this.logId,
    required this.notificationName,
    required this.userId,
  });

  final String deeplink;
  final String notificationId;
  final String reference;
  final String logId;
  final String notificationName;
  final String userId;

  factory DitoNotificationClick.fromMap(Map<Object?, Object?> map) {
    String readString(String key) {
      final value = map[key];
      return value?.toString() ?? '';
    }

    return DitoNotificationClick(
      deeplink: readString('deeplink'),
      notificationId: readString('notificationId'),
      reference: readString('reference'),
      logId: readString('logId'),
      notificationName: readString('notificationName'),
      userId: readString('userId'),
    );
  }
}

class DitoNotificationListener {
  static const EventChannel _channel = EventChannel('br.com.dito/notification_events');

  static Stream<DitoNotificationClick> get onNotificationClick {
    return _channel.receiveBroadcastStream().map((dynamic event) {
      final map = (event as Map<Object?, Object?>);
      return DitoNotificationClick.fromMap(map);
    });
  }
}

