# Quickstart Guide

**Feature**: Plugin Flutter dito_sdk
**Date**: 2025-01-27

## Cenários de Teste Rápido

### Cenário 1: Inicialização Básica

**Objetivo**: Verificar que o plugin pode ser inicializado com credenciais válidas

**Passos**:
1. Importar o plugin: `import 'package:dito_sdk/dito_sdk.dart';`
2. Chamar `await DitoSdk.initialize(apiKey: "test-key", apiSecret: "test-secret");`
3. Verificar que não lança exceção

**Resultado Esperado**: Plugin inicializado com sucesso, pronto para uso

**Validação**: Nenhuma exceção lançada

---

### Cenário 2: Identificação de Usuário

**Objetivo**: Verificar que um usuário pode ser identificado no CRM

**Pré-requisito**: Plugin inicializado (Cenário 1)

**Passos**:
1. Chamar `await DitoSdk.identify(id: "user123", name: "Test User", email: "test@example.com");`
2. Verificar que não lança exceção

**Resultado Esperado**: Usuário identificado no CRM Dito

**Validação**: Nenhuma exceção lançada, verificar no dashboard Dito se usuário aparece

---

### Cenário 3: Tracking de Evento

**Objetivo**: Verificar que eventos podem ser registrados

**Pré-requisito**: Plugin inicializado (Cenário 1)

**Passos**:
1. Chamar `await DitoSdk.track(action: "view_product", data: {"product_id": "123", "price": 99.99});`
2. Verificar que não lança exceção

**Resultado Esperado**: Evento registrado no CRM Dito

**Validação**: Nenhuma exceção lançada, verificar no dashboard Dito se evento aparece

---

### Cenário 4: Registro de Token de Dispositivo

**Objetivo**: Verificar que token de push notification pode ser registrado

**Pré-requisito**: Plugin inicializado (Cenário 1)

**Passos**:
1. Obter token FCM/APNS (ex: via Firebase Messaging)
2. Chamar `await DitoSdk.registerDeviceToken("fcm-token-here");`
3. Verificar que não lança exceção

**Resultado Esperado**: Token registrado para receber push notifications da Dito

**Validação**: Nenhuma exceção lançada

---

### Cenário 5: Tratamento de Erro - Não Inicializado

**Objetivo**: Verificar que métodos retornam erro apropriado se plugin não foi inicializado

**Passos**:
1. Tentar chamar `await DitoSdk.identify(id: "user123");` sem inicializar
2. Capturar exceção

**Resultado Esperado**: `PlatformException` com código `NOT_INITIALIZED`

**Validação**: Exceção capturada com código correto

---

### Cenário 6: Tratamento de Erro - Parâmetros Inválidos

**Objetivo**: Verificar validação de parâmetros

**Pré-requisito**: Plugin inicializado (Cenário 1)

**Passos**:
1. Tentar chamar `await DitoSdk.identify(id: "");` com id vazio
2. Capturar exceção

**Resultado Esperado**: `PlatformException` com código `INVALID_PARAMETERS`

**Validação**: Exceção capturada com código correto e mensagem descritiva

---

### Cenário 7: Push Notification - Android (Interceptação)

**Objetivo**: Verificar que notificações com channel="Dito" são processadas pela SDK

**Pré-requisito**: Plugin inicializado, Firebase Messaging configurado

**Passos**:
1. No `FirebaseMessagingService.onMessageReceived()`:
   ```kotlin
   val handled = DitoSdkPlugin.handleNotification(this, remoteMessage)
   if (handled) {
       return // Notificação processada pela Dito
   }
   // Processar normalmente
   ```
2. Enviar notificação com `data: {"channel": "Dito"}`
3. Verificar que SDK Dito processa a notificação via `br.com.dito.ditosdk.Dito`

**Resultado Esperado**: Notificação processada pela SDK Dito, método retorna `true`

**Validação**: Método retorna `true`, notificação não processada pelo app normalmente

---

### Cenário 8: Push Notification - iOS (Interceptação)

**Objetivo**: Verificar que notificações com channel="Dito" são processadas pela SDK

**Pré-requisito**: Plugin inicializado, UNUserNotificationCenter configurado, FCM token disponível

**Passos**:
1. **IMPORTANTE**: Garantir ordem de inicialização (iOS 18+):
   ```swift
   // 1. Firebase PRIMEIRO
   FirebaseApp.configure()
   Messaging.messaging().delegate = self

   // 2. Dito SDK DEPOIS
   Dito.shared.configure()
   ```
