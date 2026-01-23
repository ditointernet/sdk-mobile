# Data Model

**Feature**: Plugin Flutter dito_sdk
**Date**: 2025-01-27

## Entidades Principais

### Configuração de Inicialização

**Descrição**: Credenciais e configurações necessárias para inicializar o plugin

**Atributos**:
- `apiKey` (String, obrigatório): Chave de API fornecida pela Dito
- `apiSecret` (String, obrigatório): Secret de API fornecida pela Dito

**Validação**:
- Ambos os campos devem ser não-nulos e não-vazios
- Validação ocorre no lado Dart antes de chamar código nativo

**Estado**: Não persiste - passado apenas durante inicialização

---

### Identificação de Usuário (Identify)

**Descrição**: Dados para identificar um usuário no CRM Dito

**Atributos**:
- `id` (String, obrigatório): Identificador único do usuário
- `name` (String, opcional): Nome do usuário
- `email` (String, opcional): Email do usuário
- `customData` (Map<String, dynamic>, opcional): Dados customizados adicionais

**Validação**:
- `id` deve ser não-nulo e não-vazio
- `email` deve ser válido se fornecido (formato de email)
- `customData` pode conter qualquer estrutura, mas será serializado para JSON

**Relacionamentos**: Associado a eventos (track) através do `id`

---

### Evento (Track)

**Descrição**: Evento ou ação registrada no CRM Dito

**Atributos**:
- `action` (String, obrigatório): Nome da ação/evento (ex: "purchase", "view_product")
- `data` (Map<String, dynamic>, opcional): Dados adicionais do evento

**Validação**:
- `action` deve ser não-nulo e não-vazio
- `data` será serializado para JSON se fornecido

**Relacionamentos**: Associado a um usuário identificado através do contexto da inicialização

---

### Token de Dispositivo

**Descrição**: Token FCM (Firebase Cloud Messaging) ou APNS para push notifications

**Atributos**:
- `token` (String, obrigatório): Token do dispositivo para push notifications

**Validação**:
- Token deve ser não-nulo e não-vazio
- Formato específico depende da plataforma (FCM para Android, APNS para iOS)

**Uso**: Registrado uma vez por dispositivo, pode ser atualizado quando o token mudar

---

### Notificação Push

**Descrição**: Notificação recebida que pode ser processada pela Dito SDK

**Atributos** (Android - RemoteMessage):
- `data` (Map<String, String>): Dados da notificação
  - `channel` (String): Identificador do canal ("Dito" para processar)

**Atributos** (iOS - UNNotificationRequest):
- `content.userInfo` (Dictionary): Dados da notificação
  - `channel` (String): Identificador do canal ("Dito" para processar)

**Validação**:
- Verifica se `channel == "Dito"` antes de processar
- Se não for "Dito", retorna false (não processado)

**Processamento**:
- Se channel == "Dito":
  - **iOS**: Chama `Dito.notificationRead(with:token:)` quando notificação chega e `Dito.notificationClick(with:)` quando usuário interage
  - **Android**: Processa via Firebase Messaging Service
  - Retorna `true`
- Caso contrário: Retorna `false` para permitir processamento normal

**Notas Específicas iOS**:
- `notificationRead` requer FCM token válido
- Deve ser chamado em `willPresent` (foreground) e `didReceiveRemoteNotification` (background)
- `notificationClick` deve ser chamado em `didReceive` (quando usuário toca na notificação)
- Ordem crítica: Firebase deve ser configurado ANTES do Dito SDK (iOS 18+)

---

## Fluxo de Dados

### Inicialização
```
Dart (DitoSdk.initialize)
  → MethodChannel
    → Android Plugin: br.com.dito.ditosdk.Dito.init(apiKey, apiSecret)
    → iOS Plugin: Dito.shared.configure() (ou via Info.plist)
```

### Identificação
```
Dart (DitoSdk.identify)
  → MethodChannel
    → Android Plugin: Dito.identify(id, name, email, customData)
    → iOS Plugin: Dito.identify(id: String, data: [String: Any]?)
      (data contém name, email e customData)
```

### Tracking
```
Dart (DitoSdk.track)
  → MethodChannel
    → Android Plugin: Dito.track(action: String, data: Map<String, Any>?)
    → iOS Plugin: Dito.track(event: DitoEvent)
      (DitoEvent criado com name: action, data: data)
```

### Push Notification (Android)
```
Firebase Messaging (onMessageReceived)
  → App Host Code
    → DitoSdkPlugin.handleNotification()
      → Verifica channel == "Dito"
        → SDK Nativa (se sim)
```

### Push Notification (iOS)
```
UNUserNotificationCenter (willPresent/didReceive)
  → App Host Code
    → SwiftDitoSdkPlugin.didReceiveNotificationRequest()
      → Verifica channel == "Dito"
        → Se sim:
          → Dito.notificationRead(with: userInfo, token: fcmToken) [quando recebe]
          → Dito.notificationClick(with: userInfo) [quando usuário interage]
          → Retorna true
        → Se não: Retorna false
```

## Serialização

- Todos os dados são serializados para JSON ao passar pelo MethodChannel
- `Map<String, dynamic>` no Dart vira `Map` no Kotlin/Swift
- Tipos primitivos (String, int, double, bool) são preservados
- Null safety é respeitado em ambos os lados

## Persistência

- Plugin não persiste dados localmente
- SDK nativa gerencia persistência de dados do CRM
- Estado de inicialização é mantido em memória (não persiste entre sessões)
