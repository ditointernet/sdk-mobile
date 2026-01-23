# Method Signatures Contract: Refatoração de Métodos

**Feature**: 003-refactor-methods
**Date**: 2025-01-27

## Visão Geral

Este contrato define as assinaturas de métodos que devem ser mantidas consistentes entre plataformas após a refatoração. As assinaturas públicas não devem mudar - apenas a implementação interna será refatorada.

## Métodos Públicos

### 1. identify

**iOS (Swift)**:
```swift
nonisolated public static func identify(
  id: String,
  name: String? = nil,
  email: String? = nil,
  customData: [String: Any]? = nil
)
```

**Android (Kotlin)**:
```kotlin
fun identify(
  id: String,
  name: String? = null,
  email: String? = null,
  customData: Map<String, Any>? = null
)
```

**Flutter (Dart)**:
```dart
Future<void> identify({
  required String id,
  String? name,
  String? email,
  Map<String, dynamic>? customData,
})
```

**React Native (TypeScript)**:
```typescript
static async identify(options: {
  id: string;
  name?: string;
  email?: string;
  customData?: Record<string, any>;
}): Promise<void>
```

**Status**: ✅ Consistente - manter como está

---

### 2. track

**iOS (Swift)**:
```swift
nonisolated public static func track(
  action: String,
  data: [String: Any]? = nil
)
```

**Android (Kotlin)**:
```kotlin
fun track(
  action: String,
  data: Map<String, Any>? = null
)
```

**Flutter (Dart)**:
```dart
Future<void> track({
  required String action,
  Map<String, dynamic>? data,
})
```

**React Native (TypeScript)**:
```typescript
static async track(options: {
  action: string;
  data?: Record<string, any>;
}): Promise<void>
```

**Status**: ✅ Consistente - manter como está

---

### 3. registerDeviceToken

**iOS (Swift)**:
```swift
nonisolated public static func registerDevice(token: String)
```

**Android (Kotlin)**:
```kotlin
fun registerDevice(token: String?)
```

**Flutter (Dart)**:
```dart
Future<void> registerDeviceToken(String token)
```

**React Native (TypeScript)**:
```typescript
static async registerDeviceToken(token: string): Promise<void>
```

**Status**: ✅ Consistente (pequena diferença de nomenclatura aceitável)

---

### 4. unregisterDeviceToken

**iOS (Swift)**:
```swift
nonisolated public static func unregisterDevice(token: String)
```

**Android (Kotlin)**:
```kotlin
fun unregisterDevice(token: String?)
```

**Flutter (Dart)**:
```dart
Future<void> unregisterDeviceToken(String token) // A implementar
```

**React Native (TypeScript)**:
```typescript
static async unregisterDeviceToken(token: string): Promise<void> // A implementar
```

**Status**: ⚠️ Implementar em Flutter e React Native se ainda não existir

---

### 5. clickNotification

**iOS (Swift)**:
```swift
@discardableResult
nonisolated public static func notificationClick(
  userInfo: [AnyHashable: Any],
  callback: ((String) -> Void)? = nil
) -> DitoNotificationReceived
```

**Android (Kotlin)**:
```kotlin
fun notificationClick(
  userInfo: Map<String, String>,
  callback: ((String) -> Unit)? = null
): NotificationResult
```

**Flutter (Dart)**:
```dart
// Método estático no plugin nativo
static bool didReceiveNotificationClick(
  Map<String, dynamic> userInfo,
  Function(String) completion
)
```

**React Native (TypeScript)**:
```typescript
// Método estático no módulo nativo
static didReceiveNotificationClick(
  userInfo: Record<string, any>,
  resolver: (result: Record<string, any>) => void,
  rejecter: (error: Error) => void
)
```

**Status**: ✅ Consistente - manter como está

---

### 6. receiveNotification

**iOS (Swift)**:
```swift
nonisolated public static func notificationRead(
  userInfo: [AnyHashable: Any],
  token: String
)
// Dispara automaticamente evento track com action "receive-ios-notification"
```

**Android (Kotlin)**:
```kotlin
fun notificationRead(userInfo: Map<String, String>)
// Atualmente não dispara evento track - PRECISA IMPLEMENTAR
```

**Flutter (Dart)**:
```dart
// Método estático no plugin nativo
static bool didReceiveNotificationRequest(
  Map<String, dynamic> request,
  String? fcmToken
)
```

**React Native (TypeScript)**:
```typescript
// Método estático no módulo nativo
static didReceiveNotificationRequest(
  request: Record<string, any>,
  fcmToken?: string
): boolean
```

**Status**: ⚠️ Android precisa adicionar tracking automático como iOS

---

## Comportamento Esperado

### identify
- Valida que `id` não está vazio
- Valida formato de `email` se fornecido
- Identifica usuário no Dito CRM
- Deve ser chamado após `initialize`

### track
- Valida que `action` não está vazio
- Rastreia evento no Dito CRM
- Deve ser chamado após `initialize`
- Pode ser chamado antes de `identify` (mas não recomendado)

### registerDeviceToken
- Valida que `token` não está vazio
- Registra token FCM no Dito CRM
- Deve ser chamado após `initialize`
- Recomendado chamar após `identify`

### unregisterDeviceToken
- Valida que `token` não está vazio
- Desregistra token FCM no Dito CRM
- Deve ser chamado após `initialize`

### clickNotification
- Processa clique em notificação
- Retorna deeplink se disponível
- Registra interação no Dito CRM

### receiveNotification
- Processa recebimento de notificação
- **iOS**: Dispara automaticamente evento `track` com dados da notificação
- **Android**: Deve disparar automaticamente evento `track` com dados da notificação (a implementar)
- Registra recebimento no Dito CRM

## Notas de Implementação

1. **Compatibilidade**: Todas as assinaturas públicas devem ser mantidas
2. **Comportamento**: Comportamento público não deve mudar
3. **Performance**: Performance não deve degradar
4. **Erros**: Tratamento de erros deve permanecer consistente
