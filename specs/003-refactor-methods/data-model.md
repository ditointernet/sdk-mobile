# Data Model: Refatoração de Métodos

**Feature**: 003-refactor-methods
**Date**: 2025-01-27

## Visão Geral

Este documento descreve as estruturas de dados utilizadas pelos métodos a serem refatorados. Como esta é uma refatoração de código (não alteração de modelo de dados), os modelos permanecem os mesmos, mas a implementação será melhorada.

## Entidades Existentes

### UserData (Dados do Usuário)

**iOS**: `DitoUser`
```swift
struct DitoUser {
  let name: String?
  let email: String?
  let customData: [String: Any]?
}
```

**Android**: `Identify`
```kotlin
data class Identify(val id: String) {
  var name: String? = null
  var email: String? = null
  var customData: CustomData? = null
}
```

**Flutter**: `Map<String, dynamic>`
```dart
{
  'id': String,
  'name': String?,
  'email': String?,
  'customData': Map<String, dynamic>?
}
```

**React Native**: `Record<string, any>`
```typescript
{
  id: string;
  name?: string;
  email?: string;
  customData?: Record<string, any>;
}
```

### EventData (Dados do Evento)

**iOS**: `DitoEvent`
```swift
struct DitoEvent {
  let action: String
  let customData: [String: Any]?
}
```

**Android**: `Event`
```kotlin
data class Event(val action: String, val revenue: Double? = null) {
  var data: CustomData? = null
}
```

**Flutter**: `Map<String, dynamic>`
```dart
{
  'action': String,
  'data': Map<String, dynamic>?
}
```

**React Native**: `Record<string, any>`
```typescript
{
  action: string;
  data?: Record<string, any>;
}
```

### NotificationData (Dados da Notificação)

**iOS**: `DitoNotificationReceived`
```swift
struct DitoNotificationReceived {
  let userId: String
  let logId: String
  let notification: String
  let notificationName: String
}
```

**Android**: `Map<String, String>`
```kotlin
Map<String, String> {
  "notification": String,
  "reference": String,
  "deeplink": String?
}
```

**Flutter**: `Map<String, dynamic>`
```dart
Map<String, dynamic> {
  'userInfo': Map<String, dynamic>,
  'token': String?
}
```

**React Native**: `Record<string, any>`
```typescript
Record<string, any> {
  userInfo: Record<string, any>;
  token?: string;
}
```

### DeviceToken (Token de Dispositivo)

**Todas as Plataformas**: `String`
- Token FCM do dispositivo
- Não pode ser vazio
- Validação aplicada antes de uso

## Evento de Tracking Automático (receiveNotification)

### iOS (Referência)

Quando `notificationRead` é chamado, automaticamente dispara um evento `track` com:

```swift
DitoEvent(
  action: "receive-ios-notification",
  customData: [
    "canal": "mobile",
    "token": token,
    "id-disparo": notificationReceived.logId,
    "id-notificacao": notificationReceived.notification,
    "nome_notificacao": notificationReceived.notificationName,
    "provedor": "firebase",
    "sistema_operacional": "Apple iPhone",
  ]
)
```

### Android (A Implementar)

Quando `notificationRead` é chamado, deve automaticamente disparar um evento `track` com:

```kotlin
Event(
  action = "receive-android-notification",
  data = mapOf(
    "canal" to "mobile",
    "token" to token,
    "id-disparo" to logId,
    "id-notificacao" to notificationId,
    "nome_notificacao" to notificationName,
    "provedor" to "firebase",
    "sistema_operacional" to "Android"
  )
)
```

## Validações

### identify
- `id`: Não pode ser vazio (todas as plataformas)
- `email`: Formato válido se fornecido (todas as plataformas)

### track
- `action`: Não pode ser vazio (todas as plataformas)
- `data`: Opcional (todas as plataformas)

### registerDeviceToken / unregisterDeviceToken
- `token`: Não pode ser vazio (todas as plataformas)

### clickNotification / receiveNotification
- `userInfo`: Deve conter dados válidos da notificação
- `token`: Obrigatório para `receiveNotification` (iOS), opcional para outras plataformas

## Relacionamentos

- **UserData** → **EventData**: Usuário deve ser identificado antes de rastrear eventos (recomendado, não obrigatório)
- **NotificationData** → **EventData**: Recebimento de notificação dispara automaticamente evento de tracking
- **DeviceToken** → **NotificationData**: Token é necessário para processar notificações