2. No `UNUserNotificationCenterDelegate.willPresent`:
   ```swift
   let handled = SwiftDitoSdkPlugin.didReceiveNotificationRequest(
       request,
       fcmToken: fcmToken
   )
   if handled {
       completionHandler([]) // Processado pela Dito
       return
   }
   // Processar normalmente
   completionHandler([.banner, .sound, .badge])
   ```
3. No `UNUserNotificationCenterDelegate.didReceive`:
   ```swift
   let handled = SwiftDitoSdkPlugin.didReceiveNotificationRequest(
       request,
       fcmToken: fcmToken
   )
   // notificationClick é chamado automaticamente pelo plugin
   ```
4. Enviar notificação com `userInfo: ["channel": "Dito"]`
5. Verificar que `Dito.notificationRead` e `Dito.notificationClick` são chamados

**Resultado Esperado**:
- `Dito.notificationRead(with:token:)` chamado quando notificação chega
- `Dito.notificationClick(with:)` chamado quando usuário interage
- Método retorna `true`

**Validação**: Método retorna `true`, métodos da SDK Dito são chamados corretamente

---

### Cenário 9: Push Notification - Não Dito (Ignorar)

**Objetivo**: Verificar que notificações sem channel="Dito" não são processadas pela SDK

**Passos**:
1. Enviar notificação com `data: {"channel": "other"}` (Android) ou `userInfo: ["channel": "other"]` (iOS)
2. Chamar método de interceptação
3. Verificar retorno

**Resultado Esperado**: Método retorna `false`, notificação processada normalmente pelo app

**Validação**: Método retorna `false`, app processa notificação normalmente

---

## Fluxo Completo de Integração

### 1. Adicionar Dependência

```yaml
# pubspec.yaml
dependencies:
  dito_sdk: ^1.0.0
```

### 2. Inicializar no App

```dart
import 'package:dito_sdk/dito_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar plugin
  await DitoSdk.initialize(
    apiKey: "sua-api-key",
    apiSecret: "seu-api-secret",
  );

  runApp(MyApp());
}
```

### 3. Identificar Usuário

```dart
await DitoSdk.identify(
  id: "user-123",
  name: "João Silva",
  email: "joao@example.com",
  customData: {
    "plan": "premium",
    "signup_date": "2025-01-27",
  },
);
```

### 4. Registrar Eventos

```dart
await DitoSdk.track(
  action: "purchase",
  data: {
    "product_id": "prod-123",
    "amount": 99.99,
    "currency": "BRL",
  },
);
```

### 5. Configurar Push Notifications (Android)

```kotlin
// No FirebaseMessagingService
override fun onMessageReceived(remoteMessage: RemoteMessage) {
    val handled = DitoSdkPlugin.handleNotification(this, remoteMessage)
    if (handled) {
        return // Processado pela Dito SDK
    }
    // Seu código normal de processamento
}
```

### 6. Configurar Push Notifications (iOS)

**⚠️ ORDEM CRÍTICA (iOS 18+)**: Firebase deve ser configurado ANTES do Dito SDK

```swift
// No AppDelegate.didFinishLaunchingWithOptions
func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {
    // 1. Firebase PRIMEIRO
    FirebaseApp.configure()
    Messaging.messaging().delegate = self

    // 2. Dito SDK DEPOIS
    Dito.shared.configure()

    // 3. Notificações
    UNUserNotificationCenter.current().delegate = self

    return true
}

// No UNUserNotificationCenterDelegate
func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
) {
    let handled = SwiftDitoSdkPlugin.didReceiveNotificationRequest(
        notification.request,
        fcmToken: fcmToken // Token FCM necessário para notificationRead
    )
    if handled {
        completionHandler([]) // Processado pela Dito (notificationRead chamado)
        return
    }
    // Seu código normal de processamento
    completionHandler([.banner, .list, .sound, .badge])
}

func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
) {
    let handled = SwiftDitoSdkPlugin.didReceiveNotificationRequest(
        response.notification.request,
        fcmToken: fcmToken
    )
    // notificationClick é chamado automaticamente pelo plugin se handled == true
    completionHandler()
}
```

## Checklist de Validação

- [ ] Plugin inicializa sem erros
- [ ] Usuário pode ser identificado
- [ ] Eventos são registrados corretamente
- [ ] Token de dispositivo é registrado
- [ ] Erros são tratados adequadamente
- [ ] Push notifications com channel="Dito" são interceptadas
- [ ] Push notifications sem channel="Dito" são ignoradas
- [ ] Comportamento idêntico entre iOS e Android
