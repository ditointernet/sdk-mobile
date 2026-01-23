# MethodChannel API Contract

**Channel Name**: `br.com.dito/dito_sdk`
**Feature**: Plugin Flutter dito_sdk
**Date**: 2025-01-27

## Métodos Disponíveis

### initialize

**Descrição**: Inicializa o plugin com credenciais da Dito

**Método Dart**:
```dart
static Future<void> initialize({
  required String apiKey,
  required String apiSecret,
})
```

**Chamada MethodChannel**:
- **Method**: `initialize`
- **Arguments**: `{"apiKey": String, "apiSecret": String}`

**Resposta**:
- **Success**: `null` (void)
- **Error**: `PlatformException` com código `INITIALIZATION_FAILED` ou `INVALID_CREDENTIALS`

**Comportamento Nativo**:
- Android: Chama `br.com.dito.ditosdk.Dito.init(apiKey, apiSecret)`
- iOS: Chama `Dito.shared.configure()` (configuração via Info.plist ou programática)

---

### identify

**Descrição**: Identifica um usuário no CRM Dito

**Método Dart**:
```dart
static Future<void> identify({
  required String id,
  String? name,
  String? email,
  Map<String, dynamic>? customData,
})
```

**Chamada MethodChannel**:
- **Method**: `identify`
- **Arguments**:
  ```json
  {
    "id": String,
    "name": String?,
    "email": String?,
    "customData": Map<String, dynamic>?
  }
  ```

**Resposta**:
- **Success**: `null` (void)
- **Error**: `PlatformException` com código `NOT_INITIALIZED`, `INVALID_PARAMETERS`, ou `NETWORK_ERROR`

**Comportamento Nativo**:
- Android: Chama `br.com.dito.ditosdk.Dito.identify(id, name, email, customData)`
- iOS: Chama `Dito.identify(id: String, data: [String: Any]?)` onde `data` contém name, email e customData

---

### track

**Descrição**: Registra um evento no CRM Dito

**Método Dart**:
```dart
static Future<void> track({
  required String action,
  Map<String, dynamic>? data,
})
```

**Chamada MethodChannel**:
- **Method**: `track`
- **Arguments**:
  ```json
  {
    "action": String,
    "data": Map<String, dynamic>?
  }
  ```

**Resposta**:
- **Success**: `null` (void)
- **Error**: `PlatformException` com código `NOT_INITIALIZED`, `INVALID_PARAMETERS`, ou `NETWORK_ERROR`

**Comportamento Nativo**:
- Android: Chama `br.com.dito.ditosdk.Dito.track(action, data)`
- iOS: Chama `Dito.track(event: DitoEvent)` onde `DitoEvent` é criado com `name: action` e `data: data`

---

### registerDeviceToken

**Descrição**: Registra o token do dispositivo para push notifications

**Método Dart**:
```dart
static Future<void> registerDeviceToken(String token)
```

**Chamada MethodChannel**:
- **Method**: `registerDeviceToken`
- **Arguments**: `{"token": String}`

**Resposta**:
- **Success**: `null` (void)
- **Error**: `PlatformException` com código `NOT_INITIALIZED` ou `INVALID_PARAMETERS`

**Comportamento Nativo**:
- Android: Chama `br.com.dito.ditosdk.Dito.registerDevice(token)`
- iOS: Chama `Dito.registerDevice(token: String)`

---

## Códigos de Erro

| Código | Descrição | Quando Ocorre |
|--------|-----------|---------------|
| `INITIALIZATION_FAILED` | Falha na inicialização | Erro ao inicializar SDK nativa |
| `INVALID_CREDENTIALS` | Credenciais inválidas | apiKey ou apiSecret inválidos |
| `NOT_INITIALIZED` | Plugin não inicializado | Método chamado antes de initialize |
| `INVALID_PARAMETERS` | Parâmetros inválidos | Validação de parâmetros falhou |
| `NETWORK_ERROR` | Erro de rede | Falha na comunicação com servidor Dito |

## Convenções

- Todos os métodos são assíncronos (retornam `Future`)
- Erros são sempre `PlatformException` com código e mensagem descritiva
- Parâmetros opcionais são enviados como `null` se não fornecidos
- `Map<String, dynamic>` é serializado como JSON no MethodChannel
- Validação de parâmetros ocorre no lado Dart antes da chamada nativa

## Push Notifications (Métodos Estáticos Nativos)

### Android: handleNotification

**Assinatura**:
```kotlin
companion object {
    fun handleNotification(
        context: Context,
        message: RemoteMessage
    ): Boolean
}
```

**Contrato**:
- Verifica se `message.data["channel"] == "Dito"`
- Se sim: Chama SDK Dito e retorna `true`
- Se não: Retorna `false`

**Uso**: Chamado pelo código do app host (ex: Firebase Messaging Service)

---

### iOS: didReceiveNotificationRequest

**Assinatura**:
```swift
static func didReceiveNotificationRequest(
    _ request: UNNotificationRequest,
    fcmToken: String?
) -> Bool
```

**Contrato**:
- Verifica se `request.content.userInfo["channel"] == "Dito"`
- Se sim:
  - Chama `Dito.notificationRead(with: request.content.userInfo, token: fcmToken)` quando notificação é recebida
  - Chama `Dito.notificationClick(with: request.content.userInfo)` quando usuário interage
  - Retorna `true`
- Se não: Retorna `false`

**Notas**:
- `notificationRead` deve ser chamado quando notificação chega (foreground/background)
- `notificationClick` deve ser chamado quando usuário toca na notificação
- FCM token é necessário para `notificationRead` funcionar corretamente
- Ordem crítica: Firebase deve ser configurado ANTES do Dito SDK (iOS 18+)

**Uso**: Chamado pelo código do app host (ex: UNUserNotificationCenterDelegate)
