# Quickstart: Validação da Refatoração de Métodos

**Feature**: 003-refactor-methods
**Date**: 2025-01-27

## Objetivo

Este documento descreve como validar que a refatoração foi realizada corretamente, mantendo funcionalidade e melhorando qualidade de código.

## Pré-requisitos

- SDKs nativas iOS e Android funcionando
- Plugins Flutter e React Native funcionando
- Aplicações de exemplo configuradas
- Credenciais de API válidas

## Validação por Plataforma

### iOS

#### 1. Validar Método identify
```swift
// Teste básico
Dito.identify(
  id: "test-user-123",
  name: "Test User",
  email: "test@example.com",
  customData: ["type": "premium"]
)

// Verificar logs - não deve haver erros
```

#### 2. Validar Método track
```swift
// Teste básico
Dito.track(
  action: "test-event",
  data: ["key": "value"]
)

// Verificar logs - não deve haver erros
```

#### 3. Validar Método registerDeviceToken
```swift
// Teste básico
Dito.registerDevice(token: "test-fcm-token")

// Verificar logs - não deve haver erros
```

#### 4. Validar Método unregisterDeviceToken
```swift
// Teste básico
Dito.unregisterDevice(token: "test-fcm-token")

// Verificar logs - não deve haver erros
```

#### 5. Validar Método receiveNotification
```swift
// Teste básico
let userInfo: [AnyHashable: Any] = [
  "notification": "test-notification-id",
  "reference": "test-reference",
  "notificationName": "Test Notification"
]

Dito.notificationRead(userInfo: userInfo, token: "test-fcm-token")

// Verificar logs - deve disparar evento track automaticamente
// Verificar que evento "receive-ios-notification" foi criado
```

#### 6. Validar Método clickNotification
```swift
// Teste básico
let userInfo: [AnyHashable: Any] = [
  "notification": "test-notification-id",
  "reference": "test-reference",
  "deeplink": "app://test"
]

Dito.notificationClick(userInfo: userInfo) { deeplink in
  print("Deeplink: \(deeplink)")
}

// Verificar logs - não deve haver erros
```

#### 7. Validar Qualidade de Código
```bash
# Executar análise estática
swiftlint lint ios/DitoSDK/Sources/Controllers/

# Verificar complexidade ciclomática
# Cada função deve ter < 10
```

---

### Android

#### 1. Validar Método identify
```kotlin
// Teste básico
Dito.identify(
  id = "test-user-123",
  name = "Test User",
  email = "test@example.com",
  customData = mapOf("type" to "premium")
)

// Verificar logs - não deve haver erros
```

#### 2. Validar Método track
```kotlin
// Teste básico
Dito.track(
  action = "test-event",
  data = mapOf("key" to "value")
)

// Verificar logs - não deve haver erros
```

#### 3. Validar Método registerDeviceToken
```kotlin
// Teste básico
Dito.registerDevice(token = "test-fcm-token")

// Verificar logs - não deve haver erros
```

#### 4. Validar Método unregisterDeviceToken
```kotlin
// Teste básico
Dito.unregisterDevice(token = "test-fcm-token")

// Verificar logs - não deve haver erros
```

#### 5. Validar Método receiveNotification (CRÍTICO)
```kotlin
// Teste básico
val userInfo = mapOf(
  "notification" to "test-notification-id",
  "reference" to "test-reference"
)

Dito.notificationRead(userInfo = userInfo)

// Verificar logs - deve disparar evento track automaticamente
// Verificar que evento "receive-android-notification" foi criado
// Este é o comportamento novo que precisa ser implementado
```

#### 6. Validar Método clickNotification
```kotlin
// Teste básico
val userInfo = mapOf(
  "notification" to "test-notification-id",
  "reference" to "test-reference",
  "deeplink" to "app://test"
)

Dito.notificationClick(userInfo = userInfo) { deeplink ->
  println("Deeplink: $deeplink")
}

// Verificar logs - não deve haver erros
```

#### 7. Validar Qualidade de Código
```bash
# Executar análise estática
./gradlew ktlintCheck

# Verificar complexidade ciclomática
# Cada função deve ter < 10
```

---

### Flutter

#### 1. Validar Método identify
```dart
// Teste básico
await DitoSdk.identify(
  id: 'test-user-123',
  name: 'Test User',
  email: 'test@example.com',
  customData: {'type': 'premium'},
);

// Verificar logs - não deve haver erros
```

#### 2. Validar Método track
```dart
// Teste básico
await DitoSdk.track(
  action: 'test-event',
  data: {'key': 'value'},
);

// Verificar logs - não deve haver erros
```

