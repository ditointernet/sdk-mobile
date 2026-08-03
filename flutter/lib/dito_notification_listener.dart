import 'package:flutter/services.dart';

import 'dito_notification_info.dart';

class DitoNotificationClick {
  const DitoNotificationClick({
    required this.deeplink,
    required this.notificationId,
    required this.reference,
    required this.logId,
    required this.notificationName,
    required this.userId,
    this.actionId = '',
    this.actionLabel = '',
    this.customData = const {},
  });

  final String deeplink;
  final String notificationId;
  final String reference;
  final String logId;
  final String notificationName;
  final String userId;

  /// Id do botão tocado; vazio quando o clique foi no corpo da notificação.
  ///
  /// O [deeplink] deste evento já é o link do próprio botão, resolvido para o OS
  /// do device pelo backend — não é preciso escolher entre destinos aqui.
  final String actionId;

  /// Label do botão tocado; vazio quando o clique foi no corpo da notificação.
  final String actionLabel;

  /// Custom data da campanha, com as variáveis já substituídas pelo backend.
  final Map<String, String> customData;

  /// True quando o clique veio de um botão de ação, não do corpo da notificação.
  bool get isActionClick => actionId.isNotEmpty;

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
      actionId: readString('actionId'),
      actionLabel: readString('actionLabel'),
      customData: readCustomDataField(map['customData']),
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
