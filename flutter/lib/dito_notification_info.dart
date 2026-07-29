import 'dito_push_payload.dart';

class DitoNotificationInfo {
  final String id;
  final String notificationId;
  final String reference;
  final String title;
  final String message;
  final String link;
  final DateTime receivedAt;
  final bool isRead;

  /// URL da imagem do push; vazio quando a campanha não tem imagem.
  final String image;

  /// Custom data da campanha já decodificada; vazia quando não há custom data.
  final Map<String, String> customData;

  const DitoNotificationInfo({
    required this.id,
    required this.notificationId,
    required this.reference,
    required this.title,
    required this.message,
    required this.link,
    required this.receivedAt,
    required this.isRead,
    this.image = '',
    this.customData = const {},
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
      image: map['image'] as String? ?? '',
      // O inbox nativo entrega um mapa pronto, mas o parser aceita string JSON
      // também — um SDK nativo mais antigo que o plugin ainda devolve a string crua.
      customData: readCustomDataField(map['customData']),
    );
  }
}

/// Normaliza o `customData` que chega do canal nativo.
///
/// O `MethodChannel` entrega `Map<Object?, Object?>`, e valores não-string podem
/// aparecer, então a conversão é explícita em vez de um cast.
Map<String, String> readCustomDataField(Object? raw) {
  if (raw == null) return const {};
  if (raw is Map) {
    final result = <String, String>{};
    raw.forEach((key, value) {
      if (key == null || value == null) return;
      result[key.toString()] = value.toString();
    });
    return Map.unmodifiable(result);
  }
  return DitoPushPayload.fromData({'custom_data': raw}).customData;
}