#### 3. Validar Método registerDeviceToken
```dart
// Teste básico
await DitoSdk.registerDeviceToken('test-fcm-token');

// Verificar logs - não deve haver erros
```

#### 4. Validar Método unregisterDeviceToken
```dart
// Teste básico
await DitoSdk.unregisterDeviceToken('test-fcm-token');

// Verificar logs - não deve haver erros
// Verificar se método existe (pode precisar ser implementado)
```

#### 5. Validar Método receiveNotification
```dart
// Teste via método estático do plugin
final handled = DitoSdkPlugin.didReceiveNotificationRequest(
  request,
  'test-fcm-token',
);

// Verificar logs - deve disparar evento track automaticamente
```

#### 6. Validar Método clickNotification
```dart
// Teste via método estático do plugin
final handled = DitoSdkPlugin.didReceiveNotificationClick(
  userInfo,
  (deeplink) => print('Deeplink: $deeplink'),
);

// Verificar logs - não deve haver erros
```

#### 7. Validar Qualidade de Código
```bash
# Executar análise estática
flutter analyze

# Verificar complexidade ciclomática
# Cada função deve ter < 10
```

---

### React Native

#### 1. Validar Método identify
```typescript
// Teste básico
await DitoSdk.identify({
  id: 'test-user-123',
  name: 'Test User',
  email: 'test@example.com',
  customData: { type: 'premium' },
});

// Verificar logs - não deve haver erros
```

#### 2. Validar Método track
```typescript
// Teste básico
await DitoSdk.track({
  action: 'test-event',
  data: { key: 'value' },
});

// Verificar logs - não deve haver erros
```

#### 3. Validar Método registerDeviceToken
```typescript
// Teste básico
await DitoSdk.registerDeviceToken('test-fcm-token');

// Verificar logs - não deve haver erros
```

#### 4. Validar Método unregisterDeviceToken
```typescript
// Teste básico
await DitoSdk.unregisterDeviceToken('test-fcm-token');

// Verificar logs - não deve haver erros
// Verificar se método existe (pode precisar ser implementado)
```

#### 5. Validar Método receiveNotification
```typescript
// Teste via método estático do módulo
const handled = DitoSdkModule.didReceiveNotificationRequest(
  request,
  'test-fcm-token',
);

// Verificar logs - deve disparar evento track automaticamente
```

#### 6. Validar Método clickNotification
```typescript
// Teste via método estático do módulo
DitoSdkModule.didReceiveNotificationClick(
  userInfo,
  (result) => console.log('Result:', result),
  (error) => console.error('Error:', error),
);

// Verificar logs - não deve haver erros
```

#### 7. Validar Qualidade de Código
```bash
# Executar análise estática
npm run lint

# Executar type checking
npm run type-check

# Verificar complexidade ciclomática
# Cada função deve ter < 10
```

---

## Checklist de Validação

### Funcionalidade
- [ ] Todos os métodos funcionam corretamente em iOS
- [ ] Todos os métodos funcionam corretamente em Android
- [ ] Todos os métodos funcionam corretamente em Flutter
- [ ] Todos os métodos funcionam corretamente em React Native
- [ ] `receiveNotification` dispara evento track automaticamente em iOS
- [ ] `receiveNotification` dispara evento track automaticamente em Android (novo)
- [ ] Comportamento é consistente entre plataformas

### Qualidade de Código
- [ ] Código iOS segue padrões de `ios.mdc`
- [ ] Código Android segue padrões de `android.mdc`
- [ ] Código Flutter segue padrões de `flutter.mdc`
- [ ] Código React Native segue padrões de `react-native.mdc`
- [ ] Complexidade ciclomática < 10 em todas as funções
- [ ] Análise estática passa sem warnings críticos
- [ ] Código está legível e bem documentado

### Performance
- [ ] Performance não degradou (< 100ms init, < 16ms ops)
- [ ] Operações assíncronas não bloqueiam thread principal
- [ ] Não há overhead desnecessário

### Compatibilidade
- [ ] APIs públicas não mudaram
- [ ] Código existente continua funcionando
- [ ] Testes existentes continuam passando

---

## Notas

1. **Android receiveNotification**: Este é o comportamento crítico que precisa ser implementado. Deve replicar o comportamento do iOS, disparando automaticamente um evento `track` quando uma notificação é recebida.

2. **unregisterDeviceToken**: Verificar se já está implementado em Flutter e React Native. Se não estiver, implementar durante a refatoração.

3. **Testes**: Se testes quebrarem após refatoração, investigar se comportamento público foi alterado incorretamente.
