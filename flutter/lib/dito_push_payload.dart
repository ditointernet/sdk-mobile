import 'dart:convert';

/// Botão de ação de uma notificação rica.
///
/// O backend já resolve o [link] para o sistema operacional do device, então cada
/// botão carrega exatamente um destino — não existe par android/ios aqui.
class DitoPushAction {
  const DitoPushAction({
    required this.id,
    required this.label,
    required this.link,
  });

  /// Identificador do botão (`^[a-z0-9_]{1,32}$`), único dentro do push.
  final String id;

  /// Texto exibido no botão (até 25 caracteres).
  final String label;

  /// URL ou deeplink aberto ao tocar no botão.
  final String link;

  @override
  String toString() => 'DitoPushAction(id: $id, label: $label, link: $link)';
}

/// Campos ricos de um push da Dito, extraídos do data map do FCM.
///
/// O uso normal é dentro de um handler do `firebase_messaging`:
///
/// ```dart
/// FirebaseMessaging.onMessage.listen((message) {
///   final payload = DitoPushPayload.fromData(message.data);
///   if (payload.hasRichContent) {
///     debugPrint('imagem=${payload.image} botões=${payload.actions.length}');
///   }
/// });
/// ```
///
/// O parsing é deliberadamente leniente: `actions` e `custom_data` viajam como
/// strings JSON dentro do data map, e um payload malformado devolve o campo vazio
/// em vez de lançar — mesma postura dos parsers nativos, porque derrubar o handler
/// de push por causa de um campo opcional é pior que ignorá-lo.
class DitoPushPayload {
  const DitoPushPayload({
    this.image = '',
    this.actions = const [],
    this.customData = const {},
  });

  /// URL da imagem (`data.image`); vazio quando a campanha não tem imagem.
  final String image;

  /// Botões declarados em `data.actions`, no máximo [maxActions].
  final List<DitoPushAction> actions;

  /// `data.custom_data`, com as variáveis já substituídas pelo backend.
  final Map<String, String> customData;

  /// O contrato garante no máximo 2 botões; o excedente é descartado.
  static const int maxActions = 2;

  /// True quando o push traz pelo menos um dos três campos ricos.
  bool get hasRichContent =>
      image.isNotEmpty || actions.isNotEmpty || customData.isNotEmpty;

  /// Extrai os campos ricos de um data map de push (ex.: `RemoteMessage.data`).
  factory DitoPushPayload.fromData(Map<dynamic, dynamic>? data) {
    if (data == null || data.isEmpty) return const DitoPushPayload();
    return DitoPushPayload(
      image: _readString(data, 'image'),
      actions: _parseActions(_readRaw(data, 'actions')),
      customData: _parseCustomData(_readRaw(data, 'custom_data')),
    );
  }

  /// Procura [key] no mapa e, se não achar, dentro de um `data` aninhado.
  ///
  /// O blob legado `data.data` é uma **string** JSON, não um mapa, então a checagem
  /// de tipo garante que ele nunca é confundido com o nível aninhado.
  static Object? _readRaw(Map<dynamic, dynamic> data, String key) {
    final direct = data[key];
    if (direct != null) return direct;
    final nested = data['data'];
    if (nested is Map) return nested[key];
    return null;
  }

  static String _readString(Map<dynamic, dynamic> data, String key) {
    final value = _readRaw(data, key);
    if (value is String) return value.trim();
    return '';
  }

  static List<DitoPushAction> _parseActions(Object? raw) {
    final decoded = _decode(raw);
    if (decoded is! List) return const [];

    final actions = <String, DitoPushAction>{};
    for (final item in decoded) {
      if (actions.length >= maxActions) break;
      if (item is! Map) continue;
      final id = _stringField(item, 'id');
      final label = _stringField(item, 'label');
      if (id.isEmpty || label.isEmpty) continue;
      if (actions.containsKey(id)) continue;
      actions[id] = DitoPushAction(
        id: id,
        label: label,
        link: _stringField(item, 'link'),
      );
    }
    return List.unmodifiable(actions.values);
  }

  static Map<String, String> _parseCustomData(Object? raw) {
    final decoded = _decode(raw);
    if (decoded is! Map) return const {};

    final result = <String, String>{};
    decoded.forEach((key, value) {
      if (key == null || value == null) return;
      final name = key.toString().trim();
      if (name.isEmpty) return;
      result[name] = value is String ? value : value.toString();
    });
    return Map.unmodifiable(result);
  }

  /// Aceita tanto a string JSON que o backend emite quanto uma estrutura já
  /// decodificada, porque o canal nativo do inbox entrega mapas prontos.
  static Object? _decode(Object? raw) {
    if (raw == null) return null;
    if (raw is Map || raw is List) return raw;
    if (raw is! String) return null;
    final text = raw.trim();
    if (text.isEmpty) return null;
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }

  static String _stringField(Map<dynamic, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return '';
    return value.toString().trim();
  }

  @override
  String toString() =>
      'DitoPushPayload(image: $image, actions: ${actions.length}, '
      'customData: ${customData.length})';
}
