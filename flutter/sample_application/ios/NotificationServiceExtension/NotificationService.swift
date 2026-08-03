import DitoSDKNotificationService

/// Notification Service Extension do sample app Flutter.
///
/// No iOS, imagem e botões de um push só existem se o app tiver uma NSE: é ela que
/// baixa a imagem como `UNNotificationAttachment` e registra a `UNNotificationCategory`
/// com as actions. Sem este target o push **ainda é entregue**, mas degrada para título
/// e corpo, sem erro nenhum — foi exatamente o sintoma que motivou a criação deste alvo.
///
/// Tudo mora em `DitoNotificationService`; herdar é a integração inteira. Um app Flutter
/// não é diferente de um nativo aqui: a extension roda no seu próprio processo, sem
/// Flutter engine, e nada disto passa pelo Dart.
///
/// Este target linka `DitoSDKNotificationService`, nunca o `DitoSDK` completo: o SDK usa
/// `UIApplication` e CoreData, indisponíveis numa app extension. Ver o bloco desta
/// extension no `Podfile`.
class NotificationService: DitoNotificationService {}
